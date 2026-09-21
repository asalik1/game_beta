# Purchase clarity

Validated checkpoint 12, September 21, 2026. Exact commit and local state are
recorded in `build/qa/session-sept20/purchase-clarity/commit-receipt.json`.

Alchemy and Professions use the existing gold formatter for prices, purse
balances, paid receipts and relevant tooltips. Grouping makes values such as
150,000 easier to read. Material counts, mastery and numeric transaction rules
are unchanged. Domain-generated failure messages retain their existing format.

Learn blueprint, Cash out, Enter trial and Buy skin confirmations use the shared
gold primary text color in their normal state. Destructive confirmations retain
the existing coral default. Cancel and single-action notices stay neutral.
Hover/focus still use shared button styling; this is not a new theme or a claim
of semantic differentiation in every pointer state.

Actual DeepSeek supplied both private implementation drafts. Root and a peer
reviewed the four-file change and retained raw outputs under
`build/qa/session-sept20/confirmation-action-semantics-candidate/` and
`build/qa/session-sept20/bench-money-formatting-candidate/`. The separate proposed
palette-constant QA was not integrated: existing real caller, layout and economy
checks cover the behavior without duplicating the theme implementation.

## Validation scope

Use the established compile/quick/full and strict preflight workflows, scoped
mobile synchronization, and fresh isolated profiles for the existing native rigs:

- `menu_navigation --confirm-layout`: actual primary and destructive callers,
  full copy, safe initial focus and native cancel/confirmation behavior.
- `profession_lifetime`, plus separate `--workshop-preview`: complete wider
  labels, purse/recipe geometry, retained callbacks and actual paid ledgers.
- `alchemy`: complete recipe/cost text, actual blueprint confirmation, paid
  actions, optional source scrolling and first/settled continuity.
- `brewing_persistence --ui-only`: paired local ENet quote/input/world guards.

Host Compatibility rendering and emulated touch are not physical-device tests.
Resources are controlled loans, not ordinary progression. Buy skin uses the
same primary option and receives source review, but no actual Buy skin dialog
capture is claimed. Existing wardrobe browsing fixtures do not open it.

Fresh evidence belongs in `build/qa/session-sept20/purchase-clarity/`. Previous
checkpoint logs and images do not approve this candidate. Optional Sources edge
clipping, secondary text contrast and rail/footer alignment remain separate work.

## Accepted result

Initial compile/quick plus all 18 remaining serial stages passed: full campaign,
two strict preflights, scoped mobile synchronization/import/compile/quick, and
both renderers' native runs. Each renderer passed 260 confirmation, 28 workshop
preview, 1,043 Professions, 563 Alchemy and 64 paired local ENet UI checks.

Root inspected 14 originals and a peer inspected 18, with overlap. Review was
representative of the changed price and action states; not all 122 emitted
originals were individually inspected. No new overlap, monetary truncation or
incorrect normal action color was found in those views. Known renderer shutdown
and suite cleanup diagnostics remain classified by the existing verdicts.
`checkpoint-validation.json` binds source, logs, reports, original images and
review evidence. All 46 unrelated files and the old session status tail remain
unchanged. This checkpoint is local; the session remains active.

A later Sources reading-view candidate has actual Claude implementation and a
DeepSeek QA adaptation under `alchemy-source-reading-candidate/`. Neither is
included here. Its first Claude attempt timed out; the successful focused
attempt and independent corrections remain retained. Apply only its patches,
never its older full source copies, to preserve the price and color changes.
