import Foundation
import GrooveCore

#if canImport(CoreMIDI)
import Darwin
import MIDIHost

/// `disableton selftest [--seconds N] [--bpm B]`
/// Verifica sul Mac, senza Krome né EZdrummer: priorità tempo reale del thread e puntualità del
/// ciclo di generazione (stesso codice e stesso periodo usati dal vivo, con un clock interno).
func runSelfTest(_ argv: [String]) throws {
    let args = try Args(argv)
    let seconds = try args.double("seconds") ?? 5
    let bpm = try args.double("bpm") ?? 120

    // Groove di prova: sedicesimi con piccoli scostamenti "umani".
    var events: [GrooveEvent] = []
    for i in 0..<16 {
        let jitter = [0, 7, -5, 3][i % 4]
        events.append(GrooveEvent(tick: max(0, i * 240 + jitter), kind: .noteOn(note: i % 4 == 0 ? 36 : 42, velocity: 100)))
    }
    let groove = Groove(name: "test", timeSignature: .fourFour, lengthTicks: 3840, events: events)

    var lateness: [Double] = []      // ms di ritardo rispetto all'istante previsto (negativo = in anticipo)
    var cycleGaps: [Double] = []     // ms tra un ciclo e il successivo
    let lock = NSLock()
    var granted = false
    var verified = false
    let done = DispatchSemaphore(value: 0)

    let thread = Thread {
        granted = RealtimeThread.promoteCurrentThread(periodNs: 500_000, computationNs: 100_000, constraintNs: 500_000)
        verified = RealtimeThread.currentThreadIsRealtime()
        let controller = PlaybackController(songs: [EngineSong(name: "test", slots: [EngineSlot(name: "test", groove: groove)])]) { _, time in
            let now = HostClock.nowNanos()
            lock.lock()
            lateness.append((Double(now) - Double(time)) / 1_000_000)
            lock.unlock()
        }
        let start = HostClock.nowNanos() + 10_000_000
        var clock = ClockGenerator(bpm: bpm, startTime: start)
        controller.handle(.start, at: start, now: start)
        let end = start + UInt64(seconds * 1_000_000_000)
        var previous: UInt64?
        while true {
            let now = HostClock.nowNanos()
            if now > end { break }
            if let p = previous { cycleGaps.append(Double(now - p) / 1_000_000) }
            previous = now
            for t in clock.ticks(upTo: now) { controller.handle(.timingClock, at: t, now: now) }
            controller.process(now: now)
            HostClock.wait(untilNanos: now + 500_000)
        }
        done.signal()
    }
    thread.qualityOfService = .userInteractive
    thread.start()
    done.wait()

    func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))]
    }

    // Gli eventi sono generati con 2 ms di anticipo e inviati con timestamp: conta il ritardo
    // dell'invio rispetto all'istante previsto (positivo = in ritardo, cioè troppo tardi).
    let late = lateness.map { max(0, $0) }
    print("Priorità tempo reale:   \(granted ? "ottenuta" : "NON ottenuta")\(verified ? " (verificata)" : "")")
    print("Eventi inviati:         \(lateness.count) in \(seconds) s a \(bpm) BPM")
    print(String(format: "Anticipo di invio:      mediana %.2f ms (atteso circa 2 ms: lookahead)", -percentile(lateness, 0.5)))
    print(String(format: "Invii in ritardo:       %d; ritardo massimo %.3f ms", late.filter { $0 > 0 }.count, late.max() ?? 0))
    print(String(format: "Ciclo di generazione:   mediana %.3f ms, 99%% %.3f ms, massimo %.3f ms (atteso 0,5 ms)",
                 percentile(cycleGaps, 0.5), percentile(cycleGaps, 0.99), cycleGaps.max() ?? 0))

    let maxLate = late.max() ?? 0
    if lateness.isEmpty || maxLate > 10 {
        throw CLIError("verifica non superata: nessun evento o ritardo eccessivo (\(maxLate) ms)")
    }
    print("Esito: OK")
}

#else

func runSelfTest(_ argv: [String]) throws { throw CLIError("comando disponibile solo su macOS") }

#endif
