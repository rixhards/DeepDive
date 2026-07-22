//
//  StoryDecodingTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

final class StoryDecodingTests: XCTestCase {
    func testBundledStoryDecodesSuccessfully() throws {
        let story = try StoryRepository(bundle: .main).load()
        XCTAssertFalse(story.nodes.isEmpty)
        XCTAssertTrue(story.nodes.contains { $0.id == story.startNodeID })
    }

    func testMissingConditionsAndEffectsDefaultToEmpty() throws {
        let json = """
        {
            "id": "opt_1",
            "text": "olá",
            "nextNodeID": "node_2"
        }
        """.data(using: .utf8)!
        let option = try JSONDecoder().decode(StoryOption.self, from: json)
        XCTAssertEqual(option.conditions, [])
        XCTAssertEqual(option.effects, [])
    }

    func testMissingOptionsDefaultsToEmptyArray() throws {
        let json = """
        {
            "id": "node_end",
            "characterText": "fim."
        }
        """.data(using: .utf8)!
        let node = try JSONDecoder().decode(StoryNode.self, from: json)
        XCTAssertEqual(node.options, [])
    }

    func testMissingStoryFileThrows() {
        let testBundle = Bundle(for: StoryDecodingTests.self)
        XCTAssertThrowsError(try StoryRepository(bundle: testBundle).load()) { error in
            XCTAssertEqual(error as? StoryRepositoryError, .missingFile)
        }
    }
}
