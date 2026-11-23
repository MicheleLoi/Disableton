import Foundation
import GrooveCore

/// `disableton inspect <file.mid> [--bars N] [--meter 4/4] [--no-trim]`
func runInspect(_ argv: [String]) throws {
    let args = try Args(argv, flags: ["no-trim"])
    let path = try args.positional(0, "il file MIDI da analizzare")
    let url = URL(fileURLWithPath: path)
    let file = try MIDIFile(contentsOf: url)
    let options = GrooveImportOptions(lengthBars: try args.int("bars"),
                                      trimLeadingEmptyBars: !args.flag("no-trim"),
                                      timeSignature: try args.timeSignature("meter"))
    let groove = try Groove(midiFile: file, name: url.deletingPathExtension().lastPathComponent, options: options)

    print("File:            \(url.lastPathComponent)")
    print("Formato SMF:     \(file.format), \(file.tracks.count) tracce, \(file.ticksPerQuarter) tick/quarto")
    if !file.trackNames.isEmpty { print("Nomi tracce:     \(file.trackNames.joined(separator: ", "))") }
    print("Tempo nel file:  \(file.tempoBPM.map { String(format: "%.2f BPM", $0) } ?? "non indicato")")
    print("Metro nel file:  \(file.timeSignature?.description ?? "non indicato (uso 4/4)")")

    // Posizione delle note nel file originale, per riconoscere battute vuote iniziali.
    var firstOn: Int?
    for track in file.tracks {
        for e in track {
            if case .channel(.noteOn(_, _, _)) = e.kind { firstOn = min(firstOn ?? e.tick, e.tick) }
        }
    }
    if let firstOn {
        let beats = Double(firstOn) / Double(file.ticksPerQuarter)
        print(String(format: "Prima nota:      al quarto %.3f del file originale", beats))
    }

    print("")
    print("Groove importato:")
    print("  Metro:         \(groove.timeSignature)")
    print(String(format: "  Lunghezza:     %.2f battute (%d tick a %d PPQ)", groove.lengthBars, groove.lengthTicks, Groove.ppq))
    print("  Colpi:         \(groove.noteOnCount)")
    if groove.droppedEventCount > 0 {
        print("  Scartati:      \(groove.droppedEventCount) eventi oltre la fine")
    }
    // Colpi negli ultimi 1/64 prima della fine: possibili anticipi sul battere successivo.
    let pickupZone = Groove.ppq / 16
    let pickups = groove.events.filter { e in
        if case .noteOn = e.kind { return e.tick >= groove.lengthTicks - pickupZone }
        return false
    }
    if !pickups.isEmpty {
        print("  Anticipi:      \(pickups.count) colpi negli ultimi \(pickupZone) tick (suonati in anticipo sul battere)")
    }

    print("")
    print("Note usate (nomi General MIDI, solo indicativi per EZdrummer):")
    for (note, count) in groove.noteHistogram.sorted(by: { $0.key < $1.key }) {
        let name = DrumNames.gm(note) ?? "-"
        print("  " + pad(String(note), 3, left: true) + "  " + pad(NoteName.korg(note), 5) + " " + pad(name, 20) + " " + pad(String(count), 5, left: true) + " colpi")
    }
}

func pad(_ s: String, _ width: Int, left: Bool = false) -> String {
    guard s.count < width else { return s }
    let fill = String(repeating: " ", count: width - s.count)
    return left ? fill + s : s + fill
}
