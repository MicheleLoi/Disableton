#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import MIDIHost
import SwiftUI

/// Schermata per l'esecuzione: stato grande e leggibile, comandi di emergenza con il mouse.
struct StageView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let snap = model.snapshot
        let status = snap?.status
        let songIndex = status?.songIndex
        let song: SongRecord? = songIndex.flatMap { model.library.songs.indices.contains($0) ? model.library.songs[$0] : nil }

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Brano
                HStack(alignment: .center, spacing: 16) {
                    Button { model.perform(.previousSong) } label: {
                        Image(systemName: "chevron.left").font(.title)
                    }
                    .buttonStyle(.borderless)
                    .help("Brano precedente")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(songIndex.map { "Brano \($0 + 1) di \(model.library.songs.count)" } ?? "Nessun brano")
                            .foregroundColor(.secondary)
                        Text(status?.songName ?? "Aggiungi un brano nella sezione Brani")
                            .font(.system(size: 34, weight: .bold))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button { model.perform(.nextSong) } label: {
                        Image(systemName: "chevron.right").font(.title)
                    }
                    .buttonStyle(.borderless)
                    .help("Brano successivo")
                }

                // Tempo, battuta, trasporto
                HStack(spacing: 14) {
                    StatBox(title: "Trasporto", value: (status?.transportRunning ?? false) ? "▶︎ In corso" : "■ Fermo")
                    StatBox(title: "Battuta", value: snap?.bar.map { "\($0)" } ?? "–")
                    StatBox(title: "Tempo", value: snap?.tempoBPM.map { String(format: "%.1f BPM", $0) } ?? "–")
                    StatBox(title: "Clock", value: (snap?.clockReceiving ?? false) ? "Ricevuto" : "Assente")
                }

                // Groove in corso
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(status?.playingSlotName ?? "Silenzio")
                            .font(.system(size: 28, weight: .semibold))
                        if status?.stopPending == true {
                            Text("In coda: silenzio dalla prossima battuta").foregroundColor(.orange)
                        } else if let next = status?.pendingSlotName {
                            Text("In coda: \(next)").foregroundColor(.orange)
                        } else if let armed = status?.armedSlot, let song, song.slots.indices.contains(armed) {
                            Text("Pronto allo Start: \(model.displayName(of: song.slots[armed]))").foregroundColor(.blue)
                        } else {
                            Text(" ").foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                } label: {
                    Text("Groove")
                }

                // Groove del brano
                if let song {
                    Text("Groove del brano").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        ForEach(Array(song.slots.enumerated()), id: \.element.id) { index, slot in
                            SlotButton(index: index, name: model.displayName(of: slot), mode: slot.mode,
                                       playing: status?.playingSlot == index,
                                       pending: status?.pendingSlot == index) {
                                model.perform(.triggerSlot(index))
                            }
                        }
                    }
                }

                // Comandi
                HStack(spacing: 10) {
                    Button("Fill") { model.perform(.fill) }
                    Button("Groove successivo") { model.perform(.nextSlot) }
                    Button("Silenzio a fine battuta") { model.perform(.stopAtBarEnd) }
                    Spacer()
                    Button(role: .destructive) { model.panic() } label: {
                        Label("Panic", systemImage: "exclamationmark.octagon")
                    }
                }
                .controlSize(.large)

                if let last = snap?.lastCommand {
                    Text("Ultimo comando ricevuto: \(last)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2.monospacedDigit())
        }
        .padding(10)
        .frame(minWidth: 130, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
    }
}

struct SlotButton: View {
    let index: Int
    let name: String
    let mode: SlotMode
    let playing: Bool
    let pending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(index + 1)").font(.headline.monospacedDigit())
                    Spacer()
                    if let note = defaultNoteLabel(forSlot: index) {
                        Text(note).font(.caption).foregroundColor(.secondary)
                    }
                }
                Text(name).font(.body.weight(.semibold)).lineLimit(1)
                Text(mode.label).font(.caption).foregroundColor(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(playing ? Color.green.opacity(0.35) : (pending ? Color.orange.opacity(0.3) : Color.secondary.opacity(0.12)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
