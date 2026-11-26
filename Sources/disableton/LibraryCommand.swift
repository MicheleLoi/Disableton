import Foundation
import GrooveCore

/// Gestione della libreria da riga di comando (in attesa dell'interfaccia grafica).
func runLibrary(_ argv: [String]) throws {
    guard let sub = argv.first else { throw CLIError("specificare un sottocomando: init, import, add-song, assign, show") }
    let args = try Args(Array(argv.dropFirst()))
    let root = args.value("dir").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? LibraryStore.defaultRoot
    let store = try LibraryStore(root: root)

    switch sub {
    case "init":
        try store.save()
        print("Libreria pronta in \(root.path)")

    case "import":
        guard !args.positionals.isEmpty else { throw CLIError("indicare uno o più file .mid") }
        let single = args.positionals.count == 1
        for path in args.positionals {
            let url = URL(fileURLWithPath: path)
            let record = try store.importGroove(from: url, name: single ? args.value("name") : nil, source: .user,
                                                lengthBars: try args.int("bars"),
                                                timeSignature: try args.timeSignature("meter"))
            let groove = try store.loadGroove(record)
            let bars = String(format: "%.2f", groove.lengthBars)
            print("Importato \"\(record.name)\": \(bars) battute in \(groove.timeSignature), \(groove.noteOnCount) colpi")
        }
        try store.save()

    case "add-song":
        let name = try args.positional(0, "il nome del brano")
        let song = SongRecord(name: name, timeSignature: try args.timeSignature("meter") ?? .fourFour)
        store.library.songs.append(song)
        try store.save()
        print("Aggiunto brano \(store.library.songs.count): \(name) (\(song.timeSignature))")

    case "assign":
        let songNumber = Int(try args.positional(0, "il numero del brano")) ?? 0
        let grooveName = try args.positional(1, "il nome del groove")
        guard store.library.songs.indices.contains(songNumber - 1) else { throw LibraryError.songNotFound(songNumber) }
        guard let groove = store.library.groove(named: grooveName) else { throw LibraryError.grooveNotFound(grooveName) }
        let mode = try parseEnum(SlotMode.self, args.value("mode"), default: .loop, option: "mode")
        let quantize = try parseEnum(Quantize.self, args.value("quantize"), default: .bar, option: "quantize")
        let slot = SlotRecord(name: args.value("slot-name"), grooveID: groove.id, mode: mode, quantize: quantize)
        store.library.songs[songNumber - 1].slots.append(slot)
        try store.save()
        let count = store.library.songs[songNumber - 1].slots.count
        print("Brano \(songNumber), slot \(count): \(groove.name) [\(mode.rawValue), cambio a \(quantize.rawValue)]")

    case "show":
        printLibrary(store.library)
        print("\nCartella: \(root.path)")

    default:
        throw CLIError("sottocomando sconosciuto: \(sub)")
    }
}

func parseEnum<T: RawRepresentable & CaseIterable>(_ type: T.Type, _ value: String?, default def: T, option: String) throws -> T
where T.RawValue == String {
    guard let value else { return def }
    guard let v = T(rawValue: value) else {
        let allowed = T.allCases.map { $0.rawValue }.joined(separator: ", ")
        throw CLIError("valore non valido per --\(option): \(value) (ammessi: \(allowed))")
    }
    return v
}

func printLibrary(_ library: Library) {
    print("Groove (\(library.grooves.count)):")
    for g in library.grooves {
        print("  - \(g.name)\(g.lengthBars.map { ", \($0) battute" } ?? "")")
    }
    print("\nBrani (\(library.songs.count)):")
    for (i, song) in library.songs.enumerated() {
        let auto = song.autoStartSlot.map { "parte con lo slot \($0 + 1)" } ?? "attende un comando"
        print("  \(i + 1). \(song.name) (\(song.timeSignature), \(auto)) — Program Change \(i)")
        for (j, slot) in song.slots.enumerated() {
            let grooveName = library.groove(id: slot.grooveID)?.name ?? "??? groove mancante"
            let note = 36 + j
            let key = j < 12 ? " — nota \(note) (\(NoteName.korg(UInt8(note))))" : ""
            print("       slot \(j + 1): \(slot.name ?? grooveName) [\(slot.mode.rawValue), cambio a \(slot.quantize.rawValue)]\(key)")
        }
    }
    print("\nCanale MIDI della batteria in uscita: \(library.outputChannel)")
}
