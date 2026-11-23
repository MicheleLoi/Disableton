import Foundation

/// Provenienza di un groove.
public enum GrooveSource: String, Codable, Sendable {
    case ezdrummer
    case user
}

public struct GrooveRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Nome del file copiato nella cartella `grooves` della libreria.
    public var fileName: String
    public var source: GrooveSource
    /// Lunghezza forzata in battute (nil = automatica).
    public var lengthBars: Int?
    public var trimLeadingEmptyBars: Bool
    public var timeSignature: TimeSignature?
    public var noteMap: NoteMap?

    public init(id: UUID = UUID(), name: String, fileName: String, source: GrooveSource,
                lengthBars: Int? = nil, trimLeadingEmptyBars: Bool = true,
                timeSignature: TimeSignature? = nil, noteMap: NoteMap? = nil) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.source = source
        self.lengthBars = lengthBars
        self.trimLeadingEmptyBars = trimLeadingEmptyBars
        self.timeSignature = timeSignature
        self.noteMap = noteMap
    }

    enum CodingKeys: String, CodingKey {
        case id, name, fileName, source, lengthBars, trimLeadingEmptyBars, timeSignature, noteMap
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        fileName = try c.decode(String.self, forKey: .fileName)
        source = try c.decodeIfPresent(GrooveSource.self, forKey: .source) ?? .user
        lengthBars = try c.decodeIfPresent(Int.self, forKey: .lengthBars)
        trimLeadingEmptyBars = try c.decodeIfPresent(Bool.self, forKey: .trimLeadingEmptyBars) ?? true
        timeSignature = try c.decodeIfPresent(TimeSignature.self, forKey: .timeSignature)
        noteMap = try c.decodeIfPresent(NoteMap.self, forKey: .noteMap)
    }

    public var importOptions: GrooveImportOptions {
        GrooveImportOptions(lengthBars: lengthBars, trimLeadingEmptyBars: trimLeadingEmptyBars,
                            timeSignature: timeSignature, noteMap: noteMap)
    }
}

public struct SlotRecord: Codable, Equatable, Sendable {
    public var name: String?
    public var grooveID: UUID
    public var mode: SlotMode
    public var quantize: Quantize

    public init(name: String? = nil, grooveID: UUID, mode: SlotMode = .loop, quantize: Quantize = .bar) {
        self.name = name
        self.grooveID = grooveID
        self.mode = mode
        self.quantize = quantize
    }

    enum CodingKeys: String, CodingKey { case name, grooveID, mode, quantize }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        grooveID = try c.decode(UUID.self, forKey: .grooveID)
        mode = try c.decodeIfPresent(SlotMode.self, forKey: .mode) ?? .loop
        quantize = try c.decodeIfPresent(Quantize.self, forKey: .quantize) ?? .bar
    }
}

public struct SongRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var timeSignature: TimeSignature
    public var slots: [SlotRecord]
    /// Slot (0-based) avviato allo Start; nil = attende un comando.
    public var autoStartSlot: Int?

    public init(id: UUID = UUID(), name: String, timeSignature: TimeSignature = .fourFour,
                slots: [SlotRecord] = [], autoStartSlot: Int? = 0) {
        self.id = id
        self.name = name
        self.timeSignature = timeSignature
        self.slots = slots
        self.autoStartSlot = autoStartSlot
    }

    enum CodingKeys: String, CodingKey { case id, name, timeSignature, slots, autoStartSlot }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        timeSignature = try c.decodeIfPresent(TimeSignature.self, forKey: .timeSignature) ?? .fourFour
        slots = try c.decodeIfPresent([SlotRecord].self, forKey: .slots) ?? []
        if c.contains(.autoStartSlot) {
            autoStartSlot = try c.decodeIfPresent(Int.self, forKey: .autoStartSlot)
        } else {
            autoStartSlot = 0
        }
    }
}

public struct Library: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var grooves: [GrooveRecord]
    public var songs: [SongRecord]
    public var controlMap: ControlMap
    /// Canale MIDI verso EZdrummer, 1-16.
    public var outputChannel: Int

    public init(grooves: [GrooveRecord] = [], songs: [SongRecord] = [],
                controlMap: ControlMap = .default, outputChannel: Int = 10) {
        self.formatVersion = 1
        self.grooves = grooves
        self.songs = songs
        self.controlMap = controlMap
        self.outputChannel = outputChannel
    }

    enum CodingKeys: String, CodingKey { case formatVersion, grooves, songs, controlMap, outputChannel }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        grooves = try c.decodeIfPresent([GrooveRecord].self, forKey: .grooves) ?? []
        songs = try c.decodeIfPresent([SongRecord].self, forKey: .songs) ?? []
        controlMap = try c.decodeIfPresent(ControlMap.self, forKey: .controlMap) ?? .default
        outputChannel = try c.decodeIfPresent(Int.self, forKey: .outputChannel) ?? 10
    }

    public func groove(named name: String) -> GrooveRecord? {
        grooves.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public func groove(id: UUID) -> GrooveRecord? {
        grooves.first { $0.id == id }
    }
}

public enum LibraryError: Error, CustomStringConvertible {
    case missingGroove(song: String, id: UUID)
    case grooveNotFound(String)
    case songNotFound(Int)

    public var description: String {
        switch self {
        case let .missingGroove(song, id): return "il brano \"\(song)\" usa un groove inesistente (\(id))"
        case let .grooveNotFound(name): return "groove non trovato: \(name)"
        case let .songNotFound(i): return "brano \(i) non trovato"
        }
    }
}

/// Libreria su disco: `library.json` più la cartella `grooves/` con le copie dei file MIDI.
public final class LibraryStore {
    public let root: URL
    public var library: Library

    public var libraryURL: URL { root.appendingPathComponent("library.json") }
    public var groovesDirectory: URL { root.appendingPathComponent("grooves", isDirectory: true) }

    /// Cartella predefinita: ~/Library/Application Support/Disableton
    public static var defaultRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("Disableton", isDirectory: true)
    }

    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root.appendingPathComponent("grooves", isDirectory: true),
                                                withIntermediateDirectories: true)
        let url = root.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath: url.path) {
            library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
        } else {
            library = Library()
        }
    }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: libraryURL, options: .atomic)
    }

    /// Copia un file MIDI nella libreria dopo averlo verificato.
    @discardableResult
    public func importGroove(from url: URL, name: String? = nil, source: GrooveSource,
                             lengthBars: Int? = nil, timeSignature: TimeSignature? = nil) throws -> GrooveRecord {
        let data = try Data(contentsOf: url)
        let grooveName = name ?? url.deletingPathExtension().lastPathComponent
        let options = GrooveImportOptions(lengthBars: lengthBars, timeSignature: timeSignature)
        _ = try Groove(midiFile: MIDIFile(data: data), name: grooveName, options: options)
        let id = UUID()
        let fileName = "\(id.uuidString).mid"
        try data.write(to: groovesDirectory.appendingPathComponent(fileName), options: .atomic)
        let record = GrooveRecord(id: id, name: grooveName, fileName: fileName, source: source,
                                  lengthBars: lengthBars, timeSignature: timeSignature)
        library.grooves.append(record)
        return record
    }

    public func loadGroove(_ record: GrooveRecord) throws -> Groove {
        try Groove(contentsOf: groovesDirectory.appendingPathComponent(record.fileName),
                   name: record.name, options: record.importOptions)
    }

    /// Brani pronti per il motore, con tutti i groove caricati in memoria.
    public func engineSongs() throws -> [EngineSong] {
        var cache: [UUID: Groove] = [:]
        return try library.songs.map { song in
            let slots = try song.slots.map { slot -> EngineSlot in
                guard let record = library.groove(id: slot.grooveID) else {
                    throw LibraryError.missingGroove(song: song.name, id: slot.grooveID)
                }
                let groove: Groove
                if let cached = cache[record.id] {
                    groove = cached
                } else {
                    groove = try loadGroove(record)
                    cache[record.id] = groove
                }
                return EngineSlot(name: slot.name ?? record.name, groove: groove, mode: slot.mode, quantize: slot.quantize)
            }
            return EngineSong(name: song.name, timeSignature: song.timeSignature, slots: slots,
                              autoStartSlot: song.autoStartSlot)
        }
    }
}
