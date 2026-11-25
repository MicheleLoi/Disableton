#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// Editor di una mappa delle note: per ogni suono usato dai groove sceglie il tasto dello
/// strumento che lo suona. Si usa senza tastiera: ▶ per ascoltare, griglia per esplorare i tasti.
struct NoteMapEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let mapID: UUID
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Nome della mappa", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                Button("Fine") {
                    model.cancelLearn()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            Text("Per ogni suono dei tuoi groove scegli il tasto dello strumento che lo suona. ▶ fa sentire il risultato; se non trovi un suono, usa la griglia in basso per ascoltare i tasti uno per uno.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    usedNotesSection
                    Divider()
                    explorerSection
                }
                .padding(.vertical, 4)
            }

            HStack {
                Button("Duplica") { model.duplicateNoteMap(mapID); dismiss() }
                Spacer()
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Elimina mappa…", systemImage: "trash")
                }
            }
        }
        .padding(20)
        .confirmationDialog("Eliminare la mappa?", isPresented: $confirmDelete) {
            Button("Elimina", role: .destructive) {
                model.deleteNoteMap(mapID)
                dismiss()
            }
        } message: {
            Text("Le destinazioni che la usavano torneranno al General MIDI. Si può annullare con ⌘Z.")
        }
    }

    // MARK: Suoni usati

    private var usedNotesSection: some View {
        let notes = model.notesUsedByGrooves
        return VStack(alignment: .leading, spacing: 8) {
            Text("Suoni usati dai tuoi groove").font(.headline)
            if notes.isEmpty {
                Text("La libreria non contiene ancora groove.").foregroundColor(.secondary)
            }
            ForEach(notes, id: \.self) { note in
                NoteMapRow(mapID: mapID, note: note)
            }
        }
    }

    // MARK: Esplora i tasti

    private var explorerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Esplora i tasti dello strumento").font(.headline)
            Text("Clicca un tasto per sentire cosa suona lo strumento su quella nota (senza mappa).")
                .font(.caption)
                .foregroundColor(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 6)], spacing: 6) {
                ForEach(Array(24...84), id: \.self) { note in
                    Button {
                        model.playInstrumentNote(note)
                    } label: {
                        VStack(spacing: 1) {
                            Text(NoteName.korg(UInt8(note))).font(.caption.weight(.semibold))
                            Text("\(note)").font(.caption2).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill([1, 3, 6, 8, 10].contains(note % 12) ? Color.gray.opacity(0.25) : Color.gray.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Suona la nota \(note) sullo strumento")
                }
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { model.noteMap(mapID)?.name ?? "" },
                set: { model.renameNoteMap(mapID, to: $0) })
    }
}

struct NoteMapRow: View {
    @EnvironmentObject var model: AppModel
    let mapID: UUID
    let note: Int

    var body: some View {
        let learning = model.learningTarget == .instrumentNote
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(DrumNames.gm(UInt8(note)) ?? "Nota \(note)").fontWeight(.medium)
                Text("\(NoteName.korg(UInt8(note))) (\(note)) nei groove").font(.caption).foregroundColor(.secondary)
            }
            .frame(width: 190, alignment: .leading)
            Image(systemName: "arrow.right").foregroundColor(.secondary)
            Picker("Tasto dello strumento", selection: targetBinding) {
                Text("Non suonare").tag(Int?.none)
                ForEach(0...127, id: \.self) { n in
                    Text("\(NoteName.korg(UInt8(n))) (\(n))").tag(Int?.some(n))
                }
            }
            .labelsHidden()
            .frame(width: 150)
            Button { model.playMappedNote(note, in: mapID) } label: { Image(systemName: "play.fill") }
                .buttonStyle(.borderless)
                .help("Ascolta questo suono sullo strumento")
                .accessibilityLabel("Ascolta \(DrumNames.gm(UInt8(note)) ?? "nota \(note)")")
            Button(learning ? "…" : "Impara") { model.learnTarget(for: note, in: mapID) }
                .disabled(learning)
                .help("Premi poi il tasto giusto su una tastiera MIDI collegata")
            Spacer()
        }
    }

    private var targetBinding: Binding<Int?> {
        Binding(get: { model.target(for: note, in: mapID) },
                set: { model.setTarget($0, for: note, in: mapID) })
    }
}
#endif
