# Combat readability

## Host enemy bars after self-healing — September 17, 2026

Eight missing refresh calls now keep revealed overhead bars consistent with
actual HP after six boss self-heals, boss fight reset, and a Vampiric attack on
the local player. Choir Mother's Hunger, Saint Varo's incense, Ordo's consumed
Sons, Sleepkeeper's Drowse, Gardener's compost and Kaethra's roots use the
existing shared fill/cap helper immediately after their existing HP changes.
Heal amounts, damage, timing, target HUD, network messages and visibility policy
are unchanged. A pristine full bar remains hidden; a previously wounded living
bar reaches full width after reset. The existing reset test checks this too.
No player-facing Codex change is needed for this presentation correction.

`shot.bat boss_cast --healing --timeout=180` adds a focused mode to the existing
isolated keep rig. It checks all eight production entrypoints with real wounds,
real add factories and healing methods. Each run has 103 assertions. The
`--baseline` contract requires exactly 18 named stale fill/cap findings; all
other prerequisites, HP math and negative controls remain strict. Vampiric
healing covers partial/full health, shield-only damage and death. Boss controls
cover absent censers/roots, actual dying compost, reset relocation/cast lifetime,
and pristine hidden bars. The baseline keeps an 80% boss overhead bar after
its target HUD reaches 88% and then 100%; the accepted source updates both.

Baseline1 is rejected for freeing a dead actor before its deferred death
accounting callback. The fixture now drains two frames before disposal.
Baseline2 and baseline3 reproduce the numeric defect but have a chest obscuring
the posed wolf. Baseline3's attempted loot cleanup did not solve that capture
and is removed from accepted source. Baseline4 moves the wolf clear of the chest
and lets transient text expire for settled-bar inspection. All failed/partial
runs remain preserved. Static scenery and HUD are retained in final captures.

The fixture is offline, no-save and controlled: actors are frozen, HP loss calls
production damage directly, support timing is forced, Sons/blooms are posed,
Drowse's accumulator is seeded, and Ordo borrows generic Morwen cast state only
to check reset cancellation. Ordo has no authored breakable signature here.
The minimum-level factory clamp produces a Lv2 wolf. The posed Son partly
overlaps Ordo before consumption; this is not full add-art acceptance. Temporary death XP/loot
callbacks may occur; this is not an earned encounter or reward test. Tiny
Drowse healing is numerical acceptance, not a visible-pixel claim. Native
captures cover Vampiric partial/full and Ordo consumed-Son/reset; they inspect
settled bars, not readability while callouts overlap. The posed quest monster
count is stale in this cleared fixture. Native mobile renders mobile source on
the Windows Compatibility renderer with touch disabled, not a physical device.

Desktop quick/full pass (145/225), mobile import/compile and strict quick pass
(145), and focused desktop/mobile runs pass 103 checks with zero findings.
The original boss-cast mode passes its live cast and real ENet regression with
nine screenshots. Exact five-path mobile synchronization and full strict
preflight pass. Root opened
all 45 native originals, including the rejected attempts; twelve baseline4/
strict frames have independent review. The original cast rig retains posed
actor/HUD overlap in some shots and fading prior-cast text; it is not new global
framing acceptance. Established shutdown renderer/RID diagnostics and the full
suite's intentional negative base64 diagnostic remain recorded.

Evidence, exact source pins and the final commit/preservation audit are in
`build/qa/session-sept17/host-healing-checkpoint-validation.json`.
A source review found no supported online encounter that assigns Vampiric:
endgame and Waking Incursions are solo-gated, and online-capable authored
affixes exclude it. Guest-owned-victim healing acknowledgment is a future
multiplayer-affix prerequisite, not a reproduced ordinary co-op defect. See
`vamp-authority-candidate.md` in the evidence directory.

## Guest enemy bars after full healing — September 17, 2026

An already-visible guest enemy overhead bar now reaches its full edge when
its authoritative HP returns to maximum. Previously, the target HUD correctly
showed 100%, but the small overhead fill and edge cap retained the last wounded
geometry. The state receiver now calls the existing `refresh_hp_bar()` helper
for living full-health samples. Untouched hidden bars stay hidden; death bars
stay hidden. The wounded-state path, gameplay HP, heal amounts, network format,
bar dimensions, colors and target HUD are unchanged. No Codex copy is required
for this presentation correction.

The paired reproduction uses `shot.bat guest_blink_enet --healing --timeout=180`
with isolated APPDATA beneath `guest-blink-enet-candidate`. It inherits the
existing two-reader ENet boot/admission and factory wolf/mirror flow. A real
factory Choir Cantor (`stormcult`) heals the authoritative wolf using the
production `_heal_pulse()` helper; only the host wolf is in its shared-tree
recipient group. The guest receives ordinary quantized HP state. Controlled
host damage leaves 71% HP, then three real pulses reach 81%, 91%, 100%.
The test checks host/guest fill, cap and visibility, pristine hidden bars,
repeated full packets, a later wound leaving 80% HP, actual replicated death,
and a separately labelled direct late-full-state presenter control after death.

`--baseline` requires exactly four named full/repeated-full guest fill/cap
findings; every other assertion stays strict. Baseline2 has 81 checks and no
unexpected failures. Both full rows retain the preceding partial fill
32.75294px and cap x13.75294 instead of 36px and x17. The first baseline has
seven framing failures from overlapping posed player bodies and is preserved
as rejected evidence. Separating the host pose by 120 world pixels resolves
those failures without changing the healer, target, packets or framing gates.

Accepted validation: desktop quick/full suites pass (145/225), mobile import,
compile and strict quick pass (145), and fixed paired healing passes 81 checks
with no failures/findings on both desktop and mobile source. Default guest
Blink passes its unchanged 47 checks. Exact three-path mobile synchronization
and full strict preflight pass. Root opened all 32 native originals across the
rejected baseline, corrected baseline, desktop/mobile healing and Blink runs;
14 baseline2/fixed desktop frames also received independent visual review.
The unchanged runners retain shutdown RID/texture/ObjectDB warnings; the full
suite retains its intentional negative base64 diagnostic. None was suppressed
for this checkpoint.

Evidence is under `build/qa/session-sept17/`.
`heal-bar-checkpoint-validation.json` records the actual commit, exact owned
scope, gates, source/evidence hashes and preservation audit.
`healing-baseline2-source.json` pins pre-fix source and
`healing-final-source.json` pins the accepted source. The 46 unrelated preserved
files remain byte-identical and excluded from the checkpoint.

### Scope and remaining candidates

This is a controlled transport fixture: actors are frozen, peer admission and
support timing are forced, and wounds/death call production damage directly.
It does not prove an ordinary healer AI encounter, input, balance, rewards,
persistence, moving co-op, packet loss or physical-device behavior. Death can
produce normal temporary XP/loot callbacks in its disposable no-save world.
Mobile checks render mobile source on the Windows host with Compatibility.
The final death screenshot may retain a fading corpse; immediate numeric
snapshots establish hidden bars. Very low HP cap thresholds and alternate
elite/Boss art are not new native acceptance claims.

The later host-healing checkpoint above addresses the separate overhead-bar
omissions in Vampiric attacker healing and Boss self-heals/reset paths. This
earlier guest checkpoint only corrects the full-health guest state presenter. A separate candidate
places ally damage text 30px lower on guests and still needs reproduction.
The large target HUD uses actual HP and its existing damage trail is deliberate.
