//
//  ContentView.swift
//  dice game
//
//  Created by 陳詠平 on 2025/11/9.
//

import SwiftUI
import Combine

// MARK: - Supporting Types

enum GameMode: String, CaseIterable, Identifiable {
    case vsCPU = "單人模式"
    case vsHuman = "雙人對戰"

    var id: String { rawValue }
}

enum Player: Int, CaseIterable, Identifiable {
    case left = 0
    case right = 1

    var id: Int { rawValue }

    var defaultName: String {
        switch self {
        case .left: return "玩家 1"
        case .right: return "玩家 2"
        }
    }
}

struct Scoreboard: Codable, Equatable {
    var winsLeft: Int = 0
    var lossesLeft: Int = 0
    var winsRight: Int = 0
    var lossesRight: Int = 0
}

// MARK: - ViewModel

@MainActor
final class PigGame: ObservableObject {
    // Persistent names and scoreboard
    @AppStorage("playerLeftName") var playerLeftName: String = Player.left.defaultName
    @AppStorage("playerRightName") var playerRightName: String = Player.right.defaultName
    @AppStorage("scoreboard") private var scoreboardData: Data = Data()

    @Published var mode: GameMode = .vsCPU {
        didSet { resetGame() }
    }

    // Game state
    @Published var totalLeft: Int = 0
    @Published var totalRight: Int = 0
    @Published var turnTotal: Int = 0
    @Published var currentPlayer: Player = .left
    @Published var lastRoll: Int? = nil
    @Published var isGameOver: Bool = false
    @Published var winner: Player? = nil
    @Published var isCPUTakingTurn: Bool = false

    // Settings
    let winningScore: Int = 100
    var cpuHoldThreshold: Int = 20

    // Scoreboard (persisted)
    @Published private(set) var scoreboard: Scoreboard = .init() {
        didSet { persistScoreboard() }
    }

    init() {
        loadScoreboard()
    }

    // MARK: - Game Actions

    func resetGame() {
        turnTotal = 0
        lastRoll = nil
        isGameOver = false
        winner = nil
        isCPUTakingTurn = false
        totalLeft = 0
        totalRight = 0
        currentPlayer = .left
    }

    func replaySameMode() {
        turnTotal = 0
        lastRoll = nil
        isGameOver = false
        winner = nil
        isCPUTakingTurn = false
        totalLeft = 0
        totalRight = 0
        currentPlayer = .left
    }

    func rollDice() {
        guard !isGameOver else { return }
        // 當前為 CPU 回合且尚未由 CPU 自動流程接管時，不允許手動操作
        guard !(mode == .vsCPU && currentPlayer == .right && isCPUTakingTurn == false) else { return }

        let roll = Int.random(in: 1...6)
        lastRoll = roll

        if roll == 1 {
            // Pig out: lose the turn total and switch player
            turnTotal = 0
            endTurn(scorable: false)
        } else {
            turnTotal += roll
        }
    }

    func hold() {
        guard !isGameOver else { return }
        guard !(mode == .vsCPU && currentPlayer == .right && isCPUTakingTurn == false) else { return }

        applyTurnTotalToCurrentPlayer()
        checkWinAndMaybeEnd()
        if !isGameOver {
            endTurn(scorable: true)
        }
    }

    private func applyTurnTotalToCurrentPlayer() {
        switch currentPlayer {
        case .left: totalLeft += turnTotal
        case .right: totalRight += turnTotal
        }
    }

    private func endTurn(scorable: Bool) {
        // Reset turn state
        turnTotal = 0
        lastRoll = nil

        // Switch player
        currentPlayer = (currentPlayer == .left) ? .right : .left

        // 如果切換到 CPU 且遊戲未結束，啟動 CPU
        startCPUTurnIfNeeded()
    }

    private func checkWinAndMaybeEnd() {
        if totalLeft >= winningScore {
            isGameOver = true
            winner = .left
            updateScoreboard(winner: .left)
        } else if totalRight >= winningScore {
            isGameOver = true
            winner = .right
            updateScoreboard(winner: .right)
        }
    }

    // MARK: - CPU Logic

    private func shouldCPUHold() -> Bool {
        // 簡單策略：如果本回合加總已達門檻，或加總後可獲勝，就 Hold
        let projected = totalRight + turnTotal
        if projected >= winningScore { return true }
        return turnTotal >= cpuHoldThreshold
    }

    private func delay(_ milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }

    private func cpuCanAct() -> Bool {
        return mode == .vsCPU && currentPlayer == .right && !isGameOver
    }

    private func cpuRollOnce() {
        let roll = Int.random(in: 1...6)
        lastRoll = roll
        if roll == 1 {
            // Pig out
            turnTotal = 0
            endTurn(scorable: false)
        } else {
            turnTotal += roll
        }
    }

    private func cpuHoldNow() {
        applyTurnTotalToCurrentPlayer()
        checkWinAndMaybeEnd()
        if !isGameOver {
            endTurn(scorable: true)
        }
    }

    private func cancelIfNoLongerCPUTurn() -> Bool {
        return !(mode == .vsCPU && currentPlayer == .right && !isGameOver)
    }

    private func beginCPUTakingTurn() {
        isCPUTakingTurn = true
    }

    private func endCPUTakingTurn() {
        isCPUTakingTurn = false
    }

    private func cpuTurnLoopIteration() async -> Bool {
        // 回傳 true 表示 CPU 繼續回合；false 表示回合結束
        if cancelIfNoLongerCPUTurn() { return false }

        if shouldCPUHold() {
            cpuHoldNow()
            return false
        } else {
            cpuRollOnce()
            if cancelIfNoLongerCPUTurn() { return false }
            if lastRoll == 1 {
                // 掉到 1 已結束
                return false
            }
            return true
        }
    }

    // 將 cpuTurn 改為 internal（非 private），以便 View 可以在需要時觸發
    func cpuTurn() async {
        guard cpuCanAct() else { return }
        beginCPUTakingTurn()
        defer { endCPUTakingTurn() }

        // 小延遲讓 UI 可讀
        await delay(500)

        while cpuCanAct() {
            await delay(500)
            let keepGoing = await cpuTurnLoopIteration()
            if !keepGoing { break }
        }
    }

    // 供 View 呼叫的安全入口
    func startCPUTurnIfNeeded() {
        if mode == .vsCPU && currentPlayer == .right && !isGameOver && !isCPUTakingTurn {
            Task { await self.cpuTurn() }
        }
    }

    // MARK: - Scoreboard persistence

    private func updateScoreboard(winner: Player) {
        switch winner {
        case .left:
            scoreboard.winsLeft += 1
            scoreboard.lossesRight += 1
        case .right:
            scoreboard.winsRight += 1
            scoreboard.lossesLeft += 1
        }
    }

    private func persistScoreboard() {
        if let data = try? JSONEncoder().encode(scoreboard) {
            scoreboardData = data
        }
    }

    private func loadScoreboard() {
        if let loaded = try? JSONDecoder().decode(Scoreboard.self, from: scoreboardData), scoreboardData.count > 0 {
            scoreboard = loaded
        } else {
            scoreboard = .init()
        }
    }

    func resetScoreboard() {
        scoreboard = .init()
    }

    // Helpers
    func name(for player: Player) -> String {
        switch player {
        case .left: return playerLeftName.isEmpty ? Player.left.defaultName : playerLeftName
        case .right: return playerRightName.isEmpty ? Player.right.defaultName : playerRightName
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var game = PigGame()

    // 首頁 / 遊戲頁切換狀態
    @State private var isInGame: Bool = false
    @State private var selectedMode: GameMode = .vsCPU

    // 自訂顏色（深咖啡、淺咖啡）
    private let darkBrown = Color(red: 0.35, green: 0.24, blue: 0.17)
    private let lightBrown = Color(red: 0.76, green: 0.60, blue: 0.49)

    var body: some View {
        NavigationStack {
            Group {
                if isInGame {
                    gameView
                } else {
                    homeView
                }
            }
            // 首頁不顯示標題；遊戲頁顯示
            .navigationTitle(isInGame ? "Pig Dice" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isInGame {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // 回主畫面：重置遊戲並回首頁
                            game.resetGame()
                            isInGame = false
                        } label: {
                            Label("回主畫面", systemImage: "house")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 首頁

    private var homeView: some View {
        ZStack {
            // 背景圖「背景」
            Image("背景")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 前景內容
            VStack(spacing: 24) {
                Spacer()

                // 上方標題
                Text("Dice Game Pig")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

                VStack(spacing: 16) {
                    Text("選擇模式")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Picker("模式", selection: $selectedMode) {
                        ForEach(GameMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    // 讓 segmented 的背景不再是白色，改為深咖啡色
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(darkBrown.opacity(0.9))
                    )
                    // 讓內文顏色在深色背景上仍清楚
                    .tint(.white)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: 500)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 10)

                Button {
                    // 套用模式、初始化名稱規則後進入遊戲
                    game.mode = selectedMode
                    game.resetGame()

                    // 名稱規則
                    switch selectedMode {
                    case .vsCPU:
                        break
                    case .vsHuman:
                        game.playerLeftName = Player.left.defaultName
                        game.playerRightName = Player.right.defaultName
                    }

                    isInGame = true
                } label: {
                    Text("開始遊戲")
                        .font(.title3.bold())
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                // 改成淺咖啡色
                .tint(lightBrown)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - 遊戲頁

    private var gameView: some View {
        VStack(spacing: 16) {
            // 模式顯示（遊戲中僅顯示，不可切）
            HStack {
                Text("模式")
                Spacer()
                Text(game.mode.rawValue)
                    .bold()
            }

            HStack(spacing: 12) {
                playerPanel(.left)
                diceView()
                playerPanel(.right)
            }
            .frame(maxHeight: .infinity)

            turnInfo

            controls

            scoreboardView
        }
        .padding()
        .onAppear {
            // 進入遊戲頁後，如果現在輪到 CPU，啟動 CPU
            game.startCPUTurnIfNeeded()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func playerPanel(_ player: Player) -> some View {
        let isActive = game.currentPlayer == player && !game.isGameOver
        let total = player == .left ? game.totalLeft : game.totalRight
        let isCPU = (game.mode == .vsCPU && player == .right)

        VStack(spacing: 8) {
            HStack {
                if isActive { Circle().fill(.green).frame(width: 10, height: 10) }
                Text(displayName(for: player))
                    .font(.headline)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            Text("\(total)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            if isActive && game.turnTotal > 0 {
                Text("本回合暫得 +\(game.turnTotal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if game.isGameOver, let winner = game.winner, winner == player {
                Text("贏家！")
                    .font(.title3.bold())
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 單人模式左邊可輸入名字；雙人模式禁止輸入
            if game.mode == .vsCPU && player == .left {
                TextField("輸入名稱", text: $game.playerLeftName)
                    .textFieldStyle(.roundedBorder)
            } else {
                // 其他情況不顯示輸入框（雙人固定玩家 1 / 玩家 2；右邊在單人模式固定電腦）
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
    }

    private func displayName(for player: Player) -> String {
        switch game.mode {
        case .vsHuman:
            return player.defaultName // 固定「玩家 1」「玩家 2」
        case .vsCPU:
            if player == .right { return "電腦" }
            // 左邊玩家可自定名稱
            return game.playerLeftName.isEmpty ? Player.left.defaultName : game.playerLeftName
        }
    }

    @ViewBuilder
    private func diceView() -> some View {
        VStack(spacing: 12) {
            Text("骰子")
                .font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.95))
                    .frame(width: 120, height: 120)
                Text(face(for: game.lastRoll))
                    .font(.system(size: 60))
            }
            if game.lastRoll != nil {
                Text("點數：\(game.lastRoll!)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未擲骰")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160)
    }

    private func face(for value: Int?) -> String {
        // 用骰子 emoji 簡易顯示
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

    private var turnInfo: some View {
        VStack(spacing: 4) {
            if game.isGameOver, let winner = game.winner {
                Text("贏家：\(winnerDisplayName(winner))")
                    .font(.title2.bold())
                    .foregroundStyle(.pink)
            } else {
                HStack {
                    Text("目前玩家：")
                    Text(currentPlayerDisplayName())
                        .bold()
                    if game.mode == .vsCPU && game.currentPlayer == .right {
                        Text(game.isCPUTakingTurn ? "(電腦思考中…)" : "")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            HStack {
                Text("本回合總分：\(game.turnTotal)")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func winnerDisplayName(_ winner: Player) -> String {
        switch game.mode {
        case .vsHuman:
            return winner == .left ? Player.left.defaultName : Player.right.defaultName
        case .vsCPU:
            return winner == .left
                ? (game.playerLeftName.isEmpty ? Player.left.defaultName : game.playerLeftName)
                : "電腦"
        }
    }

    private func currentPlayerDisplayName() -> String {
        switch game.mode {
        case .vsHuman:
            return game.currentPlayer == .left ? Player.left.defaultName : Player.right.defaultName
        case .vsCPU:
            if game.currentPlayer == .right { return "電腦" }
            return game.playerLeftName.isEmpty ? Player.left.defaultName : game.playerLeftName
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                game.rollDice()
            } label: {
                Label("Roll", systemImage: "die.face.5")
            }
            .buttonStyle(.borderedProminent)
            // CPU 回合或 CPU 正在行動時禁用
            .disabled(game.isGameOver || (game.mode == .vsCPU && (game.currentPlayer == .right || game.isCPUTakingTurn)))

            Button {
                game.hold()
            } label: {
                Label("Hold", systemImage: "hand.raised")
            }
            .buttonStyle(.bordered)
            .disabled(game.isGameOver || game.turnTotal == 0 || (game.mode == .vsCPU && (game.currentPlayer == .right || game.isCPUTakingTurn)))

            Spacer()

            Button {
                game.replaySameMode()
            } label: {
                Label("Replay", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Menu {
                Button("重置累積戰績", role: .destructive) {
                    game.resetScoreboard()
                }
                Divider()
                Button("新遊戲（保留模式）") {
                    game.replaySameMode()
                }
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
        }
    }

    private var scoreboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("累積戰績")
                .font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(leftScoreboardName())
                        .font(.subheadline.bold())
                    Text("勝：\(game.scoreboard.winsLeft)  敗：\(game.scoreboard.lossesLeft)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(rightScoreboardName())
                        .font(.subheadline.bold())
                    Text("勝：\(game.scoreboard.winsRight)  敗：\(game.scoreboard.lossesRight)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func leftScoreboardName() -> String {
        switch game.mode {
        case .vsHuman:
            return Player.left.defaultName
        case .vsCPU:
            return game.playerLeftName.isEmpty ? Player.left.defaultName : game.playerLeftName
        }
    }

    private func rightScoreboardName() -> String {
        switch game.mode {
        case .vsHuman:
            return Player.right.defaultName
        case .vsCPU:
            return "電腦"
        }
    }
}

#Preview {
    ContentView()
}
