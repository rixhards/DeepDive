# Vision — DeepDive

> High-level product vision document.

## Problem

Players want an immersive narrative horror experience that feels like a real WhatsApp
conversation with someone in danger — no complex game mechanics, just the tension of
guiding a stranger through the unknown.

Existing interactive fiction either overwhelms with systems (inventories, stats, combat)
or breaks immersion by making the player the protagonist. Neither reproduces the specific
dread of being the safe one on the other end of the line, powerless except through words.

## Solution

DeepDive is a narrative horror game played entirely through a chat interface.

**Core concept:**

- The player does **not** live the story. They guide, from a distance, someone (the
  "chat character") who is trapped inside it.
- The contact is **completely anonymous** — two strangers who have never met, like a
  number that appeared out of nowhere.
- The chat character has **no narrative will of their own**: they follow the player's
  instructions and report back what happens next.
- The player does **not** know which path leads to the good ending. There is no
  pre-defined correct walkthrough. The path is shaped by the player's choices across
  the playthrough.

**Setting:**

- Loosely based on the **Ratanabá legend** — a supposed prehistoric city/civilization
  buried in the Brazilian Amazon, never proven, with tunnels and geometric ruins.
- The legend is used as **world inspiration only**. Real people associated with Amazonian
  legends (researchers, real Indigenous individuals, disappeared explorers) are **not**
  recreated as characters.
- The person on the chat is trapped in an **alternate temporal date** inside that city,
  where present, past, and future coexist.
- The cause of this temporal overlap is an **anomaly without explanation** — it simply is,
  and nobody in the game's universe knows why. This is a constant of the world, not a
  mystery to be solved and explained at the end.
- The **bestiary is not limited to Brazilian folklore**: creatures from cinema horror,
  folklore, mythology, and assorted mysticism coexist. What unites them is belonging to
  this city outside of time, not their cultural origin.

**Narrative tone:**

- A spectrum between **psychological/ambiguous horror** and **cosmic horror** (human
  insignificance).
- A single playthrough may slide from one to the other depending on the player's choices.

**Endings:**

Multiple emergent endings. Five reference archetypes guide the design:

1. Escape with sanity intact
2. Escape changed or marked
3. Survive but remain trapped in some way
4. Consumed by the city
5. Narratively meaningful death

Endings are a **function of accumulated state** (sanity, the chat character's trust in the
player, clues discovered, city rules respected or violated) — **never** a direct "pick
ending X" choice, and never random.

> **v1 note:** there will be no state variables in v1. Endings are determined purely by the
> node graph. State variables (sanity, trust, flags) belong to future specs.

## Target Users

Players who enjoy narrative-first horror and interactive fiction — the Bandersnatch /
choice-driven game audience — on iOS. They want a short, atmospheric session they can play
one-handed, in the dark, without learning a system.

## Value Proposition

- **Format as fiction.** The chat UI is not a wrapper around a game; it *is* the diegetic
  medium. There is no HUD to break the illusion.
- **Distance as horror.** The player is safe and useless at the same time. Every
  consequence lands on someone else, caused by the player's words.
- **No walkthrough.** No canonical good path to look up, so the tension of not knowing
  survives contact with the internet.
- **Emergent endings.** Outcomes fall out of accumulated choices rather than a final menu.

## Goals and Success Metrics (OKRs / KPIs)

| Goal | Metric |
|------|--------|
| Validate the game loop | A playtester completes a full mini-scenario without needing an explanation of how to play |
| Preserve immersion | No playtester reports the UI "feeling like a game menu" instead of a chat |
| Prove emergent endings | At least 2 distinct endings reached across playtest sessions from choices alone |
| Keep content data-driven | Adding a new scene requires editing JSON only, never Swift code |

## Language

- **Brazilian Portuguese (pt-BR)** for all in-game narrative content.
- **English (en-US)** for all project documentation, code, and identifiers.
- English narrative support will be added in a future i18n spec.

## Out of Scope (v1)

- Free-text player input (v1 uses pre-defined buttons)
- AI / Foundation Models
- Progress persistence (each session starts from zero)
- Multiplayer
- Monetization
- Audio / music
- Internationalization (i18n)

## High-Level Roadmap

| Spec | Title | Scope |
|------|-------|-------|
| 001 | Chat UI | Chat UI only, with mocked data |
| 002 | Game Engine | FSM + JSON dialog tree + mini-scenario |
| 003 | UI + Engine Integration | Connect the chat UI to the game engine |
| 004+ | State Variables | Sanity, trust, conditional flags |
| 005+ | Persistence | Save/load progress with SwiftData |
| 006+ | On-Device AI | On-device intent parsing / local model |
| 007+ | i18n | English narrative support |
| 008+ | New Siri | App Intents / Siri integration |
