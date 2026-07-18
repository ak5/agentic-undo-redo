---
name: redo
description: Redo changes undone by $undo (only valid before further edits).
---

Run this bash command and report only its stdout output (no narration):

```bash
UNDO=".jj/undo-stack-codex"
REDO=".jj/redo-stack-codex"

[[ -d .jj ]]    || { echo "no jj here — run: jj git init --colocate (one-time)"; exit 0; }
[[ -s "$REDO" ]] || { echo "nothing to redo"; exit 0; }

current=$(jj op log --limit 1 --no-graph -T 'self.id().short()')
target=$(tail -1 "$REDO")

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
