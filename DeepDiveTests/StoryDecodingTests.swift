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

    func testBundledStoryHasNoUnreachableNodesOrDanglingLinks() throws {
        let story = try StoryRepository(bundle: .main).load()
        let nodesByID = Dictionary(uniqueKeysWithValues: story.nodes.map { ($0.id, $0) })

        var reachable: Set<String> = []
        var queue = [story.startNodeID]
        while let nodeID = queue.popLast() {
            guard !reachable.contains(nodeID) else { continue }
            reachable.insert(nodeID)
            guard let node = nodesByID[nodeID] else {
                XCTFail("Option points to unknown node id: \(nodeID)")
                continue
            }
            queue.append(contentsOf: node.options.map(\.nextNodeID))
        }

        let allNodeIDs = Set(nodesByID.keys)
        XCTAssertEqual(reachable, allNodeIDs, "Every node in story.json must be reachable from the start node")
    }

    func testMissingStoryFileThrows() {
        let testBundle = Bundle(for: StoryDecodingTests.self)
        XCTAssertThrowsError(try StoryRepository(bundle: testBundle).load()) { error in
            XCTAssertEqual(error as? StoryRepositoryError, .missingFile)
        }
    }
}
