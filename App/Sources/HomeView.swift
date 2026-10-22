import SwiftUI
import SudokuCore
import SudokuGame

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showStats = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Sudoku")
                .font(.system(size: 52, weight: .bold, design: .rounded))

            if let saved = app.savedGame {
                Button { app.continueGame() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue").font(.headline)
                            Text("\(saved.puzzle.level.title) · \(formatTime(saved.elapsed))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(saved.puzzle.level.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ForEach(Level.allCases, id: \.self) { level in
                    Button { app.startNew(level) } label: {
                        HStack {
                            Circle().fill(level.color).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title).font(.headline)
                                Text(level.blurb).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New \(level.title) game. \(level.blurb)")
                }
            }

            Spacer()
            Button("Stats", systemImage: "chart.bar") { showStats = true }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: 480)
        .sheet(isPresented: $showStats) { StatsView() }
    }
}
