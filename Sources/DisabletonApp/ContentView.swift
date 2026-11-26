#if canImport(SwiftUI) && os(macOS)
import AppKit
import GrooveCore
import MIDIHost
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if model.mode != .stage {
                ModeBar()
                StatusBar()
            }
            Group {
                switch model.mode {
                case .prep: PrepView()
                case .commands: CommandsView()
                case .stage: StageView()
                }
            }
            .sheet(isPresented: $model.showReport) {
                ReportView()
                    .environmentObject(model)
                    .frame(width: 760, height: 680)
            }
        }
        .onReceive(timer) { _ in model.poll() }
        .onAppear {
            // Dimensione minima della finestra (su macOS 12 il frame minimo non basta).
            DispatchQueue.main.async {
                for window in NSApp.windows where window.isVisible {
                    window.minSize = NSSize(width: 980, height: 640)
                }
            }
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .environmentObject(model)
                .frame(width: 760, height: 700)
        }
        .sheet(item: detailGroove) { item in
            GrooveDetailView(grooveID: item.id, onDelete: {})
                .environmentObject(model)
                .frame(width: 620, height: 640)
        }
        .alert("Disableton", isPresented: errorShown, actions: {
            Button("OK") { model.errorMessage = nil }
        }, message: {
            Text(model.errorMessage ?? "")
        })
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil },
                set: { shown in if !shown { model.errorMessage = nil } })
    }

    private var detailGroove: Binding<GrooveSheetItem?> {
        Binding(get: { model.detailGrooveID.map { GrooveSheetItem(id: $0) } },
                set: { model.detailGrooveID = $0?.id })
    }
}

struct GrooveSheetItem: Identifiable {
    let id: UUID
}

/// Selettore delle tre viste e accesso alle impostazioni.
struct ModeBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text("Disableton").font(.headline)
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
                .help("Annulla l'ultima modifica (⌘Z)")
                .accessibilityLabel("Annulla")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
                .help("Ripeti (⇧⌘Z)")
                .accessibilityLabel("Ripeti")
            Spacer()
            Picker("Vista", selection: $model.mode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)
            Spacer()
            UpdateBadge()
            Button {
                model.refreshPorts()
                model.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Impostazioni (⌘,)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.showElementHelp) {
            ElementHelpView()
                .frame(width: 700, height: 640)
        }
        .sheet(isPresented: $model.showGrooveHelp) {
            GrooveHelpView()
                .frame(width: 700, height: 640)
        }
        .sheet(isPresented: $model.showDAWHelp) {
            DAWHelpView()
                .environmentObject(model)
                .frame(width: 700, height: 640)
        }
        .alert("Installare l'aggiornamento?", isPresented: $model.confirmInstallUpdate) {
            Button("Più tardi", role: .cancel) {}
            Button("Installa e riavvia") { model.installUpdate() }
        } message: {
            Text("Disableton si chiuderà e si riaprirà aggiornato. Libreria e impostazioni restano invariate.")
        }
    }
}

/// Barra di stato scura, sempre visibile in Preparazione e Comandi.
struct StatusBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if model.learningTarget != nil || model.notice != nil {
                infoRow
            }
        }
        .foregroundColor(.white)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
    }

    private var mainRow: some View {
        let snap = model.snapshot
        let status = snap?.status
        return HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(clockColor(snap)).frame(width: 10, height: 10)
                Text(clockText(snap)).font(.callout.weight(.semibold)).lineLimit(1).fixedSize()
            }
            Text(snap?.tempoBPM.map { String(format: "%.1f BPM", $0) } ?? "– BPM")
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
            Text(barText(snap))
                .font(.title3.weight(.bold).monospacedDigit())
                .fixedSize()
            BeatDots(beat: snap?.beat, count: snap?.beatsPerBar ?? 4, size: 12, lit: Color.green, unlit: Color.gray.opacity(0.6))
            VStack(alignment: .leading, spacing: 1) {
                if let name = status?.songName {
                    Text("Brano \((status?.songIndex ?? 0) + 1): \(name)").font(.caption).foregroundColor(.gray).lineLimit(1)
                }
                playingText(status)
            }
            pendingView(status)
            Spacer(minLength: 8)
            if snap?.realtimePriority == false {
                Text("Priorità tempo reale non ottenuta").font(.caption).foregroundColor(.orange).lineLimit(1)
            }
            transportButton
            Button { model.panic() } label: {
                Text("PANIC")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.75, green: 0.11, blue: 0.11)))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Emergenza: silenzio immediato (⇧⌘.)")
            .accessibilityLabel("Panic: silenzio immediato")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func playingText(_ status: PlaybackStatus?) -> some View {
        if let playing = status?.playingSlotName {
            (Text("Suona ") + Text(playing).bold()).lineLimit(1)
        } else if let armed = status?.armedSlot {
            Text("Pronto allo Start: groove \(armed + 1)").foregroundColor(Color(red: 0.55, green: 0.75, blue: 1)).lineLimit(1)
        } else {
            Text("Silenzio").foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func pendingView(_ status: PlaybackStatus?) -> some View {
        if status?.stopPending == true || status?.pendingSlotName != nil {
            HStack(spacing: 6) {
                Text(status?.stopPending == true ? "→ silenzio a fine battuta" : "→ \(status?.pendingSlotName ?? "")")
                    .foregroundColor(.orange)
                    .lineLimit(1)
                Button("Annulla") { model.cancelPending() }
                    .help("Annulla il cambio in coda")
            }
            .fixedSize()
        }
    }

    /// STOP quando qualcosa suona; "Prova senza workstation" quando tutto è fermo.
    @ViewBuilder
    private var transportButton: some View {
        if let label = model.stopLabel {
            Button { model.stopPlayback() } label: {
                Label(label, systemImage: "stop.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Ferma (⌘.)")
        } else if model.snapshot?.status.transportRunning != true {
            Button { model.startInternalClock() } label: {
                Label("Prova senza workstation", systemImage: "play.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(model.selectedSongIndex == nil)
            .help("Suona il brano selezionato con il clock interno, a \(Int(model.library.performance.internalBPM)) BPM")
        }
    }

    private var infoRow: some View {
        HStack(spacing: 10) {
            if model.learningTarget != nil {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("MIDI Learn: premi un tasto o un controllo sulla workstation…")
                Button("Annulla") { model.cancelLearn() }
            } else if let notice = model.notice {
                Image(systemName: "info.circle")
                Text(notice).lineLimit(1)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(model.learningTarget != nil ? Color.orange.opacity(0.35) : Color.blue.opacity(0.3))
    }

    private func clockColor(_ snap: LiveSnapshot?) -> Color {
        guard model.engineRunning, let snap else { return .red }
        if snap.internalClock || snap.previewing { return .blue }
        return snap.clockReceiving ? .green : .orange
    }

    private func clockText(_ snap: LiveSnapshot?) -> String {
        guard model.engineRunning else { return "Motore MIDI fermo" }
        guard let snap else { return "Avvio…" }
        if snap.previewing { return "Ascolto" }
        if snap.internalClock { return "Clock interno" }
        return snap.clockReceiving ? "Clock workstation" : "In attesa del clock"
    }

    private func barText(_ snap: LiveSnapshot?) -> String {
        guard let bar = snap?.bar else { return "–" }
        return snap?.beat.map { "\(bar) · \($0)" } ?? "\(bar)"
    }
}

/// Indicatore dei battiti della battuta.
struct BeatDots: View {
    let beat: Int?
    let count: Int
    let size: CGFloat
    let lit: Color
    let unlit: Color

    var body: some View {
        HStack(spacing: size / 2) {
            ForEach(0..<max(1, min(count, 12)), id: \.self) { i in
                Circle()
                    .fill(beat == i + 1 ? lit : unlit)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(beat.map { "Battito \($0) di \(count)" } ?? "Fermo")
    }
}
#endif
