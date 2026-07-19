# Legacy and Backup Asset Reuse Report

_Reviewed 2026-07-18. This is an inventory of **unassigned or retired**
character assets that could become mobs, NPCs, minibosses, or special
encounters. It does not authorize installation; it is a short-list for a later
content pass._

## How to read the scores

- **Aesthetic** — silhouette, current-game fit, and how little visual surgery
  the asset needs (10 = would sit naturally beside the current best work).
- **Completeness** — usable body + locomotion + action/death coverage. A
  non-directional strip is still valid for a normal enemy, but scores below a
  modern 8-direction set.
- **Overall** — weighted judgement of visual quality, a clear unique role,
  and implementation cost. It is a priority score, not a claim that the asset
  is final-quality.

The hero and enemy renderers can use a non-directional idle/walk strip, so the
old class families do *not* need an 8-direction re-export merely to become
placeholder enemies. New enemy keys must still be used; never point an enemy
at a live player class or skin key.

## Tier A — use these first

| Asset | Source | Aesthetic | Best lane | Completeness | Overall | Why / first-pass identity |
|---|---|---:|---|---:|---:|---|
| Storm Archer v1 | `backup/archer_base_v1/` | 9.0 | Elite ranged mob | 10.0 | **9.1** | The best direct conversion: distinct 216px body with 8-dir idle, walk/run, attacks, cast, dash, ult, and death. Use as **Stormbound Hunter** or **Tempest Deserter**; retain only idle/walk plus one ranged action at first. |
| Old purple fire Mage | `art_src/heroes_clips/mage*` | 8.2 | Ranged mob | 9.0 | **8.7** | A readable, self-contained **Ember Cultist** / forbidden-fire caster. Its 67px 8-frame strips cover idle, walk/run, attack, cast, dash, and death. |
| Old bandit Warrior | `art_src/heroes_clips/warrior*` | 8.0 | Melee mob / elite | 9.5 | **8.5** | The 83px family is the fullest old pack (idle, walk/run, two attacks, dash, ult/ult-idle, death). It already reads as a **Bandit Brute** or raider captain rather than a player hero. |
| Old skull Warlock | `art_src/heroes_clips/warlock*` | 8.0 | Ranged mob / mini-elite | 9.0 | **8.4** | Strong skull-and-grimoire silhouette. Reframe as a **Skull-Pact Cultist** and give it a different accent/tell from the live Warlock. |
| Old purple Assassin | `art_src/heroes_clips/assassin*` | 7.8 | Fast melee mob | 9.5 | **8.2** | Complete 84px movement/action/death family, plus old stab/throw material. Works as a **Veil Cutthroat**, but use less often because it is nearest to a player-class fantasy. |
| Old green Archer | `art_src/heroes_clips/archer*` | 7.3 | Low-tier ranged mob | 8.5 | **7.7** | Good **Wildwood Scout** / goblin-adjacent hunter. The 79px old strips are complete enough for ordinary encounters, though the body is more stylized than the current Archer. |

### Tier A implementation note

The five oldest class families above live in `art_src/`, not in `backup/`.
Only their death strips were recently moved to `backup/legacy_hero_strips/`.
They are the real former class bodies: bandit warrior, purple fire mage,
purple assassin, skull warlock, and green archer. The source directory carries
55 images across all six old families.

## Tier B — strong reserves; need assembly or a clear content home

| Asset | Source | Aesthetic | Best lane | Completeness | Overall | Why / first-pass identity |
|---|---|---:|---|---:|---:|---|
| Gold Knight draft | `backup/skin_drafts/warrior_gold_knight_rotations.png` | 8.1 | Hidden miniboss / special guard | 5.0 | **7.5** | Full 8-direction body, clean silhouette, no strips. Best as an **Unsworn Champion** behind a shrine/armory encounter, not a regular common mob. A dark/desaturated hostile pass would help. |
| Sexton r1 | `backup/boss_redesigns/_reject_pool/sexton_r1/` | 7.7 | Cemetery elite | 5.0 | **7.3** | Full 8-direction lantern-and-shovel body. It was rejected for boss intensity, which makes it an excellent **Lantern Sexton** mob. Needs idle/walk assembly. |
| Kaethra r1 | `backup/boss_redesigns/_reject_pool/kaethra_r1/` | 7.5 | Plague elite | 5.0 | **7.1** | Full 8-direction cure-twisted body. Retain the grafted-healer read, but rename it as a rank-and-file **Curewrought** so it does not compete with the Kaethra boss. |
| Hrolgar r1 | `backup/boss_redesigns/_reject_pool/hrolgar_r1/` | 7.4 | Winter brute | 5.0 | **7.0** | Full horned whitepelt body with a distinct brawler silhouette. Good **Antlered Ravager**; keep the real Hrolgar boss unique via scale, FX, and name. |
| Cyrraeth Stormmouth draft | `backup/pixellab_archive/bosses/cyrraeth_stormmouth_180_draft/` | 7.4 | Hidden boss / endless elite | 4.5 | **6.9** | Large 180px 8-direction armored wraith. Existing notes already reserve it for an elite storm mob/ch7 wraith. It needs a storm core, aura, and action strips so it does not read as merely a black mannequin. |
| Fangmaw r1 | `backup/boss_redesigns/_reject_pool/fangmaw_r1/` | 7.0 | Beast mob | 5.0 | **6.6** | Full grave-hound rotation set. A useful **Grave Hound** pack enemy, though it needs movement strips and should not borrow Fangmaw's boss mechanics. |
| Archer r1 | `backup/class_drafts/_reject_pool/archer_r1/` | 7.0 | Ranged mob | 5.0 | **6.5** | Full body and 8 directions. The permanently drawn bow makes it a good static sentry/ambusher, less convincing as a normal walker. |
| Forgemistress Calda miss | `backup/pixellab_archive/bosses/forgemistress_calda_112_a/` | 6.8 | NPC | 4.5 | **6.3** | Full 8-direction plain armed woman. Existing notes correctly identify her as a guard/hunter/hub-warrior candidate, not a boss or generic hostile. |

## Tier C — niche, prototype-scale, or visual-quality compromises

| Asset | Source | Aesthetic | Best lane | Completeness | Overall | Why / constraint |
|---|---|---:|---|---:|---:|---|
| Old Paladin | `art_src/heroes_clips/paladin*` | 5.8 | Special guard / comic relic | 8.5 | **6.3** | Complete old family, but the golden chibi look clashes with the current dark-fantasy baseline. Use only if intentionally framed as a toy-like relic, old statue guardian, or hidden joke encounter. |
| Auroch r1 | `backup/boss_redesigns/_reject_pool/auroch_r1/auroch.png` | 6.8 | Static hazard / summon | 2.5 | **5.1** | A static spider/map-object body. It could work as a nest hazard or an immobile encounter prop; not a walking enemy without new work. |
| Grove Horror | `backup/art-audit-2026-07/gen_staging/characters/grove_horror/` | 5.4 | Small forest minion | 4.5 | **5.0** | Eight rotations and one west walk. The body is legible, but its low-resolution prototype style will stand out beside current PixelLab mobs. |
| Choir Censer | `backup/art-audit-2026-07/gen_staging/characters/choir_censer/` | 5.5 | Boss summon / hazard | 3.5 | **4.9** | Tiny 8-direction censer creature. Best as a summoned incense familiar or stationary hazard, never as a normal enemy. |
| Sexton 68 | `backup/art-audit-2026-07/gen_staging/characters/sexton/` | 5.0 | Background NPC / low-tier grave mob | 4.5 | **4.7** | The r1 Sexton is substantially better. Keep this only if a deliberately small, older-looking cemetery extra is useful. |
| Legacy Witch | `backup/legacy_hero_strips/witch*` | 4.5 | Background NPC / corpse prop | 5.0 | **4.6** | Has an idle strip but no walk. The older visual language is too weak for a normal encounter. |
| Legacy Direwolf | `backup/legacy_hero_strips/direwolf*` | 4.3 | Background beast / corpse prop | 5.0 | **4.5** | Same limitation: idle material but no walk, and it is visually below current creature work. |
| Legacy Gardener | `backup/legacy_hero_strips/gardener*` | 3.8 | Set dressing / dev-only NPC | 6.0 | **4.3** | Has idle and walk, but the 34px mannequin quality is far below the live Rotmaw art. Do not make it a regular enemy. |

## Explicit exclusions

These are preserved history, not candidates for new placeholder definitions:

| Asset / family | Reason |
|---|---|
| `class_drafts/_reject_pool/paladin_r1` | Effectively the deployed Paladin body; no new silhouette. |
| `class_drafts/_reject_pool/warlock_r1` | Torso-only: no usable lower body. |
| `boss_redesigns/_reject_pool/serane_r1` | Torso-only: no usable lower body. |
| `pixellab_archive/skins_original_92px/` | Earlier low-resolution exports of live named player skins (Dreadknight, Void Weaver, Plague Doctor, etc.); duplicate identities and lower detail than the deployed 244–248px versions. |
| `skin_phantom_blue_shipped/` | Exact backup of the deployed Phantom skin. |
| `boss_readability/cinderhide*` | Exact live copy; `auroch*` is a readability/color predecessor, not a distinct character. |
| `forgemistress_legless_DEAD` | Legless export; explicitly superseded. |
| `flux_drafts/` | Concept art, often with scenery/ground baked into the figure. Not sprite-ready. |
| `anchor_fix_*`, `drift_regen_*`, `skin_fx_fix_*` | Repair/export snapshots of live assets. |
| `chest_ladder`, `wave2_clean`, wall/tone/mush originals | Props, terrain, or superseded visual passes rather than new character identities. |
| Legacy death-only strips | Useful only as corpse/set-dressing references; the complete legacy animation source is in `art_src/heroes_clips/`. |

## Recommended first reuse wave

1. **Stormbound Hunter** from `backup/archer_base_v1`.
2. **Ember Cultist** from the old Mage family.
3. **Bandit Brute** from the old Warrior family.
4. **Skull-Pact Cultist** from the old Warlock family.
5. **Lantern Sexton** from `sexton_r1` once idle/walk strips are assembled.

That wave creates a ranged elite, caster, bruiser, curse caster, and cemetery
elite without competing with live player skins or current bosses. The Codex
should be updated when any of these becomes a placed player-facing enemy.
