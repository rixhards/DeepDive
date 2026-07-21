---
name: generate-spec
description: Create a new Spec-Driven Development spec file in docs/specs/. Use when the user wants to turn a feature idea, PRD, or request into a structured spec with acceptance criteria before any code is written.
---

# generate-spec

Turn a feature idea into a complete SDD spec at `docs/specs/NNN-feature-slug.md`.

## When to use

The user describes a new feature ("I want the player to be able to…", "add a settings
screen", "let's build the game engine") and there is no spec for it yet. Specs come **before**
implementation.

## Steps

1. **Read the template** at `docs/specs/_template.md` — the new spec must match its sections.
2. **Pick the number.** List `docs/specs/`, find the highest `NNN`, use the next one
   (zero-padded, e.g. `002`). Slug = kebab-case feature name (e.g. `game-engine`).
3. **Gather context** so the spec aligns with the project:
   - `docs/vision.md` — is this in scope? (Check the "Out of Scope" list.)
   - `docs/architecture.md` — which layer does it touch?
   - Existing specs in `docs/specs/` — keep style and dependencies consistent.
4. **Write the spec**, filling every section:
   - **Status:** `draft`.
   - **Context:** why this feature exists, what problem it solves.
   - **Objective:** one sentence on what it delivers.
   - **Acceptance Criteria:** checkable, specific, verifiable — never vague. Each should be
     something you could test or demo.
   - **Expected Behavior:** main flow + UI states if relevant.
   - **Edge Cases:** errors, empty/limit states, rapid input, backgrounding, etc.
   - **Design / Wireframe:** link or ASCII sketch if UI.
   - **Technical Notes:** how to implement within our stack (SwiftUI, MVVM `@Observable`,
     iOS 17+, no new dependencies).
   - **Dependencies:** which specs must exist first.
   - **Revision History:** initial row.
5. **Save** to `docs/specs/NNN-feature-slug.md`.
6. **Report** the path and a two-line summary. Remind the user the spec is `draft` and needs
   review/approval before implementation.

## Quality bar

- Every acceptance criterion is verifiable, not vague ("shows a typing indicator during the
  1–3s delay", not "feels responsive").
- Edge cases are listed, not skipped.
- Nothing is invented that contradicts `docs/vision.md` (especially the Out-of-Scope list)
  or the golden rules in `CLAUDE.md`.
- In-game copy examples are pt-BR; everything else is English.

## Do not

- Do not write implementation code — this skill only produces the spec.
- Do not mark a new spec `approved`; that's a human decision.
