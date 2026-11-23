import Foundation

/// Messaggio MIDI 1.0. I canali sono 0-based (0 = canale 1, 15 = canale 16).
public enum MIDIMessage: Equatable, Hashable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case polyPressure(channel: UInt8, note: UInt8, pressure: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)
    case channelPressure(channel: UInt8, pressure: UInt8)
    case pitchBend(channel: UInt8, value: UInt16)
    /// Song Position Pointer, in "MIDI beat" (sedicesimi).
    case songPosition(beats: UInt16)
    case songSelect(UInt8)
    case timingClock
    case start
    case continuePlayback
    case stop
    case activeSensing
    case systemReset
    case unknown([UInt8])

    /// Numero di byte di dati che seguono lo status.
    public static func dataLength(forStatus status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0: return 2
        case 0xC0, 0xD0: return 1
        default:
            switch status {
            case 0xF2: return 2
            case 0xF1, 0xF3: return 1
            default: return 0
            }
        }
    }

    /// Interpreta un messaggio completo (status + dati). Note On con velocity 0 diventa Note Off.
    public init?(bytes: [UInt8]) {
        guard let status = bytes.first, status & 0x80 != 0 else { return nil }
        func data(_ i: Int) -> UInt8? { i < bytes.count ? bytes[i] & 0x7F : nil }
        let ch = status & 0x0F
        switch status & 0xF0 {
        case 0x80:
            guard let n = data(1), let v = data(2) else { return nil }
            self = .noteOff(channel: ch, note: n, velocity: v)
        case 0x90:
            guard let n = data(1), let v = data(2) else { return nil }
            self = v == 0 ? .noteOff(channel: ch, note: n, velocity: 0) : .noteOn(channel: ch, note: n, velocity: v)
        case 0xA0:
            guard let n = data(1), let v = data(2) else { return nil }
            self = .polyPressure(channel: ch, note: n, pressure: v)
        case 0xB0:
            guard let c = data(1), let v = data(2) else { return nil }
            self = .controlChange(channel: ch, controller: c, value: v)
        case 0xC0:
            guard let p = data(1) else { return nil }
            self = .programChange(channel: ch, program: p)
        case 0xD0:
            guard let p = data(1) else { return nil }
            self = .channelPressure(channel: ch, pressure: p)
        case 0xE0:
            guard let lsb = data(1), let msb = data(2) else { return nil }
            self = .pitchBend(channel: ch, value: (UInt16(msb) << 7) | UInt16(lsb))
        default:
            switch status {
            case 0xF2:
                guard let lsb = data(1), let msb = data(2) else { return nil }
                self = .songPosition(beats: (UInt16(msb) << 7) | UInt16(lsb))
            case 0xF3:
                guard let s = data(1) else { return nil }
                self = .songSelect(s)
            case 0xF8: self = .timingClock
            case 0xFA: self = .start
            case 0xFB: self = .continuePlayback
            case 0xFC: self = .stop
            case 0xFE: self = .activeSensing
            case 0xFF: self = .systemReset
            default: self = .unknown(bytes)
            }
        }
    }

    public var bytes: [UInt8] {
        switch self {
        case let .noteOn(ch, n, v): return [0x90 | (ch & 0x0F), n & 0x7F, v & 0x7F]
        case let .noteOff(ch, n, v): return [0x80 | (ch & 0x0F), n & 0x7F, v & 0x7F]
        case let .polyPressure(ch, n, p): return [0xA0 | (ch & 0x0F), n & 0x7F, p & 0x7F]
        case let .controlChange(ch, c, v): return [0xB0 | (ch & 0x0F), c & 0x7F, v & 0x7F]
        case let .programChange(ch, p): return [0xC0 | (ch & 0x0F), p & 0x7F]
        case let .channelPressure(ch, p): return [0xD0 | (ch & 0x0F), p & 0x7F]
        case let .pitchBend(ch, v): return [0xE0 | (ch & 0x0F), UInt8(v & 0x7F), UInt8((v >> 7) & 0x7F)]
        case let .songPosition(b): return [0xF2, UInt8(b & 0x7F), UInt8((b >> 7) & 0x7F)]
        case let .songSelect(s): return [0xF3, s & 0x7F]
        case .timingClock: return [0xF8]
        case .start: return [0xFA]
        case .continuePlayback: return [0xFB]
        case .stop: return [0xFC]
        case .activeSensing: return [0xFE]
        case .systemReset: return [0xFF]
        case let .unknown(b): return b
        }
    }

    /// Messaggi di sistema real-time (clock e trasporto).
    public var isRealTime: Bool {
        switch self {
        case .timingClock, .start, .continuePlayback, .stop, .activeSensing, .systemReset: return true
        default: return false
        }
    }
}

extension MIDIMessage: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .noteOn(ch, n, v): return "NoteOn   ch\(ch + 1) \(NoteName.korg(n)) (\(n)) vel \(v)"
        case let .noteOff(ch, n, _): return "NoteOff  ch\(ch + 1) \(NoteName.korg(n)) (\(n))"
        case let .polyPressure(ch, n, p): return "PolyAT   ch\(ch + 1) \(n) \(p)"
        case let .controlChange(ch, c, v): return "CC       ch\(ch + 1) #\(c) = \(v)"
        case let .programChange(ch, p): return "Program  ch\(ch + 1) \(p)"
        case let .channelPressure(ch, p): return "ChanAT   ch\(ch + 1) \(p)"
        case let .pitchBend(ch, v): return "PitchB   ch\(ch + 1) \(v)"
        case let .songPosition(b): return "SongPos  \(b) sedicesimi (battuta \(Int(b) / 16 + 1) in 4/4)"
        case let .songSelect(s): return "SongSel  \(s)"
        case .timingClock: return "Clock"
        case .start: return "Start"
        case .continuePlayback: return "Continue"
        case .stop: return "Stop"
        case .activeSensing: return "ActiveSensing"
        case .systemReset: return "Reset"
        case let .unknown(b): return "Altro    " + b.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
    }
}

public enum NoteName {
    private static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    /// Convenzione Korg/Roland: nota 60 = C4.
    public static func korg(_ note: UInt8) -> String {
        "\(names[Int(note) % 12])\(Int(note) / 12 - 1)"
    }
}

/// Conversione da/verso Universal MIDI Packet (UMP), formato usato da CoreMIDI moderno.
/// Gestisce solo i messaggi MIDI 1.0 a 32 bit (tipo 1 = sistema, tipo 2 = canale).
public enum UMP {
    public static func wordCount(forMessageType mt: UInt32) -> Int {
        switch mt {
        case 0x0, 0x1, 0x2, 0x6, 0x7: return 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: return 2
        case 0xB, 0xC: return 3
        default: return 4
        }
    }

    public static func messages(from words: [UInt32]) -> [MIDIMessage] {
        var result: [MIDIMessage] = []
        var i = 0
        while i < words.count {
            let w = words[i]
            let mt = w >> 28
            if mt == 0x1 || mt == 0x2 {
                let status = UInt8((w >> 16) & 0xFF)
                let len = MIDIMessage.dataLength(forStatus: status)
                var bytes = [status]
                if len >= 1 { bytes.append(UInt8((w >> 8) & 0x7F)) }
                if len >= 2 { bytes.append(UInt8(w & 0x7F)) }
                if let m = MIDIMessage(bytes: bytes) { result.append(m) }
            }
            i += wordCount(forMessageType: mt)
        }
        return result
    }

    /// Parola UMP a 32 bit per un messaggio di canale o di sistema (non SysEx).
    public static func word(for message: MIDIMessage, group: UInt8 = 0) -> UInt32? {
        let b = message.bytes
        guard let status = b.first, status != 0xF0, status != 0xF7 else { return nil }
        let mt: UInt32 = status >= 0xF0 ? 0x1 : 0x2
        let d1: UInt32 = b.count > 1 ? UInt32(b[1]) : 0
        let d2: UInt32 = b.count > 2 ? UInt32(b[2]) : 0
        return (mt << 28) | (UInt32(group & 0x0F) << 24) | (UInt32(status) << 16) | (d1 << 8) | d2
    }
}
