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
[[ -x "$fake_home/.claude/hooks/statusline.sh" ]] || fail "installer missed status-line helper"
HOME="$fake_home" CLAUDE_DIR="$fake_home/.claude" CODEX_DIR="$fake_home/.codex" \
  bash "$ROOT/uninstall.sh" --global >/dev/null
[[ ! -e "$fake_home/.codex/skills/undo" ]] || fail "uninstaller left Codex skill"

echo "== Codex skill collision safety =="
collision_home="$WORK/collision-home"
mkdir -p "$collision_home/.codex/skills/undo"
printf 'user-owned sentinel\n' > "$collision_home/.codex/skills/undo/SKILL.md"
if HOME="$collision_home" CLAUDE_DIR="$collision_home/.claude" CODEX_DIR="$collision_home/.codex" \
  bash "$ROOT/install.sh" --global >/dev/null 2>&1; then
  fail "installer overwrote an unrelated Codex skill"
fi
assert_eq "$(<"$collision_home/.codex/skills/undo/SKILL.md")" "user-owned sentinel"
[[ ! -e "$collision_home/.claude" ]] || fail "refused install left partial Claude files"
HOME="$collision_home" CLAUDE_DIR="$collision_home/.claude" CODEX_DIR="$collision_home/.codex" \
  bash "$ROOT/uninstall.sh" --global >/dev/null
assert_eq "$(<"$collision_home/.codex/skills/undo/SKILL.md")" "user-owned sentinel"

echo "== project install/idempotence/uninstall =="
project_repo="$WORK/project-install"
project_home="$WORK/project-home"
mkdir -p "$project_repo" "$project_home"
HOME="$project_home" bash "$ROOT/install.sh" --project "$project_repo" >/dev/null
[[ -d "$project_repo/.git" && -d "$project_repo/.jj" ]] || fail "project install did not initialize git and jj"
[[ -x "$project_repo/.claude/hooks/statusline.sh" ]] || fail "project install missed status-line helper"
HOME="$project_home" bash "$ROOT/install.sh" --project "$project_repo" >/dev/null
jq -e '[.hooks.UserPromptSubmit[] | .hooks[] | select(.command | endswith("jj-mark-turn.sh"))] | length == 1' \
  "$project_repo/.claude/settings.json" >/dev/null || fail "project install duplicated mark-turn hook"
jq -e '[.hooks.PostToolUse[] | .hooks[] | select(.command | endswith("jj-autosnapshot.sh"))] | length == 1' \
  "$project_repo/.claude/settings.json" >/dev/null || fail "project install duplicated autosnapshot hook"
HOME="$project_home" bash "$ROOT/uninstall.sh" --project "$project_repo" >/dev/null
[[ ! -e "$project_repo/.claude/hooks/statusline.sh" ]] || fail "project uninstall left status-line helper"

echo "== Claude turn undo/redo =="
claude_repo="$WORK/claude"
init_repo "$claude_repo"
mkdir -p "$claude_repo/packages/app"
(
  cd "$claude_repo/packages/app"
  CLAUDE_SESSION_ID=ci bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-mark-turn.sh"
  assert_eq "$(CLAUDE_PROJECT_DIR="$PWD" CLAUDE_SESSION_ID=ci bash "$ROOT/plugins/claude-code-undo-redo/statusline.sh")" "↩1"
  printf 'changed by claude\n' > ../../story.txt
  bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-autosnapshot.sh"
)
extract_command "$ROOT/plugins/claude-code-undo-redo/commands/undo.md" "$WORK/claude-undo.sh"
extract_command "$ROOT/plugins/claude-code-undo-redo/commands/redo.md" "$WORK/claude-redo.sh"
(cd "$claude_repo/packages/app" && CLAUDE_SESSION_ID=ci bash "$WORK/claude-undo.sh" >/dev/null)
assert_eq "$(<"$claude_repo/story.txt")" "original"
(cd "$claude_repo/packages/app" && CLAUDE_SESSION_ID=ci bash "$WORK/claude-redo.sh" >/dev/null)
assert_eq "$(<"$claude_repo/story.txt")" "changed by claude"

echo "== Claude multi-turn stack =="
multi_repo="$WORK/claude-multi"
init_repo "$multi_repo"
(
  cd "$multi_repo"
  CLAUDE_SESSION_ID=multi bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-mark-turn.sh"
  printf 'first turn\n' > story.txt
  bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-autosnapshot.sh"
  CLAUDE_SESSION_ID=multi bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-mark-turn.sh"
  printf 'second turn\n' > story.txt
  bash "$ROOT/plugins/claude-code-undo-redo/hooks/jj-autosnapshot.sh"
)
assert_eq "$(wc -l < "$multi_repo/.jj/undo-stack-multi" | tr -d ' ')" "2"
(cd "$multi_repo" && CLAUDE_SESSION_ID=multi bash "$WORK/claude-undo.sh" >/dev/null)
assert_eq "$(<"$multi_repo/story.txt")" "first turn"
(cd "$multi_repo" && CLAUDE_SESSION_ID=multi bash "$WORK/claude-undo.sh" >/dev/null)
assert_eq "$(<"$multi_repo/story.txt")" "original"
(cd "$multi_repo" && CLAUDE_SESSION_ID=multi bash "$WORK/claude-redo.sh" >/dev/null)
assert_eq "$(<"$multi_repo/story.txt")" "first turn"
(cd "$multi_repo" && CLAUDE_SESSION_ID=multi bash "$WORK/claude-redo.sh" >/dev/null)
assert_eq "$(<"$multi_repo/story.txt")" "second turn"

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

echo "== Codex marked-turn undo/redo =="
codex_hook_repo="$WORK/codex-hook"
init_repo "$codex_hook_repo"
mkdir -p "$codex_hook_repo/packages/app"
(
  cd "$codex_hook_repo/packages/app"
  bash "$ROOT/plugins/codex-undo-redo/hooks/jj-mark-turn.sh"
  printf 'changed in one codex turn\n' > ../../story.txt
  bash "$ROOT/plugins/codex-undo-redo/hooks/jj-autosnapshot.sh"
  bash "$WORK/codex-undo.sh" >/dev/null
)
assert_eq "$(<"$codex_hook_repo/story.txt")" "original"
(cd "$codex_hook_repo/packages/app" && bash "$WORK/codex-redo.sh" >/dev/null)
assert_eq "$(<"$codex_hook_repo/story.txt")" "changed in one codex turn"

echo "integration tests passed"
