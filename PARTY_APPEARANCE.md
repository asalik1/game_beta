# Party Appearance — validated and staged

September 8, 2026 · MP-25 · codex/crownless-wayfinder · no commits.

Friends now see each other's equipped skins and companions. Join blocks carry
validated cosmetic identity. A reliable, change-only sampler updates it live;
the host retains the latest identity for late joiners. Each remote owner has
an independent follower using the existing eight-frame art and follow/stride
behavior. Local menus pause the local follower while remote companions keep
moving with their owners in co-op. Ghost/dead owners hide their companions;
revive, unequip, owner replacement, travel and disconnect clean up correctly.

The wire accepts known pet IDs and skins belonging to the admitted class,
including the existing legacy warlock skin alias. It drops unrelated fields.
Remote presentation never grants unlocks, changes local selections or writes
saves. Chromas are scrapped and excluded. NET_VERSION is 0.3.13. No art changed.

Live QA found and fixed a freed-object Dictionary cast during world rebuild:
check the Variant before treating a freed follower as a Node. A regression
contract reproduces immediate world destruction and rebuild, plus ownership,
dead/ghost/downed visibility, unequip and unregister behavior. The mobile
same-ID test now waits for observable cleanup: its original fixed delay could
end after replacement but before queued deletion at the end of that frame.

Validation:

- Desktop import/compile: 192 scripts; quick: 115 checks; full: 195 checks.
- Mobile import/compile: 192 scripts; strict quick: 115 checks.
- Ten desktop and ten Compatibility/mobile captures with actual ENet checks:
  joins, live skin/pet changes and actual sprite clips, late roster, owner
  movement packets, rest/warp, independent menu clocks, ghost/revive, unequip,
  same-ID replacement, chapter advance, touch menus, account/home preservation,
  transport disconnect and fresh-ID reconnect. Thirteen completion checks.
- Original companion motion: 28 captures, including real follow/stop and touch.
  Original menu previews: 12 desktop and 12 mobile captures; animation,
  purchase/equip/return, hidden/clipped clocks and cleanup pass. Three series
  have pixel-identical static menus outside the moving preview slots. An
  apparent omission in repeated-image inspection was not present in the PNGs.
- Source preflight: zero failures, 16 existing warnings (11 source lines
  verified against the original index; five existing companion anchor warns).
  Engine Codex data: 80 enemies / 22 boss kinds, DATA OK.
- Fifteen frozen source mirrors and three independent UID pairs match.
  The original staged index was verified unchanged before this pass.
- Screenshot verdict: 18 fixtures pass. Unexpected engine errors fail even
  after DONE/exit0; the established renderer shutdown diagnostics remain
  printed and exempt. Compatibility GL details require the matching exit RID
  report. Headless suites retain their stricter resource gate.

The live rig uses two complete games and a lightweight third roster reader in
one muted engine. It exercises production RPC/spawn/relay/movement after ENet
connect, not lobby admission/auth. It is not a hardware or multi-process claim.
The lightweight reader is hidden so it cannot draw extra test bodies in the
playable views. The preview rig explicitly waits for a completed draw to capture.

Evidence: build/qa/party-appearance-*.log, party-appearance-parity.json,
party-appearance-menu-pixels.json and screenshot folders
party-appearance-desktop, party-appearance-mobile,
party-appearance-companion-motion, party-appearance-companion-previews and
party-appearance-mobile-companion-previews. All saves used isolated APPDATA.

Next: Road Choices. Actual audit and implementation notes are in
build/qa/road-choice-audit.md and build/qa/road-choice-implementation.md.
