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

# The phase list of the open run, in order.
#
# A named flow resolves from the catalog every time rather than from the ledger, so a flow whose
# definition changed mid-run is caught rather than silently obeyed. A composed flow has no catalog
# row by definition, so it carries its phases in the ledger and they are read from there.
phase_array() {
    local file="${RUNS}/$(open_slug)/state.json"
    if [ -f "$file" ] && jq -e 'has("phases")' "$file" >/dev/null 2>&1; then
        jq -c '.phases' "$file"
    else
        jq -c --arg f "$1" '.[$f].phases // []' "$CATALOG"
    fi
}
phases_of() { phase_array "$1" | jq -r '.[].name'; }
phase_field() { phase_array "$1" | jq -r --arg p "$2" --arg k "$3" '.[] | select(.name==$p) | .[$k] // ""'; }

cmd_seed() {
    local flow="$1" slug="$2" composed=""
    if [ "$flow" = "--composed" ]; then
        # A composed flow has no catalog row, so its phases arrive on stdin. Validate them through
        # the same resolver the catalog goes through: a composer that names a target which is not
        # installed must fail here, before a run opens on a phase that can never run.
        composed="$(cat)"
        jq -e 'type=="array" and length>0' <<<"$composed" >/dev/null 2>&1 \
            || die "a composed flow needs a non-empty phase array on stdin"
        local probe; probe="$(mktemp)"
        jq -n --argjson p "$composed" '{composed:{phases:$p}}' > "$probe"
        local bad; bad="$(bash "${SCRIPT_DIR}/check-flows.sh" "$probe" 2>&1)" || {
            rm -f "$probe"; die "composed flow does not resolve: ${bad}"; }
        rm -f "$probe"
        flow="composed"
    else
        jq -e --arg f "$flow" 'has($f)' "$CATALOG" >/dev/null 2>&1 || die "no flow named '${flow}'"
        [ "$(jq -r --arg f "$flow" '.[$f].phases | length' "$CATALOG")" -gt 0 ] \
            || die "flow '${flow}' has no phases, so it is not a run"
    fi
    local existing; existing="$(open_slug)"
    [ -n "$existing" ] && die "run '${existing}' is already open; /polaris:pause clears it"
    case "$slug" in ""|.|..|*[!A-Za-z0-9._-]*) die "slug '${slug}' is not usable as a path" ;; esac
    mkdir -p "${RUNS}/${slug}" || die "cannot create ${RUNS}/${slug}"
    if [ -n "$composed" ]; then
        jq -n --arg s "$slug" --argjson p "$composed" \
            '{slug:$s,flow:"composed",current:($p[0].name),record:{},phases:$p}' > "${RUNS}/${slug}/state.json"
    else
        jq -n --arg s "$slug" --arg f "$flow" --arg c "$(jq -r --arg f "$flow" '.[$f].phases[0].name' "$CATALOG")" \
            '{slug:$s,flow:$f,current:$c,record:{}}' > "${RUNS}/${slug}/state.json"
    fi
    printf '%s' "$slug" > "$OPEN"
    echo "$slug"
}

cmd_get() { cat "$(ledger_path)"; }

# What the current phase runs. The hooks ask for this rather than reading the catalog themselves,
# because a composed flow keeps its phases in the ledger and a catalog lookup finds nothing for it.
# One resolver, so a gate cannot disagree with the run it is gating.
cmd_target() {
    local file; file="$(ledger_path)"
    local flow phase
    flow="$(jq -r .flow "$file")"; phase="${1:-$(jq -r .current "$file")}"
    [ -n "$phase" ] && [ "$phase" != "null" ] || return 0
    phase_field "$flow" "$phase" run
}

cmd_clear() {
    local slug; slug="$(open_slug)"
    [ -n "$slug" ] || die "no run is open"
    local file="${RUNS}/${slug}/state.json"
    # A composed shape that keeps coming back is a catalog row waiting to be written. Count the
    # shapes rather than the runs, and only ever suggest: a row is a human's edit.
    if [ -f "$file" ] && jq -e '.flow=="composed"' "$file" >/dev/null 2>&1; then
        local sig; sig="$(jq -r '[.phases[] | "\(.name):\(.run)"] | join(",")' "$file")"
        printf '%s\n' "$sig" >> "${RUNS}/.composed-log"
        local n; n="$(grep -cxF "$sig" "${RUNS}/.composed-log" 2>/dev/null || echo 0)"
        [ "$n" -ge 3 ] && echo "this shape has run ${n} times; consider adding it to rules/flows.json: ${sig}" >&2
    fi
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

# Re-hash an earlier phase's artifact after it was deliberately changed.
#
# The hash exists so an artifact cannot change without the phase that claimed it going invalid, and
# that invariant is worth keeping: it is what lets a later phase, or a cleared session, trust the
# file over the conversation. But a long run finds things, and a spec that cannot absorb what its own
# build discovered gets bypassed rather than amended. Without this the only ways out are re-seeding
# the run, which discards real approvals, or leaving shipped work unspecced.
#
# So an amendment is allowed and is never quiet. It refuses a phase that was never recorded, it
# demands evidence, it keeps the prior hash and the reason in an `amendments` list that nothing
# prunes, and it stamps `amendedAt`. An approval survives, because the human approved the artifact's
# purpose rather than its bytes, and the record now shows plainly that the bytes moved after they
# said yes.
cmd_amend() {
    local phase="$1" evidence="${2:-}"
    local file; file="$(ledger_path)"
    [ "$(jq -r --arg p "$phase" '.record[$p].status // ""' "$file")" = "done" ] \
        || die "phase '${phase}' is not recorded; there is nothing to amend"
    [ -n "$evidence" ] || die "an amendment needs evidence saying what changed and why"

    local artifact old
    artifact="$(jq -r --arg p "$phase" '.record[$p].artifact // ""' "$file")"
    old="$(jq -r --arg p "$phase" '.record[$p].sha256 // ""' "$file")"
    [ -n "$artifact" ] || die "phase '${phase}' recorded no artifact to re-hash"
    [ -f "$artifact" ] || die "phase '${phase}' recorded ${artifact}, which is gone"
    [ -n "$old" ] || die "phase '${phase}' was recorded without a hash; there is nothing to amend"

    local new; new="$(hash_of "$artifact")"
    [ "$new" != "$old" ] || die "${artifact} has not changed since phase '${phase}' recorded it"

    local tmp; tmp="$(mktemp)"
    jq --arg p "$phase" --arg s "$new" --arg o "$old" --arg e "$evidence" \
       --arg t "$(date -u +%FT%TZ)" \
       '.record[$p].sha256 = $s
        | .record[$p].amendedAt = $t
        | .record[$p].amendments = ((.record[$p].amendments // []) + [{at:$t,from:$o,to:$s,evidence:$e}])' \
       "$file" > "$tmp" && mv "$tmp" "$file"
    echo "amended ${phase}: ${artifact}"
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
        if [ -n "$artifact" ]; then
            [ -f "$artifact" ] || die "phase '${p}' recorded ${artifact}, which is gone"
        fi
        if [ -n "$sha" ]; then
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
    seed)    [ $# -eq 2 ] || die "usage: seed <flow>|--composed <slug>"; cmd_seed "$@" ;;
    get)     cmd_get ;;
    target)  cmd_target "${1:-}" ;;
    clear)   cmd_clear ;;
    record)  [ $# -ge 1 ] || die "usage: record <phase> [artifact] [evidence]"; cmd_record "$@" ;;
    approve) [ $# -eq 1 ] || die "usage: approve <phase>"; cmd_approve "$@" ;;
    amend)   [ $# -eq 2 ] || die "usage: amend <phase> <evidence>"; cmd_amend "$@" ;;
    assert)  [ $# -eq 1 ] || die "usage: assert <phase>"; cmd_assert "$@" ;;
    *)       die "usage: run-state.sh seed|get|target|record|approve|amend|assert|clear" ;;
esac
