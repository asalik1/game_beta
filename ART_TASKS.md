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
- [ ] **A5 — Boss art upgrades (taste call — show the user options
  first).** Bosses kept their Crawl casting deliberately. If a pack
  piece clearly beats one (e.g. Banshee vs witch bosses), mock BOTH on
  one screenshot and let the user pick. Never swap a boss silently.
- [ ] **A6 — Identity NPCs (user call required).** villager/warden/
  envoy/merchant/elder are story faces (Sera, Callis, Vessa…). Present
  side-by-side candidates (e.g. Garden humans, Royal Knight for
  Callis) before changing anything.
- [ ] **A7 — claimed: agent-cover — Hand-made cover art.** `assets/sprites/cover.png`
  (1280x720) replaces the procedural title screen wholesale. The crown
  + four Embers motif is canon; go bigger than the procedural version.

## Source material
- Raw packs: `C:\Users\asali\Downloads\*.zip` (Pixel Crawler bundle,
  Ninja Adventure CC0, Small_Bat, Bat_Fur). Re-extract to a scratch
  dir as needed; NA `Actor/Monster/` has ~60 more mobs + CC0 audio/FX.
- Install pipeline reference: tight-crop frames to union content bbox
  (squared) or premium 64px sheets render tiny — see the memory notes
  or the installer in this session's scratchpad.
