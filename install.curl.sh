#!/usr/bin/env bash
# install.curl.sh — bootstrap installer for the curl-pipe-bash crowd.
#
# Not the documented happy path (use `/plugin install` from CC, or `npx
# agentic-undo-redo`), but supported for users without Node and without
# Claude Code's plugin system. Downloads the chosen tag/branch tarball
# and runs install.sh.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/main/install.curl.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/v0.1.0/install.curl.sh | bash -s -- --version v0.1.0
#   curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/main/install.curl.sh | bash -s -- --project
#
# Don't blindly trust ANY curl-pipe-bash. Read the script first:
#   curl -fsSL https://raw.githubusercontent.com/ak5/agentic-undo-redo/main/install.curl.sh | less

set -e

REPO="ak5/agentic-undo-redo"
VERSION="main"
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --version=*) VERSION="${1#--version=}"; shift ;;
    *) PASSTHROUGH+=("$1"); shift ;;
  esac
done

CACHE_BASE="${HOME}/.cache/agentic-undo-redo"
mkdir -p "$CACHE_BASE"

URL="https://github.com/$REPO/archive/$VERSION.tar.gz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

printf '\e[1m→ downloading %s\e[0m\n' "$URL"
curl -fsSL -o "$WORK/src.tar.gz" "$URL" || {
  printf '\e[31m✗ download failed — check that %s is a valid branch or tag\e[0m\n' "$VERSION" >&2
  exit 1
}

printf '\e[1m→ extracting\e[0m\n'
tar -xzf "$WORK/src.tar.gz" -C "$WORK"
SRC_DIR="$(find "$WORK" -maxdepth 1 -type d -name 'agentic-undo-redo-*' | head -1)"
[[ -d "$SRC_DIR" ]] || { echo "✗ extraction layout unexpected" >&2; exit 1; }

DEST="$CACHE_BASE/$VERSION"
rm -rf "$DEST"
cp -R "$SRC_DIR" "$DEST"
printf '\e[32m✓ cached at %s\e[0m\n' "$DEST"

printf '\e[1m→ running install.sh %s\e[0m\n' "${PASSTHROUGH[*]:-}"
exec bash "$DEST/install.sh" "${PASSTHROUGH[@]}"
