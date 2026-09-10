# Selecting the intended potion slot

The assigned tile in Inventory → Potions now resets the slot selected. With
Mana in both slots, selecting slot 2 produces [Mana, Health]. The old callback
removed the first matching type and instead produced [Health, Mana].

Only that tile's callback changes, to the existing slot-index operation.
The bag popover's type-level Remove from loadout callback and the two domain
operations remain unchanged. Health remains the default; default → empty →
default behavior is preserved. Selecting a tile does not drink a bottle,
refill the current room budget, change cooldowns or grant resources.

## Native checks

Use the frozen execution-ledger runner with an actual phase-specific source
manifest and fresh isolated APPDATA. The native episode is:

```powershell
shot.bat menu_navigation --potion-slots --timeout=300
```

The absent-fix baseline adds `--baseline`. Its exact contract allows only the
mouse and touch second-duplicate-slot plan findings; strict after allows none.
Each run requires all 94 ordered rows, ten real mouse clicks, ten emulated touch
taps, complete restoration and four full 1280×720 originals. The controls also
cover unique slots, default/empty behavior, exact stored rotation and unchanged
stock, economy, room allowance and cooldowns. The existing compact Reset button
(33px high in these captures) is a setup control, not a touch-target improvement.

Default `menu_navigation` remains a separate 158-row/eight-image regression.
After runs require that route on both projects, desktop quick/full, scoped
three-file mobile sync/import/quick, strict preflight and closing source/UID/
46-file preservation checks. Add `--mobile --renderer=gl_compatibility` for the
mobile project on Windows; do not force `--touch` in this combined-input episode.
These are host-rendered mouse/emulated-touch checks, not physical phone results.

The fixture is a paused, no-save chapter-three warrior with four loaned bottles,
a partly spent room allowance and a positive potion cooldown. Cleanup restores
borrowed values before unpausing, then restores outer input/settings state.
This does not prove ordinary gathering, brewing, drinking, room refill, durable
saves, ENet or the separate active-bottle fallback. The bag's Remove callback
is source-preserved rather than exercised by a new native action here.

## Accepted checkpoint

The accepted corrected baseline on `513ce942f8ff3b5e2f7fb6179758d861b1933d5c`
passed 92 of 94 observations with exactly two intended findings and no failures.
Root and independent review cover all four originals. All nine stages passed,
including quick 144 and exact closing sources/UIDs/preserved files.

An earlier attempt remains rejected: its ledger read nonexistent `Player.flags`,
causing script errors, empty preservation snapshots and an absent restoration
row (93 observations). The QA successor reads `Game.flags` and deep-copies the
`Player.tree_points` Dictionary. These two expressions strengthen the ledger;
they do not change the 94-row contract or permit additional baseline findings.

Evidence is under `build/qa/session-sept10/`. The accepted baseline is in
`potion-slot-selection-execution-ledger-candidate/runs/513ce942f8ff3b5e2f7fb6179758d861b1933d5c/baseline-1/`;
its reviews are `potion-slot-root-review/ledger-baseline1.json` and
`potion-slot-selection-independent-review/ledger-baseline1.json`. The rejected
original stays in `potion-slot-selection-execution-candidate/runs/` with its
source closure, logs, raw engine streams, report and images intact.

The separate after-1 run passed all 94 Potion rows and all 158 default-menu
rows on both desktop and mobile, with no findings or failures. Root and
independent review cover all 24 full originals (four Potion and eight menu
images per project). All 32 pipeline stages passed: desktop quick 144/full 224,
mobile quick 144, scoped three-file sync, strict seven-category preflight and
closing source/UID/preservation checks. These checks bind the tested pre-commit source on parent
`513ce942f8ff3b5e2f7fb6179758d861b1933d5c`; the final commit boundary is recorded
in `build/qa/session-sept10/potion-slot-checkpoint-validation.json`.

The final run is the adjacent `after-1/` lane. Accepted full-image and closing
reviews are `potion-slot-root-review/after1-final.json` and
`potion-slot-selection-independent-review/after1.json`.
