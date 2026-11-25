#if canImport(SwiftUI) && os(macOS)
import AppKit
import Foundation
import GrooveCore

/// Aggiornamento integrato: controlla l'ultima release di GitHub, scarica l'app, verifica che sia
/// davvero Disableton (identificativo, versione, firma), la sostituisce e riavvia.
/// Scarica solo dalle release di questo repository, via HTTPS.
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(ReleaseInfo)
        case failed(String)
    }

    static var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "sviluppo"
    }

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    static var currentCommit: String {
        Bundle.main.infoDictionary?["DisabletonCommit"] as? String ?? "-"
    }

    static var currentVersion: AppVersion {
        AppVersion(string: currentVersionString) ?? AppVersion([0])
    }

    /// L'app può sostituirsi da sola solo se è un bundle .app in una cartella scrivibile.
    static var canSelfInstall: Bool {
        let bundle = Bundle.main.bundleURL
        return bundle.pathExtension == "app"
            && FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    /// Controlla l'ultima release. `completion` è chiamato sulla coda principale.
    static func check(completion: @escaping (State) -> Void) {
        var request = URLRequest(url: ReleaseInfo.latestAPIURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Disableton-app", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let state: State
            if let error {
                state = .failed("Controllo non riuscito: \(error.localizedDescription)")
            } else if (response as? HTTPURLResponse)?.statusCode == 404 {
                state = .upToDate
            } else if let data, let release = ReleaseInfo.parse(data) {
                state = release.version > currentVersion ? .available(release) : .upToDate
            } else {
                state = .failed("Risposta di GitHub non riconosciuta")
            }
            DispatchQueue.main.async { completion(state) }
        }.resume()
    }

    /// Scarica, verifica e installa. In caso di successo l'app si chiude e riparte aggiornata;
    /// altrimenti `failure` riceve il motivo (sulla coda principale).
    static func downloadAndInstall(_ release: ReleaseInfo, canInstall: @escaping () -> Bool,
                                   log: @escaping (String) -> Void,
                                   failure: @escaping (String) -> Void) {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("Disableton-aggiornamento-\(UUID().uuidString)")
        var request = URLRequest(url: release.appZipURL, timeoutInterval: 120)
        request.setValue("Disableton-app", forHTTPHeaderField: "User-Agent")
        URLSession.shared.downloadTask(with: request) { location, response, error in
            func fail(_ message: String) { DispatchQueue.main.async { failure(message) } }
            guard let location, error == nil, (response as? HTTPURLResponse)?.statusCode == 200 else {
                return fail("Download non riuscito: \(error?.localizedDescription ?? "risposta inattesa")")
            }
            do {
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let zip = work.appendingPathComponent("Disableton.zip")
                try FileManager.default.moveItem(at: location, to: zip)
                let unzipped = work.appendingPathComponent("estratto")
                guard run("/usr/bin/ditto", ["-x", "-k", zip.path, unzipped.path]) == 0 else {
                    return fail("Archivio non valido")
                }
                let newApp = unzipped.appendingPathComponent("Disableton.app")
                guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")),
                      info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                      (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init(string:)) == release.version
                else {
                    return fail("Il file scaricato non è la versione attesa di Disableton")
                }
                guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path]) == 0 else {
                    return fail("La firma dell'app scaricata non è valida")
                }
                DispatchQueue.main.async {
                    // Ricontrollo finale: se nel frattempo è partita la musica, non si chiude l'app.
                    guard canInstall() else {
                        failure("Installazione rimandata: Disableton sta suonando. Riprova a riproduzione ferma.")
                        return
                    }
                    log("Aggiornamento \(release.version) scaricato e verificato: installazione")
                    install(newApp: newApp, work: work, failure: failure)
                }
            } catch {
                fail("Aggiornamento non riuscito: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Uno script separato attende la chiusura dell'app, sostituisce il bundle e la riapre.
    private static func install(newApp: URL, work: URL, failure: (String) -> Void) {
        let current = Bundle.main.bundleURL.path
        let backup = current + ".precedente"
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf \(q(backup))
        if mv \(q(current)) \(q(backup)) && mv \(q(newApp.path)) \(q(current)); then
          rm -rf \(q(backup))
        else
          [ -d \(q(backup)) ] && [ ! -d \(q(current)) ] && mv \(q(backup)) \(q(current))
        fi
        xattr -dr com.apple.quarantine \(q(current)) 2>/dev/null
        open \(q(current))
        rm -rf \(q(work.path))
        """
        let scriptURL = work.appendingPathComponent("installa.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [scriptURL.path]
            try process.run()
        } catch {
            failure("Installazione non riuscita: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
#endif
