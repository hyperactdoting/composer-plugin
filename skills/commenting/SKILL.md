---
name: commenting
description: Use when you're about to call `composer_reply_comment`, `composer_reply_suggestion`, or `composer_add_comment` — replying or commenting in a Composer thread. Covers terseness rules, when a suggestion replaces a reply, and the reply-vs-new-comment-vs-suggestion decision.
---

# Composer comments and replies

Comment threads in Composer render in a narrow sidebar — think Figma's
comment box, not a chat window. Long replies get unwieldy fast. The
rules below keep threads readable.

This skill is the full guide for any text reply or new comment. Load it
when you're about to call a `composer_reply_*` or `composer_add_comment`
tool.

## Terseness

- **Answer in 1–3 sentences. Prefer one.**
- **Reply directly to the question asked** — no preamble ("Great
  question!"), no restating the ask, no trailing summary of what you
  just did.
- Never dump your reasoning or tool-call chatter into a comment.
- If the answer genuinely needs structure (a list of 4+ items, code, a
  table) and a suggestion isn't the right shape, post it as a suggestion
  in the doc body instead of as a comment reply. The sidebar is the
  wrong shape for that content.

Terse beats thorough. If the user wants more, they'll ask.

## Don't double-post: a suggestion IS your reply

If you post a suggestion in response to the thread, **do not also post
a comment reply.** The suggestion renders as a Replace/With card in the
sidebar already; a pointer comment ("see the suggestion") just
duplicates what the user can already see.

Silent suggestion-only responses are correct and expected. The user
gets a visible card; the agent's reasoning is in the suggestion's
shape, not in a separate sentence.

The only time to post both is when the reply says something the
suggestion can't convey on its own — context, a follow-up question, an
explicit flag that there are companion edits elsewhere. That's rare;
default to suggestion-only.

## Reply vs new comment vs suggestion — quick decision

When the user's message in a thread asks for something, pick the shape
of your response from this:

| Shape | Use when |
|---|---|
| **Suggestion only** | The user asked for a text change ("rewrite this", "make it 200g", "tighten the wording"). The change IS the response. |
| **Suggestion + new comment elsewhere** | The text change ripples to a different span. Suggest each span separately, then leave a comment on the originating thread saying *"also touched X"* — only if the ripples aren't otherwise obvious. |
| **Reply only** | The user asked a question that has a textual answer ("when did we ship that?", "is Jesse still on this?"). No text change involved. Keep it short. |
| **Suggestion + reply on origin thread** | You changed text AND need to say something the change can't convey alone (caveat, a follow-up question, "I changed two other places too"). |
| **New comment elsewhere** | You're raising something the user didn't ask about but should see — a cross-reference, an inconsistency, a heads-up. Anchor it where it actually belongs, not on the thread you were called from. |

For suggestion craft (anchoring, ripples, multi-span), load
**`composer:suggesting`**.

## State and the ack-first flow

Every agent-authored reply / comment / suggestion carries a lifecycle
state the UI animates: **`thinking → working → replying → ready`**.
The mention loop in `composer:monitor` opens this with an ack-first
reply (`state: "thinking"`); from there you advance state with
`composer_agent_status`:

```
composer_agent_status({
  roomId,
  threadId,
  replyId?,        // identifies which reply you own; omit for thread-head
  state,           // "thinking" | "working" | "replying" | "ready"
  text?,           // rewrite the body (only meaningful on "ready")
  note?,           // short human-readable progress line
  kind?            // "comment" | "suggestion" — disambiguates head records
})
```

- `thinking` — initial ack, set by the `composer_add_*` /
  `composer_reply_*` call that posted it.
- `working` — substantive work in flight (reading the doc, computing,
  drafting). Set this whenever you expect a gap.
- `replying` — about to write the final text. Optional, brief.
- `ready` — done. Pass `text: "<final body>"` to rewrite the ack in
  place atomically; the awareness heartbeat is pruned in the same call.

**Silence is the failure mode.** If you're about to do something slow
(fetch the full doc, compute a non-trivial diff, call another tool)
transition to `working` first. The UI collapses transitions faster
than ~400 ms, so don't worry about being too fast — worry about being
silent for >2 s without a `working` flip. Use `note` to surface
progress where it helps: `note: "Reading section 3…"`,
`note: "Drafting suggestion…"`.

**Rewrite-on-ready replaces a duplicate "done" reply.** When the
substantive answer is a standalone artifact (a suggestion, a
cross-span comment, a doc link), DO NOT post a second pointer reply.
Rewrite the existing ack in place to a thin pointer and mark `ready`
in the same call:

```
composer_agent_status({
  roomId, threadId, replyId,
  state: "ready",
  text: "Posted a suggestion below."
})
```

When the substantive answer IS the reply text, do the same — rewrite
the ack to that text and set `ready` in the same call. Do not post a
separate follow-up reply.

### Worked example — ack-then-suggestion

```
// 1. Mention arrives via composer_next_event.
//    { kind: "mention", threadId: "t_abc", invokerUserId: "u_jess",
//      invokerName: "Jess", reason: "direct_mention", ... }

// 2. Ack first.
const { replyId } = composer_reply_comment({
  roomId, threadId: "t_abc",
  text: "@Jess — on it",
  mentions: ["u_jess"],
  state: "thinking",
});

// 3. Transition to working before any slow step.
composer_agent_status({
  roomId, threadId: "t_abc", replyId,
  state: "working",
  note: "Reading section 3…",
});

// 4. Post the substantive artifact.
composer_add_suggestion({
  roomId, fromThreadId: "t_abc", replacementText: "…",
});

// 5. Rewrite the ack and mark ready atomically.
composer_agent_status({
  roomId, threadId: "t_abc", replyId,
  state: "ready",
  text: "Posted a suggestion below.",
});
```

No extra pointer reply. The rewrite + suggestion card together are
the complete response.

## Empty acknowledgements: don't

Never post a reply that's just "👍", "got it", or "thanks". If the
user's message doesn't actually need a response (a thank-you back to
you, a stage direction, a note-to-self), stay silent. Posting an empty
ack adds noise to the sidebar.
