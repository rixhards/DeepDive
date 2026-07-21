# CLAUDE.md — DarkDive

> This file is loaded automatically at the start of every Claude Code session, and is the
> canonical instruction file for **any** AI agent on this project (Claude Code, Antigravity,
> etc.). `AGENTS.md` is a symlink to this file. Keep it under ~200 lines; put deep detail in
> `docs/` and link to it.

## What this project is

**DarkDive** is a narrative horror game for **native iOS**, played entirely through a chat
interface. The player guides an anonymous stranger trapped in a city outside of time
(loosely inspired by the Ratanabá legend). The player never lives the story — they only
send messages and read what happens next.

Full product vision: [`docs/vision.md`](docs/vision.md).

## How we work: Spec-Driven Development (SDD)

We do **not** vibe-code. Every feature follows this loop:

1. **Decide** — discuss the design (usually with Antigravity). Record big design sessions in
   `docs/decisions/`.
2. **Spec** — write a spec in `docs/specs/NNN-name.md` from `docs/specs/_template.md`, with
   explicit, checkable acceptance criteria. Move it `draft → review → approved`.
3. **Implement** — Claude Code writes the code for **one approved spec at a time**. Only
   build what the spec says.
4. **Review** — check the code against the spec's acceptance criteria (see the
   `spec-reviewer` subagent), then mark the spec `implemented`.

**The spec is the contract.** If a spec is ambiguous or wrong, say so and fix the spec —
do not silently guess scope.

## Golden rules (non-negotiable)

- **AI never owns game state.** When runtime AI is eventually added, Foundation Models only
  *interpret* the player's words and *narrate* in character. The **Game Engine** decides
  every consequence and owns all state. AI proposes; the engine disposes.
- **No new dependencies.** The app uses only Apple frameworks. Adding any dependency
  requires an ADR in `docs/adr/`.
- **Stay in scope.** Do not build things listed under "Out of Scope" in `docs/vision.md`.
- **Narrative content is data, not code.** Once the engine exists, story text lives in JSON
  (decoded with `Codable`), never hardcoded in Swift.
- **No real people as characters.** Do not depict real individuals tied to Amazonian
  legends (researchers, real Indigenous people, missing explorers).

## Tech stack

| Area | Choice |
|------|--------|
| Platform | Native iOS, **iOS 17+** (no visionOS, no cross-platform) |
| UI | SwiftUI |
| Architecture | MVVM with `@Observable` |
| Dependencies | Swift Package Manager (currently none) |
| Game engine | Local finite state machine (FSM) in pure Swift — deterministic, offline |
| Narrative format | JSON + `Codable` (data-driven) |
| Persistence (v1) | None — each session starts fresh |
| Runtime AI (v1) | None — validate the game loop first |

Details and diagrams: [`docs/architecture.md`](docs/architecture.md).

## Language rule

- **Code, identifiers, comments, docs, commits → English.**
- **In-game narrative text → Brazilian Portuguese (pt-BR)** only.

## Conventions

- Swift API Design Guidelines. Types `UpperCamelCase`, members `lowerCamelCase`.
  Views end in `View`, view models in `ViewModel`.
- One primary type per file; filename matches the type.
- `@Observable` for view models, `@State` for view-local state. No Combine without a reason.
- Views stay "dumb": timing/state/narrative logic lives in the view model, not the view.

## Building & testing

- Build/test from the command line with **`xcodebuild`** (lighter than the Xcode MCP):
  ```bash
  xcodebuild -project DarkDive.xcodeproj -scheme DarkDive -destination 'platform=iOS Simulator,name=iPhone 15' build
  ```
- Run the app or take screenshots via the `/run` skill when you need to see a change working.

## Who does what

| Agent | Role |
|-------|------|
| **Antigravity** (Claude in an IDE) | Brainstorming, architecture, writing specs & ADRs, review |
| **Claude Code** (terminal) | Implementation, refactoring, tests, heavy code changes |

## Where things live

- `docs/vision.md` — product vision
- `docs/architecture.md` — technical architecture & data flow
- `docs/ai-workflow.md` — **how this project uses AI** (specs, skills, subagents, MCP…) — read if unsure how any of this works
- `docs/specs/` — specs (the SDD contracts); `_template.md` to start a new one
- `docs/adr/` — architecture decision records
- `docs/decisions/` — design-session notes and learning material
- `.claude/skills/` — reusable procedures Claude Code can auto-load (e.g. `generate-spec`)
- `.claude/agents/` — subagents (e.g. `spec-reviewer`)

## Current status (2026-07)

Documentation and SDD scaffolding are in place. **Spec 001 (Chat UI) is `approved` but not
yet implemented** — the Swift code is still the empty Xcode template. Implementing spec 001
is the next step.
