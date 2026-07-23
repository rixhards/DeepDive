//
//  SessionRepositoryTests.swift
//  DeepDiveTests
//

import XCTest
import SwiftData
@testable import DeepDive

final class SessionRepositoryTests: XCTestCase {
    private func makeInMemoryRepository() throws -> SessionRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SavedSession.self, configurations: config)
        return SessionRepository(modelContext: ModelContext(container))
    }

    private func makeSession(nodeID: String = "middle") -> GameSession {
        GameSession(
            currentNodeID: nodeID,
            flags: ["found_key": true],
            ints: ["sanity": 70, "trust": 55],
            messages: [
                ChatMessage(text: "oi, tem alguém aí?", sender: .character, timestamp: .now),
                ChatMessage(text: "oi", sender: .player, timestamp: .now),
            ]
        )
    }

    func testLoadWithNoSavedSessionReturnsNil() throws {
        let repository = try makeInMemoryRepository()
        XCTAssertNil(repository.load())
    }

    func testSaveThenLoadRoundTripsAllFields() throws {
        let repository = try makeInMemoryRepository()
        let session = makeSession()

        try repository.save(session)
        let loaded = try XCTUnwrap(repository.load())

        XCTAssertEqual(loaded, session)
    }

    func testSavingTwiceOverwritesTheSingleSlot() throws {
        let repository = try makeInMemoryRepository()
        try repository.save(makeSession(nodeID: "middle"))
        try repository.save(makeSession(nodeID: "end"))

        let loaded = try XCTUnwrap(repository.load())
        XCTAssertEqual(loaded.currentNodeID, "end")
    }

    func testDeleteRemovesTheSavedSession() throws {
        let repository = try makeInMemoryRepository()
        try repository.save(makeSession())
        try repository.delete()

        XCTAssertNil(repository.load())
    }

    func testCorruptedRecordIsTreatedAsNoSaveAndDeleted() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SavedSession.self, configurations: config)
        let modelContext = ModelContext(container)
        let repository = SessionRepository(modelContext: modelContext)

        let corrupted = SavedSession(
            currentNodeID: "middle",
            flagsData: Data("not json".utf8),
            intsData: Data("not json".utf8),
            messagesData: Data("not json".utf8)
        )
        modelContext.insert(corrupted)
        try modelContext.save()

        XCTAssertNil(repository.load())
        XCTAssertNil(repository.load(), "record should have been deleted, not just skipped")
    }
}
