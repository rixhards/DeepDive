# Spec 009 — Game Loop & Redundancy

## Status
`implemented` — **superseded by [ADR-002](../adr/ADR-002-world-simulation-in-swift.md)**

> The JSON dialog tree this spec describes was replaced by a Swift world simulation on 2026-07-28. The spec's *intent* still holds; its implementation details no longer match the code. Kept as a record of how the project got here.

## Context

Spec 008 left the game with a sound state layer and three endings, but the node graph is still
a strictly forward dialog tree: every option advances to a different node, and the character
can only ever say the node's one line. Two things break because of that.

**"Olha ao redor" doesn't work.** There is no way to author an action that answers in place.
Asking her to describe the room, to check an item, or just asking if she's okay has nowhere to
land — it falls through to `.clarify` ("não entendi"), which reads as the character being
broken in a game whose entire premise is that she understands you.

**There is no exploration.** The graph has never contained a cycle, so there is no backtracking,
no locked door you return to with a key, no reason to look before moving. Every playthrough is
a straight line of 5 turns.

The story being authored for this spec (see `docs/decisions/`) opens with an explicit rule:

> Toda escolha que não leva a outra cena deve manter o personagem no mesmo lugar e contexto.

That rule is the feature this spec exists to build. Alongside it, the authored content needs
multi-message sequences (the infinite corridor plays out over several beats with no player
input), several distinct death scenes that all resolve to the same ending, and a way to replay
without force-quitting the app.

**Scope discipline:** three capabilities that looked necessary in earlier analysis were cut
after checking what already works — see "Deliberately Not Built".

## Objective

Give the engine stay-in-place actions, multi-beat sequences, and ending identities so the
authored story can have real exploration loops, and let the player see which ending they
reached and start over.

## Acceptance Criteria

### Stay-in-place actions

- [x] `StoryOption.nextNodeID` becomes optional. An option with no `nextNodeID` must carry
  `responseText`; the engine replies with it and **leaves `currentNodeID` unchanged**.
- [x] Exactly one of `nextNodeID` / `responseText` is present on every option; a node that
  violates this fails validation at engine init with a clear error.
- [x] A stay-in-place option still applies its `effects` and is still filtered by its
  `conditions`, exactly like a moving option.
- [x] After a stay-in-place option, the node's full option set is offered again (minus anything
  its effects just gated out) — the player can keep acting in the same place.
- [x] The response is narrated normally (subject to `rawNarration`), and the typing delay scales
  to it as usual.

### Multi-beat sequences

- [x] `StoryNode.beats: [String]` (default `[]`) holds extra messages delivered **after**
  `characterText`, in order, each as its own chat message with its own typing delay.
- [x] No player input is accepted while beats are being delivered; the composer is disabled and
  the typing indicator runs between them.
- [x] A node with `beats` and no options plays its sequence and then ends the game — this is how
  the infinite corridor and the water creature resolve.
- [x] Beats respect `rawNarration` and `silentTurns` on their node.

### Ending identity

- [x] `StoryNode.ending: String?` names which of the three endings a terminal node resolves to
  (`escape`, `surrender`, `taken`).
- [x] **Any number of terminal nodes may share an ending id.** `taken` is explicitly a wildcard
  for alternative deaths (fire, asphyxiation, the corridor, the water) that need no lore of
  their own. This revises spec 008's "exactly three terminal nodes" criterion — the invariant is
  now *exactly three ending identities*.
- [~] Every terminal node declares an `ending`; a terminal node without one **logs a warning** rather than failing validation — a hard throw would break every test fixture that builds a throwaway terminal node, which the General criterion forbids. The shipped story is enforced by the lint script instead.
- [x] `EngineResponse` exposes the reached ending so the UI can name it.

### Terminal-trap detection

- [x] A node is terminal because it has **no authored options**, not because its options were
  all gated out by conditions.
- [x] If a node has authored options but none pass their conditions, the engine logs a loud
  authoring error and ends the game gracefully rather than hanging.
- [x] A validation pass over `story.json` reports any node whose options are *all* conditional
  (no unconditional escape) — a dead-end risk once loops exist.

### Restart

- [x] When the game ends, the chat shows which ending was reached and a **"recomeçar"** control.
- [x] "Recomeçar" resets engine state, clears the messages, deletes any saved session, and starts
  a fresh run without relaunching the app.
- [x] The ending reveal does not appear mid-game, and does not appear during
  `node_end_taken`'s silent turns — only once the run is genuinely over.
- [x] "Voltar ao menu" is **out of scope** here: there is no menu yet. It lands in spec 010
  alongside the menu itself.

### General

- [x] All new fields are optional with defaults, so existing `story.json`, the spec-004 fixture,
  and existing tests decode and pass unchanged.
- [x] No new Swift Package dependencies.

## Expected Behavior

### Stay-in-place flow

```
node_salao  ── "descreve o ambiente"  (no nextNodeID)
              → she describes it, sanity +2, still in node_salao
           ── "você tá bem?"          (no nextNodeID)
              → she answers, sanity +3, still in node_salao
           ── "vai pela estrada"      (nextNodeID: node_trifurcacao)
              → moves
```

### Anti-farming pattern (authoring, not engine)

A stay-in-place option that grants sanity can otherwise be spammed forever. This is solved with
a flag and a second, wearier response — **not** with duplicate "sibling" nodes, which would
multiply combinatorially with every stay-in-place action a scene has:

```json
{ "id": "opt_ok_first", "responseText": "tô... acho que tô. só não para de falar comigo",
  "conditions": [{ "var": "asked_ok", "op": "eq", "value": false }],
  "effects": [{ "var": "asked_ok", "set": true }, { "var": "sanity", "delta": 3 }] },

{ "id": "opt_ok_again", "responseText": "já te disse que tô. ou tô mentindo. não sei mais",
  "conditions": [{ "var": "asked_ok", "op": "eq", "value": true }] }
```

Same `text`/`hints` on both, so intent matching is unaffected. The repeat costs nothing and
reads better than a refusal. The same two-entry pattern covers "não fazer nada" escalating into
a death on the second try — no counter primitive needed.

### Items surface themselves

Per the design note that the *character* should raise the idea of using an item, item mechanics
are authored as her observations plus stay-in-place actions — never as a hidden verb the player
must guess:

- She names the affordance in her own words: *"a luz do lampião não alcança nada lá dentro. é
  como se as sombras fugissem dela e esticassem o corredor."* — that sentence is what makes
  "apaga o lampião" occur to the player.
- Lighting/extinguishing, checking what she's carrying, and feeling around the floor are all
  stay-in-place options, so they cost a turn but never a wrong turn.
- Item-consuming options are `conditions`-gated on possession, so an option she can't perform
  is never offered.

### Sequence flow (the corridor)

```
characterText: "tá bem escuro aqui dentro. vou me apoiar na parede"
beats: [ "já faz um tempo que eu tô andando e não chega no fim",
         "tem um som vindo da frente. tipo respiração mas errada",
         "eu voltei. eu VOLTEI e continua o mesmo corredor",
         "agora vem dos dois lados",
         "não dá pra tapar os ouvidos o suficiente" ]
options: []           → sequence plays, then the ending
ending: "taken"
```

### Ending reveal + restart

When a run ends, a card appears below the transcript naming the ending (pt-BR, e.g. *"final:
levada"*) with a **recomeçar** button. The transcript stays readable behind it — the player
should be able to scroll back over what they caused.

## Edge Cases

- **Option with neither `nextNodeID` nor `responseText`, or with both:** engine init throws with
  the offending option id.
- **Stay-in-place option whose effects gate itself out:** allowed; it simply isn't offered again.
- **All options gated out after a stay-in-place action:** treated as the authoring error above,
  not a silent ending.
- **Beats on a node that also has options:** beats play first, then options are offered.
- **App backgrounded mid-sequence:** the delivery task is cancelled as today; on restore, the
  node is re-delivered from the start of its sequence.
- **Restart during the silent phase:** the reveal (and its button) only appear after the silent
  turns are exhausted, so the ending cannot be short-circuited.
- **Restart mid-game:** not offered. Only reachable from a finished run in this spec.
- **Sanity 0 during a sequence:** the surrender route is evaluated on `advance`, before the
  sequence plays, so it wins as usual.

## Design / Wireframe

```
│   (transcript …)                            │
│   personagem: não dá pra tapar os ouvidos   │
├─────────────────────────────────────────────┤
│            final: levada                    │
│          [    recomeçar    ]                │
└─────────────────────────────────────────────┘
```

Replaces the composer, which is already hidden when the run is finished. Uses existing `Theme`
colours; no new visual language.

## Technical Notes

- **`StoryOption`:** `nextNodeID: String?`, new `responseText: String?`. Validate the
  exactly-one rule in `GameEngine.init` while it already walks every node for dangling links.
- **`GameEngine.advance(choosing:)`:** when the chosen option has no `nextNodeID`, apply effects
  and return a response built from the *current* node but carrying `responseText` as
  `characterText`. `currentNodeID` is untouched, so the loop is inherent — no cycle bookkeeping.
- **`StoryNode`:** `beats: [String]` (default `[]`), `ending: String?`. Keep using
  `decodeIfPresent(...) ?? default` so nothing existing breaks.
- **`EngineResponse`:** carries `beats` and `ending`.
- **`ChatViewModel.deliver(_:)`:** after appending the main message, iterate `beats`, each with
  its own `typingDelay` and typing indicator, honouring `Task.isCancelled` between them.
- **Restart:** a `reset()` on `ChatViewModel` that rebuilds the engine from `engineProvider`,
  clears `messages`, resets `isFinished`/`silentTurnsRemaining`/`currentEngineOptions`, deletes
  the session, and re-runs `start()`'s first delivery. `hasStarted` must be cleared too.
- **Ending names:** the pt-BR label shown to the player is UI copy keyed off the `ending` id —
  the id itself stays English like every other identifier.
- **Validation script:** the story-graph checks (dangling links, unreachable nodes, terminal
  nodes missing `ending`, all-conditional option sets) run as a throwaway script over
  `story.json` rather than as a permanent test — per the project's testing rule.

## Deliberately Not Built

Three capabilities from the earlier analysis were dropped after checking what the existing
system already covers. Each is cheap to add later if playtesting proves it necessary.

- **Revisit text** (a node saying something different on return). The `Narrator` already
  receives the full message history and rephrases every delivery, so returning to a room does
  not produce a verbatim repeat — and re-describing the fork on return is useful to the player
  anyway. <!-- ponytail: add revisitText only if on-device replay actually reads as robotic -->
- **A repeat-counter primitive.** The flag pattern above expresses "second time is fatal" with
  authored data and no engine state.
- **`effectsOnce` on options.** Same reason — and the authored version yields better writing
  (a tired second answer) than a silently ignored effect. <!-- ponytail: if this pattern shows up more than ~6 times in the story, add effectsOnce + a persisted used-option set -->

## Dependencies

- **Spec 008** (Sanity Rework) — the ending identities extend its three-ending model; the
  `rawNarration`/`silentTurns` flags interact with beats and the reveal.
- **Spec 003** (UI + Engine Integration) — the wired chat this modifies.
- **Spec 005** (Persistence) — restart must clear the saved session.

Blocks: **Spec 010** (Menu + Achievements), which adds the menu, "voltar ao menu", and the
endings gallery that `ending` ids make possible.

## Open Questions

- **Authored content is not part of this spec.** The three scenes drafted so far reach only
  `taken`; the paths to `escape` and to sanity-0 `surrender` are still being written. This spec
  builds the capabilities; the story lands with it or after it.
- **Per-beat sanity effects** are not supported — a sequence's sanity cost is applied by the
  option that entered it. If the gradual on-screen drain matters for tone, beats would need
  their own effects. <!-- ponytail: text-only beats until the meter shows it matters -->

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-28 | Claude Code | Implemented. `StoryOption.nextNodeID` optional + `responseText`; `StoryNode.beats`/`ending`; terminal now means "no authored options" with a loud log when conditions strand the player; `restart()` + `EndingRevealView`. Added a minimal in-place demo at `node_where` (look around / are you ok, with the anti-farm pattern) so the feature is testable on device. Story lint lives in the scratchpad, not the test target. |
| 2026-07-27 | Claude Code | Initial draft from the authored scenes 1–3 and the "stay in place" rule. Scoped to four engine capabilities plus restart; explicitly rejected the sibling-node approach to anti-farming (combinatorial) in favour of an authored flag pattern, and cut revisit text / repeat counters / `effectsOnce` as already-covered. Awaiting review. |
