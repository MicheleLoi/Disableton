import XCTest
@testable import GrooveCore
import TestMaterial

final class DemoAndWriterTests: XCTestCase {
    func testWriterRoundTrip() throws {
        for groove in TestGrooves.grooves() {
            let file = try MIDIFile(data: groove.midiData())
            XCTAssertEqual(file.ticksPerQuarter, Groove.ppq)
            XCTAssertEqual(file.timeSignature, groove.timeSignature, groove.name)
            XCTAssertEqual(file.tempoBPM ?? 0, 120, accuracy: 0.01)
            let back = try Groove(midiFile: file, name: groove.name)
            XCTAssertEqual(back.lengthTicks, groove.lengthTicks, groove.name)
            XCTAssertEqual(back.events, groove.events, groove.name)
        }
    }

    func testVLQ() {
        XCTAssertEqual(MIDIFileWriter.vlq(0), [0x00])
        XCTAssertEqual(MIDIFileWriter.vlq(127), [0x7F])
        XCTAssertEqual(MIDIFileWriter.vlq(128), [0x81, 0x00])
        XCTAssertEqual(MIDIFileWriter.vlq(0x0FFFFFFF), [0xFF, 0xFF, 0xFF, 0x7F])
    }

    func testDemoSongsAreComplete() {
        let songs = TestGrooves.engineSongs()
        XCTAssertEqual(songs.count, TestGrooves.songs.count)
        for (song, template) in zip(songs, TestGrooves.songs) {
            XCTAssertEqual(song.slots.count, template.slots.count, song.name)
            for slot in song.slots {
                XCTAssertEqual(slot.groove.timeSignature, song.timeSignature, "\(song.name): \(slot.name)")
                XCTAssertGreaterThan(slot.groove.noteOnCount, 0)
            }
        }
    }

    func testInstallTestGroovesIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root)
        XCTAssertEqual(try store.installTestGrooves(), TestGrooves.songs.count)
        XCTAssertEqual(try store.installTestGrooves(), 0)
        XCTAssertEqual(store.library.grooves.count, TestGrooves.grooves().count)
        let songs = try store.engineSongs()
        XCTAssertEqual(songs[0].slots.map { $0.mode }, [.loop, .loop, .oneShotReturn, .oneShotStop])
        XCTAssertEqual(songs[0].autoStartSlot, 0)
    }

    func testOldSettingsDecodeWithDefaults() throws {
        let json = #"{"inputFilter":"WORKSTATION","latencyMs":3}"#
        let s = try JSONDecoder().decode(PerformanceSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.soundOutput, .virtualPort)
        XCTAssertNil(s.destinationFilter)
        XCTAssertEqual(s.internalBPM, 120)
        // Valore della porta virtuale salvato dalle versioni precedenti.
        let legacy = try JSONDecoder().decode(PerformanceSettings.self, from: Data(#"{"soundOutput":"ezdrummer"}"#.utf8))
        XCTAssertEqual(legacy.soundOutput, .virtualPort)
    }
}
