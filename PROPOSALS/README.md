# PROPOSALS — A5 boss art + A6 identity NPCs (decision document)

Deliverable for ART_TASKS **A5** (boss art upgrades) and **A6** (identity
NPCs). **Nothing has been installed and no game files were touched** — every
character below is a side-by-side PNG in this folder plus a recommendation
here. The user picks; installs happen in a follow-up task.

How to read the images: leftmost dark-red panel = the sprite in the game
today (Crawl art, 32px). Green panels = candidates, pulled from the raw
packs in `Downloads\*.zip` (or from `game/assets/sprites/` where the piece
is already installed for a mob). Everything is upscaled nearest-neighbor to
the same display height — in-game, `Art.scale_for` normalizes on-screen
size, so same-height comparison is what the player would actually see
(higher-res candidates render sharper, not bigger).

## What the survey found (read this first)

- **Castle "Royal Crew" (Knight / Archer / Priest / Soldier) is the only
  premium 64px human set we own.** Three of the four are already installed:
  `royal_knight` = ch5 Frozen Guard, `royal_soldier` = ch7 Vow Sentinel,
  `royal_priest` = installed but **cast in nothing** (free!). `Archer` was
  never installed — also free. Reusing an already-cast piece for a story
  face needs a recolor variant (A2 pattern) or players meet a boss wearing
  a mob's face.
- **The Garden "humans" are not humans.** Feminine / Masculine / Old /
  Medusa are animated *sandstone statues* — every frame is monolithic tan
  stone. Unusable as living story faces without a full repaint; not
  proposed.
- **Free Pack NPCs are real candidates:** Citizen_F (64px tavern woman,
  full anim set), Knight / Rogue / Wizzard (32px, 4f idle). None installed.
- **Ninja Adventure characters and bosses clash.** ~90 characters + 20
  bosses, but all 16px big-head chibi (bosses 48–68px, heavily
  Japanese-themed). Next to the migrated Pixel Crawler roster they read as
  a different game. Shown in several sheets for honesty; recommended
  nowhere.
- Licensing: Pixel Crawler = purchased commercial (ship edited copies,
  never the raw packs); Ninja Adventure = CC0. Both allowed.

## Verdicts at a glance

| Character | Sheet | Verdict |
|---|---|---|
| warden (Callis) | `warden.png` | **REPLACE — strongest case on the board** |
| choirmother | `choirmother.png` | **REPLACE** (royal_priest, free) |
| witch (3 bosses) | `witch.png` | **SPLIT the casting** (banshee recolors) |
| villager (Sera/Bren) | `villager.png` | **ADD a second sprite**, keep current |
| aldric | `aldric.png` | Replace (lean) — knight recolor |
| stormwarden (2 bosses) | `stormwarden.png` | Taste call — lean replace |
| elder (Maren) | `elder.png` | **Keep current** (lean) |
| merchant | `merchant.png` | **Keep current** |
| envoy (Vessa) | `envoy.png` | **Keep current** |
| nullwarden (2 bosses) | `nullwarden.png` | **Keep current** |
| king (Vargoth/Varo) | `king.png` | **Keep current** (nothing better exists) |

## Per-character detail

### warden — REPLACE (`warden.png`)
The current sprite is a **purple crystalline wraith**. Warden Callis is a
human Accord officer who salutes you and calls you "colleague" — the art
actively contradicts the character, and this sprite fronts the Accord desk
in every hub ch2–ch7. Recommend **Castle Archer**: 64px, grey mail coif
that reads well for a female soldier, and it is the one Royal Crew piece
cast in nothing — no recolor required. Castle Soldier is the runner-up but
is already the ch7 Vow Sentinel.

### choirmother — REPLACE (`choirmother.png`)
**Castle Priest (`royal_priest`)** is installed, unused, 64px, and a
hooded-cleric read that beats the current generic blue robe. Adopt it,
then let A3's Choir dress code (bone + ink + gold thread) recolor it into
the faction look. One piece, two boards satisfied. Note the sprite plays
the ch2 boss *and* four chapters of Choir briefing NPCs — a big win per
pixel edited.

### witch — SPLIT THE CASTING (`witch.png`)
This is the A5 example case. The real problem isn't quality — the current
tentacled horror is genuinely creepy — it's that **three bosses share one
face** (Morwen ch1, Vess ch3, Serane ch5). The installed Cemetery
**Banshee** (47px, full trio, currently the ch5 Hushcaller mob) is the
candidate: per-boss recolor variants — **Vess bone-pale, Serane
frost-blue** — give each boss her own presence and dodge the
double-cast with the Hushcaller. For Morwen: taste call. Blight-green
banshee for full consistency, or keep the Crawl horror as ch1's uniquely
gross signature. I lean keep for Morwen — first boss with a real face
identity is worth more than style purity.

### villager — ADD, DON'T REPLACE (`villager.png`)
One 32px sprite currently plays Widow Sera, Bren, scholars, fishers and
diggers. **Free Pack Citizen_F** (64px, full anim set) is a clear fidelity
upgrade but female-presenting — she can't play Bren. Recommend installing
her as a **new second sprite** (e.g. `villager_f`) for Sera and other
female roles (the `hud.gd` portrait map already routes "sera" by name),
keeping the current male villager for Bren and generics. No male commoner
exists in any owned pack — that's the honest gap.

### aldric — REPLACE, lean (`aldric.png`)
Ser Aldric is "the Guard's last knight" and the current art is a generic
bronze guard. **Castle Knight's** blue-white royal tabard fits the lore
better at twice the resolution — but it's the ch5 Frozen Guard, so it
needs a tarnished/aged recolor variant. Free Pack Knight (32px) is the
no-conflict fallback. Mild preference for the Castle Knight variant.

### stormwarden — TASTE CALL, lean replace (`stormwarden.png`)
Two storm bosses (Korrag ch2, Veyx ch7) share a muddy grey-armor sprite.
A **storm-blue recolor of Castle Knight** (crackle highlights, HDR-warm
pixels per A4's approach) would be a real upgrade; it needs the recolor
anyway (Frozen Guard conflict) so the cost is the same as aldric's. The NA
Giant Blue Samurai is the right color and the wrong game — rejected.

### elder (Maren) — KEEP, lean (`elder.png`)
The most-seen face in the game. Current white hooded robe is dignified,
gender-neutral, and reads "elder" instantly. The only serious candidate
(royal_priest) is better spent on the choirmother, and Free Pack Wizzard
is a bearded man. Keep unless the user wants pack-consistency above all.

### merchant — KEEP (`merchant.png`)
The flamboyant caped mustache-vendor is pure charm and zero combat.
Free Pack Rogue reads shady-fence, Wizzard reads spellcaster, NA Sultan
clashes. The Crawl piece wins on character.

### envoy (Vessa) — KEEP (`envoy.png`)
The blonde envoy holding an open flame IS the Cinderborn pitch. No owned
pack has a fire-handed human; redressing Citizen_F plus hand-painting
flames would cost more than it returns. Clear keep.

### nullwarden — KEEP (`nullwarden.png`)
Hollow white armor, single red eye — the best Crawl piece on the board and
a distinctive silhouette for two bosses (Warden Null, Cyrraeth). A Castle
Knight recolor would *lose* identity. Keep.

### king (Vargoth / Saint Varo) — KEEP (`king.png`)
The Act 1 poster boss. No humanoid king exists in any owned pack; the NA
skeletons are chibi downgrades (shown for honesty). The red-gold skeletal
king stays until we commission/generate something better.

## Install notes for whatever gets approved
- Every adoption lands as a **trio**: `<name>.png` (idle frame 0),
  `<name>_anim.png` (idle sheet), `<name>_walk.png` (run sheet), frames
  square, tight-cropped to union content bbox or 64px sheets render tiny.
- Pre-brighten ~gamma 0.78 and judge from an **in-game** screenshot — the
  Forward+ tonemap crushes midtones (see memory/BALANCE notes).
- Recolor variants of already-cast pieces (banshee, royal_knight,
  royal_soldier) follow the A2 variant pattern: new trio under a new name,
  point the `"sprite"` field at it.
- Codex check per CLAUDE.md: boss sprite swaps show up in codex portraits
  automatically (it reads the same trios), no `BOSS_KINDS` changes needed —
  no kind names change under any proposal here.

---

# A_Hunter as the player-class art template (`player_class_template.png`)

**Verdict: yes as a pilot, side-sheets only, one class first.**

What the Cemetery A_Hunter kit contains (all 64px, all 3-direction
Down/Side/Up): idle 4f, walk 6f, run 6f, hit 4f, collect 8f, and three
8-frame attack styles (Slice/Pierce/Crush) with baked weapon-swing arcs.
It is the only fully-animated player-grade character we own.

### The seam today (player_core.gd:187–225, player.gd:9–18)
- One `Sprite2D`, horizontal strip via `hframes`; `<class>_anim.png` =
  idle strip, `<class>_walk.png` = walk strip, swapped when
  `velocity > 20` (`player.gd:14-16`). Frame count auto-detected
  (width/height), fps fixed 6.0, and the clock runs **2×** while moving
  (`player.gd:17`) — so a 6-frame run sheet plays at an effective 12fps,
  which is about right.
- Facing is `flip_h` only (`Art.faces_left`) — **side view mirrored, no
  up/down channel**.
- Attacks are procedural: `weapon_spr` draws the actual equipped weapon,
  `melee_swing` + `player_combat` fx animate it. There is no attack-strip
  channel.
- Classes today: 32px static + 2-frame idle, no walk strips at all.

### Migration tiers
- **Tier 0 — drop-in, zero code.** `Idle_Side-Sheet` → `<class>_anim.png`,
  `Run_Side-Sheet` → `<class>_walk.png`. The existing seam handles frame
  count, swap, and mirroring today. Cost = art install only.
- **Tier 1 — 4-direction (~30–40 lines).** Track a facing axis in the
  `player.gd` per-frame block, hold three strips per state, add an Art
  loader convention (`<name>_anim_up.png` …). Doable, but enemies share
  the seam (`enemy.gd:125-132`) — keep them side-only. Defer until Tier 0
  is judged in-game.
- **Tier 2 — attack strips. Recommend NOT doing this.** It needs a
  one-shot strip player wired into every `_use_<class>` dispatch, and it
  fights two systems we like: `weapon_spr` shows the player's *actual
  equipped weapon* (A_Hunter's baked axes/swords would contradict gear),
  and the baked white swing arcs double the procedural `_melee_arc` fx.
  The base body sheets are weaponless — ideal under the weapon overlay —
  which is exactly why Tier 0 works and Tier 2 is redundant.

### The real cost is art, not code
Six classes need six identities; A_Hunter is one brown-leather hunter. It
maps naturally to **assassin** (hooded, knives) — recommend piloting
there: install side sheets under `assassin_anim/_walk`, pre-brighten
(tonemap memory), verify with the `shoot_lineup.gd` harness, and judge.
If it lands, the remaining five classes are five redress/recolor passes of
the same base (Free Pack `Body_A` is the naked base body for custom
dress-ups) — or we keep the Crawl class art and spend the effort on the
NPC swaps above, which are seen far more.
