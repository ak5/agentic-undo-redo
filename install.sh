#!/usr/bin/env bash
# install.sh — top-level installer.
#
#   --global  (default) — installs into ~/.claude/. Hooks fire in any repo
#                          that has .jj/. Use /agentic-undo-redo-init from
#                          inside Claude Code to enable a specific repo.
#   --project [DIR]      — installs into <DIR>/.claude/ AND runs jj-colocate
#                          in <DIR>. Single command: install + enable.
#
# OFFICIAL Claude Code path is the plugin marketplace:
#   /plugin marketplace add ak5/agentic-undo-redo
#   /plugin install claude-code-undo-redo@ak5-agentic
# This script is the manual-install fallback.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/plugins/claude-code-undo-redo"

SCOPE="global"
TARGET_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)  SCOPE="global"; shift ;;
    --project) SCOPE="project"; TARGET_DIR="${2:-$PWD}"; [[ -n "$2" && "$2" != -* ]] && shift; shift ;;
    -h|--help)
      cat <<EOF
Usage: ./install.sh [--global | --project [DIR]]

  --global             install into ~/.claude/ (default)
  --project [DIR]      install into <DIR>/.claude/ AND auto-enable in <DIR>
                       (defaults to current dir)
EOF
      exit 0 ;;
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

bold()   { printf '\e[1m%s\e[0m\n' "$1"; }
green()  { printf '\e[32m%s\e[0m\n' "$1"; }
yellow() { printf '\e[33m%s\e[0m\n' "$1"; }
red()    { printf '\e[31m%s\e[0m\n' "$1" >&2; }

check() {
  local cmd="$1" hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then green "  ✓ $cmd"; return 0; fi
  red "  ✗ $cmd not found"; red "    install with: $hint"; return 1
}

# ─── preflight ──────────────────────────────────────────────────────────────
bold "agentic-undo-redo installer"
echo "  scope    -- $SCOPE"
echo "  target   -- $CLAUDE_DIR"
echo

bold "Checking dependencies"
deps_ok=true
check jj  "brew install jj"   || deps_ok=false
check jq  "brew install jq"   || deps_ok=false
check git "brew install git"  || deps_ok=false
$deps_ok || { red "Install missing dependencies and re-run."; exit 1; }
echo

# ─── install files ──────────────────────────────────────────────────────────
bold "Installing files"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/commands"

cp "$PLUGIN_DIR/hooks/jj-autosnapshot.sh" "$CLAUDE_DIR/hooks/"
cp "$PLUGIN_DIR/hooks/jj-mark-turn.sh"    "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/jj-autosnapshot.sh" "$CLAUDE_DIR/hooks/jj-mark-turn.sh"
cp "$PLUGIN_DIR/commands/"*.md "$CLAUDE_DIR/commands/"
green "  ✓ hooks + slash commands → $CLAUDE_DIR"

HOOK_AUTOSNAP="$CLAUDE_DIR/hooks/jj-autosnapshot.sh"
HOOK_MARKTURN="$CLAUDE_DIR/hooks/jj-mark-turn.sh"
[[ ! -f "$SETTINGS" ]] && echo '{}' > "$SETTINGS"

tmp=$(mktemp)
jq --arg autosnap "$HOOK_AUTOSNAP" --arg markturn "$HOOK_MARKTURN" '
  .hooks //= {}
  | .hooks.UserPromptSubmit //= []
  | .hooks.PostToolUse //= []
  | (
      if any(.hooks.UserPromptSubmit[]?; (.hooks // []) | any(.command == $markturn))
      then . else .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $markturn}]}] end
    )
  | (
      if any(.hooks.PostToolUse[]?; (.hooks // []) | any(.command == $autosnap))
      then . else .hooks.PostToolUse += [{"matcher": "Edit|Write|MultiEdit|NotebookEdit|Bash", "hooks": [{"type": "command", "command": $autosnap}]}] end
    )
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
green "  ✓ hooks block merged into $SETTINGS"
echo

# ─── project install also auto-enables in TARGET_DIR ────────────────────────
if [[ "$SCOPE" == "project" ]]; then
  bold "Auto-enabling in $TARGET_DIR"

  if [[ -f "$TARGET_DIR/.git" ]]; then
    yellow "  ⚠  $TARGET_DIR is a git worktree — jj cannot colocate here. Skipping."
    yellow "     run install.sh --project against the MAIN worktree instead."
  elif [[ -d "$TARGET_DIR/.jj" ]]; then
    green "  ✓ jj already colocated in $TARGET_DIR"
  else
    # Auto git-init if not yet a git repo. Sweep for nested repos first.
    if ! (cd "$TARGET_DIR" && git rev-parse --git-dir >/dev/null 2>&1); then
      nested=()
      for d in "$TARGET_DIR"/*/ ; do
        [[ -d "${d}.git" ]] && nested+=("$(basename "${d%/}")")
      done
      if (( ${#nested[@]} > 0 )); then
        red "  ✗ $TARGET_DIR is not a git repo, but contains ${#nested[@]} nested git repo(s):"
        for n in "${nested[@]}"; do red "    • $n"; done
        red "    refusing to auto-init a wrapper around them."
        red "    run install.sh --project on one of those subdirs instead."
        exit 1
      fi
      (cd "$TARGET_DIR" && git init -q)
      green "  🌱 git init in $TARGET_DIR (was not a git repo)"
    fi

    if (cd "$TARGET_DIR" && jj git init --colocate >/dev/null 2>&1); then
      green "  ✓ jj git init --colocate ran in $TARGET_DIR"
    else
      red "  ✗ jj init failed in $TARGET_DIR"
      exit 1
    fi
  fi
  echo
fi

# ─── done ───────────────────────────────────────────────────────────────────
bold "Done"
echo
if [[ "$SCOPE" == "global" ]]; then
  echo "Per-repo enable: in any Claude Code session, type /agentic-undo-redo-init"
  echo "(it auto-runs git init + jj git init --colocate, with safety checks)"
else
  echo "Project install complete — /undo and /redo are armed in $TARGET_DIR."
  echo "Open a new Claude Code session there and try /undo after Claude makes an edit."
fi
echo
echo "Reverse install: $SCRIPT_DIR/uninstall.sh ${SCOPE:+--$SCOPE${TARGET_DIR:+ \"$TARGET_DIR\"}}"
