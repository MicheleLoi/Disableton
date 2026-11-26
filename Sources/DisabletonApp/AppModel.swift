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
    /// Il modello dell'app (per il delegato dell'applicazione).
    static weak var shared: AppModel?

    @Published var library: Library {
        didSet {
            if library != oldValue { libraryChanged(from: oldValue) }
        }
    }
    @Published var mode: AppMode = .prep {
        didSet { if mode == .stage, learningTarget != nil { cancelLearn() } }
    }
    @Published var showSettings = false
    @Published var selectedSongID: UUID? {
        didSet {
            guard selectedSongID != oldValue else { return }
            if learningTarget != nil { cancelLearn() }
            makeSelectedSongCurrentIfIdle()
        }
    }
    @Published var selectedSlotID: UUID? {
        didSet { if selectedSlotID != oldValue, learningTarget != nil { cancelLearn() } }
    }
    @Published var selectedKey: Int? = 24
    @Published var detailGrooveID: UUID?
    @Published var confirmDeleteSong = false
    @Published var showDAWHelp = false
    @Published var showElementHelp = false
    @Published var showGrooveHelp = false
    @Published var confirmInstallUpdate = false
    /// Avviso breve mostrato nella barra di stato (es. dopo un MIDI Learn).
    @Published private(set) var notice: String?
    @Published private(set) var undoStack: [Library] = []
    @Published private(set) var redoStack: [Library] = []
    private var isRestoring = false
    private var lastUndoPush = Date.distantPast
    private var noticeWork: DispatchWorkItem?
    private var updateTimer: Timer?
    /// Groove della libreria o slot del brano che si sta trascinando (impostati all'inizio del trascinamento).
    var draggingGrooveID: UUID?
    var draggingSlotID: UUID?
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
    @Published var previewBPM: Double = 100 {
        didSet { if previewingGrooveID != nil { host?.setInternalBPM(previewBPM) } }
    }

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
            // Controllo periodico (ogni ora), mai mentre suona.
            updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                guard let self, !self.isPlaying else { return }
                switch self.updateState {
                case .available, .downloading, .checking: return
                default: self.checkForUpdates(userInitiated: false)
                }
            }
        }
        AppModel.shared = self
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
            learningTarget = nil
            previewingGrooveID = nil
            makeSelectedSongCurrentIfIdle()
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
        if !isRestoring {
            // Le modifiche ravvicinate (es. scrittura di un nome) diventano un solo passo di "Annulla".
            let now = Date()
            if undoStack.isEmpty || now.timeIntervalSince(lastUndoPush) > 1.0 {
                undoStack.append(old)
                if undoStack.count > 200 { undoStack.removeFirst() }
            }
            lastUndoPush = now
            if !redoStack.isEmpty { redoStack.removeAll() }
        }
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
        if library.performance.internalBPM != old.performance.internalBPM, snapshot?.internalClock == true {
            host.setInternalBPM(library.performance.internalBPM)
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

    /// Il Krome sta suonando e comanda la riproduzione.
    var isKromePlaying: Bool {
        guard let snap = snapshot else { return false }
        return snap.clockReceiving && snap.status.transportRunning
    }

    /// Qualcosa sta suonando (Krome, clock interno o ascolto).
    var isPlaying: Bool { snapshot?.status.transportRunning == true }

    func perform(_ action: ControlAction) {
        host?.perform(action)
    }

    /// Emergenza: silenzio immediato e stop di ascolto e clock interno.
    func panic() {
        host?.panic()
        previewingGrooveID = nil
        log.log("PANIC")
    }

    /// Che cosa farebbe STOP adesso (nil = niente da fermare).
    var stopLabel: String? {
        guard let snap = snapshot else { return nil }
        if snap.previewing { return "Ferma ascolto" }
        if snap.internalClock { return "Ferma" }
        if snap.status.transportRunning {
            if snap.status.stopPending { return nil }
            return snap.status.playingSlot == nil ? nil : "Silenzio a fine battuta"
        }
        return snap.status.armedSlot != nil ? "Annulla avvio" : nil
    }

    /// STOP: ferma ascolto o clock interno; con il Krome mette in coda il silenzio a fine battuta
    /// (il Krome resta il padrone del trasporto).
    func stopPlayback() {
        guard let snap = snapshot else { return }
        if snap.previewing {
            stopPreview()
        } else if snap.internalClock {
            host?.stopInternalClock()
        } else {
            perform(.stopAtBarEnd)
        }
        log.log("STOP")
    }

    /// Annulla un cambio di groove (o un silenzio) in coda.
    func cancelPending() {
        guard let playing = snapshot?.status.playingSlot else {
            perform(.stopAtBarEnd)
            return
        }
        perform(.triggerSlot(playing))
    }

    /// Avvia il brano selezionato con il clock interno (prova senza Krome).
    func startInternalClock() {
        guard !isKromePlaying else {
            errorMessage = "Il Krome sta suonando: ferma prima il suo sequencer."
            return
        }
        previewingGrooveID = nil
        if let index = selectedSongIndex { perform(.selectSong(index)) }
        host?.startInternalClock(bpm: library.performance.internalBPM)
    }

    func stopInternalClock() {
        host?.stopInternalClock()
    }

    /// Fa suonare uno slot del brano selezionato come se arrivasse il comando dal Krome.
    /// A riproduzione ferma parte con il clock interno.
    func playSlot(_ index: Int) {
        guard let songIndex = selectedSongIndex else { return }
        if snapshot?.status.songIndex != songIndex { perform(.selectSong(songIndex)) }
        if isPlaying, snapshot?.previewing != true {
            perform(.triggerSlot(index))
        } else {
            previewingGrooveID = nil
            perform(.triggerSlot(index))
            host?.startInternalClock(bpm: library.performance.internalBPM)
        }
    }

    /// Prova un comando dalla vista Comandi.
    func tryAction(_ action: ControlAction) {
        switch action {
        case let .triggerSlot(i):
            playSlot(i)
        case .fill, .nextSlot, .previousSlot, .stopAtBarEnd:
            guard isPlaying else {
                errorMessage = "Avvia prima la riproduzione (Krome, oppure ▶ Prova senza Krome nella barra in alto)."
                return
            }
            perform(action)
        case .panic:
            panic()
        case .intensity:
            errorMessage = "L'intensità si regola girando la manopola associata, oppure con il cursore in Impostazioni → Suono della batteria."
        case .start:
            guard !isPlaying else { return }
            guard snapshot?.clockReceiving == true else {
                errorMessage = "«Avvia» parte al tempo del Krome, ma il clock del Krome non arriva. Per provare senza Krome usa ▶ Prova senza Krome."
                return
            }
            perform(action)
        default:
            perform(action)
        }
    }

    /// A riproduzione ferma il brano selezionato in scaletta diventa il brano corrente.
    private func makeSelectedSongCurrentIfIdle() {
        guard !isPlaying, let index = selectedSongIndex, snapshot?.status.songIndex != index else { return }
        perform(.selectSong(index))
    }

    /// Apre la guida per collegare una DAW (dalla vista Preparazione o Comandi).
    func openDAWHelp() {
        showSettings = false
        if mode == .stage { mode = .prep }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showDAWHelp = true
        }
    }

    func openElementHelp() {
        showSettings = false
        if mode == .stage { mode = .prep }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showElementHelp = true
        }
    }

    func openGrooveHelp() {
        showSettings = false
        if mode == .stage { mode = .prep }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showGrooveHelp = true
        }
    }

    func showNotice(_ text: String) {
        notice = text
        noticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.notice = nil }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    // MARK: - Annulla / Ripeti

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(library)
        restore(previous)
        log.log("Annulla")
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(library)
        restore(next)
        log.log("Ripeti")
    }

    private func restore(_ value: Library) {
        isRestoring = true
        store?.library = value
        store?.restoreDeletedFiles()
        library = value
        isRestoring = false
        if let id = selectedSongID, value.songIndex(id: id) == nil { selectedSongID = value.songs.first?.id }
        if let s = selectedSongIndex, let id = selectedSlotID, !value.songs[s].slots.contains(where: { $0.id == id }) {
            selectedSlotID = nil
        }
    }

    /// ⌘⌫: toglie il groove selezionato dal brano, oppure chiede di eliminare il brano selezionato.
    func deleteSelection() {
        if selectedSlotIndex != nil {
            removeSelectedSlot()
        } else if selectedSongIndex != nil {
            confirmDeleteSong = true
        }
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

    func removeSlot(id: UUID) {
        guard let s = selectedSongIndex, let k = library.songs[s].slots.firstIndex(where: { $0.id == id }) else { return }
        library.removeSlots(fromSong: s, atOffsets: IndexSet(integer: k))
        if selectedSlotID == id { selectedSlotID = nil }
    }

    /// Rilascio su una scheda del brano: sposta lo slot trascinato in quella posizione, oppure
    /// inserisce lì il groove trascinato dalla libreria.
    func handleSlotDrop(onto index: Int) -> Bool {
        guard let s = selectedSongIndex else { return false }
        if let slotID = draggingSlotID {
            draggingSlotID = nil
            guard let from = library.songs[s].slots.firstIndex(where: { $0.id == slotID }), from != index else { return true }
            library.moveSlots(inSong: s, fromOffsets: IndexSet(integer: from), toOffset: index > from ? index + 1 : index)
            return true
        }
        if let grooveID = draggingGrooveID {
            draggingGrooveID = nil
            addSlot(grooveID: grooveID)
            let last = library.songs[s].slots.count - 1
            if last > index {
                library.moveSlots(inSong: s, fromOffsets: IndexSet(integer: last), toOffset: index)
            }
            return true
        }
        return false
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

    /// Groove della libreria trascinati sulla sequenza del brano. Si usa il groove annotato
    /// all'inizio del trascinamento; la lettura del testo trascinato resta solo come riserva.
    func handleGrooveDrop(_ providers: [NSItemProvider]) -> Bool {
        if let slotID = draggingSlotID, let s = selectedSongIndex {
            // Uno slot del brano rilasciato sul riquadro finale: va in fondo.
            draggingSlotID = nil
            if let from = library.songs[s].slots.firstIndex(where: { $0.id == slotID }) {
                library.moveSlots(inSong: s, fromOffsets: IndexSet(integer: from), toOffset: library.songs[s].slots.count)
            }
            return true
        }
        if let id = draggingGrooveID {
            draggingGrooveID = nil
            log.log("Trascinamento sulla sequenza: groove dalla libreria")
            addSlot(grooveID: id)
            return true
        }
        log.log("Trascinamento sulla sequenza senza groove annotato: tipi \(providers.flatMap { $0.registeredTypeIdentifiers })")
        var accepted = false
        for provider in providers {
            guard let type = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .text) == true
            }) else { continue }
            accepted = true
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                guard let data else { return }
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? ""
                guard let id = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
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

    func togglePreview(_ record: GrooveRecord, intensity: Double = 1) {
        if previewingGrooveID == record.id {
            stopPreview()
            return
        }
        guard let host, let original = groove(for: record) else { return }
        let groove = intensity == 1 ? original : original.scalingVelocities(by: intensity)
        guard !isKromePlaying else {
            errorMessage = "Il Krome sta suonando: ferma prima il suo sequencer per ascoltare un groove da solo."
            return
        }
        host.startPreview(groove: groove, bpm: previewBPM)
        previewingGrooveID = record.id
    }

    /// Il groove con le velocity moltiplicate, come file MIDI (stessa lunghezza e metro).
    private func scaledMIDIData(_ record: GrooveRecord, intensity: Double) -> (Data, Groove)? {
        guard let original = groove(for: record) else { return nil }
        let scaled = original.scalingVelocities(by: intensity)
        return (scaled.midiData(tempoBPM: original.sourceTempoBPM ?? 120), scaled)
    }

    /// Salva il groove con l'intensità scelta come nuovo groove della libreria (l'originale resta).
    func saveScaledGroove(_ record: GrooveRecord, intensity: Double) {
        guard let store, let result = scaledMIDIData(record, intensity: intensity) else { return }
        let (data, scaled) = result
        let name = "\(record.name) \(Int((intensity * 100).rounded()))%"
        do {
            let new = try store.importGroove(data: data, name: name, source: .user,
                                             lengthBars: scaled.wholeBars, timeSignature: scaled.timeSignature)
            library = store.library
            showNotice("Nuovo groove in libreria: «\(new.name)»")
            log.log("Intensità: «\(record.name)» salvato come «\(new.name)»")
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error)"
        }
    }

    /// Esporta il groove con l'intensità scelta in un file .mid scelto dall'utente.
    func exportScaledGroove(_ record: GrooveRecord, intensity: Double) {
        guard let data = scaledMIDIData(record, intensity: intensity)?.0 else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.midi]
        panel.nameFieldStringValue = "\(record.name) \(Int((intensity * 100).rounded()))%.mid"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            showNotice("Esportato: \(url.lastPathComponent)")
        } catch {
            errorMessage = "Esportazione non riuscita: \(error)"
        }
    }

    /// Intensità dal vivo della batteria (1 = colpi originali).
    func setLiveIntensity(_ factor: Double) {
        host?.setIntensity(factor)
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

    /// Tasti imparati dalla tastiera del Krome (note su un canale diverso dal 16), per numero di nota.
    func learnedNoteBindings() -> [Int: ControlBinding] {
        var result: [Int: ControlBinding] = [:]
        for b in library.controlMap.bindings where b.kind == .note && b.channel != 16 {
            if let n = b.number { result[n] = b }
        }
        return result
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
            if let previous = library.controlMap.bindings.first(where: {
                $0.kind == binding.kind && $0.channel == binding.channel && $0.number == binding.number && $0.action != action
            }) {
                showNotice("\(binding.triggerLabel) ora comanda «\(action.label)» (prima: «\(previous.action.label)»)")
            } else {
                showNotice("\(binding.triggerLabel) ora comanda «\(action.label)»")
            }
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
