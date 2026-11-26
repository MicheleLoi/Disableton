#if canImport(SwiftUI) && os(macOS)
import AppKit
import SwiftUI

/// Guida: cosa fa un groove dentro un brano (ripetuto, fill, finale…) e come crearne con l'AI.
struct GrooveHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied: String?

    static let prompts: [(title: String, text: String)] = [
        ("Groove (ripetuto)", """
        Crea un file MIDI (.mid) scaricabile con un groove di batteria che si ripete senza stacchi. \
        Usa le note di batteria General MIDI sul canale 10. Metro: … . Lunghezza: esattamente … battute. \
        Stile: … . Tempo di riferimento: … BPM. Chiama il file "…".
        """),
        ("Fill", """
        Crea un file MIDI (.mid) scaricabile con un fill di batteria. Usa le note di batteria \
        General MIDI sul canale 10. Metro: … . Lunghezza: esattamente 1 battuta. Viene dopo un \
        groove … e ci riporta dentro: … . Tutte le note devono stare dentro la battuta (niente crash \
        sul battere successivo). Chiama il file "Fill …".
        """),
        ("Finale", """
        Crea un file MIDI (.mid) scaricabile con un finale di batteria. Usa le note di batteria \
        General MIDI sul canale 10. Metro: … . Lunghezza: esattamente … battute. Stile: … . \
        Finisce con … , poi silenzio. Chiama il file "Finale …".
        """),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Fill, finali e comportamento dei groove").font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Un file MIDI contiene solo note: quale pezzo della batteria suona, quando e con che forza. Se un groove si ripete, suona una volta e torna indietro, o chiude il brano lo decide Disableton, separatamente per ogni brano.")
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comportamento").font(.headline)
                        Text("Seleziona la scheda di un groove nel brano: il pannello a destra mostra il suo Comportamento.")
                            .fixedSize(horizontal: false, vertical: true)
                        bullet("Ripetuto: gira in loop finché non arriva un altro comando.")
                        bullet("Fill, poi ritorno ↩: suona una volta, poi torna da solo al groove ripetuto che suonava prima.")
                        bullet("Una volta, poi il successivo →: suona una volta, poi passa al groove successivo del brano. Utile per un'intro o per un fill che porta dalla strofa al ritornello.")
                        bullet("Finale, poi silenzio ■: suona una volta, poi la batteria si ferma.")
                        Text("Quando aggiungi un groove a un brano, Disableton sceglie il comportamento dal nome: se contiene «fill» diventa Fill, poi ritorno; se contiene «finale», Finale, poi silenzio; tutti gli altri sono Ripetuto. Puoi cambiarlo quando vuoi, e lo stesso file può comportarsi in modo diverso in brani diversi. Il nome del groove è il nome del file: «Fill tom.mid» diventa «Fill tom».")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cambio (quando parte)").font(.headline)
                        bullet("Alla battuta (predefinito): parte al battere successivo. Per un fill nella battuta 8, comandalo durante la battuta 7.")
                        bullet("Al battito: parte al battito successivo. Per un fill di mezza battuta, comandalo durante il secondo battito così parte sul terzo.")
                        bullet("A fine groove: aspetta che il groove in corso arrivi alla fine.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Da sapere").font(.headline)
                        bullet("Il comando Fill (dalla workstation) fa partire il primo fill del brano; il comando Finale il primo finale. Gli altri si fanno partire con il tasto della loro posizione (1, 2, 3…), come qualsiasi groove.")
                        bullet("Dopo un fill, il groove riparte dal suo inizio.")
                        bullet("Un fill deve finire su una stanghetta di battuta. Funzionano meglio i fill di una battuta, compresi quelli che iniziano col groove e chiudono con il fill vero e proprio.")
                        bullet("Disableton misura un groove in battute intere, fino all'ultima battuta che contiene una nota. Le battute vuote iniziali vengono saltate.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Creare groove con l'AI").font(.headline)
                        Text("Copia un modello, completa i «…» e incollalo in una chat AI che può creare file da scaricare. Poi importa il file .mid in Disableton. Ascolta il risultato prima di usarlo sul palco.")
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Self.prompts, id: \.title) { prompt in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(prompt.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button(copied == prompt.title ? "Copiato" : "Copia") { copy(prompt) }
                                }
                                Text(prompt.text)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        }
                        Text("Esempi per i «…»: metro 4/4, 3/4 o 6/8; stile rock, funk, shuffle, ballad; «due battiti di groove, poi tom dall'acuto al grave»; «cassa e crash insieme sul primo tempo».")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func copy(_ prompt: (title: String, text: String)) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.text, forType: .string)
        copied = prompt.title
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
