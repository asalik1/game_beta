# ImageGen sprite creation and runtime integration

This is the zero-context playbook for creating a new Crownless bitmap sprite
family with Codex's built-in ImageGen tool, converting the generated masters
into deterministic runtime assets, wiring them into Godot, and completing
visual and automated QA.

Use the complete workflow for player characters, skins, bosses, mobs, props,
projectiles, and animated environment art. The exact directions and frame
counts change by asset type, but the governing pattern does not:

> lore and runtime contract → approved identity → animation masters →
> deterministic builder → runtime wiring → contact-sheet QA → engine tests →
> mobile synchronization

The Oathbound Arbiter Paladin regeneration is the worked example:

- source notes and masters:
  [`art_src/paladin_oathbound_arbiter/README.md`](../../art_src/paladin_oathbound_arbiter/README.md)
- deterministic builder:
  [`tools/art/build_oathbound_paladin.py`](build_oathbound_paladin.py)
- generated QA sheets:
  `art_src/paladin_oathbound_arbiter/qa_regen/`

The guide deliberately records the failure modes found during that job. Those
failures—wrong facings, disappearing equipment, non-alternating legs, marching
gaits, recovery-frame flips, extra generated rows, and apparent
low-resolution art—are normal generation risks. They should be detected and
repaired in the source/build pipeline, not hidden with runtime hacks.

## 1. Read the repository contract before touching art

Start at the repository root and read [`CLAUDE.md`](../../CLAUDE.md). Its rules
override this document. In particular:

- `game/` is the desktop source of truth.
- Do not edit `mobile/game/` manually. Synchronize it from `game/` at the end.
- Preserve unrelated files in a dirty worktree.
- Do not stage or commit unless the user asks.
- Use built-in ImageGen for bitmap generation when requested. Do not silently
  substitute PixelLab or another provider.
- Preserve generated source masters in `art_src/`; do not leave the only copy
  in a temporary output directory.
- Run the required test order before handing off production changes.

Take a read-only inventory before generating anything:

```powershell
git status --short
rg -n '"sprite"|ABILITY_CLIP|HERO_CLIP_FILES|HERO_CLIP_FPS' `
  game/scripts/classes.gd game/scripts/player_core.gd game/scripts/art.gd
rg --files game/assets/sprites | rg '<existing-base-name>'
```

Record which existing changes belong to the user. A sprite job never grants
permission to discard or overwrite unrelated work.

### Python dependencies

The builders and visual verifiers use Pillow and NumPy. Before running them,
prove the selected interpreter has both:

```powershell
python -c "import PIL, numpy; print('sprite Python OK')"
```

If the system `python` fails, use Codex's bundled workspace interpreter. The
path in the current Windows workspace is:

```powershell
$spritePython = `
  'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $spritePython -c "import PIL, numpy; print('sprite Python OK')"
```

If that cache path changes, use Codex's workspace-dependency locator or search
the local Codex runtime for `dependencies\python\python.exe`; do not install
packages into the project blindly. Every `python` command below means an
interpreter for which the dependency check passes. In PowerShell, replace it
with `& $spritePython` when using the bundled interpreter.

## 2. Discover the actual runtime contract

Do not infer the asset contract from filenames alone. Read the code that loads
and plays the target.

For Crownless player characters, inspect:

- `game/scripts/classes.gd`: the class's `"sprite"` base name and ability data.
- `game/scripts/player_core.gd`: `ABILITY_CLIP`, class sprite loading, facing
  selection, one-shot animation behavior, and rendered body-size rules.
- `game/scripts/art.gd`: `HERO_CLIP_FILES`, `HERO_CLIP_FPS`, `dir_set`,
  `dir8_suffix`, strip slicing, and fallback behavior.

The current player convention is:

| logical clip | filename stem | default FPS |
|---|---|---:|
| idle | `<base>_anim` | 6 |
| walk | `<base>_walk` | 9 |
| run | `<base>_run` | 11 |
| primary attack | `<base>_attack` | 22 |
| secondary attack | `<base>_attack2` | 22 |
| cast | `<base>_cast` | 10 |
| dash | `<base>_dash` | 26 |
| ultimate | `<base>_ult` | 11 |
| ultimate idle | `<base>_ultidle` | 6 |
| death | `<base>_death` | 9 |

Every directional strip is named:

```text
game/assets/sprites/<base>_<clip-stem>_<direction>.png
```

Directions are:

```text
s, se, e, ne, n, nw, w, sw
```

The static class-select/codex sprite is:

```text
game/assets/sprites/<base>.png
```

Each animation file is one horizontal strip. Its height is the square cell
size, and its width must be an integer multiple of that height. The engine
calculates the frame count as `width / height`.

For non-player assets, inspect their consumer. Ordinary mobs currently use a
smaller subset of the player clip contract. Props, projectiles, bosses, and
directional aim animations each have different loaders. Never create unused
files and assume they are wired.

Write down, before generation:

1. runtime base name;
2. required clips;
3. frame count for every clip;
4. required directions;
5. intended ability-to-clip mapping;
6. target visible size and ground anchor;
7. whether any directions may be derived by mirroring;
8. files or data tables that must be changed for wiring.

## 3. Translate lore into a binding art contract

Read the relevant class, character, quest, bestiary, environment, or encounter
lore. Convert prose into visual invariants that can be checked frame by frame.

For a character, specify:

- age, face visibility, hair, facial hair, and body proportions;
- primary silhouette and posture;
- armor or clothing layers;
- tightly limited palette and material hierarchy;
- permanent insignia and where it sits on the body;
- weapon type, weapon hand, shield/off-hand ownership, and relative sizes;
- which equipment is always present;
- camera elevation and projection;
- visual attitude: guarded, predatory, ceremonial, weary, agile, and so on;
- what the design must not resemble.

The Oathbound Arbiter's binding invariants were:

- visible, weathered, middle-aged mortal face;
- short dark hair and beard;
- pale steel and warm ivory plate;
- deep judicial-blue tabard and one-shoulder mantle;
- brass oath-chain crossing a large round seal over the heart;
- square-headed oath hammer held in the right hand;
- tall battered pale shield on the left arm;
- protective magistrate silhouette, not a hooded ecclesiastical silhouette;
- low top-down orthographic/isometric camera;
- mature proportions and restrained visual noise.

### References have explicit roles

Every supplied image must be labeled conceptually as one of:

- **binding identity reference**: the generated character must match it;
- **pose/timing reference**: use only its motion or layout;
- **style/readability reference**: use its finish, scale readability, or
  material separation without copying its identity;
- **negative reference**: shows the design flaw being replaced.

Never leave those roles ambiguous in the prompt. For the Paladin, the approved
five-view Oathbound rotation became the binding identity. The old Paladin and
Maren were thereafter only design/readability references. This prevented the
animation passes from drifting back toward the old design or turning into
Maren.

### Explore the design before binding it

When the existing design itself is the problem, do a concept-selection pass
before the rotation sheet. This was the first Paladin step:

1. read the class lore and kit fantasy;
2. inspect the current Paladin and higher-quality in-game characters;
3. explain which old visual ideas conflict with the lore or quality target;
4. define three genuinely different lore-valid silhouettes;
5. generate three base-sprite candidates under the same camera, scale,
   background, and readability contract;
6. show all three at comparable size;
7. let the user choose or combine a direction;
8. turn the approved concept—Oathbound Arbiter in this case—into the binding
   identity/rotation sheet.

The concepts should differ in design language, not merely pose or tint. Vary
meaningful choices such as exposed face versus helmet, armor construction,
mantle/tabard balance, office insignia, shield profile, weapon geometry, and
protective versus crusading posture while remaining faithful to the same class
mechanics.

Concept prompt skeleton:

```text
Read the supplied lore and current sprite as a negative/continuity reference.
Create one production base-sprite concept for [CLASS/ASSET] called [CONCEPT
NAME]. Its visual thesis is [ONE-SENTENCE LORE INTERPRETATION].

Preserve gameplay essentials: [WEAPON/OFF-HAND/ROLE/SILHOUETTE REQUIREMENTS].
Replace these weaknesses in the current design: [SPECIFIC PROBLEMS].

Show one isolated full-body [S OR THREE-QUARTER] neutral base pose under the
shared Crownless camera, scale, pixel-rendering, chroma, no-shadow, no-text,
no-crop, and small-size-readability contract. This candidate must be visually
distinct from the other concepts through [DESIGN AXES].
```

Do not begin full animation until the user has selected the concept. A concept
sheet is cheap to replace; a 60-plus-file directional family is not.

### Operate the built-in ImageGen tool deliberately

In a Codex environment that exposes an ImageGen skill, read its complete
`SKILL.md` before calling the image tool. Tool parameters may evolve, so the
current skill instructions are authoritative for how references and outputs
are supplied.

The practical sequence is:

1. View every local reference image before using it. Verify that it is the
   intended identity, style, timing, or negative reference.
2. For a brand-new concept, call the built-in image generator without an image
   reference and use the complete text contract.
3. For rotations and animation, pass the approved local identity image as the
   image reference. Use absolute normalized paths when the tool accepts local
   paths.
4. For repairs, pass both the binding identity and defective timing sheet when
   the tool supports multiple local references. Define each image's role in the
   prompt.
5. Generate one logically coherent master per call: one rotation, one stable
   multi-row clip, one direction-specific walk, or one repair direction.
6. Wait for the generation to finish; do not launch a large unreviewed family
   and assume consistency.
7. Inspect the returned original at full resolution with the image viewer.
8. Immediately preserve the accepted original under `art_src/<family>/` using
   a descriptive, versioned filename.
9. Record the prompt contract and output purpose in the family's README.
10. Use the accepted repository copy—not a temporary tool-output path—as the
    reference for later animation calls.

Do not provide conflicting reference mechanisms in one tool call. For example,
if the current tool distinguishes local `referenced_image_paths` from recent
conversation images, use the smallest one mechanism that includes every
required target/reference. If a required image cannot be supplied reliably,
ask for it again instead of silently generating without it.

Small batches are useful for independent clips, but inspection is a gate
between stages:

```text
concepts → user choice → rotation approval → core locomotion review →
ability/death masters → direction repairs → deterministic build
```

## 4. Approve identity before generating animation

Do not begin by asking for the entire animation family. First generate a
rotation or compact set of base poses on a removable chroma background.

For symmetric eight-direction characters, generate five authored facings:

```text
S, SE, E, NE, N
```

After approval, derive these controlled mirrors:

```text
E  → W
SE → SW
NE → NW
```

This has three advantages:

- the character remains internally consistent;
- the generator has fewer identities to maintain at once;
- left/right symmetry is deterministic in the builder.

Do not mirror when handedness, asymmetric injuries, costume construction,
lettering, insignia, or gameplay telegraphs must remain physically correct.
In that case, author all eight directions and document why.

### Base-rotation prompt template

Adapt every bracketed field. Do not paste it unchanged for a different asset.

```text
Asset type: production high-resolution pixel-art game sprite identity sheet
for Crownless, intended to become an eight-direction animated character.

Create exactly five isolated full-body rotations of the same [CHARACTER]:
S/front, SE/front-right three-quarter, E/right profile, NE/rear-right
three-quarter, and N/back. Arrange them left to right in that exact order with
generous pure-green gutters. These are rotations of one identical production
model, not five redesigns.

Binding identity: [FACE, PROPORTIONS, CLOTHING/ARMOR, PALETTE, INSIGNIA,
WEAPON AND HAND, OFF-HAND AND HAND, SILHOUETTE, ATTITUDE].

Camera and medium: low top-down orthographic/isometric action-RPG camera;
authentic premium hand-pixeled rendering; deliberate square pixel clusters;
selective dark outlines; bold readable color masses; simplified material
seams; controlled texture; legible after reduction to [TARGET] pixels tall.
Do not render smooth digital painting, vector art, 3D, or splash illustration.

Consistency: identical body scale, equipment dimensions, palette, camera,
ground line, and proportions in all five rotations. Keep the complete weapon,
shield, head, feet, and clothing inside the canvas. Maintain [WEAPON] in the
[RIGHT/LEFT] hand and [OFF-HAND] on the [LEFT/RIGHT] arm in every view.

Backdrop: perfectly flat solid #00ff00 across the entire image. No gradient,
texture, lighting variation, floor plane, cast/contact shadow, reflection, or
green within the subject.

No text, labels, numbers, grid lines, panels, border, watermark, crop, overlap,
extra characters, extra limbs, duplicate equipment, scenery, or spell effects.
```

Inspect the rotation at full resolution and at the intended in-game size.
Approve identity, silhouette, equipment ownership, facings, and readability.
If the identity is wrong, regenerate it now. Animation amplifies identity
errors and makes them more expensive to correct.

Archive the approved output, for example:

```text
art_src/<asset-family>/regen_base_rotations.png
```

The generated original must be copied into the repository. Never rely on a
temporary image-generation path as the only copy.

## 5. Plan animation as timelines, not collections of poses

Before prompting, write a frame-by-frame motion plan for each clip. State
where the character starts, where the force or weight travels, which frame
contains the action peak, and how the character recovers.

The Oathbound player family uses:

| clip | frames | authored intent |
|---|---:|---|
| idle | 4 | restrained breathing and cloth/chain settling |
| walk | 8 | two natural alternating steps |
| run | 6 | compact shield-led run |
| Judgment / attack | 7 | overhead hammer windup, impact, recovery |
| Consecration / attack2 | 7 | measured ground strike, recovery |
| Aegis / cast | 6 | shield raise and brace |
| Conviction / ult | 7 | oath-seal surge and settle |
| death | 6 | loss of balance, collapse, grounded corpse |

These counts are a project example, not a universal ImageGen rule. Match the
runtime and gameplay timing of the target asset.

### Walk-cycle contract

Walking is especially easy for a generator to fake with unrelated standing
poses. Specify a complete two-step cycle:

1. left-foot contact;
2. left-foot load;
3. right leg passing;
4. left-foot advance;
5. right-foot contact;
6. right-foot load;
7. left leg passing;
8. right-foot advance.

Require:

- unmistakable left/right alternation;
- low knee lift appropriate to normal travel;
- heel/toe and hip motion rather than high ceremonial knee raises;
- modest vertical bob;
- planted feet that do not slide;
- stable facing and camera;
- weapon and shield reacting to the gait without swapping hands.

Explicitly say “natural walk, not a march, parade step, run, or alternating
idle poses.”

Direction-specific walk strips were more reliable than one five-row master for
the Paladin. Use one generated row per authored direction when locomotion
quality matters. Combined grids remain useful for more stable clips, but they
increase the number of identities and timelines the model must preserve.

## 6. Prompt animation masters

Use the approved identity sheet as the binding image reference for every
animation generation. When repairing a bad animation, also supply the defective
sheet as a timing reference and explicitly state that its identity errors are
not authoritative.

### Multi-direction animation prompt template

```text
Asset type: production high-resolution pixel-art animation source sheet for
Crownless.

Image 1 is the binding identity reference. Reproduce exactly that same
[CHARACTER], including [LIST NON-NEGOTIABLE IDENTITY AND EQUIPMENT INVARIANTS].
Do not redesign, simplify away, add, remove, or swap equipment.

Create a strict [ROWS]-row by [COLUMNS]-column source sheet. Rows, top to
bottom, are exactly [DIRECTION LIST]. Columns, left to right, are consecutive
frames of one [CLIP NAME] timeline:

f1 [POSE/WEIGHT]
f2 [POSE/WEIGHT]
...
fN [POSE/WEIGHT/RECOVERY]

Each row shows the same timeline from its assigned facing. The final frame
must still face the row's assigned direction. All figures use identical camera,
scale, proportions, palette, equipment dimensions, and ground baseline.

Rendering: [PROJECT PIXEL-ART STYLE CONTRACT]. Preserve crisp deliberate pixel
clusters and readable color masses. Keep texture controlled enough to reduce
cleanly to the in-game size.

Layout: generous flat pure #00ff00 gutters between every figure. No pose may
touch, overlap, cross into, or be cropped by another cell. Keep full head,
weapon, shield, clothing, feet, and effects inside each implied cell.

Backdrop: perfectly flat solid #00ff00 only; no floor, shadow, gradient,
reflection, scenery, text, labels, frame numbers, grid lines, panels, border,
or watermark. Do not use green within the character or effect.

Negative constraints targeted to this clip: [KNOWN FAILURE RISKS—E.G. HAMMER
HEAD MUST REMAIN VISIBLE; LEGS MUST ALTERNATE; NO FINAL-FRAME FACING FLIP].
```

### Direction-specific walk prompt template

```text
Create one horizontal eight-frame [DIRECTION]-facing natural walk cycle of the
exact character in Image 1. This is one coherent two-step loop, not eight
unrelated poses.

Frame timing:
f1 left-foot contact
f2 left-foot load
f3 right leg passes with low knee lift
f4 left-foot advance
f5 right-foot contact
f6 right-foot load
f7 left leg passes with low knee lift
f8 right-foot advance, flowing naturally back to f1

The legs must visibly alternate. Use ordinary grounded travel with subtle hip
shift and modest body bob—never a march, parade step, high-knee run, or shuffle.
Feet must plant rather than slide. Keep [DIRECTION] facing in every frame.

[REPEAT THE BINDING IDENTITY, EQUIPMENT-HAND, CAMERA, RENDERING, CHROMA,
GUTTER, NO-CROP, NO-TEXT, AND NO-OVERLAP CONTRACTS.]
```

### Direction-locked repair prompt template

```text
Image 1 is the binding identity reference.
Image 2 is only the existing [CLIP] timing reference and contains a defect in
[DIRECTION] [FRAME/RANGE]. Do not copy that defect.

Regenerate exactly one horizontal [FRAME COUNT]-frame [DIRECTION]-facing
[CLIP] timeline. Preserve the timing and action intent, but keep the character
locked to [DIRECTION] from f1 through the final recovery frame.

Mandatory repair: [EXACT VISUAL ACCEPTANCE CRITERION, SUCH AS "the complete
square metal hammer head and shaft remain visible through impact and recovery"
or "the rear-facing shield, shoulders, and feet never rotate toward camera"].

[REPEAT THE COMPLETE BINDING IDENTITY, LAYOUT, AND CHROMA CONTRACT.]
```

Targeted repair rows are preferable to compositing a weapon or body part from
an unrelated pose. A pasted hammer head can hide one symptom while leaving
incorrect arms, weight, perspective, lighting, or identity underneath.

## 7. Inspect every source master before extraction

Image generation follows layouts semantically, not mathematically. Never trust
the requested row count, column count, direction label, or pose order without
visual inspection.

For each generated source, check:

- expected number of visible rows and poses;
- true facing of every row based on face, shield, weapon, feet, shoulders, and
  cape—not merely its position in the sheet;
- complete head, feet, weapon head/shaft, shield, cloak, and effects;
- no overlap across implied cells;
- green gutters between poses;
- stable character identity and equipment ownership;
- stable camera, body proportions, scale, and ground line;
- motion continuity from adjacent frames;
- correct start, peak, recovery, and loop closure;
- no text, labels, numbers, shadows, floor, or scenery.

The Paladin run request returned six rows although five were requested. Visual
inspection showed that both rear-quarter rows should not be merged into a
single equal-height crop. The builder therefore reads six rows and explicitly
selects source rows `0, 1, 2, 4, 5` as S, SE, E, true NE, and N.

This is an important general rule:

> When the generated grid violates the requested layout, encode the approved
> real source layout in the builder. Do not pretend the image is an exact grid.

Use unambiguous filenames:

```text
art_src/<asset-family>/regen_idle_keyed.png
art_src/<asset-family>/regen_walk_s_keyed.png
art_src/<asset-family>/regen_attack_keyed.png
art_src/<asset-family>/regen_attack_n_keyed.png
```

Direction-specific repair names make the active source precedence obvious.
Document every exception in the family README and beside the selection logic
in the builder.

## 8. Build runtime strips deterministically

Create one asset-family builder under `tools/art/` rather than manually
cropping and copying dozens of frames. The builder is the executable record of
how approved sources become runtime art.

The Paladin implementation is
[`build_oathbound_paladin.py`](build_oathbound_paladin.py). Its stages are:

### 8.1 Remove chroma and despill

The Paladin palette intentionally contains no green, so its builder keys pixels
whose green channel strongly dominates red and blue. It then clamps residual
green dominance on visible pixels. That removes light/dark green variation and
prevents neon edge spill during downsampling.

Choose a chroma color absent from the subject. If the subject legitimately
contains green, use magenta/cyan or a different segmentation rule. Do not use a
key that erases intended colors.

After resizing, harden alpha:

- alpha above the chosen threshold becomes 255;
- everything else becomes 0;
- RGB under transparent pixels becomes black/zero.

Crownless character strips should normally have zero semi-transparent pixels.
This avoids grass or environment color bleeding through their edges.

### 8.2 Find real gutters, not idealized equal cells

Generated grids often have asymmetric margins and poses that cross nominal
equal-width boundaries. A naive `image_width / columns` crop can cut off a
hammer head or assign part of one figure to its neighbor.

The Paladin builder:

1. chroma-keys the image;
2. projects visible alpha along X or Y;
3. estimates each pose/row center with weighted one-dimensional clustering;
4. finds the empty or lowest-occupancy valley between adjacent centers;
5. cuts at those real gutters.

Reuse this principle for generated grids. Equal cell slicing is acceptable
only after proving the source really has exact cells.

For new production sheets, this is a hard gate rather than a best effort:

1. every internal cut must sit inside a contiguous fully transparent gutter;
2. the separator column/row occupancy must be exactly zero after keying;
3. require a broad gutter (the V3 class-walk builder uses at least 8 columns),
   not a single accidental empty line through a disconnected cape or prop;
4. partition the keyed image with rectangles and assert that the sum of opaque
   pixels in all cells equals the opaque-pixel count of the source;
5. emit a source-resolution cut overlay showing every separator and measured
   gutter width, then inspect it before wiring.

Do not use connected-component ownership, largest-blob cleanup, brightness
filters, or nearest-body deletion after a safe rectangular slice. Hair, cape
panels, bow strings, staff heads, weapon tips, and airborne projectiles may be
legitimately disconnected. A filter that keeps the body can still amputate the
animation. If a legacy sheet has overlapping/irregular cells, component
assignment is acceptable only as an audited salvage path where every meaningful
component is assigned exactly once and none is discarded by size, darkness, or
distance. New work should regenerate the affected direction with broad gutters.

### 8.3 Map source rows explicitly

Turn rows into named directions in source order. If a generated source has an
extra or mislabeled row, select the approved row indices explicitly and comment
the decision. Direction names should be based on visual evidence.

Treat prompt labels, filenames, and requested row order only as generation
notes. They are not runtime metadata. Before a row receives a runtime suffix,
classify its **observed** facing from the body and equipment perspective:

1. decide front, back, or profile from the face/back, shoulders, and torso;
2. decide screen-left or screen-right from the feet, nose/hood, and prop depth;
3. check every frame, including the final recovery pose;
4. record the observed result on a labeled proof sheet;
5. only then assign `s`, `se`, `e`, `ne`, `n`, `nw`, `w`, or `sw`.

If a request for E produces a visually W-facing row, preserve the generated
master but route it to W. Regenerate only when its handedness or equipment
construction makes that routing invalid. Never wire a grid directly from the
order written in its prompt.

For repair sources, replace the entire defective direction timeline:

```python
clip["n"] = load_grid("regen_attack_n_keyed.png", rows=1, cols=7)[0]
```

Replacing a whole direction keeps timing, body, weapon, and camera internally
coherent.

### 8.4 Normalize scale without destroying motion

Normalize each direction/clip from a stable reference pose, normally the first
frame:

1. find the visible bounding box of the reference frame;
2. calculate one scale for the entire direction;
3. crop each frame to its visible bounds;
4. resize every frame with that same scale;
5. place every result on a generous transparent staging cell;
6. center it horizontally;
7. align it to one ground baseline.

Never independently scale every frame to the same height. That erases authored
crouching, jumping, recoil, collapse, and corpse width, and makes the animation
“breathe” in size.

The regenerated Paladin uses:

```text
standing body target: 180 px
staging cell:         384 px
staging baseline:     350 px
final shared cell:    277 px
```

The large source body does not make the hero physically larger in gameplay.
`player_core.gd` applies the class's existing visible-body target. The higher
source density gives the renderer more detail to downsample, improving perceived
resolution and material separation.

Leave extra staging room for wide poses such as corpses, shields, weapon arcs,
and lunges. Validate that no normalized figure exceeds the staging bounds.

### 8.5 Derive approved mirrors

Once S, SE, E, NE, and N are normalized, create W, SW, and NW by horizontally
mirroring E, SE, and NE one frame at a time. Do not mirror an entire strip as
one image if that changes frame order or causes cross-cell sampling.

Use the repo helper:

```python
install_dirset.assemble_clips(
    clips,
    output_directory,
    margin=<transparent safety margin>,
    symmetric=True,
)
```

It assembles all frames into a shared square-cell geometry. A shared cell
prevents clip-to-clip scaling jumps.

### 8.6 Install and validate

Write only to:

```text
game/assets/sprites/
```

For a full player family, validate:

- eight direction files for every required clip;
- every image height equals the shared cell;
- every strip width is divisible by the shared cell;
- expected frame count per strip;
- no empty frames;
- no semi-transparent pixels;
- static `<base>.png` exists and represents the approved identity;
- no unexpected legacy clip remains active.

The Oathbound builder writes 8 clips × 8 directions plus the static sprite.
Together with the runtime naming convention, that is 65 regenerated files.
The installed `paladin` family contains 73 files because the loader-compatible
family also includes existing ancillary Paladin sprite files; use
`verify_art.py` to inventory the actual installed base.

## 9. Wire the sprite into gameplay

For a player class:

1. Set the class entry in `game/scripts/classes.gd`:

   ```gdscript
   "sprite": "<base>"
   ```

2. Map ability slots in `ABILITY_CLIP` in
   `game/scripts/player_core.gd`:

   ```gdscript
   "<class>": {
       "a1": "attack",
       "a2": "attack2",
       "a3": "cast",
       "ult": "ult",
   }
   ```

3. Confirm each logical clip exists in `Art.HERO_CLIP_FILES` in
   `game/scripts/art.gd`.

4. Confirm the intended playback rate in `Art.HERO_CLIP_FPS`.

5. Confirm the installed filenames exactly match
   `<base>_<clip-stem>_<direction>.png`.

At runtime, `_apply_class_sprite()` reads the class's sprite base, asks
`Art.hero_clips(base)` for the base strips, then loads each directional set
through `Art.dir_set()`. During a one-shot action, `_play_clip()` resolves the
current facing with `Art.dir8_suffix()`, displays the matching strip, locks that
facing for the action, and carries it back into idle.

`Art.dir_set()` can fall back to the south strip when a direction is missing.
That fallback prevents a crash but is not successful wiring. Use
`verify_art.py` and visual QA to prove all eight intended directions exist.

### Oathbound runtime mapping

The current Paladin is wired as:

```text
class sprite base: paladin
a1 Judgment:       attack
a2 Consecration:   attack2
a3 Aegis:          cast
ultimate:          ult
```

Therefore the files generated by `build_oathbound_paladin.py`, such as
`paladin_attack_n.png` and `paladin_attack2_ne.png`, are the files selected by
the live ability animation path.

## 10. Generate contact sheets and perform visual QA

Build the family and create one labeled sheet per clip:

```powershell
python tools/art/build_oathbound_paladin.py
python tools/art/anim_sheet.py paladin all `
  art_src/paladin_oathbound_arbiter/qa_regen 2
```

General form:

```powershell
python tools/art/anim_sheet.py <base> <group-or-clips> <output-dir> <scale>
```

The sheet labels all eight facings down the left and uses 1-based frame labels
across the top. Report defects as `<clip> <direction> f<number>`, for example:

```text
attack N f4: metal hammer head disappears
walk NE f3-f7: the same leg leads through both half-cycles
attack2 N f7: body turns toward camera during recovery
```

### Identity and rendering checklist

- same face, hair, silhouette, armor, palette, and insignia in every frame;
- weapon and shield stay in the correct hands;
- weapon head, shaft, shield edge, head, feet, and cape never vanish;
- camera and projection remain stable;
- material masses stay readable at actual in-game size;
- texture is controlled and not noisy or muddy;
- no chroma fringe, holes, semi-alpha, shadows, labels, or stray fragments;
- no crop or overlap from neighboring generated cells.

### Direction checklist

- S faces the camera/down-screen;
- N faces away/up-screen;
- E and W profiles are not swapped;
- NE and NW are not inverted;
- SE and SW are not inverted;
- rear-quarter rows remain rear-quarter through their last recovery frame;
- mirrored directions follow the documented handedness policy.

The checklist is a **pre-wiring gate**. Put observed facings beside the eight
runtime suffixes in one contact sheet and compare the profile/quarter pairs
side by side. A generator satisfying the requested pose order is not evidence
that the order is correct.

### Motion checklist

Idle:

- loop closes without a jump;
- no large foot sliding;
- breathing is restrained;
- chains, cloth, and equipment settle consistently.

Walk:

- legs perform two visibly alternating steps;
- two highlighted contact frames show opposite feet leading; torso bob alone
  does not count as alternation;
- knees stay low enough to read as walking, not marching;
- feet plant and release rather than slide;
- body bob is subtle;
- equipment secondary motion follows the step rhythm;
- the loop transitions smoothly from f8 to f1.

Run:

- cadence is clearly faster and more committed than walk;
- stride and body lean do not become a march;
- shield/weapon weight remains believable;
- no duplicated or mislabeled rear-quarter row.

Attack/cast/ultimate:

- anticipation, action peak, and recovery are readable;
- weapon remains structurally complete;
- the impact frame matches the gameplay hit window closely enough;
- character keeps the assigned facing through recovery;
- pose returns cleanly toward locomotion;
- FX do not replace or obscure the character unintentionally.

Death:

- body loses balance in a coherent direction;
- no resurrection-like reverse sequence;
- final corpse is fully grounded and fits the cell;
- final frame is suitable for a held/latching death state.

Static contact sheets reveal identity and frame defects. They do not fully
prove cadence, foot sliding, or loop closure. Always perform an in-game QA pass,
and make a GIF/video preview when a cadence problem remains ambiguous.

For asymmetric characters, add a class-specific invariant line to the proof
sheet (for example, “Warrior anatomical-left arm exposed; opposite arm fully
armored”) and inspect it across all frames and all eight directions. Mirroring
is forbidden unless that exact asymmetry is meant to swap on screen.

### Runtime-size benchmark gate

Before wiring, place representative candidate frames beside the approved player
benchmark and a crisp NPC benchmark at the same visible body height used in
game. Review that actual-size row first; a magnified nearest-neighbour row is
secondary diagnostic evidence. Require:

- distinct light, mid, and dark material masses at gameplay size;
- a readable face/hood/helmet and class-defining prop;
- no detail collapse into one narrow dark column;
- no blur from repeated resizing;
- stable silhouette width and garment construction across directions.

High source resolution alone does not pass this gate. If the candidate loses
to the benchmark at runtime size, re-anchor the source generation. Do not try
to recover it with sharpening or enlargement of the installed PNG.

## 11. Repair failure modes at the right layer

### Equipment disappears

Symptom: a hammer head, blade, shield edge, or hand vanishes for one or more
frames.

Check first whether the source itself is missing it or the crop cut it off. If
the source is missing it, generate a direction-locked replacement timeline
with a mandatory equipment-readability criterion. If the source contains it,
fix gutter detection, crop bounds, keying, or staging space.

The Paladin's North Judgment master hid the metal hammer head at impact. A
dedicated seven-frame North regeneration fixed the complete motion rather than
pasting metal over a bad pose.

### Final recovery frame flips direction

Symptom: a rear-facing attack turns toward the camera at its last frame.

Regenerate that full direction with explicit beginning-to-end facing lock.
Mention the last frame by number and describe visible directional evidence:
back of head, rear shield face, shoulders, feet, cloak, and weapon perspective.

The Paladin's NE and N Consecration rows were replaced this way.

### NE and NW are inverted

Do not trust row order or a prompt label. Identify facing from the actual body
and equipment perspective. Correct the source-to-direction mapping. Under the
symmetric convention, approved NE should generate NW by horizontal mirroring;
do not accidentally assign the generated NE row to NW first.

### Legs do not alternate

Replace the walk row with a direction-specific eight-frame generation. State
the foot and gait phase for every frame. Inspect f1↔f5 and f3↔f7 as opposite
halves of the cycle.

Do not “fix” alternation by swapping arbitrary frames. That can reverse body
momentum, shield swing, cloth movement, or camera perspective.

### Walk becomes a march

Add low knee lift, ordinary travel, heel/toe roll, modest bob, and explicit
negative constraints against parade/high-knee motion. A good alternation can
still be the wrong gait.

### Feet slide or body jitters

Distinguish source motion from assembly drift:

- If the body shifts inside a correctly centered frame, regenerate or repair
  the animation timing.
- If crops or figure centers vary because cell boundaries are wrong, fix the
  builder's segmentation and ground anchoring.
- If every frame was independently normalized, change the builder to use one
  reference-derived scale per direction/clip.

### Generated row count is wrong

Visually inventory the real source, slice its actual number of rows, and
explicitly choose the approved rows. Never squeeze two visual rows into one
requested row.

### Adjacent figures or rows touch

Do not let segmentation heuristics invent missing boundaries through a cloak,
staff, bow, or sword. If two generated figures touch or a row boundary clips a
head/prop, reject that row and generate the affected direction as a standalone
strip. Lost pixels cannot be recovered by padding or component selection.

An empty-looking separator is not enough. Prove zero occupancy and a broad
contiguous transparent run, generate a cut overlay, and assert lossless source
pixel accounting. If an old master fails that test, do not silently cut through
visible pixels. Preserve any already approved runtime directions and regenerate
only the unsafe directions.

### Sprite looks lower resolution than another character

Do not merely upscale installed runtime PNGs. That preserves blur, noisy
clusters, and weak material separation.

Full regeneration should:

- use high-resolution source masters;
- request bold readable color masses and controlled detail;
- preserve a larger normalized source body;
- keep gameplay body size unchanged in the loader;
- let Godot downsample a cleaner, denser source.

Judge the result at both source resolution and actual render size. “More detail”
is not automatically more readable; noisy armor texture can look lower quality
than simplified, intentional pixel clusters.

### Chroma bleed or transparent holes

- verify the key color is absent from intended subject pixels;
- despill surviving edge color;
- harden alpha after resizing;
- zero RGB under transparent pixels;
- count semi-transparent pixels;
- inspect over the actual game background color.

If intended green is being erased, change the backdrop or segmentation logic.
Do not keep lowering thresholds until the background survives.

## 12. Import and verify in the required order

After the deterministic build:

```powershell
tools\Godot_v4.4.1-stable_win64_console.exe `
  --headless --path game --import --quit

python tools/art/verify_art.py <base>

.\test_quick.bat
.\test.bat

python tools/sync_mobile.py --apply --gate
python tools/sync_mobile.py
```

The final `sync_mobile.py` call must report no unapproved desktop/mobile drift.

If the Godot editor is open, Windows file contention can cause a transient
write error such as `OSError: [Errno 22]` while replacing a sprite. Retry the
builder/import after the editor releases the file. Do not kill the user's
editor process without permission.

The headless dummy renderer can print leak/resource warnings after a successful
suite. Evaluate the suite's explicit pass marker and verdict logic; do not
declare failure solely from a known shutdown warning.

For an art-only Markdown change, gameplay tests do not need to be rerun. For
any runtime PNG, import metadata, GDScript wiring, or generated catalog change,
run the full applicable sequence.

## 13. Completion criteria

A sprite family is ready for the user's QA pass only when:

- the lore-led identity has been explicitly approved;
- original generated masters are archived under `art_src/`;
- prompts, reference roles, exceptions, and repairs are documented;
- a deterministic builder can reproduce the installed strips;
- all required clips, directions, and frame counts exist;
- strip geometry is valid;
- alpha/chroma checks pass;
- static and animated scale/baseline are stable;
- contact sheets have been inspected frame by frame;
- direction labels and mirrors are correct;
- movement loops have been inspected in motion;
- class/ability/data wiring points to the new base and clips;
- Godot has imported the current files;
- `verify_art.py` passes;
- compile, quick, and full tests pass as required;
- mobile has been synchronized and its gate passes;
- the user has a clear list of remaining manual QA targets.

## 14. Reusable execution checklist

Copy this into a task plan:

```text
[ ] Read CLAUDE.md and inspect git status.
[ ] Read lore and the real runtime loader/consumer.
[ ] Inventory current assets and comparable quality references.
[ ] Define base name, clips, directions, frames, FPS, size, and anchors.
[ ] Write binding identity/equipment/camera/palette invariants.
[ ] Assign an explicit role to every reference image.
[ ] Generate and approve a five-view identity sheet (or asset equivalent).
[ ] Archive the untouched generated original under art_src/<family>/.
[ ] Write frame-by-frame timelines.
[ ] Generate animation masters using the approved identity.
[ ] Inspect actual rows, columns, facings, crop, equipment, and continuity.
[ ] Classify every source row by observed facing before assigning suffixes.
[ ] Generate direction-locked repair rows for failed timelines.
[ ] Implement/update one deterministic family builder.
[ ] Key/despill, slice real gutters, normalize, anchor, mirror, assemble.
[ ] Validate file count, frame count, geometry, alpha, and empty frames.
[ ] Wire data tables and clip mappings.
[ ] Generate labeled contact sheets and inspect every direction/frame.
[ ] Highlight and compare the two opposing walk contacts at runtime size.
[ ] Compare representative frames beside approved player and NPC benchmarks.
[ ] Import in Godot and run verify_art.py.
[ ] Run compile/quick/full tests in repository order.
[ ] Sync mobile with --apply --gate, then prove zero drift.
[ ] Report exact files, mappings, test results, and manual QA targets.
```

## 15. Handoff report template

```text
Outcome:
- <asset> is regenerated and wired as runtime base <base>.

Generated source:
- binding identity: <path>
- animation masters: <paths/pattern>
- repair masters: <paths>
- source documentation: <path>

Runtime contract:
- static: <path>
- clips: <list with frame counts>
- directions: <list and mirror policy>
- ability/data mapping: <mapping>
- rendered body-size behavior: <summary>

Builder:
- <path>
- keying/segmentation/normalization exceptions: <summary>

QA:
- contact sheets: <path>
- verify_art: <result>
- import: <result>
- quick suite: <result>
- full suite: <result>
- mobile gate/parity: <result>

Manual QA focus:
- <specific clips/directions/frames or cadence checks>

Workspace:
- no unrelated files were discarded;
- staging/commit status: <not staged/not committed unless requested>.
```

## 16. What not to do

- Do not call a filtered upscale a full regeneration.
- Do not animate an unapproved identity.
- Do not use another character as an unlabeled identity reference.
- Do not trust ImageGen's requested grid dimensions without inspection.
- Do not cut through a lowest-occupancy valley; production separators must have
  zero occupancy and a broad transparent run.
- Do not delete disconnected components after slicing a character frame.
- Do not assume NE/NW or SE/SW labels from row position alone.
- Do not normalize every animation frame independently.
- Do not solve a disappearing weapon by compositing unrelated poses unless a
  deliberate art-directed repair is truly the best option.
- Do not accept non-alternating walk legs merely because the body moves.
- Do not fix alternation by turning the gait into a march.
- Do not edit `mobile/game/` directly.
- Do not leave source masters only in temporary storage.
- Do not overwrite unrelated dirty-worktree changes.
- Do not stage or commit without the user's request.

## 17. Adapting the pipeline to other asset types

The same pipeline applies beyond player characters:

- **Mobs/bosses:** read the enemy loader; generate only live clips unless
  intentionally building future-ready seams; preserve combat telegraphs.
- **Skins:** identify whether the skin changes identity, silhouette, equipment,
  palette only, or FX; retain the base class's gameplay-readable silhouette.
- **Props/landmarks:** replace directions with object states; lock footprint,
  crop, collision assumptions, and animation-static geometry.
- **Projectiles:** replace ground baseline with a stable visual center and
  flight axis; author directional rotations only if the runtime consumes them.
- **Icons:** replace animation timelines with level/tier progression; specify
  strict cells, small-size readability, and transparent/chroma-safe edges.
- **Terrain animation:** preserve the complete object and change only the
  intended water, fire, machinery, or magical region across frames.

In all cases, retain the reusable backbone:

1. authoritative lore and runtime contract;
2. approved binding identity/state;
3. generation masters with explicit reference roles;
4. deterministic conversion code;
5. labeled visual QA;
6. real-engine import and tests;
7. desktop/mobile parity.
