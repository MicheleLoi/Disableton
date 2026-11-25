#if canImport(SwiftUI) && os(macOS)
import Foundation
import GrooveCore
import MIDIHost

/// Mappe delle note degli strumenti (es. un kit di Analog Lab che non segue il General MIDI).
extension AppModel {
    /// Mappa scelta per la destinazione del suono attuale.
    var activeNoteMapID: UUID? {
        get { library.performance.noteMapIDs[library.performance.soundOutput.rawValue] }
        set { library.performance.noteMapIDs[library.performance.soundOutput.rawValue] = newValue }
    }

    /// Crea una mappa vuota (= General MIDI), la rende attiva e la restituisce.
    @discardableResult
    func newNoteMap() -> UUID {
        let map = NoteMap(name: "Nuova mappa \(library.noteMaps.count + 1)", mapping: [:])
        library.noteMaps.append(map)
        activeNoteMapID = map.id
        log.log("Mappa delle note creata")
        return map.id
    }

    func duplicateNoteMap(_ id: UUID) {
        guard let original = library.noteMaps.first(where: { $0.id == id }) else { return }
        let copy = NoteMap(name: original.name + " (copia)", mapping: original.mapping)
        library.noteMaps.append(copy)
        activeNoteMapID = copy.id
    }

    func deleteNoteMap(_ id: UUID) {
        library.noteMaps.removeAll { $0.id == id }
        for (key, value) in library.performance.noteMapIDs where value == id {
            library.performance.noteMapIDs[key] = nil
        }
        log.log("Mappa delle note eliminata")
    }

    func noteMap(_ id: UUID) -> NoteMap? {
        library.noteMaps.first { $0.id == id }
    }

    func renameNoteMap(_ id: UUID, to name: String) {
        guard let i = library.noteMaps.firstIndex(where: { $0.id == id }) else { return }
        library.noteMaps[i].name = name
    }

    /// Nota dello strumento per una nota dei groove (nil = non suonare).
    func target(for note: Int, in id: UUID) -> Int? {
        noteMap(id)?.target(for: note) ?? note
    }

    func setTarget(_ target: Int?, for note: Int, in id: UUID) {
        guard let i = library.noteMaps.firstIndex(where: { $0.id == id }) else { return }
        library.noteMaps[i].setTarget(target, for: note)
    }

    /// Note usate dai groove della libreria (le righe dell'editor).
    var notesUsedByGrooves: [Int] {
        library.usedNotes { groove(for: $0) }.map(Int.init)
    }

    /// Suona una nota sullo strumento così com'è (per scoprire cosa c'è su ogni tasto).
    func playInstrumentNote(_ note: Int) {
        guard (0...127).contains(note) else { return }
        guard !isKromePlaying else {
            errorMessage = "Il Krome sta suonando: ferma prima il suo sequencer."
            return
        }
        hostForTesting?.playTestNote(UInt8(note))
    }

    /// Suona la nota dei groove passando dalla mappa: si sente quello che sentirai suonando.
    func playMappedNote(_ note: Int, in id: UUID) {
        guard let target = target(for: note, in: id) else { return }
        playInstrumentNote(target)
    }

    /// MIDI Learn per una riga: il prossimo tasto premuto su una tastiera collegata diventa la
    /// nota dello strumento per quel suono.
    func learnTarget(for note: Int, in id: UUID) {
        learnRawNote { [weak self] played in
            self?.setTarget(played, for: note, in: id)
            self?.showNotice("\(DrumNames.gm(UInt8(note)) ?? "Nota \(note)") → \(NoteName.korg(UInt8(played))) (\(played))")
        }
    }
}
#endif
