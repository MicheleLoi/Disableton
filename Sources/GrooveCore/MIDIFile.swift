import Foundation

public enum MIDIFileError: Error, Equatable, CustomStringConvertible {
    case notAMIDIFile
    case truncated
    case smpteDivisionUnsupported
    case runningStatusWithoutStatus(offset: Int)
    case invalidStatus(UInt8, offset: Int)

    public var description: String {
        switch self {
        case .notAMIDIFile: return "il file non è un file MIDI standard"
        case .truncated: return "il file MIDI è troncato"
        case .smpteDivisionUnsupported: return "file MIDI con divisione SMPTE non supportato"
        case let .runningStatusWithoutStatus(o): return "running status senza status precedente (offset \(o))"
        case let .invalidStatus(s, o): return String(format: "status non valido 0x%02X (offset %d)", s, o)
        }
    }
}

/// Lettore di Standard MIDI File (formato 0 e 1).
public struct MIDIFile: Sendable {
    public enum EventKind: Equatable, Sendable {
        case channel(MIDIMessage)
        case meta(type: UInt8, data: [UInt8])
        case sysex([UInt8])
    }

    public struct Event: Equatable, Sendable {
        public var tick: Int
        public var kind: EventKind
        public init(tick: Int, kind: EventKind) {
            self.tick = tick
            self.kind = kind
        }
    }

    public var format: Int
    public var ticksPerQuarter: Int
    public var tracks: [[Event]]

    public init(contentsOf url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    public init(data: Data) throws {
        try self.init(bytes: [UInt8](data))
    }

    public init(bytes: [UInt8]) throws {
        var r = ByteReader(bytes)
        guard r.remaining >= 14, try r.readASCII(4) == "MThd" else { throw MIDIFileError.notAMIDIFile }
        let headerLength = Int(try r.readUInt32())
        guard headerLength >= 6 else { throw MIDIFileError.notAMIDIFile }
        let format = Int(try r.readUInt16())
        let trackCount = Int(try r.readUInt16())
        let division = try r.readUInt16()
        guard division & 0x8000 == 0 else { throw MIDIFileError.smpteDivisionUnsupported }
        guard division > 0 else { throw MIDIFileError.notAMIDIFile }
        try r.skip(headerLength - 6)

        var tracks: [[Event]] = []
        while r.remaining >= 8 && tracks.count < trackCount {
            let id = try r.readASCII(4)
            let length = Int(try r.readUInt32())
            // Alcuni programmi scrivono lunghezze errate nell'ultima traccia: si tollera.
            let chunk = try r.readBytes(min(length, r.remaining))
            if id == "MTrk" {
                tracks.append(try MIDIFile.parseTrack(chunk))
            }
        }
        self.format = format
        self.ticksPerQuarter = Int(division)
        self.tracks = tracks
    }

    static func parseTrack(_ bytes: [UInt8]) throws -> [Event] {
        var r = ByteReader(bytes)
        var events: [Event] = []
        var tick = 0
        var running: UInt8?
        while !r.isAtEnd {
            tick += try r.readVLQ()
            let offset = r.offset
            var status = try r.peekUInt8()
            if status & 0x80 != 0 {
                _ = try r.readUInt8()
            } else {
                guard let rs = running else { throw MIDIFileError.runningStatusWithoutStatus(offset: offset) }
                status = rs
            }
            switch status {
            case 0xFF:
                let type = try r.readUInt8()
                let length = try r.readVLQ()
                let data = try r.readBytes(length)
                events.append(Event(tick: tick, kind: .meta(type: type, data: data)))
                running = nil
                if type == 0x2F { return events }
            case 0xF0, 0xF7:
                let length = try r.readVLQ()
                let data = try r.readBytes(length)
                events.append(Event(tick: tick, kind: .sysex(data)))
                running = nil
            default:
                guard status < 0xF0 else { throw MIDIFileError.invalidStatus(status, offset: offset) }
                running = status
                var message = [status]
                for _ in 0..<MIDIMessage.dataLength(forStatus: status) {
                    message.append(try r.readUInt8() & 0x7F)
                }
                if let m = MIDIMessage(bytes: message) {
                    events.append(Event(tick: tick, kind: .channel(m)))
                }
            }
        }
        return events
    }

    private func firstMeta(_ type: UInt8) -> [UInt8]? {
        for track in tracks {
            for event in track {
                if case let .meta(t, data) = event.kind, t == type { return data }
            }
        }
        return nil
    }

    /// Primo metro dichiarato nel file.
    public var timeSignature: TimeSignature? {
        guard let d = firstMeta(0x58), d.count >= 2, d[1] < 6 else { return nil }
        return TimeSignature(Int(d[0]), 1 << Int(d[1]))
    }

    /// Primo tempo dichiarato nel file, in BPM.
    public var tempoBPM: Double? {
        guard let d = firstMeta(0x51), d.count >= 3 else { return nil }
        let usPerQuarter = (Int(d[0]) << 16) | (Int(d[1]) << 8) | Int(d[2])
        guard usPerQuarter > 0 else { return nil }
        return 60_000_000.0 / Double(usPerQuarter)
    }

    public var trackNames: [String] {
        tracks.compactMap { track in
            for event in track {
                if case let .meta(t, data) = event.kind, t == 0x03 {
                    return String(decoding: data, as: UTF8.self)
                }
            }
            return nil
        }
    }
}

struct ByteReader {
    let bytes: [UInt8]
    private(set) var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var isAtEnd: Bool { offset >= bytes.count }
    var remaining: Int { bytes.count - offset }

    func peekUInt8() throws -> UInt8 {
        guard offset < bytes.count else { throw MIDIFileError.truncated }
        return bytes[offset]
    }

    mutating func readUInt8() throws -> UInt8 {
        let b = try peekUInt8()
        offset += 1
        return b
    }

    mutating func readUInt16() throws -> UInt16 {
        let hi = try readUInt8()
        let lo = try readUInt8()
        return (UInt16(hi) << 8) | UInt16(lo)
    }

    mutating func readUInt32() throws -> UInt32 {
        var v: UInt32 = 0
        for _ in 0..<4 {
            let b = try readUInt8()
            v = (v << 8) | UInt32(b)
        }
        return v
    }

    mutating func readBytes(_ n: Int) throws -> [UInt8] {
        guard n >= 0, offset + n <= bytes.count else { throw MIDIFileError.truncated }
        defer { offset += n }
        return Array(bytes[offset..<(offset + n)])
    }

    mutating func readASCII(_ n: Int) throws -> String {
        String(decoding: try readBytes(n), as: UTF8.self)
    }

    mutating func skip(_ n: Int) throws {
        guard n >= 0, offset + n <= bytes.count else { throw MIDIFileError.truncated }
        offset += n
    }

    /// Variable Length Quantity (max 4 byte).
    mutating func readVLQ() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            let b = try readUInt8()
            value = (value << 7) | Int(b & 0x7F)
            if b & 0x80 == 0 { return value }
        }
        return value
    }
}
