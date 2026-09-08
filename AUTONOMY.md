# Crownless — autonomous improvement pass

Branch: `codex/crownless-wayfinder`, continuing from the Wayfinder update.

- [x] Combat responsiveness: retain short taps across physics ticks and brief
  cooldown boundaries; explain rejected casts on the HUD.
- [x] Combat readability: directional damage feedback and a recent-damage
  record that helps explain a defeat without delaying recovery.
- [x] Comfort settings: adjustable camera motion and screen flashes, optional
  hit-stop; preserve default game feel.
- [x] Equipment decisions: legible comparisons, sorting, protected gear and
  accurate feedback for equip/sell/drop actions.
- [x] Broader audit: reward conservation, overflow-loot ownership, stale merchant
  callbacks, readable enemy mechanics and touch layouts.
- [x] Integrated desktop/mobile tests, real-renderer review, documentation.

Existing economy, story progression, networking authority and authored art
remain the foundation. New controls must work with touch and co-op overlays.
No review checkpoint is required to continue this pass.

## What changed

**Combat:** short taps now survive between input and physics updates and across
the final 180 ms of a cooldown. Mana, freeze, class lockouts and cooldown rules
still apply. A failed cast explains itself. Pending casts clear on menus,
dialogue, loss of focus and defeat; touch holds still explain instead of casting.

**Enemy decisions:** the current target can announce reflection, a counter
stance, a heal that can be interrupted, a pounce, an exposed window, a breakable
ward or Cinderhide's plating. Reflection takes priority over an exposure hint.
Co-op guests receive the host's cue in the existing 14-byte enemy packet,
including the initial spawn snapshot. No additional packet or AI runs on guests.

**Recovery:** damage bearings show the source direction of a landed blow.
Pause → Combat report shows recent damage or the last fall, with the source,
damage type, actual HP lost and HP remaining. It excludes fully shielded hits
and overkill, and preserves a fall through recovery for this character session.
It does not force an extra screen between the player and another attempt.

**Comfort:** camera shake, movement lead and impact flashes are adjustable.
Hit-stop and damage bearings can be disabled independently. Defaults preserve
the existing feel. Test/preview sessions no longer write real settings when
`no_saves` is enabled.

**Equipment:** bag and shop inspections compare the same slot in a stat table,
including upgrades, gems, losses and passive differences. Keep a piece to protect
it from individual/bulk sales, dropping and automatic replacement; the star
survives saving. The bag can be ordered by grade, slot, kept pieces or discovery.
Refusals and successful equipment actions are visible inside the menu.

**Audit fixes:**

- Coin splits preserve the complete rolled reward; zero gold makes no coin.
- A pickup cannot pay twice while its deferred deletion is pending.
- Identical overflow drops retain separate ownership; claiming one cannot
  remove the other's saved ground-loot record.
- Ground-loot scatter is checked against collision after scattering, and the
  resolved position is what saves.
- Re-equipping an already worn piece cannot duplicate it into the bag.
- Merchant callbacks recheck item identity, ownership, bag capacity and money.
  Gear, gems, consumables, materials and loose-bag sales reject stale actions.
- Stash transfers recheck ownership, preserve kept gear, and show their result
  inside the panel. Repeated deposit/withdrawal events cannot copy an item.
- Gear sale quotes and collected-gold notices include the player's Greed bonus.
- Touch pause actions have 44 px targets and scroll when a party adds actions.
  Tall item benches reserve space for their header and controls.

## Validation

- Desktop compile gate and full suite: **PASS**, 174 reported checks, including
  all seven chapter paths, later content, endgame, co-op overlay contracts and
  the new regression checks. Final log: `build/qa/full-autonomy-final.log`.
- Desktop/mobile source parity: **PASS**, 273 scoped files with no unexpected
  mobile-only files. Mobile import, compile gate and quick gameplay suite:
  **PASS**, 93 reported checks including input/gear/loot/stash/network cases. Logs:
  `build/qa/import-autonomy-mobile.log`, `compile-autonomy-mobile.log` and
  `quick-autonomy-mobile.log`.
- Real-renderer rig: **PASS**, 18 captures reviewed for combat cues, recovery,
  equipment, merchants, stash, desktop and touch layouts. Final log:
  `build/qa/visual-autonomy-final.log`.
- Preflight: **PASS**, zero failures. Five balance-lint warnings are structural:
  the three-bit cue maximum and milliseconds-to-seconds conversions. Engine
  data audit: **PASS**, 80 enemies and 22 boss kinds. Logs:
  `build/qa/preflight-autonomy-final.log` and `preflight-data-autonomy-final.log`.

`shot.bat autonomy --no-import --timeout=240` exercises a real keyboard tap,
cooldown-boundary buffering, a live lethal hit and recovery, keep/buy/stash actions,
same-frame duplicate purchase, touch tap versus hold, and tactical cues. Images
are under `build/qa/autonomy-user/Godot/app_userdata/Crownless/shots/autonomy/`.
All test saves and visual sessions use isolated user-data directories.

Networking checks exercise the actual enemy packet encoder/decoder and mirror
state updates; they do not substitute for a live multi-client soak. Mobile checks
are headless plus rendered touch interaction/layout review, not an on-device
build. Existing invalid-code and ObjectDB shutdown diagnostics remain in the
passing suite. Windowed rigs retain the same texture-RID shutdown warnings
reproduced on the unchanged source snapshot; final runs have no script errors.

Run `run_game.bat` from this worktree. Combat additions are active immediately;
the new controls live under Pause → Settings → Combat & comfort. Inspect any
bag or shop item for comparison, and use Keep on pieces you want to protect.
