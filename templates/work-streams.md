# Work streams

<!-- The Polaris work tracker for this project. Surfaced at session start; updated by /track. -->
<!-- Keep active and blocked streams at the top. Move finished ones to the Done archive. -->

## ref' — Referral feature

- domain: feature
- status: active
- state: API contract and schema done; the invite email is drafted but not wired.
- next: wire the invite email to the send-invite action and cover the expired-invite case.
- files: src/features/referrals/, supabase/migrations/2026...referrals.sql
- touched: 2026-07-15 (built the contract, started the email)

## bug-checkout — Checkout total wrong on multi-item carts

- domain: bug
- status: blocked
- state: reproduced on carts with a discounted item; root cause looks like a rounding order.
- next: unblock once the pricing spec question is answered, then fix the rounding at the source.
- files: src/utils/cartPricing.ts
- touched: 2026-07-14 (reproduced, waiting on the pricing decision)

## Done

- <closed streams get a one-line record here, then are dropped once no longer useful>
