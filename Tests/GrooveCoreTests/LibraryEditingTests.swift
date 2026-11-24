import XCTest
@testable import GrooveCore

final class LibraryEditingTests: XCTestCase {
    func makeLibrary() -> (Library, UUID, UUID) {
        let a = GrooveRecord(name: "Strofa", fileName: "a.mid", source: .ezdrummer)
        let b = GrooveRecord(name: "Fill", fileName: "b.mid", source: .user)
        var lib = Library(grooves: [a, b])
        lib.addSong(name: "Uno")
        lib.addSlot(toSong: 0, grooveID: a.id)
        lib.addSlot(toSong: 0, grooveID: b.id, mode: .oneShotReturn)
        lib.addSlot(toSong: 0, grooveID: a.id)
        return (lib, a.id, b.id)
    }

    func testFirstLoopSlotBecomesAutoStart() {
        let (lib, _, _) = makeLibrary()
        XCTAssertEqual(lib.songs[0].autoStartSlot, 0)
        XCTAssertEqual(lib.songs[0].slots.count, 3)
    }

    func testAutoStartFollowsMovedSlot() {
        var (lib, _, _) = makeLibrary()
        let firstID = lib.songs[0].slots[0].id
        lib.moveSlots(inSong: 0, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(lib.songs[0].slots[2].id, firstID)
        XCTAssertEqual(lib.songs[0].autoStartSlot, 2)
    }

    func testRemovingAutoStartSlotFallsBackToFirstLoop() {
        var (lib, _, _) = makeLibrary()
        lib.removeSlots(fromSong: 0, atOffsets: IndexSet(integer: 0))
        XCTAssertEqual(lib.songs[0].slots.count, 2)
        XCTAssertEqual(lib.songs[0].autoStartSlot, 1) // il fill è in posizione 0, il loop in 1
    }

    func testRemoveGrooveRemovesItsSlots() {
        var (lib, a, b) = makeLibrary()
        XCTAssertEqual(lib.songsUsing(grooveID: a), ["Uno"])
        lib.removeGroove(id: a)
        XCTAssertEqual(lib.grooves.map { $0.id }, [b])
        XCTAssertEqual(lib.songs[0].slots.map { $0.grooveID }, [b])
        XCTAssertNil(lib.songs[0].autoStartSlot) // resta solo un fill
    }

    func testSetAutoStart() {
        var (lib, _, _) = makeLibrary()
        lib.setAutoStart(song: 0, slotID: lib.songs[0].slots[2].id)
        XCTAssertEqual(lib.songs[0].autoStartSlot, 2)
        lib.setAutoStart(song: 0, slotID: nil)
        XCTAssertNil(lib.songs[0].autoStartSlot)
    }

    func testUniqueGrooveName() {
        let (lib, _, _) = makeLibrary()
        XCTAssertEqual(lib.uniqueGrooveName("Nuovo"), "Nuovo")
        XCTAssertEqual(lib.uniqueGrooveName("strofa"), "strofa 2")
        XCTAssertEqual(lib.uniqueGrooveName("  "), "Groove")
    }

    func testMoveElementsMatchesOnMoveSemantics() {
        var a = ["A", "B", "C", "D"]
        a.moveElements(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        XCTAssertEqual(a, ["B", "C", "D", "A"])
        a = ["A", "B", "C", "D"]
        a.moveElements(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        XCTAssertEqual(a, ["D", "A", "B", "C"])
        a = ["A", "B", "C", "D"]
        a.moveElements(fromOffsets: IndexSet([0, 2]), toOffset: 2)
        XCTAssertEqual(a, ["B", "A", "C", "D"])
    }

    func testLibraryJSONRoundTripKeepsSettings() throws {
        var (lib, _, _) = makeLibrary()
        lib.performance = PerformanceSettings(inputFilter: "KROME", latencyMs: 4.5, lookaheadMs: 3)
        let data = try JSONEncoder().encode(lib)
        XCTAssertEqual(try JSONDecoder().decode(Library.self, from: data), lib)
        // File scritti da versioni precedenti (senza id degli slot né impostazioni) restano leggibili.
        let old = #"{"songs":[{"name":"X","slots":[{"grooveID":"\#(UUID().uuidString)"}]}]}"#
        let decoded = try JSONDecoder().decode(Library.self, from: Data(old.utf8))
        XCTAssertEqual(decoded.songs[0].slots.count, 1)
        XCTAssertEqual(decoded.performance, PerformanceSettings())
    }

    func testStoreImportCacheAndDelete() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root)
        let track: [UInt8] = [0x00, 0x99, 36, 100, 0x60, 0x89, 36, 0, 0x00, 0xFF, 0x2F, 0x00]
        let record = try store.importGroove(data: Data(smf(ppq: 96, tracks: [track])), name: "Prova", source: .user)
        store.library.addSong(name: "Brano")
        store.library.addSlot(toSong: 0, grooveID: record.id)
        try store.save()

        let reopened = try LibraryStore(root: root)
        let songs = try reopened.engineSongs()
        XCTAssertEqual(songs.first?.slots.first?.groove.noteOnCount, 1)

        try reopened.deleteGroove(id: record.id)
        XCTAssertTrue(reopened.library.grooves.isEmpty)
        XCTAssertTrue(reopened.library.songs[0].slots.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.groovesDirectory.appendingPathComponent(record.fileName).path))
    }
}

final class ClockGeneratorAndLearnTests: XCTestCase {
    func testGeneratorEmitsEachTickOnce() {
        var gen = ClockGenerator(bpm: 120, startTime: 1_000)
        XCTAssertEqual(gen.ticks(upTo: 999), [])
        XCTAssertEqual(gen.ticks(upTo: 1_000), [1_000])
        let next = gen.ticks(upTo: 1_000 + 3 * 20_833_334)
        XCTAssertEqual(next.count, 3)
        XCTAssertEqual(gen.ticks(upTo: 1_000 + 3 * 20_833_334), [])
    }

    func testInternalClockDrivesController() {
        let verse = groove("strofa", [(0, 36), (960, 38)])
        var notes: [(MIDIMessage, UInt64)] = []
        let controller = PlaybackController(songs: [EngineSong(name: "A", slots: [EngineSlot(name: "A", groove: verse)])]) { m, t in
            if case .noteOn = m { notes.append((m, t)) }
        }
        let start: UInt64 = 5_000_000_000
        var gen = ClockGenerator(bpm: 100, startTime: start)
        controller.handle(.start, at: start, now: start)
        var now = start
        while now < start + 700_000_000 { // 0,7 s a 100 BPM: oltre il secondo quarto (0,6 s)
            for t in gen.ticks(upTo: now) { controller.handle(.timingClock, at: t, now: now) }
            controller.process(now: now)
            now += 500_000
        }
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(Double(notes[1].1), Double(start + 600_000_000), accuracy: 200_000)
    }

    func testLearnCapturesNextCommandInsteadOfPerformingIt() {
        let a = groove("a", [(0, 36)])
        let controller = PlaybackController(songs: [EngineSong(name: "A", slots: [EngineSlot(name: "a", groove: a)]),
                                                    EngineSong(name: "B", slots: [EngineSlot(name: "a", groove: a)])]) { _, _ in }
        var learned: MIDIMessage?
        controller.learnCapture = { learned = $0 }
        controller.handle(.timingClock, at: 0, now: 0)          // il clock non viene catturato
        XCTAssertNil(learned)
        controller.handle(.programChange(channel: 15, program: 1), at: 0, now: 0)
        XCTAssertEqual(learned, .programChange(channel: 15, program: 1))
        XCTAssertEqual(controller.currentSongIndex, 0)            // non eseguito
        XCTAssertNil(controller.learnCapture)
        controller.handle(.programChange(channel: 15, program: 1), at: 0, now: 0)
        XCTAssertEqual(controller.currentSongIndex, 1)            // ora sì
        XCTAssertEqual(controller.lastCommand, .programChange(channel: 15, program: 1))
    }
}

final class ReloadWhilePlayingTests: XCTestCase {
    func testSongsReplacedWhilePlayingApplyAtStop() {
        let a = groove("a", [(0, 36)])
        let b = groove("b", [(0, 42)])
        var played: [UInt8] = []
        let controller = PlaybackController(songs: [EngineSong(name: "A", slots: [EngineSlot(name: "a", groove: a)])]) { m, _ in
            if case let .noteOn(_, n, _) = m { played.append(n) }
        }
        let t0: UInt64 = 1_000_000_000
        controller.handle(.start, at: t0, now: t0)
        for i in 0..<2 { let t = t0 + UInt64(i) * clock120; controller.handle(.timingClock, at: t, now: t) }
        controller.replaceSongs([EngineSong(name: "A modificato", slots: [EngineSlot(name: "b", groove: b)])])
        XCTAssertEqual(controller.status.songName, "A")              // il brano in corso non cambia
        for i in 2..<200 { let t = t0 + UInt64(i) * clock120; controller.handle(.timingClock, at: t, now: t) }
        XCTAssertEqual(Set(played), [36])
        controller.handle(.stop, at: t0, now: t0)
        XCTAssertEqual(controller.status.songName, "A modificato")   // effettivo allo Stop
    }
}
