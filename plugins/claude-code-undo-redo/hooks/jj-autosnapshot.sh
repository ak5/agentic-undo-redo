#!/usr/bin/env bash
# jj-autosnapshot.sh — Claude Code PostToolUse hook
#
# Fires after every file-mutating tool. Runs `jj st` (read-only on disk;
# auto-snapshots if the working copy actually changed). Adds one op-log
# entry per real change.
#
# Self-skips when not applicable. The check is simply: does .jj/ exist
# in this dir? If yes, snapshot. If no, do nothing. To enable in a repo,
# run `jj git init --colocate` once (or type /agentic-undo-redo-init in CC).

set -e

command -v jj >/dev/null 2>&1 || exit 0
[[ -d .jj ]] || exit 0

jj st >/dev/null 2>&1 || true
