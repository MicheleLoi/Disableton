import Foundation
import GrooveCore

#if canImport(CoreMIDI)
import CoreMIDI
import Darwin

let virtualPortName = "Disableton"

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

/// `disableton play`: segue il clock del Krome e suona i groove sulla porta virtuale "Disableton".
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

    if args.flag("library") {
        let root = args.value("dir").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LibraryStore.defaultRoot
        let store = try LibraryStore(root: root)
        songs = try store.engineSongs()
        controlMap = store.library.controlMap
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

    var settings = PlaybackController.Settings()
    if let ms = try args.double("latency-ms") { settings.latencyCompensationNs = UInt64(max(0, ms) * 1_000_000) }
    if let ms = try args.double("lookahead-ms") { settings.lookaheadNs = UInt64(max(0.1, ms) * 1_000_000) }

    let backend = try MIDIBackend(clientName: "Disableton")
    try backend.createVirtualSource(named: virtualPortName)

    let controller = PlaybackController(songs: songs, controlMap: controlMap, outputChannel: UInt8(channel - 1),
                                        settings: settings) { message, time in
        backend.send(message, atNanos: time)
    }
    if let n = try args.int("song") { controller.selectSong(n - 1) }

    let lock = NSLock()
    controller.onStatusChange = { status in
        let line = describe(status)
        DispatchQueue.main.async { print(line) }
    }
    backend.onMessage = { message, time in
        lock.lock()
        controller.handle(message, at: time, now: HostClock.nowNanos())
        lock.unlock()
    }

    let names = try backend.connectSources(matching: args.value("input"))
    guard !names.isEmpty else { throw noSourceError(args.value("input")) }

    print("Ingresso: \(names.joined(separator: ", "))")
    print("Uscita:   porta virtuale \"\(virtualPortName)\", canale \(channel) — selezionala come ingresso MIDI in EZdrummer 3")
    print("Brani:    \(songs.count); slot del brano corrente:")
    if let song = controller.engine.song {
        for (i, slot) in song.slots.enumerated() {
            let note = 36 + i
            print("  \(i + 1). \(slot.name) [\(slot.mode.rawValue)] — nota \(note) (\(NoteName.korg(UInt8(note)))) sul canale 16")
        }
    }
    print("Avvia il sequencer del Krome. Ctrl-C per uscire.\n")

    PerformanceGuard.begin(reason: "Riproduzione groove sincronizzata al Krome")

    // Thread di generazione: ogni 0,5 ms prepara gli eventi dei prossimi millisecondi.
    let worker = Thread {
        while true {
            let now = HostClock.nowNanos()
            lock.lock()
            controller.process(now: now)
            lock.unlock()
            HostClock.wait(untilNanos: now + 500_000)
        }
    }
    worker.qualityOfService = .userInteractive
    worker.start()

    // Riga di stato a ogni battuta.
    var lastBar: Int?
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now(), repeating: .milliseconds(100))
    timer.setEventHandler {
        lock.lock()
        let bar = controller.currentBar
        let bpm = controller.tempoBPM
        let status = controller.status
        lock.unlock()
        guard let bar, bar != lastBar else { return }
        lastBar = bar
        let tempo = bpm.map { String(format: "%.1f BPM", $0) } ?? "-"
        print("  battuta \(bar)  \(tempo)  \(status.playingSlotName ?? "silenzio")")
    }
    timer.resume()

    // Ctrl-C: spegne le note prima di uscire.
    signal(SIGINT, SIG_IGN)
    let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigint.setEventHandler {
        lock.lock()
        for m in controller.engine.panic() { backend.send(m, atNanos: 0) }
        lock.unlock()
        print("\nUscita.")
        exit(0)
    }
    sigint.resume()

    withExtendedLifetime((backend, timer, sigint)) {
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
