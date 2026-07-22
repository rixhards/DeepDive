# Spec 002 — Game Engine

## Status
`implemented`

## Context
The Chat UI is currently driven by a hardcoded mock inside the view layer. DeepDive needs a deterministic, data-driven core to manage the narrative. The Game Engine acts as this core, parsing a narrative graph (dialog tree) from a JSON file and maintaining the state of the conversation. This spec builds the standalone Game Engine and the foundational JSON structure, completely decoupled from the UI. 

## Objective
Deliver a local finite state machine (Game Engine) written in pure Swift that reads a JSON narrative file (`story.json`), evaluates node conditions, and returns a sanitized presentation-ready DTO to the caller. 

## Acceptance Criteria
- [x] A `story.json` file is bundled with the app, containing a slightly expanded version of the Spec 001 mini-scenario.
- [x] The JSON schema is forward-compatible, supporting optional `conditions` and `effects` arrays on options.
- [x] A `StoryRepository` (or similar) decodes `story.json` using `Codable` without external dependencies.
- [x] A `GameEngine` class is created to manage the narrative flow (Finite State Machine).
- [x] When advancing the conversation, the engine returns an `EngineResponse` DTO (presentation model) containing the character's text, valid options, and a boolean indicating if it's a terminal node.
- [x] The engine correctly parses `conditions` and `effects` (even if they are unused or empty for now, the data model supports them).
- [x] The `GameEngine` has zero dependencies on `SwiftUI` or the `ChatViewModel`.
- [x] Comprehensive Unit Tests prove that the engine navigates nodes correctly and decodes the JSON successfully.

## Expected Behavior
### Main Flow
1. The engine is initialized, triggering the load and decoding of `story.json`.
2. The caller requests the starting node.
3. The engine resolves the starting node, filtering out options whose conditions are not met (for v1, all conditions pass).
4. The engine constructs and returns an `EngineResponse` DTO.
5. The caller selects an option ID and calls `advance(choosing: optionID)`.
6. The engine locates the target node, applies any `effects`, resolves the next options, and returns the next `EngineResponse`.
7. This repeats until a node with no valid options is reached, marking the end of the narrative (terminal node).

### UI States
Not applicable (Engine only). UI integration happens in Spec 003.

## Edge Cases
- **Missing JSON file:** The engine handles the error gracefully (e.g., throwing a clear error or failing fast during tests).
- **Invalid next node ID:** If an option points to a non-existent node, the engine fails gracefully or logs a clear error.
- **Empty options:** Reaching a node with no options immediately marks the response as a terminal node.
- **Missing optional fields:** The `Codable` models gracefully handle nodes or options where `conditions` or `effects` are omitted from the JSON.

## Design / Wireframe
Not applicable (headless Domain/Data logic).

## Technical Notes
- Implement in pure Swift. No UI frameworks (`SwiftUI`, `UIKit`) should be imported in the domain models or engine.
- **JSON Schema:** Ensure the schema uses proper data types. Use standard `UpperCamelCase` for types and `lowerCamelCase` for properties, leveraging `CodingKeys` if the JSON keys differ.
- **DTO:** Create an `EngineResponse` (or similar) struct to act as the boundary between the engine and the UI.
- The `story.json` narrative content should remain in Brazilian Portuguese (pt-BR).
- Keep the `GameEngine` testable by allowing the injection of a mock `StoryRepository` or direct JSON data in tests.

## Dependencies
- Must run after: Spec 001 (Chat UI) — conceptually, though they can be built in parallel.
- Blocks: Spec 003 (UI + Engine Integration).

## Revision History
| Date | Author | Change |
|------|--------|--------|
| 2026-07-22 | Antigravity | Initial creation |
| 2026-07-22 | Claude Code | Implemented `Story`/`StoryNode`/`StoryOption`/`StoryCondition`/`StoryEffect`, `StoryRepository`, `GameEngine`, `EngineResponse`; added `DeepDiveTests` unit test target (10 tests, all passing); status → `implemented` |
