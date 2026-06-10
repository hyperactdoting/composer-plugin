---
name: create
description: Use when the user wants to start a NEW Composer doc — pasting markdown to "send to Composer", asking to create/seed a Composer room from a file or inline content, or accepting your offer to put a draft into Composer. Covers first-run agent-name prompt, seed selection (file path vs inline), the ordered `step1_startMonitor` / `step2_sayToUser` return (spawn first, speak last), and the monitor-subagent handoff.
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

If they pasted an existing `usecomposer.md/d/<id>` URL, they want to
**join**, not create — load `composer:join` instead.

## Talk like a person, not the MCP

Default to plain language. Don't *volunteer* MCP internals — tool
names, internal signals (`COMPOSER_AUTH_REQUIRED`,
`COMPOSER_AUTH_TIMED_OUT`, `text_not_found`, `no_such_doc`, HTTP
statuses, `4403`/`4410`), file paths (`~/.composer/auth.json`,
`user.json`), or mechanics ("polling", "device flow", "bearer",
"awareness state", "the MCP"). Translate every tool result into
user-friendly language before relaying.

**Say:**
- "Sign in to Composer" / "Connect Composer to your account"
- "Open this link to approve"
- "I'll wait while you sign in"
- "Looks like that didn't go through — want me to try again?"

**Not:**
- "composer_login returned COMPOSER_AUTH_REQUIRED"
- "Polling the device endpoint at /api/auth/device/token…"
- "Couldn't write `~/.composer/auth.json`"

If the user **explicitly asks** what's happening under the hood — "what
tool did you call?", "what's the error?", "show me the raw output",
"why did that fail?" — answer honestly and completely. The rule is
about not surfacing internals willy-nilly, not about hiding them when
asked. Same applies if the user is clearly debugging the integration
(a developer poking at the MCP).

The verification URL is a special case: it's not an internal, it's the
thing the user clicks. Paste it verbatim.

## Steps

### 1. Sign in (kick this off immediately, every session)

**Always call `composer_login` first**, before `composer_create_room` or
any other Composer tool. It's idempotent — if the user is already signed
in, it returns instantly with their account info, and you proceed
without saying anything about authentication.

On hosts that support interactive dialogs (Claude Code does), the
first-time sign-in is handled inside this same call: the user gets a
dialog with the approval link, approves in their browser (any device),
confirms, and the call returns success. Nothing for you to relay — just
proceed.

On hosts without dialogs, the first call returns an error whose message
starts with `COMPOSER_AUTH_REQUIRED` and contains a one-tap approval
link. Handle it like this:

1. **Tell the user once, in your own warm words**, that you need them to
   sign in to add the agent to Composer, and that you've kicked it off.
   Then **show the approval link verbatim**. Example:

   > To add your agent to Composer, you'll need to sign in or create a
   > Composer account real quick. I've started the flow — open this link
   > to approve:
   > https://usecomposer.md/device?user_code=ABCD-1234

   Don't ask "is it okay if I sign you in?" — just kick it off and
   announce it. The login tool was already called; the link is the
   evidence.

2. **Immediately call `composer_login` a second time** in the same turn.
   That call blocks polling for a couple of minutes. The moment the user
   approves, it returns `{ user: { name, email }, alreadyAuthenticated }`
   and your turn continues.

3. If the second call returns `COMPOSER_AUTH_PENDING`, the user hasn't
   approved yet and the link is still valid. Make sure they've actually
   seen the link (show it again if your earlier message didn't go out),
   then call `composer_login` again to keep waiting. Repeat as needed.

4. If a call returns `COMPOSER_AUTH_TIMED_OUT`, the sign-in link expired
   unused. Relay the user-facing line from the message verbatim and stop —
   wait for the user to say they're ready, then call `composer_login`
   again.

### 2. First-run only — agree on the agent's display name

If `composer_create_room` (next step) returns an "ask the user what to
call you" error, no `actingAs` name is saved on this machine yet. Use
the `user.name` you got back from `composer_login` to propose a default,
phrased as a single sentence that the user can accept or override:

- Have a real first name from the account → **`"<FirstName>'s Agent"`**
  (e.g. `"Josh's Agent"`).
- Account name is missing or looks like a handle/email → fall back to
  something playful like `Monty`, `Gerty`, `Rosie`, `Otto`, `Pip`.
  **Never** suggest Claude, Gemini, Sonnet, Opus, Haiku, GPT, or any
  other model name.

Phrase: *"I'll go by Josh's Agent in Composer docs — sound good, or want
me to use a different name?"* Retry the call with their answer as
`actingAs`. The name persists to `~/.composer/user.json` and is reused
forever — this step only happens once per machine.

If the user wants to switch accounts later, they can say "log out of
Composer" or "switch Composer accounts" → call `composer_logout`, then
re-run this flow.

### 3. Pick the seed source

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

### 4. Call `composer_create_room`

```
composer_create_room({
  seedMarkdownPath: "<absolute path>"   // OR seedMarkdown: "<inline>"
})
```

### 5. Honor the ordered return

Success returns two ordered steps. The field names encode the order,
and the order is deliberate: **spawn first, speak last**. End-of-turn
text reliably reaches the user; text sandwiched before a tool call can
get lost.

1. **`step1_startMonitor`** — a structured `{ tool, args, how }`
   directive pointing at `composer_next_event`. **Do not run it
   inline.** Spawn the monitor subagent (next step). This is
   non-blocking; it takes a moment.
2. **`step2_sayToUser`** — after the spawn, output this as your
   **final message and end your turn**. It carries the `@<your-name>`
   tagging hint and ends with the `browserUrl` so the link is the last
   thing on screen. Light paraphrasing is fine; **do not drop the URL
   or the mention syntax, and do not add anything after it** — no
   recap, no "monitor is running" status line.

Skipping the subagent spawn leaves the room attached but silent —
saying "I'm watching" without spawning the loop is a lie; every
mention gets missed. Skipping `step2_sayToUser` strands the user with
no link.

### 6. Spawn the monitor subagent

Use the `Agent` tool with:

- `subagent_type: "composer:watch"` — the plugin ships this agent
  type; its system prompt already carries the monitor briefing. Fall
  back to `"general-purpose"` only if the type isn't available.
- `run_in_background: true`
- `description`: the `step1_startMonitor.agentDescription` value
  **verbatim** (e.g. `Josh's Agent · "Project Phoenix"`). It's
  user-visible in the host's agent list; the MCP already built it from
  the agent name and the doc title, so don't compose your own.
- `prompt`: tell the subagent to **invoke the `composer:monitor`
  skill**, then run the loop on `{roomId}` as `{actingAs}`. Don't paste
  the loop rules inline — the `composer:monitor` skill carries them
  (spawn template, mention filtering, exit rules, event payload).

The protocol is strict:

1. Spawn the `Agent` (step 1 of the return).
2. Output `step2_sayToUser` (verbatim or lightly paraphrased) as your
   final message.
3. End turn. Nothing after the URL message.

Also: do **not** poll `composer_next_event` from the main thread —
two listeners on the same room means duplicated replies.

### When the monitor exits

You'll get a notification when the background subagent finishes. Its
final output line tells you which exit fired (idle timeout, server
kick, reconnect aborted, doc-side handoff, etc., per the
`composer:monitor` exit rules). Branch on it:

**Handoff exit (rule #2).** The owner asked for something the
terminal needs to do — a shell command, a code edit, an external
action. The subagent's final line summarizes the ask. Two things to
do, in order:

1. **Execute the ask** from the main thread. Use real tools (`Bash`,
   `Edit`, `Write`, etc.) and then report the result back into the
   doc via the Composer write tools (`composer_reply_comment` / etc.)
   on the same `threadId` the subagent named.
2. **Relaunch a fresh monitor subagent** — same spawn template as
   step 6 above (`composer:watch`, `run_in_background: true`, prompt
   that invokes `composer:monitor` for the same `{roomId}` /
   `{actingAs}`). Do this even if the ask is still in progress —
   without it, the room goes silent and any further mentions are
   missed.

**All other exits (rules #1, #3, #4, #5).** The subagent printed a
user-visible goodbye line (`userMessage` from the MCP or, for #5, the
canonical recovery line). **Relay that line verbatim to the user in
the main thread.** Don't paraphrase or wrap it in extra explanation;
the goodbye already carries the next step (`/composer:join` etc.).
Do **not** relaunch — the room is closed.

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
