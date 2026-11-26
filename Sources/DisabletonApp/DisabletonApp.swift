#if canImport(SwiftUI) && os(macOS)
import AppKit
import SwiftUI

@main
struct DisabletonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Disableton") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Controlla aggiornamenti…") { model.checkForUpdates(userInitiated: true) }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Impostazioni…") {
                    model.refreshPorts()
                    model.showSettings = true
                }
                .keyboardShortcut(",")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Annulla") { model.undo() }
                    .keyboardShortcut("z")
                    .disabled(!model.canUndo)
                Button("Ripeti") { model.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canRedo)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Elimina selezione") { model.deleteSelection() }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            CommandMenu("Riproduzione") {
                Button("Prova senza workstation") { model.startInternalClock() }
                    .keyboardShortcut("r")
                    .disabled(model.isPlaying || model.selectedSongIndex == nil)
                Button("Stop") { model.stopPlayback() }
                    .keyboardShortcut(".")
                    .disabled(model.stopLabel == nil)
                Button("Panic (silenzio immediato)") { model.panic() }
                    .keyboardShortcut(".", modifiers: [.command, .shift])
            }
            CommandMenu("Vista") {
                Button("Preparazione") { model.mode = .prep }.keyboardShortcut("1")
                Button("Comandi") { model.mode = .commands }.keyboardShortcut("2")
                Button("Palco") { model.mode = .stage }.keyboardShortcut("3")
            }
            CommandGroup(replacing: .help) {
                Button("Connecting a DAW (example: REAPER)…") { model.openDAWHelp() }
                Button("Element: plugin instruments without a DAW…") { model.openElementHelp() }
                Button("Fills, endings and groove behaviour…") { model.openGrooveHelp() }
                Divider()
                Button("Segnala un problema…") { model.openReport() }
                Button("Mostra il registro") { model.revealLog() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Necessario quando l'app è avviata come eseguibile (swift run) e non come bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Chiudere la finestra non ferma la musica: l'app resta attiva e la finestra si riapre
    /// cliccando l'icona nel Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// ⌘Q mentre suona: chiede conferma.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = AppModel.shared, model.isPlaying else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Disableton sta suonando"
        alert.informativeText = "Chiudendo l'app la batteria si ferma subito. Chiudere comunque?"
        alert.addButton(withTitle: "Non chiudere")
        alert.addButton(withTitle: "Chiudi")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

#else

@main
enum DisabletonAppUnsupported {
    static func main() {
        print("Disableton è un'app per macOS.")
    }
}

#endif
