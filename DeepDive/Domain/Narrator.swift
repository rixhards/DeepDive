//
//  Narrator.swift
//  DeepDive
//

import Foundation

/// Everything the narrator is allowed to know. `facts` are authoritative — it may rephrase
/// them, never contradict or extend them. The full chat history is deliberately absent:
/// the narrator's context comes from `memory` (compact, rebuilt at beat boundaries) plus
/// whatever its own session accumulated inside the current beat.
nonisolated struct NarrationRequest: Sendable {
    let facts: [String]
    let sanity: Int
    let beat: BeatID
    let beatSummary: String
    let carrying: [String]
    let memory: StoryMemory
    /// The last thing she actually said. Used to strip sentences she would otherwise repeat
    /// verbatim — the model likes to end every message with the same complaint.
    let previousReply: String

    init(
        facts: [String],
        sanity: Int,
        beat: BeatID,
        beatSummary: String,
        carrying: [String],
        memory: StoryMemory,
        previousReply: String = ""
    ) {
        self.facts = facts
        self.sanity = sanity
        self.beat = beat
        self.beatSummary = beatSummary
        self.carrying = carrying
        self.memory = memory
        self.previousReply = previousReply
    }
}

protocol Narrator {
    func narrate(_ request: NarrationRequest) async -> String
}

/// Returns the facts unchanged. Safe compile-time fallback and the default in tests — the
/// authored facts are already valid pt-BR on their own.
struct StaticNarrator: Narrator {
    func narrate(_ request: NarrationRequest) async -> String {
        request.facts.joined(separator: " ")
    }
}
