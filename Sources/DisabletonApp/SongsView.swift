#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// Elenco dei brani e assegnazione dei groove.
struct SongsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(Array(model.library.songs.enumerated()), id: \.element.id) { index, song in
                        HStack {
                            Text("\(index + 1).")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            Text(song.name)
                            Spacer()
                            Text(song.timeSignature.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(song.id)
                        .contextMenu {
                            Button("Elimina brano") { delete(song.id) }
                        }
                    }
                    .onMove { offsets, destination in
                        model.library.moveSongs(fromOffsets: offsets, toOffset: destination)
                    }
                }
                Divider()
                HStack(spacing: 12) {
                    Button(action: addSong) { Image(systemName: "plus") }
                        .help("Nuovo brano")
                    Button { if let id = selection { delete(id) } } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                        .help("Elimina il brano selezionato")
                    Spacer()
                    Text("\(model.library.songs.count) brani")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 260)

            Divider()

            if let id = selection, model.library.songIndex(id: id) != nil {
                SongDetailView(songID: id)
            } else {
                VStack(spacing: 8) {
                    Text("Seleziona un brano o creane uno nuovo con +")
                        .foregroundColor(.secondary)
                    Text("Il numero del brano corrisponde al Program Change dal Krome (brano 1 = PC 0).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func addSong() {
        let id = model.library.addSong(name: "Brano \(model.library.songs.count + 1)")
        selection = id
    }

    private func delete(_ id: UUID) {
        guard let index = model.library.songIndex(id: id) else { return }
        if selection == id { selection = nil }
        model.library.removeSongs(atOffsets: IndexSet(integer: index))
    }
}

struct SongDetailView: View {
    @EnvironmentObject var model: AppModel
    let songID: UUID

    var body: some View {
        let songIndex = model.library.songIndex(id: songID) ?? 0
        let song = model.library.songs[songIndex]

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Nome del brano", text: model.songBinding(songID, \.name, fallback: ""))
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                Picker("Metro", selection: model.songBinding(songID, \.timeSignature, fallback: .fourFour)) {
                    ForEach(TimeSignature.choices(including: song.timeSignature), id: \.self) { ts in
                        Text(ts.description).tag(ts)
                    }
                }
                .frame(width: 150)
            }

            Text("Dal Krome: Program Change \(songIndex) sul canale 16 seleziona questo brano.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Text("Groove del brano").font(.headline)
                Spacer()
                Menu {
                    ForEach(model.library.grooves) { groove in
                        Button(groove.name) {
                            model.library.addSlot(toSong: songIndex, grooveID: groove.id,
                                                  mode: groove.name.localizedCaseInsensitiveContains("fill") ? .oneShotReturn : .loop)
                        }
                    }
                } label: {
                    Label("Aggiungi groove", systemImage: "plus")
                }
                .frame(width: 190)
                .disabled(model.library.grooves.isEmpty)
            }

            if song.slots.isEmpty {
                Text(model.library.grooves.isEmpty
                     ? "La libreria non contiene groove: importali nella sezione Groove."
                     : "Nessun groove assegnato. Usa \"Aggiungi groove\".")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                HStack(spacing: 10) {
                    Text("#").frame(width: 24, alignment: .trailing)
                    Text("Tasto Krome").frame(width: 80, alignment: .leading)
                    Text("Groove").frame(minWidth: 170, alignment: .leading)
                    Text("Comportamento").frame(width: 210, alignment: .leading)
                    Text("Cambio").frame(width: 140, alignment: .leading)
                    Text("Avvio").frame(width: 50, alignment: .leading)
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

                List {
                    ForEach(Array(song.slots.enumerated()), id: \.element.id) { index, slot in
                        SlotRow(songID: songID, slotID: slot.id, index: index)
                    }
                    .onMove { offsets, destination in
                        model.library.moveSlots(inSong: songIndex, fromOffsets: offsets, toOffset: destination)
                    }
                }

                Text("Trascina le righe per cambiare l'ordine. \"Avvio\" indica il groove che parte allo Start del Krome.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct SlotRow: View {
    @EnvironmentObject var model: AppModel
    let songID: UUID
    let slotID: UUID
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
            Text(defaultNoteLabel(forSlot: index) ?? "–")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Picker("", selection: model.slotBinding(song: songID, slot: slotID, \.grooveID, fallback: UUID())) {
                ForEach(model.library.grooves) { groove in
                    Text(groove.name).tag(groove.id)
                }
            }
            .labelsHidden()
            .frame(minWidth: 170)
            Picker("", selection: model.slotBinding(song: songID, slot: slotID, \.mode, fallback: .loop)) {
                ForEach(SlotMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 210)
            Picker("", selection: model.slotBinding(song: songID, slot: slotID, \.quantize, fallback: .bar)) {
                ForEach(Quantize.allCases, id: \.self) { q in
                    Text(q.label).tag(q)
                }
            }
            .labelsHidden()
            .frame(width: 140)
            Toggle("", isOn: autoStart)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 50, alignment: .leading)
                .help("Groove che parte allo Start del Krome")
            Spacer()
            Button(role: .destructive) { remove() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Rimuovi dal brano")
        }
    }

    private var autoStart: Binding<Bool> {
        Binding(
            get: {
                guard let s = model.library.songIndex(id: songID) else { return false }
                let slots = model.library.songs[s].slots
                guard let auto = model.library.songs[s].autoStartSlot, slots.indices.contains(auto) else { return false }
                return slots[auto].id == slotID
            },
            set: { on in
                guard let s = model.library.songIndex(id: songID) else { return }
                model.library.setAutoStart(song: s, slotID: on ? slotID : nil)
            })
    }

    private func remove() {
        guard let s = model.library.songIndex(id: songID),
              let k = model.library.songs[s].slots.firstIndex(where: { $0.id == slotID }) else { return }
        model.library.removeSlots(fromSong: s, atOffsets: IndexSet(integer: k))
    }
}
#endif
