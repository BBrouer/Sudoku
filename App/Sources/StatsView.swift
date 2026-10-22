import SwiftUI
import SudokuCore
import SudokuGame

struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Level.allCases, id: \.self) { level in
                    let s = app.stats[level]
                    Section {
                        row("Games started", "\(s.started)")
                        row("Games won", "\(s.won)")
                        row("Win rate", s.started == 0 ? "—" : "\(Int((s.winRate * 100).rounded()))%")
                        row("Best time", s.bestTime.map(formatTime) ?? "—")
                        row("Average time", s.averageTime.map(formatTime) ?? "—")
                        row("Current streak", "\(s.streak)")
                        row("Best streak", "\(s.bestStreak)")
                    } header: {
                        Label(level.title, systemImage: "circle.fill").foregroundStyle(level.color)
                    }
                }
                Section {
                    Button("Reset stats", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Best times only count games finished without hints.")
                }
            }
            .navigationTitle("Stats")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset all stats?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { app.resetStats() }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
    }
}
