# AGENTS.md — DarkDive

> Global rules and conventions for every AI agent working on this project.

## Project Identity

DarkDive is a narrative horror game for iOS, played entirely through a chat interface.
The player guides an anonymous stranger who is trapped in a city outside of time, loosely
inspired by the Ratanabá legend. The player never lives the story — they only send messages
and receive reports of what happened next.

This is a **real project**, not a POC (renamed from `POC_EscapeRoom`).

See [`docs/vision.md`](docs/vision.md) for the full product vision.

## Tech Stack

| Decision | Value | Rationale |
|----------|-------|-----------|
| Platform | **Native iOS** | No visionOS, no cross-platform |
| UI framework | **SwiftUI** | The existing Xcode project is already SwiftUI |
| Deployment target | **iOS 17+** | Enables `@Observable` and future SwiftData; covers 95%+ of devices; ready for iOS 26+/27+ and the new Siri |
| Architecture | **MVVM** with `@Observable` | Natural SwiftUI pattern; separates logic from UI |
| Dependency manager | **SPM** (Swift Package Manager) | Native, no extra configuration |
| Game engine | **Local FSM in Swift** | Runs on-device, deterministic, works offline |
| Narrative format | **JSON** with `Codable` | Native, dependency-free, data-driven |
| Persistence (v1) | **None** | Every session starts from zero. SwiftData is a future spec |
| AI (v1) | **None** | Validate the game loop first. AI comes later as a separate spec |

## Code Conventions

- **Language of the codebase:** English for all identifiers, comments, commit messages,
  and documentation. Only in-game narrative content is pt-BR.
- **Naming:** Swift API Design Guidelines. Types `UpperCamelCase`, members
  `lowerCamelCase`. Views end in `View`, view models end in `ViewModel`.
- **File layout:** one primary type per file, filename matching the type.
- **State:** `@Observable` for view models; `@State` for view-local state. No Combine
  unless there is a concrete reason.
- **Narrative data:** never hardcode story content in Swift once the engine exists —
  it lives in JSON and is decoded with `Codable`.
- **Formatting:** Xcode defaults, 4-space indentation.

## AI Workflow

| Agent | Model | Responsibility |
|-------|-------|----------------|
| **Antigravity** | Claude Sonnet / Opus | Brainstorming, architecture, review, writing specs, ADRs, documentation |
| **Claude Code** | Claude (terminal) | Implementation, refactoring, tests, heavy code tasks |

Design decisions are made with Antigravity and recorded as specs or ADRs **before**
Claude Code implements them. Specs are the contract between the two.

## General Rules for Agents

### Non-negotiable rule

> **Foundation Models never modify game state directly. The AI interprets and narrates;
> the Game Engine decides consequences and owns the state.**

### The AI's in-game role (once implemented)

- Interprets the player's free-form instructions
- Gives voice to the chat character, keeping tone consistent and respecting what that
  character could plausibly know
- **Never** decides the fate of the story — that is the Game Engine's job

### Working rules

- Follow the approved spec. If the spec is ambiguous or wrong, say so instead of
  improvising scope.
- Do not add dependencies. The stack is SPM-only and currently dependency-free.
- Do not introduce out-of-scope features (see `docs/vision.md` → Out of Scope).
- Respect the existing section structure in documentation files; do not invent new
  sections without need.
- Do not depict real people associated with Amazonian legends as characters.

## References

- [`docs/vision.md`](docs/vision.md) — product vision
- [`docs/architecture.md`](docs/architecture.md) — technical architecture
- [`docs/specs/001-chat-ui.md`](docs/specs/001-chat-ui.md) — Chat UI spec
- [`docs/specs/_template.md`](docs/specs/_template.md) — spec template
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`docs/decisions/grill-me-session-2026-07-20.md`](docs/decisions/grill-me-session-2026-07-20.md) — source-of-truth design session
