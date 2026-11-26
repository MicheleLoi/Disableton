import Foundation
import GrooveCore

#if canImport(CoreMIDI)
import CoreMIDI
import Darwin
import MIDIHost

/// `disableton ports`: elenca sorgenti e destinazioni MIDI.
func runPorts() throws {
    print("Sorgenti MIDI (ingressi per Disableton):")
    for s in MIDIBackend.sources { print("  - \(s.name)") }
    print("\nDestinazioni MIDI:")
    for d in MIDIBackend.destinations { print("  - \(d.name)") }
}

/// `disableton monitor [--input nome] [--show-clock]`
/// Mostra i messaggi in arrivo, con il tempo misurato dal clock e il jitter degli impulsi.
func runMonitor(_ argv: [String]) throws {
    let args = try Args(argv, flags: ["show-clock"])
    let showClock = args.flag("show-clock")
    let backend = try MIDIBackend(clientName: "Disableton Monitor")
    let lock = NSLock()
    var origin: UInt64?
    var clockTimes: [UInt64] = []

    backend.onMessage = { message, time in
        lock.lock()
        defer { lock.unlock() }
        if origin == nil { origin = time }
        let ms = Double(time &- origin!) / 1_000_000
        let stamp = String(format: "%10.3f ms", ms)
        if case .timingClock = message {
            clockTimes.append(time)
            if showClock { print("\(stamp)  Clock") }
            if clockTimes.count == 25 {
                // Un quarto completo: tempo medio e scarto massimo degli impulsi.
                let total = Double(clockTimes[24] - clockTimes[0])
                let mean = total / 24
                var maxDeviation = 0.0
                for i in 1...24 {
                    let expected = Double(clockTimes[0]) + mean * Double(i)
                    maxDeviation = max(maxDeviation, abs(Double(clockTimes[i]) - expected))
                }
                let bpm = 60_000_000_000 / (mean * 24)
                print("\(stamp)  Clock: \(String(format: "%.2f", bpm)) BPM, scarto max impulsi ±\(String(format: "%.2f", maxDeviation / 1_000_000)) ms")
                clockTimes = [clockTimes[24]]
            }
            return
        }
        if case .activeSensing = message { return }
        if case .start = message { clockTimes.removeAll() }
        print("\(stamp)  \(message)")
    }

    let names = try backend.connectSources(matching: args.value("input"))
    guard !names.isEmpty else { throw noSourceError(args.value("input")) }
    print("In ascolto su: \(names.joined(separator: ", "))")
    print("Premi Ctrl-C per uscire.\n")
    withExtendedLifetime(backend) {
        RunLoop.main.run()
    }
}

/// `disableton play`: segue il clock della workstation e suona i groove sulla porta virtuale "Disableton".
///
///     disableton play --loop strofa.mid --loop ritornello.mid --fill fill.mid [--meter 4/4]
///     disableton play --library [--dir cartella] [--song 1]
///
/// Opzioni: --input <nome sorgente>, --channel <1-16> (uscita, predefinito 10),
/// --latency-ms <anticipo>, --lookahead-ms <anticipo di programmazione>, --no-autostart
func runPlay(_ argv: [String]) throws {
    let args = try Args(argv, flags: ["library", "no-autostart"])

    let songs: [EngineSong]
    var controlMap = ControlMap.default
    var channel = try args.int("channel") ?? 10
    var performance = PerformanceSettings()

    if args.flag("library") {
        let root = args.value("dir").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LibraryStore.defaultRoot
        let store = try LibraryStore(root: root)
        songs = try store.engineSongs()
        controlMap = store.library.controlMap
        performance = store.library.performance
        if args.value("channel") == nil { channel = store.library.outputChannel }
        guard !songs.isEmpty else { throw CLIError("la libreria in \(root.path) non contiene brani") }
    } else {
        let meter = try args.timeSignature("meter") ?? .fourFour
        var slots: [EngineSlot] = []
        func add(_ paths: [String], mode: SlotMode) throws {
            for path in paths {
                let groove = try Groove(contentsOf: URL(fileURLWithPath: path),
                                        options: GrooveImportOptions(timeSignature: meter))
                slots.append(EngineSlot(name: groove.name, groove: groove, mode: mode, quantize: .bar))
            }
        }
        try add(args.values("loop"), mode: .loop)
        try add(args.values("fill"), mode: .oneShotReturn)
        try add(args.values("ending"), mode: .oneShotStop)
        guard !slots.isEmpty else { throw CLIError("indicare almeno un groove con --loop, oppure --library") }
        songs = [EngineSong(name: "Prova", timeSignature: meter, slots: slots,
                            autoStartSlot: args.flag("no-autostart") ? nil : 0)]
    }
    guard (1...16).contains(channel) else { throw CLIError("--channel deve essere tra 1 e 16") }
    if let ms = try args.double("latency-ms") { performance.latencyMs = ms }
    if let ms = try args.double("lookahead-ms") { performance.lookaheadMs = ms }
    let inputFilter = args.value("input") ?? (args.flag("library") ? performance.inputFilter : nil)

    switch args.value("sound") {
    case nil: break
    case "virtual": performance.soundOutput = .virtualPort
    case "synth": performance.soundOutput = .builtInSynth
    case "midi": performance.soundOutput = .midiDestination
    case let other?: throw CLIError("--sound non valido: \(other) (ammessi: virtual, synth, midi)")
    }
    if let dest = args.value("dest") { performance.destinationFilter = dest }

    let host = try LiveHost(songs: songs, controlMap: controlMap, outputChannel: channel,
                            settings: performance.playbackSettings, inputFilter: inputFilter,
                            output: performance.soundOutput, destinationFilter: performance.destinationFilter)
    let names = host.connectedInputs
    guard !names.isEmpty else { throw noSourceError(inputFilter) }
    if let n = try args.int("song") { host.perform(.selectSong(n - 1)) }

    print("Ingresso: \(names.joined(separator: ", "))")
    print("Uscita:   \(host.snapshot().outputDescription), canale \(channel)")
    print("Brani:    \(songs.count)")
    Thread.sleep(forTimeInterval: 0.05)
    print("Priorità tempo reale del motore: \(host.snapshot().realtimePriority ? "ottenuta" : "NON ottenuta")")
    for (i, slot) in (songs.first?.slots ?? []).enumerated() where !args.flag("library") {
        let note = 36 + i
        print("  \(i + 1). \(slot.name) [\(slot.mode.rawValue)] — nota \(note) (\(NoteName.korg(UInt8(note)))) sul canale 16")
    }
    print("Avvia il sequencer della workstation. Ctrl-C per uscire.\n")

    // Riga di stato a ogni cambio e a ogni battuta.
    var lastStatus: PlaybackStatus?
    var lastBar: Int?
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: .milliseconds(100))
    timer.setEventHandler {
        let snap = host.snapshot()
        if snap.status != lastStatus {
            lastStatus = snap.status
            print(describe(snap.status))
        }
        guard let bar = snap.bar, bar != lastBar else { return }
        lastBar = bar
        let tempo = snap.tempoBPM.map { String(format: "%.1f BPM", $0) } ?? "-"
        print("  battuta \(bar)  \(tempo)  \(snap.status.playingSlotName ?? "silenzio")")
    }
    timer.resume()

    // Ctrl-C: spegne le note prima di uscire.
    signal(SIGINT, SIG_IGN)
    let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigint.setEventHandler {
        host.shutdown()
        print("\nUscita.")
        exit(0)
    }
    sigint.resume()

    withExtendedLifetime((host, timer, sigint)) {
        RunLoop.main.run()
    }
}

private func noSourceError(_ filter: String?) -> CLIError {
    guard let filter else { return CLIError("nessuna sorgente MIDI trovata") }
    return CLIError("nessuna sorgente MIDI trovata con nome contenente \"" + filter + "\" (vedi: disableton ports)")
}

private func describe(_ s: PlaybackStatus) -> String {
    var parts: [String] = []
    parts.append("brano \((s.songIndex ?? -1) + 1): \(s.songName ?? "-")")
    parts.append(s.transportRunning ? "▶︎" : "■")
    parts.append("suona: \(s.playingSlotName ?? "silenzio")")
    if s.stopPending {
        parts.append("in coda: silenzio")
    } else if let next = s.pendingSlotName {
        parts.append("in coda: \(next)")
    }
    if let armed = s.armedSlot { parts.append("pronto allo Start: slot \(armed + 1)") }
    return "[stato] " + parts.joined(separator: "  ")
}

#else

func runPorts() throws { throw CLIError("comando disponibile solo su macOS") }
func runMonitor(_ argv: [String]) throws { throw CLIError("comando disponibile solo su macOS") }
func runPlay(_ argv: [String]) throws { throw CLIError("comando disponibile solo su macOS") }

#endif
