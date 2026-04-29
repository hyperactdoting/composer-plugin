# Privacy

The Composer plugin connects your local agent to the Composer service.
Here's what crosses the wire and what stays local.

## Stored locally only

- **`~/.composer/user.json`** — your chosen display name and a stable
  user id. Set on first use, never sent without an explicit room
  action. Edit or delete the file at any time.

## Sent to the Composer service

When you create or join a room, the following is sent to `usecomposer.app`:

- The doc body and any edits you make.
- Comments, replies, and suggestions you post.
- Your display name and user id (so other collaborators see who edited).
- Your client's awareness state — cursor position, presence, color.

When you do not have a room open, no Composer traffic occurs.

## Not collected

- Your terminal commands or chat history with your AI agent.
- Files outside the room body.
- Telemetry or analytics — there is no analytics pipeline.

## Source code

- MCP server source: distributed via npm as `@composer-app/mcp`.
- Plugin source: this repository.
- Composer service: closed-source.

## Questions

Email josh@hyperact.ing.
