//
//  EngineResponse.swift
//  DeepDive
//

import Foundation

struct EngineOption: Equatable {
    let id: String
    let text: String
    let hints: [String]

    init(id: String, text: String, hints: [String] = []) {
        self.id = id
        self.text = text
        self.hints = hints
    }
}

struct EngineResponse: Equatable {
    let nodeID: String
    let characterText: String
    let options: [EngineOption]
    let isTerminal: Bool
    /// Deliver `characterText` verbatim, skipping the `Narrator`. Endings whose horror *is*
    /// the malformed text (degraded symbols, self-contradicting description) would be
    /// "fixed" into coherent prose by narration.
    let rawNarration: Bool
    /// Player messages this node swallows without replying before the game ends. `0` means
    /// a terminal node finishes immediately, as usual.
    let silentTurns: Int

    init(
        nodeID: String,
        characterText: String,
        options: [EngineOption],
        isTerminal: Bool,
        rawNarration: Bool = false,
        silentTurns: Int = 0
    ) {
        self.nodeID = nodeID
        self.characterText = characterText
        self.options = options
        self.isTerminal = isTerminal
        self.rawNarration = rawNarration
        self.silentTurns = silentTurns
    }
}
