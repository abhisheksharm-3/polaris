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
  model="$(echo "$fm" | grep -m1 -E '^model:' | awk '{print $2}')"
  case "$model" in
    opus|sonnet|haiku) ;;
    *) echo "FAIL $name: model must be opus/sonnet/haiku, got '${model:-none}'"; fail=1;;
  esac
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
  for bad in hooks mcpServers permissionMode; do
    echo "$fm" | grep -qE "^${bad}:" && { echo "FAIL $name: forbidden field '${bad}' (ignored for plugin agents)"; fail=1; }
  done
  echo "$fm" | grep -qE '^skills:' || echo "warn $name: no skills field"
  [ "$fail" = 0 ] && echo "ok $name" || true
done

exit $fail
