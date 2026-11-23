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
    /// Messaggi non associati ad alcun comando (utile per il MIDI Learn).
    public var onUnmappedMessage: ((MIDIMessage) -> Void)?

    private var lastStatus: PlaybackStatus?

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

    public func replaceSongs(_ songs: [EngineSong]) {
        self.songs = songs
        if let i = currentSongIndex, songs.indices.contains(i) {
            selectSong(i)
        } else if !songs.isEmpty {
            selectSong(0)
        } else {
            currentSongIndex = nil
        }
        notifyIfNeeded()
    }

    // MARK: - Ingresso

    public func handle(_ message: MIDIMessage, at time: UInt64, now: UInt64) {
        switch message {
        case .timingClock:
            follower.clock(at: time)
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
        case let .songPosition(beats):
            follower.setSongPosition(sixteenths: Int(beats))
        case .activeSensing:
            break
        default:
            if let action = controlMap.action(for: message) {
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
        }
        notifyIfNeeded()
    }

    public func selectSong(_ index: Int) {
        guard songs.indices.contains(index) else { return }
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
