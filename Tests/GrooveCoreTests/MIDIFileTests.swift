import XCTest
@testable import GrooveCore

func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
func be32(_ v: Int) -> [UInt8] { [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }

func smf(ppq: Int, tracks: [[UInt8]]) -> [UInt8] {
    var b = Array("MThd".utf8) + be32(6) + be16(tracks.count > 1 ? 1 : 0) + be16(tracks.count) + be16(ppq)
    for t in tracks { b += Array("MTrk".utf8) + be32(t.count) + t }
    return b
}

final class MIDIFileTests: XCTestCase {
    /// Traccia a 96 PPQ: metro 4/4, tempo 120, kick a 0 (off a 48 con running status e velocity 0),
    /// rullante a 96, off a 288 (delta VLQ a due byte).
    let track: [UInt8] = [
        0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08,
        0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
        0x00, 0x99, 36, 100,
        0x30, 36, 0,
        0x30, 38, 90,
        0x81, 0x40, 0x89, 38, 0,
        0x00, 0xFF, 0x2F, 0x00,
    ]

    func testParsesHeaderMetaAndRunningStatus() throws {
        let file = try MIDIFile(bytes: smf(ppq: 96, tracks: [track]))
        XCTAssertEqual(file.format, 0)
        XCTAssertEqual(file.ticksPerQuarter, 96)
        XCTAssertEqual(file.timeSignature, TimeSignature(4, 4))
        XCTAssertEqual(file.tempoBPM!, 120, accuracy: 0.001)

        let channel = file.tracks[0].compactMap { e -> (Int, MIDIMessage)? in
            if case let .channel(m) = e.kind { return (e.tick, m) }
            return nil
        }
        XCTAssertEqual(channel.count, 4)
        XCTAssertEqual(channel[0].0, 0)
        XCTAssertEqual(channel[0].1, .noteOn(channel: 9, note: 36, velocity: 100))
        XCTAssertEqual(channel[1].0, 48)
        XCTAssertEqual(channel[1].1, .noteOff(channel: 9, note: 36, velocity: 0))
        XCTAssertEqual(channel[2].0, 96)
        XCTAssertEqual(channel[2].1, .noteOn(channel: 9, note: 38, velocity: 90))
        XCTAssertEqual(channel[3].0, 288)
    }

    func testRejectsNonMIDI() {
        XCTAssertThrowsError(try MIDIFile(bytes: Array("ciao, non sono un file MIDI".utf8)))
    }

    func testGrooveImportScalesTicksAndComputesLength() throws {
        let file = try MIDIFile(bytes: smf(ppq: 96, tracks: [track]))
        let groove = try Groove(midiFile: file, name: "prova")
        XCTAssertEqual(groove.lengthTicks, 3840) // una battuta in 4/4 a 960 PPQ
        XCTAssertEqual(groove.noteOnCount, 2)
        XCTAssertEqual(groove.events.first?.tick, 0)
        XCTAssertEqual(groove.events.first?.kind, .noteOn(note: 36, velocity: 100))
        XCTAssertTrue(groove.events.contains(GrooveEvent(tick: 960, kind: .noteOn(note: 38, velocity: 90))))
        XCTAssertTrue(groove.events.contains(GrooveEvent(tick: 2880, kind: .noteOff(note: 38))))
        XCTAssertEqual(groove.noteHistogram[36], 1)
    }

    func testGrooveImportTrimsLeadingEmptyBar() throws {
        // Prima nota alla battuta 2 (tick 384 a 96 PPQ), ultima nella battuta 3.
        let t: [UInt8] = [
            0x83, 0x00, 0x99, 36, 100,   // delta 384
            0x60, 0x89, 36, 0,           // delta 96
            0x83, 0x00, 0x99, 38, 100,   // delta 384 → tick 864 (battuta 3)
            0x00, 0xFF, 0x2F, 0x00,
        ]
        let file = try MIDIFile(bytes: smf(ppq: 96, tracks: [t]))
        let groove = try Groove(midiFile: file, name: "trim")
        XCTAssertEqual(groove.events.first?.tick, 0)
        XCTAssertEqual(groove.lengthTicks, 2 * 3840)

        let untrimmed = try Groove(midiFile: file, name: "no-trim", options: GrooveImportOptions(trimLeadingEmptyBars: false))
        XCTAssertEqual(untrimmed.events.first?.tick, 3840)
        XCTAssertEqual(untrimmed.lengthTicks, 3 * 3840)
    }

    func testForcedLengthAndNoteMap() throws {
        let file = try MIDIFile(bytes: smf(ppq: 96, tracks: [track]))
        let map = NoteMap(name: "test", mapping: [36: 35, 38: -1])
        let groove = try Groove(midiFile: file, name: "map", options: GrooveImportOptions(lengthBars: 2, noteMap: map))
        XCTAssertEqual(groove.lengthTicks, 7680)
        XCTAssertEqual(groove.noteHistogram, [35: 1])
    }

    func testEmptyFileThrows() throws {
        let t: [UInt8] = [0x00, 0xFF, 0x2F, 0x00]
        let file = try MIDIFile(bytes: smf(ppq: 96, tracks: [t]))
        XCTAssertThrowsError(try Groove(midiFile: file, name: "vuoto"))
    }

    func testUMPRoundTrip() {
        let messages: [MIDIMessage] = [
            .noteOn(channel: 15, note: 36, velocity: 100),
            .controlChange(channel: 15, controller: 82, value: 127),
            .programChange(channel: 15, program: 4),
            .timingClock, .start, .stop, .continuePlayback,
            .songPosition(beats: 300),
        ]
        let words = messages.compactMap { UMP.word(for: $0) }
        XCTAssertEqual(words.count, messages.count)
        XCTAssertEqual(UMP.word(for: .noteOn(channel: 9, note: 36, velocity: 100)), 0x2099_2464)
        XCTAssertEqual(UMP.messages(from: words), messages)
    }

    func testNoteNames() {
        XCTAssertEqual(NoteName.korg(60), "C4")
        XCTAssertEqual(NoteName.korg(36), "C2")
        XCTAssertEqual(NoteName.korg(49), "C#3")
    }
}
