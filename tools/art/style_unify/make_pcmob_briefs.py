"""P6.2 (POLISH_TASKS.md, 2026-08-19): the Pixel Crawler EXTRA MOBS that still
run on 32px pack sprites (content/pc_extra_mobs.gd: Bloated Dead, Grave
Cutter, Tomb Warden, Sporeling, Wildkin Skirmisher, Gutter Cutter, Warren
Breaker; the Plague Chanter already has its 192px body from the 08-08 repair
pass) -> 192px cast-density bodies through headless Codex ImageGen, in the mob
house style (crisp hi-res dark-fantasy pixel art = the Plague Chanter), then
`tools/art/build_pc_extra_mobs.py` keys, normalizes and installs them
(idle 2x2 -> base + _anim; walk row of 8 -> _walk; attack 2x2 -> _attack).

Two PHASES (the walk/attack briefs need the NEW idle as their binding identity):

  python make_pcmob_briefs.py <stage_root> --phase idle
  ... run_codex_batch over <stage_root>/stages_idle.txt, build --phase idle ...
  python make_pcmob_briefs.py <stage_root> --phase action
  ... run_codex_batch over <stage_root>/stages_action.txt, build --phase action

Refs per stage: 1_style_rat_mage.png (the installed sibling = STYLE + scale
benchmark), 2_identity_<key>.png (the current 32px sprite upscaled 6x nearest =
silhouette / palette / gear identity only; it is NOT the quality target). The
action phase attaches the NEW idle strip as image 1 (binding identity + body
scale) and the identity as image 2. Every master: flat #00ff00 key, LEFT facing,
padded gutters, one shared ground line — the 08-08/08-15 mob-repair contract.
The salvaged tick / verdant / scholar placeholders are OUT of scope on purpose
(retired art "awaiting a home"; regenerate when a zone places them).
"""
import argparse, os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SPR  # noqa: E402
from PIL import Image  # noqa: E402

STYLE_REF = "rat_mage"

# key -> (display name, identity description, gait note, attack storyboard)
MOBS = {
    "zombie_overweight": (
        "Bloated Dead",
        "a hulking BLOATED ZOMBIE in LEFT-facing three-quarter view: grey-green waterlogged skin, a hugely distended round belly hanging over the belt, sagging jowls and a slack open jaw, small purple-glowing sunken eyes, thin patchy hair, torn dark-grey trousers, bare swollen feet, arms hanging heavy with dark bruised hands. No weapon. Slow, heavy, top-heavy.",
        "a heavy SHAMBLE: short dragging steps, the belly sways, shoulders roll, low knee lift, feet barely leave the ground line",
        "ready (arms hanging) -> wind-up (both arms drawn back, belly leaning back) -> STRIKE toward screen-left (a heavy two-handed downward slam, torso lunging left, belly swinging) -> follow-through (arms low, weight settling)"),
    "mummy_rogue": (
        "Grave Cutter",
        "a lean wiry MUMMY TOMB-THIEF in LEFT-facing three-quarter view: the whole body tightly bound in ochre linen wraps with loose trailing strip-ends, a thin bronze circlet across the brow, violet-glowing eyes through a gap in the wraps, a dark-red loincloth over teal wrap strips at the hips, wrapped feet, and TWO short bronze knives held low, one in each hand. Light, quick, hunched forward.",
        "a fast low PROWL: quick short steps, knees bent, torso leaning forward, knives held low and steady, wrap-ends trailing",
        "ready (knives low) -> wind-up (both knives drawn back to the right hip, body coiled) -> STRIKE toward screen-left (a double slash, both blades sweeping left with short pale slash arcs) -> follow-through (knives crossed low, body settling)"),
    "mummy_warrior": (
        "Tomb Warden",
        "a broad heavy MUMMY WARRIOR in LEFT-facing three-quarter view: thick ochre linen wraps over a bulky body, a tall bronze-and-teal pharaonic war-helm crest, violet-glowing eyes, layered teal-and-bronze shoulder guards, a dark-red kilt over the wraps, wrapped shins and feet, and a broad bronze khopesh sword held in the forward (screen-left) hand, its curve low. Solid, guarding, deliberate.",
        "a heavy deliberate MARCH-WALK: measured steps, upright torso, the khopesh carried low and steady, the crest never bobbing more than a few pixels",
        "ready (khopesh low) -> wind-up (khopesh raised high behind the helm) -> STRIKE toward screen-left (a broad diagonal downward chop with a short dull-bronze arc) -> follow-through (blade low past the feet, shoulders turned)"),
    "fungus_immature": (
        "Sporeling",
        "a small squat MUSHROOM CREATURE in LEFT-facing three-quarter view: a wide orange-brown cap flecked with pale spots draped like a hood over a stubby pale-tan stalk body, two short stubby legs with flat feet, NO arms, a dark slit of a mouth in shadow under the cap. About half the height of a man. Twitchy, simple, comic-grim.",
        "a quick stubby WADDLE: tiny alternating steps on the two short legs, the cap tilting slightly side to side, body bobbing a few pixels",
        "ready (still) -> wind-up (cap tipping back, body leaning back) -> STRIKE toward screen-left (a headbutt/cap-butt lunge left with a puff of pale spores off the cap edge) -> follow-through (recoiling, cap dipping forward)"),
    "elf_wild": (
        "Wildkin Skirmisher",
        "a lean barefoot WILD ELF in LEFT-facing three-quarter view: long moss-green hair falling around the face, a crown of pale antler-like branch tines rising from the head, a cream-and-green tunic belted with cord, blue tribal face markings, bare arms and bare feet, a small green stone pendant, and a short bone-tipped hunting spear held low in the forward hand. Wiry, wary, quick.",
        "a light springy STALK: quiet quick steps, weight low, spear held level and low, hair and tunic hem swinging softly",
        "ready (spear low) -> wind-up (spear drawn back past the hip, torso twisted) -> STRIKE toward screen-left (a fast forward thrust, arm and spear extended fully left, front foot planted) -> follow-through (spear withdrawing, weight settling back)"),
    "rat_rogue": (
        "Gutter Cutter",
        "a hunched grey RATMAN CUTPURSE in LEFT-facing three-quarter view: mangy grey fur, a long pink naked tail, red-glowing beady eyes, a dirty brown hooded cloak with the hood UP, patched dark trousers, wrapped feet, and a small rusty knife held low and reversed in the forward hand. Low, skittering, furtive.",
        "a low fast SCURRY: quick short bent-knee steps, body hunched near the ground, tail trailing, knife held low and steady",
        "ready (knife low, hunched) -> wind-up (knife pulled back beside the ribs, body coiled lower) -> STRIKE toward screen-left (a quick low stab-and-slash left, arm fully extended, tail whipping) -> follow-through (darting back, knife low)"),
    "rat_warrior": (
        "Warren Breaker",
        "a bulky grey RATMAN BRAWLER in LEFT-facing three-quarter view: heavy grey fur, a thick pink tail, red-glowing eyes and bared yellow teeth, a patched blue-purple leather jerkin with a brown hood-scarf pushed back, a rusted iron cleaver-axe held in the forward hand and a small round wooden buckler on the other arm, wrapped feet. Big, angry, forward-leaning.",
        "a heavy forward-leaning STOMP-WALK: strong short steps, shoulders swinging, cleaver carried low, buckler up by the chest, tail swinging opposite the stride",
        "ready (cleaver low, buckler up) -> wind-up (cleaver raised high and back over the shoulder) -> STRIKE toward screen-left (a savage overhead chop coming down and left with a short rust-brown arc, buckler swung back) -> follow-through (cleaver buried low left, body leaning over it)"),
}

COMMON_HEAD = """You are generating ONE game sprite animation master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.
"""

STYLE_LINE = "Style/medium: crisp high-resolution dark-fantasy pixel art with hard readable pixel clusters and a controlled MUTED palette (exactly the treatment of Image 1, the installed Plague Chanter sibling) — not painterly, not 3D, not anime, no black outlines thicker than one pixel, no bright saturated colours, no gold trim, no glow except the stated eye glow."

BACKDROP = "Scene/backdrop: a perfectly flat uniform #00ff00 chroma-key background filling every pixel, including the gaps between figures. No scenery, floor plane, ground, platform, cast shadow, contact shadow, gradient, vignette, border, grid, line, panel divider, text, frame numbers or watermark. Do not use #00ff00 or any strong green in the figure."

IDLE_BRIEF = COMMON_HEAD + """
Two images are attached to this prompt:
- Image 1 = refs/1_style_{style_ref}.png : the STYLE, quality, perspective and BODY-SCALE benchmark — an installed sibling mob (the Plague Chanter) drawn at production resolution. Match its pixel treatment, palette restraint, LEFT-facing three-quarter view and the share of the canvas its body fills. It is NOT the design.
- Image 2 = refs/2_identity_{key}.png : the CURRENT tiny (32px, upscaled) sprite of the {name} — silhouette, palette and gear IDENTITY only. Its chunky pixels are NOT the quality target; redraw the same creature at Image 1's resolution and quality.

TASK: generate exactly ONE new source sheet — a 2x2 GRID of FOUR complete figures — for the {name}'s IDLE (breathing) loop with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint). Use the tool's SQUARE output size.

---
Use case: illustration-story
Asset type: high-resolution 4-frame game sprite idle-loop source, a 2x2 grid of four complete figures, to be cropped into a horizontal sprite strip. Square output canvas.
Input images: Image 1 is the binding style / resolution / body-scale benchmark; Image 2 is the creature's identity reference (silhouette, palette, gear).
{backdrop}
Primary request: create exactly FOUR complete figures in a 2x2 grid (two rows of two), each figure fully inside its own quadrant with a clear flat-green gutter to every neighbour and to the canvas edge. All four figures share identical scale, framing and, per row, one shared invisible ground line. They are four consecutive frames of ONE subtle idle breathing loop: f1 rest, f2 inhale (chest and shoulders rise a few pixels, held items lift a hair), f3 peak (slight settle of cloth/tail/wraps), f4 exhale (back toward rest) — the head, feet, facing, height and ground point stay locked; nothing steps, turns or changes size.
Subject: {desc}
{style}
Composition/framing and ANCHOR RULE: all four figures face LEFT in the same three-quarter view as Image 1, standing at the same full height with the feet on the row's shared ground line. The camera never moves. Body fills roughly the same share of its quadrant as Image 1's figure fills its canvas.
Constraints: output only the four figures on green; no text, watermark, UI, extra characters, scenery, shadow or separators. Same gear in the same hands in every figure; do not add or drop limbs; do not duplicate a figure exactly; do not crouch or shrink the body.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{key}_idle_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{key}_idle_master_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message, report: the raw output size, how many complete figures were produced, whether each sits wholly inside its quadrant with a clear gutter, whether the four differ only by a subtle breath (no step, no turn, no size change), the facing, and any deviation from the brief (extra limbs, gear that changes hands, a figure touching the canvas edge or a neighbour, green in the figure). Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

WALK_BRIEF = COMMON_HEAD + """
Two images are attached to this prompt:
- Image 1 = refs/1_idle_{key}.png : the BINDING identity, palette, pixel-art treatment AND body-scale reference — a horizontal 4-frame strip of square cells of the {name} standing at rest, facing LEFT. Match the figure, its proportions, gear and palette precisely; every walk frame must show it at the SAME full standing height as in Image 1 (head at the same height, same torso size) — it must not crouch, hunch or shrink.
- Image 2 = refs/2_identity_{key}.png : secondary identity reference (the old tiny sprite; silhouette/palette only).

TASK: generate exactly ONE new horizontal source sheet — ONE ROW of EIGHT figures — for its WALK cycle with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint). Use the tool's widest LANDSCAPE output size.

---
Use case: illustration-story
Asset type: high-resolution 8-frame game sprite walk-cycle source, one horizontal row, to be cropped into a horizontal sprite strip. Landscape output canvas.
Input images: Image 1 (4-frame idle strip) is the binding identity, palette, pixel-art treatment and body-scale reference; Image 2 is a secondary identity reference.
{backdrop}
Primary request: create exactly EIGHT complete figures in ONE horizontal row, left to right, evenly spaced with a clear flat-green gutter between neighbours. Each figure is one consecutive frame of ONE natural two-step walk cycle. No figure may touch, overlap, or be cropped by its neighbour or by the canvas edge. All eight figures share identical scale, framing and ground line.
Subject: {desc} Same identity, proportions, palette and body scale as Image 1.
{style}
Composition/framing and ANCHOR RULE: all eight figures face LEFT and stand on ONE shared invisible ground line at the same height: every foot that is on the ground stands on that line. The camera never moves. The pelvis and torso stay at the same height in every figure except for a very slight bob (a few pixels); the head stays at the same height. Gait character: {gait}. Feet plant and do not slide.
WALK storyboard — one coherent two-step loop; the NEAR leg is the leg closer to the camera, the FAR leg is the other:
 f1 NEAR-foot contact: near leg planted forward toward screen-left; far leg trailing behind, toe on the ground.
 f2 NEAR-foot load: weight rolls onto the flat near foot; far heel lifts, far knee begins to bend.
 f3 FAR leg passes: the far leg swings forward past the planted near leg with a low knee, far foot lifted a few pixels off the ground; legs close together.
 f4 NEAR-foot push, FAR-foot reaching forward: far leg extended forward, far heel about to touch the ground; near heel lifting behind.
 f5 FAR-foot contact: far leg planted forward toward screen-left; near leg trailing behind, toe on the ground — the OPPOSITE leg leads compared with f1.
 f6 FAR-foot load: weight rolls onto the flat far foot; near heel lifts, near knee begins to bend.
 f7 NEAR leg passes: the near leg swings forward past the planted far leg with a low knee, near foot lifted a few pixels off the ground; legs close together.
 f8 FAR-foot push, NEAR-foot reaching forward: near leg extended forward, near heel about to touch the ground; far heel lifting behind — flowing back into f1.
Held items stay in the same hands; the arms swing gently opposite to the legs (or hang heavy if the creature's gait says so).
Constraints: output only the eight figures on green; no text, watermark, UI, frame numbers, extra characters, scenery, floor artifact, shadow or separators. Natural gait, not a march, parade step, high-knee run, or standing poses. Do not recolor the legs, do not detach a foot, do not duplicate a figure, do not crouch or shrink the body. f1 and f5 must have OPPOSITE legs leading; f3 and f7 must show OPPOSITE legs passing.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{key}_walk_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{key}_walk_master_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message, report: the raw output size in pixels, how many complete figures were produced, and figure by figure WHICH leg leads / whether f1 vs f5 and f3 vs f7 show opposite legs, whether the body height matches Image 1, and any deviation from the brief (a body that changes size, a foot off the ground line, extra limbs, wrong facing, an identical pair of figures, figures touching each other or the canvas edge). Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

ATTACK_BRIEF = COMMON_HEAD + """
Two images are attached to this prompt:
- Image 1 = refs/1_idle_{key}.png : the BINDING identity, palette, pixel-art treatment AND body-scale reference — a horizontal 4-frame strip of square cells of the {name} standing at rest, facing LEFT. Match the figure, its proportions, gear and palette precisely; the ready pose must show it at the SAME full standing height as in Image 1.
- Image 2 = refs/2_identity_{key}.png : secondary identity reference (the old tiny sprite; silhouette/palette only).

TASK: generate exactly ONE new source sheet — a padded 2x2 GRID of FOUR complete poses — for its ATTACK with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint). Use the tool's SQUARE output size.

---
Use case: illustration-story
Asset type: high-resolution 4-frame game sprite attack source, a 2x2 grid of four complete poses, to be cropped into a horizontal sprite strip. Square output canvas.
Input images: Image 1 (4-frame idle strip) is the binding identity, palette, pixel-art treatment and body-scale reference; Image 2 is a secondary identity reference.
{backdrop}
Primary request: create exactly FOUR complete poses in a 2x2 grid (two rows of two), each pose fully inside its own quadrant with a clear flat-green gutter to every neighbour and to the canvas edge — a raised weapon or the strike arc must ALSO stay inside its quadrant. All four share identical scale and, per row, one shared invisible ground line; the planted foot / ground point and the torso position stay locked (only the striking limbs and gear travel).
Subject: {desc} Same identity, proportions, palette and body scale as Image 1.
ATTACK storyboard, facing LEFT (the strike travels toward screen-left): {attack}.
{style}
Composition/framing and ANCHOR RULE: all four poses face LEFT in Image 1's three-quarter view; the ready pose stands at exactly Image 1's height. The camera never moves. Any slash arc is a short, dull, low-contrast streak of the weapon's own colour — not a bright magic effect.
Constraints: output only the four poses on green; no text, watermark, UI, frame numbers, extra characters, scenery, shadow or separators. Same gear in the same hands in every pose; the strike goes LEFT (never right, never up-only); do not add or drop limbs; do not duplicate a pose; the whole face/head/tail/gear must be contained in each quadrant.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{key}_attack_master_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{key}_attack_master_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message, report: the raw output size, how many complete poses were produced, whether each pose (including any raised weapon or arc) sits wholly inside its quadrant with a clear gutter, whether the strike travels LEFT, whether the ready pose matches Image 1's height, and any deviation from the brief. Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""


def _identity_ref(key: str, dst: str) -> None:
    im = Image.open(os.path.join(SPR, key + ".png")).convert("RGBA")
    if im.width < 100:
        im = im.resize((im.width * 6, im.height * 6), Image.NEAREST)
    im.save(dst)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--phase", choices=["idle", "action"], default="idle")
    ap.add_argument("--only", default="", help="comma list of keys")
    args = ap.parse_args()
    keys = [k for k in MOBS if not args.only or k in args.only.split(",")]
    stages = []
    for key in keys:
        name, desc, gait, attack = MOBS[key]
        if args.phase == "idle":
            stage = os.path.join(args.root, key + "_idle")
            refs = os.path.join(stage, "refs")
            os.makedirs(refs, exist_ok=True)
            shutil.copy(os.path.join(SPR, STYLE_REF + ".png"),
                        os.path.join(refs, "1_style_%s.png" % STYLE_REF))
            _identity_ref(key, os.path.join(refs, "2_identity_%s.png" % key))
            with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
                f.write(IDLE_BRIEF.format(style_ref=STYLE_REF, key=key, name=name, desc=desc,
                                          backdrop=BACKDROP, style=STYLE_LINE))
            stages.append(stage)
        else:
            idle_strip = os.path.join(SPR, key + "_anim.png")
            if not os.path.exists(idle_strip):
                print("SKIP %s: no installed idle strip yet" % key)
                continue
            for clip, brief in (("walk", WALK_BRIEF), ("attack", ATTACK_BRIEF)):
                stage = os.path.join(args.root, "%s_%s" % (key, clip))
                refs = os.path.join(stage, "refs")
                os.makedirs(refs, exist_ok=True)
                shutil.copy(idle_strip, os.path.join(refs, "1_idle_%s.png" % key))
                _identity_ref(key, os.path.join(refs, "2_identity_%s.png" % key))
                with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
                    f.write(brief.format(key=key, name=name, desc=desc, gait=gait, attack=attack,
                                         backdrop=BACKDROP, style=STYLE_LINE))
                stages.append(stage)
    lst = os.path.join(args.root, "stages_%s.txt" % args.phase)
    open(lst, "w").write(",".join(stages))
    print("stages (%s): %d -> %s" % (args.phase, len(stages), lst))


if __name__ == "__main__":
    main()
