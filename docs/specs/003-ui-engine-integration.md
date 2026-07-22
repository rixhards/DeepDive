# Spec 003 — UI + Engine Integration

## Status
`implemented`

## Context

Spec 001 delivered a fully working chat UI driven by hardcoded mock data. Spec 002 delivered a deterministic `GameEngine` that reads `story.json` and returns `EngineResponse` DTOs — but it is completely headless (no UI). The mock data path and the real engine path are two parallel tracks that have never been connected.

This spec closes that gap: the `ChatViewModel` is rewired to use the `GameEngine` as its single source of narrative truth, making the app fully data-driven while keeping every view unchanged.

## Objective

Replace the mock-data wiring inside `ChatViewModel` with the real `GameEngine`, making the chat UI drive from `story.json` — with no changes to any SwiftUI views.

## Acceptance Criteria

- [x] `ChatViewModel` no longer references `ConversationNode`, `MockConversation`, or `ConversationOption`.
- [x] `ChatViewModel` is initialised with a `GameEngine` (dependency-injected), not created internally.
- [x] `ChatViewModel` starts in a `.loading` state and transitions to `.ready` or `.failed(Error)` after attempting to load the engine.
- [x] `ChatView` displays a simple `ErrorView` when the ViewModel is in the `.failed` state.
- [x] A `ChatOption` presentation type (with `id: String` and `text: String`) is introduced as the boundary type the View uses — no `EngineOption` or domain types leak into the view layer.
- [x] Tapping a `ChatOption` button calls `engine.advance(choosing: option.id)` internally via the ViewModel.
- [x] The typing delay (1–3 s) and typing indicator remain working as in Spec 001.
- [x] The conversation runs end-to-end from `story.json` — every node and branch reachable in the JSON is reachable in the UI.
- [x] `ConversationNode.swift` and `MockConversation.swift` are deleted (dead code removed).
- [x] No changes are made to `ChatView`, `MessageBubble`, `OptionButtonsView`, or `TypingIndicatorView`. — **partially**, see note below.
- [x] Integration tests in `DeepDiveTests` verify the ViewModel drives the engine correctly through a controlled fixture scenario.

> **Note on the "no changes" criterion:** this was impossible to satisfy literally alongside two
> other criteria in this same list — `ChatView` must render `ErrorView` on `.failed` (requires a
> body change), and `ChatOption` must replace the deleted `ConversationOption` as the type
> `OptionButtonsView` consumes (requires a one-line type-signature change). Both files' visuals
> and behavior are otherwise untouched; `MessageBubble.swift` and `TypingIndicatorView.swift` have
> zero diff.

## Expected Behavior

### ViewModel State Machine

```
init
  └─► .loading
         │
         ├─► .ready(engine)   ← story.json loaded OK
         │       │
         │       └─► conversation starts automatically (engine.start())
         │
         └─► .failed(Error)   ← story.json missing or corrupt
                 │
                 └─► ErrorView displayed in ChatView
```

### Main Flow (Happy Path)

1. `ChatViewModel` is created; state = `.loading`.
2. In an async task, `GameEngine(bundle: .main)` is initialised (loads `story.json`).
3. On success: state = `.ready`. `engine.start()` is called, returning the first `EngineResponse`.
4. ViewModel appends the character's first message and maps `EngineResponse.options → [ChatOption]`.
5. Player taps a `ChatOption` → ViewModel appends a player message, hides options, shows typing indicator.
6. After 1–3 s delay: `engine.advance(choosing: option.id)` returns the next `EngineResponse`.
7. ViewModel appends the character reply and updates `currentOptions`.
8. Repeat until `EngineResponse.isTerminal == true` → `isFinished = true`, no options shown.

### Error Path

1. `GameEngine` init throws (e.g. `story.json` missing in bundle).
2. State transitions to `.failed(error)`.
3. `ChatView` renders `ErrorView` with a non-technical message (in pt-BR).

## Edge Cases

- **Engine throws during `advance`:** treat as a terminal state — log the error, set `isFinished = true`, do not crash.
- **Rapid double-tap on option:** unchanged from Spec 001 — `isTyping` guard prevents double processing.
- **Backgrounding during delay:** unchanged — the `Task` is owned by the ViewModel and survives.
- **`story.json` with a valid start but unreachable nodes:** not a Spec 003 concern; caught by the engine's unit tests.

## Design / Wireframe

No visual changes. The UI is identical to Spec 001 — only the data source changes.

## Technical Notes

- **Dependency injection:** `ChatView` creates `ChatViewModel(engine: try GameEngine())` (or passes a pre-built instance). For testing, inject a `GameEngine` built from an in-memory fixture JSON.
- **ViewModel state enum:**
  ```swift
  enum ChatState {
      case loading
      case ready
      case failed(Error)
  }
  ```
- **`ChatOption`** lives in the Presentation layer (e.g. `Models/ChatOption.swift`), not in Domain.
- **Async loading:** use `Task { ... }` inside `start()` (same pattern as Spec 001's delivery task) to keep the loading off the main thread if needed.
- **`ConversationNode.swift` and `MockConversation.swift`** must be deleted from the Xcode project and the file system.
- **No new dependencies** — pure Swift and Apple frameworks only.
- **Integration test approach:** create a minimal `story.json` fixture (3–4 nodes) embedded as `Data` in the test bundle, build a `GameEngine` from it, wrap in `ChatViewModel`, and assert on `messages` and `currentOptions` after calling `start()` and `select()`.

## Dependencies

- **Spec 001** (Chat UI) — provides the views being wired.
- **Spec 002** (Game Engine) — provides `GameEngine`, `EngineResponse`, `EngineOption`.

Blocks: **Spec 004+** (State Variables — sanity, trust, flags evaluated at runtime).

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-22 | Antigravity | Initial creation from /grill-me session |
| 2026-07-22 | Claude Code | Wired `ChatViewModel` to `GameEngine` via an injected `engineProvider`; added `ChatOption`, `ErrorView`, `.loading`/`.ready`/`.failed` state machine; deleted `ConversationNode.swift`/`MockConversation.swift`; added integration tests; verified end-to-end in the simulator; status → `implemented` |
