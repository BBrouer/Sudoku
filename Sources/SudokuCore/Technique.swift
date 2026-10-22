/// Human solving techniques, ordered from easiest to hardest. The ordering
/// doubles as the order `LogicSolver` tries them in: cheaper techniques are
/// always attempted before harder ones, matching how a person would solve.
public enum Technique: Int, Codable, CaseIterable, Comparable, Sendable {
    case nakedSingle
    case hiddenSingle
    case nakedPair
    case hiddenPair
    case pointingPair
    case boxLineReduction
    case nakedTriple
    case hiddenTriple
    case xWing
    case swordfish
    case xyWing
    case simpleColoring

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The difficulty tier (SPEC.md §3) a puzzle needing this technique belongs to.
    public var tier: Level {
        switch self {
        case .nakedSingle, .hiddenSingle:
            return .novice
        case .nakedPair, .hiddenPair, .pointingPair, .boxLineReduction:
            return .normal
        case .nakedTriple, .hiddenTriple, .xWing:
            return .experienced
        case .swordfish, .xyWing, .simpleColoring:
            return .hard
        }
    }
}
