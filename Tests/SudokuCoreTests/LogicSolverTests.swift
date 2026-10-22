import XCTest
@testable import SudokuCore

private func parse(_ s: String) -> [UInt8] {
    s.map { UInt8(String($0))! }
}

final class LogicSolverTests: XCTestCase {
    let puzzle = parse("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
    let solution = parse("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    /// Every deduction must agree with the true solution: placements match it,
    /// and no elimination removes the digit that belongs in that cell.
    private func assertSound(_ step: LogicSolver.Step, against solution: [UInt8],
                             file: StaticString = #filePath, line: UInt = #line) {
        if let p = step.placement {
            XCTAssertEqual(solution[p.cell], p.digit, "\(step.technique) misplaced: \(step.explanation)",
                           file: file, line: line)
        }
        for e in step.eliminations {
            XCTAssertNotEqual(solution[e.cell], e.digit, "\(step.technique) eliminated a true digit: \(step.explanation)",
                              file: file, line: line)
        }
        XCTAssertFalse(step.explanation.isEmpty, file: file, line: line)
        XCTAssertTrue(step.placement != nil || !step.eliminations.isEmpty,
                      "\(step.technique) step does nothing", file: file, line: line)
    }

    func testKnownPuzzleSolvesWithSingles() {
        let result = LogicSolver.grade(puzzle)
        XCTAssertTrue(result.solved)
        if let hardest = result.hardestTechnique {
            XCTAssertEqual(hardest.tier, .novice)
        }
    }

    func testCompleteGridGradesSolvedWithNoTechnique() {
        let result = LogicSolver.grade(solution)
        XCTAssertTrue(result.solved)
        XCTAssertNil(result.hardestTechnique)
        XCTAssertNil(LogicSolver.nextStep(solution))
    }

    func testNakedSingleOnLastEmptyCell() throws {
        var board = solution
        board[40] = 0
        let step = try XCTUnwrap(LogicSolver.nextStep(board))
        XCTAssertEqual(step.technique, .nakedSingle)
        XCTAssertEqual(step.placement?.cell, 40)
        XCTAssertEqual(step.placement?.digit, solution[40])
    }

    func testSinglesFirstWhenWholeRowIsBlank() throws {
        var board = solution
        for i in 0..<9 { board[i] = 0 }
        let step = try XCTUnwrap(LogicSolver.nextStep(board))
        XCTAssertLessThanOrEqual(step.technique, .hiddenSingle)
        assertSound(step, against: solution)
    }

    func testStepsAreSoundOnRandomPartialBoards() {
        var rng = SeededRNG(seed: 7)
        var techniquesSeen = Set<Technique>()
        for _ in 0..<150 {
            let grid = Generator.completeGrid(using: &rng)
            let givens = Generator.removeCells(from: grid, targetGivens: Int.random(in: 24...34, using: &rng),
                                               using: &rng)
            guard let step = LogicSolver.nextStep(givens) else { continue }
            techniquesSeen.insert(step.technique)
            assertSound(step, against: grid)
        }
        XCTAssertFalse(techniquesSeen.isEmpty)
    }

    func testGradedPuzzlesStayUnique() {
        var rng = SeededRNG(seed: 11)
        for _ in 0..<20 {
            let grid = Generator.completeGrid(using: &rng)
            let givens = Generator.removeCells(from: grid, targetGivens: 30, using: &rng)
            let result = LogicSolver.grade(givens)
            if result.solved {
                XCTAssertNotNil(result.hardestTechnique)
            }
            XCTAssertEqual(Solver.countSolutions(givens), 1)
        }
    }

    func testTechniqueOrderingAndTiers() {
        XCTAssertEqual(Technique.allCases.sorted(), Technique.allCases)
        XCTAssertLessThan(Technique.nakedSingle, Technique.simpleColoring)
        let order = Level.allCases
        var last = 0
        for t in Technique.allCases {
            let idx = order.firstIndex(of: t.tier)!
            XCTAssertGreaterThanOrEqual(idx, last, "\(t) tier regresses")
            last = idx
        }
        XCTAssertEqual(Set(Technique.allCases.map(\.tier)), Set(Level.allCases))
    }
}
