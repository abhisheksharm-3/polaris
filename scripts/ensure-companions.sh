#!/usr/bin/env bash
# Install Polaris companions from companions.json: marketplace plugins, the stack skill bulk.
# Idempotent and non-fatal: it never blocks a session. Registries are used at run time, not here.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
MANIFEST="${ROOT}/companions.json"
DEST="${HOME}/.claude/skills"
MARKER="${DEST}/.polaris-mindrally-synced"

# Manual re-sync: `ensure-companions.sh --force` clears the run-once markers so both the
# marketplace plugins and the skill bulk re-install on this invocation. Use it when the
# first sync was skipped (no git/CLI/network) or to pull companions.json edits.
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "--reset" ]; then
  rm -f "${DEST}/.polaris-companions-installed" "${MARKER}"
fi

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1

# --- Marketplace plugins (best-effort via the claude CLI, once) ---
# Native plugin.json dependencies already pull superpowers + frontend-design. This adds the
# cross-marketplace companions (karpathy, daymade skills) when the CLI is available.
# Marker-guarded: each `claude plugin install` spawns the CLI, and re-running the whole set on
# every session start added tens of seconds to startup. Run it once. To re-sync after editing
# companions.json, delete the marker.
PLUGIN_MARKER="${DEST}/.polaris-companions-installed"
if [ ! -f "$PLUGIN_MARKER" ] && [ "$have_jq" = 1 ] && command -v claude >/dev/null 2>&1 && [ -f "$MANIFEST" ]; then
  mkdir -p "$DEST"
  jq -r '.marketplaces[]? | (.source // .name)' "$MANIFEST" | while read -r mkt; do
    [ -n "$mkt" ] && claude plugin marketplace add "$mkt" >/dev/null 2>&1 || true
  done
  jq -r '.plugins[]? | "\(.name)@\(.marketplace)"' "$MANIFEST" | while read -r plugin; do
    [ -n "$plugin" ] && claude plugin install "$plugin" >/dev/null 2>&1 || true
  done
  touch "$PLUGIN_MARKER"
fi

# --- Stack skill bulk (sync once, only the skills something actually names) ---
#
# This copied every directory in the upstream repo into ~/.claude/skills/, which is user-global
# rather than plugin-scoped. On 2026-09-07 that was 270 skill directories against the 43 that
# companions.json names, so installing Polaris put ~227 skills the plugin never references into
# every session of every project on the machine, Polaris or not. A skill's description loads
# whether it is used or not, so that is a cost the user did not ask for and cannot see.
#
# Now it copies the named set. `--all` restores the old behaviour for anyone who wants the library.
if [ ! -f "$MARKER" ] && command -v git >/dev/null 2>&1; then
  src="https://github.com/Mindrally/skills"
  [ "$have_jq" = 1 ] && [ -f "$MANIFEST" ] && src="$(jq -r '.skillBulk.source // "https://github.com/Mindrally/skills"' "$MANIFEST")"
  # The wanted set is the union of three sources, and all three matter. companions.json names what
  # the agents preload; namedSkills names the ui and research picks; and rules/stack-map.json names
  # what the stack-resolution protocol loads per detected stack. Leaving stack-map out of the union
  # would have excluded the skills the protocol exists to reach, which is the one set that must be
  # there: 7 of its 8 entries are not in companionSkills.
  wanted=""
  if [ "${1:-}" != "--all" ] && [ "$have_jq" = 1 ] && [ -f "$MANIFEST" ]; then
    wanted="$(jq -r '[.companionSkills.skills[]?, (.namedSkills | del(.note) | .[][]?)] | unique | .[]' "$MANIFEST" 2>/dev/null)"
    if [ -f "${ROOT}/rules/stack-map.json" ]; then
      wanted="${wanted}
$(jq -r '[.[].skills[]?] | unique | .[]' "${ROOT}/rules/stack-map.json" 2>/dev/null)"
    fi
    wanted="$(printf '%s\n' "$wanted" | awk 'NF' | sort -u)"
  fi
  mkdir -p "$DEST"
  TMP="$(mktemp -d)"
  if git clone --depth 1 "$src" "$TMP" >/dev/null 2>&1; then
    copied=0; skipped=0
    for d in "$TMP"/*/; do
      name="$(basename "$d")"
      case "$name" in .*) continue;; esac
      if [ -n "$wanted" ] && ! printf '%s\n' "$wanted" | grep -qx "$name"; then
        skipped=$((skipped + 1)); continue
      fi
      [ -e "${DEST}/${name}" ] || { cp -R "$d" "${DEST}/${name}"; copied=$((copied + 1)); }
    done
    touch "$MARKER"
    if [ "$skipped" -gt 0 ]; then
      echo "ensure-companions: installed ${copied} named skills, left ${skipped} unnamed ones out (--all takes the whole library)"
    else
      echo "ensure-companions: synced ${copied} skills"
    fi
  fi
  rm -rf "$TMP"
fi

exit 0
