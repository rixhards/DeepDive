//
//  ChatViewModelTests.swift
//  DeepDiveTests
//

import XCTest
@testable import DeepDive

@MainActor
final class ChatViewModelTests: XCTestCase {
    private func makeFixtureStory() -> Story {
        Story(
            startNodeID: "start",
            nodes: [
                StoryNode(id: "start", characterText: "oi, tem alguém aí?", options: [
                    StoryOption(id: "opt_hello", text: "oi", nextNodeID: "middle"),
                ]),
                StoryNode(id: "middle", characterText: "que bom que respondeu.", options: [
                    StoryOption(id: "opt_bye", text: "tchau", nextNodeID: "end"),
                ]),
                StoryNode(id: "end", characterText: "até mais.", options: []),
            ]
        )
    }

    private func makeViewModel() throws -> ChatViewModel {
        let engine = try GameEngine(story: makeFixtureStory())
        return ChatViewModel(engineProvider: { engine })
    }

    func testStartShowsTypingThenDeliversFirstMessage() async throws {
        let viewModel = try makeViewModel()

        viewModel.start()
        XCTAssertTrue(viewModel.isTyping)
        XCTAssertTrue(viewModel.messages.isEmpty)

        try await Task.sleep(for: .seconds(3.2))

        XCTAssertFalse(viewModel.isTyping)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.text, "oi, tem alguém aí?")
        XCTAssertEqual(viewModel.messages.first?.sender, .character)
        XCTAssertEqual(viewModel.currentOptions.map(\.id), ["opt_hello"])
    }

    func testSelectingOptionAppendsPlayerMessageAndAdvances() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: .seconds(3.2))

        viewModel.select(ChatOption(id: "opt_hello", text: "oi"))
        XCTAssertEqual(viewModel.messages.last?.text, "oi")
        XCTAssertEqual(viewModel.messages.last?.sender, .player)
        XCTAssertTrue(viewModel.isTyping)
        XCTAssertTrue(viewModel.currentOptions.isEmpty)

        try await Task.sleep(for: .seconds(3.2))

        XCTAssertFalse(viewModel.isTyping)
        XCTAssertEqual(viewModel.messages.last?.text, "que bom que respondeu.")
        XCTAssertEqual(viewModel.currentOptions.map(\.id), ["opt_bye"])
        XCTAssertFalse(viewModel.isFinished)
    }

    func testReachingTerminalNodeSetsIsFinished() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: .seconds(3.2))
        viewModel.select(ChatOption(id: "opt_hello", text: "oi"))
        try await Task.sleep(for: .seconds(3.2))
        viewModel.select(ChatOption(id: "opt_bye", text: "tchau"))
        try await Task.sleep(for: .seconds(3.2))

        XCTAssertTrue(viewModel.isFinished)
        XCTAssertTrue(viewModel.currentOptions.isEmpty)
        XCTAssertEqual(viewModel.messages.last?.text, "até mais.")
    }

    func testEngineLoadFailureSetsFailedState() {
        let viewModel = ChatViewModel(engineProvider: {
            throw StoryRepositoryError.missingFile
        })

        viewModel.start()

        guard case .failed = viewModel.state else {
            return XCTFail("Expected .failed state after a throwing engineProvider")
        }
    }

    func testRapidDoubleSelectIgnoresSecondTapWhileTyping() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: .seconds(3.2))

        viewModel.select(ChatOption(id: "opt_hello", text: "oi"))
        let messageCountAfterFirstTap = viewModel.messages.count
        viewModel.select(ChatOption(id: "opt_hello", text: "oi"))

        XCTAssertEqual(viewModel.messages.count, messageCountAfterFirstTap)
    }
}
