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

## First-clear allocation guidance

The one-time Chapter 1 lesson now directs players to Skills > Talents and
Attributes without assuming they have exactly one unused talent point. The
owner-required trigger after the first combat-room clear, replay/guest guards,
completion flag and Talents callback are unchanged. There is no new point grant
or mandatory allocation.

Controlled native QA uses the existing dossier:
`shot.bat hud_dossier --onboarding-guidance --timeout=180` with isolated APPDATA
under build/qa. Add `--touch --mobile --renderer=gl_compatibility` for host-rendered
mobile source. The fixture lends legal level 3 progression and spends through
production allocation APIs to leave 2/2, 1/1, 0/0 pools. Actual Space/mouse or touch
reveals/advances the reader and visits the Attributes tab. It checks full copy,
visible geometry, unchanged pools/flags, Talents callback and cleanup. Seven
images per platform need manual review. This is neither an earned clear nor
physical-device testing; early portrait-level cache can reflect pre-fixture
level until the next normal HUD update.

The old sentence produced exactly three copy findings in 23 checks; all other
controls passed. Evidence and final gates are recorded in
`build/qa/session-sept17/guidance-checkpoint-validation.json`. DeepSeek v4-pro
provided the implementation candidate and helper; source corrections and the
lean refactor are attributed in the preserved candidate provenance.

A separate save-enabled fresh Warrior expedition on checkpoint 14 cleared the
actual 12-enemy first pack with ordinary input, reached level 2 / XP 34, read the
original lesson with2 talent / 1 attribute available, and spent Heavy Cleave +1 and
STR +1 through the actual UI. Its audit stopped on a gold mismatch after closing
Skills: primary save 88 gold, later live 91 after a visible +3 pickup. The saved level,
XP, point budgets, allocations and teaching flag match. This supports a harness
timing error, not a save-loss conclusion. Original exit 1 / audit-incomplete evidence
is retained; no return-home, reload, or retry is claimed. The temporary helper
and wrapper hook were archived and removed byte-exactly. The earlier failed Mage
and Fangmaw brewing experiments remain unchanged.
