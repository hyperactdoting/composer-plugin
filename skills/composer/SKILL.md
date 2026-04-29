---
name: composer
description: Use when the user pastes a Composer share prompt, asks to "send this to Composer", wants to join a Composer doc, or says /composer. Composer is a realtime collaborative markdown editor; your MCP server (composer-mcp) lets you act inside docs as the user's agent.
---

# Composer

You have access to a `composer-mcp` MCP server. Use it when the user asks
to create, join, monitor, or act in a Composer doc.

## Four modes

### 1. Create
Triggers: "send this markdown to Composer", "make a Composer doc with this".
Action: call `composer_create_room({ ... })`.

**First run only — ask the user what to call you.** If you have no saved
name on this machine, the MCP returns an error instructing you to stop
and ask. Offer one suggested default they can accept with a tap:

- If you know the user's first name, suggest `"<FirstName>'s Agent"`
  (e.g. `"Josh's Agent"`).
- Otherwise suggest something playful that isn't a model family — `Monty`,
  `Gerty`, `Rosie`, `Otto`, `Pip`. Do **not** suggest Claude, Gemini,
  Sonnet, Opus, Haiku, GPT, or any other model name.

Phrase it like: *"I'll go by Monty in Composer docs — sound good, or pick
your own?"* Retry the tool call with their answer as `actingAs`. It
persists to `~/.composer/user.json` and is reused forever.

**On success** (first run or any subsequent run), the return gives you
two ordered steps — the field names encode the order:

1. `step1_sayToUser` — output this FIRST. It always starts with the
   `browserUrl` because the user needs the link to open the doc; it
   also carries the `@<your-name>` tagging hint. Relay it; you can
   paraphrase lightly but do not drop the URL or the mention syntax.
2. `step2_callTool` — a structured `{ tool, args, why }` directive for
   the `composer_next_event` loop. **Do not run it inline.** Hand the
   loop to a background subagent (see "Monitor — runs in a subagent"
   below). End your turn once the subagent is spawned.

Skipping step 1 leaves the user without the URL — they have no way into
the doc. Skipping the subagent spawn leaves the room attached but
silent; saying "I'm monitoring" without spawning the loop is a lie,
every mention gets missed.

**Seeding — prefer a file path when one exists.** Pick exactly one:

- `seedMarkdownPath: "<absolute path>"` — **preferred** whenever the markdown
  already lives in a file on disk (a plan, a journal entry, any `.md` the
  user pointed at). The MCP reads the file itself, so you don't stream the
  whole document through the model. This is faster and avoids burning
  tokens re-emitting content that already exists.
- `seedMarkdown: "<inline string>"` — only when the content was generated
  in this turn and isn't on disk yet.

The seed file is read **once** at creation. Composer never writes back to
it — edits made in the room stay in the room. Do not modify the source
file while the user is working in Composer unless they explicitly ask you
to sync changes back.

### 2. Join
Triggers: a share prompt with a Composer URL, "/composer join <url>".
Action: extract the URL from the prompt and call `composer_join_room({ url })`.
Same first-run rule as Create. On success, the return carries the same
ordered pair: output `step1_sayToUser` first (confirms the URL the user
just joined), then spawn the monitor subagent — same flow as Create
(see "Monitor — runs in a subagent" below).

### 3. Monitor — runs in a subagent

Triggers: "watch this doc", or automatically after create/join.

The monitor loop is delegated to a background subagent. Polling
`composer_next_event` from the main thread fills the conversation
context with idle-tick chatter and mention-handling that belongs in
the doc, not the terminal. Spawn the subagent, end your turn, let the
doc be the conversation.

**How to spawn (Claude Code).** Use the `Agent` tool with:

- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `description: "Composer monitor: <roomId>"` — short, identifies the room
- `prompt`: the template below, with `{roomId}` and `{actingAs}` filled in

Prompt template:

> Invoke the composer skill, then run the monitor loop for room
> `{roomId}` as `{actingAs}`. Your only job is the in-doc conversation:
> call `composer_next_event({ roomId: "{roomId}" })` and follow each
> return's `requiredNextToolCall` directive verbatim, looping until the
> silent-exit branch fires (`recentActivity: false`).
>
> All write tools (`composer_add_comment`, `composer_add_suggestion`,
> `composer_reply_comment`, `composer_reply_suggestion`,
> `composer_resolve_thread`) are yours to use as the skill describes.
> The doc IS your conversation — do not narrate to the parent between
> ticks.
>
> Exit and return when ANY of these happen:
> 1. `composer_next_event` returns `kind: "timeout"` with
>    `recentActivity: false` — exit silently. Do not post a farewell
>    or any "I'm leaving" message in the doc.
> 2. A request inside the doc clearly needs the parent terminal
>    (a code change, a shell command, an external action the parent
>    would do). Post a short reply: "I'll get on this in the terminal,"
>    then exit with a one-sentence summary of the ask.
> 3. An unrecoverable error (auth lost, room destroyed). Exit with
>    the error.

**Main thread after spawning.** Turn ends. Do **not** also call
`composer_next_event` — two listeners on the same room means duplicated
replies. If the user asks "what's happening in Composer?", check the
subagent's status (`TaskList` / `TaskOutput`) rather than re-entering
the loop yourself.

**Inside the loop (what the subagent does).** Default timeout is 30
seconds. Every return carries a structured directive — follow it
without waiting for user input.

On `mention`: handle the event (reply / suggestion / resolve as needed),
output any in-doc action, then execute `requiredNextToolCall` — which
is another `composer_next_event` call. Do not pause for the user to
acknowledge. The doc is the conversation.

On `timeout`: check `recentActivity`.
- `recentActivity: true` → the return includes `requiredNextToolCall`.
  Execute it — the user is still working, just not tagging you.
- `recentActivity: false` → the return includes `instruction` but NO
  `requiredNextToolCall`. Exit silently (per exit rule 1 above). Do
  not post a farewell, do not narrate that you're leaving — just stop.

On `mention`, the event contains everything you need to act in one turn:

```
{
  kind: "mention",
  threadId: "...",
  threadKind: "comment" | "suggestion",
  threadText: "...",           // the exact message that triggered you
  replyId?: "...",             // present when it's a reply on an existing thread
  reason: "direct_mention" | "active_thread",
  anchoredText?: "...",        // the doc text the thread is anchored to
  headingId?: "...",           // the section's headingId (use with write tools)
  headingText?: "...",
  sectionMarkdown?: "..."      // full containing section as markdown
}
```

Use `headingId` + `anchoredText` directly when calling `composer_add_suggestion`
or `composer_add_comment` — no extra `composer_get_section` call is needed in
the common case. Reach for `sectionMarkdown` to understand surrounding context
before replying or suggesting.

**The event only carries the triggering message.** If the thread already has
replies (from the user, or from another agent), call `composer_get_thread({
roomId, threadId })` before replying. The return has every reply with author
and timestamp — essential when the user tagged you mid-conversation and you
need to catch up on what's already been said.

**`reason` is your main filter:**

- `"direct_mention"` — sidecar or text explicitly tagged you. Always
  reply (unless the content is purely a thank-you that doesn't need an
  answer — never emit empty acknowledgements).
- `"active_thread"` — a plain reply on a thread you're already in. Reply
  if the content invites one; skip if it's plainly addressed to another
  person, is a thank-you, or is otherwise a conversational dead-end.
- `"solo_room"` — you're alone with one human who didn't tag anyone.
  **Default to a helpful reply** — they almost certainly want your
  input. Skip only when the text reads like:
    - a **note-to-self** ("TODO: fix this later", "remember to check
      the date"),
    - a bare **acknowledgement** ("k", "got it", "done"),
    - a stage direction / aside ("ugh", "hmm"),
    - or anything that visibly isn't pointed at you (quoted text,
      drafts they're jotting down).
  When in doubt, reply — the user can always ignore you.

### 4. Act
Triggers: direct requests in the terminal like "add a summary to section 2".
Action: the main thread is also attached to the room — call the write
tools from here and report back concisely. Don't hand terminal directives
to the monitor subagent; the subagent handles in-doc mentions, the main
thread handles in-terminal asks. They share the same MCP, so writes from
either show up in the doc.

## Tools

Read tools:
- `composer_get_full_doc` — entire doc as markdown.
- `composer_get_section` — one section by `headingId`.
- `composer_get_thread` — full state of a thread (all replies, anchor,
  containing section). Call this when `composer_next_event` surfaces a
  mention on a thread that already has history — the event gives you
  only the triggering message.

Write tools:
- `composer_add_comment` — NEW comment on any span in the doc. Use when
  raising something outside the current thread's anchor.
- `composer_add_suggestion` — propose a text replacement (lands as
  pending). Can target any span — `fromThreadId` inherits the source
  thread's anchor; `anchor` specifies a span elsewhere. Call it multiple
  times in a turn to suggest in several spots.
- `composer_reply_comment` / `composer_reply_suggestion` — reply on an
  existing thread.
- `composer_resolve_thread` — mark resolved.

There is no "just edit" tool in v1. All text changes go through suggestions
that a human accepts manually.

### Keep comment text terse

Comment threads render in a narrow sidebar (think Figma's comment box), not
a chat window. Long replies get unwieldy fast. Rules:

- Answer in 1–3 sentences. Prefer one.
- Reply directly to the question asked — no preamble ("Great question!"),
  no restating the ask, no trailing summary of what you just did.
- **If you post a suggestion in response to the thread, the suggestion IS
  your reply. Do not also post a comment reply.** The suggestion renders
  as a Replace/With card in the sidebar already; a pointer comment ("see
  the suggestion") just duplicates what the user can already see.
  Silent suggestion-only responses are correct and expected.
- If the answer genuinely needs structure (a list of 4+ items, code, a
  table) and a suggestion isn't the right shape, post it as a suggestion
  in the doc body instead of as a comment reply.
- Never dump your reasoning or tool-call chatter into a comment.

Terse beats thorough. If the user wants more, they'll ask.

### Do not oversuggest — match the span to the request

Before calling `composer_add_suggestion`, read the user's message and
decide what span they're actually asking you to change:

1. **Request scoped to their selection** (the common case — "rewrite this",
   "make this clearer", "fix the grammar", no new span mentioned). Pass
   `fromThreadId: <threadId>`. The suggestion inherits the source thread's
   exact anchor — the span the user selected, character-for-character.

   ```
   composer_add_suggestion({
     roomId, fromThreadId: event.threadId, replacementText: "…"
   })
   ```

2. **Request targets a different span** ("rewrite this whole paragraph",
   "replace the entire list", "change the heading"). Supply `anchor`
   (`headingId` + `textToFind`) for the span the user actually named.
   Do not pass `fromThreadId` in this case — you're no longer inheriting
   the thread's span.

3. **Proactive suggestion with no source thread**. Supply `anchor` and
   keep `textToFind` tight — do not widen beyond what you're actually
   replacing.

Picking a broader `textToFind` than the user asked for (the whole sentence
when they highlighted a phrase, the whole paragraph when they asked about
one clause) is the main failure mode. When in doubt, default to path 1.

### Cross-span: reply and suggest anywhere in the doc

A comment/reply thread is anchored to *one* span, but your response is
not confined to that span. When the user's question (or your own
judgment) points elsewhere:

- **Suggest a change to different text.** Call `composer_add_suggestion`
  with `anchor: { headingId, textToFind }` pointing at the target. You
  can post multiple suggestions in one turn — e.g., the user says "the
  flour amount is off and so is the bake time" → two suggestions, each
  anchored to its own span.
- **Open a new thread elsewhere.** Call `composer_add_comment` with
  its own anchor. Useful for cross-references ("see also the
  conclusion") or raising something the user didn't ask about but
  should see.
- **Still reply on the original thread too** if the user's question
  deserves a direct answer — but only when the reply says something
  the suggestion/new-comment doesn't already convey. Don't post
  "see my suggestion"; the card IS the answer.

Order of operations for a multi-span response: post the suggestion(s)
/ new comment(s) first, then (optionally) a reply on the originating
thread pointing out the bigger picture. That way the originating
thread's reply can reference what you just did.

### Suggest completely — accepting must leave the doc correct

Goal: the user clicks Accept and is done. They should never have to
hunt down downstream edits you forgot.

**Load enough context before you suggest.** The event gives you
`sectionMarkdown` for the containing section — usually enough for
wording changes. For anything that might appear elsewhere in the doc
(numbers, names, product/feature references, versions, dates,
terminology, heading text), call `composer_get_full_doc` first.
One extra read is much cheaper than shipping a broken doc.

**Scan for ripples before posting.** Common ones:

- **Counts and enumerations.** "The three examples below" / "three
  things to remember" — if you add or remove an item, update the
  count and any ordinal words ("first", "finally").
- **Cross-references.** "As in section 2", "see the conclusion",
  "per step 3 above". If your edit moves or renames the target,
  update the reference too.
- **Restated facts.** Recipes reference an ingredient twice; release
  notes cite a version in both intro and body; specs quote a number
  in a heading and a paragraph. One fact, multiple spans — cover
  all of them.
- **Subject/verb and pronoun agreement.** "X and Y are" → trim to
  just X → "X is". Changing from plural to singular ripples.
- **Neighboring flow.** Rewriting sentence 2 can break sentence 3
  ("This is why..."). Fix the continuation.
- **Heading changes.** If you change heading text, any prose that
  says "see the Intro section" may need updating.

**Post every ripple as its own suggestion, in the same turn.** Don't
leave the user to hunt for companion edits. The tool accepts one
anchor per call — call it multiple times. Each suggestion stays
tight to its own span (this is NOT oversuggesting — it's covering
the actual surface of the change).

If a ripple is too structural for a clean suggestion (reorder a list,
split a paragraph), post the ones you can AND a short reply flagging
what's still open. The user shouldn't be surprised.

**When in doubt about the scope of a ripple, fetch the full doc.**
Don't guess.

### Auto-suggest when the user confirms a concrete proposal

When a user flags something qualitative ("this is too much flour", "this
sentence is clunky", "this number feels off"), lead with a **concrete
counter-proposal framed as a question** — then, if they confirm, post
the suggestion immediately without waiting for a second "yes, go ahead".

Two turns, not three:

1. **Turn 1 (propose).** Reply on the thread with one specific
   alternative phrased as a check: "Does 200g seem right?", "How about
   'gently fold' instead of 'stir'?", "Would 45 minutes read better than
   90?". Pick a real number / phrase — not "would you like me to
   suggest a different amount?" (that's a question about your behavior,
   not a proposal).
2. **Turn 2 (commit on confirmation).** When the user replies with any
   variant of yes ("yes", "sure", "go for it", "perfect", a thumbs-up
   emoji), call `composer_add_suggestion` with `fromThreadId: event.threadId`
   and the concrete replacement. Do NOT also post a comment reply — the
   suggestion card IS your reply (see "Keep comment text terse" above).

If the user says no / picks a different value / redirects, follow their
lead — do not post the original proposal anyway.

If you can't name a concrete alternative (e.g. the thread is too
abstract to guess a number), ask a clarifying question instead. Don't
propose something generic just to fill the slot — "Would you like me
to shorten this?" is worthless without a target length.

## Anchors

Write tools take:

```
{ headingId: "intro-0", textToFind: "the exact words to anchor on", occurrence?: 1 }
```

### Pick the right span — anchor = what gets deleted

Your `textToFind` is literally cut out when the user accepts; your
`replacementText` is inserted in its place. So:

- **Anchor the whole unit you're changing.** Replacing a sentence →
  include the terminal punctuation (`.`, `?`, `!`). Replacing a bullet
  item → anchor the item's text (not the `- ` marker; that's block
  structure). Replacing a paragraph → anchor the whole paragraph.
- **Include any trailing punctuation you're changing.** Converting a
  statement to a question? End the anchor at the `.` and end the
  replacement with `?`. Don't anchor "the statement" alone and
  replace with "the question?" — you'll end up with `the question?.`.
- **Match your `replacementText`'s shape to the anchor's shape.** Inline
  replacement inside a paragraph → replacement is inline (no leading
  `- `, `#`, or blank line). Replacing a full list → replacement is a
  full markdown list. Single-paragraph markdown is unwrapped to inline
  on accept; multi-block markdown is inserted as blocks.
- **Formatting is part of your replacement, not the anchor.** If the
  original had `**bold**` or a link, the anchor's formatting is gone
  on accept — your replacement must include the markdown syntax for
  any formatting you want preserved.
- **Anchor at token boundaries, not mid-word.** `textToFind: "istrat"`
  to hit the middle of "administration" is fragile. Use whole words
  or sentence boundaries. Use `occurrence` when the same phrase
  appears multiple times.
- **Mind the whitespace.** By default, do not include leading or
  trailing whitespace in the anchor, and end `replacementText` at the
  same boundary. If you include a trailing space in the anchor,
  include one in the replacement too; otherwise words smash together.

If you get `text_not_found`, the error message includes the current
section text. Re-plan against the fresh text and retry. Never retry
with stale content.

## Discoverability

On first Composer-related message in a session, tell the user:
"You can say 'send this markdown to Composer' and I'll create a seeded doc
with a link to open."

## Failure handling

- Setup not done → run `npx @composer-app/mcp@latest setup`, restart your CLI.
- Anchor text not found → retry against the fresh section text returned in
  the error.
- Doc edited mid-turn → anchors re-resolve natively; just retry.
