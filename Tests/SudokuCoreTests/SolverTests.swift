import XCTest
@testable import SudokuCore

private func parse(_ s: String) -> [UInt8] {
    s.map { UInt8(String($0))! }
}

final class SolverTests: XCTestCase {
    let puzzle = parse("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
    let solution = parse("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    func testSolvesKnownPuzzle() {
        XCTAssertEqual(Solver.solve(puzzle), solution)
    }

    func testKnownPuzzleIsUnique() {
        XCTAssertEqual(Solver.countSolutions(puzzle), 1)
    }

    func testEmptyGridHasManySolutions() {
        XCTAssertEqual(Solver.countSolutions([UInt8](repeating: 0, count: 81), limit: 2), 2)
    }

    func testConflictingGivensHaveNoSolution() {
        var bad = puzzle
        bad[2] = 5 // duplicate 5 in row 0
        XCTAssertEqual(Solver.countSolutions(bad), 0)
        XCTAssertNil(Solver.solve(bad))
    }

    func testRemovingCluesCanBreakUniqueness() {
        var p = solution
        // Blank a deadly rectangle-ish region: first row entirely -> still unique,
        // but blanking two full bands is not.
        for i in 0..<54 { p[i] = 0 }
        XCTAssertGreaterThan(Solver.countSolutions(p, limit: 2), 1)
    }
}
