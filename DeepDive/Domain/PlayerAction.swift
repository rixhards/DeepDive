//
//  PlayerAction.swift
//  DeepDive
//
//  What the player is attempting, extracted from their free text. The model may be wrong
//  about intent; it is never allowed to decide the outcome (ADR-002).

import Foundation

nonisolated enum Verb: String, Codable, CaseIterable, Sendable {
    /// Take in the whole place.
    case look
    /// Look closely at one specific thing.
    case examine
    /// Rummage: dig through, hunt for. Distinct from `examine` because "olha pro feno"
    /// describes the hay and "revira o feno" reaches into it, and only one of those finds
    /// the key.
    case search
    /// Pick something up.
    case take
    /// Interact with something, optionally with an item: push, open, cut, light.
    case use
    /// Deliberately put a hand on something. Its own verb because touching the scenery costs
    /// sanity, and that cost must only ever be paid when the player actually asked for it —
    /// it used to be the fallback for every `use` the resolver couldn't place (spec 013).
    case touch
    /// Knock on something. Its own verb because knocking on the wood door is the one thing
    /// that makes the hay room survivable — it must never blur into "open".
    case knock
    /// Set something on fire. Its own verb because burning the hay is a death, while merely
    /// searching it is the way to the key.
    case burn
    /// Move somewhere.
    case go
    /// Deliberately do nothing.
    case wait
    /// Ask her about herself — how she is, whether she's hurt, reassurance.
    case talk
    /// "oi", "ok", "beleza". Not a world action and not a question about her — but the very
    /// first thing a player types after she writes "oi? tem alguém aí?", and it used to come
    /// back as "eu não entendi" (spec 013).
    case greet
    /// Ask her a question about who she is, what happened, or where she thinks she is.
    /// The most natural first thing a player types, and it is not a world action.
    case ask
    /// Ask what she's carrying.
    case inventory
    /// Stop and pay attention to sound.
    case listen
    /// What the place smells like.
    case smell
    /// Call out into the dark. Not always free.
    case shout
    /// Look for somewhere to not be seen.
    case hide
    /// Sit down, catch her breath.
    case rest
    /// Answers to a question she asked. Only meaningful while something is pending.
    case yes
    case no
    case unknown
}

/// The emotional tone of the player's message toward her. The LLM (or the local parser)
/// only classifies; the sanity number each class maps to is decided here, in Swift.
nonisolated enum Tone: String, Codable, Sendable {
    case supportive
    case neutral
    case distressing

    var sanityDelta: Int {
        switch self {
        case .supportive: 2
        case .neutral: 0
        case .distressing: -4
        }
    }
}

nonisolated struct PlayerAction: Equatable, Sendable {
    var verb: Verb
    /// What the action is aimed at, in the player's own words. Matched against the current
    /// beat's feature and exit aliases — never trusted as an identifier.
    var target: String?
    /// What she should do it *with*, for `use`.
    var instrument: String?
    /// How the player's words land on her, independent of what they ask for.
    var tone: Tone
    /// The player told her *not* to do this ("não entra na água"). Negation is a modifier on
    /// the attempt, never a verb of its own — reading it as the verb `.no` is what made every
    /// sentence containing "não" cancel whatever she was about to ask (spec 013).
    var isProhibition: Bool

    init(
        verb: Verb,
        target: String? = nil,
        instrument: String? = nil,
        tone: Tone = .neutral,
        isProhibition: Bool = false
    ) {
        self.verb = verb
        self.target = target
        self.instrument = instrument
        self.tone = tone
        self.isProhibition = isProhibition
    }
}

/// Turns free text into an attempted action. Implementations must never mutate the state.
protocol ActionParser {
    func parse(playerText: String, state: GameState) async -> PlayerAction
}
