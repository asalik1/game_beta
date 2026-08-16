#!/usr/bin/env python
"""Act 1 boss Codex-regeneration brief library + emitter.

Every Act 1 boss already has an owner-approved design installed as
`<sprite>_anim.png`; we re-animate THAT design in the Codex 2x2 pipeline rather
than redesign it. So each brief passes the installed idle + static as the
binding identity reference, and only supplies the per-clip MOTION storyboard.

All Act 1 bosses are FRONT-FACING (south) humanoids/beasts (or a seated saint /
floating elemental) — symmetric, no profile leg-cycle. Clips are stationary
casts/swings, so the same front-facing arcs work across archetypes; identity
comes from the reference image, alignment from `--anchor bbox` at build time.

CLI:  python tools/art/act1_brief_lib.py <boss_kind> <clip> <staging_dir>
      -> writes <staging_dir>/codex_brief.txt and copies refs/ (idle+static)
Boss/clip tables are the single source of truth for the run (see also
art_src/bosses_codex_wave1/ACT1_PROGRESS.md).
"""
from __future__ import annotations
import os, shutil, sys

SPR = r"C:\Users\asali\Projects\MMO\game\assets\sprites"

# kind -> (sprite, identity one-liner, body: 'humanoid'|'seated'|'floating'|'beast')
BOSSES = {
    "vargoth": ("vargoth", "an armored hollow king in dark plate and a tattered dark cape, a horned crowned helm, wielding a large flaming greatsword in both hands", "humanoid"),
    "stormwarden": ("korrag", "a huge broken storm-giant in battered plate with curved horns, crackling with blue lightning, a long heavy chain-whip in one hand", "humanoid"),
    "choirmother": ("choirmother", "a tall hooded figure in a deep blue and gold layered choir robe, face lost in the hood, hands in wide draping sleeves", "humanoid"),
    "nullwarden": ("nullwarden", "a colossal faceless sentinel in heavy dark plate armor, cold blue null-light glowing in the armor seams, holding a massive greatsword", "humanoid"),
    "sexton": ("sexton", "a gaunt cloaked gravedigger with a bare skull face under a wide black brimmed hat, a long curved scythe in one hand and a glowing green lantern in the other", "humanoid"),
    "vess": ("vess", "a tattered grey widow in a torn mourning veil and ragged gown, a gaunt pale sorrowful face, thin arms spread", "humanoid"),
    "saint_varo": ("saint_varo", "a skeletal crowned saint seated and fused into an ornate gold reliquary throne, purple and gold vestments, the lower body part of the throne", "seated"),
    "forgemistress": ("forgemistress", "a dark sorceress-queen in a black and red gown with a crown of live orange flame, braziers of fire flanking her", "humanoid"),
    "ashpriest": ("ashpriest", "a robed molten high priest in a horned iron helm and dark layered robes edged with glowing fire, holding a heavy censer-mace", "humanoid"),
    "whitepelt": ("hrolgar", "a towering snarling berserker draped in a shaggy white wolf pelt with antlers on the hood, gripping a huge two-handed axe", "beast"),
    "icebound": ("serane", "an ice queen in a tall crown of jagged icicles and a frozen pale-blue robe, a cold frost aura, arms spread", "humanoid"),
    "sleepkeeper": ("halla", "a hooded moth-witch with large pale patterned moth wings, holding a single lit candle, white butterflies drifting around her", "floating"),
    "auroch": ("auroch_minotaur", "a huge drowned minotaur with massive curved horns and a heavy bull skull, waterlogged grey hide, gripping a great rusted axe", "beast"),
    "gardener": ("rotmaw", "a hunched rotted gardener-revenant hung with dead vines and roots, pale bloated grey flesh, long clawed hands", "humanoid"),
    "curetwisted": ("kaethra", "a lean masked figure with a pale bone mask and wrapped torso, SIX arms each holding a thin dagger, a ragged red loincloth", "humanoid"),
    "veyx": ("veyx", "a small floating storm elemental — a compact humanoid figure formed of crackling blue lightning and dark storm-cloud, trailing off into vapour with no solid legs", "floating"),
    "echo": ("echo", "a winged dark assassin with a burning skull head wreathed in orange flame, large black feathered wings, dark leathers, a knife in hand", "humanoid"),
    "stormmouth": ("stormmouth", "a colossal armored storm-titan with a bright blue glowing core set in its chest, huge horned helm and heavy plated shoulders, arcs of lightning", "humanoid"),
}

# --- Directional attacks (owner 2026-08-15): aimed clips need a facing. We
# generate S (front), N (back), E (right profile); the build mirrors E->W and
# copies E->{ne,se}, W->{nw,sw}. Projectiles/telegraphs are drawn by the GAME,
# never baked into the sprite (owner: choirmother's drawn bolt). ---
FACING = {
    "s": "The character faces the CAMERA in the SAME front view as Image 1 (we see its face/front). Its attack drives forward toward the BOTTOM of the frame (toward the viewer).",
    "n": "BACK VIEW — MANDATORY IN ALL FOUR CELLS: the character has turned around and faces directly AWAY from the camera. We see ONLY its back: the BACK of its head/helm/hood/horns/crown, the back of its shoulders, spine, cape and heels. Its FACE IS NOT VISIBLE in any frame (no eyes, no front of the face) — if you can see the face you have drawn the wrong view. It is the exact same character, gear and palette as Image 1, rotated 180 degrees so its front points UP into the screen, away from us. Its attack drives forward toward the TOP of the frame (away from the camera); arms/weapon reach up-and-away.",
    "e": "The character is shown in full RIGHT-SIDE PROFILE, turned to face the RIGHT edge of the frame (we see its right side, its front pointing right). It is the exact same character, gear and palette as Image 1, rotated 90 degrees to face right. Its attack drives forward toward the RIGHT edge.",
}
# --- WALK cycle (owner 2026-08-15): the deferred piece. 4-frame directional
# walk; the FACING clause sets which way it travels. Legs must ALTERNATE (the
# classic bipedal-walk failure is a march / a leg that never leads) and feet
# must PLANT, not slide. Robed/legless bodies (glide=True) move by cloth sway +
# bob instead of a leg cycle. ---
WALK = ("left-foot CONTACT: the near (left) leg reaches forward and plants heel-first in the travel direction, the far (right) leg trailing back on its toe, body at mid height, weapon/arms swinging naturally to counter the stride",
        "PASSING (right leg): the right leg swings forward UNDER the body past the left, knees close together, the body at its highest point of the step, weight over the planted left foot",
        "right-foot CONTACT: the far (right) leg now reaches forward and plants in the travel direction, the left leg trailing back — the clear MIRROR of frame 1, opposite legs leading, body at mid height",
        "PASSING (left leg): the left leg swings forward under the body past the right, knees close, body at its highest again, weight over the planted right foot — flowing back into frame 1",
        "This is ONE continuous two-step walk cycle, not four standing poses. The legs must VISIBLY ALTERNATE — frame 1 and frame 3 are opposite (left leads vs right leads). Ordinary grounded travel: low knee lift, a small vertical body bob, feet that PLANT and push (never sliding or hovering). NO march, parade step, high-knee, or run. Keep the head, torso, gear and weapon continuous; the whole body TRAVELS in the facing direction across the loop but stays centred in each cell (the game moves it).")
WALK_GLIDE = ("neutral glide: the robe/body drifts in the travel direction, hem and cloth trailing slightly back, a gentle downward settle",
              "rise: the body lifts a few pixels (a slow hovering bob up), robe folds lifting, cloth streaming back from the travel direction",
              "neutral glide: back to mid height, hem and sleeves sweeping with the drift, a small opposite cloth sway",
              "settle: the body eases back down, cloth settling, flowing back into frame 1",
              "This body GLIDES/hovers — it has no visible walking legs. Communicate travel ONLY through cloth flutter, hem drift, sleeve sway and a slow vertical bob, all trailing back from the travel direction. Show NO stepping legs, NO feet, NO stride. Keep the head, torso and gear continuous and centred in each cell.")

# The one rule that fixes the "literal bolt" note — appended to every directional brief.
NO_PROJECTILE = ("PROJECTILE RULE (critical, overrides any effect mentioned in the storyboard): the "
    "game engine draws every bolt, orb, beam, ray, cone, ring, wave, spawned creature, ground "
    "zone and telegraph SEPARATELY. This sprite must show ONLY the character's body motion — the "
    "wind-up, the swing/thrust/cast gesture, and the follow-through. A faint SMALL glow or spark "
    "right AT the hand, weapon-tip or mouth at the moment of release is allowed, but do NOT draw "
    "any projectile, bolt, orb, beam, ray, cone, ring, wave or effect leaving the body, flying, "
    "traveling through the air, or landing anywhere. Nothing detached from the character.")

# Per-clip fps override mirror of Balance.BOSS_ACTION_FPS intent (documentation only).
SLOW = {"charge": 7.0, "leap": 5.0, "pack": 6.0, "enrage": 6.0, "surface": 6.0,
        "blink": 10.0, "summon": 8.0, "toll": 8.0, "hymn": 7.0, "shift": 8.0}

# Front-facing 4-frame arcs. "the boss" = whatever Image 1 shows. Each is
# (windup, gather, release_peak, recover, extra). The projectile/telegraph of a
# _strike move is added by the game — we only animate the caster's gesture.
ARM = "both arms"
VERB = {
    "idle": ("a restrained standing idle: neutral rest pose exactly like Image 1",
             "a small inhale — chest and shoulders lift a few pixels, cloth/armor settling",
             "neutral rest again with a faint sway and a small shift of any hanging cloth, chain, flame or aura",
             "a small exhale, everything settling back to the rest pose",
             "Keep the pose, silhouette, weapon and palette continuous and centred — this is a breathing loop, not four different poses; nothing slides sideways."),
    "attack": ("wind-up: weight settling, the weapon or casting hand drawing back a little",
               "gather: the weapon cocked back or the hand gathering a small charge of its signature energy",
               "strike: a committed forward attack toward the viewer — weapon swung down-forward or the hand thrust out with a compact burst of the boss's signature energy, never touching a cell edge",
               "recover: the weapon/hand returning toward rest",
               "The strike frame must be the clearly biggest, most-committed pose."),
    "enrage": ("wind-up: the boss hunches slightly, head dipping, its glow/flame/aura beginning to brighten",
               "swell: head rearing back, arms/shoulders flaring outward, the signature glow flaring much brighter",
               "ROAR: head thrown back roaring, arms/weapon flung wide, every glowing element (flame, lightning, null-light, frost, eyes) blazing at its brightest, silhouette at its widest",
               "settle: coming back down toward rest, the glow dimming to normal",
               "No projectile leaves the body — this is a self-buff transformation; only pose and brightness change."),
    "bolt": ("wind-up: turning toward the viewer, one hand drawing back to the hip, a small spark of the boss's signature energy forming in the palm",
             "gather: that hand cocked back, the energy compacting into a bright compact orb",
             "cast: the hand thrust forward toward the viewer releasing a single compact bolt of the signature energy just off the fingertips, never touching a cell edge",
             "recover: the arm lowering, a few motes fading",
             "One hand casts; the other stays near the body. The bolt stays small and near the hand."),
    "cast": ("wind-up: both hands rising to chest height, fingers spreading, a faint charge kindling between them",
             "weave: the hands weaving apart, a growing lattice/orb of the signature energy forming between the palms",
             "channel: the hands framing a bright compact channelled mass of energy in front of the chest, arms tensed, energy at its brightest, contained and not touching a cell edge",
             "release: the hands opening outward as the channelled energy disperses into fading motes",
             "A two-handed channel in front of the chest; the body stays planted."),
    "ring": ("wind-up: hands drawn in against the chest, elbows tucked, a small charge cupped between them",
             "open: both arms opening outward to the sides at chest height, a thin faint ring of the signature energy beginning to form around the waist",
             "BURST: both arms flung fully out to the sides (a wide T), a clear compact ring of the signature energy expanding outward around the boss at waist height, drawn as a horizontal ellipse passing in front of the lower body and behind the back, about 1.5x the arm span, not touching any cell edge",
             "recover: arms lowering to a low open V, the ring gone, a few motes fading at waist height",
             "The ring is radial (all directions), centred on the boss."),
    "summon": ("wind-up: head bowing, both hands lowering together in front of the waist, palms up",
               "raise: both arms sweeping upward and outward to shoulder height, palms up, a beckoning gesture, the signature energy gathering around the raised hands",
               "CALL: both arms raised high overhead in a wide V, head lifting, a bright pulse/flare of the signature energy bursting from the raised hands and upward, staying above the hands and not touching the top edge",
               "recover: the arms lowering back to a low diagonal as the flare fades",
               "An upward beckoning call; the spawned creatures are added by the game."),
    "slam": ("wind-up: weight loading back, the weapon or both fists raised high overhead, body coiling",
             "peak: weapon/fists at the very top of the wind-up, body stretched tall, about to come down",
             "SLAM: the weapon or both fists driven hard straight DOWN in front of the boss, body dropped low over the impact, a small burst of the signature energy at the point of impact near the ground, not below the cell",
             "recover: rising back up from the slam, weapon/hands lifting away from the ground",
             "The ground fissure/shockwave is added by the game; keep the feet planted."),
    "beam": ("wind-up: both hands coming up and forward, aimed toward the viewer, a bright point kindling at the fingertips/muzzle",
             "charge: the hands/head drawn back, the point swelling into a bright compact node, the whole body tensing",
             "FIRE: a short thick beam of the signature energy projected forward toward the viewer from the hands or the face/core, no longer than one body-width, compact and not touching a cell edge",
             "recover: the beam gone, the hands lowering, residual glow fading",
             "A short forward beam, not a thin line to the edge; body planted."),
    "storm": ("wind-up: head tipping up, both arms beginning to rise, the sky-energy gathering at the fingertips",
              "gather: both arms raised to shoulder height and spread, lightning/storm energy crackling between the raised hands and around the head",
              "CALL: both arms flung fully overhead, head back, a bright burst of lightning/storm energy erupting from the hands and upward, staying above the body and not touching the top edge",
              "recover: arms lowering, arcs of energy dying down around the shoulders",
              "An upward storm-call; the falling strikes are added by the game."),
    "lash": ("wind-up: the whip/tendril/lashing arm drawn fully back to one side, body coiling that way",
             "coil: the whip/arm wound back at maximum, the far end trailing, body torqued",
             "LASH: the whip/tendril/claw whipped across forward toward the viewer at full extension, body uncoiling into the strike, the lash reaching out but not touching a cell edge",
             "recover: the whip/arm trailing back down after the strike",
             "A single sweeping lash across the front; keep the feet planted."),
    "throw": ("wind-up: the throwing arm cocked fully back over the shoulder, a projectile (dagger/fire/debris) gathered in the hand",
              "load: arm at maximum cock, body wound back, the held projectile bright and ready",
              "THROW: the arm snapped forward toward the viewer, the projectile just leaving the hand out in front, body following through, projectile not touching a cell edge",
              "recover: the throwing arm following through low across the body",
              "One projectile leaves the hand on the throw frame; body planted."),
    "blink": ("solid: the boss standing in its rest pose, edges just beginning to shimmer with the signature energy",
              "dissolving: the body half-dissolved into streaks/motes of the signature energy, still recognizable, thinning from the edges inward",
              "scatter: the boss almost entirely scattered into a column of drifting energy/mist, only a faint core and its head-marker remaining",
              "reforming: the body two-thirds re-condensed out of the energy back toward the rest pose, edges still wisping",
              "A vanish-and-reappear flicker in place; the head/crown stays at a fixed point across all four frames as the anchor."),
    "freeze": ("wind-up: arms drawing in across the chest, a pale frost charge gathering, breath misting",
               "gather: arms crossed tight over the chest, a bright compact core of frost energy building at the chest, frost creeping onto the arms",
               "NOVA: arms flung open wide, a compact ring/burst of pale frost and ice shards erupting outward around the boss, sharp and bright, not touching a cell edge",
               "recover: arms lowering, the frost burst fading to drifting flakes",
               "An outward frost nova centred on the boss; body planted."),
    "hymn": ("wind-up: hands rising to clasp together at the chest, head bowing, a soft pale glow at the throat/hands",
             "sing: hands clasped at the chest or spread slightly, head lifting, pale concentric rings of sound-glow beginning to pulse outward from the mouth/chest",
             "SWELL: head back, mouth open in song, bright pale concentric rings of the hymn radiating outward around the upper body, widest and brightest, not touching a cell edge",
             "settle: head lowering, the rings fading, hands returning to a clasp",
             "A sung sonic pulse from the chest/mouth; body planted, restrained and mournful."),
    "wail": ("wind-up: head dipping, hands rising toward the face, mouth beginning to open",
             "draw: head tilting back, mouth opening wider, thin pale sonic streaks starting at the mouth",
             "WAIL: head thrown fully back, mouth wide in a scream, a cone/burst of pale grief-sound streaking outward and forward from the mouth, sharp and bright, not touching a cell edge",
             "recover: head coming down, mouth closing, the sound fading",
             "A screaming sonic burst from the mouth; body planted."),
    "rain": ("wind-up: head bowing, both hands low and cupped in front of the waist, palms up, a small charge pooling",
             "gather: both arms rising to shoulder height, palms turning up to the sky, sleeves sliding back, the signature motes lifting off the palms",
             "CALL: both arms raised fully overhead in a wide V, palms to the sky, a compact spray of the signature motes/embers shooting UPWARD from both hands, staying close above the hands and not touching the top edge",
             "recover: arms lowering to a low diagonal, a few motes drifting down around the shoulders",
             "An upward call-down summon; the falling zones are added by the game."),
    "verdict": ("wind-up: the boss drawing itself up tall and straight, weapon/censer raised, head high in judgement",
                "declare: one arm/weapon thrust straight up overhead, the other extended forward toward the viewer, the signature energy blazing along it",
                "JUDGE: the raised arm/weapon slamming down to point straight forward at the viewer, a compact vertical pillar/flash of the signature energy erupting at the pointed spot in front, not touching a cell edge",
                "recover: the arm lowering, the pillar fading, the boss straightening",
                "A pointed condemning gesture; the pillar/zone is added by the game."),
    "blade": ("wind-up: the greatsword drawn back and raised, both hands on the hilt, body coiling",
              "raise: the sword lifted high overhead point-up, energy running up the blade, head lifting",
              "CALL: the sword swept in a bright overhead arc and thrust up to the sky, a flare of blades/energy bursting upward off the tip, staying above the body and not touching the top edge",
              "recover: the sword coming back down toward a guard, the flare fading",
              "An upward blade-call; the falling swords are added by the game; feet planted."),
    "pack": ("wind-up: chest swelling, head level, jaws/mouth beginning to part, weapon lowered",
             "lift: head and chest rising, mouth opening, arms/weapon dropping to the sides",
             "HOWL: head thrown fully back, mouth wide in a roaring howl, chest thrust out, arms spread, the loudest widest pose",
             "settle: head coming back down, mouth closing, chest relaxing",
             "A summoning howl/roar; the pack is added by the game; feet planted."),
    "charge": ("alert: the boss lowering into a forward-leaning ready stance, weapon/claws forward, head low toward the viewer",
               "crouch: deeper crouch, weight gathered back, body coiled to spring toward the viewer, weapon cocked",
               "LUNGE: the boss exploding forward toward the viewer — body low and stretched forward, leading foot/paw planted forward, weapon/claws thrust out ahead, the most committed forward pose",
               "recover: settling out of the lunge back toward a ready stance",
               "A forward charge toward the camera; keep at least one foot on the shared ground line each frame; no dust or motion blur."),
    "melee": ("wind-up: the weapon or claws drawn back to one side, weight loading, head fixed on the viewer",
              "cock: weapon/claws fully cocked back, body wound for the swing",
              "SWING: a big committed swing across the front toward the viewer, weapon/claws sweeping through at full extension, body following through, reaching out but not touching a cell edge",
              "recover: the weapon/arm trailing through and returning toward guard",
              "A single heavy melee swing; feet planted."),
    "quench": ("wind-up: both hands/weapon raised, molten energy gathering, head high",
               "peak: arms at the top of the wind-up, a bright pool of molten energy gathered overhead or at the hands",
               "PLUNGE: the hands/weapon driven straight down in front, a burst of steam and molten sparks erupting at the low point of the plunge, compact and not below the cell",
               "recover: rising back up out of the plunge, steam curling away",
               "A downward molten plunge; the steam/lava is mostly added by the game; feet planted."),
    "piston": ("wind-up: one armored arm/fist drawing back with a mechanical hitch, plates parting, null-light gathering at the joint",
               "load: the arm fully retracted, the fist/plate glowing bright at maximum wind-up, body braced",
               "THRUST: the armored fist/piston-arm driven straight forward toward the viewer at full mechanical extension, a compact burst of null-light at the fist, not touching a cell edge",
               "recover: the arm retracting back with a settling of the plates",
               "A single mechanical piston-thrust of one arm; body planted, heavy and rigid."),
    "surface": ("buried: only the top of the head/hat and hands breaking an implied ground line at mid-cell, the rest of the body below and hidden, dark earth-motes around the break",
                "rising: the head, shoulders and upper chest risen above the line, arms coming up, lower body still hidden/wisping into dark motes",
                "emerged: the whole body risen into the standing rest pose, weapon in hand, a last ring of earth-motes falling away around the feet",
                "set: the full standing rest pose exactly like Image 1, motes gone",
                "A rise-from-the-ground entrance; the head stays at a fixed x across all frames (the anchor); the body grows upward frame to frame."),
    "toll": ("wind-up: one arm drawing back holding a heavy hand-bell (or gripping the throne's bell-pull), the other hand raised",
             "pull: the arm cocked fully back, the bell lifted, body leaning into the coming swing",
             "TOLL: the arm swung forward ringing the bell hard, a compact burst of concentric sound-rings radiating from the bell out toward the viewer, not touching a cell edge",
             "recover: the bell swinging back, the sound-rings fading",
             "A single bell-toll with a sonic ring; the boss is seated on its throne — only the upper body and arms move, the throne and lower body stay fixed."),
    "stab": ("wind-up: several of the six dagger-arms drawing back and fanning out to the sides, blades ready",
             "fan: all the dagger-arms cocked back in a wide fan, blades catching the light, body coiled",
             "STAB: two or three of the dagger-arms thrust straight forward toward the viewer at full extension, blades leading, the other arms flared back, the most committed pose, blades not touching a cell edge",
             "recover: the thrusting arms retracting back into the fan",
             "A multi-arm dagger thrust toward the camera; feet planted; keep exactly six arms."),
    "shift": ("solid: the masked figure in its rest pose, edges beginning to blur",
              "phasing: the body smearing sideways into a motion-ghost/after-image of itself, half-transparent, the six arms trailing copies",
              "split-peak: a doubled after-image at its most pronounced — the figure and a translucent echo of it offset to one side, blades trailing",
              "reforming: the echo collapsing back into the single solid rest pose",
              "A fast phase-shift blur in place; the mask/head stays at a fixed point across frames (the anchor); keep exactly six arms."),
    "arc": ("wind-up: both hands raised, fingers spread, small arcs of lightning kindling between them",
            "gather: the hands drawn apart, a bright jagged lattice of lightning building between and around them",
            "ARC: a compact fork of bright lightning discharged forward toward the viewer from the hands, jagged and bright, not touching a cell edge",
            "recover: the arms lowering, residual arcs crawling over the body and fading",
            "A forward lightning arc; the floating body drifts only slightly, no legs to plant."),
    "split": ("solid: the winged figure in its rest pose, a seam of light opening down the centre",
              "dividing: the body pulling apart into two overlapping copies leaning to either side, wings doubling, both half-transparent",
              "SPLIT-peak: two near-complete copies of the figure side by side, mirrored, a bright flash of the signature flame between them, both inside the cell",
              "reforming: the two copies sliding back together toward the single solid rest pose",
              "A mitosis-style split into echoes; the head/core stays centred as the anchor; wings may spread wide but stay inside the cell."),
}

TEMPLATE = """You are generating ONE game sprite animation master with your built-in image_gen tool. Read $CODEX_HOME/skills/.system/imagegen/SKILL.md first, then follow this brief exactly. Work only inside the current directory (the staging dir). Do NOT touch any file under C:\\Users\\asali\\Projects\\MMO.

Two images are attached to this prompt:
- Image 1 = refs/{sprite}_idle.png : the BINDING identity, palette, pixel-art treatment AND body-scale reference — {ident}, shown front-facing (facing the viewer). Reproduce this EXACT character, its proportions, gear, markings and palette. Do not redesign it.
- Image 2 = refs/{sprite}_static.png : a secondary identity reference of the same character.

TASK: generate exactly ONE new 2x2 source sheet for its {CLIP} animation with this image_gen prompt (adapt only if the tool's parameters require it; keep every constraint):

---
Use case: illustration-story
Asset type: high-resolution 4-frame game sprite animation source, to be cropped into a horizontal sprite strip. Square output canvas.
Input images: Image 1 is the binding identity, palette, pixel-art treatment and body-scale reference (front-facing); Image 2 is a secondary identity reference.
Scene/backdrop: a perfectly flat uniform #00ff00 chroma-key background filling every pixel, including the seams between cells. No scenery, floor plane, ground, puddle, platform, cast shadow, contact shadow, gradient, vignette, border, grid, line, or panel divider.
Primary request: create exactly four separate equal square sprite cells as a clean 2x2 contact sheet in reading order top-left, top-right, bottom-left, bottom-right. The source will be cropped into a horizontal strip. All four cells have identical scale and framing; no cell may overlap another; no drawn separators; leave a broad band of flat green between the two columns and between the two rows.
Subject: {ident}, FRONT-FACING (facing the viewer), the exact same character as Image 1 in every cell — same body, gear, proportions and palette.
Style/medium: crisp high-resolution dark-fantasy pixel art with hard readable pixel clusters and a controlled palette, matching Image 1; not painterly, not 3D, not anime.
Composition/framing and ANCHOR RULE: the character is centred in each square cell, front-facing, its standing body about {occ}% of the cell height, with generous green margin on every side so raised arms/weapons and effects fit. It stays in the SAME spot in every cell — its head/crown and its feet (or lowest hem) sit at the same coordinates in every frame that has them; nothing slides sideways, the camera never moves. Only the parts named in the storyboard move.
{CLIP} storyboard - four VISIBLY DIFFERENT poses of THIS character:
 frame 1 (top-left) {f1}
 frame 2 (top-right) {f2}
 frame 3 (bottom-left) {f3}
 frame 4 (bottom-right) {f4}
{extra}
Constraints: output only the four cells on green; no text, watermark, UI, extra characters, scenery, floor artifact, shadow, or separators. Do not use #00ff00 or any bright/pure green anywhere on the character or its effects (use its own palette; a signature GREEN creature must use a darker desaturated green so chroma removal stays clean). Keep the character identical to Image 1 in all four frames — same silhouette, gear and palette. Frames 1, 2, 3 and 4 must each have a clearly different pose from every other frame.
---

AFTER generation:
1. Copy the raw generated PNG (do not resize it) to ./{clip}_master_2x2_v1.png in the current directory.
2. Run the skill's remove_chroma_key.py helper on it and write the keyed RGBA result to ./{clip}_master_2x2_v1_keyed.png (auto-key sampling, despill on).
3. Do NOT slice, do NOT install, do NOT write anywhere under the MMO project. I will do the slicing.
4. In your final message report: the raw output size in pixels, whether all four cells were produced with visibly different poses (frame by frame), and any deviation from the brief you noticed (the character redesigned or off-model, poses sliding/resizing between frames, an effect touching an edge, extra limbs, wrong facing, a fourth head, etc.). Be blunt about defects; do not soften them.

If image_gen is unavailable, say so and stop; do not fall back to another provider or the CLI.
"""

def _neutralize_direction(text: str) -> str:
    """Directional clips define 'forward' via the FACING clause, so strip the
    baked front-facing direction words from the shared storyboard frames and
    the projectiles they mention (the PROJECTILE RULE forbids drawing them)."""
    for a, b in [
        ("toward the viewer", "forward in the direction it faces"),
        ("toward the camera", "forward in the direction it faces"),
        ("toward the bottom", "forward"),
        (" just off the fingertips", ""),
        (" just leaving the hand out in front", " (no projectile drawn)"),
        ("releasing a single compact bolt of the signature energy", "in a casting thrust with only a faint spark at the fingertips"),
        ("a compact burst of the boss's signature energy", "a faint spark of energy right at the hand/weapon"),
        ("a compact burst of null-light at the fist", "a faint null-light spark at the fist"),
    ]:
        text = text.replace(a, b)
    return text

# Robed / floating / legless bodies GLIDE instead of a leg walk cycle.
GLIDE_WALK = {"choirmother", "vess", "serane", "forgemistress", "ashpriest",
              "halla", "veyx", "nullwarden"}

def brief(kind: str, clip: str, facing: str = "s", directional: bool = False) -> str:
    sprite, ident, body = BOSSES[kind]
    if clip == "walk":
        v = list(WALK_GLIDE if sprite in GLIDE_WALK else WALK)
    else:
        v = list(VERB[clip])
    occ = 60 if clip in ("summon", "rain", "storm", "blade", "slam", "verdict") else (68 if clip in ("ring", "freeze", "pack", "charge", "melee", "stab", "walk") else 74)
    clipname = {"idle": "IDLE (breathing loop)", "attack": "basic ATTACK", "walk": "WALK cycle"}.get(clip, clip.upper())
    face_ident = ident
    if clip == "walk":
        directional = True  # a walk always travels in its facing direction
    if directional:
        # profiles/back views need a touch more headroom for the extended weapon
        occ = min(occ, 66 if facing == "e" else 70)
        frames = [_neutralize_direction(v[i]) for i in range(4)]
        # IDENTITY LOCK: rotating to a back/profile view is exactly when the model
        # drifts to a generic "armored swordsman / robed mage" (choirmother/bolt/s
        # drew nullwarden). Name the character hard and forbid substitution.
        lock = (f"IDENTITY LOCK (critical): the character is EXACTLY {ident}. In every cell it must "
                f"be THAT specific character with THAT silhouette, gear and palette — do NOT substitute "
                f"a generic armored knight/swordsman, a generic robed mage, or any other boss's design. "
                f"If Image 1 has no sword, draw no sword; if it is hooded and robed, keep it hooded and "
                f"robed; match Image 1 exactly, only rotated to the stated facing.")
        face_clause = FACING[facing]
        tail = NO_PROJECTILE
        if clip == "walk":
            # travel language, not attack language; walks draw no effects at all
            face_clause = (face_clause.split(" Its attack")[0]
                           + {"s": " It walks toward the BOTTOM of the frame (toward the viewer).",
                              "n": " It walks toward the TOP of the frame (away from the camera); we see its back.",
                              "e": " It walks toward the RIGHT edge of the frame."}[facing])
            tail = ("Draw NO weapons swinging, NO spell effects, NO projectiles — this is only the "
                    "character's locomotion. Feet/hem may kick up nothing; the background stays pure green.")
        extra = lock + "\n" + face_clause + "\n" + _neutralize_direction(v[4]) + "\n" + tail
        clipname = clipname + {"s": " (FRONT view)", "n": " (BACK view)", "e": " (RIGHT PROFILE view)"}[facing]
        f1, f2, f3, f4 = frames
    else:
        f1, f2, f3, f4, extra = v[0], v[1], v[2], v[3], v[4]
    return TEMPLATE.format(sprite=sprite, ident=face_ident, CLIP=clipname, clip=clip,
                           occ=occ, f1=f1, f2=f2, f3=f3, f4=f4, extra=extra)

def main():
    # act1_brief_lib.py <kind> <clip> <stage> [facing s|n|e]  (facing => directional)
    kind, clip, stage = sys.argv[1], sys.argv[2], sys.argv[3]
    facing = sys.argv[4] if len(sys.argv) > 4 else "s"
    directional = len(sys.argv) > 4
    sprite = BOSSES[kind][0]
    os.makedirs(os.path.join(stage, "refs"), exist_ok=True)
    shutil.copy(os.path.join(SPR, f"{sprite}_anim.png"), os.path.join(stage, "refs", f"{sprite}_idle.png"))
    stat = os.path.join(SPR, f"{sprite}.png")
    if os.path.exists(stat):
        shutil.copy(stat, os.path.join(stage, "refs", f"{sprite}_static.png"))
    else:
        shutil.copy(os.path.join(SPR, f"{sprite}_anim.png"), os.path.join(stage, "refs", f"{sprite}_static.png"))
    with open(os.path.join(stage, "codex_brief.txt"), "w", encoding="utf-8") as f:
        f.write(brief(kind, clip, facing, directional))
    print(f"wrote {stage}/codex_brief.txt ({kind}/{clip}, sprite {sprite}, facing {facing}{' DIRECTIONAL' if directional else ''})")

if __name__ == "__main__":
    main()
