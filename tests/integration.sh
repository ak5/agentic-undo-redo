#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "expected '$2', got '$1'"; }

extract_command() {
  local source="$1" output="$2"
  awk '/^```bash$/ { inside=1; next } /^```$/ && inside { exit } inside' "$source" > "$output"
  bash -n "$output"
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name "CI Test"
  git -C "$repo" config user.email "ci@example.invalid"
  printf 'original\n' > "$repo/story.txt"
  git -C "$repo" add story.txt
  git -C "$repo" commit -qm initial
  jj git init --colocate "$repo" >/dev/null
}

echo "== installer sandbox =="
fake_home="$WORK/home"
mkdir -p "$fake_home/.codex"
HOME="$fake_home" CLAUDE_DIR="$fake_home/.claude" CODEX_DIR="$fake_home/.codex" \
  bash "$ROOT/install.sh" --global >/dev/null
for name in undo redo undo-stack undo-reset; do
  [[ -f "$fake_home/.codex/skills/$name/SKILL.md" ]] || fail "installer missed Codex skill $name"
done
[[ -f "$fake_home/.claude/hooks/jj-mark-turn.sh" ]] || fail "installer missed Claude hook"
HOME="$fake_home" CLAUDE_DIR="$fake_home/.claude" CODEX_DIR="$fake_home/.codex" \
  bash "$ROOT/uninstall.sh" --global >/dev/null
[[ ! -e "$fake_home/.codex/skills/undo" ]] || fail "uninstaller left Codex skill"

echo "== Claude turn undo/redo =="
claude_repo="$WORK/claude"
init_repo "$claude_repo"
(
  cd "$claude_repo"
  CLAUDE_SESSION_ID=ci bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-mark-turn.sh"
  printf 'changed by claude\n' > story.txt
  bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-autosnapshot.sh"
)
extract_command "$ROOT/plugins/claude-code-undo-redo/commands/undo.md" "$WORK/claude-undo.sh"
extract_command "$ROOT/plugins/claude-code-undo-redo/commands/redo.md" "$WORK/claude-redo.sh"
(cd "$claude_repo" && CLAUDE_SESSION_ID=ci bash "$WORK/claude-undo.sh" >/dev/null)
assert_eq "$(<"$claude_repo/story.txt")" "original"
(cd "$claude_repo" && CLAUDE_SESSION_ID=ci bash "$WORK/claude-redo.sh" >/dev/null)
assert_eq "$(<"$claude_repo/story.txt")" "changed by claude"

echo "== Codex fallback undo/redo =="
codex_repo="$WORK/codex"
init_repo "$codex_repo"
printf 'changed by codex\n' > "$codex_repo/story.txt"
(cd "$codex_repo" && jj status >/dev/null)
extract_command "$ROOT/plugins/codex-undo-redo/skills/undo/SKILL.md" "$WORK/codex-undo.sh"
extract_command "$ROOT/plugins/codex-undo-redo/skills/redo/SKILL.md" "$WORK/codex-redo.sh"
(cd "$codex_repo" && bash "$WORK/codex-undo.sh" >/dev/null)
assert_eq "$(<"$codex_repo/story.txt")" "original"
(cd "$codex_repo" && bash "$WORK/codex-redo.sh" >/dev/null)
assert_eq "$(<"$codex_repo/story.txt")" "changed by codex"

echo "integration tests passed"
