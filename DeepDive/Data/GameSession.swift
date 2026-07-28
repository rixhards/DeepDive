//
//  GameSession.swift
//  DeepDive
//

import Foundation

struct GameSession: Equatable {
    let world: World
    let messages: [ChatMessage]
}
