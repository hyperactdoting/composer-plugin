---
name: create
description: Use when the user wants to start a NEW Composer doc — pasting markdown to "send to Composer", asking to create/seed a Composer room from a file or inline content, or accepting your offer to put a draft into Composer. Covers first-run agent-name prompt, seed selection (file path vs inline), the ordered `step1_sayToUser` / `step2_callTool` return, and the monitor-subagent handoff.
---

# Composer — Create a doc

Composer is a real-time collaborative markdown editor. `composer_create_room`
seeds a new room with markdown and gives you back a shareable URL.

## When to load this skill

- The user asks to "send this to Composer", "make a Composer doc with
  this", "create a Composer room with the plan".
- They accept your offer to put a draft into Composer (the SessionStart
  hook may have nudged you to make that offer; this skill tells you how
  to follow through).

If they pasted an existing `usecomposer.app/r/<id>` URL, they want to
**join**, not create — load `composer:join` instead.

## Steps

### 1. First-run only — agree on a name

If the MCP returns an "ask the user what to call you" error, no `actingAs`
name is saved on this machine yet. Stop and ask. Suggest one default:

- If you know the user's first name → `"<FirstName>'s Agent"` (e.g.
  `"Josh's Agent"`).
- Otherwise something playful that isn't a model family — `Monty`,
  `Gerty`, `Rosie`, `Otto`, `Pip`. **Never** suggest Claude, Gemini,
  Sonnet, Opus, Haiku, GPT, or any other model name.

Phrase: *"I'll go by Monty in Composer docs — sound good, or pick your
own?"* Retry the call with their answer as `actingAs`. The name persists
to `~/.composer/user.json` and is reused forever.

### 2. Pick the seed source

Pick exactly one:

- **`seedMarkdownPath: "<absolute path>"`** — preferred whenever the
  markdown already lives in a file on disk (a plan, a journal entry, any
  `.md` the user pointed at). The MCP reads the file itself, so you don't
  stream the content through the model. Faster, cheaper.
- **`seedMarkdown: "<inline string>"`** — only when the content was
  generated this turn and isn't on disk yet.

The seed is read **once**. Composer never writes back to the source
file. If the user later wants the room contents back on disk, that's the
`/composer:export` slash command — explicit, one-way overwrite.

### 3. Call `composer_create_room`

```
composer_create_room({
  seedMarkdownPath: "<absolute path>"   // OR seedMarkdown: "<inline>"
})
```

### 4. Honor the ordered return

Success returns two ordered steps. The field names encode the order:

1. **`step1_sayToUser`** — output this **first**. It always starts with
   the `browserUrl` so the user has a way into the doc, and carries the
   `@<your-name>` tagging hint they'll need to mention you. Light
   paraphrasing is fine; **do not drop the URL or the mention syntax**.
2. **`step2_callTool`** — a structured `{ tool, args, why }` directive
   pointing at `composer_next_event`. **Do not run it inline.** Spawn
   the monitor subagent (next step), then end your turn.

Skipping `step1_sayToUser` strands the user with no link. Skipping the
subagent spawn leaves the room attached but silent — saying "I'm
monitoring" without spawning the loop is a lie; every mention gets missed.

### 5. Spawn the monitor subagent

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

## Terminal-side asks after creation

The main thread is also attached to the room. If the user later asks
something in the terminal like *"add a summary to section 2"*, call the
write tools from here and report back concisely. Don't hand terminal
directives to the monitor subagent — the subagent handles in-doc
mentions, the main thread handles in-terminal asks. They share the same
MCP, so writes from either show up in the doc.

For comment etiquette, load **`composer:commenting`**. For suggestion
craft, load **`composer:suggesting`**.

## Failure handling

- **Setup not done** → `npx @composer-app/mcp@latest setup`, restart the CLI.
- **Server kicked you (4403/4410) or reconnect aborted** → the agent
  left the room. Run `/composer:join <url>` to bring it back. The kick
  reason is in the error message.
