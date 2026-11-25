import XCTest
@testable import GrooveCore

final class NoteMapTests: XCTestCase {
    func testEngineAppliesNoteMapAndDropsSilencedNotes() {
        let g = groove("g", [(0, 36), (960, 38), (1920, 42)], offs: [(100, 36)])
        let engine = GrooveEngine()
        engine.noteMap = NoteMap(name: "kit", mapping: [36: 24, 42: -1])
        engine.load(song: EngineSong(name: "A", slots: [EngineSlot(name: "g", groove: g)]))
        engine.transportStarted(at: 0)
        let events = engine.render(to: 3840)
        XCTAssertEqual(onsets(events), [[0, 24], [960, 38]])   // 36→24, 38 invariato, 42 eliminato
        XCTAssertTrue(events.contains { $0.message == .noteOff(channel: 9, note: 24, velocity: 0) })
    }

    func testTargetEditing() {
        var map = NoteMap(name: "m", mapping: [:])
        XCTAssertEqual(map.target(for: 36), 36)
        map.setTarget(24, for: 36)
        XCTAssertEqual(map.target(for: 36), 24)
        map.setTarget(nil, for: 42)
        XCTAssertNil(map.target(for: 42))
        map.setTarget(36, for: 36)                     // tornare alla nota originale toglie la voce
        XCTAssertNil(map.mapping[36])
    }

    func testLibraryStoresMapsPerOutput() throws {
        var lib = Library()
        let kit = NoteMap(name: "Analog Lab 808", mapping: [36: 36, 38: 40])
        lib.noteMaps = [kit]
        lib.performance.soundOutput = .ezdrummer
        lib.performance.noteMapIDs[SoundOutput.ezdrummer.rawValue] = kit.id
        XCTAssertEqual(lib.activeNoteMap, kit)
        lib.performance.soundOutput = .builtInSynth
        XCTAssertNil(lib.activeNoteMap)

        let data = try JSONEncoder().encode(lib)
        let back = try JSONDecoder().decode(Library.self, from: data)
        XCTAssertEqual(back, lib)
        // Librerie precedenti, senza mappe, restano leggibili.
        let old = try JSONDecoder().decode(Library.self, from: Data(#"{"songs":[]}"#.utf8))
        XCTAssertTrue(old.noteMaps.isEmpty)
        // Mappe salvate senza identificativo (vecchie importazioni) restano leggibili.
        let legacy = try JSONDecoder().decode(NoteMap.self, from: Data(#"{"name":"x","mapping":{"36":35}}"#.utf8))
        XCTAssertEqual(legacy.map(36), 35)
    }
}
