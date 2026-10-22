public struct Puzzle: Codable, Equatable, Sendable {
    public let id: String
    public let level: Level
    public let givens: [UInt8]
    public let solution: [UInt8]

    public init(id: String, level: Level, givens: [UInt8], solution: [UInt8]) {
        self.id = id
        self.level = level
        self.givens = givens
        self.solution = solution
    }

    public var givenCount: Int { givens.lazy.filter { $0 != 0 }.count }
}
