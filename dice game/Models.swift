//
//  Models.swift
//  dice game
//
//  Created by 陳詠平 on 2025/11/9.
//

import Foundation

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
