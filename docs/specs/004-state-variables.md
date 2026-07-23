# Spec 004 — State Variables

## Status
`implemented`

## Context

Specs 001–003 delivered a complete game loop: a SwiftUI chat UI driven by a deterministic FSM that reads a JSON dialog tree. The FSM already has the skeletal infrastructure for flags (`[String: Bool]`) and conditions/effects in the JSON schema, but every node's options are always visible — no choice has ever been hidden or gated.

The game's five emergent endings require accumulation of narrative state across the session. Without tracked variables, every playthrough takes the same available paths and converges to the same outcomes. This spec activates the state variable system, making `sanity` and `trust` live numeric values that shape which options the player sees.

## Objective

Extend the `GameEngine` to track integer state variables (`sanity`, `trust`) alongside boolean flags, evaluate richer conditions (`>=`, `<=`) when filtering options, and apply delta/absolute effects on those integers — all driven from `story.json` with no UI changes.

## Acceptance Criteria

- [x] The `Story` model gains an optional `initialState` field decoded from the root of `story.json`.
- [x] `GameEngine` initialises its state from `initialState` (e.g. `sanity: 80, trust: 50`); missing keys default to `0`.
- [x] `StoryCondition` supports three operators: `eq` (bool equality, existing), `gte` (`>=`), `lte` (`<=`).
- [x] `StoryEffect` supports two modes for integers: `delta` (relative, e.g. `−10`) and `set` (absolute, e.g. `50`).
- [x] `StoryEffect` boolean `set` (`true`/`false`) continues to work unchanged.
- [x] The engine correctly filters options by evaluating all conditions (bool + int) against the current state.
- [x] Integer state is clamped to 0–100 after every effect application.
- [x] No changes are made to any SwiftUI view or `ChatViewModel`.
- [x] Unit tests cover: delta effects, absolute set effects, `gte`/`lte` conditions gating options, clamping, and `initialState` loading.
- [x] A fixture file `story-spec004-fixture.json` (test bundle only) contains a mini-scenario with at least 2 conditional branches driven by `sanity` and `trust`.

## Expected Behavior

### JSON Schema

**Root-level `initialState`:**
```json
{
  "startNodeID": "start",
  "initialState": { "sanity": 80, "trust": 50 },
  "nodes": [ ... ]
}
```

**Condition examples:**
```json
{ "var": "sanity", "op": "gte", "value": 60 }
{ "var": "trust",  "op": "lte", "value": 30 }
{ "var": "found_key", "op": "eq", "value": true }
```

**Effect examples:**
```json
{ "var": "sanity", "delta": -10 }
{ "var": "trust",  "set": 70 }
{ "var": "found_key", "set": true }
```

### State Evaluation Flow

1. Player taps an option.
2. Engine applies the option's `effects` to the current state (delta or set; int values clamped 0–100 after each effect).
3. Engine advances to the next node.
4. Engine filters the new node's options — any option whose `conditions` are not all satisfied is excluded from `EngineResponse.options`.
5. If no options pass, `isTerminal = true`.

### UI Impact

**None.** The player never sees numbers. They only notice that some options that appeared before may no longer appear (or new ones unlock). `ChatView`, `OptionButtonsView`, and all other views are unchanged.

## Edge Cases

- **`initialState` absent:** all integer variables default to `0`; boolean flags default to `false`.
- **Delta pushes value below 0 or above 100:** clamp to `[0, 100]`.
- **`set` on an undeclared variable:** creates the variable with the given value.
- **Condition references an undeclared variable:** treat as `0`/`false`; condition may fail, hiding the option — this is intentional defensive behaviour.
- **All options gated out mid-narrative:** engine returns `isTerminal = true`; the game ends gracefully at that node.

## Design / Wireframe

Not applicable — no visual changes.

## Technical Notes

- **Refactor `StoryCondition`:** add a `op: ConditionOperator` enum (`eq`, `gte`, `lte`) and a `value: StateValue` enum (`bool(Bool)` / `int(Int)`). Keep backward-compatible JSON decoding.
- **Refactor `StoryEffect`:** add a `mode: EffectMode` enum (`set` / `delta`). `delta` is only valid for `Int` values; treat `delta` on a bool variable as a no-op with a warning.
- **State storage:** the engine already has `flags: [String: Bool]`. Add `ints: [String: Int]` alongside it, or unify into a single `StateValue` enum dictionary — Claude Code should choose whichever is cleaner given the existing code.
- **Clamping:** apply after every individual effect, not after all effects in a batch, so authors can't accidentally over-clamp with conflicting effects.
- **`initialState` model:** a new `Codable` struct or a `[String: StateValue]` alias on `Story` — Claude Code's call.
- **No new Swift Package dependencies.**

## Dependencies

- **Spec 002** (Game Engine) — `GameEngine`, `StoryCondition`, `StoryEffect`, `EngineResponse` all exist.
- **Spec 003** (UI + Engine Integration) — the wired-up app is required to do an end-to-end manual check.

Blocks: **Spec 005** (Persistence) and **Spec 006** (On-Device AI), both of which depend on a stable state model.

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-23 | Antigravity | Initial creation from /grill-me session |
| 2026-07-23 | Claude Code | Added `ConditionOperator`/`StateValue`/`initialState`; refactored `StoryCondition`/`StoryEffect` (new JSON shape: `var`/`op`/`value`, `var`/`delta`/`set`); `GameEngine` tracks `ints` alongside `flags` with clamping; added `StateVariableTests.swift` + `story-spec004-fixture.json`; verified no view/`ChatViewModel` diff and no regression in the simulator; status → `implemented` |
