#if canImport(SwiftUI) && os(macOS)
import GrooveCore

extension SlotMode {
    var label: String {
        switch self {
        case .loop: return "Ripetuto"
        case .oneShotReturn: return "Fill, poi ritorno"
        case .oneShotNext: return "Una volta, poi il successivo"
        case .oneShotStop: return "Finale, poi silenzio"
        }
    }
}

extension Quantize {
    var label: String {
        switch self {
        case .beat: return "Al battito"
        case .bar: return "Alla battuta"
        case .grooveEnd: return "A fine groove"
        }
    }
}

extension ControlAction {
    var label: String {
        switch self {
        case let .selectSong(i): return "Brano \(i + 1)"
        case .selectSongFromProgram: return "Brano dal Program Change"
        case .nextSong: return "Brano successivo"
        case .previousSong: return "Brano precedente"
        case let .triggerSlot(i): return "Groove \(i + 1) del brano"
        case .fill: return "Fill"
        case .nextSlot: return "Groove successivo"
        case .previousSlot: return "Groove precedente"
        case .stopAtBarEnd: return "Silenzio a fine battuta"
        case .panic: return "Panic (spegni tutto)"
        case .start: return "Avvia (al tempo del Krome)"
        }
    }

    /// Azioni proposte nel menu "Aggiungi comando".
    static var menuChoices: [ControlAction] {
        [.start, .fill, .nextSlot, .previousSlot, .stopAtBarEnd, .nextSong, .previousSong,
         .selectSongFromProgram, .panic] + (0..<12).map { ControlAction.triggerSlot($0) }
    }
}

extension ControlBinding {
    var triggerLabel: String {
        let channel = "canale \(self.channel)"
        switch kind {
        case .note:
            guard let n = number else { return "Qualsiasi nota, \(channel)" }
            return "Nota \(NoteName.korg(UInt8(clamping: n))) (\(n)), \(channel)"
        case .controlChange:
            guard let n = number else { return "Qualsiasi controller, \(channel)" }
            return "Controller \(n), \(channel)"
        case .programChange:
            guard let n = number else { return "Program Change (qualsiasi), \(channel)" }
            return "Program Change \(n), \(channel)"
        }
    }
}

extension TimeSignature {
    static let common: [TimeSignature] = [
        TimeSignature(4, 4), TimeSignature(3, 4), TimeSignature(2, 4), TimeSignature(5, 4),
        TimeSignature(6, 8), TimeSignature(7, 8), TimeSignature(9, 8), TimeSignature(12, 8),
    ]

    /// Metri comuni più quello indicato, se non è già presente.
    static func choices(including ts: TimeSignature?) -> [TimeSignature] {
        guard let ts, !common.contains(ts) else { return common }
        return common + [ts]
    }
}

/// Nota predefinita sul Krome per lo slot `index` (canale 16).
func defaultNoteLabel(forSlot index: Int) -> String? {
    guard index < 12 else { return nil }
    let note = 24 + index
    return "\(NoteName.korg(UInt8(note))) (\(note))"
}
#endif
