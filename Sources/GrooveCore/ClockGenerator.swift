import Foundation

/// Clock interno (24 impulsi per quarto) per ascoltare i groove senza la workstation.
public struct ClockGenerator: Sendable {
    public let bpm: Double
    public let startTime: UInt64
    private var emitted = 0

    public init(bpm: Double, startTime: UInt64) {
        self.bpm = min(max(bpm, 20), 300)
        self.startTime = startTime
    }

    public var intervalNs: Double { 60_000_000_000 / (bpm * Double(ClockFollower.clocksPerQuarter)) }

    /// Istante dell'ultimo impulso restituito.
    public var lastTickTime: UInt64? {
        emitted == 0 ? nil : startTime + UInt64((Double(emitted - 1) * intervalNs).rounded())
    }

    /// Stesso clock con un nuovo tempo, che prosegue dall'ultimo impulso senza ricominciare.
    public func retimed(bpm newBPM: Double) -> ClockGenerator {
        var next = ClockGenerator(bpm: newBPM, startTime: startTime)
        if let last = lastTickTime {
            next = ClockGenerator(bpm: newBPM, startTime: last + UInt64(next.intervalNs.rounded()))
        }
        return next
    }

    /// Istanti degli impulsi maturati fino a `now` (inclusi), non ancora restituiti.
    public mutating func ticks(upTo now: UInt64) -> [UInt64] {
        var out: [UInt64] = []
        while true {
            let t = startTime + UInt64((Double(emitted) * intervalNs).rounded())
            guard t <= now else { break }
            out.append(t)
            emitted += 1
        }
        return out
    }
}
