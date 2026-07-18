#!/usr/bin/env bash
set -euo pipefail

TESTBED="${1:?usage: testbed-smoke.sh PATH_TO_TESTBED}"
WORK="$(mktemp -d)"
DEST="$WORK/fixture"
trap 'rm -rf "$WORK"' EXIT

bash "$TESTBED/bootstrap.sh" "$DEST" >/dev/null
[[ -f "$DEST/story.md" && -f "$DEST/notes.md" ]]
if git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
  echo "bootstrap target unexpectedly belongs to a git repository" >&2
  exit 1
fi

git -C "$DEST" init -q
jj git init --colocate "$DEST" >/dev/null
[[ -d "$DEST/.git" && -d "$DEST/.jj" ]]
echo "testbed smoke test passed"
