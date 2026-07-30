//
//  GameSession.swift
//  DeepDive
//
//  The save file: authoritative state + LLM context + what's on screen. The LLM session
//  itself is never persisted — it's discardable and rebuilt from `memory`.

import Foundation

nonisolated struct GameSession: Codable, Equatable {
    let state: GameState
    let memory: StoryMemory
    let messages: [ChatMessage]
}
