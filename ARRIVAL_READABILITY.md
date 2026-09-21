# Readable room arrivals

Live first visits show the room name over the same brief partial dim used by
revisits. Walking into an active encounter no longer starts a full fade from
black while its enemies are already simulating. Pocket travel and map travel
use the same live-entry classification. Boot, load, chapter rebuild, network
snapshot and respawn callers keep the ordinary default presentation.

The HUD separately owns its shared title animation and screen-overlay animation.
A replacement room or boss card cancels the previous label tween and resets
stranded position/scale. It leaves an existing fade alone. A new full arrival,
death dim, explicit dim or terminal screen takes over the overlay, cancelling
the previous overlay tween. Terminal text remains visible after an interrupted
card would have faded. Existing fade duration, partial-dim strength and title
hold are retained; the common title hold now lives in Balance.

No content, art, rewards, actor simulation, camera policy or save format changes.
The Codex has no new content entry to add for this presentation correction.

## Reproduction and checks

Use the existing muted, compile-first screenshot runner with fresh isolated
APPDATA below `build/qa/session-sept20/claude-shortcuts/`:

```
shot.bat shortcuts --corridor-camera --corridor-hot --arrival-readability --timeout=300
shot.bat shortcuts --corridor-camera --corridor-lazy --arrival-readability --arrival-rebuild-controls --arrival-ownership-controls --timeout=300
shot.bat shortcuts --solo-controls --arrival-readability --timeout=300
```

Add `--corridor-horizontal` for E/W crossings. Add
`--mobile --renderer=gl_compatibility` for the mobile project on the development
host. These are not physical-device tests.

The hot route retains real spawning, enemy AI and hero vulnerability; its source
clearance and initial pose are loans, not earned campaign progress. Lazy routes
use cleared rooms and a shortcut flag loan, checking first construction and
revisits through held native movement. Per-render observations record title,
overlay, body visibility and world identity without presentation writes during
the walks. Source presentation must settle first, and every new failure remains
strict. The passive boot observer stays connected through the deferred intro
completion and first playable draw. Solo controls retain their real slot 97
save/load and cleanup, with added full-fade and title observations.

Optional default-entry controls temporarily remove only current cleared-room
visited metadata and restore it. Ownership controls deliberately call production
HUD methods in overlapping sequences. They never erase built metadata or
reconstruct an already-built room. They test replacement title hold/transform,
an existing full fade, terminal text, death dim and cancellation. Their timing
uses scene timers, since PNG conversion can stall wall time without advancing
the scene equivalently. These are controlled presentation tests, not real
boss/death/victory flows. Re-entering the room also refills its ordinary potion
budget; the disposable fixture documents that side effect.

## Evidence and limits

Evidence is under `build/qa/session-sept20/arrival-readability/`; native episodes
live under sibling `claude-shortcuts/` to satisfy the existing profile guard.
The unchanged-production baseline fails the first-visit dim bound. A separate
hybrid negative retains the live-entry API but restores old untracked HUD
animations: it exposes disappearing replacement/end cards and a cancelled dim
returning. This hybrid is not the original-HEAD baseline or an accepted game.

Actual Claude supplied production and ownership-test drafts; actual DeepSeek
supplied the initial native observation draft. Root reviewed and corrected
them, retaining raw outputs and rejected attempts. Corrections include invalid
multiline lambdas, a boot observer detached before the deferred callback,
unsafe built-metadata erasure in an unaccepted draft, boss transform reset,
overlay ownership and timing against the scene clock.

Alpha measurements do not by themselves establish visual quality; originals
must be inspected. Existing chest/prompt/foliage overlaps and small secondary
labels remain follow-up. Network regression does not establish the live-entry
overlay policy on every guest path. Pocket/map callsite classification is
source-reviewed, not a claim of separate native interaction coverage. External
manual label resets in game_flow remain unchanged. Ordinary campaign play,
physical mobile testing and exact fade-duration/performance measurements are
outside this checkpoint's claims.

Final validation: desktop compile/quick/full, scoped mobile sync/import/compile/
strict quick, fourteen native episodes and all seven strict preflight categories
passed in `claude-shortcuts/root-arrival-final-v2` (22 stages). On each project,
hot S/E pass 20 each, lazy S ownership passes 80, lazy E passes 57, actual solo
save/load passes 38, and paired ENet passes 33. Defeat/recovery passes 30 desktop
and 26 touch/mobile checks. Final source pins match both projects.

All 178 original screenshots were opened: actual Claude read 154; root inspected
selected originals and directly reviewed the remaining 24 after both Fable and
authorized Opus max hit the same session limit. Those are explicitly root reviews,
not provider reviews. A mobile review mistook alphabetical filenames for capture
order and reported title oscillation. Root checked both flagged originals and
per-capture frame counters: each midcorridor frame precedes destination entry.
The raw finding remains preserved with a specific evidence-backed rejection.
One provider path typo was corrected against its exact proven Read image; the
original parsed advisory remains retained. Other mistaken prop/phase descriptions
are corrected in per-group dispositions. No native failure allowance was added.

Evidence: `arrival-readability/acceptance.json`; commit and local-state receipt:
`build/qa/session-sept20/arrival-readability-commit-receipt.json`. Known suite and
renderer shutdown diagnostics remain subject to the established verdict rules.
Small secondary labels, early fade-in subtitle contrast, chest/hero/prompt and
foliage overlap, transient minimap status and supplemental boundary HUD masking
remain. These frames do not establish whole-game visual quality.

The first final pipeline failed its controller-mode south return before reload.
It did not record end-state input or movement samples, so no cause is claimed.
Failure snapshots and per-poll movement observations were added without changing
the crossing predicate or eight-second timeout. A diagnostic run and a fixed
two-run repeat experiment passed; the eight traced crossings took 2.283–2.355 seconds.
The original failure remains preserved, not relabelled as a pass or fixed.
The final V2 run freezes the diagnostic additions and passes both desktop and mobile.
