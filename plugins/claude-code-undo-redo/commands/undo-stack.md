---
description: Show the undo/redo stacks (read-only inspection)
---

Run this bash command and report only its stdout output (no narration):

```bash
SID="${CLAUDE_SESSION_ID:-default}"
UNDO=".claude/.jj-undo-stack-${SID}"
REDO=".claude/.jj-redo-stack-${SID}"

[[ -d .jj ]] || { echo "no jj here"; exit 0; }

echo "═══ undo/redo stacks for session ${SID} ═══"
echo ""

if [[ -s "$UNDO" ]]; then
  echo "undo stack ($(wc -l <"$UNDO" | tr -d ' ') turns; top first) --"
  tac "$UNDO" 2>/dev/null || tail -r "$UNDO"
  echo ""
else
  echo "undo stack -- (empty)"
  echo ""
fi

if [[ -s "$REDO" ]]; then
  echo "redo stack ($(wc -l <"$REDO" | tr -d ' ') turns; top first) --"
  tac "$REDO" 2>/dev/null || tail -r "$REDO"
  echo ""
else
  echo "redo stack -- (empty)"
  echo ""
fi

current=$(jj op log --limit 1 --no-graph -T 'self.id().short()')
echo "current op -- $current"
```
