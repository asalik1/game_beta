# Mob locomotion repair (built-in ImageGen, 2026-08-08)

These are the preserved source masters for the owner-flagged mob walk pass.
Rebuild production assets with:

```powershell
python tools/art/build_mob_walk_repairs.py
```

Generation used the live static sprite as the binding identity reference and
the old walk strip only as a negative timing/layout reference. Walk prompts
requested four left-facing frames with explicit A-contact, passing,
B-contact, passing timing; quadrupeds used opposing front/rear contacts and
crawlers used alternating diagonal leg groups. Every installed pose is a
complete generated frame. Per the owner rule, the builder never cuts, mirrors,
pastes, or otherwise edits individual limbs/body regions.

The special-note override is binding: `null_acolyte` keeps its existing
floor-length identity; the nine `*_idle_master.png` designs have a continuous
floor-length hem and no visible legs or feet. All ten now use dedicated
`*_motion_master.png` four-frame glide/breathing loops instead of legged walk
strips. These are complete generated poses with readable breathing,
arm/equipment travel, and robe-fold/hem sweep while the head, torso, facing,
height, and ground point remain locked. Both the first overly subtle attempts
and a later over-exaggerated leaning/bobbing pass were rejected and are not
installed. The builder also
rejects any robe loop with fewer than three distinct complete frames.
`qa_robe_motion.png` compares the identity and all four installed motion poses.
Their matching `*_attack_master.png` strips
use the same full-height identity and keep legs/feet covered in every complete
generated frame. `qa_robe_attacks.png` compares each installed attack directly
against its accepted idle. The Static Caller and Plague Chanter first
attempts were rejected (invented halo; visible toe) and are not retained.

`skeleton_rogue_master.png` is a complete upright Barrow Wight redesign in a
strict 4x4 idle/walk/attack/defeat grid. Its dedicated
`skeleton_rogue_walk_master.png` isolates the gait, and
`skeleton_rogue_walk_opposite_master.png` supplies the separately generated
opposite step (raised screen-left knee, planted screen-right boot). This keeps
the lead leg visibly alternating without mirroring the cape or sword.
`fungus_heavy_walk_n_master.png` and
`fungus_heavy_walk_s_master.png` are isolated four-frame replacements for the
two specifically flagged Spore Shambler directions. The oversized pale claw
is identity-locked to screen-right in the north/back strip and screen-left in
the south/front strip (the same anatomical arm viewed from opposite sides),
while the other arm remains the thin root arm in every complete frame.

Every prompt required a perfectly flat `#00ff00` screen, broad gutters,
stable scale/center/ground line, the exact input identity and equipment, no
crop/shadow/text/grid/watermark, and no new or missing limbs. The builder
removes the key, hardens alpha, restores live canvas/scale/ground metrics, and
writes `qa_walk_contact.png` for four-frame review.
The accepted canvas, anchor, and body-scale metrics are frozen in
`references/`; rebuilds never measure their own prior output, preventing
one-pixel scale drift across repeated runs. Walks use the idle reference—not
the legacy walk canvas—so locomotion cannot change apparent body size.
Robe sheets are separated only through transparent ImageGen gutters, then each
complete pose is aligned by its upper-body and ground anchors. Flowing cloth
therefore cannot drag the character core sideways, and nominal quarter-width
cuts cannot create detached weapon or robe fragments.

The consistency follow-up preserves complete legacy frames for Cinder Whelp,
Storm Harrier, and Frozen Guard, translating only the whole frame to a common
ground point. Bog Lurker's walk, Grove Horror's
attack, and Marsh Spider's attack use dedicated complete-pose ImageGen masters
so no limb or artifact is repaired by compositing partial body regions. The
Grove and Spider action canvases are allowed to grow to contain the widest
pose instead of clipping it. At runtime, the first idle cell is the persistent
body-scale reference; action changes cannot overwrite it, and every strip is
ground-anchored even when its cell size happens to match the current strip.
Bog Lurker's oversized walk canvas is explicitly rendered at that persistent
idle body scale.
Marsh Spider bypasses its older direction set because those sheets vary in
subject scale (most visibly west); the installed complete-frame flat walk has
the same 386px cell and idle-body scale and uses the normal horizontal-facing
path instead.

The follow-up attack pass replaces the legacy Spore Shambler, Hollow Soldier,
Wildfang Howler, Wildkin Ranger, and Void Shade strips with four complete
ImageGen poses apiece. Those old strips contained below-feet or horizontal
neighbor fragments and/or inconsistent body anchors. The builder accepts these
masters only when it detects three genuinely empty chroma gutters, then locks
each complete pose by upper body and ground point. A first Void Shade rerender
was rejected for isolated violet pixels, and two horizontal rerenders were
rejected for unsafe gutter separation; none of those results is installed. Its
accepted source uses a
padded 2x2 layout so the single screen-left sword can remain entirely within
each complete pose without overlapping the neighboring pose's x extent. The
builder validates transparent margins around all four quadrants before
assembling the horizontal runtime strip. Foliage-bearing Wildkin uses
a magenta key, and the chroma remover selects green or magenta despill from the
sampled border instead of leaving colored edge pixels. Review all seven strict
attack replacements in `qa_consistency_attacks.png`.
`qa_idle_only_contact.png` separately proves the owner-priority robe set,
including the unchanged Null Acolyte reference.
`qa_barrow_walk.png` is a nearest-neighbor enlargement of the installed
Barrow Wight strip for explicit contact-pose review.

The 2026-08-10 follow-up adds strict padded 2x2 complete-pose attack masters
for Waking Wolf, Wildkin Ranger, Dune Prowler, Null Acolyte, Barrow Wight,
Slagbound Brute, Storm Harrier, and Plague Chanter. The prompts explicitly
require full face/muzzle/tail/robe/equipment containment, a locked planted
ground point and torso position, and the established native screen-left facing
for Wildkin and Barrow. Plague Chanter keeps exactly one staff continuously
gripped by the same hand while the free hand casts. Slagbound preserves its
accepted old idle strip whole: frame zero is now its one-frame idle and all
four former idle frames are now its walk loop. No pose was mirrored or
assembled from body pieces. Waking Wolf's accepted walk master uses opposing
foreleg contact poses; two earlier generations without a decisive contact
reversal (one also containing divider bars) were rejected and never installed.
The 2x2 extractor requires a fully transparent perimeter around each complete
pose before assembling the runtime strip.
