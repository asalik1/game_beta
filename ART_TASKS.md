# ART_TASKS — pack-art customization board (opened 2026-07-06)

Goal: take the installed Pixel Crawler art from "great generic" to
"unmistakably Emberfall". Same etiquette as CH2_TASKS: **one owner per
task, claim before starting**, verify visually before staging.

## Ground rules (all tasks)
- Edit ONLY the installed sprites in `game/assets/sprites/` — never the
  raw packs (Downloads zips). Installed = versioned, license-clean
  (Pixel Crawler is purchased-commercial; raw packs must not be
  redistributed, our edited copies ship fine).
- Every sprite is a matched TRIO: `<name>.png` (static frame, feeds
  codex + portraits), `<name>_anim.png` (idle strip), `<name>_walk.png`
  (walk strip). Edit all three together or the creature flickers
  between styles.
- Frames are square, count auto-detected (width / height). Keep frame
  size; recolor/redraw within it.
- Verify like everything else: upscaled contact sheet first, then
  in-game (scratchpad `shoot_lineup.gd` pattern: spawns kinds by name,
  `--kinds=a,b,c --shot=name`), then `test_quick.bat`; full `test.bat`
  before staging.
- Palette north star: the game's PAL in art.gd — saturated mids, bright
  highlights, near-black outlines. Blight = sickly greens; ember/ash =
  orange-on-char; void = deep violet; Choir = bone + ink + gold.
- **New ANIMATED sheets** (a grid of labelled frames — commissioned/AI
  character sheets, e.g. the six class clips): run them through
  `tools/art/extract_sheet.py` — it keys, de-labels, SOLIDIFIES (kills the
  green background bleed-through), mirrors to face-left, and slices to engine
  strips. Same tool for boss/mob sheets. Full pipeline + the green-holes fix
  writeup: `tools/art/README.md`.

## Tasks (claim by adding your name)

- [ ] **A1 — claimed: agent-palette — Palette unification pass.** Sweep all 34 installed pack
  sprites; nudge any too-bright/too-pastel frames toward the PAL tones.
  Batch-friendly (PIL hue/sat curves), but JUDGE per creature on the
  contact sheet — no blind filters.
- [ ] **A2 — claimed: agent-recolors — Chapter recolor variants.** The wolf/spider families still
  share one look across chapters. From the existing bases, produce:
  `blightwolf` (sickly green-grey), `winterfang` (frost-white),
  `duneprowler` (sand), `storm_harrier` (storm-blue) + spider variants
  (`bog_lurker` murk-green, `deep_stalker` crystal-blue,
  `casket_creeper` bone-pale, `vent_skitter` ember). Install as new
  trios, then point each kind's `"sprite"` field at its variant.
- [ ] **A3 — claimed: agent-factions — Faction dress code.** Choir-flavored kinds (cultist,
  vale_mourner robes, scholar_censor/director) get the Choir look:
  bone-white + ink-black + a gold thread. Wildfang orcs get warpaint
  in tribe colors.
- [ ] **A4 — Ember-touched elites.** A glowing-ember overlay variant
  (eyes + cracks, HDR-friendly warm pixels) usable by the elite
  promotion system as an alternative to pure tint.
- [ ] **A5 — claimed: agent-proposals — Boss art upgrades (taste call — show the user options
  first).** Bosses kept their Crawl casting deliberately. If a pack
  piece clearly beats one (e.g. Banshee vs witch bosses), mock BOTH on
  one screenshot and let the user pick. Never swap a boss silently.
  → **Proposals ready: `PROPOSALS/` (12 sheets + README verdicts).
  Awaiting user picks; nothing installed.**
- [ ] **A6 — claimed: agent-proposals — Identity NPCs (user call required).** villager/warden/
  envoy/merchant/elder are story faces (Sera, Callis, Vessa…). Present
  side-by-side candidates (e.g. Garden humans, Royal Knight for
  Callis) before changing anything.
  → **Proposals ready: `PROPOSALS/README.md`. Note: the Garden
  "humans" turned out to be sandstone statues — not usable as faces.**
- [ ] **A7 — claimed: agent-cover — Hand-made cover art.** `assets/sprites/cover.png`
  (1280x720) replaces the procedural title screen wholesale. The crown
  + four Embers motif is canon; go bigger than the procedural version.

## Boss attack animations — STANDING RULE (owner call, 2026-07-10)

Bosses have no attack animations: the engine hook exists and is no-op-safe
(`Enemy.play_action` — plays `assets/sprites/<sprite>_<action>.png` if present,
silently skips otherwise), but only ~10 of the 27 bosses' abilities even call
it, and ZERO ability-strip art has shipped. From now on:

1. **Every new or reworked boss ships with attack animations** — minimum two
   strips: its signature ability + a generic cast/swing, cut per the boss-sheet
   pipeline (5-row sheets, feet-anchored cells, char-only ability strips,
   mirror-to-left, gamma 0.85; `tools/art/extract_sheet.py`).
2. **The 10-boss redesign hit list (PROPOSALS/) now includes ability strips**
   as part of each redesign's definition of done — no more idle-only installs.
3. **Code pass (separate, zero-risk):** sweep boss.gd + content/ch*_bosses.gd
   and add `play_action("<action>")` at every telegraphed ability's wind-up —
   calls are free until art lands, and each call names the strip the art lane
   must produce. Deliverable includes the per-boss STRIP MANIFEST
   (sprite_key × action list) so generation (PixelLab lane) is a checklist.
   → **DONE 2026-07-10** — see the manifest below.
4. **Co-op note:** `play_action` one-shots are EVENTS, not state — in
   multiplayer phase 2 they ride the boss sync as event RPCs (logged in
   MULTIPLAYER.md §4.1).

### STRIP MANIFEST (code pass landed 2026-07-10)

The rule-3 sweep is DONE: every telegraphed ability across all 21 bosses now
calls `play_action` at its wind-up (91 call sites in boss.gd, up from 10).
Each row below is one strip file the art lane owes:
`assets/sprites/<sprite>_<action>.png` (horizontal one-shot, plays at 6fps,
cut per the boss-sheet pipeline — 5-row sheets, feet-anchored cells, char-only
ability strips, mirror-to-LEFT, gamma 0.85; `tools/art/extract_sheet.py`,
rules in `tools/art/README.md`). Wave-1 already shipped the morwen/korrag/
vargoth strips — those rows are marked ✔.

Action names are a shared MOTION vocabulary, not per-boss lore names — the
same action on two bosses means the same choreography, so poses can be
reused: `bolt` aimed volley cast · `ring` radial burst from self · `slam`
ground blow/shockwave · `rain` calls sky-zones onto the prey · `blade`
falling swords · `lash` walking line of strikes · `beam` piercing lane ·
`cast` single mark cast · `storm` sky-strike call · `blink` teleport ·
`pack` whistle beasts · `summon` conjure adds · `charge` charge wind-up ·
`throw` lobbed projectile · `surface` erupt from underground · `enrage`
threshold flare. Signature moves get their own name (leap, piston, wail,
toll, quench, breath, freeze, hymn, shift, arc, split, verdict, storm).

**Prerequisite:** `play_action` only fires on a boss that HAS an idle strip.
vess / serane / rotmaw / kaethra are static PNGs today — each needs
`<sprite>_anim.png` (idle) before any ability strip will play.

| Boss (kind) | sprite key | action | ability it represents |
|---|---|---|---|
| Fangmaw (ch1) | `direwolf` | leap | Pounce — marks the circle, crashes down (signature) |
| | | charge | telegraphed charge wind-up (shared `_do_charge` flash) |
| | | slam | Ground Rake — fissure races down your lane |
| | | pack | calls the pack at 50% |
| Morwen (ch1) | `morwen` | rain ✔ | Blight Rain (signature) — SHIPPED |
| | | bolt ✔ | 3-bolt spread — SHIPPED |
| | | ring ✔ | 12-bolt ring — SHIPPED |
| | | blink ✔ | retreat blink — SHIPPED |
| Vargoth (ch1) | `vargoth` | blade ✔ | Blade Storm (signature) — SHIPPED |
| | | slam ✔ | shockwave slam — SHIPPED |
| | | enrage ✔ | 30% enrage — SHIPPED |
| Korrag (ch2) | `korrag` | lash ✔ | Lightning Lash (signature) + whip snap — SHIPPED |
| | | pack ✔ | pack whistles 66/33% — SHIPPED |
| | | storm ✔ | Storm Breaks 30% + broken-storm strays — SHIPPED |
| Choir Mother (ch2) | `choirmother` | ring | Requiem — three rippling rings (signature) |
| | | bolt | Verse Volley |
| | | cast | Hymn of Hunger — the feeding mark |
| | | summon | the choir answers (60%) |
| | | blink | retreat blink |
| | | enrage | Crescendo (25%) |
| Warden Null (ch2) | `nullwarden` | piston | Piston Protocol — stamping grid (signature) |
| | | beam | Beam Spoke — lane rake |
| | | slam | shockwave slam |
| | | enrage | Armor Shed (50%) + Overdrive (25%) |
| The Sexton (ch3) | `sexton` | slam | Vale churn cluster + shovel swipe |
| | | summon | a grave shambler claws up |
| | | surface | Shovelwork exit eruption (the dig-in is an instant vanish — no strip moment exists) |
| Vess (ch3) | `vess` | wail | The Silence (signature) — needs `vess_anim.png` FIRST |
| | | bolt | Grief Fan |
| | | ring | wail ring |
| | | blink | retreat blink |
| | | enrage | Keen (30%) |
| Saint Varo (ch3) | `king` | toll | The Toll — bell strike (signature) |
| | | blade | Reliquary Rain (same falling-sword motion as vargoth_blade) |
| | | slam | Reliquary Slam |
| | | summon | censer placements/relights (setup, 60%, 30%) |
| | | enrage | Saint Varo Stands (25%) |
| Calda (ch4) | `cultist` ⚠ | quench | the Quench at the pool, clean or through-you (signature) |
| | | throw | white-hot slag lob |
| | | lash | hammer lines |
| Cinderhide (ch4) | `direwolf` ⚠ | breath | Vent Breath — lava cone (signature) |
| | | charge | baited charge (shared wind-up) |
| | | rain | Ember Rain |
| | | enrage | plate shed + 30% enrage |
| Ashpriest Ordo (ch4) | `ashpriest` | verdict | The Verdict — half-arena judgment (signature) |
| | | bolt | Brand Volley |
| | | rain | enrage magma rain (20%) |
| | | summon | Sons of the Judge (66/33%) |
| | | enrage | the Judge Attends (20%) |
| Whitepelt (ch5) | `whitepelt` | charge | Ice Charge (signature; shared wind-up) |
| | | pack | pack calls (66/33%) |
| | | slam | frost stomp + pelt drums + the wall-slam crash |
| Serane (ch5) | `serane` | freeze | Flash Freeze (signature) — needs `serane_anim.png` FIRST |
| | | beam | Shatter Lance |
| | | rain | icicle rain |
| | | blink | retreat blink |
| | | enrage | Keystone Cracks (40%) |
| Mother Halla (ch5) | `cultist` ⚠ | hymn | Frost Hymnal (signature) |
| | | freeze | Queen-stirs Flash Freeze (shared helper w/ Serane) |
| | | bolt | lullaby volley |
| | | summon | dreamers drift in |
| | | enrage | the Queen Stirs (25%) |
| Drowned Auroch (ch6) | `spider` ⚠ | charge | Gore Rush (shared wind-up) |
| | | slam | Wallow — shockwave + poison splash |
| | | surface | Submerge resurfacing under you (signature; the sink is an instant vanish) |
| Rotmaw (ch6) | `rotmaw` | lash | Vine Lash — closing root ring (signature) — needs `rotmaw_anim.png` FIRST |
| | | bolt | Spore Volley |
| | | summon | blooms sprout |
| | | enrage | Full Bloom (30%) |
| Kaethra (ch6) | `kaethra` | shift | Form Swap 80/60/40/20% (signature) — needs `kaethra_anim.png` FIRST |
| | | charge | Huntress charge (shared wind-up) |
| | | throw | Huntress thrown spear |
| | | slam | Huntress shockwave |
| | | ring | Bloom radial burst |
| | | bolt | Bloom aimed fan |
| Veyx (ch7) | `stormwarden` | arc | the Arc — chain to rod or player (signature) |
| | | ring | Squall scatter |
| | | storm | Static Field strikes |
| | | summon | conductor rods (setup + 30%) |
| | | enrage | the Current Unbound (30%) |
| Echo of the Unnamed (ch7) | `assassin` | split | Unnaming — the mirror copies (signature) |
| | | blink | blink-strike |
| | | throw | dagger fan |
| | | enrage | Refuses to be Forgotten (25%) |
| Cyrraeth (ch7) | `stormmouth` | storm | Storm Rotation — the quiet wedge (signature, P2/P3) |
| | | lash | P1 Lightning Lash (shared Korrag helper — needs its OWN `stormmouth_lash`) |
| | | bolt | P1 verse fan |
| | | cast | arc chip between rotations |
| | | summon | vow-keepers |
| | | enrage | phase flares — the Mouth Opens (60%) + the Word Unfinished (25%) |

Manifest notes:
- **89 strips total; 10 shipped (✔), 79 owed.** Of those, 11 sit on
  placeholder sprites (⚠): `cultist` (Calda + Halla — also the trash-mob
  sheet) and `spider` (Auroch), plus Cinderhide riding Fangmaw's `direwolf`
  sheet. **Hold art for ⚠ rows until each boss's own redesign sprite lands**
  (see the PROPOSALS/ hit list) — the calls are wired and re-key
  automatically via `stats["sprite"]`, so nothing needs re-coding when keys
  change; cut the strips under the NEW key.
- The Echo intentionally wears the hero `assassin` sheet (it IS the player's
  mirror) — its idle already animates, so its 4 strips light up the moment
  they land. Its action names deliberately avoid the hero clip vocabulary
  (attack/cast/dash/ult/…) so nothing collides with player animations.
- Veyx's `stormwarden` key is its own sheet (Korrag's is `korrag`) — no
  sharing there despite the name.
- Cyrraeth's P3 continuous lightning (1.5s cadence) intentionally has NO
  play_action — retriggering that fast would starve every other strip.

## OWNER PLAYTEST NOTES — v3 boss sprite polish (2026-07-12)
After the v3 hi-res bodies + ability strips + FX-sync shipped, owner q/a flagged:
1. **Vess** — REMOVE the smoke from her mouth (owner: "no smoke from mouth",
   emphatic — I first mis-read it as *add* smoke and made it worse). The smoke
   was baked into the ORIGINAL creation prompt: metadata.json literally reads
   `faint blue-white keening light at the mouth`. FIX = regen from the ORIGINAL
   prompt with ONLY that clause deleted (read metadata FIRST — see CLAUDE.md
   "PixelLab characters — regenerating an EXISTING one"). ~3 gens + re-cut.
2. **Nullwarden** — weapon is inconsistent/choppy across clips: present in some
   frames/directions, absent in others (v3 gen artifact). FIX: regen with a
   firm single-weapon description (~3 gens + re-cut) — v3 won't *guarantee*
   consistency, so may need a hand-fix pass.
3. **Whitepelt (Hrolgar)** — idle/walk carry NO axe but the ability strip does
   → the axe pops in only on attack. FIX: regen idle/walk WITH the axe so every
   clip matches — but KEEP the canonical **white-furred bone-SKULL hulk**; only
   add the axe. (A from-scratch v3-128 re-roll on 2026-07-12 lost the skull face
   + went blue/demonic = drift → REVERTED. Correct path: find the original
   hrolgar's creation prompt in its export metadata.json, regen from THAT +
   "holding a battle-axe". Deferred until the metadata prompt is pulled.)
4. **Kaethra** — wants a directional STAB/lunge attack animation on her charge.
   FIX: `animate_character` a "stab" clip (8-dir) + `play_action("stab")` at the
   charge/contact site (~48 gens + wiring).
5. **GENERAL (all melee bosses)** — close-range contact hits (`take_damage` at
   `_reach()`) played NO swing. FIXED (4bc3850 + follow-up): `play_action("melee")`
   wired at all 16 contact sites; with the ability-swing fallback the boss now
   swings its attack animation on every close hit. A dedicated `<key>_melee`
   `animate_character` clip auto-takes-over per boss IF generated later (optional
   polish, ~48 gens each) — the wiring already prefers it over the ability.

Priority vs the ~285-gen budget + shared PixelLab queue (other agent on base
archer): do the CHEAP wins first — #1 as FX (0 gens), #3 whitepelt axe (~3),
#2 nullwarden (~3). The ANIMATION items (#4, #5) are ~48 gens each and should
wait for a budget reset or be scoped to 1–2 key bosses. #5 also needs a code
pass (play_action at the melee contact sites) independent of the art.

## Source material
- Raw packs: `C:\Users\asali\Downloads\*.zip` (Pixel Crawler bundle,
  Ninja Adventure CC0, Small_Bat, Bat_Fur). Re-extract to a scratch
  dir as needed; NA `Actor/Monster/` has ~60 more mobs + CC0 audio/FX.
- Install pipeline reference: tight-crop frames to union content bbox
  (squared) or premium 64px sheets render tiny — see the memory notes
  or the installer in this session's scratchpad.
