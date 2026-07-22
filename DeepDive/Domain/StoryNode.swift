//
//  StoryNode.swift
//  DeepDive
//

import Foundation

struct StoryOption: Codable, Equatable {
    let id: String
    let text: String
    let nextNodeID: String
    let conditions: [StoryCondition]
    let effects: [StoryEffect]

    private enum CodingKeys: String, CodingKey {
        case id, text, nextNodeID, conditions, effects
    }

    init(id: String, text: String, nextNodeID: String, conditions: [StoryCondition] = [], effects: [StoryEffect] = []) {
        self.id = id
        self.text = text
        self.nextNodeID = nextNodeID
        self.conditions = conditions
        self.effects = effects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        nextNodeID = try container.decode(String.self, forKey: .nextNodeID)
        conditions = try container.decodeIfPresent([StoryCondition].self, forKey: .conditions) ?? []
        effects = try container.decodeIfPresent([StoryEffect].self, forKey: .effects) ?? []
    }
}

struct StoryNode: Codable, Equatable {
    let id: String
    let characterText: String
    let options: [StoryOption]

    private enum CodingKeys: String, CodingKey {
        case id, characterText, options
    }

    init(id: String, characterText: String, options: [StoryOption] = []) {
        self.id = id
        self.characterText = characterText
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        characterText = try container.decode(String.self, forKey: .characterText)
        options = try container.decodeIfPresent([StoryOption].self, forKey: .options) ?? []
    }
}
