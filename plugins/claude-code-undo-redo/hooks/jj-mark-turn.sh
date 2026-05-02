#!/usr/bin/env bash
# jj-mark-turn.sh — Claude Code UserPromptSubmit hook
#
# Records the current jj op id as a turn boundary on the undo stack and
# clears the redo stack (a new prompt forges a new timeline; previously
# undone work cannot be re-redone).
#
# Self-skips if jj isn't installed or .jj/ doesn't exist in this dir.

set -e

command -v jj >/dev/null 2>&1 || exit 0
[[ -d .jj ]] || exit 0

SID="${CLAUDE_SESSION_ID:-default}"
mkdir -p .claude

# Push current op onto the undo stack (LIFO; tail of file = top of stack).
jj op log --limit 1 --no-graph -T 'self.id().short()' 2>/dev/null \
  >> ".claude/.jj-undo-stack-${SID}"

# Truncate the redo stack — new timeline starts here.
: > ".claude/.jj-redo-stack-${SID}"
