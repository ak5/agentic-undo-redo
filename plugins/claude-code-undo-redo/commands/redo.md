---
description: Redo a turn that was undone (only valid before submitting a new prompt)
---

Run this bash command and report only its stdout output (no narration):

```bash
SID="${CLAUDE_SESSION_ID:-default}"
UNDO=".claude/.jj-undo-stack-${SID}"
REDO=".claude/.jj-redo-stack-${SID}"

[[ -d .jj ]]    || { echo "no jj here — type /agentic-undo-redo-init to set this repo up"; exit 0; }
[[ -s "$REDO" ]] || { echo "nothing to redo (a new prompt clears the redo stack)"; exit 0; }

current=$(jj op log --limit 1 --no-graph -T 'self.id().short()')
target=$(tail -1 "$REDO")

# Pop redo, push undo
sed -i '' '$d' "$REDO" 2>/dev/null || sed -i '$d' "$REDO"
echo "$current" >> "$UNDO"

preview=$(jj diff --from "$current" --to "$target" --stat 2>/dev/null | tail -8)
jj op restore "$target" >/dev/null 2>&1

echo "↪  redone — restored to op $target"
[[ -n "$preview" ]] && echo "" && echo "$preview"

und=$(wc -l <"$UNDO" | tr -d ' ')
red=$(wc -l <"$REDO" | tr -d ' ')
echo ""
echo "(undo: $und available; redo: $red remaining)"
```
