# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).

## [0.2.0-rc.1] — 2026-07-19

### Added
- Codex CLI support: $undo $redo $undo-stack $undo-reset skills (plugins/codex-undo-redo), installed by install.sh --global when ~/.codex exists. Codex has no prompt-hook surface to mark turn boundaries, so $undo falls back to the previous op-log entry (one level) when the stack is empty.
- GitHub Actions quality gates covering static validation, isolated installer behavior, real Claude/Codex undo-redo flows, and the sibling testbed bootstrap.
- Canonical `dev → main` release flow, pull-request template, RC publishing guide, and main-branch protection.

### Changed
- Undo/redo stack state moved from .claude/.jj-*-stack-* to .jj/{undo,redo}-stack-* — .jj/ is self-ignored by both git (via .jj/.gitignore) and jj, so repos no longer need per-repo gitignore entries, and jj no longer snapshots the stacks into the very op log they index.
- Read-only inspections (/undo-stack current op) use --ignore-working-copy: no repo lock, works under sandboxed / read-only execution.

### Fixed
- Stack state files were tracked by jj working-copy snapshots (recursive bookkeeping).
- Stale documentation still referred to the old stack paths, retired init command, and Claude Code as the only shipped integration.


## [0.1.0] — 2026-05-03

First release. Smart `/undo` and `/redo` for Claude Code, backed by [jj](https://jj-vcs.dev)'s op log. Cursor / Aider / OpenHands adapters on the roadmap.

### Added

**Slash commands:**
- `/agentic-undo-redo-init` — one-time per-repo enable. Auto-runs `git init` if needed (with a sweep against nested git repos to prevent accidental wrappers), then `jj git init --colocate`. Hard-refuses inside git worktrees.
- `/undo` — atomic per-turn rollback via `jj op restore`. Multi-undo walks back through your prompt history.
- `/redo` — symmetric counterpart. Cleared on new prompt.
- `/undo-stack` — read-only inspection of both stacks.
- `/undo-reset` — clear stacks (use after manual `jj op restore`).

**Hooks:**
- `UserPromptSubmit` (`jj-mark-turn.sh`) — push current op id onto undo stack, truncate redo stack.
- `PostToolUse` matcher `Edit|Write|MultiEdit|NotebookEdit|Bash` (`jj-autosnapshot.sh`) — auto-snapshot via `jj st`.

**Status line:**
- `statusline.sh` — opt-in badge. Displays `✓ undo` when armed, `↩N` with N undos available, `↩N ↪M` with redo also available.

**Distribution:**
- Claude Code plugin via `/plugin marketplace add ak5/agentic-undo-redo` then `/plugin install claude-code-undo-redo@ak5-agentic` — official, fully native path. Per-repo enable via `/agentic-undo-redo-init`.
- `npx agentic-undo-redo[@<version>]` — alternative install path for everything else. Supports `--project [DIR]` for repo-scoped install.

**Project structure:**
- `plugins/claude-code-undo-redo/` — the Claude Code plugin (manifest + hooks + commands + statusline).
- `.claude-plugin/marketplace.json` — Claude Code marketplace manifest. This repo IS the marketplace.
- `bin/cli.js` — Node wrapper for `npx`. Calls `install.sh` / `uninstall.sh` internally.

**Documentation:**
- README with the full distribution philosophy (against opaque skill marketplaces; Homebrew-tap-style trust per marketplace).
- Trademark notice for Claude Code, Cursor, Aider, OpenHands, Continue, jj, GitHub, Homebrew.
- [Contributor Covenant 2.1](CODE_OF_CONDUCT.md).
- LinkedIn launch post + hashtag rationale in `socials/linkedin.md`.

### Notes
- Hard dependencies — **jj**, **git**, **jq**, Claude Code with hook support.
- Hooks fire only in repos with `.jj/`. The init slash command is the only opt-in needed (no marker file).
- Pure-jj backend (without `git`) not yet supported — happy to take a PR.
- Cross-Claude-Code-session interference on the same repo is documented but not prevented.
