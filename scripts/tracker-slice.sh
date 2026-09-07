#!/usr/bin/env bash
# The slice of the work tracker worth injecting, newest first, under a byte ceiling.
#
# The tracker is the one injected file a project writes to every session, so it is the one that
# grows without a ceiling. It went 1024 -> 17374 bytes over six commits and passed rules/core.md to
# become the largest single contribution to the session payload. Excluding the `## Done` archive
# bounds nothing, because the active section is the part that grows.
#
# Streams come out ordered by their `touched:` date, newest first, until the ceiling. What did not
# fit is named by count rather than dropped in silence, so a session knows to open the file.
#
# `--titles` emits one line per active stream, name and touched date only, for the session-start
# digest. The full slice is 8KB of bodies against a 10,000-character cap on the whole injection, so
# what a session start can afford is the index, not the content; /catchup reads the file itself.
#
# Usage: tracker-slice.sh <file> [max-bytes]
#        tracker-slice.sh --titles <file> [max-bytes]
set -uo pipefail

titles=0
if [ "${1:-}" = "--titles" ]; then titles=1; shift; fi

file="${1:-}"
max="${2:-10240}"

[ -n "$file" ] && [ -r "$file" ] || exit 0

if [ "$titles" = 1 ]; then
    awk '
        /^##[ \t]+Done[ \t]*\r?$/ { done = 1 }
        done { next }
        /^## / { if (name != "") print date "\037" name; sub(/^## /, ""); name = $0; date = "0000-00-00"; next }
        name != "" && /^[ \t]*-[ \t]*touched:/ {
            if (match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/))
                date = substr($0, RSTART, RLENGTH)
        }
        END { if (name != "") print date "\037" name }
    ' "$file" 2>/dev/null | sort -r | awk -v max="$max" -F'\037' '
        {
            line = "- " $2 " (touched " $1 ")"
            if (used + length(line) + 1 <= max || kept == 0) { print line; used += length(line) + 1; kept += 1 }
            else dropped += 1
        }
        END { if (dropped > 0) printf "- (%d more; read the file)\n", dropped }
    '
    exit 0
fi

# A block is a stream and everything under it. US separates the sort key from the body and stands in
# for newlines inside it, so one stream is one line and `sort` can order them by date.
awk '
    /^##[ \t]+Done[ \t]*\r?$/ { done = 1 }
    done { next }
    /^## / {
        if (name != "") print date "\037" body
        name = $0; body = $0; date = "0000-00-00"
        next
    }
    name != "" {
        body = body "\037" $0
        if ($0 ~ /^[ \t]*-[ \t]*touched:/) {
            if (match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/))
                date = substr($0, RSTART, RLENGTH)
        }
        next
    }
    { header = header $0 "\n" }
    END { if (name != "") print date "\037" body }
' "$file" 2>/dev/null | sort -r | awk -v max="$max" '
    {
        i = index($0, "\037")
        body = substr($0, i + 1)
        gsub(/\037/, "\n", body)
        size = length(body) + 1
        if (used + size <= max || kept == 0) {
            print body
            used += size
            kept += 1
        } else {
            dropped += 1
        }
    }
    END {
        if (dropped > 0)
            printf "\n(%d older stream(s) not shown; read .polaris/work/streams.md for the rest)\n", dropped
    }
'
