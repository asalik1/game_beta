# Crownless NPC art direction

## Purpose and scope

This is a pre-production brief, not an asset-installation plan. It turns the
NPCs currently placed in hubs or chapter wanderer pools into reviewable visual
briefs. It also records narrative-only people who should receive art only when
they become placed NPCs. Bosses, monsters, environmental talk targets, and the
existing developer placeholder gallery are deliberately out of scope.

The previous refresh failed because rendered concept art was reduced into a
tiny sprite. That approach is prohibited here. The 32px NPC sheets are legacy
procedural exceptions, not the visual target. New named NPCs should be made at
the **boss-quality** bar: intentionally a little less crisp and information-
dense than the player heroes, but never reduced to mob-grade shorthand. Keep
the tool's native pixels; never resize merely to hit a number, and never use a
rendered illustration as a source and downsample it into a game sprite.

## Lore evidence

Each roster entry cites the source conversation or placement that supports its
visual choices. Citations are local code references: `file.gd : convo_id`.
Where the character is an unnamed placement, the source is the chapter's
`npcs` or `WANDERERS` data. A cited prompt may add readable clothing and props,
but it must never contradict the cited text or turn a non-combatant into a
combat silhouette.

## Measured art references

These are source-frame sizes, calculated as idle-strip width divided by the
number of horizontal frames. They are **not** the intended on-screen size, and
the runtime uses two different paths:

- Custom animated heroes measure the first frame's alpha body bounds, then
  scale that body to `HERO_TARGET_BODY × CHAR_RENDER_SCALE`
  (`game/scripts/player_core.gd:464`, `:610`). Their first-frame bodies are
  103–120 native pixels and render at roughly 84–95px: a mild 1.06–1.43x
  downsample, not 3–5x supersampling.
- Current NPCs use the generic `Art.scale_for` seam
  (`game/scripts/game_world.gd:937`; `game/scripts/art.gd:2819`). Named NPCs
  should retain that intentional, slightly softer presentation instead of
  being promoted to hero-level sharpness.
- Bosses use enemy `stats["scale"] × CHAR_RENDER_SCALE`
  (`game/scripts/enemy.gd:330`). Their major presence is gameplay render scale,
  not large source frames. Fangmaw's source body is enlarged about 1.66x,
  Morwen's about 2.09x, and Vargoth's about 2.56x.

| Set | Source idle files | Frame sizes (px) | Mean | Median | Population SD |
| --- | --- | --- | ---: | ---: | ---: |
| Heroes | `warrior`, `archer`, `mage`, `assassin`, `paladin`, `warlock` | 182, 242, 202, 166, 174, 180 | 191.00 | 181.00 | 25.29 |
| Boss reference sample | `fangmaw`, `morwen`, `vargoth`, `korrag`, `choirmother`, `nullwarden` | 139, 117, 138, 126, 121, 141 | 130.33 | 132.00 | 9.41 |

The hero range is therefore broad (76px) because each custom character has a
different export canvas; its coefficient of variation is 13.24%. The boss
source-frame range is narrower (24px; coefficient of variation 7.22%) despite
their much larger in-game silhouettes. In the boss sample, **Morwen** is the
117px frame (`585x117`, five frames) and **Warden Null** is the 141px frame
(`141x141`, one frame).

## Height ladder

Live humanoid NPCs are alpha-body normalized so transparent source padding
cannot silently determine their gameplay height. The target ladder is authored
in `Balance.NPC_HEIGHT_BY_SPRITE` / `NPC_HEIGHT_BY_CONVO`:

- Adult men use the warlock baseline: `1.00`.
- Adult women use the archer baseline: `0.95`.
- Lore-led deviations are deliberately narrow (`0.92–1.04` for adults); only
  the small miller's boy is below that at `0.88`.
- No adult NPC exceeds the warrior's `1.08` height ceiling.

This is a physical-presence rule, separate from the fidelity hierarchy: heroes
remain sharper, bosses remain deliberately upsized, and NPCs retain their
slightly softer boss-quality treatment.

## Production contract

1. Create one **new** south-facing pixel-character body per named NPC or
   approved named variant at boss-level detail density. Preserve the native
   export; do not resample it to force a common dimension.
2. Use a four-frame horizontal idle strip only after the single south-facing
   body passes review. Its width is four times its native frame width. At game
   size it must read by silhouette, posture, and at most three
   color/material signals.
3. After a body passes review, inspect all eight rotations before requesting
   idle or walk animation. Reject a body if a direction changes its body type,
   outfit, or carried object.
4. For an existing PixelLab character, download and read `metadata.json` first;
   regenerate from its exact original prompt and change only the approved
   clause. These NPCs are new work, so the prompts below are the source of
   truth until a body exists.
5. Keep the source prompt, character id, rotation review, and approved export
   name beside the final asset. Do not overwrite a live sprite until the body
   is approved in-game.

## Shared prompt

Append the character-specific tail in the roster to this master prompt. The
tail is the actual proposed prompt for that NPC; it is intentionally specific
enough that another artist or generation run can reproduce the decision.

> Native <APPROVED_NPC_CANVAS> dark-fantasy RPG pixel character; retain the
> native export rather than resampling it. Hand-authored clean pixel clusters
> at Crownless boss-level detail density: deliberate, chunky, and readable,
> with slightly less fine material detail than a player hero. Crisp near-black
> outline, south-facing neutral idle, full body and boots visible, transparent
> background, no cast shadow, no text, no UI, no scenery, no painterly
> rendering, no smooth gradients, no 3D, no chibi proportions. Adult human
> proportions unless stated otherwise. Restrained charcoal, ash, worn leather
> and weathered cloth; reserve saturated color for one deliberate faction or
> story accent. Readable silhouette before detail; no drawn weapon unless the
> lore makes the character a present combatant.

### Shared negative prompt

> no generic hooded wizard, no generic purple merchant, no regal spotless
> armor, no oversized weapon, no glowing eyes unless specified, no modern
> luggage, no floating effects, no sexualized costume, no duplicate limbs,
> no cropped feet.

## Faction language

These are visual rules, not interchangeable costumes.

| Family | Read | Materials and color cue | Must avoid |
| --- | --- | --- | --- |
| Emberfall civilian | Work survives because people maintain it. | Patched wool, practical aprons, bread/wood/rope, ash gray with one warm faded color. | Clean peasant cosplay or identical villagers. |
| Accord | Careful public service under moral strain. | Field gray, muted blue-gray, paper/ledger/measure tools, functional leather. | Shiny paladin plate or police-uniform severity. |
| Cinderborn / Compact | Order, contracts, industry, profit. | Soot, dark oxblood, brass, wax seals, ledger straps. | Royal costume, steampunk goggles, cartoon greed. |
| Hollow Choir | Funeral faith that makes rot sound gentle. | Dull bone, mourning black, faded plum, worn devotional cord. | Villain sorcerer, pristine nun habit, explicit gore. |
| Wildfang | Clan practicality and animal kinship, never a costume party. | Fur trim only where useful, hide, horn/bone tools, weather layers. | Bestial caricature or barbarian bikini armor. |
| Chapter 5 winter folk | Cold changes every choice. | Felt, quilted wool, snow-stiff leather, muted blue-white accent. | Bright Santa-red, clean snow fashion. |
| Chapter 6 Deep folk | People negotiating rot, bloom, and cure. | Wet reed, mud-brown, drowned gray; bloom color only as a troubling small accent. | Generic druid or fluorescent plant person. |
| Chapter 7 keepers | Ritual work held together by tired people. | Storm-dark cloth, rain capes, vow tokens, iron or slate. | Lightning wizard silhouettes. |

## Fidelity hierarchy

This is the rendering-quality ladder for character art. It is an art-direction
decision, not a rule that every source PNG must share one dimension.

| Tier | Visual job | Detail density and treatment |
| --- | --- | --- |
| **Hero** | The player's eye stays here during play. | Highest clarity and most legible small material detail; cleanest silhouette, best animation coverage. |
| **Boss** | Readable spectacle and fight language. | Big, deliberate pixel clusters, strong silhouette and signature prop/material; less fine body detail than a hero is acceptable. Bosses are intentionally upsized at runtime. |
| **Named NPC** | Human story signal and interaction target. | Match the boss-quality construction language: authored silhouette, meaningful props, limited but confident texture. Slightly softer/less crisp than a hero by design; never generic or mob-grade. |
| **Mob** | Fast combat classification. | Compact shorthand for role, faction, and attack readability; lower detail budget than a named NPC. |

The existing NPC setup already gives each person a deterministic small size
variation around the character scale (`Balance.NPC_SIZE_VAR` and
`game/scripts/game_world.gd:_make_npc`). Preserve that gameplay-language
relationship. The art pass should raise **source quality**, not make villagers
visually outrank the player character.

## Roster prompts

### Chapter 1: Emberfall and road wanderers

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Elder Maren** | `story.gd : maren_*`; `ch2_hub.gd : ch2_maren_hub`; `ch7_quests.gd : ch7_briefing` — recruiter, survivor, and clear-eyed keeper of ugly arithmetic. | Older Black woman; slim, steady stance; close-cropped silver hair under a faded rust headscarf; ash-gray layered robe and dark teal work shawl; carved walking cane and one small muted-cyan shard token. Warm but unflinching, not a priest or wizard. |
| **Tinker Osla** | `story.gd : wander_tinker` — fixing a broken cart and counting what repair costs. | Short, broad-shouldered roadside tinker; rolled sleeves, patched charcoal apron, small tool roll and a loose cart wheel spoke; copper-brown scarf, grease on hands. Read as practical repair before adventurer. |
| **Ragged Soldier** | `story.gd : wander_deserter` — hears the buried hum and carries shame for leaving. | Exhausted former infantryman; threadbare field coat, snapped spear shaft used as walking stick, helmet tied to pack rather than worn; hollow posture, no active weapon pose. |
| **Pilgrim of the Flame** | `story.gd : wander_pilgrim` — faith without recruitment pressure. | Older pilgrim with travel-worn ember-colored scarf, plain ash cloak, tiny protected candle lantern at belt; open empty hands, patient posture, no halo or magic. |
| **Old Hunter** | `story.gd : wander_hunter`; `ch1_quests.gd : ch1_hunter` — knows the wood and distrusts easy answers. | Lean elderly woodsman; weathered green-brown coat, worn bow unstrung across back, rabbit-skin pouch, one pale moonwell charm; watchful sideways stance, not a ranger hero. |
| **Roadside Peddler** | `story.gd : wander_peddler` — stockless but sharp, trades in gossip and survival. | Thin road peddler with collapsed handcart handle, patched long coat, dangling empty price tags and a small rumor ledger; dry expression, faded ochre accent, clearly distinct from the shop merchant. |
| **Miller's Boy** | `story.gd : wander_orphan`; `ch1_quests.gd : ch1_millers_hat` — looking for a missing hat and its blue-tipped feather. | Small, not toddler, mill worker's son; oversized flour-dusted vest, rolled trouser cuffs, blue-tipped feather tied to wrist, tiny sack of grain. Vulnerable but not ragged fantasy orphan cliché. |

### Chapter 2: Maren's Camp

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Ser Aldric** | `ch2_aldric.gd : ch2_aldric` — the man who killed Vargoth, gave up his ember, and carries a bad arm and dangerous knowledge. | Lean older veteran; dulled steel breastplate beneath a charcoal travel mantle, modest amber tabard worn thin, visibly stiff bad arm held close, sheathed old sword, no crown or heroic pose. The silhouette says spent cost, not royal knight. |
| **Warden Callis** | `ch2_factions.gd : ch2_accord_recruit` — Accord recruiter who asks shard-bearers to become less for everyone else. | Middle-aged woman field warden; disciplined gray-blue coat over practical leather, paper map case and capped ink tube, hand near a plain hilt but not drawing it. Controlled, tired, morally serious; no paladin shine. |
| **Envoy Vessa** | `ch2_factions.gd : ch2_cinder_recruit` — Cinderborn contract-maker who treats history as paperwork. | Sharp Cinderborn envoy; dark oxblood coat, brass clasp, sealed document tube, narrow ledger at hip, immaculate gloves made slightly travel-worn. Confident economic power, never a queen or mage. |
| **Caged Beastkin** | `ch2_factions.gd : ch2_beastkin_cage` — calls both packs cages and remembers who opens doors. | Scarred beastkin adult with human-readable face, cropped practical fur, worn hide vest, one broken restraint collar and chain remnant. Seated or hunched silhouette; grief and alertness, no berserker pose. |
| **Choir Pilgrim** | `ch2_factions.gd : ch2_choir_pilgrim` — gentle, unsettling, says the Choir waits. | Quiet middle-aged woman pilgrim; faded plum-and-bone mourning habit, small hymn cord, covered hands, head slightly inclined as if listening. Calm rather than malicious; no glowing rot. |
| **Sentry Piet** | `ch2_hub.gd : ch2_sentry` — camp watch, anxious about wolves and what shard-bearers may become. | Young camp sentry; oversized patched watch coat, spear planted rather than brandished, kettle-cord and cheap whistle, sleep-deprived eyes. Defensive village labor, not uniformed soldier. |
| **Widow Sera** | `ch2_hub.gd : ch2_refugee` — lost the mill, holds the memory of its blue door. | Middle-aged mill worker and widow; flour-dulled gray dress under a practical shawl, blue paint smear on one sleeve, small key ring at belt. Grounded grief, not a mourning-gown stereotype. |

### Chapter 3: the Vale

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Cantor Ilse** | `ch3_zones.gd : ch3_briefing` — thirty years in the Choir; now speaks of mercy for Saint Varo. | Older Choir cantor; severe but worn bone-and-black habit, hymnal wrapped in weather cloth, throat scarf, narrow posture softened by tired compassion. One dull plum stitch; no necromancer staff. |
| **Warden Corin** | `ch3_zones.gd : ch3_accord` — recognizes grief yet insists the thing beneath it must starve. | Accord field researcher; rain-dark gray coat, grave-dust gaiters, folded stone rubbings and survey chisel, restrained blue-gray armband. Thoughtful tactical reader, no crusader armor. |
| **Factor Imre** | `ch3_zones.gd : ch3_cinder` — wants the road reopened and speaks in invoices. | Compact factor; stout travel coat, black ledger strapped to chest, wax-seal kit, polished but muddy boots. Commercial confidence under funeral gloom; no aristocratic finery. |
| **Old Fenna** | `ch3_zones.gd : ch3_refugee` — a displaced local whose coat and home retain meaning. | Elderly Vale woman; heavy inherited coat with hand-sewn repair, home-key charm on cord, small bundle held toward chest. Face the road but body turned toward home. |
| **Old Digger Haim** | `ch3_zones.gd : ch3_wander_digger` — believes graves give grief somewhere to go. | Very old grave-digger; bent but capable, clay-spattered coat, short square spade, fingerless gloves, grave soil only on workwear. Not a gravedigger villain. |
| **Mute mourner** | `ch3_zones.gd : ch3_wander_mute` — named by the conversation, not by voice. | Silent Vale mourner; plain black layers, folded slate and chalk for messages, pale cloth tied over throat but not medical or horror imagery. Make silence legible through a deliberate writing prop. |
| **Brother Osk, formerly** | `ch3_zones.gd : ch3_wander_defector` — ex-Choir keeper of a ledger waiting for burial to begin. | Former Choir brother; habit cut short into a work coat, old prayer beads tucked away, open ledger and ordinary pen. Deprogramming in progress, no cultist menace. |
| **Archivist Lene** | `ch3_zones.gd : ch3_wander_archivist` — Accord tactician who reads graves and pays field rate. | Focused Accord archivist; slim gray-blue field cape, portable writing board, stone rubbings, ink-stained gloves. Scholar outdoors, not a library wizard. |
| **Grave-Goods Peddler** | `ch3_zones.gd : ch3_wander_peddler` — sells mourning goods honestly and wants out of grief business. | Tired peddler with a compact tray of veils, ribbon, candles, and repair needles; plain dark coat, no corpse ornaments, faint hopeful warm scarf. |

### Chapter 4: the foundry

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Overseer Brann** | `ch4_zones.gd : ch4_briefing` — signed the dockets and owns the foundry's terrible arithmetic. | Broad, soot-marked foundry overseer; heat-cracked leather apron, brass tally counter, ash goggles pushed up rather than worn, work gloves. Guilty manager, not steampunk inventor. |
| **Warden Edda** | `ch4_zones.gd : ch4_accord` — reads the foundry as a seal being broken by attention. | Weathered Accord field warden; ash-gray practical coat, restrained leather reinforcement, sealed pattern-map folio, soot scarf, one heat-cracked glove. Blunt analyst, not knight or mage. |
| **Old Smith Harl** | `ch4_quests.gd : ch4_wander_smith` — still quenches in water because ordinary iron matters. | Elderly smith; water-stained apron, simple tongs, small blue-gray quench flask, burnt forearms, quiet work stance. The water is the story accent; no flaming hammer. |
| **Compact Clerk Voss** | `ch4_zones.gd : ch4_wander_clerk` — administrative Compact presence in the heat. | Neat Compact clerk with soot-protective sleeve covers, document satchel, brass seal press, dark oxblood collar. Precise but physically out of place in the forge. |
| **Lay Preacher Immo** | `ch4_zones.gd : ch4_wander_preacher` — industrial faith near the heat. | Working-class preacher; heat-faded mourning coat, small folded sermon page, coal-blackened nails, modest ember-red thread. Never a fire mage. |
| **Charm Peddler Nix** | `ch4_quests.gd : ch4_wander_charms` — sells verdict and appeal charms with clear-eyed opportunism. | Quick, wiry charm seller; ribboned packet board, wax seals, little brass scales, bright but weathered red ribbon. Street commerce, no magical particle effects. |
| **Accord Sapper Ruel** | `ch4_zones.gd : ch4_wander_sapper` — practical demolition and containment work. | Compact Accord sapper; slate-gray jacket, rolled wire, chalk, small wedge hammer, ear scarf. Engineering silhouette, never bomb-throwing action pose. |
| **Smith Petra, Crew Five** | `ch4_quests.gd : shrine_court` — keeps nine names and rehearses their spacing. | Young exhausted smith; soot-gray work shirt, chisel and narrow memorial strip, one clean patch on apron reserved for names. Make the memorial labor visible. |

### Chapter 5: the frozen shore

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Tracker Yri** | `ch5_quests.gd : ch5_briefing` — asks the player to understand a chieftain feeding forty mouths before confronting him. | Lean Wildfang tracker; snow-stiff hide coat, wolf-tooth tally cord, practical hood, tracker's staff, grain sack patch. Clan authority and compassion, no feral warrior pose. |
| **Warden Sighne** | `ch5_zones.gd : ch5_accord` — carries the unbearable decision around Serane's failing vigil. | Older Accord warden; layered ice-gray field cloak, ledger of vigil names, frosted iron clasp, steady exhausted posture. Duty weighed, not heroic. |
| **Gentle Suli** | `ch5_zones.gd : ch5_cult` — cult-side voice in a chapter about soft madness and sleep. | Soft-spoken Long Sleep adherent; quilted white-gray layers, folded blanket bundle, carefully mended sleep charm. Gentle, human, and unsettling; no sinister cult robe. |
| **Ansa of the Shore** | `ch5_zones.gd : ch5_mother` — counts wagons while waiting for Toma and the other sleepers to wake. | Sturdy middle-aged shore woman; salt-stiff wool, tide rope, waxed wagon ledger, wind-reddened face. Civilian endurance, no warrior gear. |
| **Skald Ottar** | `ch5_quests.gd : ch5_wander_skald` — writes songs about what people stay hard for. | Lean beastkin skald; weather cape, small travel fiddle or frame harp, paper ration tucked in belt, thaw-blue thread. Musician at a fire, not bard spectacle. |
| **Wagon-Driver Pell** | `ch5_zones.gd : ch5_wander_driver` — road labor among sleeper wagons. | Frost-bitten wagon driver; layered gloves, reins looped around waist, cracked lantern, pale road salt on boots. No cult insignia unless lore specifies it. |
| **Cartographer Bree** | `ch5_zones.gd : ch5_wander_mapper` — maps a terrain where memory and snow fail. | Accord cartographer; fur-lined gray-blue coat, map tube, weighted ruler, wind-pinched cheeks. Maps must be a readable prop, not a large scroll. |
| **Peddler Onna** | `ch5_zones.gd : ch5_wander_memories` — sells small, temporary Augusts because mornings matter. | Sturdy middle-aged traveling woman; charcoal hood, patched dark-violet coat, small cart pack, spiced-oil bottles wrapped in cloth, battered price slate. Human warmth under hard business; not a spellcaster. |
| **Ridge Deserter** | `ch5_zones.gd : ch5_wander_deserter` — someone who left a bad arrangement behind. | Weather-beaten former guard; abandoned insignia cut from coat, spearhead used as tent peg, snow cloak, ashamed guarded stance. |

### Chapter 6: the Deep

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Deacon Vela** | `ch6_quests.gd : ch6_briefing` — a Choir leader whose funeral theology cannot contain Kaethra's living tragedy. | Older deacon; drowned-gray habit beneath a reed rain cape, warm loaf wrapped like a relic, modest rot-black staff. Compassionate crisis of faith, no villain priest. |
| **Herbalist Kesh** | `ch6_quests.gd : ch6_wildfang` — cure-camp witness who insists Kaethra be heard as evidence, not reduced to cost. | Wildfang herbalist; waterproof hide apron, reed sample tubes, field knife sheathed, small clean green sprig sealed in glass. Scientist and kin, not druid fantasy. |
| **Warden Palla** | `ch6_zones.gd : ch6_accord` — pattern-reader afraid of growth that ignores boundaries. | Accord warden; mud-dark gray coat, root-measure stakes, annotated map board, one thin pale-green stain at cuff. Apprehensive analyst, no floral armor. |
| **Fisher Dov** | `ch6_quests.gd : ch6_fisher` — lost family to a generous bog and needs a truth with edges. | Older bog fisher; waxed reed cape, net-mending needle, soaked boat gloves, empty fish basket, door-key tied at belt. Avoid monster-fisher visual language. |
| **Blooming Convert** | `ch6_zones.gd : ch6_wander_convert` — a former Choir member joyful about sproutings. | Adult convert in a salvaged Choir coat, flowering reed held carefully, subtle bloom-colored stitch at throat, genuinely happy expression. No body horror. |
| **Sister Ottilie** | `ch6_zones.gd : ch6_wander_doubter` — counts because numbers make small madness manageable. | Exhausted Choir sister; faded habit, tally cord and numbered bone counters, damp cloak, eyes fixed on arithmetic. No green magic. |
| **Cure-Camp Scout Renn** | `ch6_zones.gd : ch6_wander_scout` — field scout caught between camps. | Lean scout; mud gaiters, reed whistle, lightly furred Wildfang features, survey ribbon tied to wrist. Navigation rather than combat silhouette. |
| **Reed-Cutter Ama** | `ch6_zones.gd : ch6_wander_fisher` — forty years of reed labor taught her that use goes both directions. | Older wiry reed-cutter; waxed reed cape, bundled cut reeds, sheathed work knife, wet gloves, canal-line cord. Laborer, not druid or fighter. |
| **Botanist Ferro** | `ch6_zones.gd : ch6_wander_botanist` — measures the Root because what can be budgeted can be starved. | Accord botanist; oversized rain hood, sample satchel, calipers, sealed measuring vials, ink-stained field notes. Rational fear, not plant magic. |

### Chapter 7: the last relay

| NPC | Lore anchor | Prompt tail |
| --- | --- | --- |
| **Warden-Commander Ashe** | `ch7_zones.gd : ch7_accord` — Accord's final chapter field authority. | Senior Accord commander; storm-dark coat over restrained armor panels, wet map case, plain command whistle, one frayed blue-gray tabard edge. Command through posture, not ornate rank. |
| **Consul Verane** | `ch7_zones.gd : ch7_cinder` — the Compact's actual leadership makes its final pitch at the summit. | Senior Cinderborn statesman; rainproof oxblood half-cloak, brass-edged policy ledger, formal gloves, folded storm hood. Pragmatic authority, no crown or weapon. |
| **Apprentice Sorrel** | `ch7_quests.gd : ch7_apprentice` — sixteen, last of a six-hundred-year relay, carrying four lines of a vow. | Thin teenage apprentice, not childlike; soaked keeper coat too large at shoulders, storm-iron shift token, four tiny knot marks on a cord, upright despite fear. No battle weapon. |
| **Retired Keeper Vasse** | `ch7_quests.gd : ch7_wander_keeper` — lost her voice after thirty years of relay shifts but refuses to miss the work. | Older keeper; storm cloak, scarred throat wrapped in practical wool, rain-dark vow slate, hour cord, posture of someone still standing watch. Not a lightning mage. |
| **Storm-Chaser Ilya** | `ch7_zones.gd : ch7_wander_chaser` — civilian reader of dangerous weather. | Agile storm observer; layered oilskin, wind ribbon, compact glass weather gauge, boots tied high. Curious but not reckless hero. |
| **Compact Quartermaster Bel** | `ch7_zones.gd : ch7_wander_quarter` — logistics under collapse. | Compact quartermaster; reinforced satchel, ration stamps, brass tally clips, storm hood over formal collar. Supplies first, status second. |
| **Old Bellringer Tam** | `ch7_zones.gd : ch7_wander_bellringer` — keeps a civic ritual alive at the end. | Frail bellringer; heavy wool, small handbell wrapped to mute it in wind, rope-burned gloves, calm face. A keeper of time, not a cleric. |
| **Summit Undertaker Prue** | `ch7_zones.gd : ch7_wander_undertaker` — works where the ending is close and names still matter. | Middle-aged undertaker; rainproof black-gray coat, folded name tags, compact burial cloth, spade handle, practical expression. No gothic caricature. |

## Narrative-only and deferred targets

These people speak in the story but are not consistently placed as world NPCs.
They should have a portrait or body only after placement, so an asset does not
invent a canonical role ahead of content. The prompt tails below are held for
that moment.

| NPC | Lore anchor | Held prompt tail |
| --- | --- | --- |
| **Bren / Carter / Ren / Osric / The Mother** | `story.gd : opening_*` | Emberfall civilian variants: respectively frightened witness, cold carter, gatekeeper, condemned petitioner, and protective parent. Give each a work-specific prop; none needs a combat silhouette. |
| **The Tome** | `story.gd : opening_warlock` | Do not make a humanoid NPC. Treat as a separate cursed-object art brief: bound book, no face, no floating magic unless its interaction needs it. |
| **Mother Halla** | `ch5_zones.gd : boss_intro` | Do not use as a live hub NPC: she is the Long Sleep shepherd encountered through the boss/story pipeline. The generated civilian concept is retained in the dev-only placeholder gallery. |
| **Kaethra** | `ch6_quests.gd : ch6_kaethra` | Do not create as an NPC sprite in this pass: she is a story-critical transformed figure and needs a separate boss/NPC continuity brief. |
| **Hrolgar Whitepelt / Serane / Cyrraeth** | `ch5_quests.gd`, `ch5_zones.gd`, `ch7_quests.gd` | Do not create as civilian NPCs. They belong to boss and historical-figure pipelines with their own gameplay silhouettes. |

## Review order

The first review batch should be small enough to reject cheaply:

1. Elder Maren, Ser Aldric, Peddler Onna — recurring anchors with distinct
   narrative and silhouette needs.
2. Warden Callis, Envoy Vessa, Caged Beastkin, Choir Pilgrim — establish the
   four Chapter 2 social factions without collapsing them into generic roles.
3. One civilian each from Chapters 3–7: Old Digger Haim, Old Smith Harl,
   Tracker Yri, Deacon Vela, Retired Keeper Vasse.

Approve each body at native size and in the actual game renderer before
generating rotations or animation. The only acceptable next output is a review
sheet of native-size bodies plus their source prompts and lore citations.
