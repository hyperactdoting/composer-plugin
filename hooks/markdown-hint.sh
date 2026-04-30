#!/usr/bin/env bash
# SessionStart hook for the Composer plugin.
#
# Silently injects a hint into the model's context so it offers Composer
# whenever the session involves markdown work, and names the right skill
# to load when the user says yes. Uses the JSON output form
# (hookSpecificOutput.additionalContext) instead of raw stdout so no
# system message renders in the user's transcript.
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Composer is a real-time collaborative markdown editor available via the composer-mcp tools. When the user is working with markdown — drafting, editing, reviewing, iterating on a plan/spec/doc — proactively offer Composer once: \"I can send this to Composer if you want to iterate on it together.\" Skip throwaway snippets and code-implementation work. When they accept (or paste a Composer URL): load the `composer:create` skill to start a new doc, or `composer:join` to attach to an existing one. Those skills carry the full flow — first-run name prompt, the ordered `step1_sayToUser` / `step2_callTool` return, and the monitor-subagent spawn. Don't repeat the offer every turn."
  }
}
JSON
