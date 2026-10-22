// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
        .library(name: "SudokuGame", targets: ["SudokuGame"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .target(name: "SudokuGame", dependencies: ["SudokuCore"]),
        .executableTarget(name: "sudoku-gen", dependencies: ["SudokuCore"]),
        .executableTarget(name: "sudoku-play", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuGameTests", dependencies: ["SudokuGame", "SudokuCore"]),
    ]
)
