# Class concepts — approved set (2026-08-21) → ELITE SKIN identity contracts

One south-facing presentation frame per class, Codex ImageGen, owner-approved shape
("looks good" on the v2 round + "include mage too"). Owner ruling (same day): these wire
in as one new ELITE skin per class (`Skins.SKINS`); base class sprites are unchanged.
Each PNG is the BINDING IDENTITY reference for its skin's production run
(`tools/art/IMAGEGEN_SPRITE_PIPELINE.md` recipe). Skin ids: warrior `emberbound_heir`,
assassin `erased_name`, archer `severed_thread`, warlock `ledgerbound`, mage
`blighted_healer`. All five build at a **235 px source body** (owner ruling 2026-08-21:
the premium skin tier is crisper than the in-band base sprites; ratios 2.46–2.80× by
class). The paladin has no skin here — its Codex base (Oathbound Arbiter) IS the
elite-grade design and gets upscaled to 235 px in the band run instead.

`rotations/` holds the owner-approved five-view identity sheets (Phase 1, 2026-08-21) —
the binding reference for animation.

BUILD CONTRACT (proven by the runtime-size gate, sheet 37): each skin's deterministic
builder installs at a 235 px source body AND applies the ~gamma 0.78 Forward+ pre-brighten
the base sprites already carry — without it the dark black-iron armor reads as a muddy blob
at the 95 px game body; with it, the metallic value separation reads crisply. Match each
base class's clip frame counts exactly (warrior: walk/run 6f, attack/attack2/attackb/dash/
ult 7f, ultidle 4f, death 9f flat) so the skin's cadence matches movement speed (no foot-slide). Design text + the binding symmetry constraint live in
`PROPOSALS/CLASS_BASE_SPRITE_DESIGN_REVIEW.md` (see "Symmetry constraint", owner ruling
2026-08-21: hero base designs left/right symmetric apart from held weapons).

| file | design | v2 fix over the rejected v1 |
|---|---|---|
| warrior_concept_south_v2.png | Emberbound Heir (restrained helm) | both arms armored — no bare arm; ember confined to fuller + centered breastplate seam |
| assassin_concept_south_v2.png | the Erased Name | matched twin daggers; fan knives = symmetric belt row |
| archer_concept_south_v2.png | Severed-Thread Ranger | bow properly gripped (left hand on the riser) |
| warlock_concept_south_v2.png | Ledgerbound Debtor | palette locked near-black + aged-gold (v1 drifted brown) |
| mage_concept_south_v2.png | the Blighted Healer | blight rebalanced to the lower third; clean white dominates |

Open nit (offered, not ruled): warlock contract-ink climbs one hand by design —
both-wrists variant available on request. Review sheets: Downloads/UPSCALE_OWNER_REVIEW
33/34/35 + DECISIONS.md §8e.
