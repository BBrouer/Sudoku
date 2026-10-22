import Foundation
import SudokuCore

/// One cell's before/after, so a move can be undone and redone exactly.
public struct CellChange: Codable, Equatable, Sendable {
    public let cell: Int
    public let oldValue: UInt8
    public let newValue: UInt8
    public let oldNotes: UInt16
    public let newNotes: UInt16
}

/// A single player action. Entering a digit can also clear that digit from
/// its peers' notes, so one move may touch several cells.
public struct Move: Codable, Equatable, Sendable {
    public let changes: [CellChange]
}

/// Everything needed to restore a game exactly (SPEC.md §8).
public struct GameState: Codable, Equatable, Sendable {
    public var puzzle: Puzzle
    /// Full board: givens plus the player's entries. 0 = empty.
    public var values: [UInt8]
    /// Pencil notes per cell, bit `d` set = candidate digit `d`.
    public var notes: [UInt16]
    public var undoStack: [Move] = []
    public var redoStack: [Move] = []
    public var elapsed: TimeInterval = 0
    public var mistakes: Int = 0
    public var hintsUsed: Int = 0
    /// Candidates ruled out by hints the player has applied; fed back into
    /// the logic solver so the next hint moves on.
    public var hintEliminations: [UInt16] = [UInt16](repeating: 0, count: 81)

    public init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.values = puzzle.givens
        self.notes = [UInt16](repeating: 0, count: 81)
    }
}

extension Level {
    /// Hints per game (SPEC.md §6); nil = unlimited.
    public var hintLimit: Int? {
        switch self {
        case .novice, .normal: return nil
        case .experienced, .hard: return 3
        }
    }

    public var title: String { rawValue.capitalized }
}
