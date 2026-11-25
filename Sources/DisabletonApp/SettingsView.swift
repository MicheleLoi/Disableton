#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import MIDIHost
import SwiftUI

/// Impostazioni (dall'ingranaggio): Krome, clock, suono della batteria, libreria.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRestart = false
    @State private var editingNoteMap: NoteMapSheetItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Impostazioni").font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
                .sheet(item: $editingNoteMap) { item in
                    NoteMapEditor(mapID: item.id)
                        .environmentObject(model)
                        .frame(width: 640, height: 620)
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    kromeSection
                    Divider()
                    clockSection
                    Divider()
                    soundSection
                    Divider()
                    librarySection
                    Divider()
                    SupportSection()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Krome

    private var kromeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Krome").font(.headline)
            HStack {
                Picker("Ingresso MIDI", selection: inputFilter) {
                    Text("Tutte le sorgenti").tag(String?.none)
                    ForEach(choices(model.availableInputs, saved: model.library.performance.inputFilter), id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                .frame(maxWidth: 420)
                Button("Aggiorna elenco") { model.refreshPorts() }
            }
            Text(model.connectedInputs.isEmpty ? "Nessuna sorgente collegata."
                 : "Collegate: " + model.connectedInputs.joined(separator: ", "))
                .font(.caption).foregroundColor(.secondary)
            Text("Sul Krome: GLOBAL → MIDI → MIDI Clock = Internal.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Clock

    private var clockSection: some View {
        let internalRunning = model.snapshot?.internalClock == true
        return VStack(alignment: .leading, spacing: 10) {
            Text("Clock").font(.headline)
            Text(internalRunning ? "In uso: clock interno (prova senza Krome)." : "In uso: clock dal Krome (esecuzione normale).")
            HStack(spacing: 12) {
                Text("Prova senza Krome")
                Stepper(value: $model.library.performance.internalBPM, in: 40...240, step: 1) {
                    Text("\(Int(model.library.performance.internalBPM)) BPM").monospacedDigit()
                }
                .frame(width: 150)
                Button {
                    model.startInternalClock()
                } label: {
                    Label("Avvia", systemImage: "play.fill")
                }
                .disabled(internalRunning || model.isKromePlaying || model.selectedSongIndex == nil)
                Button {
                    model.stopInternalClock()
                } label: {
                    Label("Ferma", systemImage: "stop.fill")
                }
                .disabled(!internalRunning)
            }
            Text("Suona il brano selezionato in scaletta come se il Krome avesse premuto Start (si avvia anche con ▶ nella barra in alto o ⌘R). I comandi dal Krome (note, pedale, Program Change) continuano a funzionare; il suo clock viene ignorato finché premi Ferma.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Suono

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suono della batteria").font(.headline)
            Picker("Destinazione", selection: $model.library.performance.soundOutput) {
                Text("Porta virtuale “\(LiveHost.virtualPortName)” (EZdrummer o altri strumenti software)").tag(SoundOutput.ezdrummer)
                Text("Sintetizzatore integrato di macOS (suoni di prova)").tag(SoundOutput.builtInSynth)
                Text("Strumento MIDI collegato (Krome o altro synth)").tag(SoundOutput.midiDestination)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if model.library.performance.soundOutput == .midiDestination {
                Picker("Destinazione MIDI", selection: destinationFilter) {
                    Text("Nessuna").tag(String?.none)
                    ForEach(choices(model.availableDestinations, saved: model.library.performance.destinationFilter), id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                .frame(maxWidth: 420)
                Text("Lo strumento deve suonare la batteria sul canale scelto qui sotto (es. sul Krome una traccia con un kit di batteria).")
                    .font(.caption).foregroundColor(.secondary)
            }
            if model.library.performance.soundOutput == .ezdrummer {
                Text("Nello strumento software (es. EZdrummer 3: Settings → MIDI) abilita l'ingresso “\(LiveHost.virtualPortName)”.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Text("Uscita attuale: " + (model.snapshot?.outputDescription ?? "–"))
                .font(.caption).foregroundColor(.secondary)

            HStack(spacing: 10) {
                Picker("Mappa delle note", selection: $model.activeNoteMapID) {
                    Text("General MIDI (nessuna conversione)").tag(UUID?.none)
                    ForEach(model.library.noteMaps) { map in
                        Text(map.name).tag(UUID?.some(map.id))
                    }
                }
                .frame(maxWidth: 420)
                if let id = model.activeNoteMapID {
                    Button("Modifica…") { editingNoteMap = NoteMapSheetItem(id: id) }
                }
                Button("Nuova…") { editingNoteMap = NoteMapSheetItem(id: model.newNoteMap()) }
            }
            Text("Serve se lo strumento ha i suoni della batteria su tasti diversi dal General MIDI (es. un kit di Analog Lab). La mappa vale per la destinazione scelta sopra.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24) {
                Stepper(value: $model.library.outputChannel, in: 1...16) {
                    Text("Canale MIDI \(model.library.outputChannel)")
                }
                .frame(width: 190)
                HStack {
                    Text("Anticipo batteria")
                    Slider(value: $model.library.performance.latencyMs, in: 0...40, step: 0.5)
                        .frame(width: 180)
                    Text(String(format: "%.1f ms", model.library.performance.latencyMs)).monospacedDigit()
                }
            }
            Text("Se la batteria arriva in ritardo rispetto ai suoni del Krome, aumenta l'anticipo.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Libreria

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Libreria").font(.headline)
            Text(model.libraryFolder.path).font(.callout).textSelection(.enabled)
            HStack {
                Button("Mostra nel Finder") { model.showLibraryInFinder() }
                Button("Riavvia motore MIDI…") { confirmRestart = true }
                    .confirmationDialog("Riavviare il motore MIDI?", isPresented: $confirmRestart) {
                        Button("Riavvia", role: .destructive) { model.startEngine() }
                    } message: {
                        Text(model.isPlaying ? "Sta suonando: la riproduzione si interromperà." : "Le porte MIDI verranno ricollegate.")
                    }
            }
            Text(engineLine).font(.caption).foregroundColor(.secondary)
        }
    }

    private var engineLine: String {
        guard model.engineRunning, let snap = model.snapshot else { return "Motore MIDI non attivo" }
        return "Motore MIDI attivo · priorità tempo reale " + (snap.realtimePriority ? "ottenuta" : "NON ottenuta")
    }

    // MARK: Aiuti

    private func choices(_ names: [String], saved: String?) -> [String] {
        var list = names
        if let saved, !saved.isEmpty, !list.contains(saved) { list.append(saved) }
        return list
    }

    private var inputFilter: Binding<String?> {
        Binding(get: { model.library.performance.inputFilter },
                set: { model.library.performance.inputFilter = $0 })
    }

    private var destinationFilter: Binding<String?> {
        Binding(get: { model.library.performance.destinationFilter },
                set: { model.library.performance.destinationFilter = $0 })
    }
}
struct NoteMapSheetItem: Identifiable {
    let id: UUID
}
#endif
