#if canImport(SwiftUI) && os(macOS)
import AppKit
import MIDIHost
import SwiftUI

/// Guida: Element, un programma gratuito che apre strumenti plugin senza una DAW.
struct ElementHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let downloadURL = URL(string: "https://kushview.net/element/")!
    private let githubURL = URL(string: "https://github.com/kushview/element/releases")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Element: strumenti plugin senza DAW").font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Element è un programma gratuito e open source che apre strumenti in formato plugin (AU, VST3) e li fa suonare con il MIDI, senza tutto quello che fa una DAW: niente tracce, registrazione o progetti.")
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quando usarlo").font(.headline)
                        bullet("Lo strumento di batteria che vuoi usare esiste solo come plugin, senza un'app da aprire da sola.")
                        bullet("Vuoi un programma leggero e sempre uguale per il palco, invece di una DAW completa.")
                        Text("Quando non serve").font(.headline).padding(.top, 6)
                        bullet("Lo strumento ha già un'app autonoma (EZdrummer 3, Analog Lab, Pigments): basta selezionare «\(LiveHost.virtualPortName)» come ingresso MIDI nell'app stessa.")
                        bullet("Usi il sintetizzatore di macOS o il Krome: Disableton li raggiunge già da solo.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scaricarlo").font(.headline)
                        HStack(spacing: 12) {
                            Button("Sito di Element (kushview.net)") { NSWorkspace.shared.open(downloadURL) }
                            Button("Versioni su GitHub") { NSWorkspace.shared.open(githubURL) }
                        }
                        Text("Il sito può chiedere un indirizzo email prima del download; su GitHub si scarica direttamente. Prima di affidartici, controlla che la versione scaricata si apra sul tuo Mac.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Collegarlo a Disableton", [
                        "In Disableton: Impostazioni → Suono della batteria → «Porta virtuale «\(LiveHost.virtualPortName)»». Tieni Disableton aperto.",
                        "Apri Element. Nelle sue preferenze, nella parte MIDI, abilita l'ingresso «\(LiveHost.virtualPortName)». Se non c'è, chiudi e riapri Element con Disableton già aperto.",
                        "Carica lo strumento di batteria e collega l'ingresso MIDI allo strumento, e lo strumento all'uscita audio.",
                        "Prova: in Disableton premi ▶ Prova senza Krome. Lo strumento in Element deve suonare.",
                    ])

                    Text("Per far suonare più strumenti insieme (un suono di batteria per ciascuno) serve una funzione di Disableton ancora in preparazione; quando sarà pronta, questa pagina spiegherà come usarla con Element.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func section(_ title: String, _ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(offset + 1).").fontWeight(.semibold).frame(width: 24, alignment: .trailing)
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
