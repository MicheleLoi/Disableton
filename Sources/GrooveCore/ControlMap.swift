import Foundation

/// Azione eseguibile da un comando MIDI del Krome.
/// In JSON è una stringa, con numeri 1-based: "triggerSlot:1", "selectSong:3", "fill", ...
public enum ControlAction: Hashable, Sendable, Codable, CustomStringConvertible {
    /// Brano (0-based).
    case selectSong(Int)
    /// Program Change n → brano n (0-based: PC 0 = brano 1).
    case selectSongFromProgram
    case nextSong
    case previousSong
    /// Slot del brano corrente (0-based).
    case triggerSlot(Int)
    case fill
    case nextSlot
    case previousSlot
    case stopAtBarEnd
    case panic
    /// Fa partire la batteria al tempo del clock del Krome, senza messaggio Start (es. in Combi).
    /// Ignorato se la batteria sta già suonando.
    case start
    /// Intensità della batteria dal vivo, comandata in continuo da un controller (manopola):
    /// 0 → 50%, 64 → 100%, 127 → 200% della forza dei colpi.
    case intensity

    /// Fattore di intensità per il valore di un controller (0…127).
    public static func intensityFactor(controllerValue value: UInt8) -> Double {
        0.5 * pow(4, Double(min(value, 127)) / 127)
    }

    public init?(string: String) {
        let parts = string.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let name = parts.first else { return nil }
        let number = parts.count > 1 ? Int(parts[1]) : nil
        switch name {
        case "selectSong":
            guard let n = number, n >= 1 else { return nil }
            self = .selectSong(n - 1)
        case "selectSongFromProgram": self = .selectSongFromProgram
        case "nextSong": self = .nextSong
        case "previousSong": self = .previousSong
        case "triggerSlot":
            guard let n = number, n >= 1 else { return nil }
            self = .triggerSlot(n - 1)
        case "fill": self = .fill
        case "nextSlot": self = .nextSlot
        case "previousSlot": self = .previousSlot
        case "stopAtBarEnd": self = .stopAtBarEnd
        case "panic": self = .panic
        case "start": self = .start
        case "intensity": self = .intensity
        default: return nil
        }
    }

    public var description: String {
        switch self {
        case let .selectSong(i): return "selectSong:\(i + 1)"
        case .selectSongFromProgram: return "selectSongFromProgram"
        case .nextSong: return "nextSong"
        case .previousSong: return "previousSong"
        case let .triggerSlot(i): return "triggerSlot:\(i + 1)"
        case .fill: return "fill"
        case .nextSlot: return "nextSlot"
        case .previousSlot: return "previousSlot"
        case .stopAtBarEnd: return "stopAtBarEnd"
        case .panic: return "panic"
        case .start: return "start"
        case .intensity: return "intensity"
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let action = ControlAction(string: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Azione sconosciuta: \(s)")
        }
        self = action
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// Associazione tra un messaggio MIDI in ingresso e un'azione.
public struct ControlBinding: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case note
        case controlChange = "cc"
        case programChange = "pc"
    }

    public var kind: Kind
    /// Canale 1-16.
    public var channel: Int
    /// Nota o numero di controller; nil = qualsiasi.
    public var number: Int?
    public var action: ControlAction

    public init(kind: Kind, channel: Int, number: Int?, action: ControlAction) {
        self.kind = kind
        self.channel = channel
        self.number = number
        self.action = action
    }

    /// Crea un'associazione dal messaggio ricevuto (MIDI Learn).
    public static func learn(from message: MIDIMessage, action: ControlAction) -> ControlBinding? {
        switch message {
        case let .noteOn(ch, note, _): return ControlBinding(kind: .note, channel: Int(ch) + 1, number: Int(note), action: action)
        case let .controlChange(ch, cc, _): return ControlBinding(kind: .controlChange, channel: Int(ch) + 1, number: Int(cc), action: action)
        case let .programChange(ch, p):
            // "Brano dal Program Change" vale per qualsiasi numero: si impara solo il canale.
            let number: Int? = action == .selectSongFromProgram ? nil : Int(p)
            return ControlBinding(kind: .programChange, channel: Int(ch) + 1, number: number, action: action)
        default: return nil
        }
    }
}

/// Mappa dei comandi. Note On e controller ≥ 64 attivano; i rilasci sono ignorati.
public struct ControlMap: Codable, Equatable, Sendable {
    public var bindings: [ControlBinding]

    public init(bindings: [ControlBinding]) {
        self.bindings = bindings
    }

    /// Controller associato all'intensità (comando continuo, attivo con qualsiasi valore).
    public func isIntensityController(_ message: MIDIMessage) -> Bool {
        guard case let .controlChange(channel, controller, _) = message else { return false }
        return match(.controlChange, channel: channel, number: controller) == .intensity
    }

    public func action(for message: MIDIMessage) -> ControlAction? {
        switch message {
        case let .noteOn(channel, note, velocity) where velocity > 0:
            return match(.note, channel: channel, number: note)
        case let .controlChange(channel, controller, value) where value >= 64:
            return match(.controlChange, channel: channel, number: controller)
        case let .programChange(channel, program):
            guard let action = match(.programChange, channel: channel, number: program) else { return nil }
            if case .selectSongFromProgram = action { return .selectSong(Int(program)) }
            return action
        default:
            return nil
        }
    }

    private func match(_ kind: ControlBinding.Kind, channel: UInt8, number: UInt8) -> ControlAction? {
        // Le associazioni con numero preciso hanno la precedenza su quelle generiche.
        let candidates = bindings.filter { $0.kind == kind && $0.channel == Int(channel) + 1 }
        if let exact = candidates.first(where: { $0.number == Int(number) }) { return exact.action }
        return candidates.first(where: { $0.number == nil })?.action
    }

    /// Mappa predefinita sul canale 16 (note con nomi Korg: 24 = C1, 36 = C2).
    ///
    /// - Program Change n → brano n+1
    /// - note 24…35 (C1…B1) → slot 1…12
    /// - ottava dei comandi, da C2: 36 (C2) avvia, 37 (C#2) groove precedente, 38 (D2) fill,
    ///   39 (D#2) groove successivo, 40 (E2) silenzio a fine battuta, 41 (F2) panic,
    ///   42 (F#2) brano precedente, 44 (G#2) brano successivo
    /// - nessun controller predefinito: SW1, SW2 e pedale restano liberi (si assegnano con Impara)
    public static let `default`: ControlMap = {
        let ch = 16
        var b: [ControlBinding] = [
            ControlBinding(kind: .programChange, channel: ch, number: nil, action: .selectSongFromProgram),
        ]
        for i in 0..<12 {
            b.append(ControlBinding(kind: .note, channel: ch, number: 24 + i, action: .triggerSlot(i)))
        }
        b += [
            ControlBinding(kind: .note, channel: ch, number: 36, action: .start),
            ControlBinding(kind: .note, channel: ch, number: 37, action: .previousSlot),
            ControlBinding(kind: .note, channel: ch, number: 38, action: .fill),
            ControlBinding(kind: .note, channel: ch, number: 39, action: .nextSlot),
            ControlBinding(kind: .note, channel: ch, number: 40, action: .stopAtBarEnd),
            ControlBinding(kind: .note, channel: ch, number: 41, action: .panic),
            ControlBinding(kind: .note, channel: ch, number: 42, action: .previousSong),
            ControlBinding(kind: .note, channel: ch, number: 44, action: .nextSong),
        ]
        return ControlMap(bindings: b)
    }()
}
