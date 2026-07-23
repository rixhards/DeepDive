//
//  StateVariableTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class StateVariableTests: XCTestCase {
    private func loadFixtureStory() throws -> Story {
        let url = try XCTUnwrap(
            Bundle(for: StateVariableTests.self).url(forResource: "story-spec004-fixture", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Story.self, from: data)
    }

    // MARK: - initialState

    func testInitialStateSeedsEngineVariables() throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["sanity": 80],
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(
                        id: "opt_visible",
                        text: "opção visível",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "sanity", op: .gte, value: .int(60))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        let response = engine.start()
        XCTAssertEqual(response.options.map(\.id), ["opt_visible"])
    }

    func testMissingInitialStateDefaultsVariablesToZero() throws {
        let story = Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(
                        id: "opt_needs_positive",
                        text: "precisa de sanidade > 0",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "sanity", op: .gte, value: .int(1))]
                    ),
                    StoryOption(
                        id: "opt_default_zero",
                        text: "sanidade padrão é zero",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "sanity", op: .lte, value: .int(0))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        let response = engine.start()
        XCTAssertEqual(response.options.map(\.id), ["opt_default_zero"])
    }

    // MARK: - Effects

    func testDeltaEffectAccumulatesAndGatesOption() throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["trust": 40],
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_raise", text: "ganha confiança", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "trust", mode: .delta(20)),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_trusted",
                        text: "só aparece com confiança alta",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "trust", op: .gte, value: .int(60))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_raise")
        XCTAssertEqual(response.options.map(\.id), ["opt_trusted"])
    }

    func testSetEffectOverridesRegardlessOfPriorValue() throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["trust": 10],
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_set", text: "define confiança", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "trust", mode: .set(.int(70))),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_exact",
                        text: "confiança é exatamente 70",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "trust", op: .gte, value: .int(70))]
                    ),
                    StoryOption(
                        id: "opt_too_high",
                        text: "confiança não passou de 70",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "trust", op: .gte, value: .int(71))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_set")
        XCTAssertEqual(response.options.map(\.id), ["opt_exact"])
    }

    func testBooleanSetEffectStillWorks() throws {
        let story = Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_take_key", text: "pega a chave", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "found_key", mode: .set(.bool(true))),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_has_key",
                        text: "só aparece com a chave",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "found_key", op: .eq, value: .bool(true))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_take_key")
        XCTAssertEqual(response.options.map(\.id), ["opt_has_key"])
    }

    // MARK: - Clamping

    func testDeltaClampsToUpperBound() throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["sanity": 90],
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_boost", text: "ganha muita sanidade", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "sanity", mode: .delta(200)),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_capped",
                        text: "sanidade não passou de 100",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "sanity", op: .lte, value: .int(100))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_boost")
        XCTAssertEqual(response.options.map(\.id), ["opt_capped"])
    }

    func testDeltaClampsToLowerBound() throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["sanity": 10],
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_crash", text: "perde muita sanidade", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "sanity", mode: .delta(-200)),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_floor",
                        text: "sanidade não ficou negativa",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "sanity", op: .gte, value: .int(0))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_crash")
        XCTAssertEqual(response.options.map(\.id), ["opt_floor"])
    }

    // MARK: - Edge case: delta on a boolean variable

    func testDeltaOnBooleanVariableIsNoOp() throws {
        let story = Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi", options: [
                    StoryOption(id: "opt_take_key", text: "pega a chave", nextNodeID: "middle", effects: [
                        StoryEffect(variable: "found_key", mode: .set(.bool(true))),
                    ]),
                ]),
                StoryNode(id: "middle", characterText: "e agora", options: [
                    StoryOption(id: "opt_stray_delta", text: "efeito indevido", nextNodeID: "branch", effects: [
                        StoryEffect(variable: "found_key", mode: .delta(5)),
                    ]),
                ]),
                StoryNode(id: "branch", characterText: "e agora", options: [
                    StoryOption(
                        id: "opt_flag_preserved",
                        text: "a flag continua true",
                        nextNodeID: "end",
                        conditions: [StoryCondition(variable: "found_key", op: .eq, value: .bool(true))]
                    ),
                ]),
                StoryNode(id: "end", characterText: "fim", options: []),
            ]
        )
        let engine = try GameEngine(story: story)
        _ = engine.start()
        _ = try engine.advance(choosing: "opt_take_key")
        let response = try engine.advance(choosing: "opt_stray_delta")
        XCTAssertEqual(response.options.map(\.id), ["opt_flag_preserved"])
    }

    // MARK: - Fixture

    func testFixtureStoryDecodesAndBothConditionalBranchesAreReachable() throws {
        let story = try loadFixtureStory()

        let trustingEngine = try GameEngine(story: story)
        _ = trustingEngine.start()
        let trustingResponse = try trustingEngine.advance(choosing: "opt_trust")
        XCTAssertTrue(trustingResponse.options.contains { $0.id == "opt_high_trust" })

        let distrustingEngine = try GameEngine(story: story)
        _ = distrustingEngine.start()
        let distrustingResponse = try distrustingEngine.advance(choosing: "opt_distrust")
        XCTAssertTrue(distrustingResponse.options.contains { $0.id == "opt_low_sanity" })
    }
}
