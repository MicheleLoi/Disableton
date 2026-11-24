import XCTest
@testable import GrooveCore

let clock120: UInt64 = 20_833_333 // ns per impulso a 120 BPM

final class ClockFollowerTests: XCTestCase {
    func testSteadyTempo() {
        let f = ClockFollower()
        let t0: UInt64 = 1_000_000_000
        f.start()
        for i in 0..<48 { f.clock(at: t0 + UInt64(i) * clock120) }
        XCTAssertEqual(f.tempoBPM!, 120, accuracy: 0.01)
        XCTAssertEqual(f.lastSongTick, 47 * 40)
        let beat2 = f.time(forSongTick: 960)!
        XCTAssertEqual(Double(beat2), Double(t0 + 24 * clock120), accuracy: 50_000)
        XCTAssertEqual(f.songTick(atTime: t0 + 30 * clock120)!, 1200, accuracy: 0.5)
        // Previsione tra due impulsi.
        let half = f.time(forSongTick: 47 * 40 + 20)!
        XCTAssertEqual(Double(half), Double(t0 + 47 * clock120 + clock120 / 2), accuracy: 50_000)
    }

    func testJitterIsSmoothed() {
        let f = ClockFollower()
        let t0: UInt64 = 5_000_000_000
        var seed: UInt64 = 12345
        f.start()
        for i in 0..<96 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let jitter = Int64(seed >> 33) % 2_000_001 - 1_000_000 // ±1 ms
            f.clock(at: UInt64(Int64(t0 + UInt64(i) * clock120) + jitter))
        }
        XCTAssertEqual(f.tempoBPM!, 120, accuracy: 1.0)
        let predicted = f.time(forSongTick: Double(96 * 40))!
        XCTAssertEqual(Double(predicted), Double(t0 + 96 * clock120), accuracy: 1_000_000)
    }

    func testFollowsTempoChange() {
        let f = ClockFollower()
        var t: UInt64 = 1_000_000_000
        f.start()
        for _ in 0..<48 { f.clock(at: t); t += clock120 }
        let interval90: UInt64 = 27_777_778
        for _ in 0..<48 { f.clock(at: t); t += interval90 }
        XCTAssertEqual(f.tempoBPM!, 90, accuracy: 0.05)
    }

    func testContinueFromSongPosition() {
        let f = ClockFollower()
        f.setSongPosition(sixteenths: 16)
        f.continuePlayback()
        f.clock(at: 1_000_000_000)
        XCTAssertEqual(f.lastSongTick, 16 * 6 * 40)
    }

    func testStopThenContinueResumesPosition() {
        let f = ClockFollower()
        f.start()
        for i in 0..<48 { f.clock(at: 1_000_000_000 + UInt64(i) * clock120) }
        f.stop()
        XCTAssertNil(f.lastSongTick)
        XCTAssertEqual(f.resumeClock, 48)
        f.continuePlayback()
        f.clock(at: 3_000_000_000)
        XCTAssertEqual(f.lastSongTick, 48 * 40)
    }

    func testPauseWithoutClockDoesNotSkewTiming() {
        let f = ClockFollower()
        let t0: UInt64 = 1_000_000_000
        f.start()
        for i in 0..<48 { f.clock(at: t0 + UInt64(i) * clock120) }
        f.stop()
        f.setSongPosition(sixteenths: 32)
        f.continuePlayback()
        let t1 = t0 + 3_000_000_000 // ripartenza dopo una pausa senza clock
        f.clock(at: t1)
        XCTAssertEqual(f.lastSongTick, 32 * 6 * 40)
        XCTAssertEqual(f.tempoBPM!, 120, accuracy: 0.01)
        let next = f.time(forSongTick: Double(32 * 6 * 40 + 960))!
        XCTAssertEqual(Double(next), Double(t1 + 24 * clock120), accuracy: 50_000)
        for i in 1..<10 { f.clock(at: t1 + UInt64(i) * clock120) }
        XCTAssertEqual(f.tempoBPM!, 120, accuracy: 0.01)
    }

    func testRecoversMissedClocks() {
        var config = ClockFollower.Configuration()
        config.recoverMissedClocks = true
        let f = ClockFollower(configuration: config)
        let t0: UInt64 = 1_000_000_000
        f.start()
        for i in 0..<30 where !(10...12).contains(i) {
            f.clock(at: t0 + UInt64(i) * clock120)
        }
        XCTAssertEqual(f.lastSongTick, 29 * 40)
    }

    func testNothingBeforeFirstClockAfterStart() {
        let f = ClockFollower()
        for i in 0..<24 { f.clock(at: 1_000_000_000 + UInt64(i) * clock120) } // clock a trasporto fermo
        f.start()
        XCTAssertNil(f.lastSongTick)
        XCTAssertNil(f.time(forSongTick: 0))
        f.clock(at: 1_000_000_000 + 24 * clock120)
        XCTAssertEqual(f.lastSongTick, 0)
        XCTAssertEqual(f.tempoBPM!, 120, accuracy: 0.01) // tempo già noto dal clock a trasporto fermo
    }
}

final class ControlMapTests: XCTestCase {
    func testDefaultBindings() {
        let map = ControlMap.default
        XCTAssertEqual(map.action(for: .noteOn(channel: 15, note: 36, velocity: 100)), .triggerSlot(0))
        XCTAssertEqual(map.action(for: .noteOn(channel: 15, note: 38, velocity: 1)), .triggerSlot(2))
        XCTAssertEqual(map.action(for: .noteOn(channel: 15, note: 48, velocity: 100)), .fill)
        XCTAssertEqual(map.action(for: .programChange(channel: 15, program: 5)), .selectSong(5))
        XCTAssertEqual(map.action(for: .controlChange(channel: 15, controller: 82, value: 127)), .fill)
        XCTAssertNil(map.action(for: .controlChange(channel: 15, controller: 82, value: 0)))
        XCTAssertNil(map.action(for: .noteOn(channel: 0, note: 36, velocity: 100))) // altro canale
        XCTAssertNil(map.action(for: .noteOff(channel: 15, note: 36, velocity: 0)))
    }

    func testActionStringsRoundTrip() throws {
        let actions: [ControlAction] = [.selectSong(2), .selectSongFromProgram, .triggerSlot(0), .fill, .panic, .nextSlot]
        for a in actions { XCTAssertEqual(ControlAction(string: a.description), a) }
        XCTAssertEqual(ControlAction(string: "triggerSlot:1"), .triggerSlot(0))
        let data = try JSONEncoder().encode(ControlMap.default)
        XCTAssertEqual(try JSONDecoder().decode(ControlMap.self, from: data), ControlMap.default)
    }

    func testLearn() {
        let b = ControlBinding.learn(from: .controlChange(channel: 0, controller: 64, value: 127), action: .fill)
        XCTAssertEqual(b, ControlBinding(kind: .controlChange, channel: 1, number: 64, action: .fill))
    }
}

final class PlaybackControllerTests: XCTestCase {
    func testSendsGrooveInTimeWithClock() {
        let verse = groove("strofa", [(0, 36), (960, 38)])
        var sent: [(MIDIMessage, UInt64)] = []
        let controller = PlaybackController(songs: [EngineSong(name: "A", slots: [EngineSlot(name: "A", groove: verse)])]) {
            sent.append(($0, $1))
        }
        let t0: UInt64 = 10_000_000_000
        // Clock a trasporto fermo, poi Start e un quarto e mezzo di impulsi.
        for i in 0..<24 { controller.handle(.timingClock, at: t0 + UInt64(i) * clock120, now: t0 + UInt64(i) * clock120) }
        let startTime = t0 + 24 * clock120
        controller.handle(.start, at: startTime - 1_000_000, now: startTime - 1_000_000)
        for i in 0..<36 {
            let t = startTime + UInt64(i) * clock120
            controller.handle(.timingClock, at: t, now: t)
        }
        let notes = sent.filter { if case .noteOn = $0.0 { return true }; return false }
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[0].0, .noteOn(channel: 9, note: 36, velocity: 100))
        XCTAssertEqual(Double(notes[0].1), Double(startTime), accuracy: 100_000)
        XCTAssertEqual(notes[1].0, .noteOn(channel: 9, note: 38, velocity: 100))
        XCTAssertEqual(Double(notes[1].1), Double(startTime + 24 * clock120), accuracy: 100_000)
    }

    func testCommandsFromKromeSelectSongAndSlot() {
        let a = groove("a", [(0, 36)])
        let b = groove("b", [(0, 42)])
        let songs = [EngineSong(name: "Uno", slots: [EngineSlot(name: "a", groove: a)]),
                     EngineSong(name: "Due", slots: [EngineSlot(name: "a", groove: a), EngineSlot(name: "b", groove: b)])]
        let controller = PlaybackController(songs: songs) { _, _ in }
        controller.handle(.programChange(channel: 15, program: 1), at: 0, now: 0)
        XCTAssertEqual(controller.currentSongIndex, 1)
        controller.handle(.noteOn(channel: 15, note: 37, velocity: 90), at: 0, now: 0)
        XCTAssertEqual(controller.status.armedSlot, 1)
    }

    func testFreewheelStopsWhenClockDisappears() {
        let verse = groove("strofa", [(0, 36), (960, 38), (1920, 36), (2880, 38)])
        var count = 0
        let controller = PlaybackController(songs: [EngineSong(name: "A", slots: [EngineSlot(name: "A", groove: verse)])]) { m, _ in
            if case .noteOn = m { count += 1 }
        }
        let t0: UInt64 = 1_000_000_000
        controller.handle(.start, at: t0, now: t0)
        for i in 0..<24 { let t = t0 + UInt64(i) * clock120; controller.handle(.timingClock, at: t, now: t) }
        // Il clock si ferma: si continua al massimo per una battuta (4 quarti), poi silenzio.
        controller.process(now: t0 + 60 * 1_000_000_000)
        XCTAssertEqual(count, 5) // colpi fino al tick 23*40 + 3840 = 4760: 0, 960, 1920, 2880, 3840
    }
}
