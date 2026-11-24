#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import MIDIHost
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case stage, songs, grooves, controls, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stage: return "Palco"
        case .songs: return "Brani"
        case .grooves: return "Groove"
        case .controls: return "Comandi MIDI"
        case .settings: return "Impostazioni"
        }
    }

    var icon: String {
        switch self {
        case .stage: return "play.circle"
        case .songs: return "music.note.list"
        case .grooves: return "square.stack.3d.up"
        case .controls: return "pianokeys"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var section: AppSection? = .stage
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $section) {
                    ForEach(AppSection.allCases) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
                Divider()
                ConnectionBadge()
                    .padding(10)
            }
            .frame(width: 210)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(timer) { _ in model.poll() }
        .alert("Disableton", isPresented: errorShown, actions: {
            Button("OK") { model.errorMessage = nil }
        }, message: {
            Text(model.errorMessage ?? "")
        })
    }

    @ViewBuilder
    private var detail: some View {
        switch section ?? .stage {
        case .stage: StageView()
        case .songs: SongsView()
        case .grooves: GroovesView()
        case .controls: ControlsView()
        case .settings: SettingsView()
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil },
                set: { shown in if !shown { model.errorMessage = nil } })
    }
}

/// Indicatore di collegamento in fondo alla barra laterale.
struct ConnectionBadge: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let snap = model.snapshot
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color(snap))
                    .frame(width: 10, height: 10)
                Text(text(snap))
                    .font(.callout)
            }
            Text(model.connectedInputs.isEmpty ? "Nessun ingresso MIDI" : "Ingresso: " + model.connectedInputs.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text("Uscita: \(LiveHost.virtualPortName), canale \(model.library.outputChannel)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(_ snap: LiveSnapshot?) -> Color {
        guard model.engineRunning else { return .red }
        guard let snap else { return .gray }
        if snap.previewing { return .blue }
        return snap.clockReceiving ? .green : .orange
    }

    private func text(_ snap: LiveSnapshot?) -> String {
        guard model.engineRunning else { return "Motore MIDI fermo" }
        guard let snap else { return "Avvio…" }
        if snap.previewing { return "Ascolto in corso" }
        return snap.clockReceiving ? "Clock dal Krome" : "In attesa del clock"
    }
}
#endif
