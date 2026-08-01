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
    /// The last few things she actually said, oldest first. Used to strip sentences she would
    /// otherwise repeat verbatim — the model likes to end every message with the same
    /// complaint, and during the opening it echoes whole messages from two turns back.
    let recentReplies: [String]

    /// How many of her recent replies the dedup filter compares against. Five covers the
    /// four-message opening, which is where the echoing was worst.
    static let repeatWindow = 5

    init(
        facts: [String],
        sanity: Int,
        beat: BeatID,
        beatSummary: String,
        carrying: [String],
        memory: StoryMemory,
        recentReplies: [String] = []
    ) {
        self.facts = facts
        self.sanity = sanity
        self.beat = beat
        self.beatSummary = beatSummary
        self.carrying = carrying
        self.memory = memory
        self.recentReplies = recentReplies
    }
}

/// `FoundationModelsNarrator` is the only implementation, and the default `ChatViewModel`
/// takes. The protocol stays because narration has to be injectable: the facts it receives
/// are already valid pt-BR, so anything that needs a deterministic voice can supply one
/// without the model in the loop.
protocol Narrator {
    func narrate(_ request: NarrationRequest) async -> String
}
