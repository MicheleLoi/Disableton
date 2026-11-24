#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import MIDIHost
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Impostazioni").font(.title2.bold())

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Picker("Sorgente", selection: inputFilter) {
                                Text("Tutte le sorgenti").tag(String?.none)
                                ForEach(inputChoices, id: \.self) { name in
                                    Text(name).tag(String?.some(name))
                                }
                            }
                            .frame(maxWidth: 380)
                            Button("Aggiorna elenco") { model.refreshInputs() }
                        }
                        Text(model.connectedInputs.isEmpty ? "Nessuna sorgente collegata."
                             : "Collegate: " + model.connectedInputs.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Sul Krome: GLOBAL → MIDI → MIDI Clock = Internal.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Ingresso dal Krome")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Porta virtuale: \(LiveHost.virtualPortName) — selezionala come ingresso MIDI in EZdrummer 3 (Settings → MIDI).")
                        Stepper("Canale MIDI: \(model.library.outputChannel)", value: $model.library.outputChannel, in: 1...16)
                            .frame(maxWidth: 260)
                    }
                    .padding(6)
                } label: {
                    Text("Uscita verso EZdrummer 3")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Anticipo batteria")
                                .frame(width: 160, alignment: .leading)
                            Slider(value: $model.library.performance.latencyMs, in: 0...40, step: 0.5)
                                .frame(width: 240)
                            Text(String(format: "%.1f ms", model.library.performance.latencyMs))
                                .monospacedDigit()
                        }
                        Text("Se la batteria arriva in ritardo rispetto ai suoni del Krome, aumenta questo valore.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("Anticipo di programmazione")
                                .frame(width: 160, alignment: .leading)
                            Slider(value: $model.library.performance.lookaheadMs, in: 1...10, step: 0.5)
                                .frame(width: 240)
                            Text(String(format: "%.1f ms", model.library.performance.lookaheadMs))
                                .monospacedDigit()
                        }
                        Text("Valore tecnico: lascialo a 2 ms salvo problemi.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Tempi")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.libraryFolder.path)
                            .font(.callout)
                            .textSelection(.enabled)
                        HStack {
                            Button("Mostra nel Finder") { model.showLibraryInFinder() }
                            Button("Riavvia motore MIDI") { model.startEngine() }
                        }
                        Text("Priorità tempo reale del motore: " + ((model.snapshot?.realtimePriority ?? false) ? "ottenuta" : "non ottenuta"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                } label: {
                    Text("Libreria")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Sorgenti disponibili più quella salvata, anche se ora non è collegata.
    private var inputChoices: [String] {
        var names = model.availableInputs
        if let saved = model.library.performance.inputFilter, !names.contains(saved) {
            names.append(saved)
        }
        return names
    }

    private var inputFilter: Binding<String?> {
        Binding(get: { model.library.performance.inputFilter },
                set: { model.library.performance.inputFilter = $0 })
    }
}
#endif
