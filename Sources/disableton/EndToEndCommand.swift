import Foundation
import GrooveCore

#if canImport(CoreMIDI)
import Darwin
import MIDIHost

/// `disableton e2e [--bpm 120]`
/// Prova completa della catena MIDI senza hardware: un "Krome simulato" (porta virtuale) invia
/// Program Change, Start, clock, comandi di cambio e fill, Stop, Song Position e Continue;
/// un "EZdrummer simulato" ascolta la porta "Disableton". Si confrontano le note ricevute con
/// quelle attese, nell'ordine e nei tempi.
func runEndToEnd(_ argv: [String]) throws {
    let args = try Args(argv)
    let bpm = try args.double("bpm") ?? 120
    let nsPerClock = 60_000_000_000.0 / (bpm * 24)
    let nsPerTick = nsPerClock / Double(ClockFollower.songTicksPerClock)
    let songs = DemoContent.engineSongs()

    // Scenario, in impulsi di clock (24 per quarto, 96 per battuta in 4/4).
    let selectSong = MIDIMessage.programChange(channel: 15, program: 0)     // brano 1: Demo 1 – Rock
    let switchAt = 2 * 96 + 40          // battuta 3: groove 2 (ritornello) dalla battuta 4
    let fillAt = 4 * 96 + 50            // battuta 5: fill alla battuta 6, poi ritorno
    let stopAt = 8 * 96                 // Stop dopo 8 battute
    let resumeSixteenths = 10 * 16      // poi Song Position alla battuta 11 e Continue
    let resumeClocks = 2 * 96           // per 2 battute

    // Risultato atteso: lo stesso motore, senza MIDI né tempo reale.
    let reference = GrooveEngine(outputChannel: 9)
    reference.load(song: songs[0])
    var expected: [(tick: Int, segment: Int, message: MIDIMessage)] = []
    func collect(_ events: [ScheduledMIDI], segment: Int) {
        for e in events { if case .noteOn = e.message { expected.append((e.tick, segment, e.message)) } }
    }
    let ticksPerClock = ClockFollower.songTicksPerClock
    reference.transportStarted(at: 0)
    collect(reference.render(to: (switchAt + 1) * ticksPerClock), segment: 0)
    reference.trigger(slot: 1)
    collect(reference.render(to: (fillAt + 1) * ticksPerClock), segment: 0)
    reference.triggerFill()
    collect(reference.render(to: stopAt * ticksPerClock), segment: 0)
    _ = reference.transportStopped()
    let resumeTick = resumeSixteenths * 6 * ticksPerClock
    reference.transportStarted(at: resumeTick)
    collect(reference.render(to: resumeTick + resumeClocks * ticksPerClock), segment: 1)

    // Catena reale.
    let krome = try MIDIBackend(clientName: "Krome simulato")
    try krome.createVirtualSource(named: "Krome simulato")
    let host = try LiveHost(songs: songs, controlMap: .default, outputChannel: 10,
                            settings: PlaybackController.Settings(), inputFilter: "Krome simulato")
    guard host.connectedInputs == ["Krome simulato"] else {
        throw CLIError("Disableton non si è collegato al Krome simulato (collegati: \(host.connectedInputs))")
    }
    let ezdrummer = try MIDIBackend(clientName: "EZdrummer simulato")
    let lock = NSLock()
    var received: [(message: MIDIMessage, timestamp: UInt64, arrival: UInt64)] = []
    ezdrummer.onMessage = { message, time in
        let arrival = HostClock.nowNanos()
        if case .noteOn = message {
            lock.lock()
            received.append((message, time, arrival))
            lock.unlock()
        }
    }
    let outputs = try ezdrummer.connectSources(matching: LiveHost.virtualPortName)
    guard !outputs.isEmpty else { throw CLIError("porta \"\(LiveHost.virtualPortName)\" non trovata") }
    Thread.sleep(forTimeInterval: 0.5)
    print("Catena: Krome simulato → Disableton → EZdrummer simulato (\(bpm) BPM)")

    // Il Krome simulato suona su un thread tempo reale, all'istante esatto di ogni impulso.
    var segmentStarts: [UInt64] = [0, 0]
    let done = DispatchSemaphore(value: 0)
    let player = Thread {
        RealtimeThread.promoteCurrentThread(periodNs: 500_000, computationNs: 100_000, constraintNs: 500_000)
        func play(clocks: Int, from start: UInt64, commands: [Int: MIDIMessage]) {
            for k in 0..<clocks {
                let t = start + UInt64(Double(k) * nsPerClock)
                HostClock.wait(untilNanos: t)
                krome.send(.timingClock, atNanos: t)
                if let command = commands[k] {
                    HostClock.wait(untilNanos: t + 2_000_000)
                    krome.send(command, atNanos: 0)
                }
            }
        }
        krome.send(selectSong, atNanos: 0)
        Thread.sleep(forTimeInterval: 0.2)
        let start1 = HostClock.nowNanos() + 50_000_000
        segmentStarts[0] = start1
        HostClock.wait(untilNanos: start1 - 2_000_000)
        krome.send(.start, atNanos: 0)
        play(clocks: stopAt, from: start1, commands: [
            switchAt: .noteOn(channel: 15, note: 37, velocity: 100),
            fillAt: .noteOn(channel: 15, note: 48, velocity: 100),
        ])
        // Stop poco dopo l'ultimo impulso, prima del battere successivo.
        HostClock.wait(untilNanos: start1 + UInt64(Double(stopAt - 1) * nsPerClock) + 5_000_000)
        krome.send(.stop, atNanos: 0)
        Thread.sleep(forTimeInterval: 0.3)
        krome.send(.songPosition(beats: UInt16(resumeSixteenths)), atNanos: 0)
        Thread.sleep(forTimeInterval: 0.05)
        let start2 = HostClock.nowNanos() + 50_000_000
        segmentStarts[1] = start2
        HostClock.wait(untilNanos: start2 - 2_000_000)
        krome.send(.continuePlayback, atNanos: 0)
        play(clocks: resumeClocks, from: start2, commands: [:])
        HostClock.wait(untilNanos: start2 + UInt64(Double(resumeClocks - 1) * nsPerClock) + 5_000_000)
        krome.send(.stop, atNanos: 0)
        Thread.sleep(forTimeInterval: 0.3)
        done.signal()
    }
    player.start()
    done.wait()
    let snapshot = host.snapshot()
    host.shutdown()

    // Confronto.
    lock.lock()
    let got = received
    lock.unlock()
    print("Note attese:   \(expected.count)")
    print("Note ricevute: \(got.count)")
    var failures: [String] = []
    if got.map({ $0.message }) != expected.map({ $0.message }) {
        let firstDifference = zip(got.map { $0.message }, expected.map { $0.message })
            .enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(got.count, expected.count)
        failures.append("sequenza di note diversa dall'attesa (prima differenza alla nota \(firstDifference + 1))")
    }
    var timestampErrors: [Double] = []
    var arrivalErrors: [Double] = []
    for (g, e) in zip(got, expected) {
        let base = segmentStarts[e.segment]
        let localTick = e.segment == 0 ? e.tick : e.tick - resumeTick
        let expectedTime = Double(base) + Double(localTick) * nsPerTick
        timestampErrors.append((Double(g.timestamp) - expectedTime) / 1_000_000)
        arrivalErrors.append((Double(g.arrival) - expectedTime) / 1_000_000)
    }
    func stats(_ v: [Double]) -> String {
        guard !v.isEmpty else { return "-" }
        let sorted = v.map { abs($0) }.sorted()
        return String(format: "mediana %.3f ms, 99%% %.3f ms, massimo %.3f ms",
                      sorted[sorted.count / 2], sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.99))],
                      sorted.last ?? 0)
    }
    print("Scarto dei timestamp rispetto al tempo previsto: \(stats(timestampErrors))")
    print("Scarto di arrivo (informativo):                 \(stats(arrivalErrors))")
    print("Priorità tempo reale del motore: \(snapshot.realtimePriority ? "ottenuta" : "NON ottenuta")")
    let maxTimestampError = timestampErrors.map { abs($0) }.max() ?? 0
    if maxTimestampError > 2 {
        failures.append(String(format: "scarto dei timestamp troppo grande (%.3f ms)", maxTimestampError))
    }
    if expected.isEmpty { failures.append("nessuna nota attesa: scenario non valido") }

    if failures.isEmpty {
        print("Esito: OK — brano, Start, cambio di groove, fill con ritorno, Stop, Song Position e Continue corretti")
    } else {
        for f in failures { print("ERRORE: \(f)") }
        throw CLIError("prova della catena MIDI non superata")
    }
}

#else

func runEndToEnd(_ argv: [String]) throws { throw CLIError("comando disponibile solo su macOS") }

#endif
