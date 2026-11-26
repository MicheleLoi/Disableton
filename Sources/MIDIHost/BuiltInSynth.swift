#if canImport(CoreMIDI) && canImport(AVFoundation)
import AVFoundation
import AudioToolbox
import GrooveCore

/// Sintetizzatore General MIDI integrato in macOS (Apple DLS Synth): suoni di prova gratuiti,
/// con la batteria sul canale 10, per usare Disableton senza altri strumenti.
public final class BuiltInSynth {
    private let engine = AVAudioEngine()
    private let instrument: AVAudioUnitMIDIInstrument
    private let sampleRate: Double

    public init() throws {
        let description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                    componentSubType: kAudioUnitSubType_DLSSynth,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        instrument = AVAudioUnitMIDIInstrument(audioComponentDescription: description)
        engine.attach(instrument)
        engine.connect(instrument, to: engine.mainMixerNode, format: nil)
        try engine.start()
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        sampleRate = rate > 0 ? rate : 44_100
    }

    /// Suona il messaggio all'istante indicato (ns), con precisione al campione quando possibile.
    public func send(_ message: MIDIMessage, atNanos time: UInt64) {
        let bytes = message.bytes
        guard let status = bytes.first, status < 0xF0 else { return }
        let now = HostClock.nowNanos()
        let delay = time > now ? Double(time - now) : 0
        let frames = AUEventSampleTime(delay * sampleRate / 1_000_000_000)
        if let schedule = instrument.auAudioUnit.scheduleMIDIEventBlock {
            bytes.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    schedule(AUEventSampleTimeImmediate + frames, 0, bytes.count, base)
                }
            }
        } else {
            let d1 = bytes.count > 1 ? bytes[1] : 0
            let d2 = bytes.count > 2 ? bytes[2] : 0
            instrument.sendMIDIEvent(status, data1: d1, data2: d2)
        }
    }

    public func stop() {
        engine.stop()
    }
}
#endif
