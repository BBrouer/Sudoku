/// Solves grids using only human-style deduction techniques (SPEC.md §3),
/// in order from easiest to hardest, the same way a person would. Used both
/// for grading generated puzzles and for in-game hints.
///
/// `nextStep` is a stateless, single-shot deduction from the raw grid (no
/// memory of previously-deduced eliminations beyond basic peer exclusion) —
/// the right shape for a hint, which should always reflect what's deducible
/// from the board as it currently stands. `grade` instead keeps a running
/// candidate state across steps, since harder techniques build on
/// eliminations earlier steps made that aren't recoverable from `values` alone.
public struct LogicSolver {
    public struct Step: Sendable {
        public let technique: Technique
        public let placement: (cell: Int, digit: UInt8)?
        public let eliminations: [(cell: Int, digit: UInt8)]
        public let explanation: String
    }

    public struct GradeResult: Sendable {
        public let solved: Bool
        public let hardestTechnique: Technique?
    }

    /// Fully solves `givens` using only the techniques below. `solved` is
    /// false if a guess would be required to finish.
    public static func grade(_ givens: [UInt8]) -> GradeResult {
        var values = givens
        var cands = computeCandidates(values)
        var hardest: Technique?
        var iterations = 0
        while values.contains(0) {
            iterations += 1
            guard iterations <= 500, let step = findStep(values, cands) else {
                return GradeResult(solved: false, hardestTechnique: hardest)
            }
            if hardest == nil || step.technique > hardest! { hardest = step.technique }
            apply(step, &values, &cands)
        }
        return GradeResult(solved: true, hardestTechnique: hardest)
    }

    /// The next logical step for the current board, or nil if none of the
    /// supported techniques apply (a guess would be required).
    public static func nextStep(_ values: [UInt8]) -> Step? {
        findStep(values, computeCandidates(values))
    }

    // MARK: - Driving the techniques

    private static func findStep(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for scan in scans {
            if let step = scan(values, cands) { return step }
        }
        return nil
    }

    private static func apply(_ step: Step, _ values: inout [UInt8], _ cands: inout [UInt16]) {
        if let p = step.placement {
            values[p.cell] = p.digit
            cands[p.cell] = 0
            let bit = UInt16(1) << UInt16(p.digit)
            for peer in Geometry.peers[p.cell] { cands[peer] &= ~bit }
        }
        for e in step.eliminations {
            cands[e.cell] &= ~(UInt16(1) << UInt16(e.digit))
        }
    }

    private static func computeCandidates(_ values: [UInt8]) -> [UInt16] {
        var cands = [UInt16](repeating: 0, count: 81)
        for i in 0..<81 where values[i] == 0 {
            var used: UInt16 = 0
            for p in Geometry.peers[i] where values[p] != 0 {
                used |= UInt16(1) << UInt16(values[p])
            }
            cands[i] = Geometry.allDigits & ~used
        }
        return cands
    }

    private static let scans: [([UInt8], [UInt16]) -> Step?] = [
        findNakedSingle,
        findHiddenSingle,
        { findNakedSubset(2, .nakedPair, $0, $1) },
        { findHiddenSubset(2, .hiddenPair, $0, $1) },
        findPointingPair,
        findBoxLineReduction,
        { findNakedSubset(3, .nakedTriple, $0, $1) },
        { findHiddenSubset(3, .hiddenTriple, $0, $1) },
        findXWing,
        findSwordfish,
        findXYWing,
        findSimpleColoring,
    ]

    // MARK: - Novice: singles

    private static func findNakedSingle(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for i in 0..<81 where values[i] == 0 {
            if cands[i].nonzeroBitCount == 1 {
                let d = UInt8(cands[i].trailingZeroBitCount)
                return Step(technique: .nakedSingle, placement: (i, d), eliminations: [],
                            explanation: "Naked single: \(d) is the only candidate left in \(cellName(i)).")
            }
        }
        return nil
    }

    private static func findHiddenSingle(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for unit in Geometry.units {
            for d in 1...9 {
                let bit = UInt16(1) << UInt16(d)
                var only: Int?
                var count = 0
                for cell in unit where values[cell] == 0 && cands[cell] & bit != 0 {
                    count += 1; only = cell
                    if count > 1 { break }
                }
                if count == 1, let cell = only {
                    return Step(technique: .hiddenSingle, placement: (cell, UInt8(d)), eliminations: [],
                                explanation: "Hidden single: \(d) can only go in \(cellName(cell)).")
                }
            }
        }
        return nil
    }

    // MARK: - Normal: pairs, pointing pairs, box/line reduction

    private static func findNakedSubset(_ size: Int, _ technique: Technique,
                                         _ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for unit in Geometry.units {
            let candidates = unit.filter {
                values[$0] == 0 && (2...size).contains(cands[$0].nonzeroBitCount)
            }
            for combo in combinations(candidates, size) {
                let union = combo.reduce(UInt16(0)) { $0 | cands[$1] }
                guard union.nonzeroBitCount == size else { continue }
                var elims: [(cell: Int, digit: UInt8)] = []
                for cell in unit where !combo.contains(cell) && values[cell] == 0 {
                    for d in bitsList(cands[cell] & union) { elims.append((cell, UInt8(d))) }
                }
                guard !elims.isEmpty else { continue }
                return Step(technique: technique, placement: nil, eliminations: elims,
                            explanation: "\(size == 2 ? "Naked pair" : "Naked triple") \(bitsList(union)) in "
                                + "\(combo.map(cellName)) removes those digits elsewhere in the unit.")
            }
        }
        return nil
    }

    private static func findHiddenSubset(_ size: Int, _ technique: Technique,
                                          _ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for unit in Geometry.units {
            let empty = unit.filter { values[$0] == 0 }
            guard empty.count > size else { continue }
            let digits = (1...9).filter { d in empty.contains { cands[$0] & (UInt16(1) << UInt16(d)) != 0 } }
            for combo in combinations(Array(digits), size) {
                let mask = combo.reduce(UInt16(0)) { $0 | (UInt16(1) << UInt16($1)) }
                let cells = empty.filter { cands[$0] & mask != 0 }
                guard cells.count == size else { continue }
                var elims: [(cell: Int, digit: UInt8)] = []
                for cell in cells {
                    for d in bitsList(cands[cell] & ~mask) { elims.append((cell, UInt8(d))) }
                }
                guard !elims.isEmpty else { continue }
                return Step(technique: technique, placement: nil, eliminations: elims,
                            explanation: "Hidden \(size == 2 ? "pair" : "triple") \(combo) confines those digits to "
                                + "\(cells.map(cellName)).")
            }
        }
        return nil
    }

    private static func findPointingPair(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for (b, box) in Geometry.boxCells.enumerated() {
            for d in 1...9 {
                let bit = UInt16(1) << UInt16(d)
                let hits = box.filter { values[$0] == 0 && cands[$0] & bit != 0 }
                guard (2...3).contains(hits.count) else { continue }
                let rows = Set(hits.map { Geometry.row[$0] })
                let cols = Set(hits.map { Geometry.col[$0] })
                let line: [Int]?
                if rows.count == 1 { line = Geometry.rowCells[rows.first!] }
                else if cols.count == 1 { line = Geometry.colCells[cols.first!] }
                else { line = nil }
                guard let line else { continue }
                let elims = line.filter { !box.contains($0) && values[$0] == 0 && cands[$0] & bit != 0 }
                    .map { (cell: $0, digit: UInt8(d)) }
                guard !elims.isEmpty else { continue }
                return Step(technique: .pointingPair, placement: nil, eliminations: elims,
                            explanation: "Pointing pair: \(d) in box \(b + 1) is confined to one line, "
                                + "so it's removed elsewhere on that line.")
            }
        }
        return nil
    }

    private static func findBoxLineReduction(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for line in Geometry.rowCells + Geometry.colCells {
            for d in 1...9 {
                let bit = UInt16(1) << UInt16(d)
                let hits = line.filter { values[$0] == 0 && cands[$0] & bit != 0 }
                guard (2...3).contains(hits.count) else { continue }
                let boxes = Set(hits.map { Geometry.box[$0] })
                guard boxes.count == 1, let b = boxes.first else { continue }
                let box = Geometry.boxCells[b]
                let elims = box.filter { !hits.contains($0) && values[$0] == 0 && cands[$0] & bit != 0 }
                    .map { (cell: $0, digit: UInt8(d)) }
                guard !elims.isEmpty else { continue }
                return Step(technique: .boxLineReduction, placement: nil, eliminations: elims,
                            explanation: "Box/line reduction: \(d) in that line is confined to one box, "
                                + "so it's removed elsewhere in the box.")
            }
        }
        return nil
    }

    // MARK: - Experienced: triples, X-Wing

    private static func findXWing(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        findFish(size: 2, technique: .xWing, values, cands,
                 lineCells: Geometry.rowCells, perpCells: Geometry.colCells,
                 lineIndexOf: Geometry.row, perpIndexOf: Geometry.col)
        ?? findFish(size: 2, technique: .xWing, values, cands,
                    lineCells: Geometry.colCells, perpCells: Geometry.rowCells,
                    lineIndexOf: Geometry.col, perpIndexOf: Geometry.row)
    }

    // MARK: - Hard: Swordfish, XY-Wing, simple coloring

    private static func findSwordfish(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        findFish(size: 3, technique: .swordfish, values, cands,
                 lineCells: Geometry.rowCells, perpCells: Geometry.colCells,
                 lineIndexOf: Geometry.row, perpIndexOf: Geometry.col)
        ?? findFish(size: 3, technique: .swordfish, values, cands,
                    lineCells: Geometry.colCells, perpCells: Geometry.rowCells,
                    lineIndexOf: Geometry.col, perpIndexOf: Geometry.row)
    }

    /// Basic (finless) X-Wing/Swordfish: `size` lines whose digit-`d`
    /// candidates fall entirely within `size` perpendicular lines.
    private static func findFish(size: Int, technique: Technique, _ values: [UInt8], _ cands: [UInt16],
                                  lineCells: [[Int]], perpCells: [[Int]],
                                  lineIndexOf: [Int], perpIndexOf: [Int]) -> Step? {
        for d in 1...9 {
            let bit = UInt16(1) << UInt16(d)
            var lines: [(line: Int, positions: [Int])] = []
            for (li, cellsInLine) in lineCells.enumerated() {
                let hits = cellsInLine.filter { values[$0] == 0 && cands[$0] & bit != 0 }
                if (2...size).contains(hits.count) {
                    lines.append((li, hits.map { perpIndexOf[$0] }))
                }
            }
            guard lines.count >= size else { continue }
            for combo in combinations(lines, size) {
                var positions = Set<Int>()
                for c in combo { positions.formUnion(c.positions) }
                guard positions.count == size else { continue }
                let comboLines = Set(combo.map { $0.line })
                var elims: [(cell: Int, digit: UInt8)] = []
                for pos in positions {
                    for cell in perpCells[pos]
                    where values[cell] == 0 && cands[cell] & bit != 0 && !comboLines.contains(lineIndexOf[cell]) {
                        elims.append((cell, UInt8(d)))
                    }
                }
                guard !elims.isEmpty else { continue }
                let name = size == 2 ? "X-Wing" : "Swordfish"
                return Step(technique: technique, placement: nil, eliminations: elims,
                            explanation: "\(name) on \(d) confines it to \(size) lines, "
                                + "removing it elsewhere on the crossing lines.")
            }
        }
        return nil
    }

    private static func findXYWing(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        let bivalue = (0..<81).filter { values[$0] == 0 && cands[$0].nonzeroBitCount == 2 }
        for pivot in bivalue {
            let xy = bitsList(cands[pivot])
            guard xy.count == 2 else { continue }
            let pivotPeers = Geometry.peers[pivot].filter { bivalue.contains($0) }
            for pincer1 in pivotPeers {
                let d1 = Set(bitsList(cands[pincer1]))
                let shared1 = d1.intersection(xy)
                guard shared1.count == 1, let x = shared1.first, let z = d1.subtracting([x]).first else { continue }
                guard let y = xy.first(where: { $0 != x }) else { continue }
                for pincer2 in pivotPeers where pincer2 != pincer1 {
                    let d2 = Set(bitsList(cands[pincer2]))
                    guard d2 == Set([y, z]) else { continue }
                    let zBit = UInt16(1) << UInt16(z)
                    let elims = (0..<81).filter { cell in
                        cell != pivot && cell != pincer1 && cell != pincer2 && values[cell] == 0
                            && cands[cell] & zBit != 0
                            && Geometry.peers[pincer1].contains(cell) && Geometry.peers[pincer2].contains(cell)
                    }.map { (cell: $0, digit: UInt8(z)) }
                    guard !elims.isEmpty else { continue }
                    return Step(technique: .xyWing, placement: nil, eliminations: elims,
                                explanation: "XY-Wing pivoting on \(cellName(pivot)) eliminates \(z) from cells "
                                    + "seen by both pincers.")
                }
            }
        }
        return nil
    }

    /// Single-digit chain coloring: conjugate pairs (units with exactly two
    /// candidate cells for a digit) are colored alternately; a color that
    /// sees itself is eliminated entirely, and a cell seeing both colors has
    /// that digit eliminated.
    private static func findSimpleColoring(_ values: [UInt8], _ cands: [UInt16]) -> Step? {
        for d in 1...9 {
            let bit = UInt16(1) << UInt16(d)
            let cells = (0..<81).filter { values[$0] == 0 && cands[$0] & bit != 0 }
            guard cells.count >= 4 else { continue }

            var adjacency: [Int: Set<Int>] = [:]
            for unit in Geometry.units {
                let hits = unit.filter { cells.contains($0) }
                if hits.count == 2 {
                    adjacency[hits[0], default: []].insert(hits[1])
                    adjacency[hits[1], default: []].insert(hits[0])
                }
            }
            guard !adjacency.isEmpty else { continue }

            var color: [Int: Int] = [:]
            for start in adjacency.keys where color[start] == nil {
                color[start] = 0
                var queue = [start]
                var idx = 0
                while idx < queue.count {
                    let cur = queue[idx]; idx += 1
                    for nbr in adjacency[cur] ?? [] where color[nbr] == nil {
                        color[nbr] = 1 - color[cur]!
                        queue.append(nbr)
                    }
                }
            }

            for (cell, c) in color {
                if Geometry.peers[cell].contains(where: { color[$0] == c }) {
                    let elims = color.filter { $0.value == c }.map { (cell: $0.key, digit: UInt8(d)) }
                    if !elims.isEmpty {
                        return Step(technique: .simpleColoring, placement: nil, eliminations: elims,
                                    explanation: "Simple coloring on \(d): one color chain contradicts itself, "
                                        + "so that whole color is eliminated.")
                    }
                }
            }
            for cell in cells where color[cell] == nil {
                let seenColors = Set(Geometry.peers[cell].compactMap { color[$0] })
                if seenColors.count == 2 {
                    return Step(technique: .simpleColoring, placement: nil,
                                eliminations: [(cell, UInt8(d))],
                                explanation: "Simple coloring on \(d): \(cellName(cell)) sees both colors, "
                                    + "so \(d) is eliminated there.")
                }
            }
        }
        return nil
    }

    // MARK: - Small helpers

    private static func bitsList(_ mask: UInt16) -> [Int] {
        var m = mask
        var result: [Int] = []
        while m != 0 {
            result.append(m.trailingZeroBitCount)
            m &= m - 1
        }
        return result
    }

    private static func combinations<T>(_ arr: [T], _ k: Int) -> [[T]] {
        guard k > 0, arr.count >= k else { return [] }
        if k == 1 { return arr.map { [$0] } }
        if k == arr.count { return [arr] }
        var result: [[T]] = []
        for i in 0..<(arr.count - k + 1) {
            for tail in combinations(Array(arr[(i + 1)...]), k - 1) {
                result.append([arr[i]] + tail)
            }
        }
        return result
    }

    private static func cellName(_ i: Int) -> String {
        "row \(Geometry.row[i] + 1), column \(Geometry.col[i] + 1)"
    }
}
