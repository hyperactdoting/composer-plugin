---
name: suggesting
description: Use when you're about to call `composer_add_suggestion` — proposing a text replacement in a Composer doc. Covers span scoping (don't replace more than asked), cross-span responses, ripple coverage (so accepting leaves the doc correct), the auto-suggest-on-confirm pattern, and anchor mechanics (`textToFind` / `occurrence` / whitespace / formatting).
---

# Composer suggestions

A suggestion proposes a text replacement: `textToFind` is the literal
span that gets cut out when the user accepts; `replacementText` is what
gets inserted in its place. Pending suggestions render as Replace/With
cards in the doc's sidebar. There's no "just edit" — every text change
goes through the user's accept click.

This skill is the full guide for `composer_add_suggestion`. Load it any
time you're about to call the tool, even on familiar territory — the
failure modes are precise.

## Match the span to the request

Before calling `composer_add_suggestion`, decide what span the user is
actually asking you to change. Three patterns:

### 1. Request scoped to their selection (the common case)

"Rewrite this", "make this clearer", "fix the grammar" — no new span
mentioned. Pass `fromThreadId: <threadId>`. The suggestion inherits the
source thread's exact anchor — the span the user selected,
character-for-character.

```
composer_add_suggestion({
  roomId, fromThreadId: event.threadId, replacementText: "…"
})
```

### 2. Request targets a different span

"Rewrite this whole paragraph", "replace the entire list", "change the
heading". Supply `anchor` (`headingId` + `textToFind`) for the span the
user actually named. Do **not** pass `fromThreadId` — you're no longer
inheriting the thread's span.

### 3. Proactive suggestion with no source thread

Supply `anchor`. Keep `textToFind` tight — do not widen beyond what
you're actually replacing.

**Picking a broader `textToFind` than the user asked for is the main
failure mode.** When in doubt, default to path 1.

## Cross-span: respond anywhere in the doc

A thread is anchored to one span, but your response isn't confined to
it. When the user's question (or your own judgment) points elsewhere:

- **Suggest on a different span** — call `composer_add_suggestion` with
  an explicit `anchor`. You can post multiple suggestions in one turn.
  E.g. user says *"the flour amount is off and so is the bake time"* →
  two suggestions, each anchored to its own span.
- **Open a new thread elsewhere** — `composer_add_comment` with its own
  anchor. Useful for cross-references ("see also the conclusion") or
  raising something the user didn't ask about but should see.
- **Still reply on the original thread too** if the user's question
  deserves a direct answer — but only when the reply says something the
  suggestion/new-comment doesn't already convey. Don't post "see my
  suggestion"; the card IS the answer.

Order of operations for a multi-span response: post the
suggestion(s) / new comment(s) first, then (optionally) a reply on the
originating thread pointing out the bigger picture.

## Suggest completely — accepting must leave the doc correct

The user clicks Accept and is done. They should never have to hunt down
downstream edits you forgot.

**Load enough context before you suggest.** The mention event gives you
`sectionMarkdown` for the containing section — usually enough for
wording changes. For anything that might appear elsewhere in the doc
(numbers, names, product/feature references, versions, dates,
terminology, heading text), call `composer_get_full_doc` first. One
extra read is much cheaper than shipping a broken doc.

**Scan for ripples before posting.** Common ones:

- **Counts and enumerations.** "The three examples below" / "three
  things to remember" — adding or removing an item ripples to the count
  and ordinal words ("first", "finally").
- **Cross-references.** "As in section 2", "see the conclusion", "per
  step 3 above". If your edit moves or renames the target, update the
  reference too.
- **Restated facts.** Recipes mention an ingredient twice; release notes
  cite a version in both intro and body; specs quote a number in a
  heading and a paragraph. One fact, multiple spans — cover all of them.
- **Subject/verb and pronoun agreement.** "X and Y are" → trim to just X
  → "X is".
- **Neighboring flow.** Rewriting sentence 2 can break sentence 3 ("This
  is why..."). Fix the continuation.
- **Heading changes.** If you change heading text, prose that says "see
  the Intro section" may need updating.

**Post every ripple as its own suggestion, in the same turn.** The tool
accepts one anchor per call — call it multiple times. Each suggestion
stays tight to its own span (this is NOT oversuggesting — it's covering
the actual surface of the change).

If a ripple is too structural for a clean suggestion (reorder a list,
split a paragraph), post the ones you can AND a short reply flagging
what's still open. The user shouldn't be surprised.

When in doubt about the scope of a ripple, fetch the full doc. Don't
guess.

## Auto-suggest when the user confirms a concrete proposal

Two turns, not three. When a user flags something qualitative (*"this
is too much flour"*, *"this sentence is clunky"*, *"this number feels
off"*):

1. **Turn 1 — propose.** Reply on the thread with one specific
   alternative phrased as a check: *"Does 200g seem right?"*, *"How
   about 'gently fold' instead of 'stir'?"*, *"Would 45 minutes read
   better than 90?"*. Pick a real number or phrase — not *"would you
   like me to suggest a different amount?"* (that's a question about
   your behavior, not a proposal).
2. **Turn 2 — commit on confirmation.** When the user replies with any
   variant of yes ("yes", "sure", "go for it", "perfect", a thumbs-up
   emoji), call `composer_add_suggestion` with `fromThreadId:
   event.threadId` and the concrete replacement. Do **not** also post a
   comment reply — the suggestion card IS your reply.

If the user says no / picks a different value / redirects, follow their
lead — don't post the original proposal anyway.

If you can't name a concrete alternative (the thread is too abstract to
guess a number), ask a clarifying question instead. Don't propose
something generic just to fill the slot — *"Would you like me to
shorten this?"* is worthless without a target length.

## Anchor mechanics

Write tools take:

```
{ headingId: "intro-0", textToFind: "the exact words to anchor on", occurrence?: 1 }
```

`textToFind` is literally cut out on accept. Pick the right span:

- **Anchor the whole unit you're changing.** Replacing a sentence →
  include the terminal punctuation (`.`, `?`, `!`). Replacing a bullet
  item → anchor the item's text (not the `- ` marker; that's block
  structure). Replacing a paragraph → anchor the whole paragraph.
- **Include any trailing punctuation you're changing.** Converting a
  statement to a question? End the anchor at the `.`, end the
  replacement with `?`. Don't anchor "the statement" alone and replace
  with "the question?" — you'll end up with `the question?.`.
- **Match `replacementText`'s shape to the anchor's shape.** Inline
  replacement inside a paragraph → replacement is inline (no leading
  `- `, `#`, or blank line). Replacing a full list → replacement is a
  full markdown list.
- **Formatting is part of your replacement, not the anchor.** If the
  original had `**bold**` or a link, the anchor's formatting is gone on
  accept — your replacement must include the markdown for any
  formatting you want preserved.
- **Anchor at token boundaries, not mid-word.** `textToFind: "istrat"`
  to hit the middle of "administration" is fragile. Use whole words or
  sentence boundaries. Use `occurrence` when the same phrase appears
  multiple times.
- **Whitespace.** Default: no leading or trailing whitespace in the
  anchor, end `replacementText` at the same boundary. If you include a
  trailing space in the anchor, include one in the replacement; otherwise
  words smash together.

If you get `text_not_found`, the error message includes the current
section text. Re-plan against the fresh text and retry. Never retry
with stale content.
