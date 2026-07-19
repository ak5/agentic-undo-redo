# agentic-undo-redo

[![test](https://github.com/ak5/agentic-undo-redo/actions/workflows/test.yml/badge.svg)](https://github.com/ak5/agentic-undo-redo/actions/workflows/test.yml) [![status: experimental](https://img.shields.io/badge/status-experimental-orange)](#a-note-on-experimental-status) [![version](https://img.shields.io/badge/version-0.2.0--rc.1-yellow)](https://github.com/ak5/agentic-undo-redo/releases) [![license: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

> `/undo` and `/redo` for AI coding agents. One command rolls back the agent's last turn — every tool call in it, atomically. Built on [jj](https://jj-vcs.dev)'s op log. Claude Code and Codex CLI today; Cursor / Aider / OpenHands on the roadmap.

## Status — experimental

The core works. `jj op restore` is stable; this plumbs it into Claude Code's hook surface and Codex CLI skills. The integration plumbing is what's in flux: hook contracts, skill behavior, plugin manifest fields, multi-repo semantics. Pin to an exact version if you depend on it. Breaking changes likely until v1.0.

## Why

AI agents make multi-step edits that look fine one at a time and wrong together. "Undo that" today means the agent re-reads the diff, generates inverse edits, applies them. ~10–30k tokens. 20–60 seconds. Often imperfect.

`/undo` runs `jj op restore` directly. ~50 tokens. ~50ms. Deterministic.

`/redo` is the symmetric half — undo, run lint or tests, redo, run them again. A/B test two states with two keystrokes.

## What you get

For Claude Code:

| Slash command | Effect |
|---|---|
| `/agentic-undo-redo-init` | One-time per-repo enable. Auto-runs `git init` if needed (with a sweep against nested repos), then `jj git init --colocate`. |
| `/undo` | Revert the agent's most recent turn — every tool call collapsed into one atomic undo. Type again to walk back further turns. |
| `/redo` | Re-apply a turn that was undone. Symmetric. Cleared when you submit a new prompt (forging a new timeline). |
| `/undo-stack` | Read-only view of both stacks for this session. |
| `/undo-reset` | Clear stacks (use after manually running `jj op restore`). |

For Codex CLI, the `codex-undo-redo` plugin provides `$undo`, `$redo`, `$undo-stack`, and `$undo-reset`. Its trusted lifecycle hooks mark prompt boundaries and snapshot tool changes, giving the same atomic turn-level behavior. `$undo` retains a one-op fallback when those hooks are not installed or trusted.

Plus a status-line badge: `✓ undo` when armed, `↩3 ↪1` when there's history. Opt-in (see below).

## The lint A/B trick

```
[Claude finishes a turn touching src/auth/]

> /undo
↩  undone — restored to op ab12cd34
M src/auth/login.ts (+12, -3)
M src/db/users.ts (+4, -1)

> !pnpm lint
✓ no errors

> /redo
↪  redone — restored to op ef56gh78

> !pnpm lint
✗ src/auth/login.ts:42:1: no-unused-vars
✗ src/db/users.ts:8:5: prefer-const

→ Claude introduced those 2 errors. Two keystrokes proved it.
```

Same trick for `pnpm test`, `pnpm typecheck`, perf benchmarks — anything you can run from the shell.

## Install

Three paths. Pick whichever fits.

### A. Claude Code plugin (recommended — fully native, all in CC)

Inside Claude Code:

```
/plugin marketplace add ak5/agentic-undo-redo
/plugin install claude-code-undo-redo@ak5-agentic
```

Then in any repo where you want it active:

```
/agentic-undo-redo-init
```

That's it. No terminal commands.

### B. Codex CLI plugin (recommended for Codex)

```sh
codex plugin marketplace add ak5/agentic-undo-redo
codex plugin add codex-undo-redo@ak5-agentic
```

Restart Codex, review and trust the plugin hooks with `/hooks`, then run `jj git init --colocate` once in each repository you want armed.

### C. `npx` (manual installer)

```sh
# install
npx agentic-undo-redo

# install this release candidate after it is published
npx agentic-undo-redo@0.2.0-rc.1

# pin the previous stable release
npx agentic-undo-redo@0.1.0
npx github:ak5/agentic-undo-redo#v0.1.0

# project-scoped (also auto-enables in that dir)
npx agentic-undo-redo install --project /path/to/repo

# uninstall
npx agentic-undo-redo uninstall
```

<details>
<summary>Power-user paths (curl|bash, git clone)</summary>

Not the recommended happy path — use the Claude Code or Codex plugin. These paths exist for compatibility and for users without a plugin workflow.

```sh
# curl | bash bootstrap
curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/main/install.curl.sh | bash

# pinned tag
curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/v0.1.0/install.curl.sh | bash -s -- --version v0.1.0

# don't trust piped-bash blindly — read the script first
curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/main/install.curl.sh | less

# audit-friendly clone-and-run
git clone https://github.com/ak5/agentic-undo-redo
cd agentic-undo-redo && ./install.sh                          # global
                       ./install.sh --project /path/to/repo   # project-scoped
```

</details>

## Try it without committing to a real repo

[`ak5/agentic-undo-redo-testbed`](https://github.com/ak5/agentic-undo-redo-testbed) is a tiny throwaway sandbox. Some text, a bootstrap script, instructions. Clone it, run `./bootstrap.sh`, open Claude Code in the bootstrapped dir, run `/agentic-undo-redo-init`, ask Claude to rewrite some prose, then `/undo`. ~2 minutes end-to-end. Verifies the full auto-`git init` + `jj colocate` path.

## Testing

`npm test` runs static checks plus isolated integration tests for global install/uninstall, Claude Code marked-turn undo/redo, and Codex fallback undo/redo. CI runs that suite on pushes and pull requests. The sibling testbed has its own workflow that verifies its bootstrap-to-fresh-directory and `git`/`jj` initialization path whenever the testbed changes. The agent UI interaction remains a manual smoke test.

## Global vs project install

These scopes apply to the Claude Code integration. The manual global installer also copies the Codex fallback skills into `~/.codex/skills` when `~/.codex` exists; project installs do not install them. The recommended Codex plugin path is managed by Codex itself.

| | Global | Project |
|---|---|---|
| Where | `~/.claude/` | `<repo>/.claude/` |
| Scope | every Claude Code session, any repo | only this repo's sessions |
| Per-repo enable | `/agentic-undo-redo-init` (one slash command per repo) | done automatically by the installer |
| Use when | you want it everywhere | testing on one repo, or your team commits `.claude/` to git |

## Status line badge

Opt-in. The `npx`/manual global installer places the helper at `~/.claude/hooks/statusline.sh`; add it to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/<you>/.claude/hooks/statusline.sh"
  }
}
```

Marketplace installs keep plugin files in Claude's plugin cache; point the command to that installed `statusline.sh` or copy it to a stable path first. When CC is in a jj-armed repo, the bottom of the screen shows `✓ undo` (no history) or `↩3` (3 undos available) or `↩3 ↪1` (also 1 redo available).

If you already have a custom statusline script, append our line via shell composition rather than overwriting yours.

## A note on distribution

Not listed in a curated "skill marketplace." Curated lists give the illusion of security — a curator can't review every commit, clicking Install doesn't read the source. The trust is in infrastructure you don't see.

This repo is the source. Read it. Install when you're satisfied.

`npx` and `@<version>` exist because typing is annoying — not because curated lists are safer.

Claude Code's plugin marketplace path (option A) works under a different trust model: **you** explicitly opt into `ak5/agentic-undo-redo` as a marketplace. Each marketplace is one trust boundary, like a Homebrew tap.

## Dependencies

| | Why |
|---|---|
| **[jj (jujutsu)](https://jj-vcs.dev)** | The whole thing is built on jj's op log. `brew install jj`. |
| **git** | Required for `jj git init --colocate`. The init slash command auto-runs `git init` if your dir isn't yet a repo (with a sweep against nested git repos to prevent accidentally creating a wrapper). `brew install git`. |
| **jq** | Required by the manual installer to safely merge JSON into `~/.claude/settings.json`. `brew install jq`. |
| **Claude Code or Codex CLI** | Choose the integration you use. Claude Code provides turn-boundary hooks; Codex uses skills with a one-op fallback when no marked turn exists. |

I love that jj exists. It's one of those projects that questions a fundamental assumption (git's working tree / staging / commit model) and rebuilds from scratch with cleaner primitives. In the agentic era, when AI is reshaping how we write code, breaking the status quo and asking "wait, why do we do it this way?" is more necessary than ever. jj is exactly that for version control — go give them a star.

## How the Claude Code integration works

```
User submits prompt
  ↓
UserPromptSubmit hook fires (jj-mark-turn.sh):
  • appends current jj op id to .jj/undo-stack-<session-id>
  • truncates .jj/redo-stack-<session-id>
  ↓
Agent runs N file-mutating tools (Edit/Write/MultiEdit/NotebookEdit/Bash)
  ↓
PostToolUse hook fires after each (jj-autosnapshot.sh):
  • runs `jj st` (does not modify project files; snapshots if anything changed)
  ↓
Agent finishes turn. Op log accumulated:
  [turn-start, snap1, snap2, …, snapN]
```

`/undo` pops the top of the undo stack, captures the current op (pushes onto redo stack), and runs `jj op restore <target>`. `/redo` is the mirror image. A new prompt clears the redo stack — once you keep typing forward, undone turns are gone (textbook editor behavior).

The Codex plugin uses the same boundary/snapshot model with Codex lifecycle hooks and `.jj/undo-stack-codex`; its `$undo` and `$redo` skills perform the restore operations.

## Multi-agent roadmap

| Agent | Status |
|---|---|
| Claude Code | ✅ shipped |
| Codex CLI | ✅ shipped |
| Cursor / Aider / OpenHands / Continue.dev | 🚧 contributions welcome |

The undo/redo logic is agent-agnostic — it's just `jj op restore` against a marker file. What differs per agent is the hook equivalent (turn-boundary detection, tool-call detection) and the command-registration mechanism. Open an issue if you want to land an adapter for your favorite agent.

## What it CAN'T break

- Does not rewrite existing commit objects (commits are content-addressed).
- Does not delete operation history as part of undo/redo; recovery remains subject to jj's normal operation-log retention and garbage collection.
- Cannot push anything to remotes.
- Cannot affect teammates — `.jj/` and op log are local; auto-snapshot ops never reach origin.
- Cannot accidentally wrap a parent dir of nested git repos with a fresh `git init` (the init sweeps for nested repos and refuses).

## Limitations

- **External side effects aren't reverted.** `/undo` or `$undo` rolls back tracked file state and jj metadata. If the agent's turn ran a webhook, sent an email, deleted node_modules, pushed to origin — those external effects stay.
- **Concurrent agent sessions on the same repo can interfere.** Claude sessions have separate stack files, while the Codex plugin currently shares one stack per repo; in both cases `jj op restore` changes the repository globally.
- **Manual `jj op restore` makes stacks stale.** Run `/undo-reset` (Claude Code) or `$undo-reset` (Codex) after manual time travel.
- **Gitignored files aren't restored** (e.g. `node_modules/`, `.env.local`).
- **Pushed commits stay pushed.** `git push --force-with-lease` if you want to publish a rollback.

## Going deeper

If the underlying ideas interest you more than the wrapping:

- [**jj**](https://jj-vcs.dev) — the VCS this is built on. Site, install, getting-started.
- [jj user docs](https://jj-vcs.github.io/jj/latest/) — daily-use reference. Op log, revsets, conflicts-as-data.
- [jj technical architecture](https://jj-vcs.github.io/jj/latest/technical/architecture/) — how the working copy as a commit, the operation log, and conflict-storage are designed.
- [Mimram & Di Giusto, *A Categorical Theory of Patches* (2013)](https://arxiv.org/abs/1311.3903) — formal foundation for patch-based VCS (the math behind Pijul; informs jj's design philosophy).
- [Darcs Theory of Patches](http://darcs.net/Theory) — older treatment, the practical roots of patch theory in VCS.
- [Pro Git book, chapter 10 (internals)](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain) — for the comparison: how git's object model differs from what we're using here.

If you want better project docs than the current README, open an issue. There's no GitBook yet — the surface is small enough that the README is the docs.

## Uninstall

```sh
./uninstall.sh                          # global
./uninstall.sh --project /path/to/repo  # project
# or via npx
npx agentic-undo-redo uninstall
# or via plugin marketplace (inside Claude Code)
/plugin uninstall claude-code-undo-redo@ak5-agentic
```

## Repository layout

```
agentic-undo-redo/
├── .claude-plugin/
│   └── marketplace.json                       # Claude Code marketplace manifest
├── plugins/
│   ├── claude-code-undo-redo/                 # the Claude Code plugin
│       ├── .claude-plugin/plugin.json
│       ├── hooks/
│       │   ├── hooks.json
│       │   ├── jj-autosnapshot.sh
│       │   └── jj-mark-turn.sh
│       ├── commands/
│       │   ├── agentic-undo-redo-init.md
│       │   ├── undo.md
│       │   ├── redo.md
│       │   ├── undo-stack.md
│       │   └── undo-reset.md
│       └── statusline.sh
│   └── codex-undo-redo/                       # the Codex CLI plugin
│       ├── .codex-plugin/plugin.json
│       ├── hooks/
│       └── skills/
├── .github/workflows/test.yml                 # hosted quality gate
├── docs/publishing.md                         # RC release procedure
├── tests/                                     # integration + testbed smoke tests
├── bin/cli.js                                  # npx entry — calls install.sh internally
├── install.sh                                  # internal — invoked by npx
├── uninstall.sh                                # internal — invoked by npx uninstall
├── package.json
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

## License

MIT — see [LICENSE](LICENSE).

## Code of Conduct

[Contributor Covenant 2.1](CODE_OF_CONDUCT.md). Short version: keep it about the project, don't be an ass.

## Trademarks

All product names, logos, and brands are property of their respective owners. References to third-party products are for identification only and do not imply endorsement.

- **Claude Code**, **Claude**, and **Anthropic** are trademarks of Anthropic, PBC. This project is not affiliated with or endorsed by Anthropic.
- **Cursor** is a trademark of Anysphere, Inc.
- **Aider** is the trademark/property of its respective project.
- **OpenHands** (formerly OpenDevin) is the trademark/property of its respective project.
- **Continue** is a trademark of Continue, Inc.
- **jj** / **jujutsu** is the project of Martin von Zweigbergk and contributors.
- **GitHub** is a trademark of GitHub, Inc.
- **Homebrew** is a trademark of the Homebrew project.

Use of these names in this README is descriptive only.
