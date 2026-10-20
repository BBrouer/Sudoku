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
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
