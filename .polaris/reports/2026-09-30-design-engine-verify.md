# Design engine verification

Date: 2026-09-30. Run: audit-0930. One adversarial verifier (polaris:verifier) against nine claims,
each run rather than read.

| Claim | Verdict | Action |
|---|---|---|
| 1. inject-design wired and emitting design-core; session-start unchanged apart from one index line | holds | none |
| 2. inject-standard routes design core to ui, ux, feature-builder only | holds | none |
| 3. check-patterns `unless` safe, other languages unchanged | holds, with 6 ui false positives and one false negative | outline-removed moved to the judgment pass; viewport-height, zoom-disabled, div-click tightened; `tests/fixtures/clean-ui-edges.tsx` pins each false positive |
| 4. design flow and experience phase walk through run-state and the gates | holds | none |
| 5. design routing steals no prompts | broken: 12 misroutes (questions, bugs, backend) | class moved after bug and conversation, patterns tightened; 21 prompts checked, 6 added to routing fixtures |
| 6. review.js design gate, build.js critique | holds; an unrendered critique looped through bug-fixer | an unrendered critique now passes as `unrendered` in the build result; ui slices are fixed by ui, not bug-fixer |
| 7. agents, floors, no stale skill names | holds | none |
| 8. docs match code | holds, except the routing `_why` | `_why` corrected |
| 9. suite exits 0 | holds | still exits 0 after the fixes |

Known cost, accepted: a backend-only feature or foggy run now stops at the ux `experience` phase
for an approval, even when its evidence is "no user-facing surface".

Not verified: GNU grep, the Windows branch of run-hook.cmd, the real workflow runtime (mocked).
