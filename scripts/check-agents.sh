#!/usr/bin/env bash
# Validate plugin-agent frontmatter: required fields present, model tier valid,
# no forbidden fields (hooks/mcpServers/permissionMode are ignored for plugin agents).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
fail=0

for f in "${ROOT}"/agents/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$f")"

  echo "$fm" | grep -qE '^name:' || { echo "FAIL $name: missing name"; fail=1; }
  echo "$fm" | grep -qE '^description:' || { echo "FAIL $name: missing description"; fail=1; }
  # The accepted spellings are the ones rules/model-floor.json can rank, plus `inherit`. Keeping a
  # second hardcoded list here is what let the validator reject `fable` while guard-phase waved it
  # through: one file decides what a model may be, and both readers ask it.
  model="$(echo "$fm" | grep -m1 -E '^model:' | awk '{print $2}')"
  if [ -f "${ROOT}/rules/model-floor.json" ] && command -v jq >/dev/null 2>&1; then
    jq -e --arg m "${model:-}" '($m == "inherit") or (.aliases | has($m))' \
      "${ROOT}/rules/model-floor.json" >/dev/null 2>&1 \
      || { echo "FAIL $name: model '${model:-none}' is not in rules/model-floor.json aliases (or 'inherit')"; fail=1; }
  fi

  # The effort floor. It was a dispatch gate in guard-phase and refused nothing for its whole life,
  # because the Agent tool has no `effort` parameter. Frontmatter is where the value exists, so this
  # is where the floor is enforceable.
  if [ -f "${ROOT}/rules/effort-floor.json" ] && command -v jq >/dev/null 2>&1; then
    agent_name="$(basename "$f" .md)"
    efloor="$(jq -r --arg a "$agent_name" '.floor[$a] // ""' "${ROOT}/rules/effort-floor.json")"
    effort="$(echo "$fm" | grep -m1 -E '^effort:' | awk '{print $2}')"
    if [ -n "$efloor" ]; then
      if [ -z "$effort" ]; then
        echo "FAIL $name: rules/effort-floor.json sets a floor of '${efloor}' and the frontmatter declares no effort"; fail=1
      else
        want="$(jq -r --arg e "$effort" '.levels | index($e) // -1' "${ROOT}/rules/effort-floor.json")"
        need="$(jq -r --arg e "$efloor" '.levels | index($e) // -1' "${ROOT}/rules/effort-floor.json")"
        if [ "$want" -lt 0 ]; then
          echo "FAIL $name: effort '${effort}' is not one of $(jq -r '.levels | join("/")' "${ROOT}/rules/effort-floor.json")"; fail=1
        elif [ "$want" -lt "$need" ]; then
          echo "FAIL $name: effort '${effort}' is below the floor '${efloor}' in rules/effort-floor.json"; fail=1
        fi
      fi
    fi
  fi
  # A misspelled tool name in tools/disallowedTools does not error at load, it silently drops the
  # restriction or the capability. Check every token against the canonical tool names.
  canonical="Agent Artifact AskUserQuestion Bash CronCreate CronDelete CronList Edit EndConversation
EnterPlanMode EnterWorktree ExitPlanMode ExitWorktree Glob Grep ListMcpResourcesTool LSP Monitor
NotebookEdit PowerShell PushNotification Read ReadMcpResourceTool RemoteTrigger ReportFindings
ScheduleWakeup SendMessage SendUserFile ShareOnboardingGuide Skill TaskCreate TaskGet TaskList
TaskOutput TaskStop TaskUpdate TodoWrite ToolSearch WaitForMcpServers WebFetch WebSearch Workflow
Write"
  for field in tools disallowedTools; do
    line="$(echo "$fm" | awk -v f="^${field}:" '$0~f{sub(/^[a-zA-Z]+:[[:space:]]*/,"");print;exit}')"
    [ -n "$line" ] || continue
    for tok in $(printf '%s' "$line" | tr ',' ' '); do
      [ -n "$tok" ] || continue
      case "$tok" in mcp__*) continue;; esac
      printf '%s\n' $canonical | grep -qx "$tok" \
        || { echo "FAIL $name: ${field} names unknown tool '${tok}'"; fail=1; }
    done
  done
  # `hooks`, `mcpServers`, and `permissionMode` were failed here as "ignored for plugin agents".
  # The current subagent schema supports all three, along with memory, maxTurns, isolation,
  # background, color, and initialPrompt, so failing the build on them blocked the plugin from using
  # documented capability. Only genuinely unknown fields are worth failing on now.
  known="name description model effort tools disallowedTools skills permissionMode maxTurns
mcpServers hooks memory background isolation color initialPrompt experimental"
  while IFS= read -r field; do
    [ -n "$field" ] || continue
    printf '%s\n' $known | grep -qx "$field" \
      || { echo "FAIL $name: unknown frontmatter field '${field}'"; fail=1; }
  done < <(echo "$fm" | grep -oE '^[a-zA-Z][a-zA-Z0-9_]*:' | tr -d ':')
  echo "$fm" | grep -qE '^skills:' || echo "warn $name: no skills field"
  [ "$fail" = 0 ] && echo "ok $name" || true
done

exit $fail
