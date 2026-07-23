# CLAUDE.md — DeepDive

> This file is loaded automatically at the start of every Claude Code session, and is the
> canonical instruction file for **any** AI agent on this project (Claude Code, Antigravity,
> etc.). `AGENTS.md` is a symlink to this file. Keep it under ~200 lines; put deep detail in
> `docs/` and link to it.

## What this project is

**DeepDive** is a narrative horror game for **native iOS**, played entirely through a chat
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

- **AI never owns game state.** Foundation Models only *interpret* the player's words
  (`IntentParser`) and *narrate* in character (`Narrator`). The **Game Engine** decides
  every consequence and owns all state. AI proposes; the engine disposes.
- **No new dependencies.** The app uses only Apple frameworks. Adding any dependency
  requires an ADR in `docs/adr/`.
- **Stay in scope.** Do not build things listed under "Out of Scope" in `docs/vision.md`.
- **Narrative content is data, not code.** Story text lives in JSON (decoded with
  `Codable`), never hardcoded in Swift.
- **No real people as characters.** Do not depict real individuals tied to Amazonian
  legends (researchers, real Indigenous people, missing explorers).

## Tech stack

| Area | Choice |
|------|--------|
| Platform | Native iOS, **iOS 26+** (no visionOS, no cross-platform) |
| UI | SwiftUI |
| Architecture | MVVM with `@Observable` |
| Dependencies | Swift Package Manager (currently none) |
| Game engine | Local finite state machine (FSM) in pure Swift — deterministic, offline |
| Narrative format | JSON + `Codable` (data-driven) |
| Persistence | SwiftData, single auto-saved session slot |
| Runtime AI | Foundation Models — `IntentParser` (free text → option) + `Narrator` (brief → in-character prose) |

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

- Build/test from the command line with **`xcodebuild`** (lighter than the Xcode MCP). If
  `xcode-select -p` points at the Command Line Tools instead of Xcode, prefix commands with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (adjust the path/name if you have
  a differently named or beta Xcode install) rather than changing the system-wide selection.
  Check available simulators with `xcrun simctl list devices available` — the destination
  name must match an installed runtime (e.g. `iPhone 17`, not `iPhone 15`, on newer Xcode).
  ```bash
  xcodebuild -project DeepDive.xcodeproj -scheme DeepDive -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcodebuild -project DeepDive.xcodeproj -scheme DeepDive -destination 'platform=iOS Simulator,name=iPhone 17' test
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

Specs 001–007 are implemented: chat UI, game engine, state variables, persistence, and the
full on-device AI layer (free-text intent parsing + dynamic narration). Deployment target is
**iOS 26+** (Foundation Models / Apple Intelligence required). Next up: 008+ Menu +
Achievements.
