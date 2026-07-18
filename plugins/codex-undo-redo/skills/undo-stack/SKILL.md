---
name: undo-stack
description: Show the $undo/$redo stacks (read-only inspection).
---

Run this bash command and report only its stdout output (no narration):

```bash
UNDO=".jj/undo-stack-codex"
REDO=".jj/redo-stack-codex"

[[ -d .jj ]] || { echo "no jj here"; exit 0; }

echo "═══ \$undo/\$redo stacks ═══"
echo ""
if [[ -s "$UNDO" ]]; then
  echo "undo stack ($(wc -l <"$UNDO" | tr -d ' ') entries; top first) --"
  tac "$UNDO" 2>/dev/null || tail -r "$UNDO"
else
  echo "undo stack -- (empty)"
fi
echo ""
if [[ -s "$REDO" ]]; then
  echo "redo stack ($(wc -l <"$REDO" | tr -d ' ') entries; top first) --"
  tac "$REDO" 2>/dev/null || tail -r "$REDO"
else
  echo "redo stack -- (empty)"
fi
echo ""
echo "current op -- $(jj op log --ignore-working-copy --limit 1 --no-graph -T 'self.id().short()')"
```
