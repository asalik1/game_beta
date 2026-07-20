# Crownless — Skin Animation Bible

This is the production contract for elite and mythic skins. It exists because a
good concept plus a new static PNG is not a skin experience. The reference
implementations are **Golden Ronin** (elite) and **Phantom** (mythic).

## Non-negotiable rules

- Skins are cosmetic. Damage/ticks, cast/release/recovery and hit timing,
  hitboxes, targeting, range, projectile physics, cooldowns and ability behavior remain identical to the
  base kit. A different visual origin must be an offset render, never a moved
  gameplay projectile.
- Animation is part of the skin. A static `Sprite2D` that scales and fades is
  a *single accent*, never an ult sequence or a full ability replacement.
- A visual only counts when it has a readable **anticipation → action →
  aftermath**. It needs changing shapes, poses or positions over time—not a
  decal shown once under a generic ring/burst.
- The character remains the focus. A large effect may stage the world, but it
  must return the eye to the hero and/or marked target before it resolves.
- Mythic awakening changes the character sprite strips only. It may draw
  embedded energy in those strips, as Phantom does; it never changes the ult
  sequence, ability FX, damage, or mechanics.

## What Phantom actually does

Phantom is the acceptance reference because its identity survives every action:

| Lane | Phantom evidence | Required lesson |
|---|---|---|
| Locomotion | Floating read, soft footfall replacement, spectral dash trail. | A mythic must be recognizable before it attacks. |
| Basic attacks | Sharp teal crescent, spectral knife silhouette and knife trail. | Do not only recolor a base projectile/slash. |
| Movement skill | Dash has a dedicated trail and sound language. | The mobility button needs a thematic movement signature. |
| Ult staging | Splash-art wash, marked-target blade ring, repeated moving knives, altered execution presentation. | A mythic ult is a short scene with several timed beats—not a single icon at cast. |
| Awakening | Same actions and mechanics, but a void face, stronger cyan energy, wider cloak silhouette and embedded wisps in the sprite strips. | The sprite itself must look transformed, not merely recoloured. |

**Phantom's ult story:** the marked enemy has been chosen by a spectral reaper.
The splash is the reaper's arrival; the surrounding blades are not decoration,
they are a visible clock. They close and stab in sequence for the duration of
the mark, then the assassin enters to finish the sentence. That is the level of
theme-to-motion causality every mythic needs.

## Narrative engines — every motion must mean something

Do not start a skin from a colour and a list of particle effects. Start with a
single sentence that explains why its weapon, locomotion, abilities and ult
move as they do. An effect without a job in that sentence is cut.

| Skin | The fantasy sentence | Mandatory motion language | What the ult is *about* |
|---|---|---|---|
| **Dreadknight** | A grave-general commands the dead he has sworn to protect. | Souls are ordered: they fall into line, trail a command stroke, then rally to the banner. The banner cloth flutters and unfurls; it never just pops in. | Renewing the oath: the knight calls the dead to the standard, then takes their strength into his armour for Berserk. |
| **Stormforged** | A warrior is the grounding rod for a living storm. | Every attack conducts: charge runs along steel before contact, jumps at contact, and crawls back through armour after contact. Electricity must travel, branch, or reconnect—never sit as a glow. | Accepting the storm: it circles, finds the warrior's raised blade, and inhabits the armour. The character is being empowered, not calling an AoE strike. |
| **Frostfall Ranger** | A winter hunter turns a battlefield into the still moment before a kill. | Snow follows the arrow's path, rime spreads after it lands, and every roll leaves a breakable frozen trace. The moon assembles from snow/ice pieces, then sheds them. | Calling the silent winter hunt: moonlight freezes the air and the resulting hail is the hunter's kill-zone. |
| **Voidwraith** | An eclipse predator hunts from the dark between a moon and its prey. | Cloak feathers drift against movement; arrows curve like they are orbiting invisible gravity; the body disappears through one thin eclipse slit and emerges from another. | The black moon chooses the hunting ground, gathers the volley around itself, then releases it at the prey. |
| **Void Weaver** | A reality tailor plants watching eyes between seams, then pulls the victim's world apart by its threads. | Eyes assemble and blink; thread routes remain taut until contact; cocoons wrap, empty, reform and unwind. Threads never behave like generic purple smoke, and Blink never borrows a portal. | Condemning a patch of ground: violet light reveals the chosen area, then countless threads rip vertically upward through it in one sudden execution. |
| **Crystal Archmage** | A sovereign of a crystal citadel no longer needs to touch the ground. | **Never walk.** A faceted crystal dais sits under the character, tilts in the travel direction and glides; the hero uses oriented idle frames while riding it. The dais rotates through distinct facets, not a single bob. Every cast refracts, splits, aligns or shatters geometry. | Delivering a royal sentence: three court prisms assemble a monolith, which descends, fractures, and leaves the battlefield reflected in its shards. |
| **Eclipse Knight** | A knight carries a stolen sun, and every holy act is light trying to escape a black prison. | Gold crescents close around a black centre, corona segments ignite one after another, and shield plates lock into orbit. Nothing is a flat yellow aura. | The eclipse claims the court: darkness swallows the halo, chains answer the black sun, and the final hammer lets the corona burst free. |
| **Fallen Arbiter** | An angelic executioner has already written the sentence; the fight is its ceremonial enforcement. | Feather-blades align into geometric law-runes, seals lock one segment at a time, and wings hold rather than flap. Motions are deliberate and judicial. | A tribunal convenes: each target is sealed as evidence, tethers become lines of judgment, and the assembled verdict blade falls only after the sentence is complete. |
| **Hellfire Inquisitor** | A zealot brands a confession into the guilty, then burns the evidence. | Brands stamp, flare, cool to smoking iron, and tighten with chain links. Fire is disciplined and punitive—not a generic fireball haze. | The interrogation becomes execution: the ring of brands seals the accused in, chains draw the pyre shut, and the final blast is the sentence being carried out. |
| **Eldritch Herald** | A human herald is only the doorway through which something ancient watches. | Eyes blink, lids peel open, tendrils reach toward what the eye has noticed, then withdraw. Robe movement should feel submerged and deliberate. | The door opens fully: the eye watches victims being drawn toward it, closes around the detonation, then leaves a blinking wound in reality. |

## Review: current skin pass — prototype only

The current implementation compiles, and some assets are individually attractive.
It is **not accepted as the final skin pass**. The review found that the new
assets (`fx_dread_banner`, `fx_storm_eye`, `fx_frost_moon`, `fx_void_eclipse`,
the mage monolith/spindle, paladin seals, and warlock sigils) are single-frame
props. Their common runtime treatment is spawn → scale tween → alpha fade.

That creates a better icon on an existing event, but not a new animation:

- no new skin-specific character pose or state strip;
- no multi-beat ult timeline beyond a short prop tween;
- little or no locomotion/idle ownership for the new skins;
- no target-specific visual relationship comparable to Phantom's marked blade
  storm; and
- no required screenshot sequence proving the story can be read frame to frame.

Keep the prototype assets only where they remain useful as a **frame within** a
larger sequence. Do not declare a skin complete because that prop is present.

## Tier acceptance gates

### Elite — Golden Ronin bar

An elite needs all of the following.

1. A readable weapon/projectile or slash replacement on its core attack.
2. A distinct movement accent on its movement skill (trail, afterimage,
   displacement shape, or pose), not just a tint.
3. At least two other kit touches that change the visual verb—e.g. hail instead
   of arrows, branded victims instead of a generic rune, or orbiting swords
   instead of generic whirl blades.
4. A 0.6–1.2 second ult mini-sequence with three beats: **pose/declare → themed
   transformation around the hero → short lingering proof of the new buff or
   field**. A non-damaging ult must never look like an untelegraphed AoE hit.
5. A distinct sound or silence choice on the signature ability where appropriate.

### Mythic — Phantom bar

A mythic needs everything above plus all of the following.

1. A locomotion identity: idle/run/walk/dash has an authored read, not only an
   attack-time effect.
2. A custom visual silhouette for **every** ability, including the mobility
   skill. At least one must change the relation to a target (mark, orbit,
   tether, pursuit, fracture, etc.).
3. A staged ult of 1.0–2.0 seconds, while preserving the original damage
   schedule. Its storyboard must include: **declaration, world/target takeover,
   escalating mid-beat, hero re-entry or transformation, and resolution**.
4. At least one reusable animated helper (trail, orbit, tether, blade storm,
   particle behavior, or stateful mark)—not five unrelated one-shot decals.
5. Re-authored strips for the states the skin asks the player to notice:
   `anim`, `run`/`walk`, `attack`, `attack2`, mobility state where applicable,
   and `ult`/`ultidle`. Recolour copies fail this gate.
6. An awakened sprite pass that has a stronger head/face, weapon/focus,
   costume silhouette and embedded energy. It reuses the exact same FX logic.

## Locked animation boards

These are required stories, not names for static assets. The listed timings are
presentation timing only; gameplay remains on its current schedule.

| Skin | Required animation board |
|---|---|
| **Dreadknight — elite** | **Cleave:** a red soul-cut tears free of the blade, lags behind the swing, then gets pulled back into it. **Charge:** bodies/afterimages leave a torn banner wake rather than a straight red smear. **Whirlwind:** three greatswords enter one at a time and then orbit. **Berserk:** sword comes across the chest in an oath pose; a ragged standard unrolls behind the hero; thin soul threads climb from the standard into armour seams; the standard remains faintly visible for the first buff beat. |
| **Stormforged — mythic** | **Locomotion:** intermittent small arcs crawl between blade, shoulder and ground; run frames carry a wind-pulled mantle. **Cleave:** electricity travels down the blade then leaps forward after the contact. **Charge:** body breaks into a jagged bolt with a delayed re-form at the endpoint. **Whirlwind:** the blades gather charge for one revolution, discharge, then decay. **Berserk storyboard:** storm eye opens above hero → three arcs circle inward without striking enemies → armour and sword take the charge → a contained storm halo persists while the buff begins. |
| **Frostfall Ranger — elite** | **Quick/Multishot:** arrows visibly crystallize at the bow, leave a short snow wake, and stick a moment as ice splinters. **Tumble:** the departure footprint cracks into rime and the landing releases loose snow. **Arrow Storm:** small frost motes rise from the hero → an ice moon forms in pieces overhead → hail arrows begin → the moon sheds shards and fades while rain continues. |
| **Voidwraith — mythic** | **Locomotion:** cloak tails and sparse void feathers trail the run; idle has a barely moving eclipse outline, not a permanent glow blob. **Arrows:** a crescent draw bends each shaft into a barbed void streak. **Tumble:** the archer is swallowed by a closing slit and reappears from a second slit. **Arrow Storm storyboard:** room darkens locally → black moon opens in growing rings → arrows orbit the moon/marked target for a beat → volleys peel off in curved trajectories → moon fractures to a thin crescent as normal rain continues. |
| **Void Weaver — elite** | **Bolt:** one woven void eye forms at a random clear pocket near the caster (never overlapping another live eye), opens, and launches a tiny sharp violet needle. Its moving trail records the entire travelled route and collapses rapidly on first contact. **Nova:** keep the accepted clockwise stitched circle, closing knot and violent outward unravel. **Blink:** threads wrap the full body at departure and contract to an empty filament; matching threads reform at the destination and unwind to reveal the caster—no portal, slit or travel smear. **Meteor replacement:** the target footprint lights violet and accumulates stitch-points, then countless fine threads erupt straight upward across the circle, hold through the damage beat and retract. Nothing descends from the sky. |
| **Crystal Archmage — mythic** | **Locomotion:** never use walk/run frames. Spawn a sprite-animated faceted crystal dais below the hero; it tilts and glides in the movement direction while the hero holds the appropriate oriented idle pose. **Bolt:** light enters a crystal focus, refracts into a hard lance, then throws off two fleeting shard ghosts. **Nova:** crystal spokes grow in sequence around the caster before breaking outward. **Blink:** body shards into a directional stream and reassembles from the leading shard. **Meteor storyboard:** three prism glyphs form around the target → rotate into a descending monolith → monolith cracks mid-fall → shards fan around the impact then freeze for one beat before dissolving. |
| **Eclipse Knight — elite** | **Judgment:** a thin gold crescent closes over a black inner disc at the hammer contact. **Consecration:** corona segments light in a clockwise sequence instead of appearing as one decal. **Aegis:** four dark-gold plates lock into a shield in turn. **Retribution/Chains ult:** eclipse disc eclipses the paladin's halo → chain links pull toward the disc → corona hammer lands → the disc opens back to gold as the stance settles. |
| **Fallen Arbiter — mythic** | **Locomotion:** wings shed occasional pale blade-feathers; the movement state should feel solemn, not busy. **Judgment:** a cold seal locks around the victim in segments. **Consecration/Aegis:** angular law-runes assemble, hold, then break into ordered shards. **Retribution/Chains storyboard:** court seals appear under each tethered target → their lines draw to the arbiter's raised weapon → giant white verdict blade materializes in pieces above the pile → blade resolves as the existing impact lands → feathers and seal fragments hang for the aftermath. |
| **Hellfire Inquisitor — elite** | Retain the existing fire shadowbolt. **Hex:** a brand is stamped onto each victim with a hot flash and smoking edge. **Pact:** the hero's blood/embers feed a brazier seal, which breathes back out. **Void Rift ult:** brands stamp a ring one at a time → heated chain lines tighten → the centre becomes a pyre mouth → it erupts and leaves smouldering brand fragments. |
| **Eldritch Herald — mythic** | **Locomotion:** robe hem moves like slow submerged tendrils; the staff eye blinks on a low-frequency idle loop. **Bolt:** the eye opens, launches the living bolt, and leaves an ichor tether for a beat. **Hex:** eye-runes open over targets, then blink shut as the curse lands. **Pact:** a small iris opens in the seal and watches the blood draw. **Void Rift storyboard:** a closed eye sigil forms → lid segments pull apart → tendrils reach from the opening toward victims as the existing pull ticks → iris contracts around the blast → a blinking scar remains briefly. |

## Asset and implementation rules

- Build the **narrative sentence and timeline first** as a beat sheet, then list
  every required strip, frame sequence, helper and sound. Do not start from
  “make an icon for the ult.”
- Any new `fx_*.png` must name its exact role: one frame of a sequence, a
  projectile silhouette, a persistent mark, or a reusable helper. A lone
  generic badge is rejected.
- Prefer short, purposeful sequences: 3–6 changing poses/shapes can read far
  better than a large static prop. Sprite-frame swapping, orbit paths, moving
  trails, staggered child timing, and target-attached marks are all valid.
- Effects must be reviewed on both bright and dark terrains, at gameplay zoom,
  and beside the base skin.
- Use `shot_kit.gd --class=<class> --skin=<skin>` to capture each beat. One
  screenshot is insufficient: capture declaration, mid-beat, payoff, and
  aftermath for every ult.

## Sign-off checklist

- [ ] Core attack and mobility read as this skin with the HUD hidden.
- [ ] All four abilities have an explicit visual board and are visible in a
      four-frame capture sequence.
- [ ] Elite ult has all three required beats; mythic ult has all five.
- [ ] No buff-only ult appears to damage or crowd-control enemies.
- [ ] No mythic ult is reducible to a single static PNG plus scale/fade tween.
- [ ] Mythic awakening is a re-authored sprite-strip evolution and does not
      alter ult/ability logic.
- [ ] Screenshots at bright and dark terrain pass human review before staging.
