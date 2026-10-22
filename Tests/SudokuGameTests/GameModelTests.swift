import XCTest
import SudokuCore
@testable import SudokuGame

private func parse(_ s: String) -> [UInt8] { s.map { UInt8(String($0))! } }

final class GameModelTests: XCTestCase {
    let givens = parse("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
    let solution = parse("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    func makeModel() -> GameModel {
        GameModel(puzzle: Puzzle(id: "t", level: .novice, givens: givens, solution: solution))
    }

    func testGivensAreLocked() {
        let m = makeModel()
        m.selected = 0   // given 5
        m.enter(9)
        m.erase()
        XCTAssertEqual(m.values[0], 5)
        XCTAssertFalse(m.canUndo)
    }

    func testEnterUndoRedo() {
        let m = makeModel()
        m.selected = 2
        m.enter(4)
        XCTAssertEqual(m.values[2], 4)
        m.undo()
        XCTAssertEqual(m.values[2], 0)
        XCTAssertTrue(m.canRedo)
        m.redo()
        XCTAssertEqual(m.values[2], 4)
        m.undo()
        m.selected = 2
        m.enter(1)
        XCTAssertFalse(m.canRedo, "a new move clears redo")
    }

    func testWrongEntryCountsMistakeAndIsFlagged() {
        let m = makeModel()
        m.selected = 2
        m.enter(1)
        XCTAssertEqual(m.mistakes, 1)
        XCTAssertTrue(m.isWrong(2))
        m.undo()
        XCTAssertEqual(m.mistakes, 1, "undo doesn't forgive a mistake")
    }

    func testMistakeCheckingOffHidesWrongEntries() {
        let m = makeModel()
        m.instantMistakeChecking = false
        m.selected = 2
        m.enter(1)
        XCTAssertEqual(m.mistakes, 0)
        XCTAssertFalse(m.isWrong(2))
    }

    func testConflictsDetectDuplicates() {
        let m = makeModel()
        m.instantMistakeChecking = false
        m.selected = 2
        m.enter(5)          // row 0 already has a 5 at index 0
        XCTAssertTrue(m.conflicts.contains(2))
        XCTAssertTrue(m.conflicts.contains(0))
    }

    func testNotesToggleAndPeerCleanup() {
        let m = makeModel()
        m.notesMode = true
        m.selected = 3          // row 0, col 3
        m.enter(6); m.enter(8)
        XCTAssertEqual(m.notes(3), (1 << 6) | (1 << 8))
        m.enter(6)
        XCTAssertEqual(m.notes(3), 1 << 8)

        m.selected = 5          // note a 4 in a row-0 peer, then place 4 at index 2
        m.enter(4)
        m.notesMode = false
        m.selected = 2
        m.enter(4)
        XCTAssertEqual(m.notes(5) & (1 << 4), 0, "placing a digit strikes it from peer notes")
        m.undo()
        XCTAssertNotEqual(m.notes(5) & (1 << 4), 0, "undo restores the peer note")
    }

    func testCompletion() {
        let m = makeModel()
        XCTAssertFalse(m.isComplete)
        for cell in 0..<81 where givens[cell] == 0 {
            m.selected = cell
            m.enter(solution[cell])
        }
        XCTAssertTrue(m.isComplete)
        XCTAssertEqual(m.mistakes, 0)
    }

    func testHintRevealsThenFills() throws {
        let m = makeModel()
        m.hintTapped()
        let hint = try XCTUnwrap(m.hint)
        let cell = try XCTUnwrap(hint.placement?.cell)
        XCTAssertEqual(m.hintsUsed, 1)
        m.hintTapped()
        XCTAssertNil(m.hint)
        XCTAssertEqual(m.values[cell], solution[cell])
    }

    func testHintsRunOutOnHardLevels() {
        let m = GameModel(puzzle: Puzzle(id: "t", level: .hard, givens: givens, solution: solution))
        for _ in 0..<3 { m.hintTapped(); m.hintTapped() }
        XCTAssertEqual(m.hintsRemaining, 0)
        let used = m.hintsUsed
        m.hintTapped()
        XCTAssertEqual(m.hintsUsed, used)
    }

    func testHintFlagsWrongEntryFirst() throws {
        let m = makeModel()
        m.selected = 2
        m.enter(1)
        m.hintTapped()
        XCTAssertTrue(try XCTUnwrap(m.hint).isCorrection)
        XCTAssertEqual(m.hintsUsed, 0)
    }

    func testEliminationHintsMakeProgress() {
        // Hard generated puzzle: walking hints to the end must always terminate.
        let puzzle = Generator.makePuzzle(level: .normal, seed: 3)!
        let m = GameModel(puzzle: puzzle)
        m.instantMistakeChecking = true
        var taps = 0
        while !m.isComplete && taps < 400 {
            m.hintTapped(); m.hintTapped()
            taps += 1
        }
        XCTAssertTrue(m.isComplete, "hints stalled after \(taps) rounds")
    }

    func testStateRoundTripsThroughJSON() throws {
        let m = makeModel()
        m.selected = 2
        m.enter(4)
        m.addTime(12)
        let data = try JSONEncoder().encode(m.state)
        let restored = GameModel(state: try JSONDecoder().decode(GameState.self, from: data))
        XCTAssertEqual(restored.state, m.state)
        XCTAssertEqual(restored.elapsed, 12)
    }

    func testPausedClockAndInputAreFrozen() {
        let m = makeModel()
        m.pause()
        m.addTime(5)
        m.selected = 2
        m.enter(4)
        XCTAssertEqual(m.elapsed, 0)
        XCTAssertEqual(m.values[2], 0)
        m.resume()
        m.enter(4)
        XCTAssertEqual(m.values[2], 4)
    }
}

final class StatsTests: XCTestCase {
    func testWinsStreaksAndBestTimeIgnoreHinted() {
        var s = Stats()
        s.recordStart(.hard); s.recordWin(.hard, time: 300, hintsUsed: 0)
        s.recordStart(.hard); s.recordWin(.hard, time: 200, hintsUsed: 1)
        XCTAssertEqual(s[.hard].won, 2)
        XCTAssertEqual(s[.hard].bestTime, 300, "hinted wins don't set best time")
        XCTAssertEqual(s[.hard].streak, 2)
        s.recordAbandon(.hard)
        XCTAssertEqual(s[.hard].streak, 0)
        XCTAssertEqual(s[.hard].bestStreak, 2)
        XCTAssertEqual(s[.hard].averageTime, 250)
        XCTAssertEqual(s[.novice], LevelStats())
    }

    func testStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = Store(directory: dir)
        var s = Stats(); s.recordStart(.normal)
        store.save(s, to: Store.statsFile)
        XCTAssertEqual(store.load(Stats.self, from: Store.statsFile), s)
        store.remove(Store.statsFile)
        XCTAssertNil(store.load(Stats.self, from: Store.statsFile))
    }
}
