import Foundation
import SudokuCore

/// Per-level results (SPEC.md §5, Stats).
public struct LevelStats: Codable, Equatable, Sendable {
    public var started = 0
    public var won = 0
    public var totalTime: TimeInterval = 0
    /// Best time among hint-free wins only (SPEC.md §6).
    public var bestTime: TimeInterval?
    public var streak = 0
    public var bestStreak = 0

    public var winRate: Double { started == 0 ? 0 : Double(won) / Double(started) }
    public var averageTime: TimeInterval? { won == 0 ? nil : totalTime / Double(won) }
}

public struct Stats: Codable, Equatable, Sendable {
    public private(set) var levels: [Level: LevelStats] = [:]

    public init() {}

    public subscript(level: Level) -> LevelStats { levels[level] ?? LevelStats() }

    public mutating func recordStart(_ level: Level) {
        levels[level, default: LevelStats()].started += 1
    }

    /// An abandoned (replaced or quit-and-new) game breaks the win streak.
    public mutating func recordAbandon(_ level: Level) {
        levels[level, default: LevelStats()].streak = 0
    }

    public mutating func recordWin(_ level: Level, time: TimeInterval, hintsUsed: Int) {
        var s = self[level]
        s.won += 1
        s.totalTime += time
        s.streak += 1
        s.bestStreak = max(s.bestStreak, s.streak)
        if hintsUsed == 0 { s.bestTime = min(s.bestTime ?? time, time) }
        levels[level] = s
    }

    public mutating func reset() { levels = [:] }
}

/// JSON persistence in Application Support (SPEC.md §2).
public struct Store: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func applicationSupport() -> Store {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Store(directory: base.appendingPathComponent("Sudoku", isDirectory: true))
    }

    public func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func save<T: Encodable>(_ value: T, to name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            // Autosave is best-effort; a failed write shouldn't interrupt play.
        }
    }

    public func remove(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}

extension Store {
    public static let gameFile = "game.json"
    public static let statsFile = "stats.json"
}
