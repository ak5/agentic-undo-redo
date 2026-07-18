#!/usr/bin/env bash
# uninstall.sh — reverse install.sh.
#   --global             clean up ~/.claude/ (default)
#   --project [DIR]      clean up <DIR>/.claude/

set -e

SCOPE="global"
TARGET_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)  SCOPE="global"; shift ;;
    --project) SCOPE="project"; TARGET_DIR="${2:-$PWD}"; [[ -n "$2" && "$2" != -* ]] && shift; shift ;;
    -h|--help) echo "Usage: ./uninstall.sh [--global | --project [DIR]]"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$SCOPE" == "global" ]]; then
  CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
else
  TARGET_DIR="${TARGET_DIR:-$PWD}"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
  CLAUDE_DIR="$TARGET_DIR/.claude"
fi
SETTINGS="$CLAUDE_DIR/settings.json"

bold()  { printf '\e[1m%s\e[0m\n' "$1"; }
green() { printf '\e[32m%s\e[0m\n' "$1"; }

bold "agentic-undo-redo uninstaller"
echo "  scope  -- $SCOPE"
echo "  target -- $CLAUDE_DIR"
echo

bold "Removing codex skills"
CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
if [[ "$SCOPE" == "global" ]]; then
  for name in undo redo undo-stack undo-reset; do
    if [[ -f "$CODEX_DIR/skills/$name/SKILL.md" ]]; then
      rm -rf "$CODEX_DIR/skills/$name"; green "  ✓ removed $CODEX_DIR/skills/$name"
    fi
  done
fi
echo

bold "Removing hook scripts"
for f in "$CLAUDE_DIR/hooks/jj-autosnapshot.sh" "$CLAUDE_DIR/hooks/jj-mark-turn.sh"; do
  if [[ -f "$f" ]]; then rm "$f"; green "  ✓ removed $f"; fi
done
echo

bold "Removing slash commands"
for f in undo.md redo.md undo-stack.md undo-reset.md agentic-undo-redo-init.md; do
  if [[ -f "$CLAUDE_DIR/commands/$f" ]]; then
    rm "$CLAUDE_DIR/commands/$f"; green "  ✓ removed $CLAUDE_DIR/commands/$f"
  fi
done
echo

if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1; then
  bold "Cleaning $SETTINGS"
  tmp=$(mktemp)
  jq '
    if .hooks then
      .hooks |= (
        ( .UserPromptSubmit |= ((. // []) | map(select(
            (.hooks // []) | any(.command | test("jj-mark-turn\\.sh$")) | not
          ))) )
        | ( .PostToolUse |= ((. // []) | map(select(
            (.hooks // []) | any(.command | test("jj-autosnapshot\\.sh$")) | not
          ))) )
        | with_entries(select(.value | length > 0 or (type == "object")))
      )
    else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  green "  ✓ stripped our hooks from $SETTINGS"
fi
echo

bold "Done"
echo
echo "Note — does NOT remove .jj/ directories from your repos."
echo "To fully clean a repo: rm -rf <repo>/.jj"
echo "Existing Claude Code sessions retain old behavior until restarted."
