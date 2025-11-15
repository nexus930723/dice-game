//
//  HomeView.swift
//  dice game
//
//  Created by 陳詠平 on 2025/11/9.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var game: PigGame
    @Binding var isInGame: Bool
    
    @State private var selectedMode: GameMode = .vsCPU

    // MARK: - Theme Colors
    private let darkBrown = Color(red: 0.2, green: 0.15, blue: 0.1)
    private let lightBrown = Color(red: 0.76, green: 0.60, blue: 0.49)
    private let accentGold = Color(red: 0.9, green: 0.7, blue: 0.3)

    var body: some View {
        ZStack {
            // Background Image with a darkening overlay for better contrast
            Image("背景")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Main Title
                VStack {
                    Text("Dice Game")
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                    Text("PIG")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: accentGold.opacity(0.8), radius: 10, x: 0, y: 5)


                // Game Mode Selection Panel
                VStack(spacing: 16) {
                    Text("選擇模式")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Picker("模式", selection: $selectedMode) {
                        ForEach(GameMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .background(darkBrown.opacity(0.8))
                    .cornerRadius(10)
                    .tint(.white)
                }
                .padding()
                .frame(maxWidth: 500)
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(lightBrown.opacity(0.5), lineWidth: 1)
                )

                // Start Game Button
                Button {
                    startGame()
                } label: {
                    Label("開始遊戲", systemImage: "play.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .frame(maxWidth: 280)
                .foregroundStyle(darkBrown)
                .background(
                    LinearGradient(
                        colors: [accentGold, .yellow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .yellow.opacity(0.5), radius: 10, y: 5)
                
                Spacer()
                Spacer()
            }
            .padding()
        }
    }

    private func startGame() {
        game.mode = selectedMode
        game.resetGame()

        // Apply naming rules based on mode
        switch selectedMode {
        case .vsCPU:
            // In vs CPU mode, we don't reset the player's custom name
            break
        case .vsHuman:
            game.playerLeftName = Player.left.defaultName
            game.playerRightName = Player.right.defaultName
        }

        isInGame = true
    }
}
