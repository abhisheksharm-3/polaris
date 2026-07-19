---
description: Plan a large, foggy effort as a shared decision map of open questions, before any spec or code
argument-hint: "<the large effort to chart, or a ticket to work>"
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch
---

<!-- Adapted from mattpocock/skills (MIT): wayfinder -->

# Recon

Chart the effort in `$ARGUMENTS` as a decision map: the open questions that must be answered before
anyone writes a spec or a line of code. Recon runs before `/flow`. When the map is clear enough,
it hands the cleared result to `/flow` or to the `product` agent. Read `.polaris/config.json` first.

The map is where you look to see what is decided, what is open, and what is takeable next. It is an
index, not a store: the map links to tickets, the tickets hold the detail.

## The map

One file per effort, an index at `.polaris/work/recon/<slug>-map.md` (the slug from the effort).
Sections:

- **Destination** — one or two lines naming what "done" is for the whole effort.
- **Notes** — domain context and standing preferences that every ticket should honor.
- **Decisions so far** — a one-line gist per closed ticket, each linking the ticket and its answer.
- **Not yet specified** — the fog of war: questions you suspect exist but that are too dim to write
  as a ticket yet. Graduate them into tickets as they sharpen.
- **Out of scope** — what this effort will not touch, so the boundary stays explicit.

## Decision tickets

One markdown file per open question at `.polaris/work/recon/<slug>/NNN-<ticket-slug>.md`, numbered
in creation order. Each ticket names its type, which fixes who resolves it and how:

- **research** (AFK) — the agent resolves it alone, via the `researcher` agent or `/research`. Fresh
  docs, prior art, a feasibility read.
- **grilling** (HITL) — resolved with the human, via the `product` agent. The agent asks; the human
  decides. The agent never answers a grilling ticket for the human.
- **prototype** (HITL) — resolved by building the throwaway proof via `/spike`, then the human reads
  the result and decides.
- **task** (manual) — a prerequisite a human must do outside the map (grant access, buy a domain).

HITL means human in the loop: the answer is the human's, and the agent must not invent it. AFK means
the agent works alone and reports back.

Each ticket carries a `blocked-by: [NNN, NNN]` field (empty when nothing blocks it). A ticket is
unblocked once every ticket it names has closed. To work a ticket, claim it first: mark it claimed at
the top so two sessions never resolve the same one.

The **frontier** is the set of tickets that are open, unblocked, and unclaimed. That is the takeable
edge of the map. Everything else is either done, waiting on a blocker, or already being worked.

## The two modes

Read the map if one exists for the slug. No map yet means chart it; a map already there means work it.

### Chart the map (first run)

1. **Name the destination.** State what "done" is for the whole effort in one or two lines.
2. **Grill for breadth.** Dispatch the `product` agent to run a breadth-first pass with the human:
   what is fixed, what is open, what is out of scope. Go wide before deep; the goal is to find the
   questions, not answer them.
3. **Write the map.** Create the index file with the five sections filled from the grilling.
4. **Cut the tickets.** For every question sharp enough to specify, create a typed decision ticket.
   Leave the dim ones in "Not yet specified".
5. **Wire the blocking.** Set each ticket's `blocked-by` so the order of resolution is explicit.
6. **Fire the research.** Dispatch every unblocked research ticket as a background subagent; they are
   AFK and can run in parallel while the human is away.
7. **Stop.** Do not resolve grilling, prototype, or task tickets in this run. Charting ends here.

### Work the map (every run after)

1. **Load the map** and list the frontier.
2. **Pick one ticket** — the one the user named, else the first on the frontier.
3. **Claim it** before doing anything.
4. **Resolve it by its type:** research via `researcher` or `/research`; grilling via `product`;
   prototype via `/spike`; task by handing the human the exact step and waiting.
5. **Close it.** Write the answer into the ticket, mark it closed, and append its one-line gist to
   "Decisions so far" on the map.
6. **Grow the map.** Promote any question the answer sharpened out of "Not yet specified" into a new
   ticket, and wire its blocking.

Hard rule: resolve at most one ticket per session, so each decision gets full attention and the human
stays in the loop. Research tickets are the only exception, because they are AFK and cheap to batch.

When the frontier empties and no fog remains, the map is cleared: hand the destination, the notes, and
the decisions to `/flow` or the `product` agent to turn into a spec.

## Run log

Create `.polaris/runs/<date>-recon-<slug>.md` (the date from `date +%F`) at the start, holding the
effort, the date, the mode, and a `## Timeline` heading. As each ticket is cut, claimed, or closed,
append one line naming the ticket, its type, and the outcome. Append as you go. Close with an
`## Outcome` line: charted (N tickets open), one ticket resolved, or map cleared and handed to `/flow`.
