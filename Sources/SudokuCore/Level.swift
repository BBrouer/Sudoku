/// The four difficulty levels. Given-count ranges come from SPEC.md §3;
/// technique tiers are enforced by the logic solver (not yet implemented).
public enum Level: String, Codable, CaseIterable, Sendable {
    case novice, normal, experienced, hard

    public var givenRange: ClosedRange<Int> {
        switch self {
        case .novice: return 40...45
        case .normal: return 32...39
        case .experienced: return 27...31
        case .hard: return 22...26
        }
    }
}
