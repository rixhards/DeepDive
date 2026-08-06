//
//  Outcome.swift
//  DeepDive
//
//  The authoritative result of an action. The narrator may rephrase `facts`, never contradict
//  or extend them — and for some facts it is not allowed to touch them at all.

import Foundation

/// How an outcome's text reaches the player.
///
/// The rule, written to last: **if rewording could stop the text from doing its job, it is not
/// reworded.** A question the player has to answer and a list of the ways out are not flavour —
/// they are the interface. The model once turned "eu entro assim mesmo, com ele aceso?" into
/// "pelo jeito, não. tá tudo tão escuro e úmido aqui", and the player was left standing at a
/// life-or-death confirmation that never arrived (spec 015).
nonisolated enum Delivery {
    /// The narrator gives it her voice. The default, and right for anything that *reacts*.
    case narrated
    /// Delivered exactly as authored, at the normal typing pace. For text that *asks* or
    /// *enumerates*.
    case verbatim
    /// Delivered exactly as authored, fast, on top of itself. For the scripted climaxes —
    /// deaths, madness, escape — which are also the ones the model's guardrails might refuse.
    case script

    /// Whether the narrator is skipped entirely.
    var skipsNarrator: Bool { self != .narrated }
    /// Whether it comes through at the hurried pace of someone in real trouble.
    var isUrgent: Bool { self == .script }
}

nonisolated struct Outcome {
    /// What must be communicated. Written as her own words already — the narrator adjusts
    /// voice and register, it does not invent.
    var facts: [String]
    /// Follow-up messages delivered in order, with no player input in between.
    var beats: [String] = []
    /// How this reaches the player. See `Delivery`.
    var delivery: Delivery = .narrated
    /// Player messages this outcome swallows unanswered before the game ends.
    ///
    /// Only deaths set this, and that asymmetry is deliberate: in a death she is gone, so the
    /// messages falling into the void *are* the ending. Escape and madness go straight to the
    /// reveal, because there the story finished and the reveal is the payoff. The view model
    /// also runs a clock alongside this count, so a player who stops typing still gets there
    /// (spec 014).
    var silentTurns: Int = 0
    /// This outcome already tells the story of the ending it triggered (the fire, the water,
    /// the corridor), so the generic ending text must not replace it.
    var narratesEnding: Bool = false

    init(
        _ facts: String...,
        beats: [String] = [],
        delivery: Delivery = .narrated,
        silentTurns: Int = 0,
        narratesEnding: Bool = false
    ) {
        self.facts = facts
        self.beats = beats
        self.delivery = delivery
        self.silentTurns = silentTurns
        self.narratesEnding = narratesEnding
    }

    /// Every line, in delivery order. Only meaningful when the narrator is skipped, where the
    /// text goes out exactly as authored.
    var allTexts: [String] { facts + beats }

    /// Each group becomes one narrated message: the facts land together, then every beat on
    /// its own so a scene arrives in pieces.
    var narratableChunks: [[String]] { [facts] + beats.map { [$0] } }

    var isEmpty: Bool { allTexts.allSatisfy(\.isEmpty) }

    /// Forces the whole outcome through untouched. Used when a pending question is restated on
    /// top of another reply: the question has to survive, and it rides as a beat, so the only
    /// way to protect it is to protect the message it travels in.
    mutating func makeVerbatim() {
        if delivery == .narrated { delivery = .verbatim }
    }
}
