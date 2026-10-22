import Foundation
import SudokuCore

/// Dev CLI for the engine: sanity checks (XCTest needs full Xcode, which
/// isn't always on hand), calibration stats, and generating the bundled
/// fallback puzzle pool (SPEC.md §7).
///
/// Usage:
///   swift run sudoku-gen check
///   swift run sudoku-gen calibrate [count-per-level]
///   swift run sudoku-gen pool <count-per-level> <output-dir>

func parse(_ s: String) -> [UInt8] { s.map { UInt8(String($0))! } }

func check() -> Bool {
    var ok = true
    func expect(_ name: String, _ condition: Bool) {
        print(condition ? "  PASS  \(name)" : "  FAIL  \(name)")
        if !condition { ok = false }
    }

    let p = parse("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
    let solution = parse("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    expect("solver solves a known puzzle", Solver.solve(p) == solution)
    expect("solver confirms known puzzle is unique", Solver.countSolutions(p) == 1)
    expect("empty grid has multiple solutions", Solver.countSolutions([UInt8](repeating: 0, count: 81), limit: 2) == 2)

    var bad = p
    bad[2] = 5
    expect("conflicting givens have no solution", Solver.countSolutions(bad) == 0)

    var rng = SeededRNG(seed: 1)
    let grid = Generator.completeGrid(using: &rng)
    expect("generated complete grid is valid+unique", Solver.countSolutions(grid) == 1)
    for u in 0..<9 {
        expect("row \(u) has 9 distinct digits", Set((0..<9).map { grid[u * 9 + $0] }).count == 9)
        expect("col \(u) has 9 distinct digits", Set((0..<9).map { grid[$0 * 9 + u] }).count == 9)
    }

    expect("logic solver fully solves a complete grid trivially", LogicSolver.grade(grid).solved)

    let gradeOfP = LogicSolver.grade(p)
    expect("logic solver solves the known puzzle", gradeOfP.solved)
    if let hardest = gradeOfP.hardestTechnique {
        print("  info  known puzzle's hardest technique: \(hardest) (tier \(hardest.tier))")
    }

    expect("seeded generation is reproducible", Generator.makePuzzle(level: .novice, seed: 42)
        == Generator.makePuzzle(level: .novice, seed: 42))

    return ok
}

func calibrate(perLevel: Int) {
    for level in Level.allCases {
        var successes = 0
        var total: TimeInterval = 0
        var tierCounts: [Technique: Int] = [:]
        for seed in 1...UInt64(perLevel) {
            let start = Date()
            if let puzzle = Generator.makePuzzle(level: level, seed: seed) {
                successes += 1
                let grade = LogicSolver.grade(puzzle.givens)
                if let t = grade.hardestTechnique { tierCounts[t, default: 0] += 1 }
            }
            total += Date().timeIntervalSince(start)
        }
        let avgMs = (total / Double(perLevel)) * 1000
        print("\(level.rawValue): \(successes)/\(perLevel) generated, avg \(String(format: "%.0f", avgMs)) ms/attempt-seed")
        for (t, c) in tierCounts.sorted(by: { $0.key < $1.key }) {
            print("    \(t): \(c)")
        }
    }
}

func pool(perLevel: Int, outDir: String) throws {
    let fm = FileManager.default
    try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for level in Level.allCases {
        var puzzles: [Puzzle] = []
        var seed: UInt64 = 1
        while puzzles.count < perLevel {
            if let p = Generator.makePuzzle(level: level, seed: seed) { puzzles.append(p) }
            seed += 1
            if seed > UInt64(perLevel) * 50 { break } // safety valve
        }
        let data = try encoder.encode(puzzles)
        let path = "\(outDir)/\(level.rawValue).json"
        try data.write(to: URL(fileURLWithPath: path))
        print("\(level.rawValue): wrote \(puzzles.count)/\(perLevel) puzzles to \(path)")
    }
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "check":
    exit(check() ? 0 : 1)
case "calibrate":
    let n = args.count > 2 ? Int(args[2]) ?? 20 : 20
    calibrate(perLevel: n)
case "pool":
    guard args.count > 3, let n = Int(args[2]) else {
        print("usage: sudoku-gen pool <count-per-level> <output-dir>"); exit(1)
    }
    try pool(perLevel: n, outDir: args[3])
default:
    print("usage: sudoku-gen <check|calibrate [n]|pool <n> <dir>>")
    exit(1)
}
