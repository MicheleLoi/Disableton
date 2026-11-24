import Foundation

/// Scrive Standard MIDI File di formato 0 (una traccia).
public enum MIDIFileWriter {
    public static func data(events: [(tick: Int, message: MIDIMessage)], ticksPerQuarter: Int = Groove.ppq,
                            tempoBPM: Double? = nil, timeSignature: TimeSignature? = nil,
                            endTick: Int? = nil, trackName: String? = nil) -> Data {
        var track: [UInt8] = []
        func meta(_ type: UInt8, _ payload: [UInt8]) {
            track += [0x00, 0xFF, type] + vlq(payload.count) + payload
        }
        if let trackName { meta(0x03, Array(trackName.utf8)) }
        if let ts = timeSignature {
            var power = 0
            while (1 << power) < ts.beatUnit { power += 1 }
            meta(0x58, [UInt8(clamping: ts.beatsPerBar), UInt8(power), 24, 8])
        }
        if let bpm = tempoBPM, bpm > 0 {
            let us = Int((60_000_000 / bpm).rounded())
            meta(0x51, [UInt8((us >> 16) & 0xFF), UInt8((us >> 8) & 0xFF), UInt8(us & 0xFF)])
        }
        let sorted = events.enumerated().sorted { a, b in
            a.element.tick != b.element.tick ? a.element.tick < b.element.tick : a.offset < b.offset
        }.map { $0.element }
        var last = 0
        for e in sorted {
            let bytes = e.message.bytes
            guard let status = bytes.first, status < 0xF0 else { continue }
            let tick = max(last, e.tick)
            track += vlq(tick - last) + bytes
            last = tick
        }
        let end = max(last, endTick ?? last)
        track += vlq(end - last) + [0xFF, 0x2F, 0x00]

        var out: [UInt8] = Array("MThd".utf8)
        out += be32(6) + be16(0) + be16(1) + be16(ticksPerQuarter)
        out += Array("MTrk".utf8) + be32(track.count) + track
        return Data(out)
    }

    static func vlq(_ value: Int) -> [UInt8] {
        var v = max(0, value)
        var bytes: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            bytes.insert(UInt8(v & 0x7F) | 0x80, at: 0)
            v >>= 7
        }
        return bytes
    }

    private static func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
    private static func be32(_ v: Int) -> [UInt8] {
        [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }
}

extension Groove {
    /// Il groove come file MIDI (tick a 960 PPQ), sul canale indicato (0-based, 9 = canale 10).
    public func midiData(channel: UInt8 = 9, tempoBPM: Double? = 120) -> Data {
        let events: [(tick: Int, message: MIDIMessage)] = events.map { e in
            switch e.kind {
            case let .noteOn(note, velocity):
                return (e.tick, .noteOn(channel: channel, note: note, velocity: velocity))
            case let .noteOff(note):
                return (e.tick, .noteOff(channel: channel, note: note, velocity: 0))
            case let .controlChange(controller, value):
                return (e.tick, .controlChange(channel: channel, controller: controller, value: value))
            }
        }
        return MIDIFileWriter.data(events: events, tempoBPM: tempoBPM ?? sourceTempoBPM,
                                   timeSignature: timeSignature, endTick: lengthTicks, trackName: name)
    }
}
