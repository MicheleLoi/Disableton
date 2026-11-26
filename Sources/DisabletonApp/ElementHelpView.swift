#if canImport(SwiftUI) && os(macOS)
import AppKit
import MIDIHost
import SwiftUI

/// Guida: Element, un programma gratuito che apre strumenti plugin senza una DAW.
struct ElementHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let downloadURL = URL(string: "https://github.com/kushview/element/releases/tag/1.1.1")!

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
                        bullet("Vuoi un programma leggero e sempre uguale per il palco, invece di una DAW completa. È anche gratuito, mentre REAPER richiede una licenza.")
                        Text("Quando non serve").font(.headline).padding(.top, 6)
                        bullet("Lo strumento ha già un'app autonoma (per esempio Analog Lab o Pigments): basta selezionare «\(LiveHost.virtualPortName)» come ingresso MIDI nell'app stessa.")
                        bullet("Usi il sintetizzatore di macOS o la workstation: Disableton li raggiunge già da solo.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scaricarlo").font(.headline)
                        Button("Element 1.1.1 su GitHub") { NSWorkspace.shared.open(downloadURL) }
                        Text("In quella pagina scorri fino ad Assets e scarica il file per macOS (non «Source code», che è per gli sviluppatori). Sposta Element in Applicazioni (non c'è un programma di installazione); la prima volta apri Element con clic destro → Apri. Non confonderlo con l'app di chat che si chiama anch'essa «Element».")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Collegarlo a Disableton", [
                        "In Disableton: Impostazioni → Suono della batteria → «Porta virtuale «\(LiveHost.virtualPortName)»». Tieni Disableton aperto.",
                        "Apri Element. Menu Element → Preferences… → pagina MIDI → in «Active MIDI Inputs» accendi «\(LiveHost.virtualPortName)». Se non c'è, chiudi e riapri Element con Disableton già aperto.",
                        "La prima volta: menu View → Plugin Manager → Scan, così Element trova i plugin installati. Poi clic destro sulla zona vuota del grafico (oppure Edit → Insert plugin…) e scegli lo strumento di batteria. Collega, trascinando, il pallino arancione di «MIDI In» allo strumento e i pallini verdi dello strumento ad «Audio Out».",
                        "Prova: in Disableton premi ▶ Prova senza workstation. Lo strumento in Element deve suonare.",
                    ])

                    Text("Per far suonare più strumenti insieme (un suono di batteria per ciascuno) serve una funzione di Disableton ancora in preparazione.")
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
