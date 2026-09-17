# Combat readability

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

Source review found separate host overhead-bar omissions in Vampiric attacker
healing and some Boss self-heals/reset paths. Those remain follow-ups; this
change only corrects the full-health guest state presenter. A separate candidate
places ally damage text 30px lower on guests and still needs reproduction.
The large target HUD uses actual HP and its existing damage trail is deliberate.
