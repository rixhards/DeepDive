//
//  GameEngine.swift
//  DeepDive
//
//  Deterministic FSM over a Story node graph. Owns no UI/timing concerns —
//  ChatViewModel wires this in via spec 003.

import Foundation

enum GameEngineError: Error, Equatable {
    case unknownNode(String)
    case unknownOption(String)
}

final class GameEngine {
    private let nodesByID: [String: StoryNode]
    private var flags: [String: Bool] = [:]
    private(set) var currentNodeID: String

    init(story: Story) throws {
        nodesByID = Dictionary(uniqueKeysWithValues: story.nodes.map { ($0.id, $0) })
        guard nodesByID[story.startNodeID] != nil else {
            throw GameEngineError.unknownNode(story.startNodeID)
        }
        currentNodeID = story.startNodeID
    }

    convenience init(bundle: Bundle = .main) throws {
        let story = try StoryRepository(bundle: bundle).load()
        try self.init(story: story)
    }

    func start() -> EngineResponse {
        response(for: currentNodeID)
    }

    @discardableResult
    func advance(choosing optionID: String) throws -> EngineResponse {
        guard let node = nodesByID[currentNodeID] else {
            throw GameEngineError.unknownNode(currentNodeID)
        }
        guard let option = node.options.first(where: { $0.id == optionID }) else {
            throw GameEngineError.unknownOption(optionID)
        }
        guard nodesByID[option.nextNodeID] != nil else {
            throw GameEngineError.unknownNode(option.nextNodeID)
        }
        apply(option.effects)
        currentNodeID = option.nextNodeID
        return response(for: currentNodeID)
    }

    private func response(for nodeID: String) -> EngineResponse {
        let node = nodesByID[nodeID]
        let availableOptions = (node?.options ?? []).filter(conditionsMet)
        return EngineResponse(
            nodeID: nodeID,
            characterText: node?.characterText ?? "",
            options: availableOptions.map { EngineOption(id: $0.id, text: $0.text) },
            isTerminal: availableOptions.isEmpty
        )
    }

    private func conditionsMet(_ option: StoryOption) -> Bool {
        option.conditions.allSatisfy { flags[$0.flag] == $0.equals }
    }

    private func apply(_ effects: [StoryEffect]) {
        for effect in effects {
            flags[effect.flag] = effect.value
        }
    }
}
