# The workflows: every dispatch names a real agent and an effort, fan-out is bounded, and review-level rates a diff.
# covers: workflows/*.js scripts/review-level.sh agents/*.md
source "$(dirname "$0")/../lib.sh"

# workflows: every agent a workflow names must exist. A dispatch to a name that is not there
# spawns a generic subagent without the fleet's tool restrictions, and nothing says so.
wf_missing=""
for f in "${DIR}"/../workflows/*.js; do
  [ -f "$f" ] || continue
  node --check "$f" >/dev/null 2>&1 || { echo "FAIL: $(basename "$f") is not valid javascript"; fail=1; }
  for a in $(grep -oE "agent(Type)?: *'polaris:[a-z-]+'" "$f" | grep -oE "polaris:[a-z-]+" | sort -u); do
    [ -f "${DIR}/../agents/${a#polaris:}.md" ] || wf_missing="${wf_missing} ${a}($(basename "$f"))"
  done
  grep -q 'agentType' "$f" || { echo "FAIL: $(basename "$f") dispatches without agentType"; fail=1; }
done
[ -z "$wf_missing" ] && echo "ok: every agent named in a workflow exists" \
  || { echo "FAIL: workflows name agents that do not exist:${wf_missing}"; fail=1; }
echo "ok: every workflow passes agentType"
# The over-engineering axis is mandatory wherever Polaris reviews, workflows included.
for f in "${DIR}"/../workflows/review.js "${DIR}"/../workflows/verify.js; do
  grep -q 'over-engineering' "$f" || { echo "FAIL: $(basename "$f") omits the over-engineering axis"; fail=1; }
done
echo "ok: the review workflows carry the over-engineering axis"

# The grep above passes on a file that merely mentions the axis. review.js selects dimensions per
# level, so a key dropped or misspelled in one level's list shrinks that level silently and
# deadlocks the reviewer against guard-review. Assert each list against DIMENSIONS instead.
lv_out="$(node -e '
const fs = require("fs")
const s = fs.readFileSync(process.argv[1], "utf8")
const q = "\x27"
const dims = [...s.matchAll(new RegExp("\\{ key: " + q + "([a-z-]+)" + q, "g"))].map(m => m[1])
const block = s.slice(s.indexOf("const LEVELS"))
const levels = [...block.slice(0, block.indexOf("\n}")).matchAll(/^  ([a-z]+): \{(.*)$/gm)]
const bad = []
if (dims.length !== 8) bad.push("DIMENSIONS holds " + dims.length + " keys, expected 8")
if (levels.length !== 4) bad.push("LEVELS holds " + levels.length + " rows, expected 4")
for (const [, name, body] of levels) {
  const m = body.match(/keys: \[([^\]]*)\]/)
  const keys = m ? [...m[1].matchAll(new RegExp(q + "([a-z-]+)" + q, "g"))].map(x => x[1]) : dims
  for (const k of keys) if (!dims.includes(k)) bad.push(name + " names " + k + ", which is not a dimension")
  if (!keys.includes("over-engineering")) bad.push(name + " omits over-engineering")
}
process.stdout.write(bad.join("; "))
' "${DIR}/../workflows/review.js")"
[ -z "$lv_out" ] && echo "ok: every review level resolves against DIMENSIONS and keeps over-engineering" \
  || { echo "FAIL: ${lv_out}"; fail=1; }

# The evidence pack and the confirm narrowing are pure code inside the workflow, so the test runs
# the real source rather than grepping for it: a pack that silently drops the tail, or a narrowing
# that reaches high severity, both read fine and cost a finding.
rv_out="$(node -e '
const fs = require("fs")
const s = fs.readFileSync(process.argv[1], "utf8")
const from = s.indexOf("const PACK_LINES")
const to = s.indexOf("const flatten")
const bad = []
if (from < 0 || to < 0 || from > to) { process.stdout.write("review.js no longer holds the pack and the filter before flatten"); process.exit(0) }
if (from > s.indexOf("await pipeline")) bad.push("the pack is built after the fan-out, not before it")
if (!/Review \$\{target\}[\s\S]*\$\{evidence\}/.test(s)) bad.push("the reviewer prompt does not interpolate the pack")
const snippet = s.slice(from, to) + "\nreturn { pack, isEligible, whyNotEligible }"
const diff = Array.from({ length: 4000 }, (_, i) => "+line " + i).join("\n")
const run = (level, confirm) => new Function("level", "rules", "args", snippet)(level, { confirm }, { evidence: diff })
const high = run("high", ["high", "medium"])
const packed = high.pack.split("\n")
if (packed.length !== 1501) bad.push("the pack holds " + packed.length + " lines, expected 1500 plus the truncation line")
if (!/2500 diff line\(s\) dropped/.test(high.pack)) bad.push("the pack does not say how many lines it dropped")
const med = sz => ({ severity: "medium", fix: "x".repeat(sz) })
if (high.isEligible(med(30))) bad.push("a medium with a 30-character fix is still confirmed at high")
if (!/30 characters/.test(high.whyNotEligible(med(30)))) bad.push("the narrowing does not name the fix size")
if (!high.isEligible(med(200))) bad.push("a medium with a long fix is no longer confirmed at high")
if (!high.isEligible({ severity: "high", fix: "x" })) bad.push("narrowing reached high severity at high")
const mid = run("mid", ["high"])
if (!mid.isEligible({ severity: "high", fix: "x" })) bad.push("a high-severity finding is not confirmed at mid")
if (mid.isEligible(med(200))) bad.push("mid confirmed a medium it does not ask about")
process.stdout.write(bad.join("; "))
' "${DIR}/../workflows/review.js")"
[ -z "$rv_out" ] && echo "ok: the evidence pack is bounded and the confirm narrowing spares high severity" \
  || { echo "FAIL: ${rv_out}"; fail=1; }

# An empty level is what review-level.sh prints for a changeset with no changed files. The workflow
# must dispatch nothing rather than fall back to seven reviewers over an empty diff.
grep -q "asked === ''" "${DIR}/../workflows/review.js" \
  && [ "$(grep -c "level: 'none'" "${DIR}/../workflows/review.js")" -eq 1 ] \
  && echo "ok: an empty changeset dispatches no reviewer" \
  || { echo "FAIL: review.js reviews a changeset with no changed files"; fail=1; }


# Every workflow dispatch names an effort. A dispatch that omits it inherits the session's, which is
# how verify.js and build.js came to run every agent at high with nothing saying so.
wf_bad=""
for w in "${DIR}/../workflows"/*.js; do
  d="$(grep -c 'agent(' "$w")"; e="$(grep -c 'effort:' "$w")"
  [ "$e" -ge "$d" ] || wf_bad="${wf_bad} $(basename "$w")(${e}/${d})"
done
[ -z "$wf_bad" ] && echo "ok: every workflow dispatch names an effort" \
  || { echo "FAIL: workflow dispatches without an effort:${wf_bad}"; fail=1; }

# The review level, from the diff alone. These run the R3 table with no dispatch and no model, which
# is the whole reason the table lives in a script rather than inside the workflow.
RL="${DIR}/../scripts/review-level.sh"
TAB="$(printf '\t')"
rl() { printf '%b' "$1" | bash "$RL"; }
rl_is() {
  got="$(rl "$2")"
  [ "$got" = "$3" ] && echo "ok: $1" || { echo "FAIL: $1 (got '${got}', wanted '${3}')"; fail=1; }
}
rl_is "a one-file doc diff rates low" "3${TAB}1${TAB}README.md\n" low
# A risk path beats the size rule: two lines under auth/ is where a small diff is the expensive one.
rl_is "a risk path rates high whatever its size" "2${TAB}0${TAB}src/auth/session.ts\n" high
rl_is "4 files and 120 lines rate mid" \
  "30${TAB}0${TAB}src/a.ts\n30${TAB}0${TAB}src/b.ts\n30${TAB}0${TAB}src/c.ts\n30${TAB}0${TAB}src/d.ts\n" mid
rl_is "20 files and 900 lines rate high" \
  "$(i=1; while [ $i -le 20 ]; do printf '45\t0\tsrc/f%s.ts\n' $i; i=$((i+1)); done)" high
# A test-only diff drops whatever its size, or every change to this file would order a full review.
rl_is "a 1000-line test-only diff rates low" "600${TAB}400${TAB}tests/run-tests.sh\n" low
rl_is "an empty diff rates nothing" "" ""
rl_is "risk wins over low risk" \
  "5${TAB}0${TAB}db/migrations/004.sql\n2${TAB}0${TAB}docs/api.md\n" high
rl_is "the order of the paths does not change the answer" \
  "2${TAB}0${TAB}docs/api.md\n5${TAB}0${TAB}db/migrations/004.sql\n" high
# Numstat shapes that would otherwise crash the arithmetic or launder a risk path through a rename.
rl_is "a binary file counts as a file and no lines" "-${TAB}-${TAB}assets/logo.png\n" low
rl_is "both sides of a rename are judged" "1${TAB}1${TAB}old.ts => src/auth/new.ts\n" high
rl_is "a brace rename is expanded before it is judged" \
  "1${TAB}1${TAB}src/{old => auth}/x.ts\n" high
rl_is "a path holding a space survives" "1${TAB}1${TAB}src/my file.ts\n" low
rl_garbage="$(printf 'garbage\n' | bash "$RL")"; rl_code=$?
[ -z "$rl_garbage" ] && [ "$rl_code" -eq 0 ] \
  && echo "ok: malformed numstat rates nothing and exits 0" \
  || { echo "FAIL: malformed numstat did not exit clean and empty"; fail=1; }


# --- every workflow's fan-out has a stated ceiling ----------------------------------------------

# verify.js bounded its finders and not its judges: rounds x angles capped the finders at 16, while
# judges were 3 lenses per finding with no cap on findings, so one productive round could dispatch
# 60 and a full run reached roughly 207. build.js had the same shape one level up, where the slice
# count the Split agent happened to return multiplied everything after it.
#
# The assertion is structural rather than a live count, because dispatching agents to measure a
# dispatch ceiling is the problem it is checking for.
for wf in verify build; do
  grep -q 'judgeBudget\|MAX_SLICES' "${DIR}/../workflows/${wf}.js" \
    && echo "ok: workflows/${wf}.js states a fan-out ceiling" \
    || { echo "FAIL: workflows/${wf}.js has no ceiling on its fan-out"; fail=1; }
done
# Each level must name its own budget, or one level inherits another's ceiling silently.
for lvl in low mid high; do
  grep -qE "${lvl}:.*judgeBudget: [0-9]+" "${DIR}/../workflows/verify.js" \
    || { echo "FAIL: verify.js level ${lvl} names no judge budget"; fail=1; }
  grep -qE "${lvl}: [0-9]+" "${DIR}/../workflows/build.js" \
    || { echo "FAIL: build.js level ${lvl} names no slice cap"; fail=1; }
done
echo "ok: every verify and build level names its own ceiling"
# A ceiling that drops work silently is worse than no ceiling: it reads as "nothing else was found".
grep -q 'reported unjudged' "${DIR}/../workflows/verify.js" \
  && echo "ok: verify.js reports what its budget did not reach" \
  || { echo "FAIL: verify.js drops findings past its budget silently"; fail=1; }
grep -q 'deferred' "${DIR}/../workflows/build.js" \
  && echo "ok: build.js reports the slices it deferred" \
  || { echo "FAIL: build.js drops slices past its cap silently"; fail=1; }
# The judge panel must scale with severity, or the budget is spent on trivia.
grep -q 'lensesFor' "${DIR}/../workflows/verify.js" \
  && echo "ok: verify.js scales its judge panel by severity" \
  || { echo "FAIL: verify.js gives every finding the same panel"; fail=1; }
# review.js batches its confirm agents per dimension, which is what bounds it at 28. If that ever
# becomes per-finding, the ceiling documented in CLAUDE.md stops being true.
grep -q 'confirm:\${r.dimension}' "${DIR}/../workflows/review.js" \
  && echo "ok: review.js confirms per dimension, which is what bounds it" \
  || { echo "FAIL: review.js no longer batches confirmation per dimension"; fail=1; }

exit $fail
