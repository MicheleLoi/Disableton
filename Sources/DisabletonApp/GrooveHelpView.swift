#if canImport(SwiftUI) && os(macOS)
import AppKit
import SwiftUI

/// Guida: cosa fa un groove dentro un brano (ripetuto, fill, finale…) e come crearne con l'AI.
struct GrooveHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied: String?

    static let prompts: [(title: String, text: String)] = [
        ("Groove (repeated)", """
        Create a downloadable MIDI file (.mid) with a drum groove that loops seamlessly. \
        Use General MIDI drum notes on channel 10. Time signature: … . Length: exactly … bars. \
        Style: … . Tempo for reference: … BPM. Name the file "…".
        """),
        ("Fill", """
        Create a downloadable MIDI file (.mid) with a drum fill. Use General MIDI drum notes on \
        channel 10. Time signature: … . Length: exactly 1 bar. It comes after a … groove and \
        leads back into it: … . Keep every note inside the bar (no crash on the next downbeat). \
        Name the file "Fill …".
        """),
        ("Ending", """
        Create a downloadable MIDI file (.mid) with a drum ending. Use General MIDI drum notes on \
        channel 10. Time signature: … . Length: exactly … bar(s). Style: … . It ends with … , \
        then silence. Name the file "Finale …".
        """),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Fills, endings and groove behaviour").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A MIDI file contains only notes: which drum plays, when and how hard. Whether a groove repeats, plays once and goes back, or ends the song is decided in Disableton, separately for each song.")
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comportamento (behaviour)").font(.headline)
                        Text("Select a groove card in a song: the panel on the right shows its Comportamento.")
                            .fixedSize(horizontal: false, vertical: true)
                        bullet("Ripetuto (repeated): loops until another command arrives.")
                        bullet("Fill, poi ritorno (fill, then back) ↩: plays once, then goes back by itself to the repeated groove that was playing before.")
                        bullet("Una volta, poi il successivo (once, then the next one): plays once, then moves on to the next groove of the song. Useful for a fill that leads from verse to chorus.")
                        bullet("Finale, poi silenzio (ending, then silence) ■: plays once, then the drums stop.")
                        Text("When you add a groove to a song, Disableton picks the behaviour from its name: if the name contains “fill” it becomes Fill, poi ritorno; if it contains “finale”, Finale, poi silenzio; anything else is Ripetuto. You can change it at any time, and the same file can behave differently in different songs. The groove's name is the file name: “Fill tom.mid” becomes “Fill tom”.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cambio (when it starts)").font(.headline)
                        bullet("Alla battuta (at the bar), the default: it starts on the next downbeat. For a fill in bar 8, trigger it during bar 7.")
                        bullet("Al battito (at the beat): it starts on the next beat. For a half-bar fill, trigger it during beat 2 so that it starts on beat 3.")
                        bullet("A fine groove (at the end of the groove): it waits until the current groove reaches its end.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good to know").font(.headline)
                        bullet("The Fill command (from the workstation) plays the first fill of the song. Other fills are triggered with their own position key (1, 2, 3…), like any groove.")
                        bullet("After a fill, the groove starts again from its beginning.")
                        bullet("A fill must end on a bar line. One-bar fills work best, including those that start with the groove and end with the actual fill.")
                        bullet("Disableton measures a groove in whole bars, up to the last bar that contains a note. Empty bars at the beginning are skipped.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Making grooves with AI").font(.headline)
                        Text("Copy a template, fill in the “…”, and paste it into an AI chat that can create downloadable files. Then import the .mid file into Disableton. Listen to the result before using it on stage.")
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Self.prompts, id: \.title) { prompt in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(prompt.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button(copied == prompt.title ? "Copied" : "Copy") { copy(prompt) }
                                }
                                Text(prompt.text)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        }
                        Text("Examples for the “…”: time signature 4/4, 3/4 or 6/8; style rock, funk, shuffle, ballad; “two beats of groove, then toms from high to low”; “kick and crash together on beat 1”.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func copy(_ prompt: (title: String, text: String)) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.text, forType: .string)
        copied = prompt.title
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
