# Party identity readability

Checkpoint 19: desktop compile/quick/full, mobile import/compile/strict quick, scoped mobile synchronization and seven-category strict preflight pass. Native desktop and host-mobile each pass 232 party-name, 64 paired UI and 149 party-pause checks, plus existing appearance and controller regression rigs. All 124 final original screenshots were independently reviewed, including 15 opened by root. Exact frozen source hashes, reports and limits: `build/qa/session-sept20/party-names/checkpoint-validation.json`; final commit and local state: `commit-receipt.json` in that directory.

Party-card names occupy a finite 164px region and world names a finite 160px region, using native clipping/ellipsis while retaining the complete identity in `Label.text`. World names remain centered near their projected position and bounded horizontally by the viewport. Names, network identity, saves, HP values and downed-state data are not shortened or rewritten. This does not resolve overlapping allies or redesign revive plaques and departure announcements.

A 44px-high party-card target opens a read-only **Ally** reader with the complete name and class in wrapped 16px text. Mouse, raw touch and mouse-emulated touch work in the validated fixtures for both host and guest readers, including downed allies. Controller access to this reader is not provided. The world continues running; this is not a pause or general keyboard-input lock. Party-owned popovers close when their identity disappears/changes or the party HUD hides/resets. Existing menu opening also closes HUD popovers. Party hide/reset leave an unrelated, untagged HUD popover alone.

The native mode extends the existing runner:

```text
shot.bat brewing_persistence --party-names --timeout=450
```

Use fresh isolated APPDATA inside a `brewing-persistence-candidate` directory. The flag is exclusive of `--party-pause` and `--ui-only`; their existing checks remain separate regression gates. Add `--mobile --renderer=gl_compatibility` for host-rendered mobile sources. The mode runs one actual ENet host and three guest worlds, assigns short/16-wide/64-character names before joining, checks transported identities and measured card/world containment, poses viewport-edge/downed cases, and restores fixture save bytes. The 64-character names stress the network envelope; ordinary character entry is capped at 16. These are controlled fixtures, not ordinary typing, earned combat/revival, physical-device testing or persistence-roundtrip evidence.

Access checks capture first-visible and settled reader geometry, complete body text, single persistent opening, native dismissal and unchanged identities/resources. Input-leak witnesses sample intents, dialogue, MP and cooldowns over physics frames with god mode disabled; there is no positive talk-callback sentinel. Held-touch lifecycle checks release an already-owned joystick and ability while the reader is open. The ability uses an explicit cooldown guard: release/pulse cleanup and duplicate-release protection are observed, **not an actual ability cast**. Hide/reset coverage invokes the real methods as controlled fixtures; the final stale-peer case closes a real isolated ENet transport and waits for departure. Same-peer name/class replacement is source-reviewed, not independently exercised.

Retained evidence is under `build/qa/session-sept20/party-names/`. `old-code-v1` had 30 failures: 18 name/edge defects and 12 overly strict whole-HP-Control enclosure checks. The corrected `old-code-v2` retained all 18 genuine failures (81 checks, 63 passing); exact HP values/fills and native ink remained readable. `pilot-v1` was rejected (219 checks, 12 failures): mouse opening immediately dismissed through generated touch. Root reused the inventory original-device event rule; pilot-v2 passes all 232 checks, with 20 original images retained. Final validation uses the same four party-name source hashes. The separate appearance rig now waits up to 15 seconds for the actual ENet handshake predicate; final-v1 retained its premature 0.7-second handshake failure. The next compile gate caught a helper-name collision with another inherited fixture; its rejected log is retained in final-v2, and the final helper has an appearance-specific name. None of these failures is an acceptance waiver.

Actual Claude implementation inputs/outputs and independent corrections remain in `party-name-candidate/`; actual DeepSeek QA requests/responses remain in `party-name-qa-candidate/provider/` and `provider-correction/`. The first DeepSeek attempt exhausted its output on reasoning; the second implementation required independent syntax, transport-oracle and lifecycle corrections. Raw drafts and all rejected originals remain intact. Established renderer RID/RenderingServer shutdown diagnostics and suite ObjectDB exit warnings remain in retained logs; runner verdicts are preserved. The final native departure view retains a separate known defect: an extreme unbroken name can clip in the announcement and truncate before its consequence in the compact event feed. No announcement redesign or general UI approval is claimed.


The subsequent announcement-wrapping checkpoint sizes the actual parented
Labels before their first draw, so the complete 64-character departure notice
fits its plaque. Its separate strict reward fixtures also cover unbroken and
mixed detail text and title/detail separation. Compact-feed truncation was
resolved September 28 (see the end of this file). A same-name rejoin now takes
back a queued or showing "left the party" plaque on the host and on sibling
guests, while the event feed keeps the line (live `--party-names` departure
phase and the quick-tier reward feedback check). See WARD_VIGILS.md,
“Complete long announcement text,” and
`build/qa/session-sept20/announcement-wrap/checkpoint-validation.json` for the
new source-bound validation and its limits. The checkpoint-19 native
frames described above remain unchanged historical evidence.


## Complete downed and revive status

Checkpoint 21 keeps the complete DOWNED countdown, GHOST label and REVIVING label/bar within the viewport when the ally's projected feet are visible. The late placement pass preserves clear authored head positions and moves obstructed marks to the nearest available position clear of the visible HUD, ally names, selected interaction prompt and earlier marks. It measures existing native controls and works after tracker/prompt layout. It does not change health, bleed-out or channel timing. Offscreen feet use the existing party arrows rather than a second clamped status label.

If an unusually small or crowded viewport offers no valid position, the status retains the viewport fallback and records a no-fit flag. This is not a universal overlap guarantee or a redesign of overlapping ally names. The normal center, four edges, four offscreen directions and a touch-control edge case are controlled poses across four real ENet worlds. Countdown and channel data are explicit display fixtures, not an earned revive. The original party identity/input/lifecycle checks remain intact. Mobile screenshots use mobile sources with Compatibility on the development host, not a physical device. Arbitrary zoom/viewport sizes and dynamic tracker reflow are not separately stress-tested; no performance benchmark is claimed.

Evidence remains under `build/qa/session-sept20/down-mark/`. The original code fails 13 of 359 checks. The viewport-only pilot passes those checks but native review rejects fixed-HUD collisions; stronger QA demonstrates 11 failures in 414 checks. A second implementation retains three interaction-prompt envelope failures, and native review catches a relocated status underneath an ally name. Those rejected reports and originals remain intact; the accepted run uses independent post-draw native geometry and visual review rather than a waiver.

Actual Claude supplied the initial bounded viewport implementation; its later correction request timed out without usable code. Independent integration added HUD/name clearance. Actual DeepSeek supplied initial and strengthened QA drafts, corrected independently before integration. Raw requests, responses, timing and reviews are retained in `down-mark-candidate/` and `down-mark-qa-candidate/`. Established renderer shutdown and suite ObjectDB diagnostics remain visible in logs.

Desktop compile/quick/full, mobile scoped sync/import/compile/strict quick and all seven strict preflight categories pass. Both renderers pass 445 party-name/down-mark, 560 HUD dossier, 64 paired UI and 149 party-pause checks. All 152 accepted originals were reviewed, 17 by root. The new names-hidden clear-center control verifies exact authored anchors with no obstructing names; the three earlier center-anchor assertions now belong to this explicit phase. Ordinary center verifies visible identity/status separation. Exact sources, retained attempts, review receipts and limits: `build/qa/session-sept20/down-mark/checkpoint-validation.json`; commit and local state: `commit-receipt.json` there.


## Clear allied world names

Checkpoint 22 places visible ally names before downed/revive status, sharing the same final painted HUD reservations. Names retain their full identity, native ellipsis, tint and opacity; their complete outlined boxes move to the nearest free position clear of the fixed HUD, selected prompt and earlier names. The status pass then reserves around those final name positions. Every draw starts from a fresh world anchor, so displacement cannot accumulate. Unobstructed interior names retain their authored position. Existing offscreen eligibility and party arrows remain in use.

The bounded solver has an explicit no-fit fallback; this is not a universal overlap guarantee for arbitrary viewport sizes or crowds. Labels can move away from the actor to clear an obstruction. In the touch-right fixture, the downed text can move above the minimap while its name remains below it, and revive status can move to the bottom edge; grouping actor, name and status is unresolved. These controlled views establish text readability, not unambiguous body/name association during ordinary crowded combat. Controller access to the full-name reader and arrows overlapping HUD remain separate issues. Queued departure notices are now taken back on rejoin (see above), and compact-feed truncation was resolved September 28.

Actual Claude supplied the production implementation and actual DeepSeek supplied the expanded QA, with raw requests/results in `party-overlays-candidate/` and `party-overlays-qa-candidate/`. Independent review corrected authored-anchor details, QA placeholders, restoration and transport geometry before integration. No protocol, economy, combat, art or identity value changed.

The QA-only baseline against unchanged checkpoint-21 production reports 624 checks with 16 failures, all new name-clearance predicates; every previous 445 predicate remains passing. Baseline originals and rejected reports are retained. Two new views compare separated and colocated transported allies. Independent native control geometry checks visible identities, full outline bounds, HUD clearance and pairwise separation across the previous edge/status phases. Temporary actor poses and settings are restored. The tests do not use production placement helpers or no-fit metadata as an oracle.

Desktop compile/quick/full, mobile scoped sync/import/compile/strict quick, and all seven strict preflight categories pass. Both renderers pass 624 name/status, 560 HUD dossier, 64 paired UI and 149 party-pause observations. All 156 accepted native originals were reviewed, 13 by root. Mobile is host-rendered Compatibility, not a physical device. Real ENet transport uses controlled poses/status displays; no ordinary earned revive, persistence roundtrip, arbitrary zoom/viewport stress or performance benchmark is claimed. Known renderer shutdown and ObjectDB diagnostics remain in raw logs. Exact pins, reviews, preserved baseline and limits: `build/qa/session-sept20/party-overlays/checkpoint-validation.json`; local commit/state: `commit-receipt.json` there.

## Complete compact-feed lines

September 28: bottom-left event-feed rows wrap instead of ending in an ellipsis,
so a 64-character departure keeps "left the party" and the Depths camp guidance
keeps its last sentence. Rows wrap at word boundaries and are never cut short.
A one-line row keeps its 20px pitch and a wrapped row adds only its extra lines.
The stack keeps its existing gap above the control hints, never grows past a
140px budget, and in co-op wrapped rows never climb into the party chat lines;
the oldest rows retire first when it would. Party chat anchors to the screen
bottom while the feed keeps a fixed y, so on a taller mobile canvas (16:10, 3:2,
4:3) the chat sits beside or below the feed: there it never costs the five
classic one-line rows. Coalescing and fades are unchanged. Checks:
`shot.bat hud_dossier --reward-plaques` views `15_compact_feed` and
`16_feed_chat` (plus the tall-canvas chat cases), and the quick-tier reward
feedback test.
