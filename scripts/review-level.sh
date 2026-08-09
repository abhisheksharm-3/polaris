#!/usr/bin/env bash
# The review level a changeset earns, from `git diff --numstat` on stdin.
#
# This file holds the spec's R3 table and is the only copy of those thresholds in the repo: prose
# elsewhere points here rather than restating them. First match wins. A caller passes the answer to
# `workflow:review` as `args.level`, because the workflow runtime cannot run a shell command itself.
#
# Auto-selection never returns `critical`: it differs from `high` only in confirm depth, so a human
# asks for it. Empty or malformed input prints an empty string and exits 0, which leaves the
# workflow on its own default rather than failing a review over a diff that could not be read.
#
# Usage: git diff --numstat | review-level.sh
set -uo pipefail

# A risk path is one where a small diff can still be the expensive one: data migration, auth,
# money, dependency and build inputs, infrastructure, and anything named for a secret.
is_risky() {
    case "/$1" in
        */migrations/* | */auth/* | */payment*/* | */billing/*) return 0 ;;
        */package.json | */package-lock.json | */yarn.lock | */pnpm-lock.yaml) return 0 ;;
        */requirements.txt | */go.mod | */Gemfile.lock | */Cargo.lock | */Dockerfile) return 0 ;;
        */.github/workflows/*) return 0 ;;
        *.tf) return 0 ;;
    esac
    case "$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')" in
        *secret* | *crypt* | *token*) return 0 ;;
    esac
    return 1
}

is_low_risk() {
    case "/$1" in
        *.md | */docs/* | */tests/* | *.test.* | *.spec.* | */__tests__/*) return 0 ;;
    esac
    return 1
}

files=0
lines=0
risk=0
all_low=1

while IFS="$(printf '\t')" read -r added deleted path; do
    [ -n "${path:-}" ] || continue
    files=$((files + 1))
    # A binary file reports `-` for both counts. It still touched a path, so it counts as a file.
    [ "$added" = "-" ] && added=0
    [ "$deleted" = "-" ] && deleted=0
    case "$added$deleted" in *[!0-9]*) added=0; deleted=0 ;; esac
    lines=$((lines + added + deleted))

    # A rename arrives as one entry naming two paths, either `old => new` or `dir/{old => new}/f`.
    # Both sides are judged, so renaming a file out of a risk path does not launder it.
    if [ "${path#*" => "}" != "$path" ]; then
        if [ "${path#*\{}" != "$path" ]; then
            pre="${path%%\{*}"; rest="${path#*\{}"; inner="${rest%%\}*}"; post="${rest#*\}}"
            set -- "${pre}${inner%% => *}${post}" "${pre}${inner##* => }${post}"
        else
            set -- "${path%% => *}" "${path##* => }"
        fi
    else
        set -- "$path"
    fi

    for p in "$@"; do
        is_risky "$p" && risk=1
        is_low_risk "$p" || all_low=0
    done
done

if [ "$files" -eq 0 ]; then printf ''
elif [ "$risk" -eq 1 ]; then printf 'high\n'
elif [ "$all_low" -eq 1 ]; then printf 'low\n'
elif [ "$lines" -le 40 ] && [ "$files" -le 3 ]; then printf 'low\n'
elif [ "$lines" -le 400 ] && [ "$files" -le 15 ]; then printf 'mid\n'
else printf 'high\n'
fi
