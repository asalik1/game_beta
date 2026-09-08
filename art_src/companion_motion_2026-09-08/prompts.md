# ImageGen prompt set

Tool: built-in ImageGen. Reference for all identities:
`game/assets/sprites/companion_atlas.png`.

Each final generation requested eight complete, equally sized frames in a
four-column/two-row sheet, facing right in a fixed three-quarter view, with
no text, borders, shadows, scenery or gradients. The masters use flat pure
green (#00FF00) or magenta (#FF00FF) extraction backgrounds.

## Spore Pup
Cream furry mushroom creature from the atlas top-left; preserve orange-red
cap with gold flecks, mossy back, dark eyes and short cream feet. Eight distinct
short-legged scamper phases: near foot forward, lowering, feet passing, far
foot reaching, far foot planted, lowering, feet passing, near foot reaching.
Cap/head steady; real legs change pose. The first RGB checkerboard output was
rejected. A background-only edit requested solid green and preserved all poses.

## Hearth Hopper
Olive-green/gold frog from atlas top-center, cream throat and black gold-rimmed
eyes. Eight hop phases: crouch, squash, spring with rear legs extending, low
flight with trailing rear legs, legs folding, front toes reaching, landing,
resting crouch. The first RGB checkerboard output was rejected; background-only
edit requested solid magenta, preserving complete toes and separated figures.

## Cinder Bat
Charcoal fuzzy bat from atlas top-right, amber ears, dark leathery wings and
brown finger spars. Eight wingbeat phases: high, half-high, sideways, halfway
down, low, folded recovery, opening up, nearly high. Keep torso/ears steady;
all wings/ears inside each cell. Solid green background.

## Ash Crow
Slate-black raven from atlas bottom-left, slate-blue feathers, black eyes,
stout black beak and tapered tail. Eight flying wingbeat phases: raised,
half-raised, horizontal, diagonal down, lowered, folded recovery, half-raised
recovery, nearly raised. Feet tucked. First crowded sheet rejected. Final
request explicitly required each bird to occupy at most 60% of cell width,
70% of height, with large empty green gutters and complete equal-size birds.

## Glimmerwing
Emerald-blue dragonfly from atlas bottom-center; turquoise eyes, gold joints,
narrow segmented abdomen and four pale turquoise wings with gold veins/flecks.
Eight phases alternate fore/hind wing strokes: raised V, forewings descending,
broad open, forewings down/hind spread, low, front recovery, narrow recovery,
reopening. Keep all four wings attached, body/head fixed, complete tips/tail.
Solid magenta background.

## Pale Flutter
Ivory-gold moth from atlas bottom-right, fuzzy cream body, dark eyes, golden
feathery antennae, four ivory wings with gold veins and ringed eyespots. Eight
phases: raised together, half opening, broad open, sweeping down, low, inward
recovery, lifting narrow, reopening high. Keep body/antennae fixed and every
wing complete. Solid green background.

Accepted source paths and SHA-256 hashes are in manifest.json. All final
master outputs are preserved unchanged in masters/. Reproducible extraction
and full-figure anchoring are in tools/art/build_companion_motion.py.
