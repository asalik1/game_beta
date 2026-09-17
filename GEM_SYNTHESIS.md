# Equipped gem synthesis

September17 refinement, validated on desktop and host-rendered mobile.

Auto-synthesize follows the existing vessel limits: C2, B3, A6 and S10. In
Crownfall it upgrades eligible equipped gems first, consuming two matching bag
gems. A capped vessel is skipped before consumption; another eligible piece can
still upgrade. Bag triples can merge beyond the equipped vessel's limit. On the
road only bag synthesis is available. Existing over-cap sockets remain intact
without further upgrades; this does not migrate saves or refund old consumption.

Inventory copy explains the cap and uses 'No available gem upgrades' for a no-op.
The socketless-item explanation correctly starts socket grades at C. Bag cards
respectively explain matching socket/grade limits and explicitly say maximum
gems cannot be synthesized further; they no longer ask for impossible upgrades.

Touch scrolling turns descendant controls into PASS targets. The equipment row
now ignores presses inside its sockets, so filled sockets open their gem card and
empty sockets open Gems without the parent replacing either with Info. Events can
still reach the scroll container, including drags started over a socket. Emulated
mouse and raw-touch fallback use one stream. The raw-emulation-off control covers
the existing item body; raw-touch-only socket activation is not claimed.

The isolated test_gem_synthesis_caps.gd domain case covers regular/special caps,
legal boundary upgrades, exact ingredients, other vessels, same-kind cascades,
newly reached limits, bag merges, road policy, the level10 achievement, and
unchanged legacy/unknown-grade data. Native QA reuses:

```text
shot.bat gems --synthesis-caps --timeout=180
```

Use a fresh APPDATA under build/qa; add --mobile --renderer=gl_compatibility
--touch for host-rendered mobile source. Legal equipment/materials are lent;
actual mouse/ScreenTouch input performs synthesis and opens cards. Capital and
road use real world rebuilds as direct setup. No earned progression, ordinary
travel, save persistence, remote replication or physical-device claim. Cleanup
restores owned character fields, not prior world node identity or every transient.

Before-source baseline1 reproduced exactly C2->3/B3->4/A6->7 with two ingredients
consumed and higher attack:25 checks, three findings, six reviewed native images.
Rejected/partial attempts, including stale QA traversal, whitespace/coordinate
oracles and the initially insufficient raw-touch guard, remain preserved. Trace1
records the actual socket-to-parent event route. Fix2 passed38 touch checks;
final4 added the empty socket control. Its visual review found misleading max-level
copy; the actual before-copy Ruby10 bag card is retained with exactly its focused
assertion and fixture failing. Final5 corrects the real bag card and showcase,
adds max-card acceptance, names the unchanged two-gem ingredient cost in Balance
after strict preflight flagged the moved literal, and reruns all required gates.

Final5: desktop quick146/full226/native36; mobile compile282/quick146/native40;
nine focused images and two default-showcase images per platform; strict
preflight and exact seven-source sync. All22 final originals independently reviewed.
The showcase's old missing menu root is repaired. An initial
review-preview impression of missing empty labels was rejected after inspecting
original-resolution files and a magnified crop; all names are present. Popup placement follows the
cursor, so the dismissal test measures its real bounds. Notice text is asserted
before popups open; screenshots may cover it. The legal S9-to-S10 upgrade is recorded numerically; the separate maximum bag
card uses lent Lv10 gems. Evidence, source/image hashes and actual commit:
`build/qa/session-sept17/gem-caps-checkpoint-validation.json`.
