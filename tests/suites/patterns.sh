# Pattern checks: every rule class flags its bad fixture and passes its clean one.
# covers: scripts/check-patterns.sh rules/patterns.json
source "$(dirname "$0")/../lib.sh"

# prose: bad flagged, clean passes
expect_exit 1 "$CHECK" prose "${DIR}/fixtures/bad-prose.md"
expect_exit 0 "$CHECK" prose "${DIR}/fixtures/clean-prose.md"
# code: bad flagged, clean passes (per language)
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ts.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.ts"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.py"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.py"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.go"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.go"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.rs"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.rs"
# the comment law: a comment trailing code is flagged, a multi-line doc block above a declaration is
# not. The clean fixtures carry real doc comments, so their exit 0 above proves the second half.
expect_exit 1 "$CHECK" code "${DIR}/fixtures/inline-comment.ts"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/inline-comment.py"
ic_out="$("$CHECK" code "${DIR}/fixtures/inline-comment.ts" || true)"
echo "$ic_out" | grep -q 'inline-comment' \
  && echo "ok: inline comment flagged by rule id" || { echo "FAIL: inline-comment rule id missing"; fail=1; }

# injection: bad flagged, clean passes, paraphrase (no literal denylist match) still flagged
expect_exit 1 "$CHECK" injection "${DIR}/fixtures/injection-bad.txt"
expect_exit 0 "$CHECK" injection "${DIR}/fixtures/injection-clean.txt"
expect_exit 1 "$CHECK" injection "${DIR}/fixtures/injection-paraphrase.txt"

# The ui pattern class: each greppable interface anti-pattern is caught by its own id, and the
# `unless` escape keeps an outline removed beside its focus-visible replacement from being flagged.
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ui.tsx"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ui.html"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean-ui.tsx"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean-ui-edges.tsx"
ui_out="$("$CHECK" code "${DIR}/fixtures/bad-ui.tsx" "${DIR}/fixtures/bad-ui.html" || true)"
for id in transition-all zoom-disabled paste-blocked div-click viewport-height; do
  grep -q ": ${id}:" <<<"$ui_out" || { echo "FAIL: ui pattern '${id}' did not fire on its fixture"; fail=1; }
done
echo "ok: every ui pattern fires on its fixture"

# The test and migration pattern classes. Blocking rules fail the check; advisory ones print and pass,
# because a deliberate column drop must not need a workaround to get through the gate.
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.test.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.test.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/migrations/0042_split_users.sql"
tp_out="$("$CHECK" code "${DIR}/fixtures/bad.test.ts" "${DIR}/fixtures/migrations/0042_split_users.sql" || true)"
for id in focused-test fixed-sleep tautology unexplained-skip drop not-null-no-default; do
  grep -q ": ${id}:" <<<"$tp_out" || { echo "FAIL: pattern '${id}' did not fire on its fixture"; fail=1; }
done
echo "ok: every test and migration pattern fires on its fixture"

# The ci class: a red pipeline "fixed" by swallowing the check is refused; continue-on-error is an
# advisory because an informational job can use it on purpose.
expect_exit 1 "$CHECK" code "${DIR}/fixtures/ci/.github/workflows/bad.yml"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/ci/.github/workflows/clean.yml"
ci_out="$("$CHECK" code "${DIR}/fixtures/ci/.github/workflows/bad.yml" || true)"
for id in swallowed-check pass-with-no-tests disabled-step continue-on-error; do
  grep -q ": ${id}:" <<<"$ci_out" || { echo "FAIL: ci pattern '${id}' did not fire on its fixture"; fail=1; }
done
echo "ok: every ci pattern fires on its fixture"

# Patch smells: a suppression with no reason fails; one that names its reason passes.
expect_exit 1 "$CHECK" code "${DIR}/fixtures/patch-smells.ts"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/patch-smells.py"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/patch-clean.ts"
ps_out="$("$CHECK" code "${DIR}/fixtures/patch-smells.ts" "${DIR}/fixtures/patch-smells.py" || true)"
for id in suppression-no-reason deferred-tick noqa-no-code; do
  grep -q ": ${id}:" <<<"$ps_out" || { echo "FAIL: patch pattern '${id}' did not fire on its fixture"; fail=1; }
done
echo "ok: every patch-smell pattern fires on its fixture"

exit $fail
