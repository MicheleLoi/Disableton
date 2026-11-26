#if canImport(SwiftUI) && os(macOS)
import MIDIHost
import SwiftUI

/// Guida: far suonare la batteria di Disableton da una DAW, con REAPER come esempio.
struct DAWHelpView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Connecting a DAW (example: REAPER)").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Disableton sends its drum notes to a MIDI port called “\(LiveHost.virtualPortName)”. A DAW can receive them and play them with its own instruments. Timing comes from the Krome or from Disableton's internal clock: the DAW doesn't need to be synced or playing.")
                        .fixedSize(horizontal: false, vertical: true)

                    section("In Disableton", [
                        "Settings → Suono della batteria (drum sound) → “Porta virtuale «\(LiveHost.virtualPortName)»” (virtual port).",
                        "Keep Disableton open while you use the DAW: the “\(LiveHost.virtualPortName)” port only exists while the app is open.",
                    ], start: 1)

                    section("In REAPER, once", [
                        "Open REAPER → Settings… (⌘,) → Audio → MIDI Inputs (called MIDI Devices in older versions).",
                        "Right-click the “\(LiveHost.virtualPortName)” row and choose “Enable input for track record input”. Then Apply and OK. The other menu items aren't needed.",
                        "If “\(LiveHost.virtualPortName)” isn't in the list, REAPER was opened before Disableton: press “Reset all MIDI devices” on the same page, or quit and reopen REAPER with Disableton already open.",
                    ], start: 3)

                    section("In each REAPER project", [
                        "Set up a track with the drum instrument you want to use.",
                        "On the track, open the input menu (below the track name) and choose Input: MIDI → \(LiveHost.virtualPortName) → All channels.",
                        "Arm the track with its red record button and turn on input monitoring (the speaker icon next to the red button).",
                        "To avoid recording while you play: right-click the red button → “Record: disable (input monitoring only)”.",
                        "Test: in Disableton press ▶ Prova senza Krome (play without Krome). The REAPER track shows MIDI activity and the instrument plays.",
                    ], start: 6)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("If something doesn't work").font(.headline)
                        bullet("The instrument plays the wrong sounds (e.g. a snare instead of the kick): the kit doesn't follow the General MIDI layout. Choose a General MIDI kit; note conversion is coming.")
                        bullet("The drums lag behind the Krome: in REAPER → Settings → Audio → Device lower “Request block size” (e.g. 128), then adjust “Anticipo batteria” (drum advance) in Disableton's settings.")
                        bullet("The track receives nothing: check that it's armed, with monitoring on and input “\(LiveHost.virtualPortName)”, and that Disableton's drum sound destination is the virtual port.")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func section(_ title: String, _ steps: [String], start: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(start + offset).").fontWeight(.semibold).frame(width: 24, alignment: .trailing)
                    Text(text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").frame(width: 24, alignment: .trailing)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
