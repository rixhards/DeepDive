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
    /// Extra messages after `arrival`, so a first impression lands in pieces instead of as
    /// one paragraph of exposition.
    let arrivalBeats: [String]
    /// One line summarising what's around, used when she's asked to look around.
    let overview: String
    /// What she hears when she stops to listen.
    let sound: String
    /// What the place smells like.
    let smell: String
    let features: [Feature]
    let exits: [Exit]
    /// Items lying here to be found, and what she says on picking each one up.
    let items: [ItemID]

    init(
        id: PlaceID,
        arrival: String,
        arrivalBeats: [String] = [],
        revisit: String,
        sound: String = "eu parei e escutei. só pinga água em algum lugar, e o resto é um silêncio que não parece natural.",
        smell: String = "cheiro de pedra molhada e mofo. e alguma coisa embaixo disso que eu não consigo nomear.",
        overview: String,
        features: [Feature] = [],
        exits: [Exit] = [],
        items: [ItemID] = []
    ) {
        self.id = id
        self.arrival = arrival
        self.arrivalBeats = arrivalBeats
        self.revisit = revisit
        self.overview = overview
        self.sound = sound
        self.smell = smell
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
    /// Whole-word alias matching. Deliberately *not* plain containment in either direction:
    /// that made a one-letter target match half the exits in the room, which is how she
    /// started walking off on her own.
    ///
    /// One side's significant words must all appear on the other side, so "ferro" matches
    /// "porta de ferro" while "porta de ferro" never matches "porta de madeira".
    func matchesAlias(_ alias: String) -> Bool {
        let mine = Self.significantWords(folded)
        let theirs = Self.significantWords(alias.folded)
        guard !mine.isEmpty, !theirs.isEmpty else { return false }

        let (smaller, larger) = mine.count <= theirs.count ? (mine, theirs) : (theirs, mine)
        return smaller.allSatisfy { word in
            larger.contains { Self.wordsMatch(word, $0) }
        }
    }

    private static func significantWords(_ text: String) -> [String] {
        // Articles and prepositions carry no meaning for matching and would let a stray "de"
        // satisfy an alias on its own.
        let noise: Set<String> = ["o", "a", "os", "as", "um", "uma", "de", "do", "da", "dos",
                                  "das", "no", "na", "em", "pra", "para", "pro", "ao", "e"]
        return text
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !noise.contains($0) }
    }

    /// Equal, or one is a prefix of the other — so "escada" matches "escadas" without a stemmer.
    private static func wordsMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard Swift.min(a.count, b.count) >= 4 else { return false }
        return a.hasPrefix(b) || b.hasPrefix(a)
    }

    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
