#if canImport(CoreMIDI)
import CoreMIDI
import Foundation
import GrooveCore

/// Fotografia dello stato, letta periodicamente dall'interfaccia.
public struct LiveSnapshot: Equatable {
    public var status: PlaybackStatus
    public var bar: Int?
    /// Tempo arrotondato a 0,1 BPM.
    public var tempoBPM: Double?
    /// Clock ricevuto negli ultimi 300 ms.
    public var clockReceiving: Bool
    public var lastCommand: String?
    public var previewing: Bool
    public var learning: Bool
}

/// Motore dal vivo completo: ingresso dal Krome, porta virtuale verso EZdrummer, thread di
/// generazione ad alta priorità, ascolto con clock interno e MIDI Learn.
/// Tutti i metodi pubblici sono sicuri da chiamare dal thread principale.
public final class LiveHost {
    public static let virtualPortName = "Disableton"

    /// Nomi delle sorgenti MIDI disponibili (esclusa la porta virtuale di Disableton).
    public static func sourceNames() -> [String] {
        MIDIBackend.sources.map { $0.name }.filter { $0 != virtualPortName }
    }

    private let backend: MIDIBackend
    private let controller: PlaybackController
    private let lock = NSLock()
    private var keepRunning = true
    private var internalClock: ClockGenerator?
    private var previewing = false
    private var learning = false
    private var connected: [String] = []

    public init(songs: [EngineSong], controlMap: ControlMap, outputChannel: Int,
                settings: PlaybackController.Settings, inputFilter: String?) throws {
        let backend = try MIDIBackend(clientName: "Disableton")
        try backend.createVirtualSource(named: LiveHost.virtualPortName)
        self.backend = backend
        self.controller = PlaybackController(songs: songs, controlMap: controlMap,
                                             outputChannel: LiveHost.channelIndex(outputChannel),
                                             settings: settings) { message, time in
            backend.send(message, atNanos: time)
        }
        backend.onMessage = { [weak self] message, time in
            self?.receive(message, at: time)
        }
        connected = try backend.connectSources(matching: inputFilter)
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
        let receiving = controller.lastClockTime.map { now > $0 ? now - $0 < 300_000_000 : true } ?? false
        let bpm = controller.tempoBPM.map { ($0 * 10).rounded() / 10 }
        return LiveSnapshot(status: controller.status,
                            bar: controller.currentBar,
                            tempoBPM: receiving || previewing ? bpm : nil,
                            clockReceiving: receiving,
                            lastCommand: controller.lastCommand?.description,
                            previewing: previewing,
                            learning: learning)
    }

    /// Brani dell'ultima configurazione caricata (nell'ordine della libreria).
    public var songCount: Int {
        lock.lock(); defer { lock.unlock() }
        return controller.songs.count
    }

    // MARK: - Configurazione

    /// Aggiorna brani, comandi e impostazioni. Se il Krome sta suonando, i nuovi brani
    /// diventano effettivi allo Stop, per non disturbare l'esecuzione.
    public func update(songs: [EngineSong], controlMap: ControlMap, outputChannel: Int,
                       settings: PlaybackController.Settings) {
        lock.lock(); defer { lock.unlock() }
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

    // MARK: - Comandi dall'interfaccia

    public func perform(_ action: ControlAction) {
        lock.lock(); defer { lock.unlock() }
        controller.perform(action, now: HostClock.nowNanos())
    }

    public func panic() {
        lock.lock(); defer { lock.unlock() }
        for m in controller.engine.panic() { backend.send(m, atNanos: 0) }
    }

    // MARK: - Ascolto con clock interno

    /// Suona un groove in ripetizione al tempo indicato, senza il Krome.
    /// Durante l'ascolto clock e trasporto del Krome vengono ignorati.
    public func startPreview(groove: Groove, bpm: Double) {
        lock.lock(); defer { lock.unlock() }
        let now = HostClock.nowNanos()
        if controller.engine.isRunning {
            controller.handle(.stop, at: now, now: now)
        }
        controller.engine.load(song: EngineSong(name: "Ascolto: \(groove.name)", timeSignature: groove.timeSignature,
                                                slots: [EngineSlot(name: groove.name, groove: groove)], autoStartSlot: 0))
        previewing = true
        controller.handle(.start, at: now, now: now)
        internalClock = ClockGenerator(bpm: bpm, startTime: now + 5_000_000)
    }

    public func stopPreview() {
        lock.lock(); defer { lock.unlock() }
        guard previewing else { return }
        let now = HostClock.nowNanos()
        internalClock = nil
        controller.handle(.stop, at: now, now: now)
        previewing = false
        if let i = controller.currentSongIndex { controller.selectSong(i) }
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
        let silence = wasRunning ? controller.engine.panic() : []
        lock.unlock()
        for m in silence { backend.send(m, atNanos: 0) }
    }

    private func receive(_ message: MIDIMessage, at time: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if previewing && LiveHost.isTransport(message) { return }
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
            while true {
                guard let host = self, host.step() else { return }
                HostClock.wait(untilNanos: HostClock.nowNanos() + 500_000)
            }
        }
        thread.name = "Disableton groove"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    private static func channelIndex(_ channel: Int) -> UInt8 {
        UInt8(min(max(channel, 1), 16) - 1)
    }

    private static func isTransport(_ message: MIDIMessage) -> Bool {
        switch message {
        case .timingClock, .start, .continuePlayback, .stop, .songPosition: return true
        default: return false
        }
    }
}
#endif
