---
description: Clear the undo/redo stacks (use after manual jj op restore)
---

Run this bash command and report only its stdout output (no narration):

```bash
SID="${CLAUDE_SESSION_ID:-default}"
ROOT="$(jj --ignore-working-copy root 2>/dev/null)" || { echo "no jj here"; exit 0; }
UNDO="$ROOT/.jj/undo-stack-${SID}"
REDO="$ROOT/.jj/redo-stack-${SID}"

und_count=0
red_count=0
[[ -s "$UNDO" ]] && und_count=$(wc -l <"$UNDO" | tr -d ' ')
[[ -s "$REDO" ]] && red_count=$(wc -l <"$REDO" | tr -d ' ')

: > "$UNDO"
: > "$REDO"

echo "🧹 stacks cleared (was undo: $und_count, redo: $red_count)"
echo "   /undo will start fresh from your next prompt"
```
