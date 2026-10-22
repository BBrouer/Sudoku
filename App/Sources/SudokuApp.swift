import SwiftUI
import SudokuGame

@main
struct SudokuApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { app.appBackgrounded() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            switch app.screen {
            case .home: HomeView()
            case .game:
                if let game = app.game { GameView(game: game).id(game.state.puzzle.id) }
            }
            if let level = app.generating {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView("Preparing \(level.title) puzzle…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.screen)
    }
}
