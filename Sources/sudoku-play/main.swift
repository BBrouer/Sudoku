import Foundation
import SudokuCore

/// Terminal Sudoku for trying out the engine.
///
/// Usage: swift run -c release sudoku-play [novice|normal|experienced|hard] [seed]

func render(_ values: [UInt8], givens: [UInt8]) {
    print("     1 2 3   4 5 6   7 8 9")
    for r in 0..<9 {
        if r % 3 == 0 { print("   +-------+-------+-------+") }
        var line = " \(r + 1) |"
        for c in 0..<9 {
            let v = values[r * 9 + c]
            let ch = v == 0 ? "." : String(v)
            line += givens[r * 9 + c] != 0 ? " \(ch)" : " \u{1B}[36m\(ch)\u{1B}[0m"
            if c % 3 == 2 { line += " |" }
        }
        print(line)
    }
    print("   +-------+-------+-------+")
}

let help = """
Commands:
  <row> <col> <digit>   place a digit (1-9); 0 clears the cell, e.g. "3 4 7"
  hint                  explain the next logical step
  check                 report any wrong entries
  new [level] [seed]    start a new puzzle
  help                  show this
  quit
"""

func newPuzzle(_ level: Level, seed: UInt64?) -> Puzzle {
    let s = seed ?? UInt64.random(in: 1...UInt64.max)
    guard let p = Generator.makePuzzle(level: level, seed: s) else {
        print("Couldn't generate a \(level.rawValue) puzzle for that seed; trying another.")
        return newPuzzle(level, seed: nil)
    }
    return p
}

var level = CommandLine.arguments.dropFirst().first.flatMap(Level.init(rawValue:)) ?? .novice
var seed = CommandLine.arguments.dropFirst(2).first.flatMap { UInt64($0) }
var puzzle = newPuzzle(level, seed: seed)
var values = puzzle.givens

print("Sudoku — \(puzzle.level.rawValue), \(puzzle.givenCount) givens, id \(puzzle.id). Type 'help' for commands.")
render(values, givens: puzzle.givens)

while true {
    print("> ", terminator: "")
    guard let line = readLine() else { break }
    let words = line.split(separator: " ").map(String.init)
    guard let cmd = words.first else { continue }

    switch cmd.lowercased() {
    case "quit", "q", "exit":
        exit(0)
    case "help", "h", "?":
        print(help)
    case "hint":
        if let bad = (0..<81).first(where: { values[$0] != 0 && values[$0] != puzzle.solution[$0] }) {
            print("Row \(bad / 9 + 1), column \(bad % 9 + 1) is wrong — fix that first.")
        } else if let step = LogicSolver.nextStep(values) {
            print("Hint (\(step.technique)): \(step.explanation)")
        } else {
            print("No logical step found; this position needs guessing.")
        }
    case "check":
        let wrong = (0..<81).filter { values[$0] != 0 && values[$0] != puzzle.solution[$0] }
        print(wrong.isEmpty ? "All entries so far are correct."
              : "Wrong: " + wrong.map { "r\($0 / 9 + 1)c\($0 % 9 + 1)" }.joined(separator: " "))
    case "new":
        if let l = words.dropFirst().first.flatMap(Level.init(rawValue:)) { level = l }
        puzzle = newPuzzle(level, seed: words.dropFirst(2).first.flatMap { UInt64($0) })
        values = puzzle.givens
        print("New \(puzzle.level.rawValue) puzzle, id \(puzzle.id).")
        render(values, givens: puzzle.givens)
    default:
        let nums = words.compactMap { Int($0) }
        guard nums.count == 3, (1...9).contains(nums[0]), (1...9).contains(nums[1]), (0...9).contains(nums[2]) else {
            print("Didn't understand that. Type 'help'.")
            continue
        }
        let cell = (nums[0] - 1) * 9 + nums[1] - 1
        if puzzle.givens[cell] != 0 { print("That's a given and can't be changed."); continue }
        values[cell] = UInt8(nums[2])
        render(values, givens: puzzle.givens)
        if !values.contains(0) {
            if values == puzzle.solution {
                print("Solved! 🎉  Type 'new' for another.")
            } else {
                print("The grid is full, but something is wrong. Try 'check'.")
            }
        }
    }
}
