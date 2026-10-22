import SwiftUI
import SudokuCore
import SudokuGame

/// The 9×9 grid. Reads highlight state straight from the observable model.
struct BoardView: View {
    let game: GameModel

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            let conflicts = game.conflicts
            let selectedValue = game.selected.map { game.values[$0] } ?? 0
            let hintCells = Set(game.hint?.cells ?? [])

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { c in
                                let i = r * 9 + c
                                CellView(game: game, index: i, size: cell,
                                         selectedValue: selectedValue,
                                         isConflict: conflicts.contains(i),
                                         isHint: hintCells.contains(i))
                            }
                        }
                    }
                }
                GridLines(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Thin lines between cells, thick lines between boxes.
    private struct GridLines: View {
        let side: CGFloat
        var body: some View {
            Canvas { ctx, size in
                let step = size.width / 9
                for k in 0...9 {
                    let thick = k % 3 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(k) * step, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(k) * step, y: size.height))
                    path.move(to: CGPoint(x: 0, y: CGFloat(k) * step))
                    path.addLine(to: CGPoint(x: size.width, y: CGFloat(k) * step))
                    ctx.stroke(path, with: .color(thick ? .primary : .secondary.opacity(0.5)),
                               lineWidth: thick ? 2 : 0.5)
                }
            }
            .frame(width: side, height: side)
            .allowsHitTesting(false)
        }
    }
}

private struct CellView: View {
    let game: GameModel
    let index: Int
    let size: CGFloat
    let selectedValue: UInt8
    let isConflict: Bool
    let isHint: Bool

    var body: some View {
        let value = game.values[index]
        ZStack {
            background
            if value != 0 {
                Text(String(value))
                    .font(.system(size: size * 0.6, weight: game.isGiven(index) ? .bold : .regular,
                                  design: .rounded))
                    .foregroundStyle(foreground)
            } else if game.notes(index) != 0 {
                NotesView(mask: game.notes(index), size: size,
                          highlight: selectedValue)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { game.selected = index }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText(value))
        .accessibilityAddTraits(.isButton)
    }

    private var background: some View {
        let selected = game.selected
        var color = Color.clear
        if let s = selected {
            if s == index {
                color = .accentColor.opacity(0.35)
            } else if game.values[s] != 0, game.values[s] == game.values[index] {
                color = .accentColor.opacity(0.22)
            } else if Geometry.peers[s].contains(index) {
                color = .gray.opacity(0.14)
            }
        }
        return ZStack {
            Rectangle().fill(Color(.systemBackground))
            Rectangle().fill(color)
            if isHint { Rectangle().fill(Color.yellow.opacity(0.45)) }
        }
    }

    private var foreground: Color {
        if isConflict || game.isWrong(index) { return .red }
        return game.isGiven(index) ? .primary : .accentColor
    }

    private func accessibilityText(_ value: UInt8) -> String {
        let pos = "Row \(index / 9 + 1), column \(index % 9 + 1)"
        if value != 0 { return "\(pos), \(value)\(game.isGiven(index) ? ", given" : "")" }
        let notes = (1...9).filter { game.notes(index) & (1 << UInt16($0)) != 0 }
        return notes.isEmpty ? "\(pos), empty"
            : "\(pos), empty, notes \(notes.map(String.init).joined(separator: " "))"
    }
}

private struct NotesView: View {
    let mask: UInt16
    let size: CGFloat
    let highlight: UInt8

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let d = r * 3 + c + 1
                        Text(mask & (1 << UInt16(d)) != 0 ? String(d) : " ")
                            .font(.system(size: size * 0.24, weight: d == Int(highlight) ? .bold : .regular,
                                          design: .rounded))
                            .foregroundStyle(d == Int(highlight) ? Color.accentColor : .secondary)
                            .frame(width: size / 3.4, height: size / 3.4)
                    }
                }
            }
        }
    }
}
