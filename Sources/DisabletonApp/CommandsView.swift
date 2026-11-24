#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// Comandi: la zona di controllo del Krome disegnata come tastiera (C2–B3, canale 16),
/// gli altri controlli (SW1, SW2, pedale, Program Change) e il MIDI Learn.
struct CommandsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Zona comandi del Krome · canale 16 · C2–B3").font(.headline)
                        Spacer()
                        Text("Clic su un tasto per vederlo o cambiarlo").font(.caption).foregroundColor(.secondary)
                    }
                    KromeKeyboard()
                        .frame(height: 230)
                    KeyLegend()
                    Divider()
                    OtherControls()
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            KeyInspector()
                .frame(width: 300)
                .padding(.vertical, 20)
                .padding(.trailing, 20)
        }
    }
}

enum KeyState {
    case playing, pending, slot, emptySlot, command, panic, unassigned
}

struct KromeKeyboard: View {
    @EnvironmentObject var model: AppModel
    static let notes = Array(36...59)

    var body: some View {
        GeometryReader { geo in
            let whites = KromeKeyboard.notes.filter { !KromeKeyboard.isBlack($0) }
            let whiteWidth = geo.size.width / CGFloat(whites.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { note in
                        KeyButton(note: note, black: false)
                            .frame(width: whiteWidth, height: geo.size.height)
                    }
                }
                ForEach(KromeKeyboard.notes.filter { KromeKeyboard.isBlack($0) }, id: \.self) { note in
                    let whitesBefore = whites.filter { $0 < note }.count
                    KeyButton(note: note, black: true)
                        .frame(width: whiteWidth * 0.64, height: geo.size.height * 0.6)
                        .offset(x: whiteWidth * CGFloat(whitesBefore) - whiteWidth * 0.32)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.6)))
    }

    static func isBlack(_ note: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(note % 12)
    }
}

struct KeyButton: View {
    @EnvironmentObject var model: AppModel
    let note: Int
    let black: Bool

    var body: some View {
        let action = model.action(forNote: note)
        let state = keyState(action)
        let selected = model.selectedKey == note
        Button {
            model.selectedKey = note
        } label: {
            VStack(spacing: 2) {
                Spacer()
                Text(shortLabel(action))
                    .font(.system(size: black ? 11 : 13, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(NoteName.korg(UInt8(note)))
                    .font(.system(size: 9))
                    .opacity(0.8)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(textColor(state))
            .background(fill(state))
            .overlay(
                Rectangle().stroke(selected ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: selected ? 3 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(NoteName.korg(UInt8(note))), nota \(note): \(action?.label ?? "nessuna azione")")
    }

    private func keyState(_ action: ControlAction?) -> KeyState {
        guard let action else { return .unassigned }
        switch action {
        case let .triggerSlot(i):
            let status = model.snapshot?.status
            if status?.playingSlot == i { return .playing }
            if status?.pendingSlot == i { return .pending }
            let current = status?.songIndex ?? model.selectedSongIndex
            if let s = current, model.library.songs.indices.contains(s), model.library.songs[s].slots.indices.contains(i) {
                return .slot
            }
            return .emptySlot
        case .panic:
            return .panic
        default:
            return .command
        }
    }

    private func fill(_ state: KeyState) -> Color {
        switch state {
        case .playing: return Color(red: 0.08, green: 0.5, blue: 0.24)
        case .pending: return Color(red: 0.99, green: 0.92, blue: 0.84)
        case .slot: return black ? Color(red: 0.12, green: 0.23, blue: 0.54) : Color(red: 0.89, green: 0.92, blue: 0.99)
        case .emptySlot: return black ? Color(white: 0.2) : Color(white: 0.96)
        case .command: return black ? Color(red: 0.3, green: 0.11, blue: 0.58) : Color(red: 0.9, green: 0.88, blue: 0.97)
        case .panic: return Color(red: 0.99, green: 0.89, blue: 0.89)
        case .unassigned: return black ? Color(white: 0.11) : .white
        }
    }

    private func textColor(_ state: KeyState) -> Color {
        switch state {
        case .playing: return .white
        case .pending, .panic: return Color(red: 0.35, green: 0.15, blue: 0.05)
        case .emptySlot: return black ? Color(white: 0.75) : Color(white: 0.45)
        case .slot, .command: return black ? .white : Color(white: 0.1)
        case .unassigned: return black ? Color(white: 0.6) : Color(white: 0.4)
        }
    }

    private func shortLabel(_ action: ControlAction?) -> String {
        guard let action else { return "" }
        switch action {
        case let .triggerSlot(i): return "\(i + 1)"
        case .fill: return "FILL"
        case .nextSlot: return "GR▶"
        case .previousSlot: return "◀GR"
        case .nextSong: return "B▶"
        case .previousSong: return "◀B"
        case .stopAtBarEnd: return "STOP"
        case .panic: return "PANIC"
        case let .selectSong(i): return "B\(i + 1)"
        case .selectSongFromProgram: return "PC"
        }
    }
}

struct KeyLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(Color(red: 0.08, green: 0.5, blue: 0.24), "suona ora")
            item(Color(red: 0.99, green: 0.92, blue: 0.84), "in coda")
            item(Color(red: 0.89, green: 0.92, blue: 0.99), "groove del brano")
            item(Color(red: 0.9, green: 0.88, blue: 0.97), "comando")
            item(Color(white: 0.96), "slot vuoto in questo brano")
        }
        .font(.caption)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.6)))
            Text(text)
        }
    }
}

/// SW1, SW2, pedale, Program Change e ogni comando che non è una nota sul canale 16.
struct OtherControls: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let entries = model.library.controlMap.bindings.enumerated().filter { _, b in
            !(b.kind == .note && b.channel == 16)
        }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Altri controlli").font(.headline)
                Spacer()
                Menu {
                    ForEach(ControlAction.menuChoices, id: \.self) { action in
                        Button(action.label) { model.learnNew(action: action) }
                    }
                } label: {
                    Label("Aggiungi comando", systemImage: "plus")
                }
                .frame(width: 190)
                Button("Ripristina predefiniti") { model.resetBindings() }
            }
            if case let .new(action)? = model.learningTarget {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Premi sul Krome il controllo per \"\(action.label)\"…")
                    Spacer()
                    Button("Annulla") { model.cancelLearn() }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.2)))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(entries, id: \.offset) { index, binding in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(binding.triggerLabel).font(.caption).foregroundColor(.secondary)
                        Text(binding.action.label).font(.headline)
                        HStack {
                            if model.learningTarget == .existing(index) {
                                Text("Premi il controllo…").font(.caption).foregroundColor(.orange)
                                Button("Annulla") { model.cancelLearn() }
                            } else {
                                Button("Impara") { model.learn(bindingAt: index) }
                                    .disabled(model.learningTarget != nil)
                            }
                            Spacer()
                            Button(role: .destructive) { model.removeBinding(at: index) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Elimina comando")
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.35)))
                }
            }
            Text("SW1, SW2 e il pedale del Krome vanno impostati in modo da inviare un controller (es. CC 80, 81, 82); poi usa \"Impara\".")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Dettagli del tasto selezionato.
struct KeyInspector: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let note = model.selectedKey ?? 36
        let action = model.action(forNote: note)
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasto selezionato").font(.caption).foregroundColor(.secondary)
            Text("\(NoteName.korg(UInt8(note))) · nota \(note)").font(.title2.weight(.bold))
            Text("Canale 16 → " + (action?.label ?? "nessuna azione"))

            if case let .triggerSlot(i)? = action {
                let songIndex = model.snapshot?.status.songIndex ?? model.selectedSongIndex
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nel brano corrente").font(.caption).foregroundColor(.secondary)
                    if let s = songIndex, model.library.songs.indices.contains(s), model.library.songs[s].slots.indices.contains(i) {
                        let slot = model.library.songs[s].slots[i]
                        Text(model.displayName(of: slot)).font(.headline)
                        Text(slot.mode.label + " · " + slot.quantize.label.lowercased()).font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("Nessun groove in questa posizione").foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
            }

            Picker("Azione del tasto", selection: Binding<ControlAction?>(
                get: { model.action(forNote: note) },
                set: { model.setAction($0, forNote: note) })) {
                Text("Nessuna").tag(ControlAction?.none)
                ForEach(ControlAction.menuChoices, id: \.self) { a in
                    Text(a.label).tag(ControlAction?.some(a))
                }
            }

            if let action {
                if model.learningTarget == .new(action) {
                    Text("Premi un tasto o un controllo sul Krome…").foregroundColor(.orange)
                    Button("Annulla") { model.cancelLearn() }
                } else {
                    Button("Impara: assegna \"\(action.label)\" al prossimo tasto premuto") {
                        model.learnNew(action: action)
                    }
                    .disabled(model.learningTarget != nil)
                }
            }

            Spacer()
            Text("Ultimo messaggio: " + (model.snapshot?.lastCommand ?? "–"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35)))
    }
}
#endif
