# Class preservation upscale pass

This pass restores the pre-2026-07-31 class identities at Paladin-grade source
density. It is an identity-preserving ImageGen edit, not a redesign and not a
filtered resize of the installed runtime PNGs.

## Binding references

- Warrior: `backup/warrior_base_pre_emberbound_heir_2026-07-31/warrior.png`
- Warlock: `backup/warlock_base_pre_ledgerbound_debtor_2026-07-31/warlock.png`
- Archer: `art_src/archer_severed_thread_ranger_production/archive_original_runtime_2026-07-31/archer.png`
- Assassin: `backup/assassin_base_pre_erased_name_2026-07-31/assassin.png`
- Mage: `backup/mage_base_pre_blighted_healer_2026-07-31/`

The archived class image is always the binding identity/design reference.
Current Paladin and Maren may be used only as source-density, material
separation, and small-size readability references. They must not contribute
identity, clothing, equipment, face, silhouette, or palette.

## Old-design runtime baseline restored

On 2026-08-01 the owner requested that every remaining class except Paladin and
Warrior return to its complete pre-redesign sprite family before individual
upscaling begins. `tools/art/revert_other_classes_to_old_strips.py` validated
the archived SHA-256 manifests, archived the currently wired redesign PNGs, and
restored the following exact source families without resizing or alteration:

- Archer: 83 PNGs from
  `art_src/archer_severed_thread_ranger_production/archive_original_runtime_2026-07-31/`
- Mage: 56 PNGs from `backup/mage_base_pre_blighted_healer_2026-07-31/`
- Assassin: 74 PNGs from `backup/assassin_base_pre_erased_name_2026-07-31/`
- Warlock: 65 PNGs from
  `backup/warlock_base_pre_ledgerbound_debtor_2026-07-31/`

The replaced redesign families are recoverable under
`runtime_pre_old_design_revert_2026-08-01/{archer,mage,assassin,warlock}/`, each
with `SHA256SUMS.txt`. Paladin, Warrior, skins, and the seven Mage plus two
Warlock projectile-only PNGs absent from the archives were outside the write
set and remain untouched.

The restored South idle first-frame body baselines are Archer 121 pixels, Mage
202, Assassin 104, and Warlock 104. Paladin and corrected Warrior remain 180.
These values intentionally reproduce the old-design starting point; subsequent
class-by-class work will raise Archer, Assassin, and Warlock to the 180-pixel
source standard while preserving these restored identities. Mage already
exceeds the target and is retained as its approved old design.

Godot reimported all 278 restored PNGs. `verify_art.py archer mage assassin
warlock`, the 97-script compile gate, and `test_quick.bat` all passed after the
rollback.

## Output contract

- Built-in ImageGen only; no PixelLab or external generator.
- One class and facing at a time.
- Flat removable `#00ff00` source background, locally converted to alpha.
- Exactly 180 visible source-body pixels in normalized standing poses.
- Gameplay comparison at approximately 88 visible body pixels.
- Preserve the archived silhouette, proportions, costume construction,
  equipment, handedness, palette, camera, and facing.
- Candidate sources stay under `art_src/`; runtime files are untouched until
  the owner explicitly approves the visual proof.

## Warrior south identity proof

Owner approved V02 on 2026-08-01 as the binding Warrior identity.

- `warrior/warrior_upscale_identity_s_v01_source.png`: first built-in ImageGen
  result. Rejected because it became too tall/narrow and simplified the ember
  wisps and some helmet/weapon cues.
- `warrior/warrior_upscale_identity_s_v01_keyed.png`: keyed rejected result.
- `warrior/warrior_upscale_identity_s_v01_180px.png`: normalized rejected
  result.
- `warrior/warrior_upscale_identity_s_v02_source.png`: built-in ImageGen
  correction using the archived Warrior as binding identity and V01 as the edit
  target.
- `warrior/warrior_upscale_identity_s_v02_keyed.png`: alpha-keyed V02 source.
- `warrior/warrior_upscale_identity_s_v02_180px.png`: V02 normalized to a
  180-pixel visible body on a 277-pixel transparent staging cell.
- `warrior/warrior_upscale_identity_s_v02_comparison.png`: archived identity,
  rejected V01, V02 candidate, and Paladin quality benchmark at 180-pixel source
  and 88-pixel gameplay sizes.

V02 correction prompt:

> Correct the high-density V01 Warrior to match the archived binding identity:
> restore the broader, stockier armored proportions, compact crowned black
> helmet and narrow orange visor, narrower flaming greatsword with a low
> cross-body diagonal and restrained ember wisps, original shoulder width,
> gauntlet bulk, chest harness, hip armor, boot stance, and silhouette. Preserve
> the black/dark-steel plate, ember-orange accents, fully enclosed face, neutral
> south-facing pose, and low top-down gameplay camera. Change rendering fidelity
> only; do not redesign or borrow another class's identity or equipment. Render
> as crisp premium hand-pixeled art on a perfectly flat `#00ff00` background,
> with exactly one complete figure and no shadow, text, crop, or extra anatomy.

## Warrior South walk candidate

Owner approved Warrior South V01 on 2026-08-01. It remains unwired until the
complete Warrior direction set is approved.

Built-in ImageGen generated `warrior/walk_s/warrior_walk_s_v01_source.png`
from two references:

- binding identity/rendering reference: approved Warrior V02;
- binding motion/cadence reference: archived six-frame `warrior_walk_s.png`.

The prompt required exactly six South-facing figures in one row and this
timeline: f1 left contact, f2 left load, f3 right pass, f4 right contact, f5
right load, f6 left pass. It locked the V02 armor, helmet, orange harness,
greatsword, palette, camera, proportions, and equipment through every frame,
required low ordinary steps and explicit f1/f4 opposite leads, and prohibited
mirroring, marching, redesign, extra equipment, and borrowed class elements.

`tools/art/build_preservation_walk_candidate.py` hard-keys and losslessly slices
the source only at broad zero-occupancy gutters, uses frame 1 to establish one
scale for the entire direction, normalizes to a 180-pixel visible source body
on a shared 277-pixel cell/baseline, and produces:

- `warrior/walk_s/warrior_walk_s_v01_candidate.png`: unwired transparent strip;
- `warrior/walk_s/warrior_walk_s_v01_contact.png`: labeled QA sheet with f1/f4
  contacts highlighted;
- `warrior/walk_s/warrior_walk_s_v01_9fps.gif`: source-size cadence proof;
- `warrior/walk_s/warrior_walk_s_v01_actual_size_9fps.gif`: approximate
  gameplay-size cadence proof;
- `warrior/walk_s/warrior_walk_s_v01_cuts.png`: lossless gutter audit;
- `warrior/walk_s/warrior_walk_s_v01_keyed.png`: keyed full source.

Structural QA: six frames; 49/58/53/54/50-pixel empty gutters; 277-pixel square
cells; 180-pixel frame-1 body; common baseline y=255; zero semi-alpha pixels;
transparent strip corners; GIF delay sequence 110/110/110/110/110/120 ms
(8.955 effective FPS, the nearest complete-loop timing GIF's 10 ms resolution
can represent for this six-frame 9 FPS target). Runtime remains untouched while
the complete direction set is assembled and approved.

## Warrior Southeast walk candidate

Built-in ImageGen independently generated
`warrior/walk_se/warrior_walk_se_v01_source.png` from the approved Warrior V02
identity and the archived six-frame `warrior_walk_se.png` direction/motion
reference. The prompt locked the front-right three-quarter facing through the
entire cycle, required travel toward screen-down-right, explicit f1/f4 opposite
contacts, ordinary low steps, and the complete low-carried flaming greatsword.
It prohibited mirroring, turning toward South/East/Southwest, redesign, and
borrowed class elements.

The generic preservation builder emitted the unwired candidate, keyed source,
lossless cut overlay, contact sheet, source-size 9 FPS GIF, and approximate
gameplay-size 9 FPS GIF under `warrior/walk_se/`. Structural QA: six frames;
71/88/90/92/97-pixel empty gutters; 277-pixel cells; one frame-1-derived scale;
common baseline y=255; zero semi-alpha pixels; transparent corners; and the
same 110/110/110/110/110/120 ms representable GIF timing. Runtime remains
untouched while Southeast awaits owner approval.

Owner rejected Southeast V01 on 2026-08-01 because it did not read as a real
walk: the feet popped between poses while the torso and sword appeared to
slide. V01 remains archived as rejected evidence and is not eligible for
installation.

Built-in ImageGen generated Southeast V02 as a targeted gait replacement. The
V01 row was the edit target for identity/facing/equipment only; approved South
V01 supplied same-class cadence reference only; approved Warrior V02 remained
the binding identity. The correction prompt required continuous anatomical-foot
travel through left contact -> planted load -> right pass -> right contact ->
planted load -> left pass, with explicit planted-foot holds, down/up pelvis
motion, subtle sword counter-sway, locked Southeast facing, and no skating,
foot teleporting, marching, mirroring, or redesign.

`warrior/walk_se/warrior_walk_se_v02_*` contains the complete unwired V02
source, keyed master, candidate strip, lossless cut audit, contact sheet, and
both 9 FPS review GIFs. Structural QA: six frames; 95/78/102/101/86-pixel empty
gutters; 277-pixel cells; one frame-1-derived scale; common baseline y=255;
zero semi-alpha pixels; transparent corners; and 8.955 effective representable
GIF FPS. Runtime remains untouched while V02 awaits owner review.

Owner approved Southeast V02 on 2026-08-01. Southeast V01 remains rejected;
V02 remains unwired until the complete Warrior direction set is approved.

## Warrior East walk attempts

Owner approved East V06 on 2026-08-01 with the explicit exception "good enough
even if choppy." It remains unwired until the complete Warrior direction set is
approved. Earlier East attempts remain rejected and ineligible for installation.

- V01 preserved the right profile but f1/f4 collapsed into the same visible
  leading-leg silhouette.
- V02 explicitly requested near/far leg depth but still repeated the same
  anatomical lead.
- Two-contact key V01 duplicated the lead; key V02 changed the second pose into
  an airborne passing pose; key V03 still failed to ground the forward far boot.
- An independently generated far-leg-forward contact was retained as diagnostic
  evidence, but comparison with the near-leg key showed the same underlying
  screen-space lead rather than a reliable opposite contact.
- V03 key-pose synthesis placed its intended opposite contact late at f5 and
  repeated it through recovery.
- V04 ImageGen-only second-half repair still repeated the same second-half leg
  lead.
- V05 used a subtle 10-degree frontward depth offset while remaining East, but
  f1 became a passing pose instead of a planted contact and the cycle still did
  not prove opposing leads.

The fallback preservation audit split the archived East strip into six
independent edit targets under `warrior/walk_e/legacy_targets/`. Visual
inspection showed that the archived motion itself does not contain two clean,
opposing planted contacts: its likely contact frames retain ambiguous/same-leg
ownership or feet-together poses. Faithfully AI-upscaling those poses would
preserve the defective walk rather than correct it.

All East `warrior_walk_e_v01_*` through `v05_*`, contact-key sources, and legacy
targets are archived as rejected/diagnostic sources only. None touched runtime.

After the owner requested continued attempts, the East V06 strategy extracted
the two owner-approved Southeast V02 contact frames without rescaling or
altering their pixels. Built-in ImageGen then rotated each contact independently
into East using the archived East strip for camera/equipment perspective and
approved Warrior V02 for identity. Those East contacts were supplied as binding
f1/f4 endpoints for a unified six-frame source generation.

`warrior/walk_e/warrior_walk_e_v06_*` contains the unwired V06 source, keyed
master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS GIFs.
Structural QA: six frames; 63/63/55/58/73-pixel empty gutters; 277-pixel cells;
one frame-1-derived scale; common baseline y=255; zero semi-alpha pixels;
transparent corners; and 8.955 effective representable GIF FPS. V06 was
initially approved under the noted slight-choppiness exception and installed in
the guarded Warrior walk pass. The owner reopened East after the in-game review,
so V06 is no longer final.

East V07 is a fresh built-in ImageGen eight-frame recovery pass. V06 supplied
binding identity/camera/equipment evidence and negative timing evidence; the
archived East strip supplied only old-design direction and restrained gait.
V07 adds distinct down, passing, and recovery beats between its two contact
halves while retaining the right-facing helmet, backpack on screen-left, sword
pointing screen-right, armor construction, and 180-pixel body source standard.

`warrior/walk_e/warrior_walk_e_v07_*` contains the pending V07 source, keyed
master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS GIFs.
Structural QA: eight frames; 39/28/35/42/33/34/31-pixel empty gutters;
277-pixel cells; one frame-1-derived scale; common baseline y=255; zero
semi-alpha pixels; transparent corners; and 8.989 effective representable GIF
FPS. The owner rejected V07 as too choppy. It never replaced installed V06.

East V08 follows the prescribed split-cycle fallback. Built-in ImageGen created
two independent four-frame half-steps from the previously generated East
Contact A and Contact B keys: contact, load, passing, and recovery for each
physical step. The second generation also used the accepted first half only as
upper-body rhythm, scale, sword-inertia, and rendering evidence. The two raw
halves were concatenated losslessly; no interpolation, mirroring, warping, limb
editing, or procedural animation was applied. The generic preservation builder
then used one frame-1-derived scale for the entire eight-frame direction.

`warrior/walk_e/warrior_walk_e_v08_half_a_source.png` and
`warrior_walk_e_v08_half_b_source.png` preserve the two ImageGen originals.
`warrior_walk_e_v08_*` contains the combined source, keyed master, candidate
strip, lossless cut audit, contact sheet, and both 9 FPS GIFs. Structural QA:
eight frames; 171/113/128/206/155/112/149-pixel empty gutters; 277-pixel cells;
180-pixel visible frame-1 body; common baseline y=255; zero semi-alpha pixels;
transparent corners; and 8.989 effective representable GIF FPS. The owner found
V08 better than V07 but still visibly jumpy rather than fluid. V08 is rejected
and did not replace installed V06.

East V09 is a surgical transition repair of V08 rather than another full-cycle
generation. Frames 1–3 and 5–7 are pixel-identical to the V08 candidate. Built-in
ImageGen generated frame 4 independently between V08 frames 3 and 5, and frame 8
independently between V08 frame 7 and the loop's next frame 1. This targets the
two half-step seams while preserving the accepted contact/load/pass artwork.
`tools/art/replace_preservation_walk_transitions.py` chroma-keyed and normalized
only those two new figures to the established 180-pixel body height, 277-pixel
cell, and y=255 baseline before splicing them into the unchanged grid.

`warrior/walk_e/warrior_walk_e_v09_transition_4_source.png` and
`warrior_walk_e_v09_transition_8_source.png` preserve the two ImageGen originals.
`warrior_walk_e_v09_*` contains the candidate strip, keyed/normalized replacement
proofs, contact sheet, and both 9 FPS GIFs. Structural QA: eight frames; only
frames 4 and 8 differ from V08; visible body heights 180/178/181/180/182/175/179/
180 pixels; common baseline y=255; zero semi-alpha pixels; transparent corners;
and 8.989 effective representable GIF FPS. The owner accepted V09 on 2026-08-01
as a suboptimal but passable East compromise. The guarded East-only installer
verified the live V06 pixel digest, archived it under
`warrior/walk_e/runtime_pre_v09_2026-08-01/`, and installed only the eight-frame
V09 `warrior_walk_e.png`. The other seven runtime directions were not written.

The owner subsequently authorized mirroring specifically for Warrior East and
requested that it use the approved West walk's mirror. East V10 is therefore a
literal per-frame horizontal mirror of West V03. The six 277-pixel review cells
were mirrored independently so frame order was not reversed; no AI generation,
interpolation, rescaling, or redrawing was used. The runtime installer verified
both live West V03 and live East V09, then mirrored each already-cropped
244-pixel West runtime cell directly. This makes installed East pixel-for-pixel
West's mirror without a crop-alignment discrepancy.

`warrior/walk_e/warrior_walk_e_v10_mirrored_west_*` contains the review strip,
contact sheet, and 9 FPS GIFs. The superseded V09 runtime is archived under
`warrior/walk_e/runtime_pre_v10_mirrored_west_2026-08-01/`. Only
`warrior_walk_e.png` was replaced; it is now six 244-pixel cells. Godot import,
`verify_art.py warrior`, compile, and `test_quick.bat` passed after installation.

## Warrior South idle candidate

The archived four-frame `warrior_anim_s.png` is the binding design, camera,
weapon-side, pose-order, and restrained-breathing authority. Built-in ImageGen
used that literal old-design strip together with the approved 180-pixel South
identity source to redraw the same idle at the preservation render density.
This is deliberately a planted breathing loop, not a new combat-ready stance.

`warrior/idle_s/warrior_idle_s_v01_*` contains the unwired ImageGen source,
keyed master, lossless cut audit, candidate strip, contact sheet, and both 6 FPS
GIFs. Structural QA: four frames; 192/187/187-pixel empty gutters; 277-pixel
cells; 180-pixel visible frame-1 body; per-frame visible heights 180/182/180/179;
common baseline y=255; zero semi-alpha pixels; transparent corners; and 5.97
effective representable GIF FPS. The owner approved South V01 and delegated
self-QA for the remaining idle directions on 2026-08-01.

## Warrior complete idle preservation set

Built-in ImageGen produced separate old-design V01 idle sources for Southeast,
East, Northeast, North, Northwest, West, and Southwest. Every direction used
its archived idle as the binding design/pose source and its approved 180-pixel
walk direction only as camera and upgraded-detail evidence. Each direction was
generated independently; no mirroring was used. Southwest deliberately corrects
the archived idle defect that raised the sword across the torso, keeping the
blade down-left for a true planted breathing loop.

`warrior/idle_{s,se,e,ne,n,nw,w,sw}/warrior_idle_*_v01_*` contains every built-in
ImageGen original, keyed/cut proof, candidate strip, contact sheet, and 6 FPS QA
GIF. Full structural QA passed: four frames per direction; 277-pixel review
cells; frame-1 body height 180 pixels; per-frame body range 177–182 pixels;
common baseline y=255; broad empty authored gutters; zero semi-alpha pixels;
transparent corners; and looping 160/170/170/170 ms GIF timing. Visual self-QA
confirmed stable camera, equipment sides, planted feet, restrained motion, and
old-design identity in all eight directions.

`tools/art/install_preservation_warrior_idles.py` archived the wired redesign
idles under `warrior/runtime_pre_idle_preservation_2026-08-01/`, then installed
only the eight `warrior_anim_<dir>.png` files plus the flat South alias
`warrior_anim.png`. Runtime strips are four 244-pixel cells with the 180-pixel
body grounded on row 239.

## Warrior archived attack restoration

The owner requested that attack and attack2 retain the archived old artwork and
timing rather than the redesign. No AI generation was used for these actions.
`tools/art/install_preservation_warrior_attacks.py` applies one frame-1-derived
scale to each archived seven-frame direction, targeting a 180-pixel opening
body while preserving every later pose and effect. A 288-pixel square runtime
cell retains the widest West blade sweep and the largest whirlwind arcs without
cropping. Hard alpha and common baseline y=283 are enforced.

`warrior/attacks_old_normalized/{attack,attack2}/` contains the normalized
candidate strips, contact sheets, and 22 FPS QA GIFs for all eight directions.
The prior redesign runtime attacks are archived under
`warrior/runtime_pre_attack_restore_2026-08-01/`. The installer replaced only
the sixteen directional attack files and two flat South aliases.

Because these preserved actions need a larger cell than the 244-pixel idle,
`player_core.gd` now caches scale/grounding metadata per installed strip. The
measurement uses Godot's native used-rectangle query rather than a GDScript
per-pixel scan. Locomotion retains identical 244-pixel behavior; the 288-pixel
Warrior actions render at the same measured body size and feet anchor without
cropping. Godot import, `verify_art.py warrior` (74 files), compile (97 scripts),
and `test_quick.bat` all passed after installation.

## Warrior Northeast walk candidate

Northeast V01 and the first neutral identity extraction were rejected before
review because ImageGen turned the Warrior toward the camera. The archived
Northeast frame 1 was then isolated as a literal edit target. The resulting
`warrior/walk_ne/warrior_ne_identity_v02_rear_right_source.png` preserves the
binding rear-right orientation, square rear shoulder/back block, helmet back,
weapon side, and down-right sword silhouette.

Built-in ImageGen generated Northeast V02 from that rear-right identity, the
archived Northeast strip, approved Warrior V02 identity, and approved Southeast
V02 cadence. `warrior/walk_ne/warrior_walk_ne_v02_*` contains the unwired source,
keyed master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS
GIFs. Structural QA: six frames; 59/44/59/61/53-pixel empty gutters; 277-pixel
cells; one frame-1-derived scale; 180-pixel visible frame-1 body; common baseline
y=255; zero semi-alpha pixels; transparent corners; and 8.955 effective
representable GIF FPS. Owner approved Northeast V02 on 2026-08-01 as "good
enough." It remains unwired until the complete Warrior direction set is
approved. Runtime remains untouched.

## Warrior North walk candidate

The archived North frame 1 was isolated under `warrior/walk_n/legacy_targets/`
and used as the binding edit target for
`warrior/walk_n/warrior_n_identity_v01_rear_source.png`. That identity preserves
the straight rear camera, rectangular backplate, helmet back, stocky armor,
sword on screen-left, and off-hand grip on screen-right at the upgraded render
density.

North walk V01 preserved identity and orientation but repeated the same visible
leg lead at its two intended contact beats. It is archived as
`warrior_walk_n_v01_rejected_same_contact_source.png` and is ineligible for
installation. Built-in ImageGen V02 was a targeted lower-body cadence correction
that retained the successful V01 torso, backplate, equipment sides, and rear
camera. V02 plants the screen-right boot at f1 and the screen-left boot at f4.

`warrior/walk_n/warrior_walk_n_v02_*` contains the unwired V02 source, keyed
master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS GIFs.
Structural QA: six frames; 61/63/64/34/54-pixel empty gutters; 277-pixel cells;
one frame-1-derived scale; 180-pixel visible frame-1 body; common baseline y=255;
zero semi-alpha pixels; transparent corners; and 8.955 effective representable
GIF FPS. Owner approved North V02 on 2026-08-01. It remains unwired until the
complete Warrior direction set is approved. Runtime remains untouched.

## Warrior Northwest walk candidate

The archived Northwest frame 1 was isolated under
`warrior/walk_nw/legacy_targets/` and used as the binding literal edit target.
`warrior_nw_identity_v01_rear_left_source.png` preserves the archived rear-left
yaw, dominant rectangular backplate, back of helmet, sword on screen-left,
off-hand grip on screen-right, and approved Warrior rendering density.

Northwest walk V01 preserved identity and camera but its intended opposite
contact was too close to a feet-even pose at normalized scale. Built-in ImageGen
V02 was a targeted lower-body cadence correction with the successful V01 upper
body, equipment sides, and rear-left yaw locked. The model reversed the requested
contact labels, which is harmless to loop order: f1/f4 retain opposing leg
ownership while the six-frame motion stays compact and grounded. V01 remains
archived as a rejected motion attempt; neither version touched runtime.

`warrior/walk_nw/warrior_walk_nw_v02_*` contains the unwired V02 source, keyed
master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS GIFs.
Structural QA: six frames; 78/89/96/79/72-pixel empty gutters; 277-pixel cells;
one frame-1-derived scale; 180-pixel visible frame-1 body; common baseline y=255;
zero semi-alpha pixels; transparent corners; and 8.955 effective representable
GIF FPS. Owner approved Northwest V02 on 2026-08-01. It remains unwired until
the complete Warrior direction set is approved. Runtime remains untouched.

## Warrior West walk candidate

West was generated independently from the archived left-facing source; no East
asset was mirrored or transformed. The archived frame 1 under
`warrior/walk_w/legacy_targets/` produced
`warrior_w_identity_v01_left_source.png`, which locks the narrow left-looking
visor, vertical sword on screen-left, and backpack mass trailing on screen-right.

West V01 and the targeted V02 lower-body correction retained the same visible
profile-leg lead at their intended contact beats. Two subsequent single-frame
contact-key attempts tried to force the bright foreground leg forward while the
darker rear leg trailed, but ImageGen repeatedly reconnected the foreground
thigh to the rearward boot. Those sources and the failed auto-crop are retained
as rejected diagnostic evidence and are ineligible for installation.

At normalized game scale, the best coherent V02 strip still reads as a stable,
heavy leftward walk with useful pose variation, despite that anatomical profile
limitation. It was preserved without pixel changes as the explicitly reviewable
West V03 tolerance candidate. `warrior/walk_w/warrior_walk_w_v03_*` contains the
unwired source, keyed master, candidate strip, lossless cut audit, contact sheet,
and both 9 FPS GIFs. Structural QA: six frames; 183/147/179/187/156-pixel empty
gutters; 277-pixel cells; one frame-1-derived scale; 180-pixel visible frame-1
body; common baseline y=255; zero semi-alpha pixels; transparent corners; and
8.955 effective representable GIF FPS. Owner approved West V03 on 2026-08-01 as
"good enough," under the same profile-choppiness tolerance used for East. It
remains unwired until the complete Warrior direction set is approved. Runtime
remains untouched.

## Warrior Southwest walk candidate

The archived `warrior_walk_sw.png` cannot serve as direction authority: its
SHA-256 is byte-for-byte identical to archived `warrior_walk_w.png`
(`95F7BFBE48DC22DB8B90E3A3430F9E96929DFC6766C791F94BB6B71959C4D9CD`).
Other archived Southwest actions also drift between West and front-left. This is
documented as a legacy direction-authoring defect rather than silently preserved.

Built-in ImageGen reconstructed the missing Southwest identity independently
from approved Warrior South identity, independently generated West equipment
asymmetry, and the approved left-diagonal depth construction. It did not mirror
Southeast. `warrior_sw_identity_v01_front_left_source.png` locks a true front-left
45-degree view: front chest and visor visible, partial backpack behind the
screen-right shoulder, and the sword carried down-left.

Southwest walk V01 preserved that reconstructed camera and identity but repeated
the same screen-left boot lead at its intended contact beats. V02 was a targeted
lower-body cadence correction with camera, upper body, backpack depth, sword
side, palette, and scale locked. Its contact ownership remains compact at game
scale, so V02 is presented under the same possible-choppiness tolerance already
accepted for East and West.

`warrior/walk_sw/warrior_walk_sw_v02_*` contains the unwired V02 source, keyed
master, candidate strip, lossless cut audit, contact sheet, and both 9 FPS GIFs.
Structural QA: six frames; 114/96/101/116/113-pixel empty gutters; 277-pixel
cells; one frame-1-derived scale; 180-pixel visible frame-1 body; common baseline
y=255; zero semi-alpha pixels; transparent corners; and 8.955 effective
representable GIF FPS. Owner approved Southwest V02 on 2026-08-01. With that
approval, all eight Warrior directions are eligible for the guarded surgical
runtime install. Runtime remained untouched through the approval gate.

## Archer, Assassin, Warlock idle/walk preservation install

On 2026-08-01 the owner requested a pass-wide upscale of every old-design idle
and walk direction for Archer, Assassin, and Warlock, with self-QA followed by
one owner review at the end. Built-in ImageGen generated each of the eight
facings independently for each action. No cross-direction mirroring, procedural
interpolation, or class redesign was used in that initial set; the later
owner-authorized Archer walk mirrors are documented below.

The accepted candidates live under `archer/`, `assassin/`, and `warlock/` in
direction-specific `idle_*` and `walk_*` folders. Rejected generations remain
archived beside them as negative evidence, including wrong-facing Archer
Southeast, an overlapping Archer Northwest gutter, an Archer West repeated
half-stride, a crouched Assassin Northeast recovery, and Warlock outputs with
extra figures, vertical layouts, or opaque panel contamination.

Archer South, Southeast, and Southwest were regenerated after the owner found
smile drift in some earlier strips. The installed forward-visible faces use a
consistent neutral, focused expression in both idle and walk; side and rear
directions remain neutral by construction.

`tools/art/install_preservation_class_idle_walks.py` validates every candidate,
archives the live old-design baseline, and installs only idle and walk assets.
The final write set was 54 PNGs: flat South aliases plus eight directional idle
and eight directional walk strips for each of the three classes. Attack,
attack2, cast, dash, death, hit, spawn, static portrait, projectile, Mage,
Paladin, and Warrior files were outside the write set. The replaced 104/107/121
pixel old-design runtime strips are recoverable under
`runtime_pre_upscaled_idle_walk_2026-08-01/`.

All accepted generated strips use 277-pixel transparent cells and a 180-pixel
standing-body source target. Idle strips contain four frames and play at 6 FPS;
walk strips contain six frames and play at 9 FPS. The runtime comparison sheets
are under `qa_runtime/` and show all eight facings as rows with frames as
columns.

Mage was deliberately retained byte-for-byte from the restored old design.
Its idle frames measure 200–206 visible body pixels and its walk frames measure
197–211, already exceeding the 180-pixel target without regeneration.

Godot imported all 54 installed sprites. `verify_art.py archer assassin warlock
mage`, the 97-script compile gate, and `test_quick.bat` passed. Visual self-QA
confirmed exact frame counts, transparent corners, stable class identity and
equipment, correct direction reads, neutral Archer expressions, and coherent
contact/load/pass variation. The full suite and mobile sync remain intentionally
deferred until the owner's final visual review.

### Archer alpha, mouth, and owner-authorized walk mirrors

Owner review found that the first Archer extraction globally removed
green-dominant pixels even though Archer's cape is green. The dark-background
contact sheet hid the resulting transparent holes. All sixteen Archer idle and
walk sources were therefore rebuilt non-destructively as new `alpha_fixed`
candidates by `tools/art/rebuild_preservation_archer_alpha.py`. The revised
mask removes exact chroma-field pixels globally (including enclosed negative
space inside a bow) but removes broader key-colored pixels only when connected
to the source border. Darker enclosed cape greens retain their original RGB
and remain fully opaque. Light checkerboard runtime proofs are
`qa_runtime/archer_idle_alpha_checker.png` and
`qa_runtime/archer_walk_alpha_checker.png`.

South idle also received one tightly scoped built-in ImageGen correction:
closed neutral lips in all four frames and a magenta source field. The accepted
source is `archer_idle_s_v03_closed_mouth_source.png`; the installed candidate
is `archer_idle_s_v03_closed_mouth_alpha_fixed_candidate.png`. A nearest-neighbor
face proof is `qa_runtime/archer_idle_s_face_closeup.png`.

The owner explicitly authorized two Archer walk mirrors on 2026-08-01:
Northwest per-frame into Northeast, and West per-frame into East.
`tools/art/install_preservation_archer_walk_mirrors.py` preserves frame order,
performs a reversible double-mirror assertion on every cell, archives the
superseded Northeast/East runtime strips under
`archer/runtime_pre_owner_mirrored_walks_2026-08-01/`, and installs only those
two directions. Final pixel assertions confirmed 6/6 exact mirrored frames for
both pairs.

After the complete Archer correction, Godot import, `verify_art.py archer`, the
97-script compile gate, and `test_quick.bat` all passed. The full suite and
mobile sync remain deferred until owner visual approval.

### Final Archer/Warlock horizontal walk substitutions

The owner later superseded Archer's West/East mapping and applied the same rule
to Warlock: West is now a literal byte-for-byte copy of Southwest, and East is
a literal byte-for-byte copy of Southeast. No mirroring, regeneration,
resampling, re-encoding, or frame reordering is involved. The current guarded
installer is `tools/art/install_preservation_owner_walk_copies.py`; the earlier
Archer mirror installer is retained as historical provenance only.

During this correction the owner found two Warlocks visible in South walk. The
ImageGen source actually contains seven clean figures, while the first builder
was incorrectly told to slice it into six cells and consequently merged source
figures four and five into one runtime frame. The source was re-extracted as
`warlock_walk_s_v02_7frame_candidate.png`: seven 277-pixel cells, one Warlock
per frame, common 180-pixel standing scale, and the original 9 FPS cadence.
Both `warlock_walk_s.png` and its flat South alias `warlock_walk.png` use this
same corrected seven-frame strip.

The six superseded runtime files are recoverable under the per-class
`runtime_pre_owner_walk_direction_copies_2026-08-01/` archives. SHA-256 checks
confirmed all five source/target relationships (including the Warlock South
alias) are exact copies. Godot imported the six changed PNGs, `verify_art.py
archer warlock` passed, the 97-script compile gate passed, and
`test_quick.bat` passed. Updated owner galleries are
`qa_runtime/archer_walk.png` and `qa_runtime/warlock_walk.png`. Full-suite and
mobile-sync gates remain deferred until visual approval.

### Variable frame-count guardrail

The runtime was already data-driven: `Art._strip_info()` derives frame count as
strip width divided by square-cell width, `_play_clip()` assigns that value to
`Sprite2D.hframes`, and the animation driver loops modulo the detected count.
There was no six-frame assumption in gameplay. The double-Warlock defect came
from the offline preservation builder accepting a manually supplied
`--frames 6` for a source that visibly contained seven authored figures.

`tools/art/build_preservation_walk_candidate.py` now auto-detects figure count
from broad transparent gutters. `--frames` is optional and acts only as an
assertion: if the requested count disagrees with the detected count, the build
fails instead of merging or dropping figures. The general preservation
installer likewise derives candidate frame count from width rather than using
idle/walk constants. Regression checks prove the real Warlock strip is read as
seven frames and the iterator accepts a synthetic 100-frame timeline. A single
horizontal texture is still subject to the target GPU's maximum texture width;
very large high-resolution timelines should be split across rows or textures.

### Assassin two-dagger continuity regeneration

Owner review found that the first Assassin upscale omitted the far-hand dagger
in the Southeast, East, Northeast, Northwest, West, and Southwest idle and walk
strips. South and North already showed one short curved dagger in each hand and
remain unchanged. Built-in ImageGen regenerated the twelve defective rows from
the accepted strip for motion/facing and `assassin_identity_s_v02_source.png`
for old-design identity and equipment. Every prompt required exactly two
distinct held daggers in every figure, with the far hand and complete blade
kept readable outside the cloak silhouette; extra, floating, merged, hidden,
or sheathed-substitute weapons were forbidden.

The accepted sources and derived candidates use the
`*_two_daggers_{source,candidate}.png` naming convention in their existing
direction folders. Northwest idle V02 was rejected because it shortened the
cloak and is retained as `assassin_idle_nw_v02_rejected_short_cloak_source.png`;
the accepted tightened correction is V03. All candidates retain 277-pixel
cells and a 180-pixel standing-body target. Idle remains four frames at 6 FPS
and walk remains six frames at 9 FPS.

The superseded live Assassin idle/walk set is recoverable under
`assassin/runtime_pre_two_dagger_regen_2026-08-01/`. Runtime contact sheets are
`qa_runtime/assassin_idle.png` and `qa_runtime/assassin_walk.png`; visual QA
confirmed two visible daggers in all 80 frames, stable old-design identity,
correct facings, clean alpha, and one character per cell. Godot imported the
twelve changed strips, `verify_art.py assassin` passed for all 74 Assassin
PNGs, the 97-script compile gate passed, and `test_quick.bat` passed. The full
suite and mobile sync remain deferred until owner visual approval.

### Assassin walk opposite-contact repair

Owner review found that the two-dagger walk regeneration had collapsed the
lower-body cycle into repeated same-foot poses. North walk was explicitly
approved and remains byte-for-byte unchanged. South, Southeast, East,
Northeast, Northwest, West, and Southwest now use distinct f1/f4 contact
anchors: one leg leads in f1 and the opposite leg leads in f4, with the existing
two-dagger transition frames retained between them. South uses an exact
horizontal mirror of its accepted f1 contact for f4 because its front-facing
equipment and stance are symmetric. The other facings use direction-locked
built-in ImageGen opposite-contact inserts with screen-coordinate leg contracts.

Rejected evidence is retained, including the South six-frame reroll with a weak
opposite contact and the Southeast two-pose source that repeated the same
stride. `tools/art/replace_preservation_walk_transitions.py` now supports
selecting a frame from an already normalized square-cell strip with
`@SOURCE_FRAME` and an optional `:mirror`; it also preserves authored alpha
instead of re-keying transparent candidate canvases.

The immediately superseded walk set is recoverable under
`assassin/runtime_pre_alternating_walk_contacts_2026-08-01/`. The updated owner
sheet is `qa_runtime/assassin_walk.png`. Visual QA confirmed opposing contact
silhouettes in the seven repaired facings, two visible daggers in every frame,
and an unchanged North strip. Godot imported exactly those seven directions
plus the South alias, `verify_art.py assassin` passed for all 74 PNGs, the
97-script compile gate passed, and `test_quick.bat` passed. The full suite and
mobile sync remain deferred until owner visual approval.
