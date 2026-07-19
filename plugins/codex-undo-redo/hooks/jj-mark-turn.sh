#!/usr/bin/env bash
set -e

command -v jj >/dev/null 2>&1 || exit 0
ROOT="$(jj --ignore-working-copy root 2>/dev/null)" || exit 0

jj op log --limit 1 --no-graph -T 'self.id().short() ++ "\n"' 2>/dev/null \
  >> "$ROOT/.jj/undo-stack-codex"
: > "$ROOT/.jj/redo-stack-codex"
