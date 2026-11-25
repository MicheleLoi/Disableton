#if canImport(CoreMIDI)
import CoreMIDI
import Foundation
import GrooveCore

/// Fotografia dello stato, letta periodicamente dall'interfaccia.
public struct LiveSnapshot: Equatable {
    public var status: PlaybackStatus
    public var bar: Int?
    /// Battito nella battuta (1-based).
    public var beat: Int?
    public var beatsPerBar: Int
    /// Tempo arrotondato a 0,1 BPM.
    public var tempoBPM: Double?
    /// Clock del Krome ricevuto negli ultimi 300 ms.
    public var clockReceiving: Bool
    /// Clock interno attivo (prova senza Krome).
    public var internalClock: Bool
    public var lastCommand: String?
    /// Ultimo messaggio MIDI ricevuto non associato ad alcun comando (es. canale sbagliato).
    public var lastUnmapped: String?
    /// Ascolto di un singolo groove in corso.
    public var previewing: Bool
    public var learning: Bool
    /// Il thread di generazione ha ottenuto la priorità tempo reale di macOS.
    public var realtimePriority: Bool
    public var output: SoundOutput
    /// Descrizione della destinazione del suono (o del problema).
    public var outputDescription: String
}

/// Motore dal vivo completo: ingresso dal Krome, uscita verso EZdrummer / sintetizzatore di
/// macOS / Krome, thread di generazione ad alta priorità, clock interno, ascolto e MIDI Learn.
/// Tutti i metodi pubblici sono sicuri da chiamare dal thread principale.
public final class LiveHost {
    public static let virtualPortName = "Disableton"

    /// Nomi delle sorgenti MIDI disponibili (esclusa la porta virtuale di Disableton).
    public static func sourceNames() -> [String] {
        MIDIBackend.sources.map { $0.name }.filter { $0 != virtualPortName }
    }

    /// Nomi delle destinazioni MIDI disponibili (per inviare la batteria al Krome).
    public static func destinationNames() -> [String] {
        MIDIBackend.destinations.map { $0.name }
    }

    private enum InternalMode { case none, preview, transport }

    private let backend: MIDIBackend
    private let controller: PlaybackController
    private let lock = NSLock()
    private var keepRunning = true
    private var internalClock: ClockGenerator?
    private var internalMode = InternalMode.none
    private var learning = false
    private var connected: [String] = []
    private var realtimeGranted = false
    private var output = SoundOutput.ezdrummer
    private var outputDescription = ""
    private var synth: AnyObject?
    private var lastUnmapped: MIDIMessage?

    public init(songs: [EngineSong], controlMap: ControlMap, outputChannel: Int,
                settings: PlaybackController.Settings, inputFilter: String?,
                output: SoundOutput = .ezdrummer, destinationFilter: String? = nil,
                noteMap: NoteMap? = nil) throws {
        let backend = try MIDIBackend(clientName: "Disableton")
        try backend.createVirtualSource(named: LiveHost.virtualPortName)
        self.backend = backend
        self.controller = PlaybackController(songs: songs, controlMap: controlMap,
                                             outputChannel: LiveHost.channelIndex(outputChannel),
                                             settings: settings) { _, _ in }
        controller.output = { [weak self] message, time in
            self?.route(message, at: time)
        }
        backend.onMessage = { [weak self] message, time in
            self?.receive(message, at: time)
        }
        controller.engine.noteMap = noteMap
        controller.onUnmappedMessage = { [weak self] message in
            self?.lastUnmapped = message
        }
        connected = try backend.connectSources(matching: inputFilter)
        configureOutput(output, destinationFilter: destinationFilter)
        PerformanceGuard.begin(reason: "Riproduzione groove sincronizzata al Krome")
        startWorker()
    }

    deinit {
        shutdown()
    }

    // MARK: - Stato

    public var connectedInputs: [String] {
        lock.lock(); defer { lock.unlock() }
        return connected
    }

    public func snapshot() -> LiveSnapshot {
        lock.lock(); defer { lock.unlock() }
        let now = HostClock.nowNanos()
        let receiving = internalMode == .none
            && (controller.lastClockTime.map { now > $0 ? now - $0 < 300_000_000 : true } ?? false)
        let bpm = controller.tempoBPM.map { ($0 * 10).rounded() / 10 }
        let ts = controller.engine.song?.timeSignature ?? .fourFour
        var beat: Int?
        if controller.engine.isRunning, let tick = controller.follower.lastSongTick {
            let beatTicks = ts.ticksPerBeat(ppq: Groove.ppq)
            beat = (tick % ts.ticksPerBar(ppq: Groove.ppq)) / beatTicks + 1
        }
        return LiveSnapshot(status: controller.status,
                            bar: controller.currentBar,
                            beat: beat,
                            beatsPerBar: ts.beatsPerBar,
                            tempoBPM: receiving || internalMode != .none ? bpm : nil,
                            clockReceiving: receiving,
                            internalClock: internalMode == .transport,
                            lastCommand: controller.lastCommand?.description,
                            lastUnmapped: lastUnmapped?.description,
                            previewing: internalMode == .preview,
                            learning: learning,
                            realtimePriority: realtimeGranted,
                            output: output,
                            outputDescription: outputDescription)
    }

    // MARK: - Configurazione

    /// Aggiorna brani, comandi e impostazioni. Se sta suonando, i nuovi brani diventano
    /// effettivi allo Stop, per non disturbare l'esecuzione.
    public func update(songs: [EngineSong], controlMap: ControlMap, outputChannel: Int,
                       settings: PlaybackController.Settings, noteMap: NoteMap? = nil) {
        lock.lock(); defer { lock.unlock() }
        if controller.engine.noteMap != noteMap {
            for m in controller.engine.panic() { route(m, at: 0) }
            controller.engine.noteMap = noteMap
        }
        controller.controlMap = controlMap
        controller.settings = settings
        controller.engine.outputChannel = LiveHost.channelIndex(outputChannel)
        controller.replaceSongs(songs)
    }

    /// Ricollega l'ingresso MIDI (nil = tutte le sorgenti).
    @discardableResult
    public func reconnect(inputFilter: String?) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        backend.disconnectAll()
        connected = try backend.connectSources(matching: inputFilter)
        return connected
    }

    /// Sceglie dove suonare la batteria. Restituisce la descrizione dell'uscita.
    @discardableResult
    public func configureOutput(_ output: SoundOutput, destinationFilter: String?) -> String {
        lock.lock(); defer { lock.unlock() }
        for m in controller.engine.panic() { route(m, at: 0) }
        self.output = output
        backend.sendsToVirtualSource = output == .ezdrummer
        backend.setDestinations(matching: nil)
        if output != .builtInSynth, let old = synth {
            stopSynth(old)
            synth = nil
        }
        switch output {
        case .ezdrummer:
            outputDescription = "Porta virtuale \"\(LiveHost.virtualPortName)\""
        case .midiDestination:
            let names = backend.setDestinations(matching: destinationFilter)
            outputDescription = names.isEmpty
                ? "Nessuna destinazione MIDI con nome \"\(destinationFilter ?? "")\""
                : names.joined(separator: ", ")
        case .builtInSynth:
            if synth == nil { synth = makeSynth() }
            outputDescription = synth == nil ? "Sintetizzatore di macOS non disponibile" : "Sintetizzatore di macOS"
        }
        return outputDescription
    }

    // MARK: - Comandi dall'interfaccia

    public func perform(_ action: ControlAction) {
        lock.lock(); defer { lock.unlock() }
        controller.perform(action, now: HostClock.nowNanos())
    }

    /// Emergenza: silenzio immediato. Ferma ascolto e clock interno; con il Krome il groove
    /// si ferma subito (il trasporto del Krome continua, un nuovo comando fa ripartire).
    public func panic() {
        lock.lock(); defer { lock.unlock() }
        stopInternalLocked(now: HostClock.nowNanos())
        for m in controller.engine.silenceNow() { route(m, at: 0) }
    }

    /// Suona una singola nota sullo strumento (per trovare i suoni di un kit), senza mappa.
    public func playTestNote(_ note: UInt8, velocity: UInt8 = 110) {
        lock.lock(); defer { lock.unlock() }
        let channel = controller.engine.outputChannel
        let now = HostClock.nowNanos()
        route(.noteOn(channel: channel, note: note, velocity: velocity), at: now)
        route(.noteOff(channel: channel, note: note, velocity: 0), at: now + 300_000_000)
    }

    /// Cambia il tempo del clock interno (o dell'ascolto) senza ricominciare.
    public func setInternalBPM(_ bpm: Double) {
        lock.lock(); defer { lock.unlock() }
        if let clock = internalClock { internalClock = clock.retimed(bpm: bpm) }
    }

    // MARK: - Clock interno

    /// Avvia il brano corrente con il clock interno (prova senza Krome). I comandi dal Krome
    /// continuano a funzionare; clock e trasporto del Krome vengono ignorati.
    public func startInternalClock(bpm: Double) {
        lock.lock(); defer { lock.unlock() }
        let now = HostClock.nowNanos()
        stopInternalLocked(now: now)
        if controller.engine.isRunning { controller.handle(.stop, at: now, now: now) }
        internalMode = .transport
        controller.handle(.start, at: now, now: now)
        internalClock = ClockGenerator(bpm: bpm, startTime: now + 5_000_000)
    }

    public func stopInternalClock() {
        lock.lock(); defer { lock.unlock() }
        stopInternalLocked(now: HostClock.nowNanos())
    }

    /// Suona un groove in ripetizione al tempo indicato, senza il Krome.
    public func startPreview(groove: Groove, bpm: Double) {
        lock.lock(); defer { lock.unlock() }
        let now = HostClock.nowNanos()
        stopInternalLocked(now: now)
        if controller.engine.isRunning { controller.handle(.stop, at: now, now: now) }
        controller.engine.load(song: EngineSong(name: "Ascolto: \(groove.name)", timeSignature: groove.timeSignature,
                                                slots: [EngineSlot(name: groove.name, groove: groove)], autoStartSlot: 0))
        internalMode = .preview
        controller.handle(.start, at: now, now: now)
        internalClock = ClockGenerator(bpm: bpm, startTime: now + 5_000_000)
    }

    public func stopPreview() {
        lock.lock(); defer { lock.unlock() }
        guard internalMode == .preview else { return }
        stopInternalLocked(now: HostClock.nowNanos())
    }

    private func stopInternalLocked(now: UInt64) {
        guard internalMode != .none else { return }
        let wasPreview = internalMode == .preview
        internalClock = nil
        controller.handle(.stop, at: now, now: now)
        internalMode = .none
        if wasPreview, let i = controller.currentSongIndex { controller.selectSong(i) }
    }

    // MARK: - MIDI Learn

    /// Il prossimo Note On / CC / Program Change ricevuto viene passato a `handler`
    /// (sulla coda principale) invece di essere eseguito.
    public func learnNext(_ handler: @escaping (MIDIMessage) -> Void) {
        lock.lock(); defer { lock.unlock() }
        learning = true
        controller.learnCapture = { [weak self] message in
            self?.learning = false
            DispatchQueue.main.async { handler(message) }
        }
    }

    public func cancelLearn() {
        lock.lock(); defer { lock.unlock() }
        learning = false
        controller.learnCapture = nil
    }

    // MARK: - Interni

    public func shutdown() {
        lock.lock()
        let wasRunning = keepRunning
        keepRunning = false
        if wasRunning {
            for m in controller.engine.panic() { route(m, at: 0) }
        }
        if let s = synth { stopSynth(s) }
        synth = nil
        lock.unlock()
    }

    /// Invio verso l'uscita scelta. Chiamato con il lock acquisito.
    private func route(_ message: MIDIMessage, at time: UInt64) {
        switch output {
        case .ezdrummer, .midiDestination:
            backend.send(message, atNanos: time)
        case .builtInSynth:
            sendToSynth(message, at: time)
        }
    }

    private func receive(_ message: MIDIMessage, at time: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if internalMode != .none && LiveHost.isTransport(message) { return }
        controller.handle(message, at: time, now: HostClock.nowNanos())
    }

    /// Un passo del thread di generazione; false = il thread deve terminare.
    private func step() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard keepRunning else { return false }
        let now = HostClock.nowNanos()
        if var clock = internalClock {
            let ticks = clock.ticks(upTo: now)
            internalClock = clock
            for t in ticks { controller.handle(.timingClock, at: t, now: now) }
        }
        controller.process(now: now)
        return true
    }

    private func startWorker() {
        let thread = Thread { [weak self] in
            let granted = RealtimeThread.promoteCurrentThread(periodNs: LiveHost.cycleNs,
                                                              computationNs: 100_000,
                                                              constraintNs: LiveHost.cycleNs)
            if let host = self {
                host.lock.lock()
                host.realtimeGranted = granted
                host.lock.unlock()
            }
            while true {
                guard let host = self, host.step() else { return }
                HostClock.wait(untilNanos: HostClock.nowNanos() + LiveHost.cycleNs)
            }
        }
        thread.name = "Disableton groove"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Periodo del thread di generazione.
    static let cycleNs: UInt64 = 500_000

    private static func channelIndex(_ channel: Int) -> UInt8 {
        UInt8(min(max(channel, 1), 16) - 1)
    }

    private static func isTransport(_ message: MIDIMessage) -> Bool {
        switch message {
        case .timingClock, .start, .continuePlayback, .stop, .songPosition: return true
        default: return false
        }
    }

    // MARK: - Sintetizzatore (facoltativo)

    private func makeSynth() -> AnyObject? {
        #if canImport(AVFoundation)
        return try? BuiltInSynth()
        #else
        return nil
        #endif
    }

    private func sendToSynth(_ message: MIDIMessage, at time: UInt64) {
        #if canImport(AVFoundation)
        (synth as? BuiltInSynth)?.send(message, atNanos: time)
        #endif
    }

    private func stopSynth(_ object: AnyObject) {
        #if canImport(AVFoundation)
        (object as? BuiltInSynth)?.stop()
        #endif
    }
}
#endif
