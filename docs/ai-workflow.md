# How DeepDive Uses AI

> A short, accurate reference for how this project is built with AI assistance. It corrects
> and condenses the class notes in `docs/decisions/ai-assisted-development-guide.md`
> and, crucially, only describes things that are **actually set up in this repo**.
>
> If a concept is useful *in general* but not used here yet, it's marked **(not used yet)**
> so you don't go looking for something that doesn't exist.

## The core idea

We build with **Spec-Driven Development (SDD)**: write a clear specification *before* the
code, so the AI implements against a contract instead of guessing. This is the opposite of
**vibe coding** (letting the AI decide everything and shipping without review). The whole
setup below exists to make good, specific prompting cheap: once the context is in place, you
can say "implement spec 001" and the right thing happens.

## The building blocks (as used here)

### CLAUDE.md — persistent project context
The single most important file. Claude Code reads it automatically at the start of **every**
session, before your first message. It holds the stable facts: what the project is, the
rules, the stack, conventions. It is **not** an orchestrator — it doesn't decide task order,
it just gives context. Keep it under ~200 lines; longer files dilute the model's attention.
`AGENTS.md` is a symlink to it so other tools (Antigravity) read the same thing.

### Specs — the contract for one feature
A spec is like a User Story with acceptance criteria: what to build, what's out of scope,
and how we'll know it's done. Each lives in `docs/specs/NNN-name.md`, made from
`_template.md`. A spec is versioned by status: `draft → review → approved → implemented`.
Specs are committed to the repo as living documentation. A big spec can be broken into
smaller ones. **A spec is only implemented when you explicitly point the AI at it** — specs
are not auto-loaded.

### Skills — reusable procedures
A skill is a folder in `.claude/skills/<name>/` containing a `SKILL.md` with YAML
frontmatter (`name`, `description`) and a step-by-step procedure. Because of **progressive
disclosure**, Claude Code initially sees only the name + description; it loads the full
`SKILL.md` only when the description matches what you're doing (or when you ask for it by
name). That's why the description must clearly say *when* to use the skill. Write skills in
English — models follow English instructions more reliably.

This repo has one: **`generate-spec`** (creates a new spec from an idea). Larger skills can
add `scripts/`, `references/`, `assets/` subfolders to keep the main `SKILL.md` short.

> Skills only work if they live in `.claude/skills/`. The old copies were in `.agents/skills/`,
> which Claude Code does **not** scan — so they were documentation, not working skills. Fixed.

### Subagents — an isolated helper
A subagent runs a delegated task in its **own, clean context window** and returns only a
summary — this keeps the main conversation's context from filling up, and lets work run in
parallel. Subagents live in `.claude/agents/<name>.md`.

This repo has one: **`spec-reviewer`** (checks an implementation against a spec's acceptance
criteria and reports pass/fail). Reviewing in a subagent means the review's file-reading
doesn't clog your main session.

### ADRs — architecture decision records
When a decision has long-term structural consequences (e.g. "local FSM instead of AI-driven
narration"), record it in `docs/adr/` from the template. This is *why* we chose something,
kept for future-you.

## Concepts from the notes that we deliberately don't use (yet)

- **RAG (Retrieval-Augmented Generation)** — fetching from an indexed knowledge base at
  runtime. **Not used, and not planned for the app.** DeepDive is an offline single-player
  game with no backend; there's nothing to retrieve. And for *development*, "search the
  project's knowledge" just means Claude Code reading the `docs/` folder directly — no vector
  store, embeddings, or `rag-query` skill needed. (The old `rag-query` skill was removed
  because it described infrastructure that doesn't exist.)
- **MCP (Model Context Protocol)** — the standard way a harness talks to external tools
  (Figma, a database, etc.). **(not used yet.)** If we ever wire up Figma for the chat UI
  design, that's where MCP would come in. Note: for builds we prefer `xcodebuild` on the
  command line over an Xcode MCP — lighter, fewer tokens.
- **Hooks** — deterministic scripts that fire at fixed lifecycle points (e.g. run a
  formatter after every edit). **(not used yet.)** Useful later for auto-formatting or
  running tests; nothing needs them today.
- **Plugins** (e.g. Superpowers) — bundles of skills/hooks/subagents installed together.
  **(not used yet.)** We're keeping the setup minimal and hand-made so it's understandable.

This list is about *development-tooling* concepts (how Claude Code/Antigravity work), not
the shipped app's own AI feature. The game's runtime AI (`IntentParser` + `Narrator`, both
Foundation Models, Specs 006–007) **is** implemented — see `docs/architecture.md`'s "AI /
Agents" section — and is a separate concern from the list above.

## Corrections to the class notes (`ai-assisted-development-guide.md`)

The notes are mostly right; these factual points were off:

1. **Tokens ↔ words:** the ratio was inverted. Anthropic's rule of thumb is **~4 characters
   ≈ 1 token** (≈ 0.75 words per token in English), *not* "¼ of a word = 1 token".
   Portuguese tends to spend slightly more tokens per word (accents, longer words).
2. **CLAUDE.md length:** the guideline is **under ~200 lines**, not 80.
3. **Harness:** it means the *infrastructure that gives the model access to a terminal,
   tools, and code* — the "airplane" the model "pilots". Claude Code and Antigravity **are**
   harnesses. It does **not** mean "testing/QA infrastructure" (that's a *test* harness, an
   unrelated use of the word). The earlier `docs/harness/` file defined it wrongly and was
   removed.
4. **CLAUDE.md is not an orchestrator** — it's persistent context loaded up front, not a
   thing that decides execution order.

## A day in the workflow

1. Have an idea → discuss with Antigravity → (if big) note it in `docs/decisions/`.
2. Turn it into a spec: `generate-spec` skill → `docs/specs/NNN-name.md` → refine → mark
   `approved`.
3. In Claude Code: *"Implement spec NNN."* It reads `CLAUDE.md` + the spec and codes it.
4. Review with the `spec-reviewer` subagent against the acceptance criteria.
5. Commit. Mark the spec `implemented`. Repeat.
