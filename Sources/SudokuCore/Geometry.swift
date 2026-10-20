/// Precomputed board geometry. Cells are indexed 0..<81, row-major.
enum Geometry {
    static let row: [Int] = (0..<81).map { $0 / 9 }
    static let col: [Int] = (0..<81).map { $0 % 9 }
    static let box: [Int] = (0..<81).map { ($0 / 27) * 3 + ($0 % 9) / 3 }

    /// Bitmask with bits 1...9 set (bit 0 unused so digit d is `1 << d`).
    static let allDigits: UInt16 = 0b11_1111_1110
}
