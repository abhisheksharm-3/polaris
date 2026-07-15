#!/usr/bin/env bash
# Install Polaris companions from companions.json: marketplace plugins, the stack skill bulk.
# Idempotent and non-fatal: it never blocks a session. Registries are used at run time, not here.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
MANIFEST="${ROOT}/companions.json"
DEST="${HOME}/.claude/skills"
MARKER="${DEST}/.polaris-mindrally-synced"

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1

# --- Marketplace plugins (best-effort via the claude CLI) ---
# Native plugin.json dependencies already pull superpowers + frontend-design. This adds the
# cross-marketplace companions (karpathy, daymade skills) when the CLI is available.
if [ "$have_jq" = 1 ] && command -v claude >/dev/null 2>&1 && [ -f "$MANIFEST" ]; then
  jq -r '.marketplaces[]? | (.source // .name)' "$MANIFEST" | while read -r mkt; do
    [ -n "$mkt" ] && claude plugin marketplace add "$mkt" >/dev/null 2>&1 || true
  done
  jq -r '.plugins[]? | "\(.name)@\(.marketplace)"' "$MANIFEST" | while read -r plugin; do
    [ -n "$plugin" ] && claude plugin install "$plugin" >/dev/null 2>&1 || true
  done
fi

# --- Stack skill bulk (sync once) ---
if [ ! -f "$MARKER" ] && command -v git >/dev/null 2>&1; then
  src="https://github.com/Mindrally/skills"
  [ "$have_jq" = 1 ] && [ -f "$MANIFEST" ] && src="$(jq -r '.skillBulk.source // "https://github.com/Mindrally/skills"' "$MANIFEST")"
  mkdir -p "$DEST"
  TMP="$(mktemp -d)"
  if git clone --depth 1 "$src" "$TMP" >/dev/null 2>&1; then
    for d in "$TMP"/*/; do
      name="$(basename "$d")"
      case "$name" in .*) continue;; esac
      [ -e "${DEST}/${name}" ] || cp -R "$d" "${DEST}/${name}"
    done
    touch "$MARKER"
    echo "ensure-companions: synced the stack skill bulk"
  fi
  rm -rf "$TMP"
fi

exit 0
