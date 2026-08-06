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
    /// Bumped on every write. This is how a reader tells that the store moved on without it —
    /// which is how the app notices an App Intent took a turn while it was in the background.
    /// Without it the app kept writing stale in-memory state over the intent's work (spec 014).
    var revision: Int

    init(state: GameState, memory: StoryMemory, messages: [ChatMessage], revision: Int = 0) {
        self.state = state
        self.memory = memory
        self.messages = messages
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case state, memory, messages, revision
    }

    /// Saves written before spec 014 have no `revision`. They decode as 0 instead of failing,
    /// so a run in progress survives the upgrade rather than being discarded.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(GameState.self, forKey: .state)
        memory = try container.decode(StoryMemory.self, forKey: .memory)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
    }
}
