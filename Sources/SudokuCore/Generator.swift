/// Generates uniquely-solvable puzzles, graded by `LogicSolver` so a puzzle
/// is only accepted for a level if its hardest required technique matches
/// that level's tier (SPEC.md §3) — and it is solvable without guessing.
public enum Generator {
    /// A random valid complete grid: a base pattern shuffled by
    /// validity-preserving permutations.
    public static func completeGrid<R: RandomNumberGenerator>(using rng: inout R) -> [UInt8] {
        let digits = Array(1...9).shuffled(using: &rng)
        let bands = Array(0..<3).shuffled(using: &rng)
        let stacks = Array(0..<3).shuffled(using: &rng)
        func order(_ groups: [Int], _ rng: inout R) -> [Int] {
            groups.flatMap { g in (0..<3).shuffled(using: &rng).map { g * 3 + $0 } }
        }
        let rowOrder = order(bands, &rng)
        let colOrder = order(stacks, &rng)

        var grid = [UInt8](repeating: 0, count: 81)
        for r in 0..<9 {
            for c in 0..<9 {
                let pr = rowOrder[r], pc = colOrder[c]
                let base = (3 * (pr % 3) + pr / 3 + pc) % 9
                grid[r * 9 + c] = UInt8(digits[base])
            }
        }
        return grid
    }

    /// Removes cells in 180°-symmetric pairs while the puzzle stays unique,
    /// until `targetGivens` is reached or no more cells can go.
    public static func removeCells<R: RandomNumberGenerator>(
        from solution: [UInt8], targetGivens: Int, using rng: inout R
    ) -> [UInt8] {
        var grid = solution
        var givens = 81
        for i in (0...40).shuffled(using: &rng) where givens > targetGivens {
            let j = 80 - i
            let (a, b) = (grid[i], grid[j])
            grid[i] = 0; grid[j] = 0
            if Solver.countSolutions(grid, limit: 2) == 1 {
                givens -= (i == j ? 1 : 2)
            } else {
                grid[i] = a; grid[j] = b
            }
        }
        return grid
    }

    /// Generates a puzzle for `level`. Retries with fresh grids until the
    /// given count lands in the level's range *and* `LogicSolver` says the
    /// puzzle's hardest required technique matches that level's tier.
    public static func makePuzzle(level: Level, seed: UInt64, maxAttempts: Int = 2000) -> Puzzle? {
        var rng = SeededRNG(seed: seed)
        for _ in 0..<maxAttempts {
            let solution = completeGrid(using: &rng)
            let target = Int.random(in: level.givenRange, using: &rng)
            let givens = removeCells(from: solution, targetGivens: target, using: &rng)
            let count = givens.lazy.filter { $0 != 0 }.count
            guard level.givenRange.contains(count) else { continue }
            let grade = LogicSolver.grade(givens)
            guard grade.solved, let hardest = grade.hardestTechnique, hardest.tier == level else { continue }
            return Puzzle(id: String(seed, radix: 16), level: level,
                          givens: givens, solution: solution)
        }
        return nil
    }
}
