# Spec 007 — Dynamic Narration

## Status
`implemented` — partially superseded by [Spec 008](008-sanity-rework.md)

> **Superseded parts.** The `trust` parameter was dropped from the `Narrator` protocol in spec
> 008; the signature is now `narrate(brief:sanity:history:)` and tone is shaped by sanity alone.
> Spec 008 also added a `rawNarration` opt-out: nodes flagged with it bypass this narrator
> entirely, so deliberately malformed ending text isn't rewritten into clean prose.

## Context

Spec 006 gave the player a natural-language voice. Spec 007 gives the character one too.

Today, the character's messages are the exact text strings stored in `story.json`. They are necessarily generic — written once by the author, read identically in every playthrough. A player who has run the same node twice will see the same sentence.

This spec activates the second half of the AI layer: Foundation Models rewrites the character's raw JSON text into a human, WhatsApp-style message on every delivery — varying phrasing, adapting emotional register to the current sanity and trust levels, and never sounding scripted. The JSON text becomes a **narrative brief** (what to communicate) rather than the final output.

The Game Engine and its node graph remain completely unchanged. The AI narrates; the engine decides.

## Objective

Use Foundation Models to dynamically rewrite each character message at delivery time, adapting tone and wording to the current game state (sanity, trust) — while communicating exactly the narrative intent encoded in the node's JSON text.

## Acceptance Criteria

- [x] A `NarratorService` (or equivalent) is introduced in the Domain layer, implementing a `Narrator` protocol. — implemented as `FoundationModelsNarrator`.
- [x] When the `ChatViewModel` is about to display a character message, it calls `NarratorService.narrate(brief:gameState:history:)` instead of using the raw `EngineResponse.characterText` directly. — `narrate(brief:sanity:trust:history:)`, called from `deliver(_:delayOverride:)`.
- [x] The `NarratorService` passes to Foundation Models: the node's raw text (the brief), the current sanity and trust values, and the full message history. — history capped to the last 20 messages in the prompt (full history kept in `messages`; unbounded growth in the prompt itself isn't useful past that).
- [x] The model generates a response that communicates the same information as the brief, but in natural WhatsApp pt-BR prose, with emotional register matching the sanity/trust state.
- [x] Sanity-driven tone: high sanity → coherent, descriptive messages; low sanity → fragmented, erratic, fearful.
- [x] Trust-driven tone: high trust → personal, vulnerable, relies on the player; low trust → guarded, terse, doubting.
- [x] The generated text is never longer than ~3 short WhatsApp-style messages worth of content (avoid walls of text). — prompt instructs 1–3 messages, output hard-truncated to 300 chars regardless.
- [x] The typing indicator duration scales proportionally to the length of the generated text.
- [x] `GameEngine`, `StoryNode`, `story.json`, `SessionRepository`, and `IntentParser` are **unchanged**.
- [x] If narration fails (Foundation Models error), fall back to the raw `EngineResponse.characterText` silently.
- [x] Unit tests verify that the `Narrator` protocol has a `StaticNarrator` stub that returns the brief unchanged (used in all existing tests).

> **Note on testability:** same constraint as Spec 006 — no on-device model asset in this
> Simulator environment, so tone/register quality is unverified here. `FoundationModelsNarrator`
> compiled and linked against the real `FoundationModels.framework`; the timeout-and-fallback
> path (`withTimeout` + `guard let narrated`) is exercised by every test that runs through
> `ChatViewModel`'s default `narrator` parameter during test-host app launch (confirmed via the
> `Resource (Local Model Asset) unavailable` log), and always falls back correctly without
> crashing.

## Expected Behavior

### Narration Flow

```
engine.advance(choosing: optionID) → EngineResponse
    │
    ├─ EngineResponse.characterText = "a personagem precisa de ajuda e não sabe onde está"
    │                                  (JSON brief — never shown to player)
    │
    ├─ NarratorService.narrate(
    │       brief: "a personagem precisa de ajuda e não sabe onde está",
    │       sanity: 45,
    │       trust: 80,
    │       history: [last N messages]
    │   )
    │
    ├─ Foundation Models generates (example, sanity=45 low, trust=80 high):
    │   "cara, eu não sei mais... já perdi a noção de onde estou"
    │   "me ajuda por favor, tô com muito medo"
    │
    └─ ViewModel appends this generated text as the character message
```

### Tone Reference (for the system prompt)

| State | Tone Example |
|-------|-------------|
| sanity HIGH + trust HIGH | "Olha, acabei de ver uma porta no fim do corredor. Parece uma saída. O que você acha?" |
| sanity HIGH + trust LOW | "Tem uma porta aqui. Você sabe o que eu faço?" |
| sanity LOW + trust HIGH | "porta... tem uma porta... você vê isso? diz que sim" |
| sanity LOW + trust LOW | "não sei. não sei mais. tem algo ali. não sei" |

## Edge Cases

- **Narration times out (>8 s on device):** fall back to the raw JSON brief. Log the timeout silently.
- **Generated text exceeds ~300 characters:** truncate or instruct the model via the prompt to keep it short.
- **Terminal node:** the last character message is narrated as any other. After it displays, the game ends normally.
- **All existing unit tests:** use `StaticNarrator` (returns brief unchanged) — zero test changes needed from previous specs.

## Design / Wireframe

No visual changes. The character bubble looks identical — only its text content changes.

## Technical Notes

- **`Narrator` protocol:**
  ```swift
  protocol Narrator {
      func narrate(
          brief: String,
          sanity: Int,
          trust: Int,
          history: [ChatMessage]
      ) async -> String          // returns narrated text; falls back to brief on error
  }
  ```
- **`FoundationModelsNarrator`:** concrete implementation. Use a `LanguageModelSession` with a system prompt that:
  1. Defines the character persona (anonymous stranger trapped in a city outside of time, communicates via WhatsApp).
  2. Provides the current emotional state (sanity N/100, trust M/100) with tone guidance.
  3. Instructs the model to rephrase the brief in first-person, in pt-BR, as 1–3 short messages (separated by `\n`), never more than 300 chars total.
  4. Forbids inventing new plot facts not in the brief.
- **`StaticNarrator`:** returns `brief` unchanged. Used in all tests and as a compile-time fallback.
- **Session context:** Pass the last N messages (N = full history) as conversation context to help the model maintain consistent voice.
- **Typing delay:** `max(1.5, min(5.0, Double(narratedText.count) / 40.0))` seconds.
- **`ChatViewModel` change:** Replace `let text = response.characterText` with `let text = await narrator.narrate(brief: response.characterText, sanity: engine.ints["sanity"] ?? 80, trust: engine.ints["trust"] ?? 50, history: messages)`.
- **No new Swift Package dependencies.**

## Dependencies

- **Spec 006** (Intent Parsing) — establishes the Foundation Models integration pattern and the iOS 26+ deployment target.
- **Spec 004** (State Variables) — sanity and trust must be readable from the engine.
- **Spec 005** (Persistence) — narrated text (not the JSON brief) is what gets persisted in `messages`.

Blocks: **Spec 008+** (Menu / Achievements — the fully AI-narrated game should be the version players see from the menu).

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-23 | Antigravity | Initial creation from /grill-me session |
| 2026-07-23 | Claude Code | Implemented alongside Spec 006 (approved together by Richard). Added `Narrator`/`StaticNarrator`/`FoundationModelsNarrator`; `ChatViewModel.deliver(_:delayOverride:)` narrates before computing the typing delay, unifying Spec 006's and 007's delay formulas into one (`max(1.5, min(5.0, narratedText.count / 40))`). Added `NarratorTests` + a `StubNarrator`-based `ChatViewModelTests` case proving the pipeline uses the narrator's output, not the raw brief. |
| 2026-07-23 | Claude Code | Real-device testing surfaced a serious leak: the model would echo the transcript's own "personagem:"/"jogador:" speaker labels into its output, and occasionally wrap dialogue in `*asterisk roleplay*` notation that renders as literal characters (no markdown support in `Text`). Tightened the prompt (explicit anti-label/anti-asterisk rules, tighter "don't invent" guidance with a negative example, brevity preferred over the previous "always up to 3 messages"), and — since this must never reach the screen — made `clean(_:)` defensively strip speaker labels line-by-line and asterisks unconditionally, regardless of whether the model follows instructions. Extended `NarratorTests` accordingly. |
