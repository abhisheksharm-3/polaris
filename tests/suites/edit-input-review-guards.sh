# The tool guards: guard-input screens tool results, guard-edit denies the comment law, guard-review demands the over-engineering axis.
# covers: hooks/guard-input hooks/guard-edit hooks/guard-review hooks/hooks.json scripts/check-patterns.sh rules/patterns.json rules/core.md hooks/guard-tests scripts/run-state.sh
source "$(dirname "$0")/../lib.sh"

# guard-input: injection in a tool result flagged, clean stays silent
GINPUT="${DIR}/../hooks/guard-input"
inj_bad="$(jq -n --rawfile t "${DIR}/fixtures/injection-bad.txt" '{tool_response:$t}')"
inj_clean="$(jq -n --rawfile t "${DIR}/fixtures/injection-clean.txt" '{tool_response:$t}')"
if echo "$inj_bad"   | "$GINPUT" | grep -q 'additionalContext'; then echo "ok: injection flagged"; else echo "FAIL: injection not flagged"; fail=1; fi
if echo "$inj_clean" | "$GINPUT" | grep -q 'additionalContext'; then echo "FAIL: clean flagged"; fail=1; else echo "ok: clean tool result silent"; fi

# guard-edit runs on PreToolUse and denies the write, so these assertions changed shape on
# 2026-09-07 along with the hook. It ran on PostToolUse until then, where the hooks reference says
# plainly that a hook cannot block ("the tool already ran"), so the `decision: block` it emitted was
# read by nobody. The old assertions passed anyway, because they only checked that the string
# appeared in stdout. That is the bug worth not repeating: assert the field the harness acts on
# (`permissionDecision`), and assert the file is still untouched afterwards.
GEDIT="${DIR}/../hooks/guard-edit"
ge_on="$(mktemp -d)";  mkdir -p "${ge_on}/.polaris";  echo '{"guardEdit":true}'  > "${ge_on}/.polaris/config.json"
ge_off="$(mktemp -d)"; mkdir -p "${ge_off}/.polaris"; echo '{"guardEdit":false}' > "${ge_off}/.polaris/config.json"

# The content is what this hook judges now, not the file on disk: PreToolUse fires before the write,
# so the bytes under review arrive in tool_input, from `content` for a Write and `new_string` for an
# Edit. A payload naming a path with no content is a call this hook has nothing to say about.
ge_write() { jq -n --arg f "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'; }
ge_edit()  { jq -n --arg f "$1" --arg c "$2" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"x",new_string:$c}}'; }
ge_decision() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="${2:-$ge_on}" "$GEDIT" \
    | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null; }

ge_bad="$(cat "${DIR}/fixtures/inline-comment.ts")"
ge_slopsrc="$(cat "${DIR}/fixtures/slop-no-comment.ts")"

[ "$(ge_decision "$(ge_write "${ge_on}/x.ts" "$ge_bad")")" = "deny" ] \
  && echo "ok: guard-edit denies a Write carrying an inline comment" \
  || { echo "FAIL: guard-edit did not deny an inline comment"; fail=1; }
[ "$(ge_decision "$(ge_edit "${ge_on}/x.ts" "$ge_bad")")" = "deny" ] \
  && echo "ok: guard-edit denies an Edit whose new_string carries one" \
  || { echo "FAIL: guard-edit ignored new_string"; fail=1; }
[ -z "$(ge_decision "$(ge_write "${ge_on}/x.ts" 'export const total = items.length')" )" ] \
  && echo "ok: guard-edit passes clean content with no decision" \
  || { echo "FAIL: guard-edit denied clean content"; fail=1; }

# Non-comment slop stays advisory: it is a judgment call, and denying a write over a naming smell
# would make the hook the thing people switch off.
ge_slop_out="$(printf '%s' "$(ge_write "${ge_on}/y.ts" "$ge_slopsrc")" | CLAUDE_PROJECT_DIR="$ge_on" "$GEDIT")"
printf '%s' "$ge_slop_out" | grep -q 'additionalContext' \
  && echo "ok: non-comment slop is still reported" \
  || { echo "FAIL: non-comment slop not reported"; fail=1; }
printf '%s' "$ge_slop_out" | grep -q 'permissionDecision' \
  && { echo "FAIL: advisory slop carried a permission decision"; fail=1; } \
  || echo "ok: advisory slop carries no permission decision"

[ -z "$(ge_decision "$(ge_write "${ge_off}/x.ts" "$ge_bad")" "$ge_off")" ] \
  && echo "ok: guardEdit false turns the hook off" \
  || { echo "FAIL: guard-edit fired with guardEdit false"; fail=1; }

# It has to be registered on PreToolUse, or none of the above reaches the harness.
jq -e '[.hooks.PreToolUse[] | select(.hooks[0].command | contains("guard-edit"))] | length == 1' \
  "${DIR}/../hooks/hooks.json" >/dev/null \
  && echo "ok: guard-edit is registered on PreToolUse" \
  || { echo "FAIL: guard-edit is not on PreToolUse, where it can deny"; fail=1; }
rm -rf "$ge_on" "$ge_off"

# guard-review: a review with no over-engineering axis is sent back once, one that has it passes
GREVIEW="${DIR}/../hooks/guard-review"
gr_tmp="$(mktemp -d)"
gr_missing="$(jq -n '{agent_id:"rev-1",last_assistant_message:"high | src/x.ts:4 | missing authz check | add one"}')"
gr_present="$(jq -n '{agent_id:"rev-2",last_assistant_message:"Over-engineering: src/y.ts:10 factory with one product, inline it"}')"
gr_run() { echo "$1" | TMPDIR="$gr_tmp" "$GREVIEW"; }
gr_run "$gr_missing" | grep -q '"decision":"block"' && echo "ok: guard-review blocks a review missing the axis" || { echo "FAIL: guard-review did not block"; fail=1; }
if gr_run "$gr_missing" | grep -q '"decision":"block"'; then echo "FAIL: guard-review blocked the same reviewer twice"; fail=1; else echo "ok: guard-review blocks once per reviewer"; fi
if gr_run "$gr_present" | grep -q 'decision'; then echo "FAIL: guard-review blocked a complete review"; fail=1; else echo "ok: guard-review passes a review with the axis"; fi
rm -rf "$gr_tmp"

# guard-tests: weakening a test is the cheapest way to turn red green, and the way Claude models
# cheat most (rules/root-cause.md). Removing assertions or adding a skip in an existing test is
# refused until this session logs a reason with waive; a waiver from another session does not count.
gt_proj="$(mktemp -d)"; mkdir -p "$gt_proj/src/__tests__"
gt_file="$gt_proj/src/__tests__/total.test.ts"
printf "it('a', () => {\n  expect(total(1)).toBe(2);\n  expect(total(0)).toBe(0);\n});\n" > "$gt_file"
gt() { printf '%s' "$2" | jq -c '. + {session_id:"gt-1"}' | CLAUDE_PROJECT_DIR="$gt_proj" bash "${DIR}/../hooks/guard-tests" \
  | grep -q '"permissionDecision":"deny"' && got=deny || got=allow
  [ "$got" = "$1" ] || { echo "FAIL: guard-tests wanted $1, got $got: $3"; fail=1; }; }
gt_waive() { CLAUDE_PROJECT_DIR="$gt_proj" CLAUDE_CODE_SESSION_ID="$1" bash "${DIR}/../scripts/run-state.sh" waive "$gt_file" "$2" >/dev/null 2>&1; }
gt_drop="$(jq -n --arg f "$gt_file" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"  expect(total(1)).toBe(2);\n  expect(total(0)).toBe(0);",new_string:"  expect(total(0)).toBe(0);"}}')"
gt deny "$gt_drop" "an edit dropping an assertion"
gt deny "$(jq -n --arg f "$gt_file" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"it(",new_string:"it.skip("}}')" "an edit adding a skip"
gt deny "$(jq -n --arg f "$gt_file" '{tool_name:"Write",tool_input:{file_path:$f,content:"it(\"a\", () => {});\n"}}')" "a write emptying the test"
gt allow "$(jq -n --arg f "$gt_file" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"expect(total(1)).toBe(2);",new_string:"expect(total(1)).toBe(2);\n  expect(total(2)).toBe(4);"}}')" "an edit adding an assertion"
gt allow "$(jq -n --arg f "$gt_proj/src/__tests__/new.test.ts" '{tool_name:"Write",tool_input:{file_path:$f,content:"it(\"a\", () => {});\n"}}')" "a new test file"
gt_waive gt-1 "   " && { echo "FAIL: waive accepted a blank reason"; fail=1; }
gt_waive gt-other "the pricing rule changed in the 2026 spec"
gt deny "$gt_drop" "an edit after another session's waiver"
gt_waive gt-1 "the pricing rule changed in the 2026 spec"
gt allow "$gt_drop" "an edit after this session's waiver"
gt_fresh="$(mktemp -d)"; mkdir -p "$gt_fresh/src/__tests__"
printf "it('a', () => {\n  expect(f(1)).toBe(2);\n});\n" > "$gt_fresh/src/__tests__/f.test.ts"
gtf() { printf '%s' "$2" | jq -c '. + {session_id:"gt-2"}' | (cd "$gt_fresh" && CLAUDE_PROJECT_DIR="$gt_fresh" bash "${DIR}/../hooks/guard-tests") \
  | grep -q '"permissionDecision":"deny"' && got=deny || got=allow
  [ "$got" = "$1" ] || { echo "FAIL: guard-tests wanted $1, got $got: $3"; fail=1; }; }
gtf deny "$(jq -n --arg f "$gt_fresh/src/__tests__/f.test.ts" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"  expect(f(1)).toBe(2);",new_string:"  // expect(f(1)).toBe(2);"}}')" "commenting out an assertion"
gtf deny "$(jq -n --arg f "$gt_fresh/src/__tests__/f.test.ts" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"it(",new_string:"it.only("}}')" "focusing one test with .only"
gtf deny "$(jq -n '{tool_name:"Bash",tool_input:{command:"sed -i \"\" \"/expect/d\" src/__tests__/f.test.ts"}}')" "an in-place shell rewrite of a test"
gtf allow "$(jq -n '{tool_name:"Bash",tool_input:{command:"sed -i \"\" s/a/b/ src/app.ts"}}')" "an in-place shell edit of source"
gtf allow "$(jq -n '{tool_name:"Bash",tool_input:{command:"npx vitest run src/__tests__/f.test.ts > /tmp/out.log 2>&1"}}')" "running a test with its output redirected"
gtf allow "$(jq -n '{tool_name:"Bash",tool_input:{command:"cp src/__tests__/f.test.ts /tmp/backup.ts"}}')" "copying a test out"
gtf deny "$(jq -n '{tool_name:"Bash",tool_input:{command:"cp /tmp/empty.ts src/__tests__/f.test.ts"}}')" "copying over a test"
gtf allow "$(jq -n --arg f "$gt_fresh/src/__tests__/f.test.ts" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"});",new_string:"});\nit(\"q\", () => { expect(queue.pending()).toBe(0); });"}}')" "a method named pending in a new assertion"
rm -rf "$gt_fresh"
rm -rf "$gt_proj"
echo "ok: guard-tests refuses a weakened test until a reason is logged"

# guard-edit stages the content at the file's relative path before the permission decision, so the
# path is untrusted: no shape of `..` may place the staged copy outside its temp dir. A class test,
# because the cost of a recurrence is a write anywhere the user can write.
tv_proj="$(mktemp -d)"; mkdir -p "$tv_proj/.polaris"; echo '{}' > "$tv_proj/.polaris/config.json"
tv_mark="$(mktemp -u "${TMPDIR:-/tmp}/polaris-traversal.XXXXXX")"
tv_base="$(basename "$tv_mark")"; tv_parent="$(dirname "$tv_mark")"
for tv_path in "$tv_proj/../../../../../../..${tv_parent}/${tv_base}/a.ts" "$tv_proj/src/./../../../../../../..${tv_parent}/${tv_base}/b.test.ts" "../../../../../../..${tv_parent}/${tv_base}/c.ts"; do
  jq -n --arg f "$tv_path" '{tool_name:"Write",tool_input:{file_path:$f,content:"export const a = 1;\n"}}' \
    | CLAUDE_PROJECT_DIR="$tv_proj" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/guard-edit" >/dev/null 2>&1
done
[ ! -e "$tv_mark" ] && echo "ok: guard-edit stages nothing outside its temp dir, whatever the path" \
  || { echo "FAIL: guard-edit wrote outside its stage dir at $tv_mark"; rm -rf "$tv_mark"; fail=1; }
rm -rf "$tv_proj"

# Polaris exempts its own rules files by real path. A segment match exempted every user file under a
# rules/ directory, which turned the comment law off there once guard-edit staged real paths.
ru_proj="$(mktemp -d)"; mkdir -p "$ru_proj/.polaris"; echo '{}' > "$ru_proj/.polaris/config.json"
jq -n --arg f "$ru_proj/src/rules/pricing.ts" '{tool_name:"Write",tool_input:{file_path:$f,content:"export const a = 1; // why\n"}}' \
  | CLAUDE_PROJECT_DIR="$ru_proj" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/guard-edit" | grep -q '"permissionDecision":"deny"' \
  && echo "ok: the comment law holds in a user file under a rules/ directory" \
  || { echo "FAIL: a user file under rules/ escaped the comment law"; fail=1; }
rm -rf "$ru_proj"

exit $fail
