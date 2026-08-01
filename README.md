# DeepDive

> A narrative horror game for iOS, played entirely through a chat interface. You guide an
> anonymous stranger trapped in a city outside of time — you never live the story, you only
> send messages and read what happens next.

Built with **Spec-Driven Development (SDD)** and AI assistance (Claude Code + Antigravity).
Every feature starts as an approved spec before any code is written — no vibe coding.

## Start here

| If you want to… | Read |
|-----------------|------|
| Understand the product | [`docs/vision.md`](docs/vision.md) |
| Understand the tech | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Understand the narrative scope | [`GAME_SCOPE.md`](GAME_SCOPE.md) |
| **Understand how we use AI** (specs, skills, subagents) | [`docs/ai-workflow.md`](docs/ai-workflow.md) |
| Know the rules every AI agent follows | [`CLAUDE.md`](CLAUDE.md) (`AGENTS.md` is a symlink to it) |

## Specs

Every feature is a spec in [`docs/specs/`](docs/specs/), created from
[`_template.md`](docs/specs/_template.md).

| Nº | Spec | Status |
|----|------|--------|
| 001 | [Chat UI](docs/specs/001-chat-ui.md) | `implemented` |
| 002 | [Game Engine](docs/specs/002-game-engine.md) | `implemented` — superseded by [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md) |
| 003 | [UI + Engine Integration](docs/specs/003-ui-engine-integration.md) | `implemented` — superseded by [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md) |
| 004 | [State Variables](docs/specs/004-state-variables.md) | `implemented` — superseded by 008 + [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md) |
| 005 | [Persistence](docs/specs/005-persistence.md) | `implemented` |
| 006 | [On-Device AI — Intent Parsing](docs/specs/006-on-device-ai-intent-parsing.md) | `implemented` — superseded by [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md) |
| 007 | [Dynamic Narration](docs/specs/007-dynamic-narration.md) | `implemented` — partially superseded by 008 |
| 008 | [Sanity Rework](docs/specs/008-sanity-rework.md) | `implemented` |
| 009 | [Game Loop Redundancy](docs/specs/009-game-loop-redundancy.md) | `implemented` — superseded by [ADR-002](docs/adr/ADR-002-world-simulation-in-swift.md) |
| 010 | [Visual Redesign](docs/specs/010-visual-redesign.md) | `implemented` |
| 011 | [App Store Submission](docs/specs/011-app-store-submission.md) | `implemented` — pendente das etapas manuais |
| 012 | [Repetition Window](docs/specs/012-repetition-window.md) | `approved` |

A spec marked *superseded* stays here on purpose: it records what was decided at the time,
and the ADR it points to explains why the design moved on.

## AI scaffolding in this repo

- **[`CLAUDE.md`](CLAUDE.md)** — project context + rules, auto-loaded every Claude Code session.
- **[`.claude/skills/generate-spec/`](.claude/skills/generate-spec/SKILL.md)** — skill: turn an idea into a spec.
- **[`.claude/agents/spec-reviewer.md`](.claude/agents/spec-reviewer.md)** — subagent: check an implementation against a spec's acceptance criteria.
- **[`docs/adr/`](docs/adr/)** — architecture decision records.
- **[`docs/decisions/`](docs/decisions/)** — design-session notes and learning material.

MCP, RAG, hooks, and plugins are intentionally **not** set up — see `docs/ai-workflow.md`
for why (short version: an offline single-player game doesn't need them yet).

## The workflow

1. **Idea** → discuss (usually with Antigravity), note big sessions in `docs/decisions/`.
2. **Spec** → `generate-spec` → refine → mark `approved`.
3. **Implement** → in Claude Code: "implement spec NNN". It reads `CLAUDE.md` + the spec.
4. **Review** → `spec-reviewer` subagent checks it against the acceptance criteria.
5. **Commit**, mark the spec `implemented`, repeat.

## Building

The project file format (110) requires **Xcode 27 beta**, and the target is iOS 26+.
Build from the command line:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project DeepDive.xcodeproj -scheme DeepDive -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build
```

There is no test target — see the "Building & testing" section of [`CLAUDE.md`](CLAUDE.md)
for why tests aren't a deliverable on this project.

## Status

Specs 001–011 are implemented and 012 is approved. The app is prepared for App Store
submission (see [`docs/submissao.md`](docs/submissao.md)); what remains are the manual
steps that need Richard's credentials.
