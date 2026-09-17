# Skills allocation touch layout

Touch Skills navigation tabs and attribute/substat +1/+5 controls use a
44-unit minimum target in the game's virtual viewport. Desktop controls keep
their compact dimensions. The change is scoped to these controls; the shared
widget theme and talent/ability allocation rules are unchanged.

Spending refreshes the existing stat sheet and highlights changed values while
preserving both columns' scroll offsets. The refresh waits for layout and
checks the exact menu shell before restoring, so a closed or replaced page
cannot receive stale offsets. Ordinary reopening starts at the top. The zero
point heading reads "All spent" on one line, avoiding a list-height jump.

## Validation

Use the existing muted, compile-gated dossier rig with isolated APPDATA:

```powershell
.\shot.bat hud_dossier --skills-touch --touch --scroll-retention --skills-extra --timeout=240
.\shot.bat hud_dossier --skills-touch --desktop-sizes --timeout=240
```

Add `--mobile --renderer=gl_compatibility` to the touch scenario for mobile
source running on the host. This is not physical-device ergonomics testing.
The baseline uses `--baseline --touch --scroll-retention` without `--skills-extra`.
Baseline1 reproduced 23 undersized targets and an 82-to-0 lower-row scroll reset
with 170 checks and no unexpected errors. Four original screenshots also show
the old zero-pool heading wrapping and moving the list down 32 pixels.

The fixture borrows seven attribute points without awarding XP or levels.
Geometry inventory explicitly reveals each row; separate real edge taps and
ScreenTouch/ScreenDrag gestures check spending, final-row reachability, no
spend during drag, clamping and exhausted-control behavior. The extended run
checks a nonzero right-sheet offset, actual close/reopen navigation and other
Skills tabs. The shell-replacement race is a controlled direct rebuild, clearly
separate from the input sequence. Player allocation, derived stats, previews,
HUD cache and input-emulation state are restored.

Evidence, rejected attempts, source pins, visual reviews and final acceptance
are recorded under `build/qa/session-sept17/skills-*`, including
`skills-touch-checkpoint-validation.json`. Prototype1 is an import-only canceled
run after an edit precondition failed before writes; it is not game validation.
Prototype2 passed quick 145/native 170, with all four after images inspected.
Natural leveling, every class description, all Skills controls, physical
hardware and two-peer transport are outside this focused fixture's claims.

Prototype3 adds the extended checks: 250 pass, with seven native views.
Its right column stayed at 32; the clamp-aware oracle did not exercise a
maximum-scroll boundary. Final desktop/mobile receipts supersede prototypes.

The first final desktop control rejected an incorrect QA assumption that both
allocation buttons were 42 units wide. Pre-change baseline measurements show
+1 at 42 and +5 at 43 (both 27 tall); the corrected oracle pins those exact
separate widths. The rejected final1 logs and images are retained.

Final2 passes desktop quick/full145/225, focused touch250, desktop compact162,
readiness192 and dossier560. Mobile compile279/strict quick145, touch250,
readiness192 and dossier560 pass, as do exact four-path synchronization and
full strict preflight. All71 final native originals received independent visual
review; root inspected39 originals across baseline, prototypes and final runs.
Mobile uses Windows Compatibility with emulated touch. Default dossier party
shells are synthetic and its loopback host is empty; this is not remote-peer
replication evidence. Existing allowed shutdown warnings remain in the logs.
