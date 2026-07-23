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
    private var ints: [String: Int] = [:]
    private(set) var currentNodeID: String

    init(story: Story) throws {
        nodesByID = Dictionary(uniqueKeysWithValues: story.nodes.map { ($0.id, $0) })
        guard nodesByID[story.startNodeID] != nil else {
            throw GameEngineError.unknownNode(story.startNodeID)
        }
        currentNodeID = story.startNodeID
        ints = story.initialState ?? [:]
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
        option.conditions.allSatisfy(evaluate)
    }

    private func evaluate(_ condition: StoryCondition) -> Bool {
        switch condition.value {
        case .bool(let expected):
            return (flags[condition.variable] ?? false) == expected
        case .int(let expected):
            let current = ints[condition.variable] ?? 0
            switch condition.op {
            case .eq: return current == expected
            case .gte: return current >= expected
            case .lte: return current <= expected
            }
        }
    }

    private func apply(_ effects: [StoryEffect]) {
        for effect in effects {
            switch effect.mode {
            case .delta(let amount):
                guard flags[effect.variable] == nil else {
                    print("GameEngine warning: ignoring delta effect on boolean variable '\(effect.variable)'")
                    continue
                }
                let current = ints[effect.variable] ?? 0
                ints[effect.variable] = clamp(current + amount)
            case .set(.bool(let value)):
                flags[effect.variable] = value
            case .set(.int(let value)):
                ints[effect.variable] = clamp(value)
            }
        }
    }

    private func clamp(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
