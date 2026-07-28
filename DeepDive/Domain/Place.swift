//
//  Place.swift
//  DeepDive
//
//  Shape of a location. Content lives in WorldMap; this file only describes the mould.

import Foundation

/// Something in a place the player can look at or act on. Enumerating these once is what
/// makes a room feel answerable — every feature is examinable without authoring an option.
struct Feature {
    let id: String
    /// Words the player might use for it. Matched after diacritic/case folding.
    let aliases: [String]
    /// What she reports when she looks at it.
    let detail: String

    init(_ id: String, aliases: [String], detail: String) {
        self.id = id
        self.aliases = aliases
        self.detail = detail
    }
}

struct Exit {
    let aliases: [String]
    let destination: PlaceID
    /// When present and unmet, she refuses with `blocked` instead of moving.
    let requires: ((World) -> Bool)?
    let blocked: String?
    /// Applied when she actually goes through.
    let sanityDelta: Int

    init(
        aliases: [String],
        to destination: PlaceID,
        requires: ((World) -> Bool)? = nil,
        blocked: String? = nil,
        sanityDelta: Int = 0
    ) {
        self.aliases = aliases
        self.destination = destination
        self.requires = requires
        self.blocked = blocked
        self.sanityDelta = sanityDelta
    }
}

struct Place {
    let id: PlaceID
    /// What she says the first time she arrives.
    let arrival: String
    /// What she says on coming back — never a verbatim repeat of `arrival`.
    let revisit: String
    /// One line summarising what's around, used when she's asked to look around.
    let overview: String
    let features: [Feature]
    let exits: [Exit]
    /// Items lying here to be found, and what she says on picking each one up.
    let items: [ItemID]

    init(
        id: PlaceID,
        arrival: String,
        revisit: String,
        overview: String,
        features: [Feature] = [],
        exits: [Exit] = [],
        items: [ItemID] = []
    ) {
        self.id = id
        self.arrival = arrival
        self.revisit = revisit
        self.overview = overview
        self.features = features
        self.exits = exits
        self.items = items
    }

    func feature(matching text: String) -> Feature? {
        features.first { $0.aliases.contains { text.matchesAlias($0) } }
    }

    func exit(matching text: String) -> Exit? {
        exits.first { $0.aliases.contains { text.matchesAlias($0) } }
    }
}

extension String {
    /// Accent- and case-insensitive containment, so "porta de ferro" matches "PORTA DE FERRO"
    /// and "abre a porta de ferro".
    func matchesAlias(_ alias: String) -> Bool {
        let me = folded
        let other = alias.folded
        return me.contains(other) || other.contains(me)
    }

    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
