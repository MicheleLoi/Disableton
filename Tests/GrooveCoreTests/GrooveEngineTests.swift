import XCTest
@testable import GrooveCore

let bar = 3840 // una battuta in 4/4 a 960 PPQ

func groove(_ name: String, _ hits: [(Int, UInt8)], bars: Int = 1, offs: [(Int, UInt8)] = []) -> Groove {
    let ons = hits.map { GrooveEvent(tick: $0.0, kind: .noteOn(note: $0.1, velocity: 100)) }
    let offEvents = offs.map { GrooveEvent(tick: $0.0, kind: .noteOff(note: $0.1)) }
    return Groove(name: name, timeSignature: .fourFour, lengthTicks: bars * bar, events: ons + offEvents)
}

/// Solo i Note On, come (tick, nota).
func onsets(_ events: [ScheduledMIDI]) -> [[Int]] {
    events.compactMap { e in
        if case let .noteOn(_, note, _) = e.message { return [e.tick, Int(note)] }
        return nil
    }
}

final class GrooveEngineTests: XCTestCase {
    let verse = groove("strofa", [(0, 36), (960, 38), (1920, 36), (2880, 38)])
    let chorus = groove("ritornello", [(0, 42), (1920, 42)])
    let fill = groove("fill", [(0, 50), (1920, 47)])

    func makeEngine(_ slots: [EngineSlot], autoStart: Int? = 0) -> GrooveEngine {
        let engine = GrooveEngine()
        engine.load(song: EngineSong(name: "test", slots: slots, autoStartSlot: autoStart))
        return engine
    }

    func testLoopsFromStart() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse)])
        engine.transportStarted(at: 0)
        let ev = engine.render(to: 2 * bar)
        XCTAssertEqual(onsets(ev), [[0, 36], [960, 38], [1920, 36], [2880, 38],
                                    [3840, 36], [4800, 38], [5760, 36], [6720, 38]])
        XCTAssertTrue(ev.allSatisfy { if case let .noteOn(ch, _, _) = $0.message { return ch == 9 }; return true })
    }

    func testSwitchHappensAtNextBar() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse), EngineSlot(name: "B", groove: chorus)])
        engine.transportStarted(at: 0)
        var ev = engine.render(to: 1000)
        engine.trigger(slot: 1)
        XCTAssertEqual(engine.pendingSlotIndex, 1)
        ev += engine.render(to: 2 * bar)
        XCTAssertEqual(onsets(ev), [[0, 36], [960, 38], [1920, 36], [2880, 38], [3840, 42], [5760, 42]])
        XCTAssertEqual(engine.playingSlotIndex, 1)
        XCTAssertNil(engine.pendingSlotIndex)
    }

    func testRenderingInSmallChunksGivesSameResult() {
        let a = makeEngine([EngineSlot(name: "A", groove: verse), EngineSlot(name: "F", groove: fill, mode: .oneShotReturn)])
        a.transportStarted(at: 0)
        var chunked: [ScheduledMIDI] = []
        var t = 0
        while t < 4 * bar {
            t += 37
            if t >= 500 && t < 537 { a.triggerFill() }
            chunked += a.render(to: t)
        }
        let b = makeEngine([EngineSlot(name: "A", groove: verse), EngineSlot(name: "F", groove: fill, mode: .oneShotReturn)])
        b.transportStarted(at: 0)
        var whole = b.render(to: 518)
        b.triggerFill()
        whole += b.render(to: t)
        XCTAssertEqual(onsets(chunked), onsets(whole))
    }

    func testFillReturnsToPreviousGroove() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse),
                                 EngineSlot(name: "B", groove: chorus),
                                 EngineSlot(name: "F", groove: fill, mode: .oneShotReturn)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 100)
        engine.trigger(slot: 1)              // ritornello dalla battuta 2
        var ev = engine.render(to: bar + 100)
        engine.triggerFill()                 // fill alla battuta 3
        ev += engine.render(to: 4 * bar)
        XCTAssertEqual(onsets(ev).filter { $0[0] >= bar }, [
            [3840, 42], [5760, 42],          // battuta 2: ritornello
            [7680, 50], [9600, 47],          // battuta 3: fill
            [11520, 42], [13440, 42],        // battuta 4: ritorno al ritornello
        ])
        XCTAssertEqual(engine.playingSlotIndex, 1)
    }

    func testFillThenNextAndEnding() {
        let ending = groove("finale", [(0, 49)])
        let engine = makeEngine([EngineSlot(name: "A", groove: verse),
                                 EngineSlot(name: "F→B", groove: fill, mode: .oneShotNext),
                                 EngineSlot(name: "B", groove: chorus),
                                 EngineSlot(name: "Fine", groove: ending, mode: .oneShotStop)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 10)
        engine.trigger(slot: 1)
        var ev = engine.render(to: 2 * bar + 10)
        XCTAssertEqual(engine.playingSlotIndex, 2) // dopo il fill passa allo slot successivo
        engine.trigger(slot: 3)
        ev += engine.render(to: 6 * bar)
        XCTAssertEqual(onsets(ev).filter { $0[0] >= bar }, [
            [3840, 50], [5760, 47],          // fill
            [7680, 42], [9600, 42],          // ritornello
            [11520, 49],                     // finale, poi silenzio
        ])
        XCTAssertNil(engine.playingSlotIndex)
    }

    func testContinueFromSongPositionKeepsPhase() {
        let two = groove("due battute", [(0, 36), (bar, 38)], bars: 2)
        let engine = makeEngine([EngineSlot(name: "A", groove: two)])
        engine.transportStarted(at: 3 * bar + 1920) // battuta 4, a metà
        let ev = engine.render(to: 6 * bar)
        // Il groove di 2 battute è allineato all'inizio del brano: battuta 5 = inizio ciclo.
        XCTAssertEqual(onsets(ev), [[4 * bar, 36], [5 * bar, 38]])
    }

    func testHangingNotesAreReleasedOnSwitch() {
        let held = groove("tenuto", [(900, 46)], offs: [(1100, 46)])
        let engine = makeEngine([EngineSlot(name: "A", groove: held),
                                 EngineSlot(name: "B", groove: chorus, quantize: .beat)])
        engine.transportStarted(at: 0)
        var ev = engine.render(to: 950)
        engine.trigger(slot: 1) // cambio al battito successivo (960)
        ev += engine.render(to: 2000)
        let atSwitch = ev.filter { $0.tick == 960 }.map { $0.message }
        XCTAssertEqual(atSwitch, [.noteOff(channel: 9, note: 46, velocity: 0), .noteOn(channel: 9, note: 42, velocity: 100)])
    }

    func testStopAtNextBarAndTransportStop() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 100)
        engine.stopAtNextBar()
        XCTAssertTrue(engine.isStopPending)
        let ev = engine.render(to: 3 * bar)
        XCTAssertEqual(onsets(ev).count, 3) // resto della prima battuta, poi silenzio
        let messages = engine.transportStopped()
        XCTAssertEqual(messages.last, .controlChange(channel: 9, controller: 123, value: 0))
        XCTAssertTrue(engine.render(to: 10 * bar).isEmpty)
    }

    func testSlotChosenWhileStoppedStartsOnStart() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse), EngineSlot(name: "B", groove: chorus)])
        engine.trigger(slot: 1)
        XCTAssertEqual(engine.armedSlotIndex, 1)
        engine.transportStarted(at: 0)
        XCTAssertEqual(onsets(engine.render(to: bar)), [[0, 42], [1920, 42]])
    }

    func testRetriggeringCurrentGrooveCancelsPending() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse), EngineSlot(name: "B", groove: chorus)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 100)
        engine.trigger(slot: 1)
        engine.trigger(slot: 0)
        XCTAssertNil(engine.pendingSlotIndex)
        _ = engine.render(to: 2 * bar)
        XCTAssertEqual(engine.playingSlotIndex, 0)
    }

    func testNextSlotSkipsFills() {
        let engine = makeEngine([EngineSlot(name: "A", groove: verse),
                                 EngineSlot(name: "F", groove: fill, mode: .oneShotReturn),
                                 EngineSlot(name: "B", groove: chorus)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 10)
        engine.triggerNextSlot()
        XCTAssertEqual(engine.pendingSlotIndex, 2)
    }

    func testGrooveEndQuantize() {
        let two = groove("due battute", [(0, 36), (bar, 38)], bars: 2)
        let engine = makeEngine([EngineSlot(name: "A", groove: two),
                                 EngineSlot(name: "B", groove: chorus, quantize: .grooveEnd)])
        engine.transportStarted(at: 0)
        _ = engine.render(to: 100)
        engine.trigger(slot: 1)
        XCTAssertEqual(engine.pendingBoundary, 2 * bar)
    }

    func testThreeFourMeter() {
        let waltz = Groove(name: "valzer", timeSignature: TimeSignature(3, 4), lengthTicks: 2880,
                           events: [GrooveEvent(tick: 0, kind: .noteOn(note: 36, velocity: 100))])
        let engine = GrooveEngine()
        engine.load(song: EngineSong(name: "3/4", timeSignature: TimeSignature(3, 4),
                                     slots: [EngineSlot(name: "A", groove: waltz), EngineSlot(name: "B", groove: chorus)]))
        engine.transportStarted(at: 0)
        _ = engine.render(to: 100)
        engine.trigger(slot: 1)
        XCTAssertEqual(engine.pendingBoundary, 2880)
    }
}
