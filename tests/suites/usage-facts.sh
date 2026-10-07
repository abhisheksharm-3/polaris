# usage-facts reads Claude Code's usage database read-only and stays silent without it.
# covers: scripts/usage-facts.sh
source "$(dirname "$0")/../lib.sh"

# usage-facts reads Claude Code's own database and must never write to it or fail without it.
UF="${DIR}/../scripts/usage-facts.sh"
uf_missing="$(POLARIS_USAGE_DB=/nonexistent/usage.db bash "$UF" project 2>&1)"; uf_rc=$?
[ "$uf_rc" -eq 0 ] && [ -z "$uf_missing" ] \
  && echo "ok: usage-facts is silent and clean with no database" \
  || { echo "FAIL: usage-facts errored without a database (rc=$uf_rc)"; fail=1; }
grep -q 'mode=ro' "$UF" && grep -q -- '-readonly' "$UF" \
  && echo "ok: usage-facts opens the database read-only" \
  || { echo "FAIL: usage-facts could write to Claude Code's usage database"; fail=1; }
# Both conditions, because the first version of this assertion only ran the one that happens to hold
# on the author's machine. usage-facts checked for the database before it validated the subcommand,
# so it exited 0 on any host without one: the test passed locally, where usage.db exists, and failed
# in CI, where it does not. A caller who typed the wrong name has made a mistake either way.
POLARIS_USAGE_DB=/nonexistent/usage.db bash "$UF" nonsense >/dev/null 2>&1 \
  && { echo "FAIL: usage-facts accepted an unknown subcommand with no database"; fail=1; } \
  || echo "ok: usage-facts rejects an unknown subcommand with no database"
bash "$UF" nonsense >/dev/null 2>&1 \
  && { echo "FAIL: usage-facts accepted an unknown subcommand"; fail=1; } \
  || echo "ok: usage-facts rejects an unknown subcommand"
for uf_sub in project agents models days sessions; do
  POLARIS_USAGE_DB=/nonexistent/usage.db bash "$UF" "$uf_sub" >/dev/null 2>&1 \
    || { echo "FAIL: usage-facts ${uf_sub} errored with no database instead of staying silent"; fail=1; }
done
echo "ok: every real subcommand exits clean with no database"

exit $fail
