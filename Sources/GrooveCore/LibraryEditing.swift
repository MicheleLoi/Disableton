import Foundation

/// Operazioni di modifica della libreria usate dall'interfaccia.
/// Mantengono coerente lo slot di avvio quando gli slot vengono spostati o eliminati.
extension Library {
    public func songIndex(id: UUID) -> Int? {
        songs.firstIndex { $0.id == id }
    }

    public func grooveIndex(id: UUID) -> Int? {
        grooves.firstIndex { $0.id == id }
    }

    /// Brani che usano un groove.
    public func songsUsing(grooveID: UUID) -> [String] {
        songs.filter { song in song.slots.contains { $0.grooveID == grooveID } }.map { $0.name }
    }

    /// Nome non ancora usato da altri groove ("Strofa", "Strofa 2", ...).
    public func uniqueGrooveName(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Groove" : trimmed
        guard groove(named: name) != nil else { return name }
        var n = 2
        while groove(named: "\(name) \(n)") != nil { n += 1 }
        return "\(name) \(n)"
    }

    // MARK: - Brani

    @discardableResult
    public mutating func addSong(name: String, timeSignature: TimeSignature = .fourFour) -> UUID {
        let song = SongRecord(name: name, timeSignature: timeSignature)
        songs.append(song)
        return song.id
    }

    public mutating func removeSongs(atOffsets offsets: IndexSet) {
        for i in offsets.sorted(by: >) where songs.indices.contains(i) {
            songs.remove(at: i)
        }
    }

    public mutating func moveSongs(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        songs.moveElements(fromOffsets: offsets, toOffset: destination)
    }

    // MARK: - Slot

    @discardableResult
    public mutating func addSlot(toSong songIndex: Int, grooveID: UUID, mode: SlotMode = .loop,
                                 quantize: Quantize = .bar) -> UUID? {
        guard songs.indices.contains(songIndex) else { return nil }
        let slot = SlotRecord(grooveID: grooveID, mode: mode, quantize: quantize)
        songs[songIndex].slots.append(slot)
        if songs[songIndex].autoStartSlot == nil, mode == .loop, songs[songIndex].slots.count == 1 {
            songs[songIndex].autoStartSlot = 0
        }
        return slot.id
    }

    public mutating func removeSlots(fromSong songIndex: Int, atOffsets offsets: IndexSet) {
        guard songs.indices.contains(songIndex) else { return }
        let autoStartID = autoStartSlotID(song: songIndex)
        for i in offsets.sorted(by: >) where songs[songIndex].slots.indices.contains(i) {
            songs[songIndex].slots.remove(at: i)
        }
        restoreAutoStart(song: songIndex, id: autoStartID)
    }

    public mutating func moveSlots(inSong songIndex: Int, fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard songs.indices.contains(songIndex) else { return }
        let autoStartID = autoStartSlotID(song: songIndex)
        songs[songIndex].slots.moveElements(fromOffsets: offsets, toOffset: destination)
        restoreAutoStart(song: songIndex, id: autoStartID)
    }

    /// Imposta lo slot di avvio (nil = il brano attende un comando).
    public mutating func setAutoStart(song songIndex: Int, slotID: UUID?) {
        guard songs.indices.contains(songIndex) else { return }
        songs[songIndex].autoStartSlot = slotID.flatMap { id in songs[songIndex].slots.firstIndex { $0.id == id } }
    }

    // MARK: - Groove

    /// Rimuove il groove e gli slot che lo usano (il file va eliminato da `LibraryStore`).
    public mutating func removeGroove(id: UUID) {
        grooves.removeAll { $0.id == id }
        for s in songs.indices {
            let autoStartID = autoStartSlotID(song: s)
            songs[s].slots.removeAll { $0.grooveID == id }
            restoreAutoStart(song: s, id: autoStartID)
        }
    }

    // MARK: - Interni

    private func autoStartSlotID(song: Int) -> UUID? {
        guard let i = songs[song].autoStartSlot, songs[song].slots.indices.contains(i) else { return nil }
        return songs[song].slots[i].id
    }

    private mutating func restoreAutoStart(song: Int, id: UUID?) {
        guard let id else {
            if let i = songs[song].autoStartSlot, !songs[song].slots.indices.contains(i) {
                songs[song].autoStartSlot = nil
            }
            return
        }
        // Se lo slot di avvio è stato eliminato si passa al primo groove ripetuto.
        songs[song].autoStartSlot = songs[song].slots.firstIndex { $0.id == id }
            ?? songs[song].slots.firstIndex { $0.mode == .loop }
    }
}

extension Array {
    /// Sposta gli elementi indicati prima della posizione `destination` (semantica di SwiftUI `onMove`).
    public mutating func moveElements(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let valid = offsets.filter { indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.map { self[$0] }
        let before = valid.filter { $0 < destination }.count
        for i in valid.sorted(by: >) { remove(at: i) }
        let target = Swift.min(Swift.max(0, destination - before), count)
        insert(contentsOf: moving, at: target)
    }
}
