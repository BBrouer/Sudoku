# Sudoku for iPhone — Product & Technical Spec

Status: **Draft v1 — for review before any code is written.**
Items marked **[DECIDE]** are open questions with a recommended default.

## 1. Goals

A clean, fast, offline Sudoku game for iPhone with four difficulty levels:
**Novice, Normal, Experienced, Hard**. Every puzzle has exactly one solution
and is solvable by logic alone (no guessing).

Non-goals (v1): multiplayer, accounts/cloud sync, ads, in-app purchases,
iPad/Mac/Watch layouts, daily-challenge server.

## 2. Platform & Stack

- iOS 17+, iPhone only (portrait; landscape locked off in v1).
- Swift 5.10+, SwiftUI, `@Observable` view models.
- Persistence: `Codable` JSON in Application Support (current game, stats,
  settings). No backend, no network, no third-party dependencies.
- Tests: XCTest (engine) + a small XCUITest smoke test.
- Project layout: Xcode project generated from `project.yml` (XcodeGen) so it
  is diff-friendly. **[DECIDE]** Plain `.xcodeproj` instead? Default: XcodeGen.
- Note: iOS apps can only be built/run with Xcode on macOS. The engine is
  pure Swift Package code (`SudokuCore`) so it can be built and unit-tested
  on Linux too.

## 3. Difficulty Levels

Difficulty is defined by **the hardest solving technique required** plus the
**number of givens**, not by givens alone. The generator grades each puzzle
with a human-style logic solver.

| Level | Givens | Techniques required (cumulative) |
|---|---|---|
| Novice | 40–45 | Naked single, hidden single |
| Normal | 32–39 | + Naked/hidden pairs, pointing pairs / box-line reduction |
| Experienced | 27–31 | + Naked/hidden triples, X-Wing |
| Hard | 22–26 | + Swordfish, XY-Wing, simple coloring (no trial-and-error) |

A puzzle is accepted for a level only if its hardest required technique
matches that level's tier (and it's within the given-count range).

## 4. Core Gameplay

- 9×9 grid, 3×3 boxes, digits 1–9.
- Tap a cell to select; tap a digit on the number pad to fill.
- **Pencil notes** toggle: tap digits to add/remove candidates in a cell.
- **Erase** clears the selected cell (value and notes).
- **Undo / Redo** unlimited within a game.
- **Hint** (limited per game, see §6): reveals the next logical step,
  explaining the technique ("Hidden single: 7 can only go here in row 4").
  Two taps: first highlights the relevant cells, second fills the value.
- **Pause**: hides the grid and stops the timer; auto-pauses on app
  background.
- Givens are locked and styled differently from player entries.
- Completion: all cells correct → celebratory screen with time, mistakes,
  hints used, and best-time comparison.

### Highlighting (each toggleable in Settings)
- Same row / column / box as the selected cell.
- All cells containing the same digit as the selected cell.
- Conflicts (duplicate digit in a unit) shown in red.
- Number pad digits grayed out once all nine are placed.

### Mistake handling
- **Mistake checking** setting: *Instant* (wrong entry flagged immediately and
  counted) or *Off* (no feedback until the player taps Check or finishes).
- Default: Instant, with a mistake counter. **[DECIDE]** Add a 3-strikes
  game-over mode? Default: no — counter is informational only.

## 5. Screens

1. **Home** — "Continue" (if a game is in progress, showing level + elapsed
   time), four level buttons, Stats, Settings.
2. **Game** — top bar (back, level name, timer, pause), grid, tool row
   (Undo, Erase, Notes, Hint), number pad (1–9).
3. **Pause overlay** — Resume, New Game, Quit.
4. **Win** — summary, "New game (same level)", "Home".
5. **Stats** — per level: games started/won, win %, best time, average time,
   current & best win streak. Reset-stats option.
6. **Settings** — highlight toggles, mistake checking, timer visibility,
   haptics, sounds, theme (System/Light/Dark), left-handed number pad
   layout, "How to play".
7. **How to play** — short rules + a one-page glossary of the techniques
   used by each level.

## 6. Hints

- Novice/Normal: unlimited hints. Experienced/Hard: 3 per game.
  **[DECIDE]** Default as stated; used hints are shown on the win screen and
  don't block a "win", but a best time is only recorded for hint-free games.
- Hints come from the same logic solver as grading, so a hint always names a
  real technique and is never a guess.

## 7. Puzzle Engine (`SudokuCore` Swift package)

1. **Solver (backtracking + bitmask)** — counts solutions (stops at 2) to
   guarantee uniqueness.
2. **Logic solver** — applies techniques in order of difficulty, recording
   which were needed; used for grading and hints.
3. **Generator** — fill a random complete grid, remove cells in a random
   symmetric (180° rotational) order while uniqueness holds, then grade;
   retry until the target level is hit.
4. **Puzzle pool** — to keep "New Game" instant, generate puzzles on a
   background task and keep a small buffer (≈5 per level) persisted on disk;
   ship ~50 pre-generated puzzles per level in the bundle as a fallback.
   Hard puzzles are the slowest to find, so this matters most there.
5. **Seeded RNG** so puzzles are reproducible in tests and by a puzzle ID
   (shown in the pause menu; lets a user re-enter a known puzzle later).

Acceptance targets: New Game starts in <300 ms from the pool; generation of
a Hard puzzle <3 s on an iPhone 12-class device in the background.

## 8. Data Model (sketch)

```swift
struct Puzzle: Codable { let id: String; let level: Level
                         let givens: [UInt8]   // 81, 0 = empty
                         let solution: [UInt8] }
struct GameState: Codable { var puzzle: Puzzle
                            var entries: [UInt8]          // 81
                            var notes: [UInt16]           // 81 bitmasks
                            var history: [Move]           // undo/redo
                            var elapsed: TimeInterval
                            var mistakes: Int
                            var hintsUsed: Int }
enum Level: String, Codable { case novice, normal, experienced, hard }
```

Autosave after every move and on backgrounding; "Continue" restores exactly.
One in-progress game at a time. **[DECIDE]** Allow one per level? Default: one.

## 9. Design & Feel

- Native, minimal look; SF Pro / SF Rounded for digits; large tap targets
  (min 44 pt); thicker lines on box borders.
- Light/Dark mode; accent color per level (e.g. green / blue / orange / red)
  used sparingly on the level badge.
- Haptics: light tap on entry, error haptic on mistake, success on win.
  Subtle sounds, off by default. **[DECIDE]**
- Dynamic Type support for non-grid text; VoiceOver labels per cell
  ("Row 3, column 5, 7, given" / "empty, notes 1 4 9").
- Smooth, short animations (cell fill, row/col/box completion pulse).

## 10. Milestones

1. **M1 – Engine**: `SudokuCore` solver, uniqueness check, generator, logic
   solver + grading, full unit tests, calibrate level thresholds on ≥1000
   generated puzzles per level.
2. **M2 – Playable app**: Home, Game screen, notes, undo/redo, autosave,
   win screen.
3. **M3 – Polish**: hints, highlighting options, settings, stats, haptics,
   dark mode, accessibility, How to play.
4. **M4 – Ship prep**: app icon, launch screen, bundled puzzle pool, App
   Store metadata, TestFlight build.

## 11. Open Questions Summary

1. Xcode project: XcodeGen (default) vs. hand-maintained `.xcodeproj`.
2. Mistake mode: informational counter (default) vs. 3-strikes.
3. Hint limits per level and best-time eligibility (as in §6).
4. One saved game total (default) vs. one per level.
5. Sounds on/off by default (default: off).
6. App name / bundle ID (placeholder: "Sudoku", `com.example.sudoku`).
7. Minimum iOS version (default 17).

## 12. Out of Scope / Future Ideas

Daily puzzle, iCloud sync, Game Center leaderboards, iPad layout, themes,
puzzle import by photo, widgets, a fifth "Expert/Extreme" level.
