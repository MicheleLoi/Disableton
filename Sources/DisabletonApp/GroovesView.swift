#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI
import UniformTypeIdentifiers

/// Libreria dei groove: importazione, informazioni, ascolto.
struct GroovesView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection: UUID?
    @State private var search = ""
    @State private var showImporter = false
    @State private var importAsEZdrummer = true
    @State private var dropTargeted = false

    private var filtered: [GrooveRecord] {
        let all = model.library.grooves
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Cerca", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .padding(8)
                List(selection: $selection) {
                    ForEach(filtered) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.name)
                            Text(subtitle(record))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(record.id)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button { showImporter = true } label: {
                            Label("Importa file MIDI…", systemImage: "square.and.arrow.down")
                        }
                        Spacer()
                    }
                    Toggle("Provenienza: EZdrummer 3", isOn: $importAsEZdrummer)
                        .toggleStyle(.checkbox)
                    Text("Puoi anche trascinare qui i file .mid dal Finder o da EZdrummer 3.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(width: 300)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .opacity(dropTargeted ? 1 : 0)
            )
            .onDrop(of: [UTType.fileURL, UTType.midi], isTargeted: $dropTargeted) { providers in
                model.handleDrop(providers, source: importAsEZdrummer ? .ezdrummer : .user)
            }

            Divider()

            if let id = selection, model.library.groove(id: id) != nil {
                GrooveDetailView(grooveID: id, onDelete: { selection = nil })
            } else {
                VStack(spacing: 8) {
                    Text(model.library.grooves.isEmpty ? "La libreria è vuota" : "Seleziona un groove")
                        .foregroundColor(.secondary)
                    Text("Da EZdrummer 3: trascina un groove dal suo browser sulla Scrivania o direttamente qui.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.midi], allowsMultipleSelection: true) { result in
            switch result {
            case let .success(urls):
                model.importFiles(urls, source: importAsEZdrummer ? .ezdrummer : .user)
            case let .failure(error):
                model.errorMessage = "\(error.localizedDescription)"
            }
        }
    }

    private func subtitle(_ record: GrooveRecord) -> String {
        var parts = [record.source.label]
        if let g = model.groove(for: record) {
            parts.append(String(format: "%.0f batt.", g.lengthBars.rounded(.up)))
            parts.append(g.timeSignature.description)
        } else {
            parts.append("file non leggibile")
        }
        let uses = model.library.songsUsing(grooveID: record.id).count
        if uses > 0 { parts.append("in \(uses) brani") }
        return parts.joined(separator: " · ")
    }
}

struct GrooveDetailView: View {
    @EnvironmentObject var model: AppModel
    let grooveID: UUID
    let onDelete: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        if let record = model.library.groove(id: grooveID) {
            let groove = model.groove(for: record)
            let usedIn = model.library.songsUsing(grooveID: grooveID)
            let previewing = model.previewingGrooveID == grooveID

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Nome", text: model.grooveBinding(grooveID, \.name, fallback: ""))
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)

                    Form {
                        Picker("Provenienza", selection: model.grooveBinding(grooveID, \.source, fallback: .user)) {
                            Text(GrooveSource.ezdrummer.label).tag(GrooveSource.ezdrummer)
                            Text(GrooveSource.user.label).tag(GrooveSource.user)
                        }
                        Picker("Lunghezza", selection: model.grooveBinding(grooveID, \.lengthBars, fallback: nil)) {
                            Text("Automatica").tag(Int?.none)
                            ForEach(1...16, id: \.self) { n in
                                Text(n == 1 ? "1 battuta" : "\(n) battute").tag(Int?.some(n))
                            }
                        }
                        Picker("Metro", selection: model.grooveBinding(grooveID, \.timeSignature, fallback: nil)) {
                            Text("Dal file").tag(TimeSignature?.none)
                            ForEach(TimeSignature.common, id: \.self) { ts in
                                Text(ts.description).tag(TimeSignature?.some(ts))
                            }
                        }
                        Toggle("Togli le battute vuote iniziali",
                               isOn: model.grooveBinding(grooveID, \.trimLeadingEmptyBars, fallback: true))
                    }
                    .frame(maxWidth: 420)

                    GroupBox {
                        HStack(spacing: 12) {
                            Button {
                                model.togglePreview(record)
                            } label: {
                                Label(previewing ? "Ferma" : "Ascolta", systemImage: previewing ? "stop.fill" : "play.fill")
                            }
                            .disabled(groove == nil)
                            Slider(value: $model.previewBPM, in: 40...240, step: 1)
                                .frame(width: 200)
                            Text("\(Int(model.previewBPM)) BPM")
                                .monospacedDigit()
                                .frame(width: 70, alignment: .leading)
                        }
                        .padding(4)
                    } label: {
                        Text("Ascolto con EZdrummer 3 (senza Krome)")
                    }

                    if let groove {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: "Lunghezza: %.2f battute in %@, %d colpi",
                                            groove.lengthBars, groove.timeSignature.description as NSString, groove.noteOnCount))
                                if let bpm = groove.sourceTempoBPM {
                                    Text(String(format: "Tempo indicato nel file: %.1f BPM", bpm))
                                }
                                if groove.droppedEventCount > 0 {
                                    Text("\(groove.droppedEventCount) eventi oltre la fine sono stati ignorati")
                                        .foregroundColor(.orange)
                                }
                                Divider()
                                ForEach(groove.noteHistogram.sorted(by: { $0.key < $1.key }), id: \.key) { note, count in
                                    HStack {
                                        Text("\(note)").monospacedDigit().frame(width: 30, alignment: .trailing)
                                        Text(NoteName.korg(note)).frame(width: 40, alignment: .leading)
                                        Text(DrumNames.gm(note) ?? "–").frame(width: 170, alignment: .leading)
                                        Text("\(count) colpi").foregroundColor(.secondary)
                                    }
                                    .font(.callout)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        } label: {
                            Text("Contenuto (nomi General MIDI indicativi)")
                        }
                    } else {
                        Text("Il file del groove non si riesce a leggere.").foregroundColor(.red)
                    }

                    Text(usedIn.isEmpty ? "Non usato in nessun brano." : "Usato in: " + usedIn.joined(separator: ", "))
                        .foregroundColor(.secondary)

                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Elimina groove…", systemImage: "trash")
                    }
                }
                .padding(20)
            }
            .confirmationDialog("Eliminare \"\(record.name)\"?", isPresented: $confirmDelete) {
                Button("Elimina", role: .destructive) {
                    onDelete()
                    model.deleteGroove(id: grooveID)
                }
            } message: {
                Text(usedIn.isEmpty ? "Il file verrà rimosso dalla libreria."
                     : "Verrà tolto anche da: " + usedIn.joined(separator: ", ") + ".")
            }
        }
    }
}
#endif
