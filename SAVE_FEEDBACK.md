# Character-save feedback

Implemented and validated on desktop and mobile-project Compatibility. The
checkpoint scope is character-save feedback in the controlled fixture below.

## Behavior

A failed character-file write shows an amber notice: **Saving failed.** It tells
the player that recent progress is still unsaved and suggests checking free
space or access to the save folder. The warning stays visible across ordinary
menu changes and paused scenes. It has no timeout while that character's save
remains failed.

The next successful write for the same local character and active slot changes
the notice to green **Progress saved.** for four seconds of monotonic time,
including while paused. Ordinary successful saves create no notice. An export
to another slot cannot clear the active character's warning; replacing the
local character or active slot clears its old presentation.

The presenter reads the result of the existing atomic write in `SaveGame.write`
and `SaveGame.write_character_home`. Guest/endgame character saves retain the
existing home-world routing. Skipped autosaves do not manufacture a save result:
the existing no-saves, restore, duel, invalid-slot, non-playing and dead/downed/
ghost gates still apply. Dedicated world saves, account meta, settings and stash
writes are outside this character notice.

The notice reports persistence only. It adds no retry, save button, rollback,
new durable state or changed save cadence. A completed brew can remain in the
live session after its save fails; the warning does not undo or repeat the
transaction. Recovery is shown only after a later actual successful write.

## Placement

The notice is independent of the gameplay HUD and menu shell, and does not
consume mouse input, focus or pause control. At the standard 1280×720 viewport,
gameplay and ordinary dialogue use a compact upper-right three-line warning.
Ordinary menus use one line across the top. Fangmoot board/playback uses the row
immediately below its top bar, including final playback before Continue; hub
and result screens use the ordinary menu row. Recovery uses the same footprint.

The intended tradeoff permits overlap with a little decorative title/frame
chrome in tall menus. Readable text, dismissal/action targets and the tested
HUD controls still require native clearance. This is not a guarantee for every
possible viewport, menu, boss cast or future HUD arrangement.

## QA commands and limits

The fixture writes real isolated character files. Always use the prepared
runner's fresh APPDATA under a `save-feedback-candidate` directory; do not run
it against normal player saves. From the worktree, its native command is:

```powershell
shot.bat save_feedback --placement-modes --timeout=180
```

The absent-presenter baseline adds `--baseline`; its separate exact external
ledger decides which missing-notice observations are expected. Strict after
runs omit that flag. The rig's baseline flag by itself is not acceptance.
For the mobile-source check add `--mobile --renderer=gl_compatibility`. This
fixture forces desktop controls on the host; it does not prove touch input or
physical Android/iOS behavior.

The sequential baseline and after templates are under
`build/qa/session-sept10/save-feedback-candidate/`:

- `checkpoint-preparation-quick144/README.md` requires the actual committed HEAD
  and explicitly reviewed current journey-inventory SHA before preparing the
  source-frozen baseline. Only its four native QA files are installed first.
- `checkpoint-after-template/README.md` consumes an accepted baseline and its
  full-image review before composing the revised production alternative. It
  runs desktop compile/quick/native/full, scoped mobile sync/compile/quick/native,
  strict preflight and closing source/preservation checks.

The validated source is the revised production alternative followed
by `save-feedback-bool-fix/production.patch`, which adds the required explicit
`bool` type to `same_owner`. The alternative replaces the original production
candidate; do not combine the two base patches.
The after sync contract selects six game-relative paths and requires six actual
files checked. Project-local UID files are not copied between projects.

The native test covers actual Alchemy mouse input and exact session costs under
a real owned empty `.tmp` directory obstruction; unchanged file bytes on failed
writes; same-slot recovery versus other-slot writes; writable skipped-autosave
controls; a posed guest-home save; warning/recovery readability, expiry and
placement; and restoration of isolated files and fixture state. The placement
extension uses the real Fangmoot builders with a non-granting host and a posed
final turn, including actual Continue input. It does not play a normal match.

Acceptance requires the complete strict report, all ten original images per
project reviewed at full size, clean wrapper exit, exact source boundaries and
confirmed cleanup. Missing reports, runtime errors, failed geometry or expired
early-window observations remain failures. Loaned resources are not ordinary
gathering proof. This does not test real guest ENet, full-disk/final-rename faults,
immediate-quit protection or crash durability.

## Validated checkpoint

The actual post-Party baseline on `e2bb7d4f8397496262f553080ac21e8bf4186333`
completed 105 observations: 53 strict passes, 52 exact absent-notice findings and
zero unexpected failures. Root and independent review cover its ten originals.
The bool-corrected after run passed 118 strict observations on each project,
with no findings or failures; root and independent image reviews cover all
20 after originals. The expanded geometry checks require complete readable
notices once the presenter exists.

Desktop quick/full passed 144/224; mobile quick passed 144. Both imports and
ordinary/native compile gates passed at 260/262 scripts. All 27 sequential
stages and strict seven-category preflight passed. Closing checks preserve
486 desktop/490 mobile runtime sources, the six exact mirrors, project-local
UIDs, all 46 unfinished/unrelated files and 235 material controls. All isolated
file variants and owned temporary obstructions were restored or removed.

Evidence is under `build/qa/session-sept10/save-feedback-candidate/`:

- Baseline: `checkpoint-e2bb7d4f8397496262f553080ac21e8bf4186333/baseline-1/`.
- Validated after: `checkpoint-after-template/preparations/e2bb7d4-bool-fix/after-1/`.
  Its preparation SHA starts `8ffca4e6`; it includes the revised base patch plus
  the one-line explicit-boolean amendment.
- The preceding
  `checkpoint-after-template/preparations/e2bb7d4-baseline1/after-1/`
  production attempt remains rejected:
  import could not infer `same_owner`. The strict log contract stopped it before
  quick/native/mobile execution; a zero editor-import exit did not override
  that error. Its closing source proof and rejection records are preserved.

Final accepted image/source receipts under `build/qa/session-sept10/` are:

- `save-feedback-root-review/bool-after1-final.json` — SHA256 `19c01a00208924d21510ed9b4dc2574b65597a5905aaec2fe0f98ed2f43f8873`.
- `save-feedback-independent-review/desktop-bool-fix-after1.json` — SHA256 `a521fe1cd70e15482f3f8403f9d5403457ca780f67f0789e787e2207864321d3`.
- `save-feedback-independent-review/mobile-bool-fix-after1.json` — SHA256 `5e50dfa34b542c8c7a3ede5792d4a12fa9c579546c8de5719509dfe9f87c88cf`.

The posed long-HUD view retains separate existing fountain/quest and
achievement/boss-readout overlaps. This checkpoint accepts notice placement;
it does not establish that those other HUD families are universally clear.
