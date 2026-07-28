//
//  SessionRepository.swift
//  DeepDive
//

import Foundation
import SwiftData

@Model
final class SavedSession {
    var worldData: Data
    var messagesData: Data
    /// Bumped whenever the persisted shape changes; a mismatch discards the save rather than
    /// resuming into a world that no longer matches it.
    var schemaVersion: Int

    init(worldData: Data, messagesData: Data, schemaVersion: Int = SessionRepository.schemaVersion) {
        self.worldData = worldData
        self.messagesData = messagesData
        self.schemaVersion = schemaVersion
    }
}

struct SessionRepository {
    /// Raise this when `World` or the story changes enough that old saves are meaningless.
    static let schemaVersion = 2

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
        let worldData = try JSONEncoder().encode(session.world)
        let messagesData = try JSONEncoder().encode(session.messages)

        if let record = try existingRecord() {
            record.worldData = worldData
            record.messagesData = messagesData
            record.schemaVersion = Self.schemaVersion
        } else {
            modelContext.insert(SavedSession(worldData: worldData, messagesData: messagesData))
        }
        try modelContext.save()
    }

    /// Returns `nil` when there's no save, the save is from an older schema, or it's corrupt
    /// (deleting it in the latter two cases).
    func load() -> GameSession? {
        guard let record = try? existingRecord() else { return nil }
        guard record.schemaVersion == Self.schemaVersion else {
            try? delete()
            return nil
        }
        guard
            let world = try? JSONDecoder().decode(World.self, from: record.worldData),
            let messages = try? JSONDecoder().decode([ChatMessage].self, from: record.messagesData)
        else {
            try? delete()
            return nil
        }
        return GameSession(world: world, messages: messages)
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
