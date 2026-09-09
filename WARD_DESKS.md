# Crownfall ward boards — pass 30

The capital's four contract desks promised Wildfang, Choir, Accord or
Cinderborn contracts but opened the generic Quests page. The Archive also
uses the generic journal action and should keep that destination.

## Reproduction

Starting production source: `1ed0831`, September 9, 2026. A new shared-`ShotRig`
scene uses the real generated city, positions the hero at its actual hotspot,
and presses ordinary keyboard Interact. `build/qa/ward-desks-baseline2.log`
records all four desks opening `tab=quests ward=`; Archive opens Quests as
intended. The run takes six correctly encoded Forward+ captures and exits 1
for the four reproduced findings. The earlier baseline log records a fixture
Label/String error; it is retained and is not evidence of the game defect.

Captures: `build/qa/ward-desks-baseline2-user/Godot/app_userdata/Crownless/shots/ward_desks`.
No production change was present during the baseline. No external save was
used: the runner has isolated APPDATA and the rig uses `no_saves`.

## Implemented behavior

Each desk opens its own filtered Activities board using the existing contract
objects and payout rules. The board offers all four wards and the combined
Activities page, states the shared daily allowance on this hero, shows current
standing and exact gold/favor rewards, and stays on the chosen ward through
claims and live refreshes. The Archive keeps Quests; the Wildfang moot remains.

Daily choices, reward amounts, board ownership and save schema are unchanged.
The exact favor quote uses the same existing resonance multiplier and rounding
as favor payout; the displayed base five can actually pay four, five or six.
No new artwork or chroma work.

The city-map service descriptions now read actual NPC and landmark actions,
including each ward desk, rather than inferring a contract from a decorative
map mark. The capital generator's four references and known-action list match
the generated data; unrelated generator prose was not regenerated.

## Validation

Desktop quick and strict mobile quick both passed 123 checks; the full desktop
suite passed 203 checks with the strict exit-code/log verdict. Desktop and
mobile ward rigs each passed eight captures; the desktop run uses keyboard
Interact and GUI clicks, while mobile uses actual ScreenTouch events for Act,
ward selectors, claim and All activities. Desktop Forward+ and mobile
Compatibility each passed the real ENet ward module with nine captures.

The ENet module checks exact personal rewards and home-save ownership, shared
daily choices, live room credit while reading, level/resonance/standing/favor
refresh, focus and scroll preservation, yesterday's retained callback after
rollover, and watcher teardown. Assertions restore fixture state and exact
save bytes on every returned result. All runs use isolated APPDATA; no player
save is used. Mobile here means the mobile project and renderer on the
development host, not a physical phone test.

The existing real-ENet Activities regression also passed thirteen captures:
ready badge, exact quote/payout, stale callback, touch, personal save, live
progress, daily rollover, party travel and disconnect ownership. The relevant
41 ward/Activities images were reviewed, including the updated Codex notes.
The deliberately seeded unfinished 1/1 row in the travel fixture is documented
in the Activities review; normal progress updates completion together.

Evidence is under `build/qa/ward-desks-*`, including the source freeze,
explicit 34-path stage list, independent UID pairs, suite counts and two
visual reviews. Twelve source mirrors are byte-identical; three new UID pairs
were minted independently. Windowed ENet runs retain the established renderer
texture shutdown messages. The full suite retains its malformed Fangmoot-code
negative-control diagnostic and RefCounted/timer teardown warning. No script
errors or strict RID-leak verdict failures occurred in the passing headless
runs. Earlier fixture failures remain in the logs; the Label/String baseline
read and WeakRef type inference were corrected before the passing runs.

Full preflight passed without findings (imports, modules, balance, physics,
rigs, art QA and Codex data). The checkpoint is titled **Open capital ward
boards with accurate rewards**. Its post-commit identity/status is recorded in
`build/qa/ward-desks-checkpoint.json`; no push or merge is part of this pass.
