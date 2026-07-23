//
//  SessionRepository.swift
//  DeepDive
//

import Foundation
import SwiftData

@Model
final class SavedSession {
    var currentNodeID: String
    var flagsData: Data
    var intsData: Data
    var messagesData: Data

    init(currentNodeID: String, flagsData: Data, intsData: Data, messagesData: Data) {
        self.currentNodeID = currentNodeID
        self.flagsData = flagsData
        self.intsData = intsData
        self.messagesData = messagesData
    }
}

struct SessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Convenience initializer that owns a private, on-disk SwiftData store.
    init() throws {
        let container = try ModelContainer(for: SavedSession.self)
        self.modelContext = ModelContext(container)
    }

    /// Upserts the single save slot — never accumulates multiple records.
    func save(_ session: GameSession) throws {
        let flagsData = try JSONEncoder().encode(session.flags)
        let intsData = try JSONEncoder().encode(session.ints)
        let messagesData = try JSONEncoder().encode(session.messages)

        if let record = try existingRecord() {
            record.currentNodeID = session.currentNodeID
            record.flagsData = flagsData
            record.intsData = intsData
            record.messagesData = messagesData
        } else {
            modelContext.insert(SavedSession(
                currentNodeID: session.currentNodeID,
                flagsData: flagsData,
                intsData: intsData,
                messagesData: messagesData
            ))
        }
        try modelContext.save()
    }

    /// Returns `nil` if no save exists, or if the saved record is corrupted (and deletes it).
    func load() -> GameSession? {
        guard let record = try? existingRecord() else { return nil }
        guard
            let flags = try? JSONDecoder().decode([String: Bool].self, from: record.flagsData),
            let ints = try? JSONDecoder().decode([String: Int].self, from: record.intsData),
            let messages = try? JSONDecoder().decode([ChatMessage].self, from: record.messagesData)
        else {
            try? delete()
            return nil
        }
        return GameSession(currentNodeID: record.currentNodeID, flags: flags, ints: ints, messages: messages)
    }

    func delete() throws {
        for record in try modelContext.fetch(FetchDescriptor<SavedSession>()) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func existingRecord() throws -> SavedSession? {
        try modelContext.fetch(FetchDescriptor<SavedSession>()).first
    }
}
