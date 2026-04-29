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

## Empty acknowledgements: don't

Never post a reply that's just "👍", "got it", or "thanks". If the
user's message doesn't actually need a response (a thank-you back to
you, a stage direction, a note-to-self), stay silent. Posting an empty
ack adds noise to the sidebar.
