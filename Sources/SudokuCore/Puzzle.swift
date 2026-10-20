public struct Puzzle: Codable, Equatable, Sendable {
    public let id: String
    public let level: Level
    public let givens: [UInt8]
    public let solution: [UInt8]

    public var givenCount: Int { givens.lazy.filter { $0 != 0 }.count }
}
