---
description: Undo Claude's most recent turn (multi-undo OK; pair with /redo)
---

Run this bash command and report only its stdout output (no narration):

```bash
SID="${CLAUDE_SESSION_ID:-default}"
UNDO=".jj/undo-stack-${SID}"
REDO=".jj/redo-stack-${SID}"

[[ -d .jj ]]    || { echo "no jj here — type /agentic-enable to set this repo up (one-time)"; exit 0; }
[[ -s "$UNDO" ]] || { echo "nothing to undo"; exit 0; }

current=$(jj op log --limit 1 --no-graph -T 'self.id().short()')
target=$(tail -1 "$UNDO")

# Pop undo, push redo
sed -i '' '$d' "$UNDO" 2>/dev/null || sed -i '$d' "$UNDO"
echo "$current" >> "$REDO"

preview=$(jj diff --from "$target" --to "$current" --stat 2>/dev/null | tail -8)
jj op restore "$target" >/dev/null 2>&1

echo "↩  undone — restored to op $target"
[[ -n "$preview" ]] && echo "" && echo "$preview"

und=$(wc -l <"$UNDO" | tr -d ' ')
red=$(wc -l <"$REDO" | tr -d ' ')
echo ""
echo "(undo: $und remaining; redo: $red available — type /redo to come back)"
```
