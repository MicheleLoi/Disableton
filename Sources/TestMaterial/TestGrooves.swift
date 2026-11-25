import Foundation
import GrooveCore

/// Groove di prova generati in modo deterministico (note General MIDI, canale 10).
/// Materiale per i test e per la verifica su GitHub: non fa parte dell'app.
public enum TestGrooves {
    public struct SongTemplate {
        public let name: String
        public let timeSignature: TimeSignature
        public let slots: [(groove: String, mode: SlotMode)]
    }

    typealias Hit = (beat: Double, note: UInt8, velocity: Int)

    static func hits(_ items: Hit...) -> [Hit] { items }

    // Note General MIDI
    static let kick: UInt8 = 36, snare: UInt8 = 38, sideStick: UInt8 = 37, hatClosed: UInt8 = 42
    static let hatOpen: UInt8 = 46, crash: UInt8 = 49, ride: UInt8 = 51
    static let tomHigh: UInt8 = 50, tomMid: UInt8 = 47, tomFloor: UInt8 = 43

    public static let songs: [SongTemplate] = [
        SongTemplate(name: "Demo 1 – Rock", timeSignature: .fourFour, slots: [
            ("Rock strofa", .loop), ("Rock ritornello", .loop), ("Fill tom", .oneShotReturn), ("Finale", .oneShotStop),
        ]),
        SongTemplate(name: "Demo 2 – Funk", timeSignature: .fourFour, slots: [
            ("Funk 16esimi", .loop), ("Shuffle", .loop), ("Fill tom", .oneShotReturn), ("Finale", .oneShotStop),
        ]),
        SongTemplate(name: "Demo 3 – Valzer", timeSignature: TimeSignature(3, 4), slots: [
            ("Valzer", .loop),
        ]),
        SongTemplate(name: "Demo 4 – Sei ottavi", timeSignature: TimeSignature(6, 8), slots: [
            ("Sei ottavi", .loop),
        ]),
    ]

    /// Tutti i groove dimostrativi, per nome.
    public static func grooves() -> [Groove] {
        [rockVerse(), rockChorus(), tomFill(), ending(), funk(), shuffle(), waltz(), sixEight()]
    }

    /// Brani pronti per il motore, senza passare dalla libreria.
    public static func engineSongs() -> [EngineSong] {
        let byName = Dictionary(uniqueKeysWithValues: grooves().map { ($0.name, $0) })
        return songs.map { song in
            EngineSong(name: song.name, timeSignature: song.timeSignature,
                       slots: song.slots.compactMap { slot in
                           byName[slot.groove].map { EngineSlot(name: slot.groove, groove: $0, mode: slot.mode) }
                       },
                       autoStartSlot: 0)
        }
    }

    // MARK: - Costruzione

    /// Piccoli scostamenti ripetibili, per un'esecuzione meno meccanica.
    private static let timingOffsets = [0, 5, -3, 2, -5, 4, -2, 3, 1, -4]
    private static let velocityOffsets = [0, -6, 4, -3, 6, -8, 2, -2]

    private static func build(_ name: String, _ ts: TimeSignature, bars: Int,
                              _ hits: [Hit]) -> Groove {
        var events: [GrooveEvent] = []
        for (i, h) in hits.enumerated() {
            let base = Int((h.beat * Double(Groove.ppq)).rounded())
            let tick = max(0, base + (base == 0 ? 0 : timingOffsets[i % timingOffsets.count]))
            let velocity = UInt8(min(127, max(1, h.velocity + velocityOffsets[i % velocityOffsets.count])))
            events.append(GrooveEvent(tick: tick, kind: .noteOn(note: h.note, velocity: velocity)))
            events.append(GrooveEvent(tick: tick + 60, kind: .noteOff(note: h.note)))
        }
        return Groove(name: name, timeSignature: ts, lengthTicks: bars * ts.ticksPerBar(ppq: Groove.ppq),
                      events: events, sourceTempoBPM: 120)
    }

    private static func eighthHats(bars: Int, beatsPerBar: Int = 4, note: UInt8 = hatClosed) -> [Hit] {
        (0..<(bars * beatsPerBar * 2)).map { i -> Hit in
            let velocity: Int = i % 2 == 0 ? 92 : 62
            return (Double(i) / 2, note, velocity)
        }
    }

    static func rockVerse() -> Groove {
        var h = eighthHats(bars: 2)
        for bar in 0..<2 {
            let o = Double(bar * 4)
            h += hits((o + 0, kick, 112), (o + 2, kick, 104), (o + 1, snare, 110), (o + 3, snare, 112))
            if bar == 1 { h.append((o + 2.5, kick, 96)) }
        }
        return build("Rock strofa", .fourFour, bars: 2, h)
    }

    static func rockChorus() -> Groove {
        var h: [Hit] = [(0, crash, 118)]
        h += (0..<16).map { i -> Hit in
            let velocity: Int = i % 2 == 0 ? 96 : 70
            return (Double(i) / 2, ride, velocity)
        }
        for bar in 0..<2 {
            let o = Double(bar * 4)
            h += hits((o + 0, kick, 116), (o + 1.5, kick, 100), (o + 2, kick, 108), (o + 1, snare, 116), (o + 3, snare, 118))
            if bar == 1 { h.append((o + 3.5, kick, 98)) }
        }
        return build("Rock ritornello", .fourFour, bars: 2, h)
    }

    static func tomFill() -> Groove {
        var h: [Hit] = [
            (0, hatClosed, 90), (0.5, hatClosed, 60), (1, hatClosed, 90), (1.5, hatClosed, 60),
            (0, kick, 110), (1, snare, 110),
        ]
        let toms: [UInt8] = [snare, snare, tomHigh, tomHigh, tomMid, tomMid, tomFloor, tomFloor]
        for (i, note) in toms.enumerated() {
            h.append((2 + Double(i) * 0.25, note, 96 + i * 3))
        }
        h += hits((2, kick, 104), (3, kick, 108))
        return build("Fill tom", .fourFour, bars: 1, h)
    }

    static func ending() -> Groove {
        build("Finale", .fourFour, bars: 1, [(0, crash, 124), (0, kick, 124)])
    }

    static func funk() -> Groove {
        var h: [Hit] = (0..<16).map { i -> Hit in
            let velocity: Int = i % 4 == 0 ? 96 : (i % 2 == 0 ? 72 : 48)
            return (Double(i) / 4, hatClosed, velocity)
        }
        h += hits((0, kick, 114), (0.75, kick, 96), (2.5, kick, 104),
              (1, snare, 114), (3, snare, 116),
              (1.75, snare, 34), (2.25, snare, 30), (3.75, snare, 36))
        return build("Funk 16esimi", .fourFour, bars: 1, h)
    }

    static func shuffle() -> Groove {
        var h: [Hit] = []
        for beat in 0..<4 {
            h.append((Double(beat), hatClosed, 92))
            h.append((Double(beat) + 2.0 / 3.0, hatClosed, 60))
        }
        h += hits((0, kick, 112), (2, kick, 104), (2 + 2.0 / 3.0, kick, 90), (1, snare, 110), (3, snare, 112))
        return build("Shuffle", .fourFour, bars: 1, h)
    }

    static func waltz() -> Groove {
        build("Valzer", TimeSignature(3, 4), bars: 1, [
            (0, kick, 110), (1, hatClosed, 80), (2, hatClosed, 76), (1, sideStick, 70), (2, sideStick, 66),
        ])
    }

    static func sixEight() -> Groove {
        var h: [Hit] = (0..<6).map { i -> Hit in
            let velocity: Int = i % 3 == 0 ? 94 : 64
            return (Double(i) / 2, hatClosed, velocity)
        }
        h += hits((0, kick, 112), (1.5, snare, 110), (2.5, kick, 90))
        return build("Sei ottavi", TimeSignature(6, 8), bars: 1, h)
    }
}

extension LibraryStore {
    /// Aggiunge groove e brani di prova che non sono già presenti (per nome).
    /// Restituisce il numero di brani aggiunti. Solo per test e strumenti di sviluppo.
    @discardableResult
    public func installTestGrooves() throws -> Int {
        var ids: [String: UUID] = [:]
        for groove in TestGrooves.grooves() {
            if let existing = library.groove(named: groove.name) {
                ids[groove.name] = existing.id
            } else {
                let record = try importGroove(data: groove.midiData(), name: groove.name, source: .user)
                ids[groove.name] = record.id
            }
        }
        var added = 0
        for template in TestGrooves.songs where !library.songs.contains(where: { $0.name == template.name }) {
            let songID = library.addSong(name: template.name, timeSignature: template.timeSignature)
            guard let index = library.songIndex(id: songID) else { continue }
            for slot in template.slots {
                if let grooveID = ids[slot.groove] {
                    library.addSlot(toSong: index, grooveID: grooveID, mode: slot.mode)
                }
            }
            library.songs[index].autoStartSlot = 0
            added += 1
        }
        return added
    }
}
