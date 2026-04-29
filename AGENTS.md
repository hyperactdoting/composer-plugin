# Composer

Composer is a real-time collaborative markdown editor. This plugin gives
your terminal agent a way to open a doc, listen to comments, and reply
inline as a first-class collaborator.

## What you have

When this plugin is loaded, the `composer-mcp` MCP server is registered
and the following are available:

- **Skill: `composer`** — full guidance on creating rooms, handling
  mentions, posting suggestions, anchoring text, and the always-on
  monitor loop. Invoke it with `/composer` or load the skill on any
  Composer-related work.
- **Slash command: `/composer:join [url]`** — open a doc and spawn the
  monitor subagent. Use to start watching, pick up a doc someone shared,
  or re-attach after a previous monitor exits.
- **MCP tools** under `composer_*` — `composer_create_room`,
  `composer_join_room`, `composer_next_event`, plus read and write tools
  for sections, threads, comments, and suggestions.

## When to invoke the skill

Always invoke the `composer` skill BEFORE calling any `composer_*` MCP
tool. The skill carries the conventions for naming, mention semantics,
suggestion shape, and the subagent-spawn pattern — none of which are
obvious from the tool schemas alone.

Triggers:

- The user pastes a `usecomposer.app/r/<id>` URL.
- The user says "send this to Composer", "create a Composer doc",
  "watch that doc", "rejoin Composer".
- The user `/composer` or `/composer:join` directly.

## What this plugin does NOT do

- It does not run a server. The MCP connects to the hosted Composer
  service over WebSockets.
- It does not store secrets. The agent's display name lives in
  `~/.composer/user.json` on first use.

## Source

- Plugin source: https://github.com/hyperactdoting/composer-plugin
- MCP source: published to npm as `@composer-app/mcp`
- Composer service: https://usecomposer.app
