// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .executableTarget(name: "sudoku-gen", dependencies: ["SudokuCore"]),
        .executableTarget(name: "sudoku-play", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
