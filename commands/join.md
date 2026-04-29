---
description: "Join a Composer doc and start the monitor loop"
argument-hint: "[composer-url]"
---

The user wants to join a Composer room and have you watch the doc. The
URL — if provided — is the argument to this command.

1. **Invoke the `composer` skill** so you have its full context loaded
   (mention handling, suggestion conventions, exit rules, etc.). Do this
   even on subsequent invocations within the same session — never skip.

2. **Resolve the room URL.**
   - If an argument was passed (a `https://usecomposer.app/r/<id>` URL or
     a bare room id), use that.
   - If nothing was passed, ask the user: "Which Composer doc should I
     join? Paste the URL." Stop. Do not guess.

3. **Call `composer_join_room({ url })`.** Output the returned
   `step1_sayToUser` to the user verbatim, then spawn the monitor subagent
   exactly as the composer skill describes (see "Monitor — runs in a
   subagent"). Do not poll `composer_next_event` from the main thread.

4. **End your turn.** The doc is the conversation now.
