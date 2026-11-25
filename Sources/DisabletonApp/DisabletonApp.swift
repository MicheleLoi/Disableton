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
                .frame(minWidth: 1100, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Controlla aggiornamenti…") { model.checkForUpdates(userInitiated: true) }
            }
            CommandGroup(replacing: .help) {
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
