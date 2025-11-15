//
//  GameView.swift
//  dice game
//
//  Created by 陳詠平 on 2025/11/9.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var game: PigGame
    @Binding var isInGame: Bool

    // MARK: - Theme Colors
    private let darkBrown = Color(red: 0.2, green: 0.15, blue: 0.1)
    private let midBrown = Color(red: 0.4, green: 0.3, blue: 0.2)
    private let lightBrown = Color(red: 0.76, green: 0.60, blue: 0.49)
    private let accentGold = Color(red: 0.9, green: 0.7, blue: 0.3)

    var body: some View {
        ZStack {
            // A rich gradient background
            LinearGradient(
                gradient: Gradient(colors: [darkBrown, midBrown]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Player panels and dice view, now vertically compact
                HStack(alignment: .top, spacing: 12) {
                    PlayerPanel(game: game, player: .left)
                    DiceView(game: game)
                    PlayerPanel(game: game, player: .right)
                }

                Spacer() // Pushes content to top and bottom

                // Game state information
                TurnInfoView(game: game)

                // Action buttons
                ControlsView(game: game)

                // Scoreboard
                ScoreboardView(game: game)
            }
            .padding()
        }
        .navigationTitle("Pig Dice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    game.resetGame()
                    isInGame = false
                } label: {
                    Label("回主畫面", systemImage: "house.fill")
                }
                .tint(accentGold)
            }
        }
        .onAppear {
            game.startCPUTurnIfNeeded()
        }
    }
}


// MARK: - View Extensions for Effects

private extension View {
    func panelBackground() -> some View {
        self.background(.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    func glow(color: Color, radius: CGFloat) -> some View {
        self
            .shadow(color: color, radius: radius / 2)
            .shadow(color: color, radius: radius / 2)
    }
}


// MARK: - Subviews

private struct PlayerPanel: View {
    @ObservedObject var game: PigGame
    let player: Player
    
    private let accentGold = Color(red: 0.9, green: 0.7, blue: 0.3)
    private var isActive: Bool { game.currentPlayer == player && !game.isGameOver }
    private var total: Int { player == .left ? game.totalLeft : game.totalRight }

    var body: some View {
        VStack(spacing: 8) {
            // Player Name and Status
            HStack(spacing: 8) {
                Text(game.name(for: player))
                    .font(.headline)
                    .foregroundStyle(.white)
                if isActive {
                    Circle().fill(.green)
                        .frame(width: 10, height: 10)
                        .glow(color: .green, radius: 10)
                }
            }
            
            // Avatar
            Image(player == .left ? "2" : "1")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(5)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))


            // Total Score
            Text("\(total)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(accentGold)

            // Current Turn Score
            // This container reserves a consistent height to prevent layout jumps
            VStack {
                if isActive && game.turnTotal > 0 {
                    Text("+\(game.turnTotal)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .transition(.scale.animation(.spring()))
                }
            }
            .frame(height: 30)

            // Winner text
            if game.isGameOver, game.winner == player {
                Text("WINNER")
                    .font(.title2.bold())
                    .foregroundStyle(accentGold)
                    .glow(color: accentGold, radius: 10)
                    .padding(.bottom, 5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity) // Removed minHeight to make panel compact
        .panelBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? .green : .clear, lineWidth: 3)
                .glow(color: .green, radius: isActive ? 12 : 0)
        )
        .animation(.spring(), value: isActive)
        .animation(.spring(), value: game.turnTotal)
    }
}

private struct DiceView: View {
    @ObservedObject var game: PigGame
    
    private let accentGold = Color(red: 0.9, green: 0.7, blue: 0.3)

    var body: some View {
        VStack(spacing: 8) {
            Text("骰子")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 5)
                
                Text(face(for: game.lastRoll))
                    .font(.system(size: 70))
            }
            .frame(width: 120, height: 120)
            
            if let roll = game.lastRoll {
                Text("\(roll)")
                    .font(.title.bold())
                    .foregroundStyle(accentGold)
            } else {
                Text("-")
                    .font(.title.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 160)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: game.lastRoll)
    }

    private func face(for value: Int?) -> String {
        switch value {
        case 1: return "⚀"
        case 2: return "⚁"
        case 3: return "⚂"
        case 4: return "⚃"
        case 5: return "⚄"
        case 6: return "⚅"
        default: return "🎲"
        }
    }
}

private struct TurnInfoView: View {
    @ObservedObject var game: PigGame

    var body: some View {
        VStack {
            if game.isGameOver, let winnerName = game.winnerName {
                Text("贏家: \(winnerName)")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
            } else {
                HStack {
                    Text("輪到:")
                        .foregroundStyle(.white.opacity(0.8))
                    Text(game.currentPlayerName)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    if game.isCPUTakingTurn {
                        Text("(電腦思考中…)")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .panelBackground()
    }
}

private struct ControlsView: View {
    @ObservedObject var game: PigGame
    private let accentGold = Color(red: 0.9, green: 0.7, blue: 0.3)

    var body: some View {
        HStack(spacing: 12) {
            // Roll Button
            Button {
                game.rollDice()
            } label: {
                Label("擲骰", systemImage: "die.face.5.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentGold)
            .disabled(game.isGameOver || (game.mode == .vsCPU && game.currentPlayer == .right))

            // Hold Button
            Button {
                game.hold()
            } label: {
                Label("停手", systemImage: "hand.raised.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(accentGold)
            .disabled(game.isGameOver || game.turnTotal == 0 || (game.mode == .vsCPU && game.currentPlayer == .right))
        }
    }
}

private struct ScoreboardView: View {
    @ObservedObject var game: PigGame

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("累積戰績")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Menu {
                    Button("重置戰績", role: .destructive, action: game.resetScoreboard)
                    Button("重玩一局", action: game.replaySameMode)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            HStack {
                scoreItem(for: .left)
                Spacer()
                scoreItem(for: .right)
            }
        }
        .padding()
        .panelBackground()
    }
    
    @ViewBuilder
    private func scoreItem(for player: Player) -> some View {
        let wins = player == .left ? game.scoreboard.winsLeft : game.scoreboard.winsRight
        let losses = player == .left ? game.scoreboard.lossesLeft : game.scoreboard.lossesRight
        
        VStack(alignment: player == .left ? .leading : .trailing) {
            Text(game.name(for: player))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("勝 \(wins) / 敗 \(losses)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
