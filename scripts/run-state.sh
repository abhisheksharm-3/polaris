#!/usr/bin/env bash
# The run ledger: which flow is open, which phase it is on, and what each finished phase produced.
# Every gate reads this. It is the difference between routing that suggests and routing that binds,
# so the one thing it must never do is let a phase claim done without evidence that it is.
#
# Two invariants, both of which the gates depend on:
# 1. A phase is done only with its artifact on disk and its hash matching. An artifact edited after
#    the fact invalidates the phase that claimed it, because a stale claim is worse than no claim.
# 2. One open run per session. Two ledgers in one session means two answers to "what phase is
#    this", and the PreToolUse gate would then allow whatever the more permissive one says. Two
#    sessions are two conversations, each with its own answer, so they run in parallel: the pointer
#    is keyed by CLAUDE_CODE_SESSION_ID, which subagents inherit unchanged from the session that
#    dispatched them, so a gate and the agent it gates always read the same run.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
RUNS="${PROJECT_DIR}/.polaris/runs"
SESSION="${POLARIS_SESSION:-${CLAUDE_CODE_SESSION_ID:-shared}}"
OPEN="${RUNS}/.open-${SESSION//[^A-Za-z0-9._-]/_}"
CATALOG="${ROOT}/rules/flows.json"

# A run opened before the pointer was per-session sits at the old shared path. Adopt it into the
# first session that asks, so an in-flight run survives the upgrade instead of going invisible.
[ -e "$OPEN" ] || [ ! -f "${RUNS}/.open" ] || mv "${RUNS}/.open" "$OPEN"

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
    [ -n "$existing" ] && die "run '${existing}' is already open in this session; /polaris:pause clears it"
    case "$slug" in ""|.|..|*[!A-Za-z0-9._-]*) die "slug '${slug}' is not usable as a path" ;; esac
    # Sessions run in parallel but they do not share a run. A slug whose directory is already there
    # belongs to another session, and two conversations writing one state.json is the one race the
    # ledger cannot survive, so the second caller picks a different slug.
    [ -d "${RUNS}/${slug}" ] && die "run '${slug}' already exists; another session owns it, so pick another slug"
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
    # Archive rather than delete. `rm -rf` here destroyed every phase record, artifact hash,
    # approval timestamp and amendment at the exact moment the run became a complete history of
    # itself, which is the one dataset Polaris generates about its own operation. Keeping it is what
    # lets a later pass answer which flows finish, which stall, and where approvals actually sit.
    mkdir -p "${RUNS}/.done" 2>/dev/null
    if [ -d "${RUNS}/${slug}" ]; then
        dest="${RUNS}/.done/${slug}"
        # A slug can be reused across runs, so an existing archive entry is suffixed rather than
        # overwritten. Counting up beats a timestamp: run-state.sh has no clock it can trust in a
        # test, and the order only has to be stable.
        if [ -e "$dest" ]; then
            n=2
            while [ -e "${dest}-${n}" ]; do n=$((n + 1)); done
            dest="${dest}-${n}"
        fi
        mv "${RUNS}/${slug}" "$dest" 2>/dev/null || rm -rf "${RUNS:?}/${slug}"
    fi
    rm -f "$OPEN"
    echo "$slug"
}

cmd_record() {
    local phase="$1" artifact="${2:-}" evidence="${3:-}"
    local file; file="$(ledger_path)"
    local flow current
    flow="$(jq -r .flow "$file")"; current="$(jq -r .current "$file")"
    [ "$phase" = "$current" ] || die "phase '${phase}' is not current; the run is on '${current}'"

    local declared=""
    [ "$phase" = "spec" ] && { declared="$(surfaces_of "$artifact")" || exit 1; }
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
    [ "$phase" = "spec" ] && set_surfaces "$declared"

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
    local declared=""
    [ "$phase" = "spec" ] && { declared="$(surfaces_of "$artifact")" || exit 1; }

    local tmp; tmp="$(mktemp)"
    jq --arg p "$phase" --arg s "$new" --arg o "$old" --arg e "$evidence" \
       --arg t "$(date -u +%FT%TZ)" \
       '.record[$p].sha256 = $s
        | .record[$p].amendedAt = $t
        | .record[$p].amendments = ((.record[$p].amendments // []) + [{at:$t,from:$o,to:$s,evidence:$e}])' \
       "$file" > "$tmp" && mv "$tmp" "$file"
    [ "$phase" = "spec" ] && set_surfaces "$declared"
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

# The surfaces a change touches, read from the spec's `Surfaces:` line. The product agent writes it
# as a classification; everything after is code. Only the spec sets it, and recording or amending
# the spec sets it again, so a spec corrected during approval to add `auth` gets its threat model.
SURFACES="ui api data auth integration mobile none"

# The declared surfaces of an artifact as JSON, or nothing when it declares none. An unknown token is
# refused, because the failure it causes is silent: a typo matches no phase's `when`, and every
# conditional phase, the threat model included, would be skipped.
surfaces_of() {
    local artifact="$1" line tokens bad
    [ -n "$artifact" ] && [ -f "$artifact" ] || return 0
    line="$(grep -m1 -iE '^[*_ ]*surfaces[*_ ]*:' "$artifact" | sed -E 's/^[^:]*:[[:space:]]*//')"
    [ -n "$line" ] || return 0
    tokens="$(jq -cn --arg l "$line" '$l | ascii_downcase | [scan("[a-z0-9-]+")]')"
    bad="$(jq -r --arg v "$SURFACES" '($v | split(" ")) as $ok | map(select(. as $t | $ok | index($t) | not)) | join(", ")' <<<"$tokens")"
    [ -z "$bad" ] || die "the Surfaces line names '${bad}'; allowed: ${SURFACES}"
    [ "$tokens" != "[]" ] || die "the Surfaces line is empty; name the surfaces or write 'none'"
    printf '%s' "$tokens"
}

# Set the surfaces, then re-open every phase skipped under the old ones that the new ones select. A
# spec amended after approval to add `auth` owes its threat model even though the run is past it;
# assert refuses every later phase until it is recorded. A spec that no longer declares surfaces
# skips nothing, so every skipped phase re-opens.
set_surfaces() {
    local tokens="$1" file tmp flow p
    file="$(ledger_path)"; tmp="$(mktemp)"
    if [ -n "$tokens" ]; then
        jq --argjson s "$tokens" '.surfaces = $s' "$file" > "$tmp" && mv "$tmp" "$file"
    else
        jq 'del(.surfaces)' "$file" > "$tmp" && mv "$tmp" "$file"
    fi
    flow="$(jq -r .flow "$file")"
    local reopened=0
    while read -r p; do
        [ "$(jq -r --arg p "$p" '.record[$p].status // ""' "$file")" = "skipped" ] || continue
        should_skip "$flow" "$p" && continue
        tmp="$(mktemp)"
        jq --arg p "$p" 'del(.record[$p])' "$file" > "$tmp" && mv "$tmp" "$file"
        reopened=1
    done < <(phases_of "$flow")
    [ "$reopened" = 1 ] && reopen_current
    return 0
}

# Point current at the first phase still owed: not recorded, or recorded and waiting on an approval.
# Called only when a skipped phase re-opened, so a re-opened phase behind the current one becomes
# current again, and a phase still waiting on a human keeps the run held on it.
reopen_current() {
    local file flow p next="" tmp status
    file="$(ledger_path)"; flow="$(jq -r .flow "$file")"
    while read -r p; do
        status="$(jq -r --arg p "$p" '.record[$p].status // ""' "$file")"
        [ "$status" = "skipped" ] && continue
        if [ "$status" = "done" ]; then
            [ -n "$(phase_field "$flow" "$p" approve)" ] \
                && [ -z "$(jq -r --arg p "$p" '.record[$p].approvedAt // ""' "$file")" ] \
                && { next="$p"; break; }
            continue
        fi
        next="$p"; break
    done < <(phases_of "$flow")
    tmp="$(mktemp)"
    jq --arg c "$next" '.current = $c' "$file" > "$tmp" && mv "$tmp" "$file"
}

# A phase with `when` runs only for a change that touches one of the named surfaces. With no
# surfaces declared nothing is skipped: a spec that never classified the change gets every phase,
# because a skipped threat model is the expensive mistake and an extra one is the cheap one.
should_skip() {
    local flow="$1" phase="$2" file when
    file="$(ledger_path)"
    when="$(phase_field "$flow" "$phase" when)"
    [ -n "$when" ] || return 1
    [ "$(jq -r 'has("surfaces")' "$file")" = "true" ] || return 1
    jq -e --arg w "$when" '(.surfaces) as $s | ($w | ascii_downcase | [scan("[a-z0-9-]+")]) | any(. as $x | $s | index($x)) | not' "$file" >/dev/null
}

advance_past() {
    local file; file="$(ledger_path)"
    local flow; flow="$(jq -r .flow "$file")"
    local next="" seen=0 tmp
    while read -r p; do
        if [ "$seen" = 1 ]; then
            [ "$(jq -r --arg p "$p" '.record[$p].status // ""' "$file")" = "done" ] && continue
            if should_skip "$flow" "$p"; then
                tmp="$(mktemp)"
                jq --arg p "$p" --arg w "$(phase_field "$flow" "$p" when)" --arg t "$(date -u +%FT%TZ)" \
                   '.record[$p] = {status:"skipped",reason:("the change declares none of: " + $w),at:$t}' "$file" > "$tmp" && mv "$tmp" "$file"
                continue
            fi
            next="$p"; break
        fi
        [ "$p" = "$1" ] && seen=1
    done < <(phases_of "$flow")
    tmp="$(mktemp)"
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
        [ "$status" = "skipped" ] && continue
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

# Record why a test is being weakened, before guard-tests lets the edit through, for this session only. The waiver log is
# project-level and committed, not run-scoped, so a reviewer reads every reason a test lost an
# assertion, whether or not a flow was open. It is append-only: a reason is never edited away.
cmd_waive() {
    local file="$1" reason="${2:-}"
    [ "$(printf '%s' "$reason" | tr -d '[:space:][:punct:]' | wc -c | tr -d ' ')" -ge 10 ] \
        || die "a waiver needs the reason the test is wrong, in words"
    local rel="${file#"${PROJECT_DIR}"/}"; rel="${rel#./}"
    mkdir -p "${PROJECT_DIR}/.polaris"
    jq -cn --arg f "$rel" --arg r "$reason" --arg s "$SESSION" --arg t "$(date -u +%FT%TZ)" \
        '{file:$f,reason:$r,session:$s,at:$t}' >> "${PROJECT_DIR}/.polaris/waivers.jsonl"
    echo "waived ${rel}"
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
    waive)   [ $# -eq 2 ] || die "usage: waive <test file> <why the test is wrong>"; cmd_waive "$@" ;;
    *)       die "usage: run-state.sh seed|get|target|record|approve|amend|assert|waive|clear" ;;
esac
