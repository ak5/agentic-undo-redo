---
name: undo-reset
description: Clear the $undo/$redo stacks (use after manual jj op restore).
---

Run this bash command and report only its stdout output (no narration):

```bash
ROOT="$(jj --ignore-working-copy root 2>/dev/null)" || { echo "no jj here"; exit 0; }
UNDO="$ROOT/.jj/undo-stack-codex"
REDO="$ROOT/.jj/redo-stack-codex"

und=0; red=0
[[ -s "$UNDO" ]] && und=$(wc -l <"$UNDO" | tr -d ' ')
[[ -s "$REDO" ]] && red=$(wc -l <"$REDO" | tr -d ' ')
: > "$UNDO"
: > "$REDO"
echo "🧹 stacks cleared (was undo: $und, redo: $red)"
```
