#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// "Segnala un problema": descrizione, anteprima del rapporto, invio come segnalazione su GitHub.
struct ReportView: View {
    @EnvironmentObject var model: AppModel
    @State private var description = ""
    @State private var preview = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Segnala un problema").font(.title2.bold())
            if let reason = model.reportReason {
                Text(reason)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.18)))
            }
            Text("Cosa è successo? Cosa stavi facendo, cosa ti aspettavi, cosa hai sentito?")
                .foregroundColor(.secondary)
            TextEditor(text: $description)
                .font(.body)
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))

            HStack {
                Text("Rapporto allegato").font(.headline)
                Spacer()
                Button("Aggiorna anteprima") { preview = model.diagnosticReport(description: description) }
            }
            ScrollView {
                Text(preview)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))

            Text("La segnalazione sarà pubblica su GitHub. Contiene versione, impostazioni, porte MIDI e registro degli eventi; non contiene nomi di brani o groove. Il rapporto completo viene anche copiato negli appunti.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Annulla") {
                    model.reportReason = nil
                    model.reportCrashExcerpt = nil
                    model.showReport = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Copia rapporto") { model.copyToClipboard(model.diagnosticReport(description: description)) }
                Button("Apri la segnalazione su GitHub") { model.sendReport(description: description) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .onAppear { preview = model.diagnosticReport(description: description) }
    }
}

/// Riquadro "Assistenza" delle impostazioni: versione, aggiornamenti, segnalazioni, registro.
struct SupportSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assistenza").font(.headline)
            Text("Versione \(Updater.currentVersionString) · build \(Updater.currentBuild) · \(AppModel.architecture)")
                .font(.callout)
            HStack {
                Button("Controlla aggiornamenti") { model.checkForUpdates(userInitiated: true) }
                updateStatus
            }
            HStack {
                Button("Segnala un problema…") { model.openReport() }
                Button("Mostra il registro") { model.revealLog() }
            }
            Text("Il registro degli eventi è in ~/Library/Logs/Disableton e si apre anche con Console.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch model.updateState {
        case .idle:
            EmptyView()
        case .checking:
            Text("Controllo in corso…").foregroundColor(.secondary)
        case .upToDate:
            Text("Disableton è aggiornato.").foregroundColor(.secondary)
        case let .available(release):
            Button("Installa la versione \(release.version.description) e riavvia") { model.requestInstallUpdate() }
        case let .downloading(release):
            Text("Scarico la versione \(release.version.description)…").foregroundColor(.secondary)
        case let .failed(message):
            Text(message).foregroundColor(.orange).lineLimit(2)
        }
    }
}

/// Avviso di aggiornamento nella barra in alto.
struct UpdateBadge: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if case let .available(release) = model.updateState {
            Button {
                model.requestInstallUpdate()
            } label: {
                Label("Aggiorna a \(release.version.description)", systemImage: "arrow.down.circle.fill")
            }
            .help("Scarica e installa la nuova versione, poi riavvia Disableton")
        } else if case .downloading = model.updateState {
            Text("Aggiornamento in corso…").foregroundColor(.secondary)
        }
    }
}
#endif
