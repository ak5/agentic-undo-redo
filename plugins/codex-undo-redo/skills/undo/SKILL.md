---
name: undo
description: >-
  Undo the agent's recent file changes via the jj op log. Pops a marked turn
  from the undo stack when one exists; otherwise falls back to the previous
  op (one level — codex has no prompt hooks to mark turn boundaries).
  Pair with $redo.
---

Run this bash command and report only its stdout output (no narration):

```bash
UNDO=".jj/undo-stack-codex"
REDO=".jj/redo-stack-codex"

[[ -d .jj ]] || { echo "no jj here — run: jj git init --colocate (one-time)"; exit 0; }
jj st >/dev/null 2>&1 || true

current=$(jj op log --limit 1 --no-graph -T 'self.id().short()')
if [[ -s "$UNDO" ]]; then
  target=$(tail -1 "$UNDO")
  sed -i '' '$d' "$UNDO" 2>/dev/null || sed -i '$d' "$UNDO"
else
  # no marked turns — fall back to the previous op: undoes the most recent
  # change batch; deeper walking needs marked turns
  target=$(jj op log --limit 2 --no-graph -T 'self.id().short()++"\n"' | tail -1)
fi
[[ -n "$target" && "$target" != "$current" ]] || { echo "nothing to undo"; exit 0; }

echo "$current" >> "$REDO"
preview=$(jj diff --from "$target" --to "$current" --stat 2>/dev/null | tail -8)
jj op restore "$target" >/dev/null 2>&1

echo "↩  undone — restored to op $target"
[[ -n "$preview" ]] && echo "" && echo "$preview"

und=0; [[ -s "$UNDO" ]] && und=$(wc -l <"$UNDO" | tr -d ' ')
red=$(wc -l <"$REDO" | tr -d ' ')
echo ""
echo "(undo: $und remaining; redo: $red available — \$redo to come back)"
```
