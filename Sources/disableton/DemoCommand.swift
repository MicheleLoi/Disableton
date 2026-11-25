import Foundation
import GrooveCore
import TestMaterial

/// `disableton demo --export cartella`: scrive i groove di prova come file .mid.
/// `disableton demo [--dir cartella]`: (sviluppo) aggiunge groove e brani di prova a una libreria.
func runDemo(_ argv: [String]) throws {
    let args = try Args(argv)
    if let folder = args.value("export") {
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for groove in TestGrooves.grooves() {
            let file = url.appendingPathComponent("\(groove.name).mid")
            try groove.midiData().write(to: file)
            print("Scritto \(file.path)")
        }
        return
    }
    let root = args.value("dir").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LibraryStore.defaultRoot
    let store = try LibraryStore(root: root)
    let added = try store.installTestGrooves()
    try store.save()
    print("Aggiunti \(added) brani di prova in \(root.path)")
    printLibrary(store.library)
}
