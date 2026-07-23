//
//  GameSession.swift
//  DeepDive
//

import Foundation

struct GameSession: Equatable {
    let currentNodeID: String
    let flags: [String: Bool]
    let ints: [String: Int]
    let messages: [ChatMessage]
}
