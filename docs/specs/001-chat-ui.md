# Spec 001 — Chat UI

## Status
`approved`

## Context

DarkDive is played entirely through a chat conversation with an anonymous stranger trapped
in a city outside of time. The chat interface is not a wrapper around the game — it *is*
the medium the fiction is delivered through, so its credibility carries the immersion.

Before building the game engine, we need to prove the format works: that a messaging UI
with inline choices feels like a real conversation rather than a game menu. This spec
isolates that question by building the UI alone, with mocked data and no engine behind it.

## Objective

Deliver a single dark, WhatsApp-like chat screen with message bubbles, inline option
buttons, a typing indicator, and auto-scroll — driven entirely by hardcoded mock data.

## Acceptance Criteria

- [ ] A single chat screen renders a scrollable list of messages
- [ ] Player messages and chat-character messages are visually distinct (alignment and
      bubble color)
- [ ] The visual style is dark: black / dark-grey background, subtle timestamps
- [ ] Each message shows a subtle timestamp
- [ ] Option buttons appear inline, below the chat character's latest message
- [ ] Tapping an option turns it into a sent player message, as if the player had typed it
- [ ] After a choice, the option buttons disappear until the next character message arrives
- [ ] The character's reply arrives after a delay of 1–3 seconds
- [ ] A "typing…" animation (three pulsing dots) is shown during that delay
- [ ] The list auto-scrolls to the newest message after every new message
- [ ] All content is mocked/hardcoded — no game engine, no JSON, no AI
- [ ] There is no free-text input field

## Expected Behavior

### Main Flow

1. The screen opens showing the conversation's opening state.
2. The typing indicator appears; after 1–3 seconds the chat character's first message
   is appended.
3. Option buttons for that message appear inline beneath it.
4. The player taps an option.
5. The option button set disappears, and the option's text is appended as a player
   message (right-aligned, player bubble color).
6. The typing indicator appears again.
7. After 1–3 seconds the chat character's next message is appended, followed by its
   option buttons.
8. Steps 4–7 repeat through the mocked conversation.
9. The list auto-scrolls to the bottom after each append.

### UI States

| State | Behavior |
|-------|----------|
| **Idle** | Message list rendered; option buttons visible and tappable |
| **Typing** | Typing indicator visible at the bottom; option buttons hidden; taps ignored |
| **Terminal** | End of the mocked conversation: no options rendered, no typing indicator |

There is no loading state (nothing is fetched) and no error state (nothing can fail) in
this spec.

## Edge Cases

- **Rapid double-tap on an option:** only the first tap registers; input is ignored while
  in the Typing state.
- **Long option text:** buttons wrap to multiple lines rather than truncating.
- **Long message text:** bubbles wrap and grow vertically, capped at a maximum width
  (~75% of screen width) so sender alignment stays readable.
- **Many options on one node:** the option area scrolls or stacks vertically rather than
  overflowing the screen.
- **End of mocked conversation:** the screen stays on the last message with no options
  and no typing indicator; the app does not crash or hang.
- **Backgrounding during the typing delay:** on return, the pending message is delivered
  rather than lost.
- **Dynamic Type / small devices:** layout remains usable at larger text sizes.

## Design / Wireframe

Dark WhatsApp-like aesthetic. No Figma file yet — textual reference:

```
┌─────────────────────────────────┐
│  ● unknown number          ⋮    │  ← minimal header
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────┐      │
│  │ tem alguém aí?        │      │  ← character bubble (left, dark grey)
│  │                 03:14 │      │
│  └───────────────────────┘      │
│                                 │
│           ┌──────────────────┐  │
│           │ quem é você?     │  │  ← player bubble (right, accent)
│           │            03:14 │  │
│           └──────────────────┘  │
│                                 │
│  ┌───────────────────────┐      │
│  │ ● ● ●                 │      │  ← typing indicator
│  └───────────────────────┘      │
│                                 │
├─────────────────────────────────┤
│  [ não sei onde estou       ]   │  ← inline option buttons
│  [ me ajuda                 ]   │
└─────────────────────────────────┘
```

- Background: black / very dark grey
- Character bubble: dark grey, left-aligned
- Player bubble: accent color, right-aligned
- Timestamps: small, low-contrast, inside the bubble
- No free-text composer bar — options replace it

In-game copy is **pt-BR**; code and identifiers are English.

## Technical Notes

- SwiftUI, iOS 17+, MVVM with `@Observable` (see [`AGENTS.md`](../../AGENTS.md)).
- Suggested structure:
  - `ChatView` — screen scaffold, `ScrollViewReader` + `ScrollView` / `LazyVStack`
  - `MessageBubble` — one message, styled by sender
  - `TypingIndicatorView` — three pulsing dots
  - `OptionButtonsView` — inline option list
  - `ChatViewModel` — `@Observable`; owns `messages`, `currentOptions`, `isTyping`
  - `ChatMessage` — `id`, `text`, `sender` (`.player` / `.character`), `timestamp`
- Mock conversation lives in a single hardcoded fixture inside the view model or a
  dedicated `MockConversation` type — kept in one place so spec 002/003 can swap it for the
  engine without touching the views.
- Views must stay dumb: no timing or narrative logic in the view layer. The view model
  owns the delay and the state transitions.
- Auto-scroll via `ScrollViewReader.scrollTo(_:anchor:)` with animation, triggered on
  message append.
- Delay implemented with `Task.sleep`, cancellable, so a backgrounded or dismissed view
  does not leave dangling work.
- Colors and spacing centralized (asset catalog / a small theme type) — the whole app is
  this one aesthetic.
- No new dependencies.

## Dependencies

None. This is the first spec and stands alone.

Downstream: spec 002 (Game Engine) and spec 003 (UI + Engine Integration) build on this
screen; the mock data boundary defined here is what spec 003 replaces.

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-07-20 | Antigravity + Richard | Initial creation from the /grill-me design session |
| 2026-07-20 | Claude Code | Filled from session decisions; status → `approved` |
