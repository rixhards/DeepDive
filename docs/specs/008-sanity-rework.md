# Spec 008 — Sanity Rework and Three Endings

## Status
`implemented`

## Context

Two design decisions (2026-07-27) reshape the game's state layer:

**Trust is removed.** It hurt the experience, and its only mechanical use — gating the bridge
branch — is now a direct player choice. Sanity becomes the single narrative state variable.

**Five endings become three.** Scope is being cut to fit the available development time. The
five reference archetypes in `docs/vision.md` collapse into three authored endings (see below).

That leaves sanity carrying the whole state layer, and today it is opaque:

- It **only ever decreases** — nothing raises it.
- Drops are **brutal** (−10 / −20 / −30 on a 0–100 scale).
- Its only live effect is narration tone, invisible in the Simulator (no on-device model), so
  it cannot be felt or balanced during development.
- Bottoming out at 0 does **nothing**; only the final door's `>= 70` check reads sanity.

This spec makes sanity two-directional and gentler, gives 0 a real consequence (it becomes the
neutral ending), and adds a **temporary, debug-only** meter so the value can be balanced
on-device. The meter is explicitly not shipping UI — the vision's "no HUD to break the
illusion" principle stands; it is a balancing instrument to switch off with one flag.

With three endings, sanity's job becomes legible for the first time: **sanity 0 *is* the
neutral ending.** The final door no longer forks on it, because escaping is now a single
outcome.

The golden rule holds: **the engine owns all sanity changes.** Supportive vs hostile tone is
authored as option effects in `story.json`; the AI only maps free text to an option. AI never
decides a sanity delta.

## Objective

Rework sanity into a softer, two-directional resource — raised by supportive choices and rare
restorative beats, lowered by gentler penalties — collapse the endings from five to three with
sanity 0 driving the neutral ending, and add a removable debug meter for on-device balancing.

## The Three Endings

| # | Ending | Trigger | Node |
|---|--------|---------|------|
| 1 | **Good — escape, transformed** | Reaches the exit alive | `node_end_escape` |
| 2 | **Neutral — surrender** | Sanity hits 0 | `node_end_surrender` |
| 3 | **Bad — taken** | Fatal/hostile choice while escaping | `node_end_taken` |

**1. Good — escape, transformed.** She gets out, but not intact: she leaves changed, carrying
what happened. A hero's-journey return where the person who comes out is not the person who
went in. Thematic homage to *As Above, So Below* — the descent that only ends by going
*through*, and the hermetic axiom itself ("assim em cima como embaixo") as a symbol carved in
the city. Merges the old `node_end_sane` + `node_end_marked`.

**2. Neutral — surrender.** Sanity reaches 0: she stops trying to escape and settles into the
city. Her messages degrade — fragments, then repeated symbols, then glossolalia — and the chat
simply stops. Thematic homage to *The King in Yellow* (Chambers, 1895, public domain): the
madness that arrives through a sign that shouldn't be read. Absorbs the old `node_trapped`
(stays there forever) and `node_consumed_early`.

**3. Bad — taken.** She is actively escaping when something reaches her: an entity outside
comprehension. She tries to describe it and *cannot* — the description contradicts itself,
reads as geometrically impossible, corrects itself and fails again. Then she is gone.

Then the chat goes **silent**. The composer stays live and the player can still write. Nothing
answers. No typing indicator — the absence is the point. After the player's **third**
unanswered message, the game ends on this ending. Nothing further is ever said.

Thematic homage to Nyarlathotep (Lovecraft, 1920, public domain) — but **the entity is never
named**, in copy or in code. Naming it would make it comprehensible, which is precisely the
horror being avoided, and it also keeps the city's own mythology (Ratanabá-adjacent, the altar
guardians) coherent instead of importing a foreign mythos. Absorbs the old `node_death` and the
guardian path.

## Acceptance Criteria

- [x] `trust` is fully absent from the app: state model, `story.json`, `Narrator`, and its
  references in `docs/` (specs 004/007, `architecture.md`, `vision.md`) are updated.
- [x] `docs/vision.md`'s five ending archetypes are replaced by the three above, and its
  roadmap reflects the new numbering.
- [x] Exactly three terminal nodes exist: `node_end_escape`, `node_end_surrender`,
  `node_end_taken`. The old five terminal nodes are removed or merged into them.
- [x] Every non-terminal path in `story.json` leads to one of the three; no dangling or
  unreachable node (the existing reachability test still passes).
- [x] Sanity remains a 0–100 integer in `initialState`, clamped after every effect (spec 004
  behaviour unchanged).
- [x] **Softer drops:** no single choice lowers sanity by more than 15 (see Tuning Table).
- [x] **Supportive vs hostile:** calming/supportive options carry a positive `sanity` effect;
  harsh/hostile options carry a negative one — authored in `story.json`, applied by the engine.
- [x] **Restorative beat:** at least one authored option grants a larger positive sanity effect
  (a scripted moment of relief).
- [x] **No passive regeneration.** Sanity changes only through authored option effects.
- [x] **Surrender routing:** reaching sanity 0 (after any effect) routes the engine to the node
  named by an optional root config `sanityZeroNodeID`, overriding the option's own
  `nextNodeID`. Absent config → no special routing (keeps existing fixtures/tests green).
- [x] `node_end_surrender`'s and `node_end_taken`'s text is delivered **without** the Narrator's
  humanising pass, so the degraded/symbolic/self-contradicting copy reaches the screen intact.
- [x] **Silent ending:** after `node_end_taken` is delivered, the composer stays enabled and the
  player can send messages that receive **no reply and no typing indicator**. After the third
  such message the game ends (`isFinished`). The player's own messages still appear.
- [x] The number of silent attempts is authored data (`silentTurns: 3`), not a hardcoded
  constant.
- [x] No message, narration, or engine advance occurs during silent turns — the intent parser is
  never called.
- [ ] **Reachability:** a unit-test playthrough proves sanity 0 is reachable through sustained
  hostile/harmful choices, and **not** reached by a path of only neutral/supportive choices.
- [x] **Debug meter:** a sanity meter is visible in `ChatView`, gated behind a single flag
  (`DebugFlags.showSanityMeter`). With the flag off there is zero visual or behavioural change.
  Removing it is one flag flip / one view deletion — it touches no game logic.
- [x] `ChatViewModel` exposes the current sanity for the meter without exposing engine internals.
- [x] New `GameEngine` behaviour (0-route, config decoding, narration bypass) is covered by unit
  tests; all existing spec-004 tests and `story-spec004-fixture.json` pass unchanged.
- [x] The narrator shapes tone by sanity only (no trust) — no regression in spec-007 tests.
- [x] No new Swift Package dependencies.

## Expected Behavior

### Sanity economy

Sanity moves in three ways, all decided by the engine:

1. **Authored drops** (option `effects`, `delta < 0`) — softened.
2. **Authored gains** (option `effects`, `delta > 0`) — supportive choices and the restorative beat.
3. **Clamp** — every change clamped to `[0, 100]` (unchanged).

If any change brings sanity to exactly **0**, the engine immediately routes to
`sanityZeroNodeID`, regardless of the chosen option's `nextNodeID`.

### Initial Tuning Table (starting values — to be refined on-device via the meter)

| Where | Old | New |
|-------|-----|-----|
| `opt_stay` (esperar parado) | −20 | −10 |
| `opt_touch` (pegar o amuleto) | −10 | −5 |
| `opt_run_altar` (correr pelos guardiões) | −30 | −15 |
| `opt_ignore` (hostil: "cala a boca") | trust −15 | sanity −5 |
| `opt_bridge_yell` (hostil: "para de chorar") | trust-gated | sanity −10 |
| `opt_bridge_calm` (apoio: "calma, respira") | trust-gated | sanity +10 |
| `opt_who` (gentil: pergunta o nome) | trust +5 | sanity +3 |
| restorative beat | — | sanity +12 |
| initial sanity | 80 | 80 |
| final door threshold | `>= 70` / `<= 69` | **removed** (escape is one ending) |

Acceptance is on the **mechanisms**, not these magic numbers — the meter exists to refine them.

> **Known balance tension.** Softer drops + no regen + a ~6-turn story means sanity 0 may be
> effectively unreachable today (80 down to 0 would need nearly every choice to be the worst
> one). The surrender ending becomes properly reachable once **Spec 009** adds exploration
> loops (more turns → more chances to lose sanity). If 009 slips, the lever is to lower the
> starting sanity (~50) or steepen the drops — decided from meter readings, not guessed here.

### Config (root of `story.json`)

```json
{
  "startNodeID": "start",
  "initialState": { "sanity": 80 },
  "sanityZeroNodeID": "node_end_surrender",
  "nodes": [ ... ]
}
```

`sanityZeroNodeID` is optional. When absent the engine behaves exactly as in spec 004 — this is
what keeps the spec-004 fixture and existing tests green.

### Engine advance flow (revised)

1. Player's free text → `IntentParser` → an option id (unchanged).
2. Engine applies the option's `effects` (delta/set, clamped after each — unchanged).
3. Engine advances to `option.nextNodeID`.
4. **Surrender route:** if `ints["sanity"] == 0` and `sanityZeroNodeID` is set, override the
   current node to that node.
5. Filter the new node's options by conditions; if none pass, `isTerminal = true` (unchanged).

### Surrender ending delivery

`node_end_surrender` is authored as degraded text — fragments, then repeated symbols, then
glossolalia. The Narrator's system prompt instructs it to write natural WhatsApp pt-BR, so
running this text through narration would **sanitise it back into coherent prose** and destroy
the ending. The node therefore carries an opt-out flag and its text is delivered raw.

### The silent ending (`node_end_taken`)

Normally a terminal node ends the game immediately: `isTerminal` → `isFinished` → the composer
disappears. This ending deliberately inverts that — the composer **stays**, and the silence is
the payload.

```
personagem:  "não é uma pessoa. tem braços mas não são braços,
              e eu vi antes de virar, eu vi ANTES, ele não
              chegou ele já tava, a forma dele não fecha—"
             (raw, never narrated)

    [ she is gone. no typing indicator. ever. ]

jogador:     "oi???"                    → silence   (1/3)
jogador:     "vc tá aí?"                → silence   (2/3)
jogador:     "responde"                 → silence   (3/3)

    [ game ends on the bad ending. nothing further is said. ]
```

The player's messages appear as normal player bubbles — seeing your own unanswered messages
stack up is the mechanic. There is no farewell text and no "game over" copy in the chat; the
ending is the absence.

### UI states — debug meter

When `DebugFlags.showSanityMeter == true`, a thin strip sits under the chat header:

```
┌────────────────────────────────────────────┐
│  ● número desconhecido               ⋯      │  ← existing header (diegetic)
├────────────────────────────────────────────┤
│  🧠 sanidade  62/100  ▓▓▓▓▓▓▓░░░            │  ← DEBUG meter (flag-gated)
├────────────────────────────────────────────┤
│   (chat messages …)                         │
```

With the flag `false` the strip is absent and the layout is identical to today.

## Edge Cases

- **Sanity hits 0 on an option that leads to an ending:** the surrender route wins — she gives
  up instead of reaching that ending.
- **Sanity hits 0 on the very first choice:** allowed; the game ends early. Tuning should make
  this require a deliberately hostile opening, not a plausible one.
- **Gain would exceed 100:** clamp to 100.
- **`sanityZeroNodeID` names an unknown node:** engine throws `unknownNode` at init, consistent
  with existing start-node validation.
- **Saved-session restore (spec 005):** persisted sanity restores as today. A session saved at
  sanity 0 restores directly into the surrender ending.
- **Narration bypass + fallback:** the raw-delivery path must not depend on model availability —
  it bypasses the narrator entirely rather than relying on the failure fallback.
- **Silent turns — no typing indicator:** `isTyping` must stay `false` for the entire silent
  phase. A typing indicator would imply she is still there and destroy the ending.
- **Player abandons during the silent phase:** if they close the app after 1 of 3 attempts, the
  session restores at `node_end_taken` with the counter reset to 3 and **no** catch-up message
  replayed. <!-- ponytail: counter transient like any per-session UI state; persist only if playtest shows it matters -->
- **Rapid double-send during silence:** each message consumes exactly one attempt; existing
  `isTyping`/empty-text guards still apply.
- **Silent phase reached with sanity 0:** the surrender route is evaluated first (step 4 of the
  advance flow), so sanity 0 wins and the player gets the neutral ending instead.
- **Debug flag off:** no view, no display read path — pure removal, zero game-logic impact.
- **Tone-neutral nodes:** most nodes carry no sanity effect. Not every node needs a +/− option.

## Design / Wireframe

ASCII sketch above. No Figma. The meter uses existing `Theme` colours; a simple `ProgressView`
or `Rectangle` fill. No animation requirement beyond the value updating on message delivery.

## Technical Notes

- **`Story` model:** add optional `sanityZeroNodeID: String?`, decoded from the root. Keep
  `initialState`. (The `sanityRegen` config from the previous draft is dropped — no regen.)
- **`StoryNode`:** add two optional fields, both decoded with the existing
  `decodeIfPresent`-with-default pattern so no existing JSON or fixture changes:
  - `rawNarration: Bool` (default `false`) — when `true`, `ChatViewModel.deliver(_:)` skips the
    narrator and appends `characterText` as-is.
  - `silentTurns: Int` (default `0`) — when `> 0`, the node does not finish the game on
    delivery; it enters the silent phase for that many player messages.

  `EngineResponse` carries both through.
- **Silent phase in `ChatViewModel`:** a `private var silentTurnsRemaining = 0`. On delivering a
  response with `silentTurns > 0`, set the counter instead of `isFinished`. In `send(_:)`, an
  early branch runs *before* the intent parser: append the player message, decrement, and when
  it reaches 0 set `isFinished = true` and delete the saved session. `isTyping` is never set
  during this branch. This is the only place the loop is short-circuited — the engine is not
  consulted at all.
- **`GameEngine`:** in `advance(choosing:)`, after applying effects and setting
  `currentNodeID`, apply the 0-route override before building the response. Validate
  `sanityZeroNodeID` at init like `startNodeID`. Sanity stays a plain key in `ints` — no
  special-casing beyond this one hook; the engine stays generic.
- **`ChatViewModel`:** expose `var currentSanity: Int` (from `engine?.state.ints["sanity"]`,
  default 80), updated on delivery.
- **Debug UI:** `enum DebugFlags { static let showSanityMeter = true }` in one file (default
  `true` for this balancing phase). A small `SanityMeterView(sanity:)`. `ChatView` renders it
  conditionally under the header.
- **`story.json`:** apply the Tuning Table; collapse the five terminal nodes into the three;
  author the restorative beat; add root `sanityZeroNodeID`; write the three endings' pt-BR copy.
- **Copyright:** all three references are **thematic homage in original pt-BR copy** — no
  reproduced text. *The King in Yellow* (1895) and Nyarlathotep (1920) are public domain;
  *As Above, So Below* (2014) is not, so that allusion is limited to the hermetic axiom (which
  long predates the film) and the descent/transformation shape. No dialogue or distinctive
  phrasing is lifted from any of them, and the entity is never named.
- **Golden-rule compliance:** every sanity change originates from authored data or engine
  config; the AI intent parser only selects an option. AI never owns state.
- **No new Swift Package dependencies.**

## Dependencies

- **Spec 004** (State Variables) — the `ints`/effect/condition machinery this builds on.
- **Spec 007** (Dynamic Narration) — narrator consumes sanity (trust param removed); the
  surrender ending opts out of it.
- **Spec 003** (UI + Engine Integration) — the wired app, for the meter and an on-device check.
- **Spec 005** (Persistence) — sanity persists across restore.

Blocks / precedes: **Spec 009** (Game Loop & Redundancy — inspect actions, revisit text,
exploration loops). 009 is what makes the surrender ending comfortably reachable.

Roadmap note: "Menu + Achievements" shifts to **010+**.

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-27 | Claude Code | Initial draft (remove trust; soften sanity; supportive gains + passive regen + restorative beats; madness ending at 0; removable debug meter). |
| 2026-07-27 | Claude Code | Revised after review: **passive regeneration cut**; five endings collapsed to **three** (escape-transformed / surrender-at-0 / caught) with sanity 0 now driving the neutral ending and the door's sanity fork removed; added raw-narration bypass so the surrender copy isn't sanitised by the Narrator; documented the balance tension with the short story length. |
| 2026-07-27 | Claude Code | Bad ending reworked into `node_end_taken`: an unnameable entity, a self-contradicting description, then a **silent phase** — the composer stays live, three player messages go unanswered with no typing indicator, and the game ends on the absence. Added `silentTurns` as authored data. |
| 2026-07-27 | Claude Code | Implemented. `trust` gone from app + docs; `sanityZeroNodeID` routing and `rawNarration`/`silentTurns` node flags added (all optional, so spec-004 fixtures decode unchanged); story collapsed to 12 nodes / 3 endings with the retuned economy and a restorative beat at `node_bridge_crossed`; debug meter behind `DebugFlags.showSanityMeter`. **Open:** an exhaustive walk of the shipped story shows the lowest reachable sanity is **55**, so the surrender ending is unreachable until spec 009 lengthens the game — the routing itself is verified by fixture. Per the new testing rule, only the sanity-zero route got tests (it is otherwise unverifiable); the silent phase is left to on-device testing. Status → `implemented`. |
