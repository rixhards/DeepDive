//
//  SessionRepository.swift
//  DeepDive
//
//  Single auto-saved slot in SwiftData. Also the bridge that makes the run reachable from
//  outside the UI: App Intents run in the app's process and read/write the same store, so
//  Siri/Shortcuts can talk to her without the app on screen.

import Foundation
import SwiftData

@Model
final class SavedGame {
    /// The whole `GameSession`, JSON-encoded. One blob keeps SwiftData migrations trivial:
    /// shape changes are handled by `schemaVersion`, not by the store's own schema.
    var payload = Data()
    /// Bumped whenever the persisted shape changes; a mismatch discards the save rather
    /// than resuming into a state that no longer matches it.
    var schemaVersion = SessionRepository.schemaVersion

    init(payload: Data, schemaVersion: Int = SessionRepository.schemaVersion) {
        self.payload = payload
        self.schemaVersion = schemaVersion
    }
}

nonisolated struct SessionRepository {
    /// Raise this when `GameState`/`StoryMemory` or the story changes enough that old saves
    /// are meaningless. v3: World → GameState + StoryMemory (the ARCHITECTURE.md refactor).
    static let schemaVersion = 3

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Convenience initializer that owns a private, on-disk SwiftData store.
    init() throws {
        let container = try ModelContainer(for: SavedGame.self)
        self.modelContext = ModelContext(container)
    }

    /// Upserts the single save slot — never accumulates multiple records.
    func save(_ session: GameSession) throws {
        let payload = try JSONEncoder().encode(session)

        if let record = try existingRecord() {
            record.payload = payload
            record.schemaVersion = Self.schemaVersion
        } else {
            modelContext.insert(SavedGame(payload: payload))
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
        guard let session = try? JSONDecoder().decode(GameSession.self, from: record.payload) else {
            try? delete()
            return nil
        }
        return session
    }

    func delete() throws {
        for record in try modelContext.fetch(FetchDescriptor<SavedGame>()) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    private func existingRecord() throws -> SavedGame? {
        try modelContext.fetch(FetchDescriptor<SavedGame>()).first
    }

    /// Whether there's a resumable run, for the menu's "continuar". Cheap enough to call on
    /// every menu appearance.
    static func savedRunExists() -> Bool {
        guard let repository = try? SessionRepository() else { return false }
        guard let session = repository.load() else { return false }
        return !session.state.isFinished
    }
}
