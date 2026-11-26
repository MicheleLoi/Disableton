import Foundation

/// Stato della riproduzione, per l'interfaccia.
public struct PlaybackStatus: Equatable, Sendable {
    public var songIndex: Int?
    public var songName: String?
    public var transportRunning: Bool
    public var playingSlot: Int?
    public var playingSlotName: String?
    public var pendingSlot: Int?
    public var pendingSlotName: String?
    public var stopPending: Bool
    public var armedSlot: Int?
}

/// Collega clock, comandi e motore. Indipendente dalla piattaforma: riceve messaggi con il loro
/// istante (ns) e produce messaggi con l'istante di invio tramite `output`.
///
/// Non è thread-safe: il chiamante deve serializzare `handle` e `process` (es. con un lock).
public final class PlaybackController {
    public struct Settings: Sendable {
        /// Anticipo con cui gli eventi vengono generati e inviati con timestamp futuro.
        public var lookaheadNs: UInt64 = 2_000_000
        /// Anticipo aggiuntivo per compensare la latenza audio di EZdrummer rispetto al Krome.
        public var latencyCompensationNs: UInt64 = 0
        /// Se il clock si interrompe, si continua al tempo corrente per questo numero di tick.
        public var freewheelTicks: Int = Groove.ppq * 4
        public init() {}
    }

    public let follower: ClockFollower
    public let engine: GrooveEngine
    public var settings: Settings
    public var controlMap: ControlMap
    public private(set) var songs: [EngineSong]
    public private(set) var currentSongIndex: Int?

    /// Invio di un messaggio all'istante indicato (ns).
    public var output: (MIDIMessage, UInt64) -> Void
    public var onStatusChange: ((PlaybackStatus) -> Void)?
    /// Messaggi non associati ad alcun comando.
    public var onUnmappedMessage: ((MIDIMessage) -> Void)?
    /// MIDI Learn: se impostato, il prossimo Note On / CC / Program Change viene passato qui
    /// invece di essere eseguito, e la cattura si disattiva.
    public var learnCapture: ((MIDIMessage) -> Void)?

    /// Istante dell'ultimo impulso di clock ricevuto.
    public private(set) var lastClockTime: UInt64?
    /// Ultimo messaggio di comando ricevuto (non clock), per la visualizzazione.
    public private(set) var lastCommand: MIDIMessage?

    private var lastStatus: PlaybackStatus?
    /// Controller attualmente "sopra la metà" (canale << 8 | numero): un comando da controller
    /// scatta solo quando il valore sale oltre 63, così una manopola girata non lo ripete.
    private var controllersAboveHalf = Set<Int>()

    public init(songs: [EngineSong], controlMap: ControlMap = .default, outputChannel: UInt8 = 9,
                settings: Settings = Settings(), output: @escaping (MIDIMessage, UInt64) -> Void) {
        self.follower = ClockFollower()
        self.engine = GrooveEngine(outputChannel: outputChannel)
        self.settings = settings
        self.controlMap = controlMap
        self.songs = songs
        self.output = output
        if !songs.isEmpty { selectSong(0) }
    }

    public var tempoBPM: Double? { follower.tempoBPM }

    /// Battuta corrente (1-based) secondo il metro del brano.
    public var currentBar: Int? {
        guard engine.isRunning, let tick = follower.lastSongTick else { return nil }
        let ts = engine.song?.timeSignature ?? .fourFour
        return tick / ts.ticksPerBar(ppq: Groove.ppq) + 1
    }

    /// Sostituisce i brani. Durante l'esecuzione il brano corrente continua invariato e i nuovi
    /// brani diventano effettivi allo Stop (o alla prossima selezione di un brano).
    public func replaceSongs(_ songs: [EngineSong]) {
        self.songs = songs
        if engine.isRunning {
            reloadPending = true
            if let i = currentSongIndex, !songs.indices.contains(i) { currentSongIndex = songs.isEmpty ? nil : songs.count - 1 }
        } else {
            reloadCurrentSong()
        }
        notifyIfNeeded()
    }

    private var reloadPending = false

    private func reloadCurrentSong() {
        reloadPending = false
        if let i = currentSongIndex, songs.indices.contains(i) {
            selectSong(i)
        } else if !songs.isEmpty {
            selectSong(0)
        } else {
            currentSongIndex = nil
        }
    }

    // MARK: - Ingresso

    public func handle(_ message: MIDIMessage, at time: UInt64, now: UInt64) {
        switch message {
        case .timingClock:
            follower.clock(at: time)
            lastClockTime = time
        case .start:
            follower.start()
            engine.transportStarted(at: 0)
        case .continuePlayback:
            let position = follower.resumeClock * ClockFollower.songTicksPerClock
            follower.continuePlayback()
            engine.transportStarted(at: position)
        case .stop:
            follower.stop()
            for m in engine.transportStopped() { output(m, now) }
            if reloadPending { reloadCurrentSong() }
        case let .songPosition(beats):
            follower.setSongPosition(sixteenths: Int(beats))
        case .activeSensing:
            break
        default:
            if case let .controlChange(channel, controller, value) = message, learnCapture == nil {
                let key = Int(channel) << 8 | Int(controller)
                let wasAbove = controllersAboveHalf.contains(key)
                if value >= 64 { controllersAboveHalf.insert(key) } else { controllersAboveHalf.remove(key) }
                if wasAbove && value >= 64, controlMap.action(for: message) != nil {
                    // Già sopra la metà (manopola che continua a salire): nessun nuovo comando.
                    break
                }
            }
            if let capture = learnCapture, ControlBinding.learn(from: message, action: .fill) != nil {
                learnCapture = nil
                lastCommand = message
                capture(message)
            } else if let action = controlMap.action(for: message) {
                lastCommand = message
                perform(action, now: now)
            } else {
                onUnmappedMessage?(message)
            }
        }
        process(now: now)
    }

    public func perform(_ action: ControlAction, now: UInt64) {
        switch action {
        case let .selectSong(i): selectSong(i)
        case .selectSongFromProgram: break
        case .nextSong: selectSong((currentSongIndex ?? -1) + 1)
        case .previousSong: selectSong((currentSongIndex ?? 1) - 1)
        case let .triggerSlot(i): engine.trigger(slot: i)
        case .fill: engine.triggerFill()
        case .nextSlot: engine.triggerNextSlot()
        case .previousSlot: engine.triggerPreviousSlot()
        case .stopAtBarEnd: engine.stopAtNextBar()
        case .panic: for m in engine.panic() { output(m, now) }
        case .start: startFromCommand(now: now)
        }
        notifyIfNeeded()
    }

    /// Il clock del Krome è arrivato da poco (trasporto avviato o no).
    public func isClockReceiving(now: UInt64) -> Bool {
        guard let last = lastClockTime else { return false }
        return now <= last || now - last < 300_000_000
    }

    /// Comando "Avvia": se la batteria è ferma e il clock arriva, parte subito (posizione 0
    /// sull'impulso più vicino) con il groove di avvio del brano. Il Krome non deve mandare Start.
    /// Se il trasporto è avviato ma la batteria tace (dopo un finale o uno stop), riparte il groove
    /// di avvio alla battuta successiva. Se sta suonando, il comando è ignorato.
    private func startFromCommand(now: UInt64) {
        if engine.isRunning {
            if engine.isSilentWhileRunning { engine.triggerAutoStart() }
            return
        }
        guard isClockReceiving(now: now) else { return }
        follower.startNow(at: now)
        engine.transportStarted(at: 0)
    }

    public func selectSong(_ index: Int) {
        guard songs.indices.contains(index) else { return }
        reloadPending = false
        currentSongIndex = index
        engine.load(song: songs[index])
    }

    // MARK: - Generazione

    /// Da chiamare a intervalli brevi (≤ 1 ms) da un thread ad alta priorità.
    public func process(now: UInt64) {
        defer { notifyIfNeeded() }
        guard engine.isRunning,
              let lastTick = follower.lastSongTick,
              let horizon = follower.songTick(atTime: now &+ settings.lookaheadNs &+ settings.latencyCompensationNs)
        else { return }
        let target = min(Int(horizon.rounded(.down)), lastTick + settings.freewheelTicks)
        guard target > engine.renderedTo else { return }
        for event in engine.render(to: target) {
            guard let t = follower.time(forSongTick: Double(event.tick)) else { continue }
            let sendAt = t > settings.latencyCompensationNs ? t - settings.latencyCompensationNs : 0
            output(event.message, sendAt)
        }
    }

    // MARK: - Stato

    public var status: PlaybackStatus {
        let song = engine.song
        func slotName(_ i: Int?) -> String? {
            guard let i, let song, song.slots.indices.contains(i) else { return nil }
            return song.slots[i].name
        }
        return PlaybackStatus(
            songIndex: currentSongIndex,
            songName: song?.name,
            transportRunning: engine.isRunning,
            playingSlot: engine.playingSlotIndex,
            playingSlotName: slotName(engine.playingSlotIndex),
            pendingSlot: engine.pendingSlotIndex,
            pendingSlotName: slotName(engine.pendingSlotIndex),
            stopPending: engine.isStopPending,
            armedSlot: engine.armedSlotIndex
        )
    }

    private func notifyIfNeeded() {
        guard let callback = onStatusChange else { return }
        let s = status
        if s != lastStatus {
            lastStatus = s
            callback(s)
        }
    }
}
