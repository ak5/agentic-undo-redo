#!/usr/bin/env bash
# statusline.sh — Claude Code statusline contributor.
#
# Outputs a one-line badge showing undo/redo readiness for the CURRENT repo.
# Wired in via ~/.claude/settings.json under "statusLine":
#
#   "statusLine": {
#     "type": "command",
#     "command": "/path/to/this/statusline.sh"
#   }
#
# Badge format:
#   ✓ undo            (jj armed; no undo history yet)
#   ↩3                (3 turns in undo stack)
#   ↩3 ↪1             (3 undo, 1 redo available)
#   (empty)           (jj not initialized in this repo)

set -e

# Resolve the working directory. CC may pass it via env; fall back to PWD.
CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Silently skip if jj isn't here.
[[ -d "$CWD/.jj" ]] || exit 0

SID="${CLAUDE_SESSION_ID:-default}"
UNDO="$CWD/.claude/.jj-undo-stack-${SID}"
REDO="$CWD/.claude/.jj-redo-stack-${SID}"

und=0; red=0
[[ -s "$UNDO" ]] && und=$(wc -l <"$UNDO" | tr -d ' ')
[[ -s "$REDO" ]] && red=$(wc -l <"$REDO" | tr -d ' ')

if (( und == 0 && red == 0 )); then
  printf '✓ undo'
elif (( red == 0 )); then
  printf '↩%d' "$und"
else
  printf '↩%d ↪%d' "$und" "$red"
fi
