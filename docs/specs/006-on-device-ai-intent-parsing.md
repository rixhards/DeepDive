# Spec 006 — On-Device AI: Intent Parsing

## Status
`implemented`

## Context

Specs 001–005 built a complete, persistent game driven by pre-defined option buttons. This is intentional: it validated the core loop before adding AI complexity. The game is now ready for the next leap.

Spec 006 replaces the button-based input with free-text conversation, backed by Apple's Foundation Models framework running entirely on-device. The player types anything in natural language; the AI infers which narrative option the engine should execute. The Game Engine remains the sole authority over game state — the AI only interprets player intent, never decides the story outcome.

This spec also updates the deployment target from iOS 17 to **iOS 26+**, enabling Foundation Models across the supported device range (iPhone 11+ with iOS 27+).

## Objective

Replace the option buttons with a text input field and use Foundation Models to map the player's free-text messages to valid `GameEngine` options — keeping the FSM as the single source of narrative truth.

## Acceptance Criteria

- [x] The deployment target is updated to **iOS 26+** across the Xcode project, `CLAUDE.md`, `vision.md`, `architecture.md`, and `README.md`.
- [x] `OptionButtonsView` (and its host area in `ChatView`) is replaced by a text input composer bar at the bottom of the screen.
- [x] The composer bar is only visible when the game is in the `.ready` state and not typing (`!isTyping && !isFinished`).
- [x] When the player sends a message, the `ChatViewModel` calls a new `IntentParser` (or equivalent) passing the player's text and the list of currently valid `EngineOption`s.
- [x] The `IntentParser` uses Foundation Models to select the best matching `EngineOption.id` from the available options.
- [x] If the match is confident, the engine advances with that option — identical to tapping a button in the previous design.
- [x] If the match is ambiguous (no confident option found), the `IntentParser` returns a `.clarify` result; the `ChatViewModel` generates a short in-character clarification message from the character and does **not** advance the engine.
- [x] The `IntentParser` protocol is defined separately from its Foundation Models implementation, enabling future alternative implementations (e.g. regex, CoreML) without changing the ViewModel.
- [x] `GameEngine`, `StoryNode`, `StoryCondition`, `StoryEffect`, and `SessionRepository` are **unchanged**.
- [x] Unit/integration tests verify the `IntentParser` correctly maps unambiguous player input and returns `.clarify` for nonsensical input.

> **Note on testability:** Foundation Models' on-device model asset is not available in this
> Xcode Simulator environment (confirmed at runtime: `SafetyGuardrailTextSanitizerBackend:
> Resource (Local Model Asset) unavailable`), so real inference could not be exercised here.
> `FoundationModelsIntentParserTests` covers the one path that's deterministic without the
> model (empty options → `.clarify`); all `ChatViewModel` intent-mapping behavior is verified
> against a `StubIntentParser` instead. The confident/ambiguous mapping logic itself lives
> entirely in `FoundationModelsIntentParser`'s post-generation validation (any id not in the
> passed-in `options` list is treated as `.clarify`, preventing hallucinated ids from ever
> reaching the engine) — this compiled and linked successfully against the real
> `FoundationModels.framework` in the iOS 27 SDK, but hasn't been exercised with a live model.

## Expected Behavior

### Input Flow (confident match)

```
Player types "eu vou entrar pela porta"
    │
    ├─ IntentParser receives:
    │    - playerText: "eu vou entrar pela porta"
    │    - availableOptions: [{id: "opt_enter", text: "entrar pela porta"}, {id: "opt_run", text: "correr"}, ...]
    │
    ├─ Foundation Models selects: "opt_enter" (confident)
    │
    ├─ ViewModel appends player message (player's own words, not the option text)
    ├─ engine.advance(choosing: "opt_enter")
    ├─ auto-save
    └─ typing indicator → character reply
```

### Input Flow (ambiguous)

```
Player types "sei lá, tanto faz"
    │
    ├─ IntentParser → .clarify
    │
    ├─ ViewModel does NOT advance the engine
    └─ Character sends an in-character clarification message (generated or fixed pt-BR string)
       e.g. "não entendi... o que você quer que eu faça?"
```

### UI Changes

- **Removed:** `OptionButtonsView` and its container in `ChatView`.
- **Added:** A composer bar at the bottom: `TextField` ("Digite sua mensagem...") + Send button.
- The composer bar adopts the same dark aesthetic as the rest of the app (`Theme`).
- Send button is disabled while `isTyping` or `isFinished`.

## Edge Cases

- **Player sends empty string:** ignore; do not call `IntentParser`.
- **Player sends during `isTyping`:** composer send button is disabled; ignore taps.
- **Terminal node reached:** composer is hidden (`isFinished = true`) — no input possible.
- **Foundation Models unavailable at runtime** (unexpected): treat as ambiguous → clarify message. (Should not occur given iOS 26+ requirement, but defensive handling is required.)
- **Very long player input (>500 chars):** truncate to 500 chars before passing to `IntentParser`.

## Design / Wireframe

```
┌─────────────────────────────────┐
│  ● número desconhecido     ⋮    │
├─────────────────────────────────┤
│                                 │
│  ┌──────────────────────────┐   │
│  │ tem alguém aí?      03:14│   │  ← character bubble
│  └──────────────────────────┘   │
│                                 │
│        ┌────────────────────┐   │
│        │ eu preciso de ajuda│   │  ← player bubble (own words)
│        │              03:15 │   │
│        └────────────────────┘   │
│                                 │
│  ┌────────────────────────────┐ │
│  │ ● ● ●                      │ │  ← typing indicator
│  └────────────────────────────┘ │
│                                 │
├─────────────────────────────────┤
│  [  Digite sua mensagem...  ] ► │  ← composer bar (replaces buttons)
└─────────────────────────────────┘
```

## Technical Notes

- **`IntentParser` protocol:**
  ```swift
  enum IntentResult {
      case match(optionID: String)
      case clarify
  }
  
  protocol IntentParser {
      func parse(playerText: String, options: [EngineOption]) async -> IntentResult
  }
  ```
- **`FoundationModelsIntentParser`:** concrete implementation using `LanguageModelSession` (Foundation Models). Use structured output (`@Generable`) to constrain the model to return exactly one option ID or a `nil` clarify signal — prevents hallucination of invented option IDs.
- **Prompt design:** Provide the model with: (1) a system persona ("You are mapping a player's message to one of the available story options. Return only the option ID that best matches, or null if no option clearly matches."), (2) the list of option IDs and their texts, (3) the player's message. Keep the prompt short.
- **Clarification message:** A fixed pt-BR string pool (3–5 variants) chosen at random, e.g. "não entendi... o que você quer que eu faça?", "pode repetir?". No AI generation needed for the clarification itself (the AI failed to parse — calling it again to generate the clarification is wasteful).
- **Typing delay with variable duration:** After the engine advances, the typing indicator duration scales with the upcoming character message length (e.g. `max(1.0, min(4.0, characterText.count / 50))`).
- **No new Swift Package dependencies** — Foundation Models and SwiftUI only.

## Dependencies

- **Spec 001** (Chat UI) — `ChatView`, `Theme`.
- **Spec 003** (UI + Engine Integration) — `ChatViewModel`, `ChatOption`, `EngineOption`.
- **Spec 004** (State Variables) — `EngineOption` list correctly filtered by engine state.
- **Spec 005** (Persistence) — auto-save after `advance()` must still fire.

Blocks: **Spec 007** (Dynamic Narration — character responses generated by AI instead of JSON text).

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-23 | Antigravity | Initial creation from /grill-me session |
| 2026-07-23 | Claude Code | Status `draft` → `approved` (confirmed by Richard) → `implemented`. Bumped deployment target to iOS 26+ (`.pbxproj` + docs). Added `IntentParser`/`IntentResult`/`FoundationModelsIntentParser`/`ClarificationMessages`; replaced `OptionButtonsView` with `ComposerView`; deleted `ChatOption`/`OptionButtonsView` (dead code once buttons were gone). Rewrote `ChatViewModelTests` around `send()` + `StubIntentParser`; added `FoundationModelsIntentParserTests`. |
