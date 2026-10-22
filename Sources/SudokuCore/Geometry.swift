/// Precomputed board geometry. Cells are indexed 0..<81, row-major.
enum Geometry {
    static let row: [Int] = (0..<81).map { $0 / 9 }
    static let col: [Int] = (0..<81).map { $0 % 9 }
    static let box: [Int] = (0..<81).map { ($0 / 27) * 3 + ($0 % 9) / 3 }

    /// Bitmask with bits 1...9 set (bit 0 unused so digit d is `1 << d`).
    static let allDigits: UInt16 = 0b11_1111_1110

    static let rowCells: [[Int]] = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
    static let colCells: [[Int]] = (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
    static let boxCells: [[Int]] = (0..<9).map { b in
        let br = (b / 3) * 3, bc = (b % 3) * 3
        return (0..<9).map { k in (br + k / 3) * 9 + (bc + k % 3) }
    }

    /// All 27 units (9 rows, 9 columns, 9 boxes) as lists of cell indices.
    static let units: [[Int]] = rowCells + colCells + boxCells

    /// Cells sharing a row, column, or box with `i`, excluding `i` itself.
    static let peers: [[Int]] = (0..<81).map { i in
        var s = Set<Int>()
        s.formUnion(rowCells[row[i]])
        s.formUnion(colCells[col[i]])
        s.formUnion(boxCells[box[i]])
        s.remove(i)
        return s.sorted()
    }
}
