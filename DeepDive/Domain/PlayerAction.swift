//
//  PlayerAction.swift
//  DeepDive
//
//  What the player is attempting, extracted from their free text. The model may be wrong
//  about intent; it is never allowed to decide the outcome (ADR-002).

import Foundation

enum Verb: String, Codable, CaseIterable {
    /// Take in the whole place.
    case look
    /// Look closely at one specific thing.
    case examine
    /// Pick something up.
    case take
    /// Interact with something, optionally with an item: touch, knock, push, open, cut, burn.
    case use
    /// Move somewhere.
    case go
    /// Deliberately do nothing.
    case wait
    /// Ask her about herself — how she is, whether she's hurt, reassurance.
    case talk
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

struct PlayerAction: Equatable {
    var verb: Verb
    /// What the action is aimed at, in the player's own words. Matched against the current
    /// place's feature and exit aliases — never trusted as an identifier.
    var target: String?
    /// What she should do it *with*, for `use`.
    var instrument: String?
    /// True when the player's words were hostile toward her.
    var isHostile: Bool

    init(verb: Verb, target: String? = nil, instrument: String? = nil, isHostile: Bool = false) {
        self.verb = verb
        self.target = target
        self.instrument = instrument
        self.isHostile = isHostile
    }
}

/// Turns free text into an attempted action. Implementations must never mutate the world.
protocol ActionParser {
    func parse(playerText: String, world: World) async -> PlayerAction
}
