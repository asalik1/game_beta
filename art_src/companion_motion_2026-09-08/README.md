# Companion movement repair

The user identified that the six rescue pets were static portraits bobbing while following. All six require real walk/hop/wingbeat animation.

Generated with built-in ImageGen, serially with Godot stopped, September 8 2026.
Reference: game/assets/sprites/companion_atlas.png, one matching creature per job.
Eight distinct poses per companion in a four-column/two-row sheet. Masters remain
untouched here. The first transparency attempts were RGB with baked checkerboards
and were rejected. Accepted masters use flat green/magenta extraction backgrounds.
Use existing repository key/extraction tools; whole separated creatures only,
never composite limbs or reconstruct frames. Inspect the resulting loops in-engine.

Identity: cream orange-capped Spore Pup scamper; green/gold Hearth Hopper hop;
charcoal amber-eared Cinder Bat wingbeat; slate Ash Crow wingbeat; turquoise/gold
four-wing Glimmerwing cycle; ivory/gold four-wing Pale Flutter cycle.

Build with `python tools/art/build_companion_motion.py`. The builder keys and
despills, splits only at empty gutters, aligns each whole figure to its face,
and applies one shared scale per cycle. Output: six 4096×512 RGBA strips.

All six contact sheets reviewed. Desktop full: 185 checks, strict PASS.
The live companion rig captured 28 states, including real follower movement,
rest and touch controls. Art gate: zero failures. Rim scan: zero defects or
suspects. Wing/hop silhouette-anchor warnings were visually checked against the
stable face anchor and accepted. See COMPANION_MOTION.md and
AUTONOMOUS_STATUS.md for the final mobile/checkpoint record.
