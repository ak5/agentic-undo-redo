#!/usr/bin/env bash
# jj-autosnapshot.sh — Claude Code PostToolUse hook
#
# Fires after every file-mutating tool. Runs `jj st` (does not modify project
# files; snapshots the working copy if it changed). Adds one op-log
# entry per real change.
#
# Self-skips when the working directory isn't inside a jj repo. To enable one,
# run `jj git init --colocate` once (or type /agentic-undo-redo-init in CC).

set -e

command -v jj >/dev/null 2>&1 || exit 0
jj --ignore-working-copy root >/dev/null 2>&1 || exit 0

jj st >/dev/null 2>&1 || true
