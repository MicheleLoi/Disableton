import Foundation

/// Metro musicale. In JSON è rappresentato come stringa, es. "4/4", "6/8".
public struct TimeSignature: Hashable, Sendable, CustomStringConvertible, Codable {
    public var beatsPerBar: Int
    public var beatUnit: Int

    public init(_ beatsPerBar: Int, _ beatUnit: Int) {
        self.beatsPerBar = max(1, beatsPerBar)
        self.beatUnit = [1, 2, 4, 8, 16, 32].contains(beatUnit) ? beatUnit : 4
    }

    public static let fourFour = TimeSignature(4, 4)

    public init?(string: String) {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let n = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let d = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              n > 0, [1, 2, 4, 8, 16, 32].contains(d)
        else { return nil }
        self.init(n, d)
    }

    public var description: String { "\(beatsPerBar)/\(beatUnit)" }

    public func ticksPerBeat(ppq: Int) -> Int { ppq * 4 / beatUnit }
    public func ticksPerBar(ppq: Int) -> Int { beatsPerBar * ticksPerBeat(ppq: ppq) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let ts = TimeSignature(string: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Metro non valido: \(s)")
        }
        self = ts
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
