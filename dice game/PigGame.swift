
import SwiftUI
import Combine

@MainActor
final class PigGame: ObservableObject {
    // Persistent names and scoreboard
    @AppStorage("playerLeftName") var playerLeftName: String = Player.left.defaultName
    @AppStorage("playerRightName") var playerRightName: String = Player.right.defaultName
    @AppStorage("scoreboard") private var scoreboardData: Data = Data()

    @Published var mode: GameMode = .vsCPU {
        didSet { resetGame() }
    }


    @Published var totalLeft: Int = 0
    @Published var totalRight: Int = 0
    @Published var turnTotal: Int = 0
    @Published var currentPlayer: Player = .left
    @Published var lastRoll: Int? = nil
    @Published var isGameOver: Bool = false
    @Published var winner: Player? = nil
    @Published var isCPUTakingTurn: Bool = false

    
    let winningScore: Int = 100
    var cpuHoldThreshold: Int = 20


    @Published private(set) var scoreboard: Scoreboard = .init() {
        didSet { persistScoreboard() }
    }

    init() {
        loadScoreboard()
    }

    // MARK: - Display Name Helpers

    func name(for player: Player) -> String {
        switch mode {
        case .vsHuman:
            return player.defaultName
        case .vsCPU:
            switch player {
            case .left:
                return playerLeftName.isEmpty ? Player.left.defaultName : playerLeftName
            case .right:
                return "電腦"
            }
        }
    }

    var currentPlayerName: String {
        name(for: currentPlayer)
    }

    var winnerName: String? {
        guard let winner = winner else { return nil }
        return name(for: winner)
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


        currentPlayer = (currentPlayer == .left) ? .right : .left

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
        
        if cancelIfNoLongerCPUTurn() { return false }

        if shouldCPUHold() {
            cpuHoldNow()
            return false
        } else {
            cpuRollOnce()
            if cancelIfNoLongerCPUTurn() { return false }
            if lastRoll == 1 {
               
                return false
            }
            return true
        }
    }


    func cpuTurn() async {
        guard cpuCanAct() else { return }
        beginCPUTakingTurn()
        defer { endCPUTakingTurn() }

     
        await delay(500)

        while cpuCanAct() {
            await delay(500)
            let keepGoing = await cpuTurnLoopIteration()
            if !keepGoing { break }
        }
    }


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
}
