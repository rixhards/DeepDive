//
//  ChatViewModelTests.swift
//  DeepDiveTests
//

import XCTest
import SwiftData
@testable import DeepDive

@MainActor
final class ChatViewModelTests: XCTestCase {
    /// Short story texts here all fall under the typing-delay formula's 1.5 s floor —
    /// keep waits comfortably above that rather than the old random(1...3) upper bound.
    private static let typingWait: Duration = .seconds(1.8)

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

    private func makeViewModel(intentParser: IntentParser = StubIntentParser.matchesFirstOption) throws -> ChatViewModel {
        let engine = try GameEngine(story: makeFixtureStory())
        return ChatViewModel(
            engineProvider: { engine },
            sessionRepository: nil,
            intentParser: intentParser,
            narrator: StaticNarrator()
        )
    }

    func testStartShowsTypingThenDeliversFirstMessage() async throws {
        let viewModel = try makeViewModel()

        viewModel.start()
        XCTAssertTrue(viewModel.isTyping)
        XCTAssertTrue(viewModel.messages.isEmpty)

        try await Task.sleep(for: Self.typingWait)

        XCTAssertFalse(viewModel.isTyping)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.text, "oi, tem alguém aí?")
        XCTAssertEqual(viewModel.messages.first?.sender, .character)
    }

    func testSendingMessageAppendsPlayerOwnWordsAndAdvances() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        viewModel.send("oi, quem é você?")
        XCTAssertEqual(viewModel.messages.last?.text, "oi, quem é você?")
        XCTAssertEqual(viewModel.messages.last?.sender, .player)
        XCTAssertTrue(viewModel.isTyping)

        try await Task.sleep(for: Self.typingWait)

        XCTAssertFalse(viewModel.isTyping)
        XCTAssertEqual(viewModel.messages.last?.text, "que bom que respondeu.")
        XCTAssertFalse(viewModel.isFinished)
    }

    func testAmbiguousInputDoesNotAdvanceAndSendsClarification() async throws {
        let viewModel = try makeViewModel(intentParser: StubIntentParser.alwaysClarifies)
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        viewModel.send("sei lá, tanto faz")
        try await Task.sleep(for: Self.typingWait)

        XCTAssertFalse(viewModel.isTyping)
        XCTAssertEqual(viewModel.messages.count, 3) // start + player + clarification
        XCTAssertEqual(viewModel.messages.last?.sender, .character)
        XCTAssertNotEqual(viewModel.messages.last?.text, "que bom que respondeu.")
        XCTAssertFalse(viewModel.isFinished)
    }

    func testEmptyOrWhitespaceInputIsIgnored() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        let countBefore = viewModel.messages.count
        viewModel.send("")
        viewModel.send("   \n  ")

        XCTAssertEqual(viewModel.messages.count, countBefore)
        XCTAssertFalse(viewModel.isTyping)
    }

    func testLongInputIsTruncatedToFiveHundredCharacters() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        viewModel.send(String(repeating: "a", count: 900))

        XCTAssertEqual(viewModel.messages.last?.text.count, 500)
    }

    func testReachingTerminalNodeSetsIsFinished() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)
        viewModel.send("oi")
        try await Task.sleep(for: Self.typingWait)
        viewModel.send("tchau")
        try await Task.sleep(for: Self.typingWait)

        XCTAssertTrue(viewModel.isFinished)
        XCTAssertEqual(viewModel.messages.last?.text, "até mais.")
    }

    func testEngineLoadFailureSetsFailedState() {
        let viewModel = ChatViewModel(
            engineProvider: { throw StoryRepositoryError.missingFile },
            sessionRepository: nil,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: StaticNarrator()
        )

        viewModel.start()

        guard case .failed = viewModel.state else {
            return XCTFail("Expected .failed state after a throwing engineProvider")
        }
    }

    func testRapidDoubleSendIgnoresSecondMessageWhileTyping() async throws {
        let viewModel = try makeViewModel()
        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        viewModel.send("oi")
        let messageCountAfterFirstSend = viewModel.messages.count
        viewModel.send("oi de novo")

        XCTAssertEqual(viewModel.messages.count, messageCountAfterFirstSend)
    }

    // MARK: - Narration (spec 007)

    func testCharacterMessageUsesNarratorOutputNotRawBrief() async throws {
        let narrator = StubNarrator { brief, _, _, _ in "[narrado] \(brief)" }
        let engine = try GameEngine(story: makeFixtureStory())
        let viewModel = ChatViewModel(
            engineProvider: { engine },
            sessionRepository: nil,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: narrator
        )

        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        XCTAssertEqual(viewModel.messages.first?.text, "[narrado] oi, tem alguém aí?")
    }

    func testNarratorReceivesCurrentSanityAndTrust() async throws {
        let story = Story(
            startNodeID: "start",
            initialState: ["sanity": 42, "trust": 77],
            nodes: [StoryNode(id: "start", characterText: "oi", options: [])]
        )
        let engine = try GameEngine(story: story)
        var capturedSanity: Int?
        var capturedTrust: Int?
        let narrator = StubNarrator { brief, sanity, trust, _ in
            capturedSanity = sanity
            capturedTrust = trust
            return brief
        }
        let viewModel = ChatViewModel(
            engineProvider: { engine },
            sessionRepository: nil,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: narrator
        )

        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        XCTAssertEqual(capturedSanity, 42)
        XCTAssertEqual(capturedTrust, 77)
    }

    // MARK: - Persistence round-trip (spec 005)

    private func makeInMemorySessionRepository() throws -> SessionRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SavedSession.self, configurations: config)
        return SessionRepository(modelContext: ModelContext(container))
    }

    func testSaveKillRestoreRoundTripPreservesNodeAndMessages() async throws {
        let story = makeFixtureStory()
        let repository = try makeInMemorySessionRepository()

        let firstEngine = try GameEngine(story: story)
        let firstViewModel = ChatViewModel(
            engineProvider: { firstEngine },
            sessionRepository: repository,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: StaticNarrator()
        )
        firstViewModel.start()
        try await Task.sleep(for: Self.typingWait)
        firstViewModel.send("oi")
        // "Killed" here — right after advance()/save(), before the "middle" node's
        // character reply would have been delivered.
        try await Task.sleep(for: .seconds(0.1))

        // Simulate relaunch: a fresh engine and a fresh view model, same backing store.
        let secondEngine = try GameEngine(story: story)
        let secondViewModel = ChatViewModel(
            engineProvider: { secondEngine },
            sessionRepository: repository,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: StaticNarrator()
        )
        secondViewModel.start()

        XCTAssertEqual(secondViewModel.messages.count, 2)
        XCTAssertEqual(secondViewModel.messages.last?.sender, .player)

        try await Task.sleep(for: .seconds(0.8))

        XCTAssertEqual(secondViewModel.messages.count, 3)
        XCTAssertEqual(secondViewModel.messages.last?.text, "que bom que respondeu.")
        XCTAssertFalse(secondViewModel.isFinished)
    }

    func testNoSavedSessionStartsFreshConversation() async throws {
        let repository = try makeInMemorySessionRepository()
        let engine = try GameEngine(story: makeFixtureStory())
        let viewModel = ChatViewModel(
            engineProvider: { engine },
            sessionRepository: repository,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: StaticNarrator()
        )

        viewModel.start()
        try await Task.sleep(for: Self.typingWait)

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.text, "oi, tem alguém aí?")
    }

    func testAmbiguousSendStillSavesTheSession() async throws {
        let story = makeFixtureStory()
        let repository = try makeInMemorySessionRepository()
        let engine = try GameEngine(story: story)
        let viewModel = ChatViewModel(
            engineProvider: { engine },
            sessionRepository: repository,
            intentParser: StubIntentParser.alwaysClarifies,
            narrator: StaticNarrator()
        )

        viewModel.start()
        try await Task.sleep(for: Self.typingWait)
        viewModel.send("sei lá, tanto faz")
        try await Task.sleep(for: .seconds(0.1))

        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.currentNodeID, "start")
        XCTAssertEqual(saved.messages.count, 2) // character start + player's ambiguous message
        XCTAssertEqual(saved.messages.last?.text, "sei lá, tanto faz")
    }

    func testTerminalNodeDeletesTheSavedSession() async throws {
        let story = makeFixtureStory()
        let repository = try makeInMemorySessionRepository()
        let engine = try GameEngine(story: story)
        let viewModel = ChatViewModel(
            engineProvider: { engine },
            sessionRepository: repository,
            intentParser: StubIntentParser.matchesFirstOption,
            narrator: StaticNarrator()
        )

        viewModel.start()
        try await Task.sleep(for: Self.typingWait)
        viewModel.send("oi")
        try await Task.sleep(for: Self.typingWait)
        viewModel.send("tchau")
        try await Task.sleep(for: Self.typingWait)

        XCTAssertTrue(viewModel.isFinished)
        XCTAssertNil(repository.load(), "save record should be deleted once the conversation ends")
    }
}
