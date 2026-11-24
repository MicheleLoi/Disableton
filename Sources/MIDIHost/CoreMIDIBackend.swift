#if canImport(CoreMIDI)
import CoreMIDI
import Darwin
import Foundation
import GrooveCore

/// Orologio di sistema in nanosecondi (host time di CoreMIDI convertito).
public enum HostClock {
    public static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    public static func nanos(fromHost t: UInt64) -> UInt64 {
        t / UInt64(timebase.denom) * UInt64(timebase.numer)
            + (t % UInt64(timebase.denom)) * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    public static func host(fromNanos n: UInt64) -> UInt64 {
        n / UInt64(timebase.numer) * UInt64(timebase.denom)
            + (n % UInt64(timebase.numer)) * UInt64(timebase.denom) / UInt64(timebase.numer)
    }

    public static func nowNanos() -> UInt64 { nanos(fromHost: mach_absolute_time()) }

    public static func wait(untilNanos n: UInt64) { mach_wait_until(host(fromNanos: n)) }
}

public struct MIDIBackendError: Error, CustomStringConvertible {
    public let status: OSStatus
    public let call: String
    public var description: String { "\(call) non riuscita (OSStatus \(status))" }
}

/// Ingresso dal Krome e porta virtuale di uscita verso EZdrummer (protocollo MIDI 1.0 via UMP).
public final class MIDIBackend {
    public struct Endpoint {
        public let ref: MIDIEndpointRef
        public let name: String
    }

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var virtualSource = MIDIEndpointRef()
    private var connected: [MIDIEndpointRef] = []

    /// Chiamato sul thread di CoreMIDI con il messaggio e il suo istante (ns).
    public var onMessage: ((MIDIMessage, UInt64) -> Void)?

    public init(clientName: String) throws {
        var status = MIDIClientCreateWithBlock(clientName as CFString, &client) { _ in }
        guard status == noErr else { throw MIDIBackendError(status: status, call: "MIDIClientCreate") }
        status = MIDIInputPortCreateWithProtocol(client, "\(clientName) In" as CFString, ._1_0, &inputPort) { [weak self] list, _ in
            self?.receive(list)
        }
        guard status == noErr else { throw MIDIBackendError(status: status, call: "MIDIInputPortCreate") }
    }

    public static var sources: [Endpoint] {
        (0..<MIDIGetNumberOfSources()).map { i in
            let ref = MIDIGetSource(i)
            return Endpoint(ref: ref, name: displayName(ref))
        }
    }

    public static var destinations: [Endpoint] {
        (0..<MIDIGetNumberOfDestinations()).map { i in
            let ref = MIDIGetDestination(i)
            return Endpoint(ref: ref, name: displayName(ref))
        }
    }

    public static func displayName(_ object: MIDIObjectRef) -> String {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &name)
        guard status == noErr, let value = name?.takeRetainedValue() else { return "(senza nome)" }
        return value as String
    }

    /// Collega le sorgenti il cui nome contiene `filter` (senza distinzione di maiuscole).
    /// Restituisce i nomi collegati.
    @discardableResult
    public func connectSources(matching filter: String?) throws -> [String] {
        var names: [String] = []
        for source in MIDIBackend.sources {
            if source.ref == virtualSource || connected.contains(source.ref) { continue }
            if let filter, !source.name.localizedCaseInsensitiveContains(filter) { continue }
            let status = MIDIPortConnectSource(inputPort, source.ref, nil)
            guard status == noErr else { throw MIDIBackendError(status: status, call: "MIDIPortConnectSource") }
            connected.append(source.ref)
            names.append(source.name)
        }
        return names
    }

    /// Scollega tutte le sorgenti collegate.
    public func disconnectAll() {
        for ref in connected { MIDIPortDisconnectSource(inputPort, ref) }
        connected.removeAll()
    }

    /// Crea la porta virtuale che EZdrummer vedrà come ingresso MIDI.
    public func createVirtualSource(named name: String) throws {
        let status = MIDISourceCreateWithProtocol(client, name as CFString, ._1_0, &virtualSource)
        guard status == noErr else { throw MIDIBackendError(status: status, call: "MIDISourceCreate") }
    }

    /// Invia un messaggio dalla porta virtuale con timestamp (ns, 0 = subito).
    public func send(_ message: MIDIMessage, atNanos time: UInt64) {
        guard virtualSource != 0, let word = UMP.word(for: message) else { return }
        var w = word
        let timestamp: MIDITimeStamp = time == 0 ? 0 : HostClock.host(fromNanos: time)
        var list = MIDIEventList()
        withUnsafeMutablePointer(to: &list) { listPointer in
            let packet = MIDIEventListInit(listPointer, ._1_0)
            _ = MIDIEventListAdd(listPointer, MemoryLayout<MIDIEventList>.size, packet, timestamp, 1, &w)
            _ = MIDIReceivedEventList(virtualSource, listPointer)
        }
    }

    private func receive(_ list: UnsafePointer<MIDIEventList>) {
        for packet in list.unsafeSequence() {
            let timestamp = packet.pointee.timeStamp
            let count = min(Int(packet.pointee.wordCount), 64)
            let words: [UInt32] = withUnsafeBytes(of: packet.pointee.words) { raw in
                (0..<count).map { raw.load(fromByteOffset: $0 * 4, as: UInt32.self) }
            }
            let time = timestamp == 0 ? HostClock.nowNanos() : HostClock.nanos(fromHost: timestamp)
            for message in UMP.messages(from: words) {
                onMessage?(message, time)
            }
        }
    }

    deinit {
        if virtualSource != 0 { MIDIEndpointDispose(virtualSource) }
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }
}

/// Impedisce ad App Nap e allo stop di sistema di rallentare la riproduzione.
public enum PerformanceGuard {
    static var token: NSObjectProtocol?

    public static func begin(reason: String) {
        token = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
            reason: reason)
    }
}
#endif
