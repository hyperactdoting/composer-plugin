---
name: export
description: Use when the user wants to dump a Composer doc's current contents to a local markdown file — running `/composer:export <path>`, asking to "save this Composer doc to disk", or to "export the room as markdown". This is ONE-WAY — Composer is the source of truth and the local file is overwritten on every export. There is no merge, no diff, no two-way sync.
---

# Composer — Export to a local file

`composer_export_to_file` writes the current room contents to a local
markdown file. **There is no merge, no diff, no two-way sync** —
Composer is authoritative; whatever's at the path becomes a fresh
snapshot on every export. **If a file already exists at the path, the
export will overwrite it.** Always confirm with the user first when
that's the case — see step 3 below.

## Steps

### 1. Resolve the room

- If exactly one Composer room is attached this session, use it.
- If multiple are attached, ask: *"Which doc — paste the URL or
  roomId."* Stop. Do not guess.
- If none are attached, ask the user to `/composer:join <url>` first,
  then re-run.

### 2. Resolve the path

- The argument **must be an absolute path**. If it's relative, ask the
  user for an absolute one (or resolve it against the current working
  directory if unambiguous — but confirm before doing so).
- The parent directory must already exist. The MCP will not create
  directories.

### 3. Check for an existing file and ask permission before overwriting

Before calling the export tool, check whether anything is at the
target path (use whatever read-only tool your host gives you — `ls`,
`stat`, `Read`, etc.):

- **File does not exist** — proceed straight to step 4. No confirmation
  needed; nothing is at risk.
- **File exists** — STOP and ask the user explicitly. Show them the
  path and the consequence in one short line, e.g.:

  > *`{path}` already exists. Exporting will overwrite it. Want me to
  > go ahead?*

  Wait for an affirmative answer (yes / sure / go ahead / 👍) before
  calling the tool. If they say no or pick a different path, follow
  their lead — do NOT call the tool with the original path.

Do not silently overwrite. The user typing `/composer:export <path>`
opts them into the export, not into clobbering arbitrary local files
without warning.

### 4. Call `composer_export_to_file`

```
composer_export_to_file({ roomId, path: "<absolute>" })
```

Returns `{ roomId, path, bytesWritten }`.

### 5. Confirm in one short line

> *"Exported to `{path}` ({bytes} bytes)."*

End your turn. No follow-up call needed.
