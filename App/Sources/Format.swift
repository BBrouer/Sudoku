import SwiftUI
import SudokuCore

func formatTime(_ t: TimeInterval) -> String {
    let s = Int(t)
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
        : String(format: "%d:%02d", s / 60, s % 60)
}

extension Level {
    /// Accent per level (SPEC.md §9).
    var color: Color {
        switch self {
        case .novice: return .green
        case .normal: return .blue
        case .experienced: return .orange
        case .hard: return .red
        }
    }

    var blurb: String {
        switch self {
        case .novice: return "Singles only"
        case .normal: return "Pairs and pointing"
        case .experienced: return "Triples and X-Wing"
        case .hard: return "Swordfish, XY-Wing, coloring"
        }
    }
}
