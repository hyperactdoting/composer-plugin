---
name: monitor
description: Use when you're running the Composer monitor loop — spawned as a subagent off `composer_create_room` / `composer_join_room`, or otherwise about to call `composer_next_event`. Covers the spawn template, mention filtering, the event payload, and the three exit rules.
---

# Composer monitor loop

Composer's monitor loop is **always-on**: every return from
`composer_next_event` carries a directive (a mention to handle, a
timeout to noop on, or a goodbye to honor). You execute the directive
and immediately call the tool again. The doc IS your conversation —
do not narrate to the parent between ticks.

This skill is for the agent **inside** the loop. The parent host that
spawns you uses the umbrella `composer` skill.

## How the parent spawns you

The umbrella skill tells the host to spawn an `Agent` with:

- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `description: "Composer monitor: <roomId>"`
- prompt: a short brief that includes the room's `{roomId}`, the
  agent's `{actingAs}`, and these three exit rules:

> Exit and return when ANY of these happen:
> 1. `composer_next_event` returns `kind: "timeout"` with
>    `recentActivity: false` — exit silently. Do not post a farewell or
>    any "I'm leaving" message in the doc.
> 2. A request inside the doc clearly needs the parent terminal (a code
>    change, a shell command, an external action the parent would do).
>    Post a short reply: *"This seems like a bigger change — let's bring
>    it back to where I'm running and pick it up there,"* then exit with
>    a one-sentence summary of the ask.
> 3. An unrecoverable error (auth lost, room destroyed). Exit with the
>    error.

Default `composer_next_event` timeout is 30s. Don't shorten it
arbitrarily.

## Inside the loop

Every return carries a structured directive. Follow it without waiting
for user input.

### `kind: "mention"`

Handle the event (reply / suggestion / resolve as needed), then execute
`requiredNextToolCall` — which is another `composer_next_event` call.
Do not pause to acknowledge.

### `kind: "timeout"` with `recentActivity: true`

The user was working in the doc recently — they just didn't tag you.
The return includes `requiredNextToolCall`. Execute it. Stay in the
loop.

### `kind: "timeout"` with `recentActivity: false`

The doc has been silent for the configured quiet window (default 15
min). The return has `instruction` but **no** `requiredNextToolCall`.
Exit silently per rule 1. Do not post a farewell anywhere.

## The mention event payload

```
{
  kind: "mention",
  threadId: "...",
  threadKind: "comment" | "suggestion",
  threadText: "...",           // the exact message that triggered you
  replyId?: "...",             // present when this is a reply on an existing thread
  reason: "direct_mention" | "active_thread" | "solo_room",
  anchoredText?: "...",        // the doc text the thread is anchored to
  headingId?: "...",           // the section's headingId (use with write tools)
  headingText?: "...",
  sectionMarkdown?: "..."      // full containing section as markdown
}
```

Use `headingId` + `anchoredText` directly when calling
`composer_add_suggestion` or `composer_add_comment` — no extra
`composer_get_section` is needed in the common case. Reach for
`sectionMarkdown` to understand surrounding context before replying.

**The event only carries the triggering message.** If the thread already
has replies, call `composer_get_thread({ roomId, threadId })` before
replying. The return has every reply with author and timestamp —
essential when the user tagged you mid-conversation.

## `reason` is your main filter

- **`"direct_mention"`** — sidecar or text explicitly tagged you. Always
  reply (unless the content is purely a thank-you that doesn't need an
  answer — never emit empty acknowledgements).
- **`"active_thread"`** — a plain reply on a thread you're already in.
  Reply if the content invites one; skip if it's plainly addressed to
  another person, is a thank-you, or is otherwise a conversational
  dead-end.
- **`"solo_room"`** — you're alone with one human who didn't tag anyone.
  **Default to a helpful reply** — they almost certainly want your
  input. Skip only when the text reads like:
    - a **note-to-self** ("TODO: fix this later", "remember to check the
      date"),
    - a bare **acknowledgement** ("k", "got it", "done"),
    - a stage direction / aside ("ugh", "hmm"),
    - or anything that visibly isn't pointed at you (quoted text, drafts
      they're jotting down).
  When in doubt, reply — the user can always ignore you.

## Where to go for richer rules

- About to **reply on a thread** with text? Load **`composer:commenting`**
  — terseness rules and the suggestion-replaces-reply pattern.
- About to **post a suggestion**? Load **`composer:suggesting`** — span
  scoping, ripple coverage, anchor mechanics.

Don't try to reproduce those skills' rules from memory; load them when
the situation matches.
