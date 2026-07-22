# AI-Assisted Development Guide

> Revised version — corrected writing and information verified against Anthropic's official documentation (docs.claude.com) and public sources for the other tools mentioned.

---

# LLM (Large Language Model)

An LLM is a model trained to predict text. It can understand natural language and generate code, explanations, and other forms of content. It is essentially the "brain" behind everything, adapting its responses based on the context provided by the user.

---

# Context Window

The Context Window is the maximum number of tokens an LLM can consider at one time. It defines **what information is available to the model while it reasons and generates responses.**

> **Correction:** Anthropic's rule of thumb is the opposite of what was originally written.

It is **not** true that "one quarter of a word equals one token."

Instead:

- **1 token ≈ 4 characters**
- Roughly **0.75 words per token in English**
- Languages like Portuguese generally consume more tokens per word because of longer words and accent marks.

When the context window becomes full, older information begins to disappear through a process often referred to as **context compaction**, which can lead to forgotten instructions or hallucinations.

Conversation history and AI memory also consume part of the available context window.

There are several techniques for optimizing token usage, including:

- Subagents
- Skills
- Context compaction

### Separate Context Windows

Yes—each Claude Code session has its own independent context window.

When a subagent is launched, it receives a completely fresh context window, performs its work independently, and only returns a summary to the parent session.

This is one of the primary mechanisms used to save context space.

*(If Igor meant something more specific, it's worth confirming with him.)*

---

# Chat

Chat is the simplest way to interact with an LLM.

You send messages.
The model returns responses.

In its purest form—a raw LLM without additional layers—it has:

- no tools
- no persistent memory
- no autonomy

It simply transforms input text into output text.

### Important nuance

This definition applies only to the underlying model.

Products such as **Claude.ai** add multiple layers on top of the model, including:

- Web search
- Persistent memory
- File creation
- Tool usage
- Other capabilities

Because of this, the distinction between a **Chat** and an **Agent** becomes less about the interface itself and more about **whether the model can autonomously use tools and perform actions.**

---

# Agent

An Agent follows a continuous decision-making loop:

```
Gather Context
        ↓
Take Action
        ↓
Verify Results
        ↓
Repeat
```

This behavior continues until the requested objective is achieved—or until the available context or tokens are exhausted.

An Agent is **a behavior**, not a product or tool.

This behavior is usually guided by Markdown files such as:

- `CLAUDE.md`
- Skills
- Subagents
- Other instruction files

These documents provide specialized context and significantly reduce hallucinations.

---

# Harness

A Harness is the infrastructure that allows an Agent to actually perform work.

It provides access to things such as:

- Terminal
- Source code
- External tools
- APIs
- File system
- Other execution environments

### Airplane analogy

The Agent is the pilot.

The Harness is the airplane.

A pilot knows how to fly, but without an airplane, there is nothing to operate.

Examples:

- **Claude Code** is Anthropic's official Harness for Claude models.
- **Google Antigravity** is a more generic, multi-model Harness. Besides Gemini, it also supports models from Anthropic and other providers.

---

# MCP (Model Context Protocol)

MCP is the standardized protocol that allows a Harness to communicate with external tools and data sources.

Its architecture is divided into:

- Host
- Client
- Server

For example, Xcode can expose its available capabilities to a Harness through MCP.

An MCP server can also connect to services like Figma, giving the Agent access to their resources.

Any tool can expose its own MCP interface.

### Token Cost

Each connected MCP server consumes context.

Because of that, it's generally better to keep enabled only the MCP servers that are actually needed during the current task.

> Personal note:
>
> In practice, using the Xcode MCP often isn't worth the overhead.
> Using `xcodebuild` directly through the command line is usually lighter and more efficient.

---

# RAG (Retrieval-Augmented Generation)

RAG combines **information retrieval** with **text generation**.

Instead of relying exclusively on the model's training data, the system searches for relevant information in real time and injects that information into the context window before generating a response.

This allows the model to answer questions about:

- Information it was never trained on
- Recently updated information
- Private company knowledge
- Internal documentation

Because the answers are grounded in retrieved evidence, RAG significantly improves factual accuracy.

# Skills

A Skill is a reusable package of specialized knowledge that an Agent follows to perform a specific task.

Think of it as a documented workflow or playbook that teaches the Agent **how** to accomplish something consistently.

Skills are designed to be reusable across multiple projects and tasks.

---

## Writing Good Skills

Skills are written entirely in **Markdown**, and Anthropic provides templates that help the model better understand their structure.

A well-written Skill includes a clear description.

That description acts as a **trigger**:

When the Agent determines that a Skill is relevant to the current task, it automatically loads it into the context.

Because of this behavior, Anthropic even provides its own **skill-creator** Skill to help generate new Skills from a standard template.

A Skill can describe:

- **How** something should be done.
- **When** it should be done.

---

## Recommended Structure

A Skill is a directory containing a primary `SKILL.md` file and any supporting resources.

```
skill-name/
├── SKILL.md
├── scripts/
├── references/
└── assets/
```

The main `SKILL.md` should contain only the instructions and description necessary for the model to understand when and how to use the Skill.

Supporting files—such as scripts, reference documents, and assets—should remain in subdirectories to avoid unnecessarily increasing the context size.

Multiple Skills can coexist as long as each one has its own directory.

---

## Improving Skills

Skills should evolve over time.

As you use them, refine them based on the Agent's behavior.

If the Agent repeatedly makes the same mistake, that's usually a good indication that a new Skill—or an update to an existing one—should be created.

> **Recommendation:** Write Skills in English whenever possible, since most foundation models perform better with English instructions.

---

# Progressive Disclosure

Progressive Disclosure is the mechanism that prevents the model from loading every Skill into the context window at once.

Initially, the model only sees:

- The Skill name
- Its description

The full contents of the Skill are loaded **only if the model determines they are relevant to the current task.**

This significantly reduces unnecessary context consumption.

A Skill can also be loaded explicitly by prompting the Agent to use it.

Example:

```
Use the iOS Architecture Skill.
```

---

# Plugins

A Plugin bundles multiple Agent components into a single installable package.

A plugin may include:

- Skills
- Hooks
- Subagents
- MCP Servers

Instead of configuring each component individually, a plugin installs everything at once.

One well-known example in the Claude Code community is **Superpowers**, which provides a collection of generic development Skills covering workflows such as:

- Brainstorming
- Writing Specs
- Test-Driven Development (TDD)
- Structured debugging
- Other engineering practices

Typical installation command:

```bash
/plugin install superpowers@claude-plugins-official
```

Plugins are essentially a convenient way to install pre-built Agent capabilities into your Harness.

---

# Hooks

Hooks are automatic event handlers.

They execute at predefined points during the Agent's lifecycle.

Examples include:

- Before a tool runs
- After a file is edited
- At the beginning of a session

Unlike Skills, Hooks are **deterministic**.

A Hook always runs when its triggering event occurs.

It does **not** depend on whether the model decides to use it.

---

# Subagents

Normally, you directly instruct the Harness.

A Subagent allows part of that work to be delegated to another specialized Agent.

Each Subagent receives:

- Its own isolated context window
- Its own permissions
- Its own tools
- Its own instructions

It performs the delegated work independently and returns only a summary to the parent Agent.

This dramatically reduces context consumption in the main conversation.

Subagents are useful for:

- Specialized research
- Running dedicated Skills
- Parallelizing work
- Delegating independent tasks

---

# Workflows

Unlike a Skill, which describes how to perform a single task, a Workflow coordinates multiple tasks and Skills into a larger process.

A Workflow may be:

- **Implicit**, allowing the Agent to decide the execution order.
- **Explicit**, where the Agent asks for confirmation before each step.

---

## Clarification

Two different concepts are often confused.

### Workflow (general software engineering)

A Workflow is simply the overall sequence of work required to accomplish an objective.

This is what the original explanation described.

---

### Claude Code Workflows

Claude Code also has a feature called **Workflows**.

This feature automates repetitive operations across many files.

Example:

> Fix this same issue across 50 files.

These workflows can later be reused.

---

## What is `CLAUDE.md`?

`CLAUDE.md` is **not** a workflow orchestrator.

Instead, it is a persistent project instruction file.

It is automatically loaded at the beginning of every Claude Code session before any user prompt.

Typical contents include:

- Project conventions
- Architecture decisions
- Build commands
- Coding standards
- Development guidelines

Its purpose is to provide context—not to decide task execution order.

---

## Recommended Size

Anthropic recommends keeping `CLAUDE.md` below **approximately 200 lines**.

Longer files consume more context in every session, reducing the model's ability to consistently follow all instructions.

When the file grows too large, move specialized rules into:

```
.claude/rules/
```

These rules are loaded only when relevant, reducing unnecessary context usage.

The Superpowers plugin also includes Skills that demonstrate this style of structured workflow organization.

# Specs

A Spec defines exactly **what should be built**.

It is conceptually similar to a **User Story**, describing the intended outcome, scope, and acceptance criteria for a feature.

A typical Spec includes:

- Feature name
- Expected outcome
- What's explicitly out of scope
- Acceptance criteria

If you're unsure how detailed a Spec should be, ask yourself:

> "If I were writing a User Story for this feature, what would it contain?"

The answer is usually your Spec.

In practice, every feature in a project can have its own Spec.

Some teams even use dedicated Agents to generate Specs that align with the project's architecture and conventions.

In certain organizations, Specs become the actual development tasks stored directly inside the repository.

---

## Progressive Disclosure and Specs

Unlike Skills, Specs are **not automatically loaded** through Progressive Disclosure.

The Agent must be explicitly instructed to use one.

For example:

> Implement the feature described in `docs/specs/login.md`.

Although writing a Spec is similar to writing a long prompt, a Spec provides much more detail and becomes reusable documentation.

A common project structure is:

```
docs/
└── specs/
```

A large Spec can describe an entire User Story, while smaller Specs derived from it can represent individual implementation tasks.

Because of this, Specs are often committed to version control as living documentation.

Typical workflows include:

### Scenario 1

You brainstorm the solution together with the Agent, then write the Spec collaboratively.

### Scenario 2

The Spec already exists, and you simply instruct the Agent to use it as the implementation input.

---

# Spec-Driven Development (SDD)

Spec-Driven Development is the practice of writing specifications **before writing code**.

Instead of jumping directly into implementation, the development process starts with clear, structured documentation describing the intended behavior.

This methodology has become increasingly popular in AI-assisted software development, with several open-source tools specifically designed around this workflow.

---

# Prompt Engineering

Prompt Engineering is essentially about providing the right amount of context.

### Poor Prompt

A vague or overly broad request.

Example:

> Build a login screen.

---

### Good Prompt

A request with clear objectives and constraints.

Example:

> Build a SwiftUI login screen using MVVM architecture, supporting email/password authentication, following the project's design system.

---

### Excellent Prompt

The best prompt is often surprisingly short.

Example:

> Implement the authentication feature.

Why?

Because all of the surrounding context already exists in:

- `CLAUDE.md`
- Skills
- Specs
- Rules
- Project documentation

Instead of repeating instructions every time, the Agent already knows how your project works.

---

## Layers of Prompt Engineering

Think of Prompt Engineering as layers of reusable context.

```
Prompt
↓
Immediate request

Spec
↓
Rules for one feature

Skill
↓
Reusable knowledge across multiple features

CLAUDE.md
↓
Persistent project-wide context
```

The higher the layer, the less information you need to repeat in future prompts.

---

# Vibe Coding

Vibe Coding describes a style of development where the programmer relies heavily on an LLM to make implementation decisions with minimal manual review.

Instead of carefully validating each change, the developer trusts the Agent to decide:

- What to build
- How to build it
- When to perform each step

A common joke in the community is:

> "This is where the app dies."

The joke reflects the risk of shipping software that the developer hasn't actually understood or validated.

In its most common usage, **Vibe Coding** refers to trusting the generated output without performing careful code review.

This stands in contrast to methodologies such as:

- Test-Driven Development (TDD)
- Spec-Driven Development (SDD)

Both of these approaches introduce verification checkpoints throughout the development process, encouraging developers to validate each step rather than blindly accepting generated code.

---

# Review Notes (Summary of Factual Corrections)

## 1. Tokens and Words

The original explanation inverted the relationship between words and tokens.

Anthropic's rule of thumb is:

- Approximately **4 characters per token**
- Roughly **0.75 words per token in English**

Not:

> One quarter of a word equals one token.

---

## 2. `CLAUDE.md` Size

The official recommendation is to keep `CLAUDE.md` below **approximately 200 lines**, not 80.

---

## 3. `CLAUDE.md` Is Not a Workflow Orchestrator

`CLAUDE.md` should be viewed as a persistent project instruction file that is automatically loaded at the beginning of every Claude Code session.

Its purpose is to provide project context, not orchestrate workflow execution.

---

## 4. Google Antigravity

Google Antigravity is correctly described as a multi-model, agent-first Harness.

It supports Gemini models as well as models from Anthropic and OpenAI.

The comparison with Claude Code is accurate.

---

## 5. Superpowers

Superpowers is a real and widely recognized Claude Code plugin.

The installation command referenced in the original document matches the publicly documented version.

---

# Final Takeaway

Modern AI-assisted development is less about writing increasingly complex prompts and more about building reusable layers of context.

A mature project typically evolves toward a structure like this:

```
Project
├── CLAUDE.md
├── .claude/
│   ├── rules/
│   ├── skills/
│   ├── hooks/
│   └── subagents/
├── docs/
│   └── specs/
└── source code
```

As these layers become more complete, prompts naturally become shorter.

Instead of explaining *how* something should be implemented every time, you simply describe *what* you want, and the Agent combines the project's accumulated knowledge to determine the implementation details.

This shift—from prompt-centric development to context-centric development—is one of the defining ideas behind modern AI-native software engineering.