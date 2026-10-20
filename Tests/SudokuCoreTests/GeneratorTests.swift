import XCTest
@testable import SudokuCore

final class GeneratorTests: XCTestCase {
    func testCompleteGridIsValid() {
        var rng = SeededRNG(seed: 1)
        let g = Generator.completeGrid(using: &rng)
        XCTAssertEqual(Solver.countSolutions(g), 1)
        for u in 0..<9 {
            XCTAssertEqual(Set((0..<9).map { g[u * 9 + $0] }).count, 9)   // row
            XCTAssertEqual(Set((0..<9).map { g[$0 * 9 + u] }).count, 9)   // column
        }
    }

    func testSeedIsReproducible() {
        XCTAssertEqual(Generator.makePuzzle(level: .novice, seed: 42),
                       Generator.makePuzzle(level: .novice, seed: 42))
    }

    func testPuzzlesAreUniqueAndInRangeForEveryLevel() throws {
        for level in Level.allCases {
            for seed in 1...5 {
                let p = try XCTUnwrap(Generator.makePuzzle(level: level, seed: UInt64(seed)),
                                      "no \(level) puzzle for seed \(seed)")
                XCTAssertEqual(Solver.countSolutions(p.givens), 1)
                XCTAssertEqual(Solver.solve(p.givens), p.solution)
                XCTAssertTrue(level.givenRange.contains(p.givenCount),
                              "\(level): \(p.givenCount) givens")
            }
        }
    }
}
