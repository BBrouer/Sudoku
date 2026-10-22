import Combine
import SwiftUI
import SudokuCore
import SudokuGame

struct GameView: View {
    @Environment(AppModel.self) private var app
    let game: GameModel
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                topBar
                ZStack {
                    BoardView(game: game).opacity(game.isPaused ? 0 : 1)
                    if game.isPaused { PauseCard(game: game) }
                }
                .padding(.horizontal, 8)
                statusLine
                hintBanner
                toolRow
                NumberPad(game: game)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: 560)

            if game.isComplete { WinView(game: game) }
        }
        .onReceive(tick) { _ in game.addTime(1) }
        .sensoryFeedback(.error, trigger: game.mistakes)
        .sensoryFeedback(.success, trigger: game.isComplete)
        .sensoryFeedback(.impact(weight: .light), trigger: game.values)
        .accessibilityAction(.escape) { app.quitToHome() }
    }

    private var topBar: some View {
        HStack {
            Button { app.quitToHome() } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Back to home")
            Spacer()
            Text(game.level.title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(game.level.color.opacity(0.2), in: Capsule())
            Spacer()
            Text(formatTime(game.elapsed))
                .font(.body.monospacedDigit())
                .accessibilityLabel("Elapsed time \(formatTime(game.elapsed))")
            Button {
                game.isPaused ? game.resume() : game.pause()
            } label: { Image(systemName: game.isPaused ? "play.fill" : "pause.fill") }
                .accessibilityLabel(game.isPaused ? "Resume" : "Pause")
                .padding(.leading, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var statusLine: some View {
        HStack {
            Text("Mistakes: \(game.mistakes)")
            Spacer()
            if let left = game.hintsRemaining {
                Text("Hints left: \(left)")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
    }

    @ViewBuilder private var hintBanner: some View {
        if let hint = game.hint {
            VStack(alignment: .leading, spacing: 4) {
                Text(hint.explanation).font(.callout)
                Text(hint.isCorrection ? "Tap the Erase button to fix it."
                     : "Tap Hint again to apply it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 8)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 0) {
            tool("arrow.uturn.backward", "Undo", disabled: !game.canUndo) { game.undo() }
            tool("arrow.uturn.forward", "Redo", disabled: !game.canRedo) { game.redo() }
            tool("eraser", "Erase", disabled: game.selected == nil) { game.erase() }
            tool(game.notesMode ? "pencil.circle.fill" : "pencil", "Notes", on: game.notesMode) {
                game.notesMode.toggle()
            }
            tool("lightbulb", "Hint", disabled: game.hintsRemaining == 0 && game.hint == nil) {
                game.hintTapped()
            }
        }
    }

    private func tool(_ symbol: String, _ title: String, on: Bool = false, disabled: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(on ? Color.accentColor : .primary)
        }
        .disabled(disabled || game.isPaused)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct NumberPad: View {
    let game: GameModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...9, id: \.self) { d in
                let done = game.placedCount(of: UInt8(d)) >= 9
                Button { game.enter(UInt8(d)) } label: {
                    Text(String(d))
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(done ? Color.secondary.opacity(0.4) : .primary)
                .disabled(done || game.isPaused)
                .accessibilityLabel("\(d)\(done ? ", all placed" : "")")
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct PauseCard: View {
    @Environment(AppModel.self) private var app
    let game: GameModel

    var body: some View {
        VStack(spacing: 14) {
            Text("Paused").font(.title2.bold())
            Text("Puzzle \(game.state.puzzle.id)").font(.caption).foregroundStyle(.secondary)
            Button("Resume") { game.resume() }.buttonStyle(.borderedProminent)
            Button("New Game") { app.startNew(game.level) }.buttonStyle(.bordered)
            Button("Quit Game", role: .destructive) { app.abandonGame() }.buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WinView: View {
    @Environment(AppModel.self) private var app
    let game: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Solved! 🎉").font(.largeTitle.bold())
                Text(game.level.title).foregroundStyle(game.level.color).font(.headline)
                VStack(alignment: .leading, spacing: 6) {
                    line("Time", formatTime(game.elapsed))
                    line("Mistakes", "\(game.mistakes)")
                    line("Hints used", "\(game.hintsUsed)")
                    line("Best time", app.stats[game.level].bestTime.map(formatTime) ?? "—")
                }
                Button("New \(game.level.title) Game") { app.startNew(game.level) }
                    .buttonStyle(.borderedProminent)
                Button("Home") { app.quitToHome() }.buttonStyle(.bordered)
            }
            .padding(28)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
        .transition(.opacity)
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(minLength: 40); Text(v).monospacedDigit().foregroundStyle(.secondary) }
    }
}
