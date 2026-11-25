#if canImport(SwiftUI) && os(macOS)
import MIDIHost
import SwiftUI

/// Guida: far suonare la batteria di Disableton da una DAW, con REAPER come esempio.
struct DAWHelpView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Collegare una DAW (esempio: REAPER)").font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Disableton manda le note della batteria a una porta MIDI chiamata «\(LiveHost.virtualPortName)». Una DAW può riceverle e suonarle con i suoi strumenti. Il tempo lo decidono il Krome o il clock interno di Disableton: la DAW non deve essere sincronizzata né in riproduzione.")
                        .fixedSize(horizontal: false, vertical: true)

                    section("In Disableton", [
                        "Impostazioni → Suono della batteria → «Porta virtuale «\(LiveHost.virtualPortName)»».",
                        "Tieni Disableton aperto mentre usi la DAW: la porta «\(LiveHost.virtualPortName)» esiste solo quando l'app è aperta.",
                    ], start: 1)

                    section("In REAPER, una volta sola", [
                        "Apri REAPER → Settings… (⌘,) → Audio → MIDI Inputs (nelle versioni meno recenti si chiama MIDI Devices).",
                        "Nell'elenco trova «\(LiveHost.virtualPortName)»: doppio clic, spunta «Enable input» e conferma con OK.",
                        "Se «\(LiveHost.virtualPortName)» non è nell'elenco, REAPER è stato aperto prima di Disableton: premi «Reset all MIDI devices» nella stessa pagina, oppure chiudi e riapri REAPER con Disableton già aperto.",
                    ], start: 3)

                    section("In ogni progetto di REAPER", [
                        "Prepara una traccia con lo strumento di batteria che vuoi usare.",
                        "Nella traccia apri il menu dell'ingresso (sotto il nome della traccia) e scegli Input: MIDI → \(LiveHost.virtualPortName) → All channels.",
                        "Arma la traccia con il pulsante rosso di registrazione e accendi il monitoraggio dell'ingresso (l'icona dell'altoparlante accanto al pulsante rosso).",
                        "Per non registrare nulla mentre suoni: clic destro sul pulsante rosso → «Record: disable (input monitoring only)».",
                        "Prova: in Disableton premi ▶ Prova senza Krome. Nella traccia di REAPER si accende l'indicatore MIDI e lo strumento suona.",
                    ], start: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Se qualcosa non va").font(.headline)
                        bullet("Lo strumento suona i suoni sbagliati (es. un rullante al posto della cassa): il kit non segue la disposizione General MIDI. Scegli un kit General MIDI; la conversione delle note è in preparazione.")
                        bullet("La batteria arriva in ritardo rispetto al Krome: in REAPER → Settings → Audio → Device riduci «Request block size» (per esempio 128), poi regola «Anticipo batteria» nelle impostazioni di Disableton.")
                        bullet("La traccia non riceve nulla: controlla che sia armata, con il monitoraggio acceso e l'ingresso «\(LiveHost.virtualPortName)», e che in Disableton la destinazione del suono sia la porta virtuale.")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func section(_ title: String, _ steps: [String], start: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(start + offset).").fontWeight(.semibold).frame(width: 24, alignment: .trailing)
                    Text(text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").frame(width: 24, alignment: .trailing)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
