# ADR-002 — World simulation in Swift, replacing the JSON dialog tree

**Status:** `accepted`
**Date:** 2026-07-28
**Deciders:** Richard (product owner), Claude Code (implementation)

## Context

Specs 001–009 built a working game on a **JSON dialog tree**: nodes hold one line of character
text plus a list of authored options, an on-device model maps the player's free text to one of
those options, and a narrator rephrases the authored line.

Play-testing on device showed it does not deliver the product's premise. Measured against the
shipped `story.json`, the character had **37 authored strings in the entire game** — seven in
the opening room. That is the hard ceiling on everything she can ever say, because the narrator
is forbidden (correctly) from inventing facts the brief doesn't contain.

Audited against the premise as the owner restated it, only two of eight points held:

| Premise | Status before this ADR |
|---|---|
| Character trapped in Ratanabá; the player helps her out | met |
| Several death scenarios | met |
| Finds items and uses them only when told to | partial — "use" only existed where pre-authored |
| Places she moves between and returns to until one advances the story | partial — a single loop existed |
| A madness ending where she gives up | partial — unreachable (sanity could not reach 0) |
| **She always keeps the player informed of where she is and what she found** | **not met** |
| **She reacts to what happens to her and around her** | **not met** |
| A good exit requiring correct choices | not met — placeholder |

The two unmet points are not content gaps. They are structural: a dialog tree can only answer
what was authored as an option. "O que você tem aí?" resolved to *"não entendi"* because there
was no such option, not because the answer was unknown — the engine held the inventory the
whole time.

A separate, unrelated defect surfaced in the same session: the narrator prompt never stated the
character's gender, so Portuguese agreement came out inconsistent. Fixed alongside this work;
it is not a reason for the architecture change.

## Options Considered

### Option 1: Keep the JSON dialog tree, author much more content

- **Pros:** No migration. Specs 001–009 stay valid. Smallest immediate diff.
- **Cons:** Does not fix the structural limits at any content volume. Every question the player
  might ask has to exist as an authored option in every node where it could be asked, which is
  combinatorial. "Where are you / what do you have / what do you see" would need re-authoring
  per node despite the answer being derivable from state the engine already holds.

### Option 2: Keep JSON for content, add a rules layer for verbs

- **Pros:** Preserves the "narrative is data" golden rule.
- **Cons:** Two sources of truth for the same world. The condition mini-language (`eq`/`gte`/`lte`,
  AND-only) cannot express the interaction rules — "knife on hay" versus "hand on hay" versus
  "lamp on hay" — so the rules end up in Swift anyway, with the JSON reduced to a lookup table
  that Swift constantly has to re-validate at runtime.

### Option 3: World simulation in Swift (chosen)

Places with enumerated features, items with identity, generic verbs, and a resolver that
answers from world state.

- **Pros:** Directly serves the two unmet premise points, because answering "where are you" and
  "what do you have" becomes reading state rather than matching an authored option. Interaction
  rules get Swift's full expressiveness. Broken references become compile errors instead of the
  runtime decode crash that shipped earlier in this project. Enumerating a place's features once
  makes every one of them examinable, so redundancy stops being per-option authoring work.
- **Cons:** Violates the "narrative content is data, not code" golden rule (this ADR amends it).
  Substantially rewrites the domain layer. Introduces a new failure mode: actions targeting
  things the world doesn't model produce "there's nothing like that here", so a thin world reads
  as an unresponsive one.

## Decision

**Option 3.** The story is represented as a Swift world model — `Place`s with `Feature`s and
`Exit`s, `Item`s, flags, and an `ActionResolver` holding the interaction rules. The on-device
model's job changes from *"pick one of these authored options"* to *"extract a verb and a
target"*; the resolver decides the outcome against world state; the narrator describes that
outcome in character.

**The golden rule in `CLAUDE.md` is amended** from "narrative content is data, not code" to:
narrative content lives in Swift as declarative world data (`WorldMap`), separated from the
engine that interprets it. The rule's intent — no prose scattered through view code, no
hardcoded strings in control flow — still holds and is enforced by keeping all prose in
`WorldMap.swift` and the resolver's outcome facts.

This was chosen over Option 1 with the trade-off understood and accepted: it costs more work
now, and the owner has limited time, but Option 1 cannot reach the premise at any budget.

### Explicitly kept

The chat UI (spec 001), the `Narrator` and its Foundation Models integration (007), sanity and
the three endings (008), and SwiftData persistence (005) all survive. The deterministic local
matcher from spec 006 is repurposed to resolve verbs and targets without the model, which also
makes the game playable in the Simulator where Apple Intelligence does not exist.

### Superseded

Specs **002** (Game Engine), **003** (UI + Engine Integration), **004** (State Variables),
**006** (Intent Parsing), and **009** (Game Loop & Redundancy) are superseded in their
implementation details. Their *intent* carries over: determinism, AI never owning state,
exploration loops, endings. Spec **008**'s sanity model and three endings carry over unchanged
in behaviour.

## Consequences

### Positive

- She can answer about her location, her inventory, and anything the current place models,
  anywhere in the game, without that being authored per place.
- "Olha pros pilares", "olha pra água", "olha pro teto" are three distinct actions rather than
  one bucketed option with a canned paragraph.
- Failure stays in fiction: an unrecognised action yields "eu tentei e não consegui" or "não tem
  nada assim aqui" instead of the character breaking with *"não entendi"*.
- Adding a place means listing its features once; every feature is immediately examinable.
- Compile-time checking of place, item, and exit references.

### Negative / Trade-offs

- The world's responsiveness now scales with how diligently features and items are enumerated. A
  sparse place will feel dead.
- Narrative changes require a rebuild; no hot-editing a JSON file.
- The domain layer is rewritten, and the tests covering the removed types are deleted with them
  (consistent with this project's rule that tests are not a deliverable and exist only where they
  are the sole way to verify something).
- Non-programmers can no longer edit the story. Accepted: this project has a single developer who
  is also the author.

## References

- `docs/specs/008-sanity-rework.md` — sanity model and the three endings, carried over.
- `docs/specs/009-game-loop-redundancy.md` — the stay-in-place rule this architecture generalises.
- Owner's premise restatement and the 37-string measurement, 2026-07-28 session.
- The reference architecture the owner supplied (`Text RPG with LLM.md`): interpreter → deterministic
  engine → narrator, with the model never owning state.
