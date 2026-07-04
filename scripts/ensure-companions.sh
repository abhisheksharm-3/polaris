#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
DEST="${HOME}/.claude/skills"
MARKER="${DEST}/.polaris-mindrally-synced"

[ -f "$MARKER" ] && exit 0
command -v git >/dev/null 2>&1 || { echo "ensure-companions: git required to sync skill bulk" >&2; exit 0; }

mkdir -p "$DEST"
TMP="$(mktemp -d)"
if git clone --depth 1 https://github.com/Mindrally/skills "$TMP" 2>/dev/null; then
  for d in "$TMP"/*/; do
    name="$(basename "$d")"
    [ -e "${DEST}/${name}" ] || cp -R "$d" "${DEST}/${name}"
  done
  touch "$MARKER"
  echo "ensure-companions: synced Mindrally skill bulk"
fi
rm -rf "$TMP"
exit 0
