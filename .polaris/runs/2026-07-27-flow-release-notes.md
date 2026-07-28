# Flow run — release-notes maker

**Task:** a detailed release-notes maker with two audience modes (dev team/client, and product
audience), sourcing changes by diffing dev against main or by whatever release method the project
uses, inferring the ICP when the audience is users.

**Date:** 2026-07-27

## Timeline
| Phase 0 | intake — asked directly (human present, no proxy interview) | opus | output=file+offer to publish, source=auto-detect+confirm, modes=both, ICP=full researcher pass |
| Phase 1 | spec written to .polaris/specs/2026-07-27-release-notes-spec.md | opus | prose gate clean, awaiting approval |
| Phase 4 | implement — commands/notes.md written directly (one markdown file, no code) | opus | prose gate + check-commands clean, suite 41 ok exit 0 |
| Phase 7 | docs — README row and job note, CHANGELOG 1.6.0, both manifests bumped | opus | prose gate clean |
| Phase 5 | review — reviewer (correctness+simplicity vs the 10 criteria) | opus | 6 should-fix, 7 nits, no blocker; 6 should-fix applied, nit 10 rejected (it anchors AC7), nits 8/9/12 applied |
| Phase 6 | verify — ran step 1 commands against this repo | opus | all run; found and fixed my own off-by-one (--skip=49 gave 49 commits, now 50) |
| Phase 8 | ship — committed 87600a9 on main, not pushed | opus | guard hook clean |
| Phase 10 | report at .polaris/reports/2026-07-27-release-notes.md | opus | done |

## Outcome

Shipped: `/polaris:notes` committed as 87600a9 on `main`, not pushed, no PR (this project keeps work
on `main`). Spend: telemetry disabled; one reviewer dispatch, ~61k subagent tokens.
| Exercise | ran /notes on a3f41bd..HEAD — researcher (ICP) + tech-writer x2 | opus | two documents written; found broken relative commit links and padded empty dev sections, both fixed in the command |
