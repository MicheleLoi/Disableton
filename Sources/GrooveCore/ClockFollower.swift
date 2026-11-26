import Foundation

/// Segue il MIDI clock esterno (24 impulsi per quarto) e i comandi di trasporto.
///
/// Stima tempo e fase con una regressione lineare sugli ultimi impulsi ricevuti: in questo modo
/// il jitter dei singoli impulsi (USB/MIDI) viene smussato, e le posizioni intermedie tra due
/// impulsi si possono calcolare con precisione senza quantizzare le sfumature dei groove.
///
/// I tempi sono in nanosecondi su un orologio monotono (su macOS: host time convertito).
public final class ClockFollower {
    public static let clocksPerQuarter = 24
    /// Tick di groove per impulso di clock (960 / 24 = 40).
    public static let songTicksPerClock = Groove.ppq / clocksPerQuarter

    public struct Configuration: Sendable {
        /// Numero di impulsi usati per la stima (24 = una nota da un quarto).
        public var windowSize: Int = 24
        /// Tempo ipotizzato prima di aver ricevuto almeno due impulsi.
        public var defaultBPM: Double = 120
        /// Recupera gli impulsi persi (buchi di almeno 1,75 intervalli). Disattivato per default:
        /// un rallentamento brusco del tempo (es. dimezzamento) verrebbe scambiato per impulsi persi.
        public var recoverMissedClocks = false
        /// Buchi più lunghi di questo azzerano la stima invece di essere recuperati.
        public var maxGapRecoveryNs: UInt64 = 2_000_000_000
        public init() {}
    }

    private struct Fit {
        var anchorCounter: Int
        var anchorTime: UInt64
        /// Scostamento della retta stimata rispetto a `anchorTime`, in ns.
        var anchorOffset: Double
        var nsPerClock: Double
    }

    public var configuration: Configuration
    public private(set) var isRunning = false
    /// Posizione (in impulsi di clock) da cui riprenderà un Continue.
    public private(set) var resumeClock = 0

    private var counter = 0
    private var window: [(counter: Int, time: UInt64)] = []
    private var songBase: Int?
    private var pendingStartClock: Int?
    private var fit: Fit?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Ingressi

    public func start() {
        resumeClock = 0
        pendingStartClock = 0
        songBase = nil
        isRunning = true
    }

    /// Avvio senza messaggio Start (comando "Avvia" con il clock già in corso): la posizione 0
    /// è l'impulso più vicino all'istante indicato, già ricevuto o il prossimo.
    public func startNow(at time: UInt64) {
        resumeClock = 0
        isRunning = true
        if let f = fit, let last = window.last {
            let dt = Double(Int64(bitPattern: time &- f.anchorTime)) - f.anchorOffset
            let position = Double(f.anchorCounter) + dt / f.nsPerClock
            if position - Double(last.counter) < 0.5 {
                songBase = last.counter
                pendingStartClock = nil
                return
            }
        }
        songBase = nil
        pendingStartClock = 0
    }

    public func continuePlayback() {
        pendingStartClock = resumeClock
        songBase = nil
        isRunning = true
    }

    public func stop() {
        if let base = songBase {
            resumeClock = counter - base + 1
        }
        songBase = nil
        pendingStartClock = nil
        isRunning = false
    }

    /// Song Position Pointer (in sedicesimi = 6 impulsi).
    public func setSongPosition(sixteenths: Int) {
        resumeClock = max(0, sixteenths) * 6
    }

    public func clock(at time: UInt64) {
        if let last = window.last {
            let gap = time > last.time ? time - last.time : 0
            let interval = fit?.nsPerClock ?? 60_000_000_000.0 / (configuration.defaultBPM * Double(ClockFollower.clocksPerQuarter))
            if Double(gap) > 1.75 * interval {
                if configuration.recoverMissedClocks, isRunning, songBase != nil, gap <= configuration.maxGapRecoveryNs {
                    // Impulsi persi: si recuperano per non far restare indietro la posizione.
                    let missed = Int((Double(gap) / interval).rounded()) - 1
                    if missed > 0 { counter += missed }
                } else {
                    // Pausa del clock (es. Stop senza clock a trasporto fermo) o salto di tempo:
                    // la stima riparte dai nuovi impulsi, mantenendo l'ultimo tempo noto.
                    window.removeAll()
                }
            }
        }
        counter += 1
        window.append((counter: counter, time: time))
        if window.count > max(2, configuration.windowSize) {
            window.removeFirst(window.count - max(2, configuration.windowSize))
        }
        if let pending = pendingStartClock {
            // Il primo impulso dopo Start/Continue corrisponde alla posizione richiesta.
            songBase = counter - pending
            pendingStartClock = nil
        }
        refit()
    }

    // MARK: - Uscite

    public var tempoBPM: Double? {
        guard let f = fit else { return nil }
        return 60_000_000_000.0 / (f.nsPerClock * Double(ClockFollower.clocksPerQuarter))
    }

    /// Posizione (in tick di groove) dell'ultimo impulso ricevuto, se il trasporto è avviato.
    public var lastSongTick: Int? {
        guard let base = songBase else { return nil }
        return (counter - base) * ClockFollower.songTicksPerClock
    }

    /// Istante previsto per una posizione del brano (in tick di groove).
    public func time(forSongTick tick: Double) -> UInt64? {
        guard let base = songBase, let f = fit else { return nil }
        let clock = Double(base) + tick / Double(ClockFollower.songTicksPerClock)
        let dt = f.anchorOffset + (clock - Double(f.anchorCounter)) * f.nsPerClock
        if dt >= 0 { return f.anchorTime &+ UInt64(dt) }
        let back = UInt64(-dt)
        return back < f.anchorTime ? f.anchorTime - back : 0
    }

    /// Posizione del brano (in tick di groove) prevista per un istante.
    public func songTick(atTime time: UInt64) -> Double? {
        guard let base = songBase, let f = fit else { return nil }
        let dt = Double(Int64(bitPattern: time &- f.anchorTime)) - f.anchorOffset
        let clock = Double(f.anchorCounter) + dt / f.nsPerClock
        return (clock - Double(base)) * Double(ClockFollower.songTicksPerClock)
    }

    // MARK: - Stima

    private func refit() {
        guard let last = window.last else { return }
        let fallback = fit?.nsPerClock ?? 60_000_000_000.0 / (configuration.defaultBPM * Double(ClockFollower.clocksPerQuarter))
        guard window.count >= 2 else {
            fit = Fit(anchorCounter: last.counter, anchorTime: last.time, anchorOffset: 0, nsPerClock: fallback)
            return
        }
        // Regressione: tempo = a + b * contatore, coordinate relative all'ultimo punto.
        let n = Double(window.count)
        var sx = 0.0, sy = 0.0
        for p in window {
            sx += Double(p.counter - last.counter)
            sy += Double(Int64(bitPattern: p.time &- last.time))
        }
        let mx = sx / n
        let my = sy / n
        var sxy = 0.0, sxx = 0.0
        for p in window {
            let dx = Double(p.counter - last.counter) - mx
            let dy = Double(Int64(bitPattern: p.time &- last.time)) - my
            sxy += dx * dy
            sxx += dx * dx
        }
        var slope = sxx > 0 ? sxy / sxx : fallback
        if !(slope > 0) || !slope.isFinite { slope = fallback }
        let intercept = my - slope * mx
        fit = Fit(anchorCounter: last.counter, anchorTime: last.time, anchorOffset: intercept, nsPerClock: slope)
    }
}
