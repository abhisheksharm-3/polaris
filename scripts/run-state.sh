#!/usr/bin/env bash
# The run ledger: which flow is open, which phase it is on, and what each finished phase produced.
# Every gate reads this. It is the difference between routing that suggests and routing that binds,
# so the one thing it must never do is let a phase claim done without evidence that it is.
#
# Two invariants, both of which the gates depend on:
# 1. A phase is done only with its artifact on disk and its hash matching. An artifact edited after
#    the fact invalidates the phase that claimed it, because a stale claim is worse than no claim.
# 2. One open run per project. Two ledgers means two answers to "what phase is this", and the
#    PreToolUse gate would then allow whatever the more permissive one says.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
RUNS="${PROJECT_DIR}/.polaris/runs"
OPEN="${RUNS}/.open"
CATALOG="${ROOT}/rules/flows.json"

die() { echo "run-state: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq is required"

hash_of() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else die "no sha256 tool"; fi
}

open_slug() { [ -f "$OPEN" ] && tr -d '\n' < "$OPEN" || true; }

ledger_path() {
    local slug; slug="$(open_slug)"
    [ -n "$slug" ] || die "no run is open"
    echo "${RUNS}/${slug}/state.json"
}

# The phase list of the open run, in order. Every subcommand resolves it from the catalog rather
# than from the ledger, so a flow whose definition changed is caught rather than silently obeyed.
phases_of() { jq -r --arg f "$1" '.[$f].phases[]?.name' "$CATALOG"; }
phase_field() { jq -r --arg f "$1" --arg p "$2" --arg k "$3" '.[$f].phases[] | select(.name==$p) | .[$k] // ""' "$CATALOG"; }

cmd_seed() {
    local flow="$1" slug="$2"
    jq -e --arg f "$flow" 'has($f)' "$CATALOG" >/dev/null 2>&1 || die "no flow named '${flow}'"
    [ "$(phases_of "$flow" | wc -l)" -gt 0 ] || die "flow '${flow}' has no phases, so it is not a run"
    local existing; existing="$(open_slug)"
    [ -n "$existing" ] && die "run '${existing}' is already open; /polaris:pause clears it"
    case "$slug" in ""|.|..|*[!A-Za-z0-9._-]*) die "slug '${slug}' is not usable as a path" ;; esac
    mkdir -p "${RUNS}/${slug}" || die "cannot create ${RUNS}/${slug}"
    jq -n --arg s "$slug" --arg f "$flow" --arg c "$(phases_of "$flow" | head -1)" \
        '{slug:$s,flow:$f,current:$c,record:{}}' > "${RUNS}/${slug}/state.json"
    printf '%s' "$slug" > "$OPEN"
    echo "$slug"
}

cmd_get() { cat "$(ledger_path)"; }

cmd_clear() {
    local slug; slug="$(open_slug)"
    [ -n "$slug" ] || die "no run is open"
    rm -rf "${RUNS:?}/${slug}" "$OPEN"
    echo "$slug"
}

cmd_record() {
    local phase="$1" artifact="${2:-}" evidence="${3:-}"
    local file; file="$(ledger_path)"
    local flow current
    flow="$(jq -r .flow "$file")"; current="$(jq -r .current "$file")"
    [ "$phase" = "$current" ] || die "phase '${phase}' is not current; the run is on '${current}'"

    local wants; wants="$(phase_field "$flow" "$phase" evidence)"
    local sha=""
    if [ -n "$wants" ]; then
        [ -n "$artifact" ] && [ -f "$artifact" ] || die "phase '${phase}' needs an artifact holding ${wants}"
        [ -n "$evidence" ] || die "phase '${phase}' needs evidence: ${wants}"
        sha="$(hash_of "$artifact")"
    fi

    local tmp; tmp="$(mktemp)"
    jq --arg p "$phase" --arg a "$artifact" --arg s "$sha" --arg e "$evidence" \
       --arg t "$(date -u +%FT%TZ)" \
       '.record[$p] = {status:"done",artifact:$a,sha256:$s,evidence:$e,at:$t}' "$file" > "$tmp" && mv "$tmp" "$file"

    # A phase that needs a human holds the run where it is. The Stop hook reads current to decide
    # between asking for an approval and asking for the next phase, so advancing here would skip it.
    [ -n "$(phase_field "$flow" "$phase" approve)" ] && return 0
    advance_past "$phase"
}

cmd_approve() {
    local phase="$1"
    local file; file="$(ledger_path)"
    local flow; flow="$(jq -r .flow "$file")"
    [ -n "$(phase_field "$flow" "$phase" approve)" ] || die "phase '${phase}' does not take an approval"
    [ "$(jq -r --arg p "$phase" '.record[$p].status // ""' "$file")" = "done" ] \
        || die "phase '${phase}' is not done yet"
    local tmp; tmp="$(mktemp)"
    jq --arg p "$phase" --arg t "$(date -u +%FT%TZ)" '.record[$p].approvedAt = $t' "$file" > "$tmp" && mv "$tmp" "$file"
    advance_past "$phase"
}

advance_past() {
    local file; file="$(ledger_path)"
    local flow; flow="$(jq -r .flow "$file")"
    local next="" seen=0
    while read -r p; do
        [ "$seen" = 1 ] && { next="$p"; break; }
        [ "$p" = "$1" ] && seen=1
    done < <(phases_of "$flow")
    local tmp; tmp="$(mktemp)"
    jq --arg c "$next" '.current = $c' "$file" > "$tmp" && mv "$tmp" "$file"
}

# The gate. Walks every phase before the named one and fails on the first that has not been earned,
# naming it, because a refusal that does not say what is owed just reads as a broken tool.
cmd_assert() {
    local target="$1"
    local file; file="$(ledger_path)"
    local flow; flow="$(jq -r .flow "$file")"
    phases_of "$flow" | grep -qx "$target" || die "phase '${target}' is not in flow '${flow}'"

    while read -r p; do
        [ "$p" = "$target" ] && { echo "ok"; return 0; }
        local status artifact sha
        status="$(jq -r --arg p "$p" '.record[$p].status // ""' "$file")"
        [ "$status" = "done" ] || die "phase '${p}' is not done; '${target}' cannot start"
        artifact="$(jq -r --arg p "$p" '.record[$p].artifact // ""' "$file")"
        sha="$(jq -r --arg p "$p" '.record[$p].sha256 // ""' "$file")"
        if [ -n "$sha" ]; then
            [ -f "$artifact" ] || die "phase '${p}' recorded ${artifact}, which is gone"
            [ "$(hash_of "$artifact")" = "$sha" ] || die "phase '${p}' recorded ${artifact}, which has changed since"
        fi
        if [ -n "$(phase_field "$flow" "$p" approve)" ]; then
            [ "$(jq -r --arg p "$p" '.record[$p].approvedAt // ""' "$file")" != "" ] \
                || die "phase '${p}' is done but not approved; present it and ask"
        fi
    done < <(phases_of "$flow")
    echo "ok"
}

sub="${1:-}"; shift || true
case "$sub" in
    seed)    [ $# -eq 2 ] || die "usage: seed <flow> <slug>"; cmd_seed "$@" ;;
    get)     cmd_get ;;
    clear)   cmd_clear ;;
    record)  [ $# -ge 1 ] || die "usage: record <phase> [artifact] [evidence]"; cmd_record "$@" ;;
    approve) [ $# -eq 1 ] || die "usage: approve <phase>"; cmd_approve "$@" ;;
    assert)  [ $# -eq 1 ] || die "usage: assert <phase>"; cmd_assert "$@" ;;
    *)       die "usage: run-state.sh seed|get|record|approve|assert|clear" ;;
esac
