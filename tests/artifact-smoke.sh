#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

package_name="$(cd "$ROOT" && npm pack --silent --cache "$WORK/npm-cache" --pack-destination "$WORK")"
package_path="$WORK/$package_name"
mkdir -p "$WORK/unpacked"
tar -xzf "$package_path" -C "$WORK/unpacked"

cli="$WORK/unpacked/package/bin/cli.js"
[[ -x "$cli" ]]
[[ "$($cli --version)" == "0.2.0-rc.1" ]]

mkdir -p "$WORK/project" "$WORK/home"
HOME="$WORK/home" "$cli" install --project "$WORK/project" >/dev/null
[[ -d "$WORK/project/.git" && -d "$WORK/project/.jj" ]]
[[ -f "$WORK/project/.claude/commands/undo.md" ]]
HOME="$WORK/home" "$cli" uninstall --project "$WORK/project" >/dev/null
[[ ! -e "$WORK/project/.claude/commands/undo.md" ]]

echo "packed artifact smoke test passed"
