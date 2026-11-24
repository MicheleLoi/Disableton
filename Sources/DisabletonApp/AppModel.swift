#if canImport(SwiftUI) && os(macOS)
import AppKit
import Foundation
import GrooveCore
import MIDIHost
import SwiftUI
import UniformTypeIdentifiers

/// Stato dell'app. Ogni modifica alla libreria viene salvata subito su disco e passata al motore.
/// Tutti i metodi vanno chiamati dal thread principale.
final class AppModel: ObservableObject {
    @Published var library: Library {
        didSet {
            if library != oldValue { libraryChanged(from: oldValue) }
        }
    }
    @Published private(set) var snapshot: LiveSnapshot?
    @Published private(set) var availableInputs: [String] = []
    @Published private(set) var connectedInputs: [String] = []
    @Published private(set) var engineRunning = false
    @Published var errorMessage: String?
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
        refreshInputs()
        startEngine()
    }

    var libraryFolder: URL { store?.root ?? LibraryStore.defaultRoot }

    // MARK: - Motore

    func startEngine() {
        guard let store else { return }
        host?.shutdown()
        host = nil
        do {
            let songs = try store.engineSongs()
            let newHost = try LiveHost(songs: songs, controlMap: library.controlMap,
                                       outputChannel: library.outputChannel,
                                       settings: library.performance.playbackSettings,
                                       inputFilter: library.performance.inputFilter)
            host = newHost
            connectedInputs = newHost.connectedInputs
            engineRunning = true
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
        if s != snapshot { snapshot = s }
    }

    private func libraryChanged(from old: Library) {
        guard let store else { return }
        store.library = library
        do {
            try store.save()
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error)"
        }
        if library.performance.inputFilter != old.performance.inputFilter {
            reconnectInput()
        }
        pushToEngine()
    }

    private func pushToEngine() {
        guard let store, let host else { return }
        do {
            let songs = try store.engineSongs()
            host.update(songs: songs, controlMap: library.controlMap, outputChannel: library.outputChannel,
                        settings: library.performance.playbackSettings)
        } catch {
            errorMessage = "\(error)"
        }
    }

    // MARK: - Ingresso MIDI

    func refreshInputs() {
        availableInputs = LiveHost.sourceNames()
    }

    private func reconnectInput() {
        guard let host else { return }
        do {
            connectedInputs = try host.reconnect(inputFilter: library.performance.inputFilter)
        } catch {
            errorMessage = "Collegamento MIDI non riuscito: \(error)"
        }
    }

    // MARK: - Comandi dall'interfaccia

    func perform(_ action: ControlAction) {
        host?.perform(action)
    }

    func panic() {
        host?.panic()
    }

    // MARK: - Import

    func importFiles(_ urls: [URL], source: GrooveSource) {
        guard let store else { return }
        var failures: [String] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try store.importGroove(from: url, source: source)
            } catch {
                failures.append("\(url.lastPathComponent): \(error)")
            }
        }
        library = store.library
        if !failures.isEmpty {
            errorMessage = "Alcuni file non sono stati importati:\n" + failures.joined(separator: "\n")
        }
    }

    func importData(_ data: Data, name: String, source: GrooveSource) {
        guard let store else { return }
        do {
            try store.importGroove(data: data, name: name, source: source)
            library = store.library
        } catch {
            errorMessage = "\(name): \(error)"
        }
    }

    /// File trascinati dal Finder o da EZdrummer 3.
    func handleDrop(_ providers: [NSItemProvider], source: GrooveSource) -> Bool {
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
                    DispatchQueue.main.async { self.importFiles([fileURL], source: source) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.midi.identifier) {
                accepted = true
                let name = provider.suggestedName ?? "Groove"
                provider.loadDataRepresentation(forTypeIdentifier: UTType.midi.identifier) { data, _ in
                    guard let data else { return }
                    DispatchQueue.main.async { self.importData(data, name: name, source: source) }
                }
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

    // MARK: - MIDI Learn

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
            library.controlMap.bindings.append(binding)
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

    /// Nome visualizzato di uno slot.
    func displayName(of slot: SlotRecord) -> String {
        slot.name ?? library.groove(id: slot.grooveID)?.name ?? "groove mancante"
    }
}
#endif
