//
//  Outcome.swift
//  DeepDive
//
//  The authoritative result of an action. The narrator may rephrase `facts`, never contradict
//  or extend them.

import Foundation

nonisolated struct Outcome {
    /// What must be communicated. Written as her own words already — the narrator adjusts
    /// voice and register, it does not invent.
    var facts: [String]
    /// Follow-up messages delivered in order, with no player input in between.
    var beats: [String] = []
    /// Deliver verbatim, skipping the narrator. For authored climaxes and text that is
    /// malformed on purpose.
    var raw: Bool = false
    /// Player messages this outcome swallows unanswered before the game ends.
    var silentTurns: Int = 0
    /// This outcome already tells the story of the ending it triggered (the fire, the water,
    /// the corridor), so the generic ending text must not replace it.
    var narratesEnding: Bool = false

    init(
        _ facts: String...,
        beats: [String] = [],
        raw: Bool = false,
        silentTurns: Int = 0,
        narratesEnding: Bool = false
    ) {
        self.facts = facts
        self.beats = beats
        self.raw = raw
        self.silentTurns = silentTurns
        self.narratesEnding = narratesEnding
    }

    /// Every line, in delivery order. Only meaningful for `raw` outcomes, where the text goes
    /// out exactly as authored.
    var allTexts: [String] { facts + beats }

    /// Each group becomes one narrated message: the facts land together, then every beat on
    /// its own so a scene arrives in pieces.
    var narratableChunks: [[String]] { [facts] + beats.map { [$0] } }

    var isEmpty: Bool { allTexts.allSatisfy(\.isEmpty) }
}
