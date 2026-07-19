#!/usr/bin/env bash
set -e

command -v jj >/dev/null 2>&1 || exit 0
jj --ignore-working-copy root >/dev/null 2>&1 || exit 0

jj st >/dev/null 2>&1 || true
