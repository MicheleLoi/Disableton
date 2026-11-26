import Foundation

/// Evento di un groove, con posizione in tick a `Groove.ppq`. Il canale non è memorizzato:
/// in uscita tutti gli eventi vanno sul canale configurato per EZdrummer.
public struct GrooveEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case noteOn(note: UInt8, velocity: UInt8)
        case noteOff(note: UInt8)
        case controlChange(controller: UInt8, value: UInt8)
    }

    public var tick: Int
    public var kind: Kind

    public init(tick: Int, kind: Kind) {
        self.tick = tick
        self.kind = kind
    }

    /// Ordine a parità di tick: prima i Note Off, poi i controller, poi i Note On.
    var sortRank: Int {
        switch kind {
        case .noteOff: return 0
        case .controlChange: return 1
        case .noteOn: return 2
        }
    }
}

public enum GrooveError: Error, Equatable, CustomStringConvertible {
    case noNotes
    case invalidLength

    public var description: String {
        switch self {
        case .noNotes: return "il file non contiene note"
        case .invalidLength: return "lunghezza del groove non valida"
        }
    }
}

/// Groove pronto per la riproduzione: eventi ordinati, tutti in [0, lengthTicks).
public struct Groove: Sendable {
    /// Risoluzione interna: tick per nota da un quarto.
    public static let ppq = 960

    public var name: String
    public var timeSignature: TimeSignature
    public var lengthTicks: Int
    public private(set) var events: [GrooveEvent]
    public var sourceTempoBPM: Double?
    /// Eventi scartati all'importazione perché oltre la fine del groove.
    public var droppedEventCount: Int

    public init(name: String, timeSignature: TimeSignature, lengthTicks: Int, events: [GrooveEvent],
                sourceTempoBPM: Double? = nil, droppedEventCount: Int = 0) {
        self.name = name
        self.timeSignature = timeSignature
        let length = max(1, lengthTicks)
        self.lengthTicks = length
        var dropped = droppedEventCount
        var kept: [(Int, GrooveEvent)] = []
        for (i, event) in events.enumerated() {
            var e = event
            if e.tick < 0 { dropped += 1; continue }
            if e.tick >= length {
                // I Note Off oltre la fine si anticipano all'ultimo tick; il resto si scarta.
                if case .noteOff = e.kind { e.tick = length - 1 } else { dropped += 1; continue }
            }
            kept.append((i, e))
        }
        kept.sort { a, b in
            if a.1.tick != b.1.tick { return a.1.tick < b.1.tick }
            if a.1.sortRank != b.1.sortRank { return a.1.sortRank < b.1.sortRank }
            return a.0 < b.0
        }
        self.events = kept.map { $0.1 }
        self.sourceTempoBPM = sourceTempoBPM
        self.droppedEventCount = dropped
    }

    public var ticksPerBar: Int { timeSignature.ticksPerBar(ppq: Groove.ppq) }
    public var lengthBars: Double { Double(lengthTicks) / Double(ticksPerBar) }

    /// Copia con le velocity dei colpi moltiplicate per `factor` (1 = invariate), limitate a 1…127.
    /// Il rapporto tra i colpi resta lo stesso, tranne per quelli che arrivano al massimo (127).
    public func scalingVelocities(by factor: Double) -> Groove {
        let scaled = events.map { event -> GrooveEvent in
            guard case let .noteOn(note, velocity) = event.kind else { return event }
            let value = Int((Double(velocity) * factor).rounded())
            return GrooveEvent(tick: event.tick, kind: .noteOn(note: note, velocity: UInt8(min(127, max(1, value)))))
        }
        return Groove(name: name, timeSignature: timeSignature, lengthTicks: lengthTicks, events: scaled,
                      sourceTempoBPM: sourceTempoBPM, droppedEventCount: droppedEventCount)
    }

    /// Quanti colpi supererebbero il massimo (127) con il fattore indicato.
    public func clippedHits(factor: Double) -> Int {
        events.filter { event in
            guard case let .noteOn(_, velocity) = event.kind else { return false }
            return Double(velocity) * factor > 127.5
        }.count
    }

    /// Le battute intere del groove (per riscriverlo con la stessa lunghezza).
    public var wholeBars: Int { max(1, lengthTicks / timeSignature.ticksPerBar(ppq: Groove.ppq)) }

    public var noteOnCount: Int {
        events.reduce(0) { n, e in if case .noteOn = e.kind { return n + 1 }; return n }
    }

    /// Numero di colpi per nota.
    public var noteHistogram: [UInt8: Int] {
        var h: [UInt8: Int] = [:]
        for e in events { if case let .noteOn(n, _) = e.kind { h[n, default: 0] += 1 } }
        return h
    }

    /// Indici degli eventi con tick in [from, to).
    public func eventIndices(from: Int, to: Int) -> Range<Int> {
        guard from < to else { return 0..<0 }
        let lo = lowerBound(from)
        let hi = lowerBound(to)
        return lo..<max(lo, hi)
    }

    private func lowerBound(_ tick: Int) -> Int {
        var lo = 0
        var hi = events.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if events[mid].tick < tick { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

public struct GrooveImportOptions: Sendable {
    /// Lunghezza forzata in battute; se nil viene calcolata dall'ultima nota.
    public var lengthBars: Int?
    /// Rimuove le battute vuote iniziali (alcuni export aggiungono una battuta di silenzio).
    public var trimLeadingEmptyBars: Bool
    /// Metro forzato; se nil si usa quello del file, altrimenti 4/4.
    public var timeSignature: TimeSignature?
    /// Conversione delle note (es. mappa Korg → EZdrummer).
    public var noteMap: NoteMap?

    public init(lengthBars: Int? = nil, trimLeadingEmptyBars: Bool = true,
                timeSignature: TimeSignature? = nil, noteMap: NoteMap? = nil) {
        self.lengthBars = lengthBars
        self.trimLeadingEmptyBars = trimLeadingEmptyBars
        self.timeSignature = timeSignature
        self.noteMap = noteMap
    }
}

extension Groove {
    public init(contentsOf url: URL, name: String? = nil, options: GrooveImportOptions = GrooveImportOptions()) throws {
        let file = try MIDIFile(contentsOf: url)
        try self.init(midiFile: file, name: name ?? url.deletingPathExtension().lastPathComponent, options: options)
    }

    public init(midiFile: MIDIFile, name: String, options: GrooveImportOptions = GrooveImportOptions()) throws {
        let ppq = Groove.ppq
        let sourcePPQ = Int64(midiFile.ticksPerQuarter)
        func convert(_ tick: Int) -> Int {
            Int((Int64(tick) * Int64(ppq) + sourcePPQ / 2) / sourcePPQ)
        }

        func mapped(_ note: UInt8) -> UInt8? {
            guard let map = options.noteMap else { return note }
            return map.map(note)
        }

        var events: [GrooveEvent] = []
        for track in midiFile.tracks {
            for e in track {
                guard case let .channel(message) = e.kind else { continue }
                let tick = convert(e.tick)
                switch message {
                case let .noteOn(_, note, velocity):
                    guard let n = mapped(note) else { continue }
                    events.append(GrooveEvent(tick: tick, kind: .noteOn(note: n, velocity: velocity)))
                case let .noteOff(_, note, _):
                    guard let n = mapped(note) else { continue }
                    events.append(GrooveEvent(tick: tick, kind: .noteOff(note: n)))
                case let .controlChange(_, controller, value):
                    events.append(GrooveEvent(tick: tick, kind: .controlChange(controller: controller, value: value)))
                default:
                    continue
                }
            }
        }

        let noteOnTicks = events.compactMap { e -> Int? in
            if case .noteOn = e.kind { return e.tick }
            return nil
        }
        guard let firstOn = noteOnTicks.min(), let lastOn = noteOnTicks.max() else { throw GrooveError.noNotes }

        let ts = options.timeSignature ?? midiFile.timeSignature ?? .fourFour
        let barTicks = ts.ticksPerBar(ppq: ppq)

        var shift = 0
        if options.trimLeadingEmptyBars && firstOn >= barTicks {
            shift = (firstOn / barTicks) * barTicks
        }

        let length: Int
        if let bars = options.lengthBars {
            guard bars > 0 else { throw GrooveError.invalidLength }
            length = bars * barTicks
        } else {
            length = ((lastOn - shift) / barTicks + 1) * barTicks
        }

        let shifted = events.map { GrooveEvent(tick: $0.tick - shift, kind: $0.kind) }
        self.init(name: name, timeSignature: ts, lengthTicks: length, events: shifted,
                  sourceTempoBPM: midiFile.tempoBPM)
    }
}

/// Tabella di conversione delle note. Un valore -1 elimina la nota.
public struct NoteMap: Codable, Equatable, Sendable {
    public var name: String
    public var mapping: [Int: Int]

    public init(name: String, mapping: [Int: Int]) {
        self.name = name
        self.mapping = mapping
    }

    public static let identity = NoteMap(name: "identità", mapping: [:])

    /// Nota convertita, oppure nil se la nota va eliminata.
    public func map(_ note: UInt8) -> UInt8? {
        guard let target = mapping[Int(note)] else { return note }
        guard (0...127).contains(target) else { return nil }
        return UInt8(target)
    }
}

/// Nomi General MIDI delle percussioni (canale 10), utili per verificare le mappature.
public enum DrumNames {
    public static func gm(_ note: UInt8) -> String? { table[note] }

    private static let table: [UInt8: String] = [
        35: "Acoustic Bass Drum", 36: "Bass Drum 1", 37: "Side Stick", 38: "Acoustic Snare",
        39: "Hand Clap", 40: "Electric Snare", 41: "Low Floor Tom", 42: "Closed Hi-Hat",
        43: "High Floor Tom", 44: "Pedal Hi-Hat", 45: "Low Tom", 46: "Open Hi-Hat",
        47: "Low-Mid Tom", 48: "Hi-Mid Tom", 49: "Crash Cymbal 1", 50: "High Tom",
        51: "Ride Cymbal 1", 52: "Chinese Cymbal", 53: "Ride Bell", 54: "Tambourine",
        55: "Splash Cymbal", 56: "Cowbell", 57: "Crash Cymbal 2", 58: "Vibraslap",
        59: "Ride Cymbal 2", 60: "Hi Bongo", 61: "Low Bongo", 62: "Mute Hi Conga",
        63: "Open Hi Conga", 64: "Low Conga", 65: "High Timbale", 66: "Low Timbale",
        67: "High Agogo", 68: "Low Agogo", 69: "Cabasa", 70: "Maracas",
        71: "Short Whistle", 72: "Long Whistle", 73: "Short Guiro", 74: "Long Guiro",
        75: "Claves", 76: "Hi Wood Block", 77: "Low Wood Block", 78: "Mute Cuica",
        79: "Open Cuica", 80: "Mute Triangle", 81: "Open Triangle",
    ]
}
