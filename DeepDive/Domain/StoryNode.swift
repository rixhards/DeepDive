//
//  StoryNode.swift
//  DeepDive
//

import Foundation

struct StoryOption: Codable, Equatable {
    let id: String
    let text: String
    let nextNodeID: String
    /// Alternate phrasings of `text`, authored to widen free-text intent matching.
    /// Never shown in the UI — matching only.
    let hints: [String]
    let conditions: [StoryCondition]
    let effects: [StoryEffect]

    private enum CodingKeys: String, CodingKey {
        case id, text, nextNodeID, hints, conditions, effects
    }

    init(
        id: String,
        text: String,
        nextNodeID: String,
        hints: [String] = [],
        conditions: [StoryCondition] = [],
        effects: [StoryEffect] = []
    ) {
        self.id = id
        self.text = text
        self.nextNodeID = nextNodeID
        self.hints = hints
        self.conditions = conditions
        self.effects = effects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        nextNodeID = try container.decode(String.self, forKey: .nextNodeID)
        hints = try container.decodeIfPresent([String].self, forKey: .hints) ?? []
        conditions = try container.decodeIfPresent([StoryCondition].self, forKey: .conditions) ?? []
        effects = try container.decodeIfPresent([StoryEffect].self, forKey: .effects) ?? []
    }
}

struct StoryNode: Codable, Equatable {
    let id: String
    let characterText: String
    let options: [StoryOption]
    /// Deliver `characterText` as authored, bypassing the `Narrator`. Set on endings whose
    /// text is deliberately malformed — narration would rewrite it into clean prose.
    let rawNarration: Bool
    /// Player messages this node absorbs, unanswered, before the game ends.
    let silentTurns: Int

    private enum CodingKeys: String, CodingKey {
        case id, characterText, options, rawNarration, silentTurns
    }

    init(
        id: String,
        characterText: String,
        options: [StoryOption] = [],
        rawNarration: Bool = false,
        silentTurns: Int = 0
    ) {
        self.id = id
        self.characterText = characterText
        self.options = options
        self.rawNarration = rawNarration
        self.silentTurns = silentTurns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        characterText = try container.decode(String.self, forKey: .characterText)
        options = try container.decodeIfPresent([StoryOption].self, forKey: .options) ?? []
        rawNarration = try container.decodeIfPresent(Bool.self, forKey: .rawNarration) ?? false
        silentTurns = try container.decodeIfPresent(Int.self, forKey: .silentTurns) ?? 0
    }
}
