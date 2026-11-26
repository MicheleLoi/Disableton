#if canImport(SwiftUI) && os(macOS)
import AppKit
import MIDIHost
import SwiftUI

/// Guida: Element, un programma gratuito che apre strumenti plugin senza una DAW.
struct ElementHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let downloadURL = URL(string: "https://github.com/kushview/element/releases/tag/1.1.1")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Element: plugin instruments without a DAW").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Element is a free, open-source program that opens plugin instruments (AU, VST3) and plays them via MIDI, without everything a DAW does: no tracks, recording or projects.")
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("When to use it").font(.headline)
                        bullet("The drum instrument you want exists only as a plugin, with no standalone app.")
                        bullet("You want a light setup that opens the same way every time on stage, instead of a full DAW. It's also free, while REAPER needs a license.")
                        Text("When you don't need it").font(.headline).padding(.top, 6)
                        bullet("The instrument has its own standalone app (EZdrummer 3, Analog Lab, Pigments): just select “\(LiveHost.virtualPortName)” as the MIDI input in that app.")
                        bullet("You use the macOS synth or the Krome: Disableton reaches them on its own.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Download").font(.headline)
                        Button("Element 1.1.1 on GitHub") { NSWorkspace.shared.open(downloadURL) }
                        Text("On that page, scroll down to Assets and download the macOS file (not “Source code”, which is for developers). Move Element into Applications (there's no installer); the first time, right-click Element → Open. Don't confuse it with the chat app also called “Element”.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Connecting it to Disableton", [
                        "In Disableton: Settings → Suono della batteria (drum sound) → “Porta virtuale «\(LiveHost.virtualPortName)»” (virtual port). Keep Disableton open.",
                        "Open Element. In its preferences, MIDI section, enable the “\(LiveHost.virtualPortName)” input. If it isn't listed, quit and reopen Element with Disableton already open.",
                        "Load the drum instrument, then connect the MIDI input to the instrument and the instrument to the audio output.",
                        "Test: in Disableton press ▶ Prova senza Krome (play without Krome). The instrument in Element should play.",
                    ])

                    Text("Playing several instruments at once (one drum sound each) needs a Disableton feature that's still in preparation; when it's ready, this page will explain how to use it with Element.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func section(_ title: String, _ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { offset, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(offset + 1).").fontWeight(.semibold).frame(width: 24, alignment: .trailing)
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
