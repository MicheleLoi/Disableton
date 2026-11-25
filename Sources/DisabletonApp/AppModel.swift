#if canImport(SwiftUI) && os(macOS)
import AppKit
import Foundation
import GrooveCore
import MIDIHost
import SwiftUI
import UniformTypeIdentifiers

/// Le tre viste dell'app.
enum AppMode: String, CaseIterable, Identifiable {
    case prep, commands, stage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prep: return "Preparazione"
        case .commands: return "Comandi"
        case .stage: return "Palco"
        }
    }
}

/// Stato dell'app. Ogni modifica alla libreria viene salvata subito su disco e passata al motore.
/// Tutti i metodi vanno chiamati dal thread principale.
final class AppModel: ObservableObject {
    @Published var library: Library {
        didSet {
            if library != oldValue { libraryChanged(from: oldValue) }
        }
    }
    @Published var mode: AppMode = .prep
    @Published var showSettings = false
    @Published var selectedSongID: UUID?
    @Published var selectedSlotID: UUID?
    @Published var selectedKey: Int? = 38
    @Published var detailGrooveID: UUID?
    @Published private(set) var snapshot: LiveSnapshot?
    @Published private(set) var availableInputs: [String] = []
    @Published private(set) var availableDestinations: [String] = []
    @Published private(set) var connectedInputs: [String] = []
    @Published private(set) var engineRunning = false
    @Published var errorMessage: String? {
        didSet {
            if let message = errorMessage, message != oldValue { log.log("Errore mostrato: \(message)") }
        }
    }
    @Published var showReport = false
    @Published var reportReason: String?
    @Published var reportCrashExcerpt: String?
    @Published var updateState: Updater.State = .idle

    /// Registro degli eventi (~/Library/Logs/Disableton/Disableton.log).
    let log = EventLog(fileURL: EventLog.defaultURL)
    var lastLoggedSnapshot: LiveSnapshot?
    @Published private(set) var learningTarget: LearnTarget?
    @Published private(set) var previewingGrooveID: UUID?
    @Published var previewBPM: Double = 100

    enum LearnTarget: Equatable {
        case existing(Int)
        case new(ControlAction)
    }

    let store: LibraryStore?
    private var host: LiveHost?

    init() {
        var openedStore: LibraryStore?
        var openError: String?
        do {
            openedStore = try LibraryStore(root: LibraryStore.defaultRoot)
        } catch {
            openError = "Impossibile aprire la libreria: \(error)"
        }
        store = openedStore
        library = openedStore?.library ?? Library()
        errorMessage = openError
        selectedSongID = library.songs.first?.id
        selectedSlotID = library.songs.first?.slots.dropFirst().first?.id
        // Usato dalla verifica automatica per fotografare ogni vista.
        let environment = ProcessInfo.processInfo.environment
        if let raw = environment["DISABLETON_MODE"], let initial = AppMode(rawValue: raw) { mode = initial }
        if environment["DISABLETON_SETTINGS"] == "1" { showSettings = true }
        logStartup()
        refreshPorts()
        startEngine()
        // Nella verifica automatica (schermate) niente avvisi né controlli in rete.
        let automated = environment["DISABLETON_AUTOMATION"] == "1"
        if !automated { checkPreviousSession() }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            self?.applicationWillTerminate()
        }
        if !automated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.checkForUpdates(userInitiated: false)
            }
        }
    }

    var libraryFolder: URL { store?.root ?? LibraryStore.defaultRoot }

    // MARK: - Motore

    func startEngine() {
        guard let store else { return }
        host?.shutdown()
        host = nil
        do {
            let songs = try store.engineSongs()
            let p = library.performance
            let newHost = try LiveHost(songs: songs, controlMap: library.controlMap,
                                       outputChannel: library.outputChannel,
                                       settings: p.playbackSettings, inputFilter: p.inputFilter,
                                       output: p.soundOutput, destinationFilter: p.destinationFilter)
            host = newHost
            connectedInputs = newHost.connectedInputs
            engineRunning = true
            log.log("Motore MIDI avviato · ingressi: \(connectedInputs.isEmpty ? "nessuno" : connectedInputs.joined(separator: ", ")) · uscita: \(newHost.snapshot().outputDescription)")
        } catch {
            engineRunning = false
            errorMessage = "Il motore MIDI non è partito: \(error)"
        }
    }

    /// Chiamato periodicamente dall'interfaccia (10 volte al secondo).
    func poll() {
        guard let host else {
            if snapshot != nil { snapshot = nil }
            return
        }
        let s = host.snapshot()
        if s != snapshot {
            logChanges(from: lastLoggedSnapshot, to: s)
            lastLoggedSnapshot = s
            snapshot = s
        }
    }

    private func libraryChanged(from old: Library) {
        guard let store else { return }
        store.library = library
        do {
            try store.save()
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error)"
        }
        guard let host else { return }
        if library.performance.inputFilter != old.performance.inputFilter {
            do {
                connectedInputs = try host.reconnect(inputFilter: library.performance.inputFilter)
            } catch {
                errorMessage = "Collegamento MIDI non riuscito: \(error)"
            }
        }
        if library.performance.soundOutput != old.performance.soundOutput
            || library.performance.destinationFilter != old.performance.destinationFilter {
            let description = host.configureOutput(library.performance.soundOutput,
                                                   destinationFilter: library.performance.destinationFilter)
            log.log("Uscita del suono: \(description)")
        }
        if library.performance.inputFilter != old.performance.inputFilter {
            log.log("Ingresso MIDI: \(connectedInputs.isEmpty ? "nessuno" : connectedInputs.joined(separator: ", "))")
        }
        do {
            let songs = try store.engineSongs()
            host.update(songs: songs, controlMap: library.controlMap, outputChannel: library.outputChannel,
                        settings: library.performance.playbackSettings)
        } catch {
            errorMessage = "\(error)"
        }
    }

    // MARK: - Porte MIDI

    func refreshPorts() {
        availableInputs = LiveHost.sourceNames()
        availableDestinations = LiveHost.destinationNames()
    }

    // MARK: - Comandi e trasporto

    func perform(_ action: ControlAction) {
        host?.perform(action)
    }

    func panic() {
        host?.panic()
    }

    func startInternalClock() {
        previewingGrooveID = nil
        host?.startInternalClock(bpm: library.performance.internalBPM)
    }

    func stopInternalClock() {
        host?.stopInternalClock()
    }

    // MARK: - Brani e slot

    var selectedSongIndex: Int? {
        selectedSongID.flatMap { library.songIndex(id: $0) }
    }

    var selectedSlotIndex: Int? {
        guard let s = selectedSongIndex, let id = selectedSlotID else { return nil }
        return library.songs[s].slots.firstIndex { $0.id == id }
    }

    func addSong() {
        let id = library.addSong(name: "Brano \(library.songs.count + 1)")
        selectedSongID = id
        selectedSlotID = nil
    }

    func moveSelectedSong(by delta: Int) {
        guard let index = selectedSongIndex else { return }
        let target = index + delta
        guard library.songs.indices.contains(target) else { return }
        library.moveSongs(fromOffsets: IndexSet(integer: index), toOffset: delta > 0 ? target + 1 : target)
        log.log("Brano spostato: \(index + 1) → \(target + 1)")
    }

    func deleteSong(_ id: UUID) {
        guard let index = library.songIndex(id: id) else { return }
        library.removeSongs(atOffsets: IndexSet(integer: index))
        if selectedSongID == id { selectedSongID = library.songs.first?.id }
        selectedSlotID = nil
    }

    /// Aggiunge un groove in fondo al brano selezionato (fill se il nome contiene "fill").
    func addSlot(grooveID: UUID) {
        guard let s = selectedSongIndex, let record = library.groove(id: grooveID) else { return }
        let mode: SlotMode = record.name.localizedCaseInsensitiveContains("fill") ? .oneShotReturn
            : (record.name.localizedCaseInsensitiveContains("finale") ? .oneShotStop : .loop)
        selectedSlotID = library.addSlot(toSong: s, grooveID: grooveID, mode: mode)
    }

    func moveSelectedSlot(by delta: Int) {
        guard let s = selectedSongIndex, let k = selectedSlotIndex else { return }
        let target = k + delta
        guard library.songs[s].slots.indices.contains(target) else { return }
        library.moveSlots(inSong: s, fromOffsets: IndexSet(integer: k), toOffset: delta > 0 ? target + 1 : target)
    }

    func removeSelectedSlot() {
        guard let s = selectedSongIndex, let k = selectedSlotIndex else { return }
        library.removeSlots(fromSong: s, atOffsets: IndexSet(integer: k))
        selectedSlotID = nil
    }

    // MARK: - Import

    func importFiles(_ urls: [URL]) {
        guard let store else { return }
        var failures: [String] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try store.importGroove(from: url, source: .user)
            } catch {
                failures.append("\(url.lastPathComponent): \(error)")
            }
        }
        library = store.library
        log.log("Importazione: \(urls.count - failures.count) file importati, \(failures.count) non riusciti")
        if !failures.isEmpty {
            errorMessage = "Alcuni file non sono stati importati:\n" + failures.joined(separator: "\n")
        }
    }

    func importData(_ data: Data, name: String) {
        guard let store else { return }
        do {
            try store.importGroove(data: data, name: name, source: .user)
            library = store.library
        } catch {
            errorMessage = "\(name): \(error)"
        }
    }

    /// File trascinati dal Finder o da EZdrummer 3.
    func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let direct = item as? URL {
                        url = direct
                    }
                    guard let fileURL = url else { return }
                    DispatchQueue.main.async { self.importFiles([fileURL]) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.midi.identifier) {
                accepted = true
                let name = provider.suggestedName ?? "Groove"
                provider.loadDataRepresentation(forTypeIdentifier: UTType.midi.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async { self.importData(data, name: name) }
                }
            }
        }
        return accepted
    }

    /// Groove della libreria trascinati sulla sequenza del brano.
    func handleGrooveDrop(_ providers: [NSItemProvider]) -> Bool {
        log.log("Trascinamento sulla sequenza: \(providers.count) elementi, tipi \(providers.flatMap { $0.registeredTypeIdentifiers })")
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            accepted = true
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let text = object as? NSString, let id = UUID(uuidString: text as String) else { return }
                DispatchQueue.main.async { self.addSlot(grooveID: id) }
            }
        }
        return accepted
    }

    // MARK: - Groove

    func groove(for record: GrooveRecord) -> Groove? {
        try? store?.loadGroove(record)
    }

    func deleteGroove(id: UUID) {
        guard let store else { return }
        if previewingGrooveID == id { stopPreview() }
        do {
            try store.deleteGroove(id: id)
        } catch {
            errorMessage = "\(error)"
        }
        library = store.library
    }

    func togglePreview(_ record: GrooveRecord) {
        if previewingGrooveID == record.id {
            stopPreview()
            return
        }
        guard let host, let groove = groove(for: record) else { return }
        host.startPreview(groove: groove, bpm: previewBPM)
        previewingGrooveID = record.id
    }

    func stopPreview() {
        host?.stopPreview()
        previewingGrooveID = nil
    }

    // MARK: - Comandi MIDI e MIDI Learn

    /// Azione assegnata a una nota sul canale 16.
    func action(forNote note: Int) -> ControlAction? {
        library.controlMap.action(for: .noteOn(channel: 15, note: UInt8(clamping: note), velocity: 100))
    }

    /// Assegna (o toglie, con nil) l'azione di una nota sul canale 16.
    func setAction(_ action: ControlAction?, forNote note: Int) {
        var bindings = library.controlMap.bindings.filter { !($0.kind == .note && $0.channel == 16 && $0.number == note) }
        if let action {
            bindings.append(ControlBinding(kind: .note, channel: 16, number: note, action: action))
        }
        library.controlMap.bindings = bindings
    }

    /// Indice dell'associazione per uno slot (nota), per il pulsante "Impara" della Preparazione.
    func learnKey(forSlot index: Int) {
        startLearning(.new(.triggerSlot(index)))
    }

    func learn(bindingAt index: Int) {
        guard library.controlMap.bindings.indices.contains(index) else { return }
        startLearning(.existing(index))
    }

    func learnNew(action: ControlAction) {
        startLearning(.new(action))
    }

    func cancelLearn() {
        host?.cancelLearn()
        learningTarget = nil
    }

    private func startLearning(_ target: LearnTarget) {
        guard let host else {
            errorMessage = "Il motore MIDI non è attivo."
            return
        }
        learningTarget = target
        host.learnNext { message in
            self.finishLearn(message)
        }
    }

    private func finishLearn(_ message: MIDIMessage) {
        defer { learningTarget = nil }
        guard let target = learningTarget else { return }
        switch target {
        case let .existing(index):
            guard library.controlMap.bindings.indices.contains(index),
                  let binding = ControlBinding.learn(from: message, action: library.controlMap.bindings[index].action)
            else { return }
            library.controlMap.bindings[index] = binding
        case let .new(action):
            guard let binding = ControlBinding.learn(from: message, action: action) else { return }
            log.log("MIDI Learn: \(action) ← \(binding.triggerLabel)")
            // Il nuovo controllo sostituisce sia il vecchio controllo di questa azione (stesso tipo)
            // sia l'azione che il controllo aveva prima.
            var bindings = library.controlMap.bindings.filter { b in
                !(b.action == action && b.kind == binding.kind)
                    && !(b.kind == binding.kind && b.channel == binding.channel && b.number == binding.number)
            }
            bindings.append(binding)
            library.controlMap.bindings = bindings
            if binding.kind == .note, let n = binding.number { selectedKey = n }
        }
    }

    func removeBinding(at index: Int) {
        guard library.controlMap.bindings.indices.contains(index) else { return }
        library.controlMap.bindings.remove(at: index)
    }

    func resetBindings() {
        library.controlMap = .default
    }

    // MARK: - Binding sicuri (per identificativo, non per posizione)

    func songBinding<T>(_ id: UUID, _ keyPath: WritableKeyPath<SongRecord, T>, fallback: T) -> Binding<T> {
        Binding(
            get: {
                guard let i = self.library.songIndex(id: id) else { return fallback }
                return self.library.songs[i][keyPath: keyPath]
            },
            set: { value in
                guard let i = self.library.songIndex(id: id) else { return }
                self.library.songs[i][keyPath: keyPath] = value
            })
    }

    func slotBinding<T>(song songID: UUID, slot slotID: UUID, _ keyPath: WritableKeyPath<SlotRecord, T>,
                        fallback: T) -> Binding<T> {
        Binding(
            get: {
                guard let s = self.library.songIndex(id: songID),
                      let k = self.library.songs[s].slots.firstIndex(where: { $0.id == slotID }) else { return fallback }
                return self.library.songs[s].slots[k][keyPath: keyPath]
            },
            set: { value in
                guard let s = self.library.songIndex(id: songID),
                      let k = self.library.songs[s].slots.firstIndex(where: { $0.id == slotID }) else { return }
                self.library.songs[s].slots[k][keyPath: keyPath] = value
            })
    }

    func grooveBinding<T>(_ id: UUID, _ keyPath: WritableKeyPath<GrooveRecord, T>, fallback: T) -> Binding<T> {
        Binding(
            get: {
                guard let i = self.library.grooveIndex(id: id) else { return fallback }
                return self.library.grooves[i][keyPath: keyPath]
            },
            set: { value in
                guard let i = self.library.grooveIndex(id: id) else { return }
                self.library.grooves[i][keyPath: keyPath] = value
            })
    }

    // MARK: - Varie

    func showLibraryInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([libraryFolder.appendingPathComponent("library.json")])
    }

    func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    /// Nome visualizzato di uno slot.
    func displayName(of slot: SlotRecord) -> String {
        slot.name ?? library.groove(id: slot.grooveID)?.name ?? "groove mancante"
    }
}
#endif
