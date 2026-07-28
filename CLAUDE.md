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
- **Narrative content is declarative data, kept out of the engine.** All prose lives in
  `WorldMap.swift` as plain declarations — places, features, items, endings — with no control
  flow. The engine (`ActionResolver`) interprets it; views never contain prose.
  *Amended by [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md): this used to require
  JSON. The dialog tree capped her at 37 authored lines and could not answer "where are you" or
  "what do you have", so the story became a Swift world model.*
- **No real people as characters.** Do not depict real individuals tied to Amazonian
  legends (researchers, real Indigenous people, missing explorers).

## Tech stack

| Area | Choice |
|------|--------|
| Platform | Native iOS, **iOS 26+** (no visionOS, no cross-platform) |
| UI | SwiftUI |
| Architecture | MVVM with `@Observable` |
| Dependencies | Swift Package Manager (currently none) |
| Game engine | `ActionResolver` — deterministic world simulation in pure Swift, offline |
| Narrative format | Swift world model (`WorldMap.swift`): places, features, items, endings |
| Persistence | SwiftData, single auto-saved session slot |
| Runtime AI | Foundation Models — `ActionParser` (free text → verb + target) + `Narrator` (facts → in-character prose). `LocalActionParser` handles common phrasings with no AI, so the game runs in the Simulator too |

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
- **Who tests what:** Richard tests on a **physical iPhone 16 (iOS 26.5)** — that's the only
  place Apple Intelligence actually runs, so intent parsing and dynamic narration can only be
  judged there. Agents **validate that it builds** and stop; do not launch the Simulator app or
  ask him to check the Simulator. A Simulator *destination* is fine as a pure compile target.
- **Tests are not a deliverable here.** Write a test only when it's the only way *you* can
  verify something (e.g. engine logic unreachable in the shipped story). No broad suites —
  nobody reviews them. Keep model changes additive (optional fields with defaults) so existing
  tests keep compiling.

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

## Current status (2026-07-28)

**The JSON dialog tree is gone.** [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md)
replaced it with a Swift world simulation, because the tree capped the character at 37 authored
lines and structurally could not answer "onde você está?" or "o que você tem aí?".

The loop is now: player text → `ActionParser` extracts a **verb + target** → `ActionResolver`
decides the outcome against `World` → `Narrator` says it in her voice. Places list their
**features**, so everything listed is examinable without authoring an option for it.

- `World.swift` — the authoritative state (place, inventory, flags, sanity, ending)
- `WorldMap.swift` — **all narrative prose**; add a place by listing what's in it
- `ActionResolver.swift` — the interaction rules (knife vs hands vs lamp on the hay, etc.)
- `LocalActionParser.swift` — deterministic pt-BR verb matching, no AI needed

Three endings (008, unchanged in behaviour): escape, surrender (sanity 0), taken. Debug sanity
meter is **on** (`DebugFlags.showSanityMeter`) — turn it off before shipping; the game is meant
to have no HUD.

Specs 002/003/004/006/009 are superseded by ADR-002 and kept only as history. Specs 001, 005,
007 and 008 still describe live behaviour.

**Known gaps:** `pastIronDoor` is a placeholder ending, the world is only three real places, and
sanity 0 is hard to reach — all of them need more authored content, not more engine.
