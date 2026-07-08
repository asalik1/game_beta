# Emberfall — Chapter 1: The Hollow King

Second iteration of the MMO project: a **solo, story-driven action RPG**
with classes, gear, loot chests, merchants and a skill tree.
You play Aldric, last of the Ember Guard, fighting through three zones and
three bosses to reclaim the stolen Ember Crown.

Built with **Godot 4.4** (free, open source — no fees ever, unlike Unity),
which exports to **Windows/Steam and Android** from the same project.

## ▶ How to play (right now, on your PC)

Double-click **`run_game.bat`**. That's it — the engine is bundled in `tools/`.

For testing, **`dev_mode.bat`** launches the same game with an **F1 debug
panel**: god mode, instant class/level/gold/item/gem cheats, zone teleports,
boss spawning, monster clearing, and a live **terrain switcher**.

Combat is **keyboard only**: your abilities auto-aim at the nearest enemy
(watch the yellow reticle). All keys below are rebindable in-game
(ESC → B, or click any action and press a new key).

| Input | Action |
|---|---|
| WASD / arrows | Move |
| TAB | Switch / lock target (orange reticle) |
| J | Ability 1 (basic attack) |
| K | Ability 2 |
| L | Ability 3 |
| U | Ultimate (long cooldown) |
| Q | Drink potion (heals 60%) |
| E | Talk to NPCs / shop |
| I | Inventory (equip gear) |
| T | Skill tree (spend points) |
| C | Codex (monsters & gear gallery) |
| ESC | Pause (B = rebind keys) |

## ⚔ The systems

- **4 classes** — Warrior (STR), Archer (AGI), Mage (INT), Assassin (AGI) —
  each with 3 basics + 1 ultimate and a class passive.
- **Themes** — every class has 3 elemental playstyles (Assassin:
  Poison/Shadow/Blood; Mage: Fire/Ice/Wind; Warrior: Fury/Bulwark/Earth;
  Archer: Storm/Venom/Hunt), unlocked as you level. **Each ability can be
  assigned any unlocked theme independently** — poison Stab with shadow
  Shadowstep is a build. Themes change behavior: DoTs, roots, echo hits,
  crit riders, self-buffs.
- **Full stat engine** — STR/AGI/INT primaries, DEX vs enemy EVA hit-rate,
  crit with diminishing returns past 70%, PhysRes/MagRes/CritRes on
  logarithmic curves, penetration (excess over enemy res becomes bonus
  damage), TRUE damage that ignores everything, COMBO (chance abilities
  don't go on cooldown + refund mana), Greed with soft caps, lifesteal
  (33% effective on AoE). Check YOUR STATS in the inventory.
- **Gems** — B/A/S gear has 1/2/3 sockets. Gems grant one stat each, drop
  from chests, and synthesize 3-into-1 up the levels (max Lv10). Selling
  gear auto-returns its gems.
- **Loot** — enemies drop gold and sometimes chests (wood/silver/gold tiers);
  bosses always drop a golden chest. Gear comes in grades **F→E→D→C→B→A→S**
  with random substats, in 4 slots: weapon, armor, boots, charm.
  Your equipped weapon is **drawn in your hero's hand** (A/S weapons glow).
  **Every shape has a stat personality**: Claymores roll massive ATK, Fangs
  and Kunai roll crit, Bows roll attack speed (Haste), Staves roll mana,
  Guards roll damage reduction — check the codex for each shape's tag.
  **A-grade gear has unique epic names** ("The Ruined King's Sword");
  **S-grade gear is class-exclusive** with synergy stats, and S weapons carry
  a passive: Kingsbane hurls sword waves, Stormcaller arrows ricochet,
  Heart of the Phoenix explodes and ignites, Nightfang auto-crits
  stunned/slowed enemies.
- **Zone assaults** — entering a zone aggros EVERY monster in it (the quest
  tracker counts them down), and the boss only emerges once the zone is
  cleared. Melee classes have better base stats than ranged (LoL-style) to
  pay for the risk of fighting up close.
- **Attributes & Combat Rating** — every level grants 5 attribute points
  (STR/AGI/INT/VIT) allocated in the skill menu's Attributes tab; each class
  converts them at different scaling ratios (an assassin gets 3x more from
  AGI than STR). Your **Combat Rating** (under the gold display) sums your
  whole build into one power number.
- **Monster levels** — every monster has a level (shown on the target
  reticle, color-coded by threat) and per-species growth rates: a boss
  gains far more per level than a wolf. The codex lists each monster's
  scaling and projected stats at Lv 25/50. Cap: 100.
- **14 terrains with unique mechanics** (terrains.gd) — beyond the four
  story zones: Scorched Wastes (magma falls from the sky, floors collapse
  into lava), Frozen Expanse (slippery ice speeds everyone up, constant
  snowfall), Restless Graveyard (zombies claw out of the ground), Scorching
  Dunes (sandstorm gusts shove everyone), Poison Bog, Crystal Caverns (mana
  surge + shard bursts), Thunder Plains (lightning strikes + rain), The Void
  (slowing rifts), Sanctified Ruins (healing springs), Spore Glade (drifting
  poison clouds). Preview them all via dev mode's terrain switcher.
- **Telegraphed boss mechanics** — red danger zones mark heavy attacks:
  Fangmaw pounces onto marked ground, Morwen rains blight zones, and
  Vargoth calls greatswords down from the sky. Stand in the red = get hit.
  Regular monsters flash yellow before biting, so every hit is dodgeable.
- **Skill tree** — MMO-style talent rows: a new row unlocks every 10
  levels, you spend up to 10 points per row across 3 columns (max 10 per
  skill), and each column follows one of your class's themes. You gain a
  point every level, so the tree fills out across all of Act 1 and caps at
  level 40. Every point is an increment ("Stab +2.5% damage per point, to
  +25%").
- **Codex** — press C for a gallery of every monster and boss (with stats)
  and a full **visual gear gallery**: every equipment shape (5 weapon types,
  3 armors, 3 boots, 3 charms) rendered at all 7 grades, plus the named
  A-grade epics and each class's S-grade legendary set with its passive.
- **Merchants** — one per zone: buy potions and gear, upgrade your weapon
  and armor (+15% per level), or sell your junk.
- Story: talk to Elder Maren → slay **Fangmaw** → destroy **Morwen** →
  defeat **King Vargoth** (he enrages at 30% health).
  Dying respawns you at the zone start — bosses reset, you keep everything.

## 🛠 How it's built

- **`game/`** — the whole Godot project.
  - `scripts/story.gd` — **all dialogue, quests, zones, enemy stats.**
  - `scripts/classes.gd` — the 4 classes, their abilities and evolutions.
  - `scripts/items.gd` — gear grades, chest tiers, random stat rolls, prices.
  - `scripts/skills.gd` — the skill tree nodes.
  - `scripts/art.gd` — every sprite, drawn as a grid of characters (one char =
    one pixel). Change a letter, change a pixel. No image files needed.
  - `scripts/sfx.gd` — sound effects synthesized in code. No audio files.
  - `scripts/game.gd` — world building, gates, bosses, loot, death/victory.
  - `scripts/player.gd` (abilities, stats, auto-aim), `enemy.gd`, `boss.gd`,
    `hud.gd`, `menus.gd` (all UI screens), `projectile.gd`, `chest.gd`,
    `pickup.gd`.
- **`open_editor.bat`** — opens the project in the Godot editor to explore.
- **Autotest**: the game can play itself to catch bugs. Run:
  `tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game res://scenes/test.tscn`
  It plays the entire storyline (all bosses, a death, the victory screen) and
  prints `AUTOTEST PASS`.

Most art + all sound is generated by code. Character and monster sprites use
**public-domain (CC0) art** from the Dungeon Crawl tileset, dropped into
`game/assets/sprites/` — any PNG there overrides the procedural sprite of the
same name (auto-scaled to fit), so you can restyle any character by replacing
one file, or delete it to fall back to code-drawn art. Godot itself is
MIT-licensed. See `game/assets/sprites/CREDITS.txt`.

## 🗺 Roadmap (how this becomes the MMO)

1. **Done**: solo storyline, 3 bosses, 4 classes + themes, gear/loot,
   skill tree, merchants, keybinding, auto-aim keyboard combat, 14 terrains,
   monster level scaling, **save games** (autosaved to `user://save_<n>.json`
   on story progress / zone changes / menu closes; title screen lists saved
   heroes with continue + delete; up to 6 characters).
2. **Phase 1** (see `DESIGN.md` Phase Plan): choice dialogue + Resonance,
   class openings, Paladin + Warlock, two joinable factions, Chapter 2.
3. **Polish**: real sprite sheets with walk/attack animations (swap the pixel
   grids in `art.gd` — e.g. free CC0 packs from kenney.nl or itch.io),
   more zones and quests.
3. **Steam**: in the Godot editor: *Project → Export → Windows Desktop* gives
   you an `.exe`; upload via Steamworks (one-time $100 Steam Direct fee).
4. **Android**: *Project → Export → Android* (needs the free Android SDK once;
   Godot walks you through it). Add a virtual joystick for touch.
5. **Multiplayer**: Godot has built-in high-level multiplayer
   (`MultiplayerSpawner` / `MultiplayerSynchronizer`). Start co-op (2–4
   friends, one player hosts), then dedicated servers. A true MMO server is a
   much bigger project — co-op first is the proven path.

## 💡 Tips for a beginner

- Break things! Change numbers in `story.gd` (enemy HP, damage), rerun, feel
  the difference. That's game design.
- The Godot docs are excellent: https://docs.godotengine.org — start with the
  "Your first 2D game" tutorial to understand what the scripts here are doing.
