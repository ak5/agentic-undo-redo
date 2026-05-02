---
description: Enable /undo /redo in this repo (one-time — auto-runs git init if needed, then jj git init --colocate)
---

Run this bash command and report only its stdout output (no narration):

```bash
# Already enabled?
if [[ -d .jj ]]; then
  echo "✅ jj already initialized in $(pwd) — /undo and /redo are ready."
  exit 0
fi

# Hard dependency: jj
if ! command -v jj >/dev/null 2>&1; then
  echo "❌ jj not installed — install with: brew install jj"
  exit 1
fi

# Hard dependency: git
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git not installed — install with: brew install git"
  exit 1
fi

# Refuse inside a git worktree (jj forbids colocation here)
if [[ -f .git ]]; then
  echo "❌ this is a git worktree, not the main repo."
  echo "   run /agentic-undo-redo-init in the main worktree (where .git/ is a directory)"
  exit 1
fi

# If we're about to AUTO git-init, sweep for existing nested git repos one level deep.
# A directory of project clones (e.g. ~/Projects) shouldn't accidentally get a
# wrapper repo — the user probably meant to init inside one of the children.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  nested=()
  for d in */ ; do
    [[ -d "${d}.git" ]] && nested+=("${d%/}")
  done
  if (( ${#nested[@]} > 0 )); then
    echo "❌ this dir is not a git repo, but contains ${#nested[@]} nested git repo(s):"
    printf '   • %s\n' "${nested[@]}"
    echo ""
    echo "   I won't auto-init a wrapper around them. cd into one of those repos"
    echo "   and run /agentic-undo-redo-init there instead."
    exit 1
  fi
  git init -q
  echo "🌱 git init ran (this dir wasn't a git repo — created a fresh one)"
fi

jj git init --colocate
echo "🪄 jj colocated in $(pwd)"
echo ""
echo "✅ /undo and /redo are armed for this repo."
echo "   Submit your next prompt; tool calls will start being checkpointed."
echo "   First /undo works after one prompt has been processed."
```
