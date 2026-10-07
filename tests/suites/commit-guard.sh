# The commit guards: a banned message is denied in every form it arrives in, and a hook or CI bypass is
# refused while a command that only mentions one runs.
# covers: hooks/guard-commit-pr hooks/guard-bypass scripts/check-patterns.sh rules/patterns.json rules/writing.md
source "$(dirname "$0")/../lib.sh"

# guard-commit-pr: bad commit message denied, good allowed
GUARD="${DIR}/../hooks/guard-commit-pr"
bad_msg="$(cat "${DIR}/fixtures/commit-bad.txt")"
good_msg="$(cat "${DIR}/fixtures/commit-good.txt")"
bad_payload="$(jq -n --arg c "git commit -m \"${bad_msg}\"" '{tool_input:{command:$c}}')"
good_payload="$(jq -n --arg c "git commit -m \"${good_msg}\"" '{tool_input:{command:$c}}')"
if echo "$bad_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "ok: bad commit denied"; else echo "FAIL: bad commit not denied"; fail=1; fi
if echo "$good_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "FAIL: good commit denied"; fail=1; else echo "ok: good commit allowed"; fi

# Every form a message arrives in, because until 2026-09-07 only the first of these was checked.
# The extraction was one regex requiring a double-quoted -m, so five of the six forms below carried
# banned words straight through, and the heredoc form, the one a multi-paragraph message actually
# uses, was invisible. A single assertion on the happy path is what let that ship: the guard looked
# tested and covered the least likely case.
gc_denies() { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | "$GUARD" \
    | grep -q '"permissionDecision":"deny"'; }
gc_msgfile="$(mktemp)"; printf '%s\n\nand a second paragraph\n' "$bad_msg" > "$gc_msgfile"
gc_heredoc="git commit -m \"\$(cat <<'EOF'
${bad_msg}

and a second paragraph
EOF
)\""
for form in \
  "single|git commit -m '${bad_msg}'" \
  "ansi-c|git commit -m \$'${bad_msg}'" \
  "dash-F|git commit -F ${gc_msgfile}" \
  "file-eq|git commit --file=${gc_msgfile}" \
  "body-file|gh pr create --body-file ${gc_msgfile} --title ok" \
  "gh-body|gh pr create --title ok --body \"${bad_msg}\"" ; do
  label="${form%%|*}"; cmd="${form#*|}"
  gc_denies "$cmd" && echo "ok: a bad message via ${label} is denied" \
    || { echo "FAIL: ${label} bypassed the writing guard"; fail=1; }
done
gc_denies "$gc_heredoc" && echo "ok: a bad message in a heredoc body is denied" \
  || { echo "FAIL: the heredoc form bypassed the writing guard"; fail=1; }

# And it must stay quiet on things that are not a message. It used to lint any Bash command holding
# the string "git commit", so a grep or a doc edit naming a banned word was refused as a commit.
for form in \
  "a grep|grep -rn 'seamless' docs/" \
  "git status|git status --short" \
  "clean plus a chained command|git commit -m 'key the ledger by session' && echo done" ; do
  label="${form%%|*}"; cmd="${form#*|}"
  gc_denies "$cmd" && { echo "FAIL: the guard fired on ${label}"; fail=1; } \
    || echo "ok: the guard stays quiet on ${label}"
done
rm -f "$gc_msgfile"

# guard-bypass: skipping a hook or CI is never cheaper than fixing the cause. Each refusal names a
# bypass an agent reaches for when a check is red; each allowance is a command that only mentions one.
GB="${DIR}/../hooks/guard-bypass"
gb() { printf '%s' "$2" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | bash "$GB" | grep -q '"permissionDecision":"deny"' \
  && got=deny || got=allow; [ "$got" = "$1" ] || { echo "FAIL: guard-bypass wanted $1, got $got: $2"; fail=1; }; }
gb deny 'git commit --no-verify -m "wip"'
gb deny 'git push --no-verify origin main'
gb deny 'git commit -nm "wip"'
gb deny 'HUSKY=0 git push'
gb deny 'LEFTHOOK=0 git commit -m "x"'
gb deny 'git -c core.hooksPath=/dev/null commit -m x'
gb deny 'gh pr merge 12 --admin --squash'
gb deny "$(printf 'git commit -F- <<EOF\nfix things\n\n[ci skip]\nEOF')"
gb allow 'git commit -m "feat: add guard"'
gb allow 'grep -rn -- --no-verify agents/'
gb allow "$(printf 'cat > notes.md <<EOF\nnever use --no-verify or [skip ci]\nEOF')"
gb allow 'git push -n origin main'
# The second verify pass broke the first fix by quoting: the shell strips the quotes, git still gets
# the flag. Quoted flags, a wrapped `bash -c`, a quoted runner value, a relative hooks path, and the
# GitLab push option are each refused; a real hook directory and a message about the flag are not.
gb deny 'git commit -m x "--no-verify"'
gb deny "bash -c 'git commit --no-verify -m x'"
gb deny 'HUSKY="0" git commit -m x'
gb deny 'git -c core.hooksPath=nohooks commit -m x'
gb deny 'git push -o ci.skip'
gb allow 'git config core.hooksPath .husky'
gb allow 'git commit -m "explain why --no-verify is banned"'
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("guard-bypass"))' "${DIR}/../hooks/hooks.json" >/dev/null \
  || { echo "FAIL: guard-bypass is not wired on Bash"; fail=1; }
echo "ok: guard-bypass refuses every hook and CI bypass and lets mentions through"

exit $fail
