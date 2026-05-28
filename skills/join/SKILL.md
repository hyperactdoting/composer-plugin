---
name: join
description: Use when the user wants to JOIN an existing Composer doc — pasting a `usecomposer.md/d/<id>` URL, running `/composer:join`, or otherwise asking you to attach to a room they already have. Covers first-run agent-name prompt, the `composer_join_room` call, the ordered `step1_sayToUser` / `step2_callTool` return, and the monitor-subagent handoff.
---

# Composer — Join a doc

Composer is a real-time collaborative markdown editor. `composer_join_room`
attaches you to an existing room so you can read, comment, suggest, and
respond to mentions.

## When to load this skill

- The user pastes a `usecomposer.md/d/<id>` URL.
- They run `/composer:join <url>` (the slash command delegates here).
- They ask you to "watch this Composer doc" / "join this room" with a
  URL or roomId.

If they want to spin up a NEW doc from markdown they've shown you, that's
**create**, not join — load `composer:create` instead.

## Talk like a person, not the MCP

Don't *volunteer* tool names, internal codes (`COMPOSER_AUTH_REQUIRED`,
HTTP statuses, `4403`), file paths, or mechanics ("polling", "device
flow"). Translate tool results into plain language before relaying.
Verification and room URLs are the exceptions — the user clicks those,
paste them verbatim. If the user explicitly asks what's happening under
the hood, answer honestly. See `composer:create` ➜ "Talk like a person,
not the MCP" for the full guidance.

## Steps

### 1. Sign in (kick this off immediately, every session)

Same as the `composer:create` skill: **always call `composer_login`
first**, before `composer_join_room`. If the user is already signed in,
it returns instantly and you proceed silently. If not, the first call
returns `COMPOSER_AUTH_REQUIRED` with a one-tap approval link — tell the
user once (warmly) that you've kicked off sign-in, paste the link
verbatim, and **immediately call `composer_login` again** to block until
they approve. See `composer:create` step 1 for the full pattern,
including the timeout copy and the "don't ask permission, just kick it
off" framing.

### 2. First-run only — agree on the agent's display name

If `composer_join_room` (step 4) returns an "ask the user what to call
you" error, no `actingAs` name is saved yet. Use the `user.name` from
`composer_login` to propose a default — `"<FirstName>'s Agent"` (e.g.
`"Josh's Agent"`). Account name missing or handle-like → fall back to
something playful: `Monty`, `Gerty`, `Rosie`, `Otto`, `Pip`. **Never**
suggest Claude, Gemini, Sonnet, Opus, Haiku, GPT, or any other model
name. Phrase as a single sentence the user can accept or override:
*"I'll go by Josh's Agent in Composer docs — sound good?"* Retry with
their answer as `actingAs`. The name persists to `~/.composer/user.json`
and is reused forever — this step only happens once per machine.

### 3. Resolve the URL

- If the user pasted a `https://usecomposer.md/d/<id>` URL, use it.
- If `/composer:join` was run with no argument, ask: *"Which Composer
  doc should I join? Paste the URL."* Stop. Do not guess.
- A bare roomId (no `https://` prefix) is also acceptable.

### 4. Call `composer_join_room`

```
composer_join_room({ url: "<the URL or roomId>" })
```

### 5. Honor the ordered return

Success returns two ordered steps:

1. **`step1_sayToUser`** — output this **first**. It confirms the URL
   the user just joined and carries the `@<your-name>` tagging hint.
   Light paraphrasing OK; don't drop the URL or the mention syntax.
2. **`step2_callTool`** — a structured `{ tool, args, why }` directive
   pointing at `composer_next_event`. **Do not run it inline.** Spawn
   the monitor subagent (next step), then end your turn.

### 6. Spawn the monitor subagent

Use the `Agent` tool with:

- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `description: "Composer monitor: <roomId>"`
- `prompt`: tell the subagent to **invoke the `composer:monitor`
  skill**, then run the loop on `{roomId}` as `{actingAs}`. Don't paste
  the loop rules inline — the `composer:monitor` skill carries them
  (spawn template, mention filtering, exit rules, event payload).

Once spawned, **end your turn immediately**. Do not output any text
after the spawn — no closing recap, no "monitor is running" status
line, no restating the mention syntax. The host already shows a
status indicator for the backgrounded `Agent` tool call; that's the
user's confirmation. Anything you say after `step1_sayToUser` just
duplicates it. The protocol is strict:

1. Output `step1_sayToUser` (verbatim or lightly paraphrased).
2. Spawn the `Agent`.
3. End turn. No closing remark.

Also: do **not** poll `composer_next_event` from the main thread —
two listeners on the same room means duplicated replies.

### When the monitor exits

You'll get a notification when the background subagent finishes. Its
final output line is the agent's goodbye — written in the agent's
voice (idle timeout, server kick, reconnect aborted, etc., per the
`composer:monitor` exit rules). **Relay that line verbatim to the user
in the main thread** so they see why the agent left and how to bring
it back. Don't paraphrase or wrap it in extra explanation; the
goodbye line already carries the next step (`/composer:join` etc.).

## Terminal-side asks after joining

The main thread is also attached to the room. If the user asks something
in the terminal like *"reply to that thread saying we'll ship Friday"*,
call the write tools from here and report back concisely. Don't hand
terminal directives to the monitor subagent — the subagent handles
in-doc mentions, the main thread handles in-terminal asks. They share
the same MCP, so writes from either show up in the doc.

For comment etiquette, load **`composer:commenting`**. For suggestion
craft, load **`composer:suggesting`**.

## Failure handling

- **Setup not done** → `npx @composer-app/mcp@latest setup`, restart the CLI.
- **Server kicked you (4403/4410) or reconnect aborted** → the agent
  left the room. Run `/composer:join <url>` to bring it back. The kick
  reason is in the error message.
