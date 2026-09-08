# Encounter Company — validated pass 25

Staged, uncommitted. All 24 earlier passes are preserved. No artwork or
network packet format changed; the compatible network build remains 0.3.14.

## Player changes

- Hunt, escort and ward objectives share a compact panel above the keyboard
  bar and between touch controls. The old escort/ward slot covered party
  health. Colors and integrity/resolve meters remain distinct.
- The panel fades to 12% when it covers the camera-transformed hero or current
  target, then recovers. Ordinary combat exposed this at a room edge; fading
  keeps the fight visible. Its timing lives in Balance.
- A room admits one optional fight at a time. Invitations explain the active
  encounter and disable conflicting starts. Host-side checks also reject
  stale clicks and direct guest requests; ending the fight releases the room.
  Hunt escape routes remain open.
- Guests receive new hunt discoveries and warning messages once. Late joins,
  repeated snapshots and older states do not replay historical discoveries.
- Hunt reward copy says Earn, separating the promised reward from the wallet.
  The minimap reports encounters and live threats even when their doors remain
  unsealed; it no longer labels a fighting quarry's room Sanctuary.
- Road Deck Field notes explain the shared encounter rule.

## Validation

Desktop import / compile 201 / quick 118 / full 198 pass. Mobile import /
compile 201 / strict quick 118 pass. Source preflight has 0 failures and 12
known warnings; the engine-backed Codex data gate passes. All 19 source
mirrors and five independent project UID pairs are verified.

The company rig reuses two complete games and production ENet APIs in one
engine. It covers guest discoveries, both fight orders, disabled invitations,
direct/guest request guards, released reservations, escort/ward party vitals
and touch clearance, panel fade/recovery, and open hunt exits. Its negative
control detects the original overlapping HUD position. Final desktop run has
8 captures; final mobile Compatibility run has 9, including controlled panel
coverage. The guest announcement capture now waits for readable opacity.

The original hunt, escort and ward regressions passed another 8 + 12 + 13
desktop captures. Invitations, combat panels and touch presentation were
visually inspected. Selected mobile evidence is retained under
build/qa/encounter-company-visuals.

Normal-input hunt probes use starting equipment, level 1, ordinary health,
real keyboard intents and god mode off. They never inject combat damage or
call abilities directly. Setup moves to the three signs. Warrior won in
37.6 seconds after a six-second observation period; mage won in 20.8 seconds
at 59.4/90 HP. The final mobile-source warrior won in 33.7 seconds, took a
real hit (minimum 113.4/130 HP), and recovered through normal class behavior.
Each earned 120 gold. Combat JSON includes sampled health, positions and
quarry health. These are bounded automated gameplay probes, not hardware or
human playtest claims. Prototype probes that over-kited melee range or withheld
all attacks are retained in logs; no game balance was changed to make them win.

The full suite retains its established malformed-Fangmoot-code diagnostic and
bare ObjectDB exit warning. Windowed runs retain only the known renderer
shutdown diagnostics admitted by the strict screenshot verdict. Mobile import
reports the existing missing Android build-tools directory; no device build
or hardware test is claimed.

## Evidence and continuation

Logs: build/qa/encounter-company-final-{quick,full,live}.log,
encounter-company-{hunt,escort,vigil}-regression.log,
encounter-company-mobile-{import,compile,quick,readable,combat}.log,
encounter-company-preflight.log, and hunt-combat-{warrior-contact,mage-trace}.log.

The final QA-only helper capture/opacity refinements were compiled and tested
in the last mobile live run; production source remained frozen after full QA.
Manifests: build/qa/encounter-company-{source-freeze,sync-paths,uids,stage-paths}.json.
The stage manifest contains 51 explicit paths. The baseline index is retained
as encounter-company-baseline-index.txt for preservation checks.

Next candidates: build/qa/caravan-followup-plan.md and
build/qa/hud-cover-followup-audit.md. Continue autonomously until the authorized
September 9 deadline, with a final stable checkpoint. Preserve staged work;
no commits, chroma development, off-limits hero art or original-worktree edits.
