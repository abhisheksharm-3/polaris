#!/usr/bin/env bash
# What a project, a model tier, or an agent actually cost, from Claude Code's own usage database.
#
# ~/.claude/usage.db is maintained by Claude Code and nothing in Polaris read it until 2026-09-07.
# It holds one row per session and one per turn, with input, output, cache-read and cache-creation
# tokens, the tool name, the working directory, and for a subagent turn its agent id and type. That
# is ground truth for every question Polaris had been answering by estimation: the token-efficiency
# work was arithmetic over file sizes, the model and effort floors were policy with no feedback, and
# the review levels were picked from diff-size heuristics alone.
#
# Read-only, and it never creates the database. When it is absent this prints nothing and exits 0,
# because a machine without it is not an error, it is a machine that has not been used yet.
#
# Two limits worth knowing before trusting a number out of this, both observed on 2026-09-07:
#
# 1. The `agents` table is sparse. It had 3 rows against 753 distinct subagent ids in `turns`, so
#    `agents` reports most work as agent_type 'unknown'. Use it for how much subagent work happened,
#    not for which agent did it. For that, count subagent_type across the transcripts:
#    grep -rhoE '"subagent_type":"[^"]+"' ~/.claude/projects | sort | uniq -c | sort -rn
#
# 2. It is a cache Claude Code fills by parsing transcripts, so it lags. `processed_files` tracks
#    what it has read; the newest row in `turns` can be days behind the newest session.
#
# Usage:
#   usage-facts.sh project [dir]        tokens and turns for one project, default the current one
#   usage-facts.sh agents [days]        which subagents ran, how often, and what they cost
#   usage-facts.sh models [days]        spend per model tier
#   usage-facts.sh days [n]             the last n days, newest first
#   usage-facts.sh sessions [n]         the n most recent sessions
set -uo pipefail

DB="${POLARIS_USAGE_DB:-${HOME}/.claude/usage.db}"
[ -f "$DB" ] || exit 0
command -v sqlite3 >/dev/null 2>&1 || { echo "usage-facts: sqlite3 is required" >&2; exit 0; }

# A read-only URI so a reporting script can never be the thing that corrupts the database, and so it
# works while Claude Code holds the file open.
q() { sqlite3 "file:${DB}?mode=ro" -readonly "$@" 2>/dev/null; }

fmt() { awk -F'|' 'BEGIN{OFS="\t"} {print}'; }

sub="${1:-project}"
case "$sub" in
    project)
        dir="${2:-$PWD}"
        q "SELECT
             COUNT(*)                                   AS turns,
             COALESCE(SUM(input_tokens), 0)             AS input,
             COALESCE(SUM(output_tokens), 0)            AS output,
             COALESCE(SUM(cache_read_tokens), 0)        AS cache_read,
             COALESCE(SUM(cache_creation_tokens), 0)    AS cache_created,
             COALESCE(SUM(is_subagent), 0)              AS subagent_turns
           FROM turns WHERE cwd LIKE '${dir}%';" \
        | awk -F'|' '{printf "turns\t%s\ninput\t%s\noutput\t%s\ncache_read\t%s\ncache_created\t%s\nsubagent_turns\t%s\n",$1,$2,$3,$4,$5,$6}'
        ;;
    agents)
        days="${2:-30}"
        echo "# agent_type is sparse in this table; see the header for the transcript count" >&2
        # agent_type lives on the agents table; a turn carries only the id, so the join is what
        # turns "some subagent ran" into "the reviewer ran 166 times and cost this much".
        q "SELECT COALESCE(a.agent_type, 'unknown') AS agent,
                  COUNT(DISTINCT t.agent_id)        AS runs,
                  COUNT(*)                          AS turns,
                  COALESCE(SUM(t.output_tokens), 0) AS output
           FROM turns t LEFT JOIN agents a ON a.agent_id = t.agent_id
           WHERE t.is_subagent = 1
             AND t.timestamp >= datetime('now', '-${days} days')
           GROUP BY agent ORDER BY output DESC;" | fmt
        ;;
    models)
        days="${2:-30}"
        q "SELECT COALESCE(model, 'unknown')            AS model,
                  COUNT(*)                              AS turns,
                  COALESCE(SUM(input_tokens), 0)        AS input,
                  COALESCE(SUM(output_tokens), 0)       AS output,
                  COALESCE(SUM(cache_read_tokens), 0)   AS cache_read
           FROM turns
           WHERE timestamp >= datetime('now', '-${days} days')
           GROUP BY model ORDER BY output DESC;" | fmt
        ;;
    days)
        n="${2:-14}"
        q "SELECT date(timestamp)                       AS day,
                  COUNT(DISTINCT session_id)            AS sessions,
                  COUNT(*)                              AS turns,
                  COALESCE(SUM(output_tokens), 0)       AS output
           FROM turns
           GROUP BY day ORDER BY day DESC LIMIT ${n};" | fmt
        ;;
    sessions)
        n="${2:-10}"
        q "SELECT substr(session_id, 1, 8) AS id,
                  COALESCE(project_name, '?')           AS project,
                  COALESCE(git_branch, '?')             AS branch,
                  turn_count,
                  total_output_tokens,
                  COALESCE(topic, '')                   AS topic
           FROM sessions ORDER BY last_timestamp DESC LIMIT ${n};" | fmt
        ;;
    *)
        echo "usage-facts: usage: usage-facts.sh project|agents|models|days|sessions [arg]" >&2
        exit 1
        ;;
esac
