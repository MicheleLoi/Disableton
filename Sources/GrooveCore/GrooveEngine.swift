import Foundation

/// Comportamento di uno slot quando viene eseguito.
public enum SlotMode: String, Codable, Sendable, CaseIterable {
    /// Ripetuto finché non arriva un altro comando.
    case loop
    /// Suonato una volta, poi ritorno al groove ripetuto precedente (fill).
    case oneShotReturn = "fill"
    /// Suonato una volta, poi passaggio allo slot successivo.
    case oneShotNext = "next"
    /// Suonato una volta, poi silenzio (finale).
    case oneShotStop = "ending"

    public var isOneShot: Bool { self != .loop }
}

/// Quando un comando di cambio diventa effettivo.
public enum Quantize: String, Codable, Sendable, CaseIterable {
    case beat
    case bar
    /// Alla fine del ciclo del groove in corso.
    case grooveEnd = "end"
}

public struct EngineSlot: Sendable {
    public var name: String
    public var groove: Groove
    public var mode: SlotMode
    public var quantize: Quantize

    public init(name: String, groove: Groove, mode: SlotMode = .loop, quantize: Quantize = .bar) {
        self.name = name
        self.groove = groove
        self.mode = mode
        self.quantize = quantize
    }
}

public struct EngineSong: Sendable {
    public var name: String
    public var timeSignature: TimeSignature
    public var slots: [EngineSlot]
    /// Slot avviato automaticamente allo Start del Krome (nil = attende un comando).
    public var autoStartSlot: Int?

    public init(name: String, timeSignature: TimeSignature = .fourFour, slots: [EngineSlot], autoStartSlot: Int? = 0) {
        self.name = name
        self.timeSignature = timeSignature
        self.slots = slots
        self.autoStartSlot = autoStartSlot
    }
}

/// Messaggio da inviare a una posizione del brano (tick a `Groove.ppq`).
public struct ScheduledMIDI: Equatable, Sendable {
    public var tick: Int
    public var message: MIDIMessage

    public init(tick: Int, message: MIDIMessage) {
        self.tick = tick
        self.message = message
    }
}

/// Motore dei groove: lavora solo in tempo musicale (tick), indipendente da orologi e MIDI I/O.
///
/// Il chiamante avanza la riproduzione con `render(to:)`; i cambi richiesti con i comandi
/// vengono messi in coda e applicati al confine musicale scelto (battito, battuta, fine groove).
/// Le battute sono contate dall'inizio del brano (posizione 0) con il metro del brano.
public final class GrooveEngine {
    private struct Segment {
        let slotIndex: Int
        let groove: Groove
        let mode: SlotMode
        /// Posizione assoluta del tick 0 della prima ripetizione.
        let start: Int
        /// Nessun evento prima di questa posizione (ripartenze a metà brano).
        let activeFrom: Int
        /// Groove ripetuto a cui tornare dopo un fill.
        let returnSlot: Int?

        var end: Int? { mode.isOneShot ? start + groove.lengthTicks : nil }
    }

    private struct Pending {
        /// nil = silenzio.
        let slotIndex: Int?
        let boundary: Int
    }

    /// Canale di uscita, 0-based (9 = canale 10).
    public var outputChannel: UInt8
    public private(set) var song: EngineSong?
    public private(set) var isRunning = false
    /// Fin dove è già stato generato il brano.
    public private(set) var renderedTo = 0

    private var segment: Segment?
    private var pending: Pending?
    private var armedSlot: Int?
    private var lastLoopSlot: Int?
    private var activeNotes = Set<UInt8>()

    public init(outputChannel: UInt8 = 9) {
        self.outputChannel = outputChannel
    }

    // MARK: - Stato

    public var playingSlotIndex: Int? { segment?.slotIndex }
    public var pendingSlotIndex: Int? { pending?.slotIndex }
    public var isStopPending: Bool { pending != nil && pending?.slotIndex == nil }
    public var pendingBoundary: Int? { pending?.boundary }
    /// Slot scelto a trasporto fermo, che partirà allo Start.
    public var armedSlotIndex: Int? { armedSlot }

    // MARK: - Comandi

    public func load(song: EngineSong) {
        self.song = song
        armedSlot = nil
        lastLoopSlot = nil
        // A batteria ferma, o in silenzio con il clock che continua (dopo un finale o uno stop
        // in Combi), il nuovo brano aspetta un comando invece di partire da solo.
        guard isRunning, segment != nil else { pending = nil; return }
        let next = song.autoStartSlot.flatMap { song.slots.indices.contains($0) ? $0 : nil }
        pending = Pending(slotIndex: next, boundary: boundary(for: .bar))
    }

    public func trigger(slot index: Int) {
        guard let song, song.slots.indices.contains(index) else { return }
        guard isRunning else { armedSlot = index; return }
        let slot = song.slots[index]
        if slot.mode == .loop, let seg = segment, seg.slotIndex == index, seg.mode == .loop {
            // Groove già in esecuzione: annulla eventuali cambi in coda.
            pending = nil
            return
        }
        pending = Pending(slotIndex: index, boundary: boundary(for: slot.quantize))
    }

    /// True se il trasporto è avviato ma non suona niente e non c'è niente in coda.
    public var isSilentWhileRunning: Bool { isRunning && segment == nil && pending == nil }

    /// Fa partire il groove di avvio del brano (al momento scelto per quello slot).
    public func triggerAutoStart() {
        guard let song, let i = song.autoStartSlot, song.slots.indices.contains(i) else { return }
        trigger(slot: i)
    }

    /// Esegue il primo slot di tipo fill del brano.
    public func triggerFill() {
        guard let song, let i = song.slots.firstIndex(where: { $0.mode == .oneShotReturn }) else { return }
        trigger(slot: i)
    }

    public func triggerNextSlot() { stepLoopSlot(by: 1) }
    public func triggerPreviousSlot() { stepLoopSlot(by: -1) }

    /// Silenzio dalla battuta successiva (il trasporto del Krome continua).
    public func stopAtNextBar() {
        guard isRunning else { armedSlot = nil; return }
        pending = Pending(slotIndex: nil, boundary: boundary(for: .bar))
    }

    // MARK: - Trasporto

    /// Avvio dalla posizione indicata (0 per Start, la posizione SPP per Continue).
    public func transportStarted(at tick: Int) {
        isRunning = true
        renderedTo = max(0, tick)
        activeNotes.removeAll()
        pending = nil
        segment = nil
        guard let song else { armedSlot = nil; return }
        let chosen: Int?
        if let armed = armedSlot {
            chosen = armed
        } else if renderedTo > 0, let last = lastLoopSlot {
            chosen = last
        } else {
            chosen = song.autoStartSlot
        }
        armedSlot = nil
        guard let index = chosen, song.slots.indices.contains(index) else { return }
        let slot = song.slots[index]
        if slot.mode == .loop {
            let len = slot.groove.lengthTicks
            lastLoopSlot = index
            segment = Segment(slotIndex: index, groove: slot.groove, mode: .loop,
                              start: floorDiv(renderedTo, len) * len, activeFrom: renderedTo, returnSlot: nil)
        } else {
            pending = Pending(slotIndex: index, boundary: boundary(for: .bar))
        }
    }

    /// Arresto: restituisce i messaggi per spegnere le note ancora attive.
    public func transportStopped() -> [MIDIMessage] {
        isRunning = false
        segment = nil
        pending = nil
        return silenceMessages()
    }

    public func panic() -> [MIDIMessage] { silenceMessages() }

    /// Silenzio immediato: ferma il groove in corso e svuota la coda, senza fermare il trasporto
    /// (il Krome continua a mandare il clock; un nuovo comando fa ripartire un groove).
    public func silenceNow() -> [MIDIMessage] {
        segment = nil
        pending = nil
        armedSlot = nil
        return silenceMessages()
    }

    // MARK: - Generazione

    /// Genera gli eventi del brano fino alla posizione `target` (esclusa).
    public func render(to target: Int) -> [ScheduledMIDI] {
        var out: [ScheduledMIDI] = []
        guard isRunning else { return out }
        var iterations = 0
        while renderedTo < target && iterations < 10_000 {
            iterations += 1
            var changeAt = Int.max
            if let end = segment?.end { changeAt = end }
            if let p = pending { changeAt = min(changeAt, p.boundary) }
            let chunkEnd = min(target, changeAt)
            if let seg = segment, chunkEnd > renderedTo {
                emit(seg, from: renderedTo, to: chunkEnd, into: &out)
            }
            renderedTo = max(renderedTo, chunkEnd)
            if changeAt != Int.max && renderedTo >= changeAt {
                performTransition(at: changeAt, into: &out)
            }
        }
        return out
    }

    // MARK: - Interni

    private func performTransition(at boundary: Int, into out: inout [ScheduledMIDI]) {
        flushNotes(at: boundary, into: &out)
        let next: Int?
        if let p = pending, p.boundary <= boundary {
            next = p.slotIndex
            pending = nil
        } else if let seg = segment {
            switch seg.mode {
            case .oneShotReturn: next = seg.returnSlot
            case .oneShotNext: next = nextIndex(after: seg.slotIndex) ?? seg.returnSlot
            case .oneShotStop: next = nil
            case .loop: next = seg.slotIndex
            }
        } else {
            next = nil
        }
        let returnSlot: Int?
        if let seg = segment {
            returnSlot = seg.mode == .loop ? seg.slotIndex : seg.returnSlot
        } else {
            returnSlot = lastLoopSlot
        }
        guard let index = next, let song, song.slots.indices.contains(index) else {
            segment = nil
            return
        }
        let slot = song.slots[index]
        if slot.mode == .loop { lastLoopSlot = index }
        segment = Segment(slotIndex: index, groove: slot.groove, mode: slot.mode, start: boundary,
                          activeFrom: boundary, returnSlot: slot.mode == .loop ? nil : returnSlot)
    }

    private func emit(_ seg: Segment, from a: Int, to b: Int, into out: inout [ScheduledMIDI]) {
        let len = seg.groove.lengthTicks
        let lo = max(a, seg.activeFrom, seg.start)
        var hi = b
        if let end = seg.end { hi = min(hi, end) }
        guard lo < hi else { return }
        let firstK = floorDiv(lo - seg.start, len)
        let lastK = floorDiv(hi - 1 - seg.start, len)
        guard lastK >= firstK else { return }
        for k in firstK...lastK {
            if seg.mode.isOneShot && k != 0 { continue }
            let base = seg.start + k * len
            for i in seg.groove.eventIndices(from: lo - base, to: hi - base) {
                let event = seg.groove.events[i]
                out.append(ScheduledMIDI(tick: base + event.tick, message: message(for: event.kind)))
            }
        }
    }

    private func message(for kind: GrooveEvent.Kind) -> MIDIMessage {
        switch kind {
        case let .noteOn(note, velocity):
            activeNotes.insert(note)
            return .noteOn(channel: outputChannel, note: note, velocity: velocity)
        case let .noteOff(note):
            activeNotes.remove(note)
            return .noteOff(channel: outputChannel, note: note, velocity: 0)
        case let .controlChange(controller, value):
            return .controlChange(channel: outputChannel, controller: controller, value: value)
        }
    }

    private func flushNotes(at tick: Int, into out: inout [ScheduledMIDI]) {
        for note in activeNotes.sorted() {
            out.append(ScheduledMIDI(tick: tick, message: .noteOff(channel: outputChannel, note: note, velocity: 0)))
        }
        activeNotes.removeAll()
    }

    private func silenceMessages() -> [MIDIMessage] {
        var messages = activeNotes.sorted().map { MIDIMessage.noteOff(channel: outputChannel, note: $0, velocity: 0) }
        activeNotes.removeAll()
        messages.append(.controlChange(channel: outputChannel, controller: 123, value: 0))
        return messages
    }

    private func boundary(for quantize: Quantize) -> Int {
        let ts = song?.timeSignature ?? .fourFour
        func ceilTo(_ step: Int, offset: Int = 0) -> Int {
            offset + ceilDiv(renderedTo - offset, step) * step
        }
        switch quantize {
        case .beat:
            return ceilTo(ts.ticksPerBeat(ppq: Groove.ppq))
        case .bar:
            return ceilTo(ts.ticksPerBar(ppq: Groove.ppq))
        case .grooveEnd:
            guard let seg = segment else { return ceilTo(ts.ticksPerBar(ppq: Groove.ppq)) }
            if let end = seg.end { return max(end, renderedTo) }
            return ceilTo(seg.groove.lengthTicks, offset: seg.start)
        }
    }

    private func nextIndex(after index: Int) -> Int? {
        guard let song, index + 1 < song.slots.count else { return nil }
        return index + 1
    }

    private func stepLoopSlot(by step: Int) {
        guard let song, !song.slots.isEmpty else { return }
        let current = pending?.slotIndex
            ?? segment.map { $0.mode == .loop ? $0.slotIndex : ($0.returnSlot ?? $0.slotIndex) }
            ?? armedSlot
            ?? lastLoopSlot
        let n = song.slots.count
        var i = current ?? (step > 0 ? -1 : 0)
        for _ in 0..<n {
            i = ((i + step) % n + n) % n
            if song.slots[i].mode == .loop {
                trigger(slot: i)
                return
            }
        }
    }
}

func floorDiv(_ a: Int, _ b: Int) -> Int {
    precondition(b > 0)
    return a >= 0 ? a / b : -((-a + b - 1) / b)
}

func ceilDiv(_ a: Int, _ b: Int) -> Int {
    -floorDiv(-a, b)
}
