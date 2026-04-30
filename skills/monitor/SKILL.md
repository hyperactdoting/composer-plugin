---
name: monitor
description: Use when you're running the Composer monitor loop — spawned as a subagent off `composer_create_room` / `composer_join_room`, or otherwise about to call `composer_next_event`. Covers the spawn template, mention filtering, the event payload, and the five exit rules.
---

# Composer monitor loop

Composer's monitor loop is **always-on**: every return from
`composer_next_event` carries a directive (a mention to handle, a
timeout to noop on, or a goodbye to honor). You execute the directive
and immediately call the tool again. The doc IS your conversation —
do not narrate to the parent between ticks.

This skill is for the agent **inside** the loop. The parent host that
spawns you uses `composer:create` (after `composer_create_room`) or
`composer:join` (after `composer_join_room`).

## How the parent spawns you

The parent skill tells the host to spawn an `Agent` with:

- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `description: "Composer monitor: <roomId>"`
- prompt: a short brief that includes the room's `{roomId}`, the
  agent's `{actingAs}`, and the five exit rules below.

## Exit rules

When you exit, your **final output line is the user-visible goodbye** —
the parent surfaces it back to the main thread. Voice: first-person,
casual, the same agent saying goodbye. Not a system notification, not
a stack trace. **For terminal exits #1, #3, #4, the goodbye text is
returned by the MCP as `userMessage` — print it verbatim, do not
paraphrase.** Exit #5 (unrecoverable error) has no MCP-supplied text
because the loop never returned cleanly; use the canonical line below.

> Exit and return when ANY of these happen:
>
> **1. Idle timeout.** `composer_next_event` returns `kind: "timeout"`
> with `recentActivity: false`, `userMessage`, and `instruction` (no
> `requiredNextToolCall`). The doc has been silent for the configured
> quiet window. Do **not** post anything in the doc — awareness has
> already cleared. Print `userMessage` verbatim to the terminal, then
> exit.
>
> **2. Doc-side handoff.** A request inside the doc clearly needs the
> parent terminal (a code change, a shell command, an external action
> the parent would do). Post this short reply **in the thread**, then
> exit with a one-sentence summary of the ask:
>
> > *Let's chat more about this in our connected session.*
>
> **3. Server kicked the client.** Close code `4403` (old MCP), `4410`
> (kill switch), or HTTP 403 on upgrade. `composer_next_event` returns
> `kind: "timeout"` with `userMessage` carrying the kick goodbye. Print
> `userMessage` verbatim and exit; don't post in the doc — you're
> being told to leave the room.
>
> **4. Reconnect aborted.** The client circuit breaker tripped after 15
> consecutive failed reconnects (network down, server unreachable).
> Same shape as #3 — `composer_next_event` returns
> `kind: "timeout"` with the appropriate `userMessage`. Print verbatim
> and exit.
>
> **5. Unrecoverable mid-loop error.** Auth lost, room destroyed, or
> any other thrown error not covered above. The MCP can't supply a
> `userMessage` because the call didn't return cleanly. Print the
> error AND this line, then exit:
>
> > *Something went wrong and I had to stop. Try running
> > `/composer:join` in a bit to bring me back.*

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

### `kind: "timeout"` without `requiredNextToolCall`

The return has `userMessage` and `instruction`. This branch covers
**three** exits (rules 1, 3, 4) — the MCP picks the right `userMessage`
based on whether the doc went silent (idle), the server kicked us
(close code 4403/4410/HTTP 403), or the reconnect breaker tripped
(15 consecutive failed retries). You don't need to distinguish the
three: print `userMessage` verbatim to the terminal and exit. Do not
post in the doc.

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
