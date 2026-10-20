/// Backtracking solver with bitmask candidates and a fewest-candidates-first
/// heuristic. Used to prove uniqueness (`countSolutions`) and to find the
/// solution of a generated puzzle. Grids are 81 digits, 0 = empty.
public struct Solver {
    private var cells: [UInt8]
    private var rows = [UInt16](repeating: 0, count: 9)
    private var cols = [UInt16](repeating: 0, count: 9)
    private var boxes = [UInt16](repeating: 0, count: 9)
    private var found = 0
    private var limit = 2
    private var first: [UInt8]?
    private var valid = true

    private init(_ grid: [UInt8]) {
        precondition(grid.count == 81, "grid must have 81 cells")
        cells = grid
        for i in 0..<81 where grid[i] != 0 {
            let bit = UInt16(1) << UInt16(grid[i])
            let r = Geometry.row[i], c = Geometry.col[i], b = Geometry.box[i]
            if (rows[r] | cols[c] | boxes[b]) & bit != 0 { valid = false }
            rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
        }
    }

    /// Number of solutions, stopping once `limit` is reached.
    public static func countSolutions(_ grid: [UInt8], limit: Int = 2) -> Int {
        var s = Solver(grid)
        guard s.valid else { return 0 }
        s.limit = limit
        s.search()
        return s.found
    }

    /// First solution found, or nil if none.
    public static func solve(_ grid: [UInt8]) -> [UInt8]? {
        var s = Solver(grid)
        guard s.valid else { return nil }
        s.limit = 1
        s.search()
        return s.first
    }

    private mutating func search() {
        var best = -1
        var bestMask: UInt16 = 0
        var bestCount = 10
        for i in 0..<81 where cells[i] == 0 {
            let mask = ~(rows[Geometry.row[i]] | cols[Geometry.col[i]] | boxes[Geometry.box[i]])
                & Geometry.allDigits
            let n = mask.nonzeroBitCount
            if n < bestCount {
                best = i; bestMask = mask; bestCount = n
                if n <= 1 { break }
            }
        }
        if best == -1 {
            found += 1
            if first == nil { first = cells }
            return
        }
        if bestCount == 0 { return }

        let r = Geometry.row[best], c = Geometry.col[best], b = Geometry.box[best]
        var mask = bestMask
        while mask != 0 {
            let d = mask.trailingZeroBitCount
            let bit = UInt16(1) << UInt16(d)
            mask &= mask - 1
            cells[best] = UInt8(d)
            rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
            search()
            rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit
            cells[best] = 0
            if found >= limit { return }
        }
    }
}
