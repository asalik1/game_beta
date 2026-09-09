# Pocket trial HUD clarity

September 9, 2026. Native, suite and preflight validation passed.

The pocket arena repeated its name in the location header, boss bar and rule
card, while the campaign objective pointed back to Brann outside the arena.
An empty ordinary objective still drew a diamond; a count-only objective
started with a separator. Victory and Renown plaques could cover the portal
prompt even though the local card and event feed already carried the feedback.

## Change

The real current pocket room uses its local rule card in place of the campaign
tracker. Ordinary room entry restores the existing campaign/count line.
Empty objectives hide their label and glyph; count-only objectives keep their
monster count without a leading separator. Campaign state and threat counts
are unchanged.

The card headings are FLOOR HAZARD, TRIAL RULE and POCKET SPOILS. Exact phase,
countdown, bottle-seal, class-healing and return instructions remain unchanged.
The location and living guardian's boss bar keep their names. The pocket guardian message uses
the existing event feed without requesting a duplicate plaque.

Local Renown grants likewise use the existing feed for the currency amount
and account-first hint. The amount, color, positive-value/local-player guards,
account balance, first-hint flag and write order are unchanged. The short hint
now reads “Spend Renown on skins in the Wardrobe.” The Wardrobe has a real
Renown skin purchase path. This removes an obsolete chroma promotion; it does
not remove legacy cosmetic machinery or claim that every historical reference
has been retired. Other achievements and award plaques retain their behavior.

## Baseline and fixture correction

The first desktop run stopped after seven images: its readiness predicate
required both the short-lived feed and a delayed guardian plaque. A second,
observational run confirmed the actual +15 Renown reward and correct arena.
The +15 Renown plaque and first-award hint queued ahead of the guardian; the
feed appeared correctly and expired before the guardian plaque was displayed.
Both failures remain in build/qa and are excluded from accepted runs.

The corrected helper retains the eight-second deadline and waits for the
exact victory feed row and Label to be visible at alpha at least 0.95. It
records guardian queued/active/visible state separately and still requires the
real finite feed before actual return input. It neither reconstructs messages
nor clears or extends their lifetime. Its detailed receipts retain all active
plaque geometry and feed rows for independent review of the Renown change.

Desktop baseline2 passed 161 strict checks with 23 images across three cases.
Its 36 presentation rows include 31 failures; those findings are expected in
baseline mode. Actual keyboard interact and mouse Return succeeded three times.
The first transient frame shows the Renown plaque covering the portal prompt;
a later reentry frame shows the delayed guardian plaque covering it too.
These are different moments, not a claim that the guardian was visible during
the first live-feed return.

## Focused after checks

Both desktop Forward+ and host mobile Compatibility runs passed 197 checks,
with all 36 presentation probes passing and 23 native fullframes each. All
three return interactions succeed on each renderer and keep their original
campaign/reward/completion behavior. The new first-award hint fits the existing
feed; the pocket guardian message remains visible there. Native review and
an external audit of all active-plaque rectangles, not just the helper's
guardian-only overlap predicate, establish the tested portal clearance.
This does not promise clearance against every unrelated game announcement.

## Broader regression

Original optional_discovery mode also passed on desktop and host mobile:
209 checks, four cases and 44 fullframes each. It covers pocket and Unlisted
active/defeated/reentry states with campaign marks both false and true, named
Atlas/Journal records and real map-button input. The two runs are bound in
checkpoint35-discovery-receipts.json; they are separate from the 92-image
focused ledger. All 180 accepted-run PNGs decode at native 1280 by 720.
Final visual reviews remain separately linked in checkpoint35-validation.json.

## Validation scope

The optional mode reuses the existing optional_discovery rig and real seeded
Molten Court and Still Larder rooms, portals and guardian death dispatch.
Actors are posed/frozen; phase snapshots use apply_state and death uses
deliberate overkill. Entry/reentry use the existing menu-button signal fixture.
Return uses actual bound keyboard E plus mouse, or ScreenTouch Act and Return.
No normal combat, physical-device or remote-party coverage is claimed.

The complete mode contains four ordinary-copy fixtures, seven active phase
views and four victory/return/reentry views per case, totaling 23 fullframes.
Rewards, campaign flags, quest state, fog, completion, bottle rules, restored
campaign text and no extra reward/respawn remain strict. Original optional
mode without --pocket-ui supplies the separate Atlas/Journal regression.

Commands and fresh build/qa profile requirements are in tools/INDEX.md.
Production is canonical game/ and mirrored to mobile/game/; new helper UIDs
are generated independently. Final native reviews, source freezes and strict
suite/preflight receipts will be recorded in checkpoint35-validation.json.

## Checkpoint gates

Desktop compile226/quick125/full205 and mobile import/compile226/strictquick125
passed. The two native modes explicitly compile their rig as well (228 scripts).
Both projects were reimported after publication; all 16 frozen source, grass
and helper-UID paths remain exact. Six desktop/mobile source pairs match byte
for byte, with independently generated helper UIDs. Full preflight passed without findings. The checkpoint uses 17 explicit paths.

The desktop full suite retains its intentional invalid-base64 diagnostic and
ObjectDB shutdown warning. Native desktop runs retain established renderer
texture/RID shutdown messages; mobile native runs have no such errors in these
logs. No SCRIPT ERROR or freed lambda capture occurred. Passing verdicts do
not imply every log is empty or that fixture wall time measures performance.

The six accepted native runs contain 180 reviewed fullframes. Before/after
focused reviews and both discovery reviews are preserved under build/qa,
along with the two native ledgers, failed early attempts, source freezes and
checkpoint35-validation.json. The checkpoint includes only explicit canonical
source/mobile mirrors, the optional QA helper/rig and documentation. Earlier
scratch and future candidates remain outside it.
