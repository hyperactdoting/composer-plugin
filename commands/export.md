---
description: "Export a Composer doc to a local markdown file (one-way, always overwrites)"
argument-hint: "<absolute-path>"
---

The user wants to dump a Composer doc's current contents to a local
markdown file. **This is ONE-WAY** — Composer is the source of truth,
the local file gets overwritten on every export. There is no merge,
no diff, no two-way sync. Make sure the user knows that if they're
about to lose local changes.

1. **Resolve the room.**
   - If exactly one Composer room is attached this session, use it.
   - If multiple are attached, ask: "Which doc — paste the URL or
     roomId." Stop. Do not guess.
   - If none are attached, ask the user to `/composer:join <url>`
     first, then re-run this.

2. **Resolve the path.**
   - The argument MUST be an absolute path. If it's relative, ask the
     user to provide an absolute one (or resolve it against the
     current working directory if obvious — but confirm before doing
     so).
   - The parent directory must already exist. The MCP will not create
     directories.
   - If the file already exists at `path`, that's expected — this
     command always overwrites. Do not ask for confirmation; the
     user already opted in by running this command.

3. **Call `composer_export_to_file({ roomId, path })`.** It returns
   `{ roomId, path, bytesWritten }`.

4. **Confirm to the user** in one short line:
   *"Exported to `{path}` ({bytes} bytes)."*

5. **End your turn.** No follow-up call needed.
