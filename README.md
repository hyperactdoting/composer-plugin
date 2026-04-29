# Composer plugin

Real-time collaborative markdown editing for your terminal agent. This
plugin pairs Claude Code, Codex CLI, and other compatible hosts with the
[Composer](https://usecomposer.app) editor — comments, suggestions, and
inline replies, all in a shared doc.

> **This repository is auto-generated.** Source of truth lives in the
> private Composer monorepo at `plugin-adapter/`. Pull requests against
> this repo will be overwritten on the next sync. File issues against
> [the source repo](https://github.com/hyperactdoting/composer) instead.

## Install

### Claude Code

Two steps — add the marketplace, then install the plugin:

```bash
claude plugin marketplace add hyperactdoting/composer-plugin
claude plugin install composer@composer-plugin
```

### Codex CLI

Codex installs from the same repo — see Codex CLI docs for the current
plugin command. The repo's layout (`.claude-plugin/plugin.json`,
`AGENTS.md`, `skills/`, `commands/`) is the format Codex expects too.

### Other hosts (Cursor, Windsurf, Gemini)

These hosts don't have a plugin system yet — install the MCP server
directly and use the included `AGENTS.md` as a guide:

```bash
npx -y @composer-app/mcp@latest setup
```

## What you get

- **Slash command `/composer:join [url]`** — open a doc, spawn the
  always-on monitor subagent, reply to mentions inline.
- **Skill `composer`** — invoked automatically when you reference a
  Composer doc, or manually with `/composer`. Teaches your agent how to
  use the rest of the plugin.
- **MCP server `composer-mcp`** — registered on install via `.mcp.json`.
  Provides the `composer_*` tools: room creation/join, mention loop,
  comments, suggestions, threads, sections.

## What's inside

| Path | What |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.claude-plugin/marketplace.json` | Marketplace listing (this repo doubles as a marketplace) |
| `.mcp.json` | MCP server registration — pinned to `@composer-app/mcp@0.0.1-beta.6` |
| `commands/join.md` | `/composer:join` slash command |
| `skills/composer/SKILL.md` | The full `composer` skill |
| `AGENTS.md` | Codex / general-purpose entry point |

## Versioning

This plugin tracks the underlying `@composer-app/mcp` npm package. Each
release publishes the matching version of both. The current pinned
version is **0.0.1-beta.6**.

## License

MIT — see [LICENSE](./LICENSE).
