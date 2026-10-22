import Foundation
import Observation
import SudokuCore
import SudokuGame

/// App-level state: which screen is up, the game in progress, stats, and
/// persistence. The in-progress game autosaves after every move.
@MainActor @Observable
final class AppModel {
    enum Screen { case home, game }

    var screen: Screen = .home
    private(set) var game: GameModel?
    private(set) var stats: Stats
    /// The level being generated, while a new puzzle is on its way.
    private(set) var generating: Level?
    /// The saved game offered by "Continue".
    private(set) var savedGame: GameState?

    private let store: Store
    private var winRecorded = false

    init(store: Store = .applicationSupport()) {
        self.store = store
        stats = store.load(Stats.self, from: Store.statsFile) ?? Stats()
        savedGame = store.load(GameState.self, from: Store.gameFile)
    }

    // MARK: - Starting and resuming

    func startNew(_ level: Level) {
        guard generating == nil else { return }
        generating = level
        Task {
            let puzzle = await Self.generate(level)
            generating = nil
            if let old = savedGame ?? game?.state, !(game?.isComplete ?? false) {
                stats.recordAbandon(old.puzzle.level)
            }
            stats.recordStart(level)
            store.save(stats, to: Store.statsFile)
            begin(GameModel(puzzle: puzzle))
        }
    }

    func continueGame() {
        guard let state = savedGame else { return }
        begin(GameModel(state: state))
    }

    private func begin(_ model: GameModel) {
        winRecorded = false
        model.onChange = { [weak self, weak model] in
            guard let self, let model else { return }
            Task { @MainActor in self.gameChanged(model) }
        }
        game = model
        savedGame = model.state
        store.save(model.state, to: Store.gameFile)
        screen = .game
    }

    func quitToHome() {
        game?.pause()
        if let game, !game.isComplete { savedGame = game.state }
        self.game = nil
        screen = .home
    }

    /// Discards the current game without finishing it.
    func abandonGame() {
        if let game, !game.isComplete { stats.recordAbandon(game.level) }
        store.save(stats, to: Store.statsFile)
        store.remove(Store.gameFile)
        savedGame = nil
        game = nil
        screen = .home
    }

    func resetStats() {
        stats.reset()
        store.save(stats, to: Store.statsFile)
    }

    // MARK: - Saving

    func appBackgrounded() {
        guard let game, !game.isComplete else { return }
        game.pause()
        store.save(game.state, to: Store.gameFile)
    }

    private func gameChanged(_ model: GameModel) {
        if model.isComplete {
            guard !winRecorded else { return }
            winRecorded = true
            stats.recordWin(model.level, time: model.elapsed, hintsUsed: model.hintsUsed)
            store.save(stats, to: Store.statsFile)
            store.remove(Store.gameFile)
            savedGame = nil
        } else {
            savedGame = model.state
            store.save(model.state, to: Store.gameFile)
        }
    }

    // MARK: - Generation

    /// Puzzle generation is CPU-bound (Experienced can take a few hundred
    /// milliseconds), so it runs off the main actor.
    private nonisolated static func generate(_ level: Level) async -> Puzzle {
        await Task.detached(priority: .userInitiated) {
            while true {
                if let puzzle = Generator.makePuzzle(level: level, seed: .random(in: 1...UInt64.max)) {
                    return puzzle
                }
            }
        }.value
    }
}
