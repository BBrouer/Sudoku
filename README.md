# Sudoku
For leisure

## Running the iPhone app

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
brew install xcodegen
xcodegen
open Sudoku.xcodeproj    # pick an iPhone simulator, press Run
```

## Other targets

- `swift test -c release -Xswiftc -enable-testing` — engine and game-model tests (fast; debug builds are slow because puzzle generation is CPU-heavy)
- `swift run -c release sudoku-play [level] [seed]` — play in the terminal
- `swift run -c release sudoku-gen calibrate|profile|pool` — generator tooling
