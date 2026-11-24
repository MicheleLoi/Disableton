#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// Dettagli di un groove (aperti dalla libreria): nome, provenienza, lunghezza, metro, ascolto.
struct GrooveDetailView: View {
    @EnvironmentObject var model: AppModel
    let grooveID: UUID
    let onDelete: () -> Void
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let record = model.library.groove(id: grooveID) {
            let groove = model.groove(for: record)
            let usedIn = model.library.songsUsing(grooveID: grooveID)
            let previewing = model.previewingGrooveID == grooveID

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        TextField("Nome", text: model.grooveBinding(grooveID, \.name, fallback: ""))
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)
                        Button("Fine") {
                            model.stopPreview()
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }

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
                    dismiss()
                }
            } message: {
                Text(usedIn.isEmpty ? "Il file verrà rimosso dalla libreria."
                     : "Verrà tolto anche da: " + usedIn.joined(separator: ", ") + ".")
            }
        }
    }
}
#endif
