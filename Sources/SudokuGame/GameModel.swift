import Foundation
import Observation
import SudokuCore

/// A revealed hint: highlighted cells plus the explanation. Applying it
/// either fills the cell or strikes the eliminated candidates.
public struct Hint: Equatable, Sendable {
    public let technique: Technique
    public let explanation: String
    public let placement: (cell: Int, digit: UInt8)?
    public let eliminations: [(cell: Int, digit: UInt8)]
    /// A "fix your mistake" notice rather than a logical step; nothing to apply.
    public let isCorrection: Bool

    public init(technique: Technique, explanation: String,
                placement: (cell: Int, digit: UInt8)?,
                eliminations: [(cell: Int, digit: UInt8)], isCorrection: Bool = false) {
        self.technique = technique
        self.explanation = explanation
        self.placement = placement
        self.eliminations = eliminations
        self.isCorrection = isCorrection
    }

    public var cells: [Int] {
        if let p = placement { return [p.cell] }
        return Array(Set(eliminations.map(\.cell))).sorted()
    }

    public static func == (lhs: Hint, rhs: Hint) -> Bool {
        lhs.technique == rhs.technique && lhs.explanation == rhs.explanation
    }
}

/// Game rules and state for one puzzle in progress. UI-free so it can be
/// unit tested; SwiftUI views observe it directly.
@Observable
public final class GameModel {
    public private(set) var state: GameState
    public var selected: Int?
    public var notesMode = false
    public var isPaused = false
    public private(set) var hint: Hint?
    /// Flag wrong entries immediately and count them (SPEC.md §4).
    public var instantMistakeChecking = true
    /// Called after every change worth persisting.
    @ObservationIgnored public var onChange: (() -> Void)?

    public init(puzzle: Puzzle) { state = GameState(puzzle: puzzle) }
    public init(state: GameState) { self.state = state }

    // MARK: - Read

    public var level: Level { state.puzzle.level }
    public var values: [UInt8] { state.values }
    public var elapsed: TimeInterval { state.elapsed }
    public var mistakes: Int { state.mistakes }
    public var hintsUsed: Int { state.hintsUsed }
    public var canUndo: Bool { !state.undoStack.isEmpty }
    public var canRedo: Bool { !state.redoStack.isEmpty }

    public var isComplete: Bool { state.values == state.puzzle.solution }

    public func isGiven(_ cell: Int) -> Bool { state.puzzle.givens[cell] != 0 }

    public func notes(_ cell: Int) -> UInt16 { state.notes[cell] }

    /// Wrong entries, only reported when instant checking is on.
    public func isWrong(_ cell: Int) -> Bool {
        instantMistakeChecking && !isGiven(cell) && state.values[cell] != 0
            && state.values[cell] != state.puzzle.solution[cell]
    }

    /// Cells whose digit duplicates another in the same row, column or box.
    public var conflicts: Set<Int> {
        var result = Set<Int>()
        for cell in 0..<81 where state.values[cell] != 0 {
            if Geometry.peers[cell].contains(where: { state.values[$0] == state.values[cell] }) {
                result.insert(cell)
            }
        }
        return result
    }

    /// How many of each digit (1...9) are on the board.
    public func placedCount(of digit: UInt8) -> Int {
        state.values.lazy.filter { $0 == digit }.count
    }

    public var hintsRemaining: Int? {
        level.hintLimit.map { max(0, $0 - state.hintsUsed) }
    }

    // MARK: - Input

    /// Digit pad tap: toggles a note in notes mode, otherwise fills the cell.
    public func enter(_ digit: UInt8) {
        guard let cell = selected, !isGiven(cell), !isPaused, (1...9).contains(digit) else { return }
        hint = nil
        if notesMode {
            guard state.values[cell] == 0 else { return }
            let newNotes = state.notes[cell] ^ (UInt16(1) << UInt16(digit))
            apply(Move(changes: [CellChange(cell: cell, oldValue: 0, newValue: 0,
                                            oldNotes: state.notes[cell], newNotes: newNotes)]))
        } else {
            fill(cell, with: digit)
        }
    }

    public func erase() {
        guard let cell = selected, !isGiven(cell), !isPaused else { return }
        guard state.values[cell] != 0 || state.notes[cell] != 0 else { return }
        hint = nil
        apply(Move(changes: [CellChange(cell: cell, oldValue: state.values[cell], newValue: 0,
                                        oldNotes: state.notes[cell], newNotes: 0)]))
    }

    private func fill(_ cell: Int, with digit: UInt8) {
        guard state.values[cell] != digit else { return }
        var changes = [CellChange(cell: cell, oldValue: state.values[cell], newValue: digit,
                                  oldNotes: state.notes[cell], newNotes: 0)]
        // Placing a digit strikes it from the notes of every peer.
        let bit = UInt16(1) << UInt16(digit)
        for peer in Geometry.peers[cell] where state.notes[peer] & bit != 0 {
            changes.append(CellChange(cell: peer, oldValue: state.values[peer], newValue: state.values[peer],
                                      oldNotes: state.notes[peer], newNotes: state.notes[peer] & ~bit))
        }
        if instantMistakeChecking && digit != state.puzzle.solution[cell] { state.mistakes += 1 }
        apply(Move(changes: changes))
    }

    private func apply(_ move: Move) {
        for c in move.changes {
            state.values[c.cell] = c.newValue
            state.notes[c.cell] = c.newNotes
        }
        state.undoStack.append(move)
        state.redoStack.removeAll()
        onChange?()
    }

    // MARK: - Undo / redo

    public func undo() {
        guard let move = state.undoStack.popLast(), !isPaused else { return }
        for c in move.changes {
            state.values[c.cell] = c.oldValue
            state.notes[c.cell] = c.oldNotes
        }
        state.redoStack.append(move)
        hint = nil
        if let first = move.changes.first { selected = first.cell }
        onChange?()
    }

    public func redo() {
        guard let move = state.redoStack.popLast(), !isPaused else { return }
        for c in move.changes {
            state.values[c.cell] = c.newValue
            state.notes[c.cell] = c.newNotes
        }
        state.undoStack.append(move)
        hint = nil
        if let first = move.changes.first { selected = first.cell }
        onChange?()
    }

    // MARK: - Hints (two taps: reveal, then apply)

    /// First tap reveals and explains the next logical step; second tap applies it.
    public func hintTapped() {
        if let current = hint { applyHint(current); return }
        guard !isPaused, !isComplete, hintsRemaining != 0 else { return }
        // A wrong entry would poison the deduction, so point at it first.
        if let bad = (0..<81).first(where: { !isGiven($0) && state.values[$0] != 0
                                                && state.values[$0] != state.puzzle.solution[$0] }) {
            hint = Hint(technique: .nakedSingle,
                        explanation: "This entry doesn't fit the solution. Erase it to continue.",
                        placement: nil, eliminations: [(bad, state.values[bad])], isCorrection: true)
            selected = bad
            return
        }
        guard let step = LogicSolver.nextStep(state.values, eliminated: state.hintEliminations) else { return }
        state.hintsUsed += 1
        hint = Hint(technique: step.technique, explanation: step.explanation,
                    placement: step.placement, eliminations: step.eliminations)
        selected = hint?.cells.first
        onChange?()
    }

    private func applyHint(_ hint: Hint) {
        self.hint = nil
        if hint.isCorrection { return }
        if let p = hint.placement {
            selected = p.cell
            fill(p.cell, with: p.digit)
        } else {
            var changes: [CellChange] = []
            for e in hint.eliminations {
                state.hintEliminations[e.cell] |= UInt16(1) << UInt16(e.digit)
                let bit = UInt16(1) << UInt16(e.digit)
                if state.notes[e.cell] & bit != 0 {
                    changes.append(CellChange(cell: e.cell, oldValue: state.values[e.cell],
                                              newValue: state.values[e.cell],
                                              oldNotes: state.notes[e.cell],
                                              newNotes: state.notes[e.cell] & ~bit))
                }
            }
            if changes.isEmpty { onChange?() } else { apply(Move(changes: changes)) }
        }
    }

    // MARK: - Clock

    public func addTime(_ seconds: TimeInterval) {
        guard !isPaused, !isComplete else { return }
        state.elapsed += seconds
    }

    public func pause() { isPaused = true; onChange?() }
    public func resume() { isPaused = false }
}
