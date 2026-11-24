#if canImport(SwiftUI) && os(macOS)
import GrooveCore
import SwiftUI

/// Associazione dei comandi del Krome alle azioni, con MIDI Learn.
struct ControlsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comandi MIDI").font(.title2.bold())
                Spacer()
                Menu {
                    ForEach(ControlAction.menuChoices, id: \.self) { action in
                        Button(action.label) { model.learnNew(action: action) }
                    }
                } label: {
                    Label("Aggiungi comando", systemImage: "plus")
                }
                .frame(width: 200)
                Button("Ripristina predefiniti") { model.resetBindings() }
            }

            Text("Per associare un tasto, un pulsante o il pedale del Krome: premi \"Impara\", poi il controllo sul Krome. Note e controller attivano il comando quando vengono premuti.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case let .new(action)? = model.learningTarget {
                LearningBanner(text: "Premi sul Krome il controllo per \"\(action.label)\"…") { model.cancelLearn() }
            }

            List {
                ForEach(Array(model.library.controlMap.bindings.enumerated()), id: \.offset) { index, binding in
                    HStack(spacing: 12) {
                        Text(binding.action.label)
                            .frame(width: 230, alignment: .leading)
                        Text(binding.triggerLabel)
                            .foregroundColor(.secondary)
                        Spacer()
                        if model.learningTarget == .existing(index) {
                            Text("Premi un controllo sul Krome…").foregroundColor(.orange)
                            Button("Annulla") { model.cancelLearn() }
                        } else {
                            Button("Impara") { model.learn(bindingAt: index) }
                                .disabled(model.learningTarget != nil)
                        }
                        Button(role: .destructive) { model.removeBinding(at: index) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(20)
    }
}

struct LearningBanner: View {
    let text: String
    let cancel: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right")
            Text(text)
            Spacer()
            Button("Annulla", action: cancel)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.2)))
    }
}
#endif
