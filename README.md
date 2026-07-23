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
| Understand the tech | [`docs/architecture.md`](docs/architecture.md) |
| **Understand how we use AI** (specs, skills, subagents) | [`docs/ai-workflow.md`](docs/ai-workflow.md) |
| Know the rules every AI agent follows | [`CLAUDE.md`](CLAUDE.md) (`AGENTS.md` is a symlink to it) |

## Specs

Every feature is a spec in [`docs/specs/`](docs/specs/), created from
[`_template.md`](docs/specs/_template.md).

| Nº | Spec | Status |
|----|------|--------|
| 001 | [Chat UI](docs/specs/001-chat-ui.md) | `implemented` |
| 002 | [Game Engine](docs/specs/002-game-engine.md) | `implemented` |
| 003 | [UI + Engine Integration](docs/specs/003-ui-engine-integration.md) | `implemented` |
| 004 | [State Variables](docs/specs/004-state-variables.md) | `implemented` |
| 005 | [Persistence](docs/specs/005-persistence.md) | `implemented` |
| 006 | [On-Device AI — Intent Parsing](docs/specs/006-on-device-ai-intent-parsing.md) | `implemented` |
| 007 | [Dynamic Narration](docs/specs/007-dynamic-narration.md) | `implemented` |

Planned next: 008+ Menu + Achievements · 009+ App Intents / Siri.

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

Requires Xcode (iOS 26+ target). Build from the command line:

```bash
xcodebuild -project DeepDive.xcodeproj -scheme DeepDive \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Status

Specs 001–007 are implemented. The Xcode project targets iOS 26+ (Foundation Models /
Apple Intelligence). Planned next: 008+ Menu + Achievements.
