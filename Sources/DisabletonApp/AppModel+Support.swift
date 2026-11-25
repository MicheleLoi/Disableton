#if canImport(SwiftUI) && os(macOS)
import AppKit
import Foundation
import GrooveCore
import MIDIHost

/// Registro, rapporto diagnostico, segnalazioni, crash e aggiornamenti.
extension AppModel {
    // MARK: - Avvio e chiusura

    private var sessionMarker: URL { libraryFolder.appendingPathComponent(".sessione-in-corso") }
    private static let lastCrashCheckKey = "ultimoControlloCrash"

    static var architecture: String {
        #if arch(x86_64)
        return "Intel (x86_64)"
        #elseif arch(arm64)
        return "Apple Silicon (arm64)"
        #else
        return "altra"
        #endif
    }

    func logStartup() {
        log.log("Avvio Disableton \(Updater.currentVersionString) (build \(Updater.currentBuild), commit \(Updater.currentCommit.prefix(7))) · \(ProcessInfo.processInfo.operatingSystemVersionString) · \(AppModel.architecture)")
    }

    /// Se l'ultima sessione non si è chiusa normalmente (crash, blocco, chiusura forzata),
    /// propone di inviare una segnalazione con il rapporto di macOS, se c'è.
    func checkPreviousSession() {
        let defaults = UserDefaults.standard
        let lastCheck = defaults.object(forKey: AppModel.lastCrashCheckKey) as? Date ?? Date().addingTimeInterval(-7 * 24 * 3600)
        let crashes = CrashReports.find(newerThan: lastCheck)
        let abnormal = FileManager.default.fileExists(atPath: sessionMarker.path)
        defaults.set(Date(), forKey: AppModel.lastCrashCheckKey)
        try? Data().write(to: sessionMarker)

        guard abnormal || !crashes.isEmpty else { return }
        if let crash = crashes.first {
            log.log("Trovato rapporto di crash di macOS: \(crash.lastPathComponent)")
            reportCrashExcerpt = "File: \(crash.lastPathComponent)\n\n" + CrashReports.excerpt(of: crash)
        } else {
            log.log("La sessione precedente non si è chiusa normalmente")
        }
        reportReason = crashes.isEmpty
            ? "L'ultima volta Disableton non si è chiuso normalmente (blocco o chiusura forzata). Vuoi segnalarlo?"
            : "L'ultima volta Disableton si è chiuso per un errore. Il rapporto di macOS è già incluso qui sotto."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.showReport = true
        }
    }

    func applicationWillTerminate() {
        log.log("Chiusura normale")
        try? FileManager.default.removeItem(at: sessionMarker)
    }

    // MARK: - Eventi nel registro

    func logChanges(from old: LiveSnapshot?, to new: LiveSnapshot) {
        let o = old?.status
        let n = new.status
        if old == nil || old?.realtimePriority != new.realtimePriority {
            log.log("Priorità tempo reale del motore: \(new.realtimePriority ? "ottenuta" : "NON ottenuta")")
        }
        if o?.songIndex != n.songIndex {
            log.log("Brano corrente: \(n.songIndex.map { "\($0 + 1)" } ?? "nessuno")")
        }
        if o?.transportRunning != n.transportRunning {
            let source = new.previewing ? "ascolto" : (new.internalClock ? "clock interno" : "Krome")
            log.log(n.transportRunning ? "Start (\(source))" : "Stop")
        }
        if old?.clockReceiving != new.clockReceiving {
            log.log(new.clockReceiving ? "Clock dal Krome ricevuto" : "Clock dal Krome assente")
        }
        if o?.playingSlot != n.playingSlot {
            log.log("Suona: \(n.playingSlot.map { "slot \($0 + 1)" } ?? "silenzio")"
                    + (new.tempoBPM.map { String(format: " · %.1f BPM", $0) } ?? "")
                    + (new.bar.map { " · battuta \($0)" } ?? ""))
        }
        if let pending = n.pendingSlot, pending != o?.pendingSlot {
            log.log("In coda: slot \(pending + 1)")
        }
        if n.stopPending && o?.stopPending != true {
            log.log("In coda: silenzio")
        }
        if let command = new.lastCommand, command != old?.lastCommand {
            log.log("Comando ricevuto: \(command)")
        }
    }

    // MARK: - Rapporto e segnalazione

    func diagnosticReport(description: String) -> String {
        var report = DiagnosticReport()
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report.add("Descrizione", [description])
        }
        report.add("Versione", [
            "Disableton \(Updater.currentVersionString) · build \(Updater.currentBuild) · commit \(Updater.currentCommit.prefix(7))",
            "\(ProcessInfo.processInfo.operatingSystemVersionString) · \(AppModel.architecture)",
        ])
        refreshPorts()
        let snap = snapshot
        report.add("MIDI", [
            "Sorgenti: " + (availableInputs.isEmpty ? "nessuna" : availableInputs.joined(separator: ", ")),
            "Destinazioni: " + (availableDestinations.isEmpty ? "nessuna" : availableDestinations.joined(separator: ", ")),
            "Ingressi collegati: " + (connectedInputs.isEmpty ? "nessuno" : connectedInputs.joined(separator: ", ")),
            "Uscita: " + (snap?.outputDescription ?? "-"),
            "Motore: " + (engineRunning ? "attivo" : "fermo") + " · priorità tempo reale: "
                + ((snap?.realtimePriority ?? false) ? "ottenuta" : "non ottenuta"),
        ])
        if let snap {
            let st = snap.status
            report.add("Stato", [
                "Trasporto: \(st.transportRunning ? "in corso" : "fermo") · clock Krome: \(snap.clockReceiving ? "sì" : "no") · clock interno: \(snap.internalClock ? "sì" : "no")",
                "Brano: \(st.songIndex.map { "\($0 + 1)" } ?? "-") · slot: \(st.playingSlot.map { "\($0 + 1)" } ?? "-") · in coda: \(st.pendingSlot.map { "\($0 + 1)" } ?? "-")",
                "Battuta: \(snap.bar.map(String.init) ?? "-") · tempo: \(snap.tempoBPM.map { String(format: "%.1f", $0) } ?? "-") BPM",
                "Ultimo comando: \(snap.lastCommand ?? "-")",
            ])
        }
        let p = library.performance
        report.add("Impostazioni", [
            "Suono: \(p.soundOutput.rawValue) · canale \(library.outputChannel) · destinazione: \(p.destinationFilter ?? "-")",
            "Ingresso: \(p.inputFilter ?? "tutte le sorgenti") · anticipo \(p.latencyMs) ms · lookahead \(p.lookaheadMs) ms · clock interno \(Int(p.internalBPM)) BPM",
            "Libreria: \(library.songs.count) brani, \(library.grooves.count) groove, \(library.controlMap.bindings.count) comandi MIDI",
        ])
        if let crash = reportCrashExcerpt {
            report.add("Rapporto di crash di macOS (inizio)", ["```", crash, "```"])
        }
        report.add("Registro (ultime righe)", ["```"] + log.recentLines.suffix(120) + ["```"])
        return report.text()
    }

    /// Copia il rapporto completo negli appunti e apre una segnalazione precompilata su GitHub.
    func sendReport(description: String) {
        let text = diagnosticReport(description: description)
        copyToClipboard(text)
        let firstLine = description.split(separator: "\n").first.map(String.init) ?? ""
        let title = firstLine.isEmpty ? "Segnalazione da Disableton \(Updater.currentVersionString)" : String(firstLine.prefix(80))
        log.log("Segnalazione aperta su GitHub")
        NSWorkspace.shared.open(IssueLink.url(title: title, body: text))
        reportCrashExcerpt = nil
        reportReason = nil
        showReport = false
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func openReport() {
        reportReason = nil
        showReport = true
    }

    func revealLog() {
        if let url = log.fileURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // MARK: - Aggiornamenti

    func checkForUpdates(userInitiated: Bool) {
        if case .downloading = updateState { return }
        updateState = .checking
        Updater.check { [weak self] state in
            guard let self else { return }
            switch state {
            case let .available(release):
                self.log.log("Aggiornamento disponibile: \(release.version)")
            case let .failed(message):
                self.log.log(message)
            default:
                break
            }
            // Un controllo automatico non riuscito non disturba: resta solo nel registro.
            if !userInitiated, case .failed = state {
                self.updateState = .idle
            } else {
                self.updateState = state
            }
        }
    }

    /// Chiede conferma prima di installare (l'app si chiude e si riapre).
    func requestInstallUpdate() {
        guard case .available = updateState else { return }
        confirmInstallUpdate = true
    }

    func installUpdate() {
        guard case let .available(release) = updateState else { return }
        if snapshot?.status.transportRunning == true {
            errorMessage = "Ferma prima il Krome (o il clock interno): l'aggiornamento riavvia l'app."
            return
        }
        guard Updater.canSelfInstall else {
            if let page = release.pageURL { NSWorkspace.shared.open(page) }
            errorMessage = "Disableton non può sostituirsi da solo in questa cartella. Ho aperto la pagina di download: scarica Disableton.zip e sostituisci l'app in Applicazioni."
            return
        }
        updateState = .downloading(release)
        log.log("Download dell'aggiornamento \(release.version)")
        Updater.downloadAndInstall(release, canInstall: { [weak self] in self?.isPlaying != true },
                                   log: { [weak self] in self?.log.log($0) }) { [weak self] message in
            self?.updateState = .failed(message)
            self?.errorMessage = message
        }
    }
}
#endif
