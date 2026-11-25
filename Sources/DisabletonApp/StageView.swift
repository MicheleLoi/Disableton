#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import MIDIHost
import SwiftUI

/// Palco: schermata scura a tutto schermo, leggibile da 2–3 metri, senza interazione.
struct StageView: View {
    @EnvironmentObject var model: AppModel

    private let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    private let secondary = Color(white: 0.64)

    var body: some View {
        let snap = model.snapshot
        let status = snap?.status
        let songIndex = status?.songIndex
        let songCount = model.library.songs.count

        VStack(alignment: .leading, spacing: 26) {
            HStack {
                Text(songIndex.map { "BRANO \($0 + 1) / \(songCount)" } ?? "NESSUN BRANO")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(secondary)
                Spacer()
                HStack(spacing: 10) {
                    Circle().fill(clockColor(snap)).frame(width: 16, height: 16)
                    Text(clockText(snap)).font(.system(size: 22, weight: .semibold))
                }
                if let label = model.stopLabel {
                    Button { model.stopPlayback() } label: {
                        Label(label, systemImage: "stop.fill")
                    }
                    .padding(.leading, 20)
                }
                Button { model.panic() } label: {
                    Text("PANIC").fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.75, green: 0.11, blue: 0.11)))
                }
                .buttonStyle(.plain)
                .help("Silenzio immediato (⇧⌘.)")
                Button("Preparazione") { model.mode = .prep }
                    .keyboardShortcut(.cancelAction)
                    .padding(.leading, 12)
                Button { model.toggleFullScreen() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Schermo intero")
                .keyboardShortcut("f", modifiers: [.command, .control])
            }

            Text(status?.songName ?? "–")
                .font(.system(size: 76, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            HStack(alignment: .top, spacing: 28) {
                Panel(title: "SUONA", titleColor: Color(red: 0.53, green: 0.94, blue: 0.67),
                      main: status?.playingSlotName ?? "Silenzio", mainSize: 64,
                      detail: playingDetail(status),
                      fill: Color(red: 0.06, green: 0.19, blue: 0.11),
                      border: Color(red: 0.29, green: 0.87, blue: 0.5))
                    .frame(maxWidth: .infinity)
                Panel(title: nextTitle(status), titleColor: Color(red: 0.99, green: 0.83, blue: 0.3),
                      main: nextName(status), mainSize: 52,
                      detail: nextDetail(status),
                      fill: Color(red: 0.18, green: 0.12, blue: 0.03),
                      border: Color(red: 0.98, green: 0.75, blue: 0.14))
                    .frame(maxWidth: .infinity)
                    .layoutPriority(-1)
            }

            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BATTUTA").font(.system(size: 20, weight: .semibold)).foregroundColor(secondary)
                    Text(snap?.bar.map { "\($0)" } ?? "–")
                        .font(.system(size: 96, weight: .heavy).monospacedDigit())
                }
                BeatDots(beat: snap?.beat, count: snap?.beatsPerBar ?? 4, size: 64,
                         lit: Color(red: 0.29, green: 0.87, blue: 0.5), unlit: Color(white: 0.25))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TEMPO").font(.system(size: 20, weight: .semibold)).foregroundColor(secondary)
                    Text(snap?.tempoBPM.map { String(format: "%.0f", $0) } ?? "–")
                        .font(.system(size: 72, weight: .heavy).monospacedDigit())
                }
            }

            Spacer()

            HStack(spacing: 18) {
                Text("Brano successivo:").font(.system(size: 24)).foregroundColor(secondary)
                Text(nextSong(songIndex)).font(.system(size: 28, weight: .bold))
                Spacer()
                Text("Esc = Preparazione").font(.system(size: 16)).foregroundColor(secondary)
            }
            .padding(.top, 14)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(white: 0.25)), alignment: .top)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 32)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
    }

    private func clockColor(_ snap: LiveSnapshot?) -> Color {
        guard let snap else { return .red }
        if snap.internalClock || snap.previewing { return .blue }
        return snap.clockReceiving ? Color(red: 0.29, green: 0.87, blue: 0.5) : .orange
    }

    private func clockText(_ snap: LiveSnapshot?) -> String {
        guard let snap else { return "MOTORE FERMO" }
        if snap.internalClock { return "CLOCK INTERNO" }
        if snap.previewing { return "ASCOLTO" }
        return snap.clockReceiving ? "CLOCK KROME" : "ATTESA CLOCK"
    }

    private func slot(_ index: Int?, in status: PlaybackStatus?) -> SlotRecord? {
        guard let index, let s = status?.songIndex, model.library.songs.indices.contains(s),
              model.library.songs[s].slots.indices.contains(index) else { return nil }
        return model.library.songs[s].slots[index]
    }

    private func playingDetail(_ status: PlaybackStatus?) -> String {
        guard let i = status?.playingSlot, let slot = slot(i, in: status) else { return " " }
        return "Slot \(i + 1) · \(slot.mode.label.lowercased())"
    }

    private func nextTitle(_ status: PlaybackStatus?) -> String {
        status?.pendingSlot != nil || status?.stopPending == true ? "PROSSIMO" : "IN CODA"
    }

    private func nextName(_ status: PlaybackStatus?) -> String {
        if status?.stopPending == true { return "Silenzio" }
        return status?.pendingSlotName ?? "–"
    }

    private func nextDetail(_ status: PlaybackStatus?) -> String {
        guard let i = status?.pendingSlot, let slot = slot(i, in: status) else { return " " }
        switch slot.mode {
        case .oneShotReturn:
            return "poi torna a \(status?.playingSlotName ?? "il groove precedente")"
        case .oneShotNext:
            return "poi il groove successivo"
        case .oneShotStop:
            return "poi silenzio"
        case .loop:
            return slot.quantize.label.lowercased()
        }
    }

    private func nextSong(_ index: Int?) -> String {
        let next = (index ?? -1) + 1
        guard model.library.songs.indices.contains(next) else { return "fine della scaletta" }
        return "\(next + 1) · \(model.library.songs[next].name)"
    }
}

private struct Panel: View {
    let title: String
    let titleColor: Color
    let main: String
    let mainSize: CGFloat
    let detail: String
    let fill: Color
    let border: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 22, weight: .semibold)).foregroundColor(titleColor)
            Text(main)
                .font(.system(size: mainSize, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(detail).font(.system(size: 26)).foregroundColor(Color(white: 0.85)).lineLimit(1)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 3))
    }
}
#endif
