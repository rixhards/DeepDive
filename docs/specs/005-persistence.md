# Spec 005 — Persistence

## Status
`implemented`

## Context

Specs 001–004 established a complete, stateful game loop running entirely in memory — but every time the player closes the app, the session is lost. DeepDive's narrative structure depends on accumulation: sanity erodes, trust builds, flags unlock paths. Losing that context mid-story breaks immersion and defeats the purpose of emergent endings.

This spec introduces session persistence using SwiftData. The player can close the app at any moment and return exactly where they left off, without any explicit save action — the same experience as reopening a WhatsApp conversation.

## Objective

Auto-save the full game session (engine state + message history) to SwiftData after every player choice, and restore it transparently on the next app launch — with no changes to the game engine or the chat views.

## Acceptance Criteria

- [x] The full session is saved to SwiftData after every call to `engine.advance()`.
- [x] The saved state includes: `currentNodeID`, `flags` (`[String: Bool]`), `ints` (`[String: Int]`), and the full `messages` array (`[ChatMessage]`).
- [x] On launch, if a saved session exists, the `ChatView` opens directly with the persisted message history and the engine restored at the correct node with correct state.
- [x] On launch with no saved session, the app starts a fresh conversation (existing behaviour unchanged).
- [x] When the engine reaches a terminal node (`isTerminal = true`), the save record is deleted automatically.
- [x] There is exactly one save slot — any new session overwrites the previous one (enforced at the data layer).
- [x] No changes are made to `StoryNode`, `StoryCondition`, `StoryEffect`, or any SwiftUI view. `GameEngine` gained two small **additive** members (`var state: EngineState` and `func restore(_:)`) — see note below.
- [x] The persistence layer is encapsulated in a `SessionRepository` (or equivalent) so the `ChatViewModel` calls a single `save(session:)` / `loadSession()` API without knowing about SwiftData internals.
- [x] Unit/integration tests verify: save → kill → restore round-trip preserves `currentNodeID`, state variables, and message count.

> **Note on "no changes to `GameEngine`":** capturing/restoring engine state for persistence is
> impossible without *some* new surface on `GameEngine`, since `flags`/`ints`/`currentNodeID` were
> all private. Added `var state: EngineState` (a read-only snapshot) and `func restore(_:) throws`
> (in-place state jump, validated against the node graph) — both additive, no existing
> signature changed, specs 002–004's behavior and tests untouched.
>
> **Note on "no changes to any SwiftUI view":** genuinely zero — `ChatView.swift` and
> `DeepDiveApp.swift` have no diff. `sessionRepository` defaults to `try? SessionRepository()`
> in `ChatViewModel.init`, so the existing no-argument `ChatViewModel()` call site in `ChatView`
> transparently gets full persistence with no call-site change required.

## Expected Behavior

### Launch Flow

```
App launches
    │
    ├─ save exists? ──YES──► restore engine at saved node
    │                         restore messages array
    │                         open ChatView mid-conversation
    │
    └─ NO ──────────────────► start fresh (existing behaviour)
```

### Auto-Save Flow (every choice)

```
Player taps option
    ├─ ViewModel appends player message
    ├─ engine.advance(choosing: optionID) → EngineResponse
    ├─ SessionRepository.save(session)      ← NEW
    ├─ ViewModel shows typing indicator
    ├─ [delay 1–3 s]
    ├─ ViewModel appends character message + new options
    └─ if isTerminal:
           SessionRepository.delete()       ← NEW
```

### Terminal / End-of-Game

When `isTerminal == true` after `advance()`:
1. Character's final message is appended.
2. Save record is deleted.
3. `isFinished = true` — no options shown (existing behaviour).
4. Next launch → fresh start.

## Edge Cases

- **App killed during typing delay (before character reply is shown):** The save was already written after the player's tap. On restore, the engine is at the new node but the character's reply has not been displayed yet — the `ChatViewModel` should detect this on restore and deliver the pending node response immediately (with no delay, or a short 0.5 s delay for UX continuity).
- **Save corrupted or schema migrated:** Treat as no save — delete the record and start fresh. Do not crash.
- **Very long message history (100+ messages):** SwiftData handles this; no artificial cap in this spec.
- **Multiple rapid taps (double-tap guard already exists):** The guard in `select()` means `advance()` is only called once; only one save is triggered per choice.

## Design / Wireframe

No new screens or visual elements. The restored `ChatView` is identical to a live conversation.

> **Note:** A future Menu spec (008+) will add a "Continue" button on a main menu screen. The Spec 005 persistence layer is what powers that button — but the menu itself is out of scope here.

## Technical Notes

- **SwiftData `@Model`:** Create a `SavedSession` model with properties for `currentNodeID: String`, `flagsData: Data` (JSON-encoded `[String: Bool]`), `intsData: Data` (JSON-encoded `[String: Int]`), and `messagesData: Data` (JSON-encoded `[ChatMessage]`). Using `Data` blobs avoids complex SwiftData relationships for dictionaries.
- **`ChatMessage` must be `Codable`:** Add `Codable` conformance to `ChatMessage` if not already present. `MessageSender` enum must also be `Codable`.
- **`SessionRepository`:** A struct/class that owns the SwiftData `ModelContext`, exposes `func save(_ session: GameSession) throws` and `func load() -> GameSession?` and `func delete() throws`. `GameSession` is a plain Swift struct (not `@Model`) used as the boundary type between the ViewModel and the repository.
- **Restoration in `ChatViewModel`:** In the `start()` async task, check `SessionRepository.load()` first. If a session is found, populate `messages` from it and reinitialise the `GameEngine` with a restored state (requires a new `GameEngine.init(story:restoredState:)` initialiser or a `restore(state:)` method).
- **Single slot enforcement:** `SessionRepository.save()` always upserts — fetch the existing record if any and update it, or insert a new one. Never accumulate multiple records.
- **No new external dependencies** — SwiftData and Foundation only.

## Dependencies

- **Spec 001** (Chat UI) — `ChatMessage`, `MessageSender`.
- **Spec 002** (Game Engine) — `GameEngine`, `Story`, state model.
- **Spec 003** (UI + Engine Integration) — `ChatViewModel` wiring.
- **Spec 004** (State Variables) — `flags` and `ints` must be persisted.

Blocks: **Spec 008+** (Menu — "Continue" button requires a saved session to exist).

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-23 | Antigravity | Initial creation from /grill-me session |
| 2026-07-23 | Claude Code | Status `draft` → `approved` (confirmed by Richard) → `implemented`. Added `SavedSession`/`SessionRepository`/`GameSession` (Data layer), `ChatMessage`/`MessageSender` `Codable` conformance, `GameEngine.state`/`restore(_:)`. Wired auto-save/restore into `ChatViewModel` with zero diff to any SwiftUI view. Fixed a real bug found along the way: `ChatMessage.id`'s inline `= UUID()` default meant Codable synthesis silently skipped decoding it. Added `SessionRepositoryTests.swift` + 3 round-trip tests in `ChatViewModelTests.swift` (34 tests total, all passing); verified no crash on a real simulator launch (full tap-driven kill/relaunch not possible — no UI automation tooling in this environment). |
