import Foundation
import GrooveCore

/// `disableton demo [--dir cartella]`: aggiunge brani e groove dimostrativi alla libreria.
/// `disableton demo --export cartella`: scrive i groove dimostrativi come file .mid.
func runDemo(_ argv: [String]) throws {
    let args = try Args(argv)
    if let folder = args.value("export") {
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for groove in DemoContent.grooves() {
            let file = url.appendingPathComponent("\(groove.name).mid")
            try groove.midiData().write(to: file)
            print("Scritto \(file.path)")
        }
        return
    }
    let root = args.value("dir").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LibraryStore.defaultRoot
    let store = try LibraryStore(root: root)
    let added = try store.installDemoContent()
    try store.save()
    print("Aggiunti \(added) brani dimostrativi in \(root.path)")
    printLibrary(store.library)
}
