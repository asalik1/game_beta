# Crownless

A **story-driven action RPG** for solo play and optional 2–4 player co-op.
Six classes explore seven Act 1 chapters through branching rooms, faction
choices, quests and boss encounters. Gear, skill trees and class themes shape
your build; the Crucible, Waking Depths and weekly incursions extend the journey.

You are a newly awakened shard-bearer: a fragment of the shattered Ember Crown
has caught in you. The road begins as King Vargoth rises from his keep again,
and follows what waking the old powers means for the rest of Vaelscar.

Built with **Godot 4.4**, targeting **Windows/Steam, Android and iOS** with
shared game code.

## ▶ How to play (right now, on your PC)

Double-click **`run_game.bat`**. That's it — the engine is bundled in `tools/`.

Grass, forest litter, desert sand and snow now use finer painted ground, with
the same material scale and readable combat warnings. [Visual notes](PAINTED_TERRAINS.md).

**Recovered Spoils** protects unopened combat chests and loose coins across saves
and travel. Resume to find the contents in your mailbox, with recovered gold
already in your purse. Letters show the real attachments and keep anything that
doesn't fit. [Details](RECOVERED_SPOILS.md).

Ground overflow now travels safely through co-op joins and lost connections:
your home save keeps it as mail, while ordinary solo saves keep local drops in
the world. [Loot travel notes](LOOT_TRAVEL.md).

**Portal trials** now put rules behind the stones: dodge the Molten Court's warned hot floor, or face the Still Larder with sealed bottles. The exit waits while you collect your spoils, and retreat is free. [Details](POCKET_TRIALS.md).

**One More Mile** brings a traveler into Village Outskirts: walk Tovin to the fire, protect him through two warned encounters, and leave a home on the road. [Details](ONE_MORE_MILE.md).

Stand the old tower's watch in **A Light on the Road**: an optional three-wave
ward defense, the earned Lamplighter title, and a promise to bring back to Mara
in Emberfall. The restored light stays with your character. [Details](WARD_VIGILS.md).

Explore for **Small Mercies**: six stranded creatures can be rescued across the first two chapters. Visit your growing sanctuary at Stillwater Reach or Crownfall, collect painted companions, and use the Journal’s quest tracking to follow discovered objectives. Kept promises now leave signs, a flame and a ribbon in the world. See [SMALL_MERCIES.md](SMALL_MERCIES.md).

Companions now have real steps, hops and wingbeats while following and at the
sanctuary. [Animation details](COMPANION_MOTION.md). Blue-ringed crystals also
bend incoming shots toward visible foes—including enemy bolts aimed at you.
[Refracting crystals](REFRACTING_CRYSTALS.md).

Each hero's sanctuary now remembers rescues made during co-op visits. Pet
cosmetics remain shared across the account; rescue history travels with the
hero. [Rescue history](RESCUE_HISTORY.md).

A thin amber silhouette now keeps your current enemy readable behind solid
props, following its actual attack poses. Toggle **Target visibility** in Combat
& comfort. [Visibility notes](TARGET_VISIBILITY.md).

Co-op now preserves your personal choices, kept promises and chapter history.
First-clear spoils are yours once, independent of the host's progress, including
a reconnect before the victory screen. [Personal history](PERSONAL_HISTORY.md).

Use the scenery in a fight: **red-X Ember Casks** explode and **diamond-marked
Rimehearts** release a slowing frost burst. Interact, swing or shoot to prime
them, then leave the marked circle. Nearby objects can chain together, and the
blast can hurt you too. See [reactive terrain](REACTIVE_TERRAIN.md).

For a quiet diversion, visit **Stillwater Reach near Emberfall** and try river
fishing: four original fish sprites, three lures, a reel-and-release challenge,
saved size records and the Riverkeeper title. See [FISHING.md](FISHING.md).

For testing, **`dev_mode.bat`** launches the same game with an **F1 debug
panel**: god mode, instant class/level/gold/item/gem cheats, zone teleports,
boss spawning, monster clearing, and a live **terrain switcher**.

Combat supports **keyboard, controller and touch controls**: your abilities auto-aim at the
nearest enemy (watch the yellow reticle). Enable touch controls in Settings.
Controller play includes analog movement, directional target selection, menu
navigation, an on-screen keyboard and fishing. See [CONTROLLER.md](CONTROLLER.md).
Action keys can be rebound in Settings → Keybinds. Movement and Escape stay fixed.

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
| M | Field atlas (explore, set routes, fast travel) |
| T | Skill tree (spend points) |
| C | Codex (monsters & gear gallery) |
| ESC | Pause (B = rebind keys) |

The **Wayfinder** corner map shows nearby threats, people, revealed chests and
doorways. Open the **field atlas** with **M**, select a room, and choose **Set
route** to keep a gold doorway bearing visible while exploring. **Main trail**
selects the next known step on the story road. The atlas supports pan/zoom,
room details and fast travel to visited sanctuaries or defeated boss arenas.
Routes respect fog of war, story gates and encounter seals. See Codex → Field
notes → Wayfinder for the map legend and controls.

Watch for **INTERRUPT** beneath a boss's health bar. Deal damage to fill the
amber pressure bar before its white fuse runs out; close hits contribute more.
A break cancels that cast and opens a brief **+25% damage** window. If it
completes, dodge the normal ground warning. See [BOSS_INTERRUPTS.md](BOSS_INTERRUPTS.md).

Short ability taps are buffered across the end of a cooldown. The target HUD
calls out reflection, counter stances and other immediate combat decisions;
Pause → **Combat report** explains the last fall. Camera motion, flashes and
hit-stop can be adjusted under Settings → **Combat & comfort**.
Ground-warning rims now fill toward impact and pause with solo combat.
The **Combat foliage** setting reveals the current target through foreground
trees. Discovery announcements appear one at a time and wait behind menus.
Combat framing shifts the view toward your current target, widening for distant
opponents and returning to the usual scale for close fights. A gold trail on
target health bars briefly shows the damage just dealt. Combat framing has its
own toggle; Camera lead controls the strength of the shared composition.

Inspect bag or shop gear to compare it with your equipped piece. **Keep**
protects gear from selling, dropping and automatic replacement; **Order** sorts
the bag without moving items. See [the improvement log](AUTONOMY.md) for the
combat, equipment, loot and mobile changes and their validation.
The subsequent graphics and gameplay QA pass is recorded in [QUALITY_PASS.md](QUALITY_PASS.md).
The camera and movement-recovery follow-up is in [COMBAT_FRAMING.md](COMBAT_FRAMING.md).

## ⚔ The systems

- **6 classes** — Warrior (STR), Paladin (STR/holy), Archer (AGI), Assassin (AGI),
  Mage (INT), Warlock (INT) — each with 3 basics + 1 ultimate and a class passive.
- **Themes** — every class has 3 elemental playstyles (Warrior:
  Fury/Bulwark/Earth; Paladin: Holy/Aegis/Wrath; Assassin: Poison/Shadow/Blood;
  Archer: Storm/Venom/Hunt; Mage: Fire/Ice/Wind; Warlock: Curse/Pact/Void),
  unlocked as you level. **Each ability can be
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
  with random substats, in 7 slots: weapon, helmet, armor, gloves, pants,
  boots, charm.
  Your equipped weapon is **drawn in your hero's hand** (A/S weapons glow).
  **Every shape has a stat personality**: Claymores roll massive ATK, daggers
  roll crit, Bows roll attack speed (Haste), Staves roll mana, bulwarks roll
  damage reduction — check the codex for each shape's tag.
  **Named uniques** — one A-grade and one S-grade per weapon shape — carry an
  authored name ("Crownfall, the Kingdom's End") and a **signature passive**,
  and drop rarer than generic gear (a generic A is just a `Dragonforged
  <shape>`). **S-grade gear is class-exclusive.** Substats always roll
  randomly — a unique is chased for its passive and top rolls, not a
  handed-out stat line.
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
- **Codex** — press C for a gallery of every monster and boss (with stats),
  plus a full **visual gear gallery**: the Gear tab shelves every shape across
  all 7 slots at each grade, all 420 named uniques (each with its passive),
  and the gem and bag catalogues.
- **Merchants** — one per zone: buy potions and gear, upgrade your weapon
  and armor (+15% per level), or sell your junk.
- Story: talk to Elder Maren → slay **Fangmaw** → destroy **Morwen** →
  defeat **King Vargoth** (he enrages at 30% health).
  Dying respawns you at the zone start — bosses reset, you keep everything.

## 🛠 How it's built

- **`game/`** — the whole Godot project.
  - `scripts/story.gd` — **all dialogue, quests, zones, enemy stats.**
  - `scripts/classes.gd` — the 6 classes, their abilities and evolutions.
  - `scripts/items.gd` — gear grades, chest tiers, random stat rolls, prices.
  - `scripts/skills.gd` — the skill tree nodes.
  - `scripts/art.gd` — the procedural sprite fallback: characters drawn as a
    grid of letters (one char = one pixel). Real pixel-art PNGs in
    `assets/sprites/` override it per-name; delete one to fall back to code art.
  - `scripts/sfx.gd` — the procedural sound-effect fallback (synthesized in
    code); WAV/MP3 files in `assets/sounds/` override it by name.
  - `scripts/game.gd` — world building, gates, bosses, loot, death/victory.
  - `scripts/player.gd` (abilities, stats, auto-aim), `enemy.gd`, `boss.gd`,
    `hud.gd`, `menus.gd` (all UI screens), `projectile.gd`, `chest.gd`,
    `pickup.gd`.
- **`open_editor.bat`** — opens the project in the Godot editor to explore.
- **Autotest**: the game can play itself to catch bugs. Run:
  `tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game res://scenes/test.tscn`
  It plays the entire storyline (all bosses, a death, the victory screen) and
  prints `AUTOTEST PASS`.

Every sprite and sound still has a code-generated fallback, but the game now
ships mostly **real pixel art and recorded audio** on top of it. Sprites and
sounds are **CC0 / CC-BY** (or generated in-house), dropped into
`game/assets/sprites/` and `game/assets/sounds/` — any file there overrides the
procedural version of the same name (auto-scaled to fit), so you can restyle any
character by replacing one file, or delete it to fall back to code-drawn art.
Godot itself is MIT-licensed. See the `CREDITS.txt` in each assets folder.

## 🗺 Roadmap (how this becomes the MMO)

1. **Done — solo core**: story campaign, bosses, 6 classes + themes, gear/loot,
   skill tree, merchants, keybinding, auto-aim keyboard combat, 14 terrains,
   monster level scaling, **save games** (autosaved to `user://save_<n>.json`
   on story progress / zone changes / menu closes; title screen lists saved
   heroes with continue + delete; up to 6 characters).
2. **Done — Phase 1** (see `DESIGN.md` Phase Plan, shipped 2026-07-04): choice
   dialogue + Resonance, cinematic class openings, Paladin + Warlock, two
   joinable factions (Ember Accord / Cinderborn), Chapter 2.
3. **Done — co-op** (see `MULTIPLAYER.md`, shipped 2026-07-10): opt-in 2–4
   player sessions via lobby codes — host-authoritative combat, instanced loot,
   downed/revive, party UI. Built on Godot's high-level multiplayer
   (`MultiplayerSpawner` / `MultiplayerSynchronizer`).
4. **In progress — art & content depth**: real sprite sheets with walk/attack
   animations replacing code-drawn art (drop CC0/CC-BY PNGs into
   `game/assets/sprites/`), and deeper Act 2–3 content. (**Difficulty tiers /
   NG+** — Normal/Nightmare/Torment with co-op tier sync — shipped 2026-07-24;
   see `DESIGN.md`.)
5. **Steam**: *Project → Export → Windows Desktop* gives you an `.exe`; upload
   via Steamworks (one-time $100 Steam Direct fee). `SteamMultiplayerPeer` drops
   in behind the netcode — lobby codes become Steam invites.
6. **Mobile**: the Android/iOS port core is built (`mobile/`); GitHub Actions
   ("Mobile builds") produces a signed-debug APK and an unsigned iOS `.ipa`,
   both sideload-proven on-device. See `mobile/README.md` and `DISTRIBUTION.md`.
7. **MMO server**: a true persistent server is a much bigger project — co-op
   first was the proven path; a dedicated headless server is a later deployment
   change, not a rewrite (see `DEDICATED_SERVER.md`).

## 💡 Tips for a beginner

- Break things! Change numbers in `story.gd` (enemy HP, damage), rerun, feel
  the difference. That's game design.
- The Godot docs are excellent: https://docs.godotengine.org — start with the
  "Your first 2D game" tutorial to understand what the scripts here are doing.
