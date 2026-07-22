//
//  GameEngineTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class GameEngineTests: XCTestCase {
    private func makeSampleStory() -> Story {
        Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi?", options: [
                    StoryOption(id: "opt_a", text: "quem é você?", nextNodeID: "middle"),
                ]),
                StoryNode(id: "middle", characterText: "não sei.", options: [
                    StoryOption(id: "opt_b", text: "continua", nextNodeID: "end"),
                ]),
                StoryNode(id: "end", characterText: "fim.", options: []),
            ]
        )
    }

    func testStartReturnsFirstNodeAndOptions() throws {
        let engine = try GameEngine(story: makeSampleStory())
        let response = engine.start()
        XCTAssertEqual(response.nodeID, "start")
        XCTAssertEqual(response.characterText, "oi?")
        XCTAssertEqual(response.options.map(\.id), ["opt_a"])
        XCTAssertFalse(response.isTerminal)
    }

    func testAdvanceMovesToNextNode() throws {
        let engine = try GameEngine(story: makeSampleStory())
        _ = engine.start()
        let response = try engine.advance(choosing: "opt_a")
        XCTAssertEqual(response.nodeID, "middle")
        XCTAssertEqual(response.characterText, "não sei.")
    }

    func testReachingNodeWithNoOptionsIsTerminal() throws {
        let engine = try GameEngine(story: makeSampleStory())
        _ = engine.start()
        _ = try engine.advance(choosing: "opt_a")
        let response = try engine.advance(choosing: "opt_b")
        XCTAssertEqual(response.nodeID, "end")
        XCTAssertTrue(response.isTerminal)
        XCTAssertTrue(response.options.isEmpty)
    }

    func testAdvanceWithUnknownOptionThrows() throws {
        let engine = try GameEngine(story: makeSampleStory())
        _ = engine.start()
        XCTAssertThrowsError(try engine.advance(choosing: "does_not_exist")) { error in
            XCTAssertEqual(error as? GameEngineError, .unknownOption("does_not_exist"))
        }
    }

    func testOptionPointingToUnknownNodeThrows() throws {
        let brokenStory = Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi?", options: [
                    StoryOption(id: "opt_broken", text: "vai", nextNodeID: "ghost_node"),
                ]),
            ]
        )
        let engine = try GameEngine(story: brokenStory)
        _ = engine.start()
        XCTAssertThrowsError(try engine.advance(choosing: "opt_broken")) { error in
            XCTAssertEqual(error as? GameEngineError, .unknownNode("ghost_node"))
        }
    }

    func testEngineInitThrowsWhenStartNodeMissing() {
        let invalidStory = Story(startNodeID: "missing", nodes: [])
        XCTAssertThrowsError(try GameEngine(story: invalidStory)) { error in
            XCTAssertEqual(error as? GameEngineError, .unknownNode("missing"))
        }
    }
}
