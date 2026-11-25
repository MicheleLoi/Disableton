#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI
import UniformTypeIdentifiers

/// Preparazione: scaletta, groove del brano in ordine, libreria, dettagli dello slot.
struct PrepView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SetlistColumn()
                .frame(minWidth: 190, idealWidth: 230, maxWidth: 250)
            Divider()
            VStack(spacing: 0) {
                SongSequence()
                    .frame(maxHeight: .infinity, alignment: .top)
                Divider()
                LibraryStrip()
                    .frame(height: 230)
            }
            .frame(minWidth: 400, maxWidth: .infinity)
            Divider()
            SlotInspector()
                .frame(minWidth: 230, idealWidth: 260, maxWidth: 280)
        }
    }
}

// MARK: - Scaletta

struct SetlistColumn: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Scaletta").font(.headline)
                Spacer()
                Button { model.addSong() } label: { Image(systemName: "plus") }
                    .help("Nuovo brano")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if model.library.songs.isEmpty {
                Text("Nessun brano.")
                    .foregroundColor(.secondary)
                    .padding(14)
                Spacer()
            } else {
                List(selection: $model.selectedSongID) {
                    ForEach(Array(model.library.songs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .trailing)
                            Text(song.name).lineLimit(1)
                            Spacer()
                            if model.snapshot?.status.songIndex == index {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.accentColor)
                                    .accessibilityLabel("Brano selezionato sul Krome")
                            }
                            if song.timeSignature != .fourFour {
                                Text(song.timeSignature.description).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .tag(song.id)
                        .contextMenu {
                            Button("Elimina brano") { model.deleteSong(song.id) }
                        }
                    }
                    .onMove { offsets, destination in
                        model.library.moveSongs(fromOffsets: offsets, toOffset: destination)
                    }
                }
            }
            Text("Brano n = Program Change n−1 dal Krome. Trascina per riordinare.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
        }
    }
}

// MARK: - Groove del brano

struct SongSequence: View {
    @EnvironmentObject var model: AppModel
    @State private var dropTargeted = false

    var body: some View {
        if let songIndex = model.selectedSongIndex {
            let song = model.library.songs[songIndex]
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("Nome del brano", text: model.songBinding(song.id, \.name, fallback: ""))
                            .textFieldStyle(.roundedBorder)
                            .font(.title2.weight(.semibold))
                        Picker("Metro", selection: model.songBinding(song.id, \.timeSignature, fallback: .fourFour)) {
                            ForEach(TimeSignature.choices(including: song.timeSignature), id: \.self) { ts in
                                Text(ts.description).tag(ts)
                            }
                        }
                        .frame(width: 140)
                        Button { model.perform(.selectSong(songIndex)) } label: {
                            Label("Seleziona", systemImage: "scope")
                        }
                        .help("Rende questo il brano corrente, come un Program Change dal Krome")
                    }

                    Text("Groove del brano, in ordine").font(.caption.weight(.semibold)).foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(Array(song.slots.enumerated()), id: \.element.id) { index, slot in
                            SlotCard(songIndex: songIndex, index: index, slot: slot)
                        }
                        Text(song.slots.isEmpty ? "Trascina qui un groove dalla libreria" : "Trascina qui un groove")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 96)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(dropTargeted ? Color.accentColor : Color.gray.opacity(0.5),
                                            style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            )
                    }
                    .onDrop(of: [UTType.plainText, UTType.text], isTargeted: $dropTargeted) { providers in
                        model.handleGrooveDrop(providers)
                    }
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 10) {
                Text("Seleziona un brano nella scaletta, o creane uno con +").foregroundColor(.secondary)
                if model.library.songs.isEmpty {
                    Button("Aggiungi brani dimostrativi") { model.installDemo() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SlotCard: View {
    @EnvironmentObject var model: AppModel
    let songIndex: Int
    let index: Int
    let slot: SlotRecord

    private var isCurrentSong: Bool { model.snapshot?.status.songIndex == songIndex }
    private var playing: Bool { isCurrentSong && model.snapshot?.status.playingSlot == index }
    private var pending: Bool { isCurrentSong && model.snapshot?.status.pendingSlot == index }
    private var selected: Bool { model.selectedSlotID == slot.id }
    private var isAutoStart: Bool {
        model.library.songs.indices.contains(songIndex) && model.library.songs[songIndex].autoStartSlot == index
    }

    private var header: String {
        guard let note = defaultNoteLabel(forSlot: index) else { return "\(index + 1)" }
        return "\(index + 1) · \(note)"
    }

    private var detail: String {
        var text = symbol(slot.mode) + " " + slot.mode.label
        if let record = model.library.groove(id: slot.grooveID), let groove = model.groove(for: record) {
            text += String(format: " · %.0f batt.", groove.lengthBars.rounded(.up))
        }
        return text
    }

    private var fillColor: Color {
        if playing { return Color.green.opacity(0.25) }
        if pending { return Color.orange.opacity(0.25) }
        return Color.gray.opacity(0.1)
    }

    private var borderColor: Color {
        if selected { return Color.accentColor }
        if playing { return Color.green }
        if pending { return Color.orange }
        return Color.clear
    }

    var body: some View {
        Button {
            model.selectedSlotID = slot.id
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Suona dal Krome (prova)") { model.perform(.triggerSlot(index)) }
            Button("Rimuovi dal brano") {
                model.selectedSlotID = slot.id
                model.removeSelectedSlot()
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(header).font(.caption).foregroundColor(.secondary)
                Spacer()
                if isAutoStart { autoStartBadge }
            }
            Text(model.displayName(of: slot))
                .font(.headline)
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(fillColor))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 2))
        .contentShape(Rectangle())
    }

    private var autoStartBadge: some View {
        Text("AVVIO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.2)))
    }

    private func symbol(_ mode: SlotMode) -> String {
        switch mode {
        case .loop: return "↻"
        case .oneShotReturn: return "↩"
        case .oneShotNext: return "→"
        case .oneShotStop: return "■"
        }
    }
}

// MARK: - Libreria

struct LibraryStrip: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var filter: GrooveSource?
    @State private var showImporter = false
    @State private var importAsEZdrummer = true
    @State private var fileDropTargeted = false

    private var filtered: [GrooveRecord] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return model.library.grooves.filter { record in
            (filter == nil || record.source == filter)
                && (query.isEmpty || record.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Libreria groove")
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 8)
                Toggle("Da EZdrummer 3", isOn: $importAsEZdrummer)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .help("Provenienza assegnata ai file importati")
                Button("Importa .mid…") { showImporter = true }
                    .fixedSize()
            }
            HStack(spacing: 10) {
                TextField("Cerca", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120, maxWidth: 220)
                Picker("Provenienza", selection: $filter) {
                    Text("Tutti").tag(GrooveSource?.none)
                    Text("EZdrummer 3").tag(GrooveSource?.some(.ezdrummer))
                    Text("Personali").tag(GrooveSource?.some(.user))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer(minLength: 0)
            }

            if model.library.grooves.isEmpty {
                Text("La libreria è vuota: trascina qui i file .mid (dal Finder o da EZdrummer 3) oppure usa \"Importa .mid…\".")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(filtered) { record in
                            GrooveChip(record: record)
                        }
                    }
                }
            }
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
                .opacity(fileDropTargeted ? 1 : 0)
        )
        .onDrop(of: [UTType.fileURL, UTType.midi], isTargeted: $fileDropTargeted) { providers in
            model.handleFileDrop(providers, source: importAsEZdrummer ? .ezdrummer : .user)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.midi], allowsMultipleSelection: true) { result in
            switch result {
            case let .success(urls):
                model.importFiles(urls, source: importAsEZdrummer ? .ezdrummer : .user)
            case let .failure(error):
                model.errorMessage = error.localizedDescription
            }
        }
    }
}

struct GrooveChip: View {
    @EnvironmentObject var model: AppModel
    let record: GrooveRecord

    var body: some View {
        let groove = model.groove(for: record)
        let previewing = model.previewingGrooveID == record.id
        HStack(spacing: 8) {
            Button { model.togglePreview(record) } label: {
                Image(systemName: previewing ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .help(previewing ? "Ferma l'ascolto" : "Ascolta")
            .accessibilityLabel(previewing ? "Ferma \(record.name)" : "Ascolta \(record.name)")
            VStack(alignment: .leading, spacing: 1) {
                Text(record.name).lineLimit(1)
                Text(subtitle(groove)).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { model.addSlot(grooveID: record.id) } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .disabled(model.selectedSongIndex == nil)
                .help("Aggiungi al brano selezionato")
                .accessibilityLabel("Aggiungi \(record.name) al brano")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).stroke(previewing ? Color.accentColor : Color.gray.opacity(0.35)))
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(object: record.id.uuidString as NSString) }
        .contextMenu {
            Button("Dettagli…") { model.detailGrooveID = record.id }
            Button("Aggiungi al brano") { model.addSlot(grooveID: record.id) }
            Divider()
            Button("Elimina dalla libreria") { model.deleteGroove(id: record.id) }
        }
        .onTapGesture(count: 2) { model.detailGrooveID = record.id }
    }

    private func subtitle(_ groove: Groove?) -> String {
        guard let groove else { return "file non leggibile" }
        var parts = [String(format: "%.0f batt.", groove.lengthBars.rounded(.up)), groove.timeSignature.description]
        if record.source == .ezdrummer { parts.append("EZD") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Dettagli dello slot

struct SlotInspector: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let s = model.selectedSongIndex, let k = model.selectedSlotIndex {
            let song = model.library.songs[s]
            let slot = song.slots[k]
            let learning = model.learningTarget == .new(.triggerSlot(k))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Slot \(k + 1) · \(model.displayName(of: slot))").font(.headline)

                    Picker("Groove", selection: model.slotBinding(song: song.id, slot: slot.id, \.grooveID, fallback: slot.grooveID)) {
                        ForEach(model.library.grooves) { g in Text(g.name).tag(g.id) }
                    }
                    Picker("Comportamento", selection: model.slotBinding(song: song.id, slot: slot.id, \.mode, fallback: .loop)) {
                        ForEach(SlotMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
                    }
                    Picker("Cambio", selection: model.slotBinding(song: song.id, slot: slot.id, \.quantize, fallback: .bar)) {
                        ForEach(Quantize.allCases, id: \.self) { q in Text(q.label).tag(q) }
                    }
                    Toggle("Parte allo Start del Krome", isOn: Binding(
                        get: { model.library.songs.indices.contains(s) && model.library.songs[s].autoStartSlot == k },
                        set: { on in model.library.setAutoStart(song: s, slotID: on ? slot.id : nil) }))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tasto sul Krome").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Text(keyLabel(forSlot: k)).fontWeight(.semibold)
                            Spacer()
                            if learning {
                                Button("Annulla") { model.cancelLearn() }
                            } else {
                                Button("Impara") { model.learnKey(forSlot: k) }
                            }
                        }
                        if learning {
                            Text("Premi un tasto sul Krome…").font(.caption).foregroundColor(.orange)
                        }
                    }

                    HStack {
                        Button { model.moveSelectedSlot(by: -1) } label: { Image(systemName: "arrow.left") }
                            .disabled(k == 0)
                            .help("Sposta prima")
                        Button { model.moveSelectedSlot(by: 1) } label: { Image(systemName: "arrow.right") }
                            .disabled(k == song.slots.count - 1)
                            .help("Sposta dopo")
                        Spacer()
                        Button(role: .destructive) { model.removeSelectedSlot() } label: {
                            Label("Rimuovi", systemImage: "trash")
                        }
                    }

                    if let record = model.library.groove(id: slot.grooveID) {
                        Button {
                            model.togglePreview(record)
                        } label: {
                            Label(model.previewingGrooveID == record.id ? "Ferma ascolto" : "Ascolta a \(Int(model.previewBPM)) BPM",
                                  systemImage: model.previewingGrooveID == record.id ? "stop.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        Slider(value: $model.previewBPM, in: 40...240, step: 1) { Text("Tempo") }
                        Button("Dettagli del groove…") { model.detailGrooveID = record.id }
                    }

                    Text("Le modifiche fatte mentre il Krome suona valgono dal prossimo Stop.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(18)
            }
            .background(Color.gray.opacity(0.05))
        } else {
            VStack(spacing: 8) {
                Text("Seleziona un groove del brano per modificarlo.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
        }
    }

    private func keyLabel(forSlot index: Int) -> String {
        let bindings = model.library.controlMap.bindings.filter { $0.action == .triggerSlot(index) }
        guard !bindings.isEmpty else { return "nessuno" }
        return bindings.map { $0.triggerLabel }.joined(separator: "; ")
    }
}
#endif
