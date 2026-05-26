---
name: plan
description: Use when the user wants to review a plan markdown file in Composer with anchored decision threads — running `/composer:plan` (with or without a path), saying "send this plan to Composer", "open this plan in Composer with question threads", or "review my plan in Composer". Also covers the in-plan-mode case where the user wants to land their active plan in Composer before hitting `ExitPlanMode`. Covers source resolution, decision identification, the `## Decisions` seeding pattern, anchored question comments in `ready` state, the ordered `step1_sayToUser` / `step2_callTool` return, the monitor-subagent handoff, and the chaptering convention for long plans.
---

# Composer — Send a plan for refinement

Composer is a real-time collaborative markdown editor. `composer:plan`
takes a plan markdown file, seeds it into Composer, and posts anchored
question comments on the still-open decisions so the user can refine
them in-thread instead of inside a wall of prose.

The contract is narrow: path-in, decision-threads-out. You do **not**
invoke other planning skills, and you do not generate the plan
yourself — it must already exist on disk.

## When to load this skill

- The user runs `/composer:plan` (with or without a path argument).
- They ask to "send this plan to Composer", "open this plan in
  Composer with question threads", or "review my plan in Composer".
- They're in plan mode and want their active plan landed in Composer
  before they hit `ExitPlanMode` — you can offer this proactively.

If they pasted an existing `usecomposer.app/r/<id>` URL, that's
**join**, not plan — load `composer:join` instead. If they want a
fresh doc seeded from arbitrary markdown with no decision-thread
overlay, that's **create** — load `composer:create` instead.

## Steps

### 1. Resolve the source plan file

Pick exactly one mode:

- **Argument given.** `/composer:plan <path>` → use `<path>` (absolute
  or relative to cwd; resolve to absolute before passing to the MCP).
- **No argument, plan mode active.** The harness exposes the active
  plan's path in plan mode's system message (typically
  `~/.claude/plans/<slug>.md`). Auto-detect it from there. Do not
  enter or exit plan mode — just read the path it advertises.
- **No argument, no plan mode.** Ask once: *"Which plan markdown file
  should I open in Composer? Paste the path."* Stop. Do not guess.

If the path doesn't exist or isn't readable, say so plainly and stop.
Don't fall back to a different file.

### 2. Identify the open decisions

Read the plan and pick the **2–5 most consequential still-open
choices**. Be conservative — better to land 3 sharp questions than 8
mushy ones. Heuristics:

- Explicit "TBD", "Open question", "Need to decide", "?".
- Sections literally titled "Open questions" / "Decisions to make".
- Places where the plan hedges between options without committing
  ("we could either X or Y", "leaning toward A but B is viable").
- Architectural forks the plan flags but defers.

Skip: rhetorical questions, things the plan already commits to,
nice-to-haves the author marked "later".

For each pick, draft:

- A short **topic title** (becomes the H3 heading — e.g.,
  *"Feature flag provider"*, *"Where idle-timeout config lives"*).
- A focused **question body** the user can answer directly. Tailor
  it to the plan's context when you can ("Should we use feature
  flags here, and if so, which provider?"). Fall back to *"How
  would we like to handle this?"* when no good tailored phrasing
  comes to mind.

### 3. Seed the Composer doc

Append a `## Decisions` section to the plan markdown with one H3 per
topic title from step 2, then seed the room.

The MCP's `seedMarkdownPath` reads the file verbatim — it does not
support appending. So build the full seed markdown in memory (source
file contents + `\n\n## Decisions\n\n### <topic 1>\n\n### <topic 2>\n…`)
and pass it as `seedMarkdown` inline:

```
composer_create_room({
  seedMarkdown: "<source plan markdown>\n\n## Decisions\n\n### <topic 1>\n\n### <topic 2>\n…"
})
```

The H3s are intentionally empty — they're anchor targets for the
comments in step 4, and they become the slots where answer prose
lands when the monitor posts suggestions. Do **not** prefill the H3s
with the question text; the question lives on the comment.

If the plan crosses the chaptering threshold (≥5 H2 sections), do
**not** seed a single room — jump to step 7 instead.

### 4. Post anchored question comments

For each H3 from step 2, call `composer_add_comment`:

```
composer_add_comment({
  roomId,
  anchor: {
    headingId: "decisions",        // slugified H2 — typically "decisions"
    textToFind: "<H3 topic title>"  // exact H3 text
  },
  body: "@<invokerName> <focused question>",
  mentions: [invokerUserId],
  state: "ready"
})
```

Key constraints:

- **`state: "ready"`** — the agent is waiting on a human decision,
  not processing. Do not use `"thinking"` here; there's no work in
  flight.
- **`@<user>`-mention** — the user needs a notification per
  decision. Pull the invoker's id and display name from awareness
  (or from the user's saved profile) before posting.
- One comment per H3. Don't batch into a single comment.

If `headingId` resolution fails (the slugified H2 wasn't "decisions"
for some reason), fall back to `composer_get_outline` to look up the
actual id of the `## Decisions` heading and retry.

### 5. Honor the ordered return

`composer_create_room` returned `step1_sayToUser` and
`step2_callTool` (same shape as `composer:create`):

1. **`step1_sayToUser`** — output this **first**. It always starts
   with the `browserUrl` so the user has a way into the doc, and
   carries the `@<your-name>` tagging hint. Light paraphrasing is
   fine; **do not drop the URL or the mention syntax**. You may
   append a single sentence noting how many decision threads you
   posted ("Posted 3 decision threads on `## Decisions`.") — but
   nothing more.
2. **`step2_callTool`** — points at `composer_next_event`. **Do not
   run it inline.** Spawn the monitor subagent (next step), then
   end your turn.

### 6. Spawn the monitor subagent

Use the `Agent` tool with:

- `subagent_type: "general-purpose"`
- `run_in_background: true`
- `description: "Composer monitor: <roomId>"`
- `prompt`: tell the subagent to **invoke the `composer:monitor`
  skill**, then run the loop on `{roomId}` as `{actingAs}`. Don't
  paste the loop rules inline — `composer:monitor` carries them.

Once spawned, **end your turn immediately**. No closing recap, no
"monitor is running" status line. The host already shows a status
indicator for the backgrounded `Agent` call. The protocol is strict:

1. Output `step1_sayToUser` (verbatim or lightly paraphrased).
2. Spawn the `Agent`.
3. End turn. No closing remark.

Also: do **not** poll `composer_next_event` from the main thread —
two listeners on the same room means duplicated replies.

### 7. Chaptering — when the plan has ≥5 H2 sections

For large plans, a single doc is hard to navigate. Apply the
chaptering convention instead of step 3's single-room seed:

1. **Build the index doc's markdown** in memory:

   ```
   # <Plan title from H1>

   ## Chapters

   ## Decisions

   ### <topic 1>
   ### <topic 2>
   …
   ```

   The `## Chapters` section starts empty — you'll backfill it with
   page-mention links once the chapter rooms exist.

2. **Create one chapter room per source H2.** For each H2 section:

   ```
   composer_create_room({
     seedMarkdown: "<back-link page mention to index>\n\n## <H2 title>\n\n<section body>"
   })
   ```

   The back-link is a `+`-style page mention to the index doc — it
   gives every chapter a way home. Collect each chapter room's
   `browserUrl` and `roomId`.

3. **Create the index room** with the markdown from step 7.1, then
   edit the `## Chapters` section to list each chapter as a `+`
   page mention in plan order, one per line. (Use the room's edit
   tools after creation; you can't pre-resolve page mentions in
   inline seed markdown without the chapter roomIds.)

4. **Post anchored question comments on the index doc only.** Same
   shape as step 4 — `headingId: "decisions"`, `textToFind: "<H3
   topic title>"`. **Decisions live only on the index doc in v1.**
   Per-chapter decisions are not supported.

5. **One** `step1_sayToUser` collecting **all** URLs — the index
   first, then each chapter in plan order. Make clear which is the
   index. **One** monitor subagent spawn, on the **index doc**. Do
   not spawn monitors on chapter docs; the index is the
   conversation.

### Refining in Composer

Once the doc is live, the user answers each H3's question by replying
in-thread. The monitor subagent handles every mention — load
`composer:monitor` for the full loop semantics. The relevant pattern
for plan refinement:

When a decision thread gets answered, the monitor posts a
`composer_add_suggestion` with **anchor = H3 text** and **replacement
= H3 text + `\n\n<answer prose>`** (multi-block markdown). The H3
stays in place as a permanent decision topic; the answer prose
becomes the resolution below it. The suggestion **is** the reply — no
redundant text reply. See `composer:suggesting` for span scoping and
ripple coverage when the answer constrains another section.

### Optional export

When the user wants the refined plan back on disk (so plan mode,
`ExitPlanMode`, or downstream tools can point at a canonical `.md`),
load `composer:export` and run `/composer:export <path>`. It's a
one-way overwrite — Composer is the source of truth, the local file
gets replaced.

### Failure handling

- **Setup not done** → `npx @composer-app/mcp@latest setup`, restart
  the CLI.
- **Source file not found / unreadable** → say so plainly and stop.
  Don't pick a different file, don't generate a plan from context.
- **No open decisions found** → tell the user the plan reads as
  fully committed, ask whether they want a plain `composer:create`
  seed instead, and stop. Don't post empty threads.
- **`headingId` resolution fails** → call `composer_get_outline`,
  find the actual id of the `## Decisions` heading, retry the
  comments. If that still fails, surface the error and stop —
  don't post unanchored comments.
- **Server kicked you (4403/4410) or reconnect aborted** → the agent
  left the room. Run `/composer:join <url>` to bring it back.

### When this skill does NOT apply

- The user wants a fresh Composer doc with no decision overlay →
  `composer:create`.
- They pasted a `usecomposer.app/r/<id>` URL → `composer:join`.
- They want you to **produce** a plan from a brief → that's a
  planning skill (plan mode, `/ce-plan`, `/grill-with-docs`). Run
  that first, save the output, then invoke this skill on the file.
- They want a non-plan markdown file (a journal entry, a draft
  essay) opened in Composer → `composer:create`. The decision-thread
  overlay only makes sense for plan-shaped docs.

### Known v1 limitations

- **No runtime composition.** `/composer:plan /grill-with-docs …` as
  a single command is not supported. Claude Code skills don't invoke
  each other programmatically today. Run the planning skill
  separately, save its output, then invoke this skill on the file.
- **No decision-curation review step.** The heuristics in step 2
  commit straight to seeding — there's no "here are the 5 I picked,
  edit before I post" gate. If the picks are off, the user has to
  delete threads in the doc and ask for re-picks.
- **No per-chapter decisions.** In the chaptered model (step 7),
  decision threads live only on the index doc. Chapter-local
  decisions aren't supported.
- **No session resume.** Each `/composer:plan` invocation creates a
  new room. There's no way to reattach to a prior plan room from
  the source file.
- **No graceful MCP-down fallback.** If the Composer MCP isn't
  running, the skill fails noisy. No on-disk degradation.
- **No confirm-before-suggest for ambiguous answers.** When the user
  answers a decision thread, the monitor always posts a suggestion
  (per `composer:monitor` semantics). If the answer is ambiguous,
  the suggestion may be wrong — the user has to reject and
  re-answer rather than the agent asking a clarifying question
  first.
