
import SwiftUI

struct ContentView: View {
    @StateObject private var game = PigGame()
    @State private var isInGame: Bool = false

    var body: some View {
        NavigationStack {
            if isInGame {
                GameView(game: game, isInGame: $isInGame)
            } else {
                HomeView(game: game, isInGame: $isInGame)
            }
        }
    }
}

#Preview {
    ContentView()
}
