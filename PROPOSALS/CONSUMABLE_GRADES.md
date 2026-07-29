# Consumable Grades — the two-lane F→S potion matrix (PROPOSAL)

Status: DRAFT v9 for owner red-pen (2026-07-29). Nothing installed.
Doc standard (owner, v6): every table carries its Price column, and every over-time effect states the TOTAL and the per-second rate — no line may be readable two ways.

## 0. Owner rulings this design encodes

- Consumables get gear-consistent grades **F→S**, unique name + flavor line per entry; **effect and price scale by grade**.
- **Every potion has a LACED twin**: same headline effect at a **35% discount** (owner-set, v7), with a designed drawback that justifies it. Two lanes: **Accord (clean)** and **Black Market (laced)**.
- **Health and Mana ship BOTH shapes as separate clean product lines**: an instant version AND an over-time version, each with its own black-market twin. Naming: **Potion = instant, Tonic = over-time**.
- **Over-time DURATION scales with grade** (owner, v7): low grades drip fast and short, high grades drip long — the grade's TOTAL is unchanged, only the window stretches, and a higher grade still ticks MORE per second than a lower one (both axes must stay monotonic up the ladder).
- **Potions are at most VERY HELPFUL, never fight-carrying** (owner, v6). S tier is the best bottle in the world, not a win button. Corollaries:
  - **Health Tonic = same totals as the Potion, cheaper and slower** — survival never gets a value multiplier. **Mana Tonic keeps its bigger totals at full price — mana isn't survival.**
  - **Buff windows cap at 6s** — 8s is a fifth of a minimum 45s boss fight. One marked exception: Deathwish Fury's 8s is its black-market bargain, paid for by the heaviest sting.
  - **Warding ramps gently** (owner, v6): potency tops at −25% and duration at 6s.
- **One sting identity per laced ladder** (no rotating gimmicks across grades). Palette: health-side → +damage taken after / reduced healing / bleed-back (owner likes the bleed); mana-side → damage dealt down / pay in health (blood price set HEFTIER, owner v7); Warding → move slow; Might → +damage taken (Deathwish Fury sting owner-set at +15%). Magnitude may scale gently; the TYPE never changes within a ladder.
- **Potions are a luxury at every tier**: clean F = **250g** (~10% of ch1-clear wealth per the 2026-07-09 repricing note in balance.gd; ~5 minutes of ch2 farm).
- **The price curve escalates harder every step up to A, then S sits close above** (owner, v8: the old A→S cliff was closed by RAISING every tier below it — F slightly, then larger and larger bumps up to A; S prices unchanged). Step ratios grow from ~×2.8 at the bottom to ~×3.8 into A, with S a soft ~×1.6 above A.
- **S is never laced** (standing: S carries no drawback — and the black market can't counterfeit legends).
- **No act/chapter gating** — REJECTED: an F potion self-obsoletes when a boss swings for half your HP; price gates the top.
- **One-per-slot loadout restriction** — raised and SCRATCHED: the cost ladder is the deterrent. Room budget / duplicate slots unchanged.
- **No save-migration work** — standing rule: the game is unreleased; old consumable ids simply die (drop unknown ids on load).
- **Flavor ties into the ACTUAL story** (owner, v9 — no copy-paste templates): the clean lane is Accord-chartered alchemy (Kesh's trade, Crownfall's stamp); lines hook real canon — the Ember Guard, the Concord wars, the blight and Mórwyn, the Choir, the seals and their keepers, Crown-bearers and the first fall. The laced lane has ONE unifying secret: **black-market brews are cut with diluted blightwater** — that's why they're cheap, and why every sting reads like the rot (weakened body, sealed wounds, dulled arms, heavy limbs, the loan that collects). Every S still hints it "can be synthesized into something greater" (long fuse into Alchemy, PROPOSALS/PROFESSIONS.md — Kesh's recipes already claim "existing shelf items").

## 1. Shape of the system

- Families and lanes: **Health ×2 shapes, Mana ×2 shapes, Might, Warding, Renewal** — each with an Accord ladder (F→S; Renewal C→S) and a laced ladder (F→A; Renewal C→A). 85 entries total.
- Accord naming spine: **Defective → Apprentice's → Journeyman's → Accordmark → Master's → Masterwork → [unique S name]** (v9: "Guildmark" renamed — the charter is the Accord's).
- Black-market names are street names with a family-recognizable noun: **…Red** = instant health, **…Rust** = slow health, **…Blue** = instant mana, **…Haze** = slow mana, **…Fury** = might, **…Hide** = warding.
- **Laced rule**: same headline numbers (and duration) as the clean twin at that grade, **65% of its price**, plus the lane's sting.
- Ungraded and unchanged: Scroll of Recall, Stone of Unlearning, Palimpsest of the Path.
- **Level-scaled pricing RETIRED for the shelf** — the grade ladder is the price curve. Sell/no-haul rules unchanged. Room budget, drink cd, bag-slot-per-unit unchanged.
- Each entry is its own slottable type in the potion loadout (plan the exact bottle; Q-cycle shows it). Alternative in §11.

### Sanity math — a 45s minimum boss fight
- **Giantsblood** (+30%, 6s): ≈ +4% damage across the fight. A burst-window edge, not a carry.
- **Adamant** (−25%, 6s): blocks ≈ 3% of the boss's total output. It exists to eat ONE combo, not the fight.
- **Heartsblood** at 25% HP: 40% of the missing 75% = 30% of max back, once, for a room budget slot.
- **Everbloom**: same total as Heartsblood but spread over 8s — burst damage runs straight through the drip.

## 2. HEALTH, instant — the Potion (the red you slam)

Instant, % of MISSING hp (anti-facetank; Constancy resonance still multiplies it). The ch1–3 teaching freebie becomes a literal Defective (F) unit — precious at these prices.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Health Potion | restore 8% of missing HP, instantly | 250g |
| E | Apprentice's Health Potion | restore 11% of missing HP, instantly | 700g |
| D | Journeyman's Health Potion | restore 14% of missing HP, instantly | 2,200g |
| C | Accordmark Health Potion | restore 17% of missing HP, instantly | 7,000g |
| B | Master's Health Potion | restore 22% of missing HP, instantly | 25,000g |
| A | Masterwork Health Potion | restore 28% of missing HP, instantly | 95,000g |
| S | Heartsblood | restore 40% of missing HP, instantly | 150,000g |

- F: "A first-year's brew that separates in the vial. Shake well and hope."
- E: "Brewed under a master's eye in the Accord's teaching halls. Closes small wounds; sours on the tongue."
- D: "The Ember Guard marched on this recipe. Half the Vale still carries one, years after the Guard stopped marching."
- C: "The Accord seal in the wax is the standard every potion in Crownfall is judged against."
- B: "A master's reduction, twice distilled. It finds the deep wounds first."
- A: "The finest red an alchemist can sign. The Grand Archive ledgers every vial ever sold; the page is short."
- S: "The Archive says no such brew exists. The Guard's last quartermaster swore one vial rode to the first fall in a Crown-bearer's saddlebag. Alchemists theorize it could be synthesized into something greater."

### Black-market lane — sting: the mend weakens the body (+damage taken)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Gutter Red | restore 8% of missing HP, instantly | +8% damage taken, 5s | 165g |
| E | Brawler's Red | restore 11% of missing HP, instantly | +8% damage taken, 5s | 455g |
| D | Dockside Red | restore 14% of missing HP, instantly | +10% damage taken, 5s | 1,450g |
| C | Thinner's Red | restore 17% of missing HP, instantly | +10% damage taken, 5s | 4,600g |
| B | Bleakvein Red | restore 22% of missing HP, instantly | +12% damage taken, 5s | 16,500g |
| A | Hollowbone Red | restore 28% of missing HP, instantly | +12% damage taken, 5s | 62,000g |

- F: "Cut with blightwater in some Sable Court cellar. Puts the blood back; doesn't ask where it goes."
- E: "Fangmoot pit medicine. You'll stand up softer than you fell."
- D: "No Accord stamp, no questions, no warranty on the ribs."
- C: "Thins the blood on its way through. The trace of rot is the recipe, not a flaw."
- B: "Brewed the winter the blight reached the Vale. Works fast, leaves the door open."
- A: "Fills the wound and hollows the bone. The Choir calls that a fair trade. The Choir would."

## 3. HEALTH, over-time — the Tonic (the red you sip)

Same TOTALS as the same-grade Potion at ~60% of its price — the discount is the wait. Duration grows with grade (owner's shape rule): a Defective drips out in 4s, Everbloom takes its full 8 — and the per-second rate still climbs every step.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Health Tonic | restore 8% of missing HP TOTAL, over 4s (2%/s) | 150g |
| E | Apprentice's Health Tonic | restore 11% of missing HP TOTAL, over 5s (~2.2%/s) | 420g |
| D | Journeyman's Health Tonic | restore 14% of missing HP TOTAL, over 5s (~2.8%/s) | 1,300g |
| C | Accordmark Health Tonic | restore 17% of missing HP TOTAL, over 6s (~2.8%/s) | 4,200g |
| B | Master's Health Tonic | restore 22% of missing HP TOTAL, over 6s (~3.7%/s) | 15,000g |
| A | Masterwork Health Tonic | restore 28% of missing HP TOTAL, over 7s (4%/s) | 57,000g |
| S | Everbloom | restore 40% of missing HP TOTAL, over 8s (5%/s) | 90,000g |

- F: "A beginner's simmer. The mending comes when it comes."
- E: "An apprentice's patience in a bottle. Sip, breathe, repeat."
- D: "The campfire standard on the Emberward road — poured after the fight, finished before the next."
- C: "Kesh's own teaching recipe. Steady hands brew it; steady drinkers earn it."
- B: "A master's infusion. The flesh remembers how it was before the blight taught it otherwise."
- A: "Wounds close like evening flowers. A master signs perhaps ten a year, and the Sable Court bids on all of them."
- S: "Mórwyn's rot refuses every ending. The Everbloom is the answer some nameless alchemist grew to refuse hers. Theory holds it could be synthesized into something greater."

### Black-market lane — sting: cheap stitching (healing received reduced after)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Gutter Rust | restore 8% of missing HP TOTAL, over 4s | healing received −15% for 8s after | 100g |
| E | Beggar's Rust | restore 11% of missing HP TOTAL, over 5s | healing received −15% for 8s after | 275g |
| D | Smuggler's Rust | restore 14% of missing HP TOTAL, over 5s | healing received −20% for 8s after | 850g |
| C | Cheapstitch Rust | restore 17% of missing HP TOTAL, over 6s | healing received −20% for 8s after | 2,700g |
| B | Scarseal Rust | restore 22% of missing HP TOTAL, over 6s | healing received −25% for 8s after | 9,800g |
| A | Deadflesh Rust | restore 28% of missing HP TOTAL, over 7s | healing received −25% for 8s after | 37,000g |

- F: "Old red gone brown. It mends the way rust holds a hinge."
- E: "Alms-brew from the Rot-Chapel's shadow. The scar it leaves takes no second medicine."
- D: "Rode the Emberward road under a forged wax seal. Heals slow, seals hard."
- C: "Stitches you with wire. Nothing else gets through the seam for a while."
- B: "Closes a wound the way the Choir closes a door: nothing in, nothing out."
- A: "The flesh it grows back isn't quite yours. It refuses second opinions."

## 4. MANA, instant — the Potion (the blue you slam)

Instant, % of MISSING mana. The emergency cast enabler.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Mana Potion | restore 11% of missing mana, instantly | 250g |
| E | Apprentice's Mana Potion | restore 16% of missing mana, instantly | 700g |
| D | Journeyman's Mana Potion | restore 21% of missing mana, instantly | 2,200g |
| C | Accordmark Mana Potion | restore 26% of missing mana, instantly | 7,000g |
| B | Master's Mana Potion | restore 33% of missing mana, instantly | 25,000g |
| A | Masterwork Mana Potion | restore 42% of missing mana, instantly | 95,000g |
| S | Stormglass | restore 55% of missing mana, instantly | 150,000g |

- F: "A beginner's blue. The spark arrives; the shine does not."
- E: "An apprentice's flash-brew. Gone before the taste is."
- D: "A journeyman's answer to an empty hand. The Wayfinders buy them by the crate."
- C: "Accord-stamped and quick — the duelist's blue."
- B: "A master's charge in a bottle. The air itches around it, the way it once did around the Guard's storm-line."
- A: "Bottled lightning that agreed to wait. Masters sign few; the Archive counts fewer."
- S: "Glass-light struck from the storms that unmade the Stormwarden line, taken neat. Its maker is unknown; modern alchemists theorize it can be synthesized into something greater."

### Black-market lane — sting: the burn is paid in blood (max-HP true damage, set HEFTIER v7)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Vein-Burn Blue | restore 11% of missing mana, instantly | 4% max HP true damage | 165g |
| E | Backalley Blue | restore 16% of missing mana, instantly | 5% max HP true damage | 455g |
| D | Smuggler's Blue | restore 21% of missing mana, instantly | 6% max HP true damage | 1,450g |
| C | Furnace Blue | restore 26% of missing mana, instantly | 8% max HP true damage | 4,600g |
| B | Stormsick Blue | restore 33% of missing mana, instantly | 10% max HP true damage | 16,500g |
| A | Heartscorch Blue | restore 42% of missing mana, instantly | 12% max HP true damage | 62,000g |

- F: "It burns going down. That's the blightwater, and that's the point."
- E: "Brewed in a Sable Court bathhouse by someone who almost finished their Accord papers."
- D: "No stamp, no ledger, no waiting."
- C: "Lights the veins like Petra's forge. Casters swear by it. And at it."
- B: "The storm arrives all at once. So does the bill."
- A: "The full charge, paid from the chest. The Cinderborn call that honest arithmetic."

## 5. MANA, over-time — the Tonic (the blue tide)

% of MISSING mana over a window — bigger totals than the Potion at the same price (mana isn't survival). Duration grows with grade (owner's shape rule); the per-second rate still climbs every step.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Mana Tonic | restore 15% of missing mana TOTAL, over 4s (~3.8%/s) | 250g |
| E | Apprentice's Mana Tonic | restore 22% of missing mana TOTAL, over 5s (~4.4%/s) | 700g |
| D | Journeyman's Mana Tonic | restore 30% of missing mana TOTAL, over 5s (6%/s) | 2,200g |
| C | Accordmark Mana Tonic | restore 37% of missing mana TOTAL, over 6s (~6.2%/s) | 7,000g |
| B | Master's Mana Tonic | restore 47% of missing mana TOTAL, over 6s (~7.8%/s) | 25,000g |
| A | Masterwork Mana Tonic | restore 60% of missing mana TOTAL, over 7s (~8.6%/s) | 95,000g |
| S | Starwater | restore 75% of missing mana TOTAL, over 8s (~9.4%/s) | 150,000g |

- F: "A first-year's simmer, thin as rain. The mana returns; the confidence doesn't."
- E: "An apprentice's tide-brew, measured twice against Kesh's ruler. Mild, honest, slow."
- D: "Steady work by a journeyman's hand. The blue runs clear as the Vale's wells before the blight."
- C: "The working mage's flask, Accord-stamped. Half the Grand Archive runs on it."
- B: "A master's slow-brew. The mana returns like a tide answering a patient moon."
- A: "Alive with light. A master makes perhaps a dozen in a career; the Wayfinders hold standing orders for ten."
- S: "Water that remembers a sky before the first fall — or so its unknown maker claimed. Kesh keeps a standing offer for a sealed vial. Synthesis, she says. Something greater."

### Black-market lane — sting: the dream dulls the blade (damage dealt reduced while it runs)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Gutter Haze | restore 15% of missing mana TOTAL, over 4s | your damage −8% while it runs | 165g |
| E | Poppyfield Haze | restore 22% of missing mana TOTAL, over 5s | your damage −8% while it runs | 455g |
| D | Backalley Haze | restore 30% of missing mana TOTAL, over 5s | your damage −10% while it runs | 1,450g |
| C | Syrup Haze | restore 37% of missing mana TOTAL, over 6s | your damage −10% while it runs | 4,600g |
| B | Lotus Haze | restore 47% of missing mana TOTAL, over 6s | your damage −12% while it runs | 16,500g |
| A | Dreamer's Haze | restore 60% of missing mana TOTAL, over 7s | your damage −12% while it runs | 62,000g |

- F: "The blue comes back on a slow smoke. So do you."
- E: "Smells like a meadow you shouldn't sleep in."
- D: "The tide rolls in; the sword arm rolls over."
- C: "Thick as syrup, twice as sweet, half as sharp."
- B: "The Rot-Chapel burns something like this and calls it worship."
- A: "One swallow and the stars talk back. Your blade stops listening."

## 6. MIGHT — the fury

Timed +damage window, both lanes. Laced sting (owner-approved): you hit harder and get hit harder. Buff windows cap at 6s; Deathwish Fury's 8s is the single marked exception — its bargain, paid at the owner-set +15% sting.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Elixir of Might | +4% damage, 4s | 380g |
| E | Apprentice's Elixir of Might | +6% damage, 4s | 1,100g |
| D | Journeyman's Elixir of Might | +8% damage, 5s | 3,400g |
| C | Accordmark Elixir of Might | +12% damage, 5s | 11,000g |
| B | Master's Elixir of Might | +16% damage, 6s | 38,000g |
| A | Masterwork Elixir of Might | +20% damage, 6s | 140,000g |
| S | Giantsblood | +30% damage, 6s | 220,000g |

- F: "Mostly pepper and spirits. The surge is real, if brief."
- E: "An apprentice's war-brew. It warms the arms and little else."
- D: "Standard issue when the Ember Guard still held a line worth breaking."
- C: "The Fangmoot's fighting tonic, measured to the drop and taxed to the coin."
- B: "A master's blend that turns fear into forward motion. The Concord's shield-walls drank it by the barrel."
- A: "Strength a master will sign for. Nothing borrowed, nothing owed."
- S: "The Concord's wars buried things bigger than men, and somebody bottled one. Never brewed by human hands, the theory goes — and it could seed something greater."

### Black-market lane — sting: fury on credit (+damage taken while it holds)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Pit Fury | +4% damage, 4s | +8% damage taken | 250g |
| E | Dogfight Fury | +6% damage, 4s | +8% damage taken | 720g |
| D | Cutthroat Fury | +8% damage, 5s | +10% damage taken | 2,200g |
| C | Warpit Fury | +12% damage, 5s | +10% damage taken | 7,200g |
| B | Blooddebt Fury | +16% damage, 6s | +12% damage taken | 24,500g |
| A | Deathwish Fury | +20% damage, **8s** | **+15% damage taken** | 91,000g |

- F: "Brewed for the dogs that fight under Fangmoot Circle. Works fine on people."
- E: "Everything hits harder. Yes, everything."
- D: "Favored by men who don't plan on being hit back."
- C: "The pit-fighter's arithmetic: they die first."
- B: "Fury on credit. The Sable Court's collectors are punctual."
- A: "Two extra seconds of glory. The body keeps the ledger."

## 7. WARDING — the hide

Timed −incoming-damage window, both lanes; quaff before the telegraphed blow. Gentle ramp (owner, v6): potency tops at −25%, duration at 6s — the S bottle eats one combo, it does not tank the fight.

**Ride-along bug fix regardless of this proposal's fate:** Warding currently bypasses `_drink_gate` entirely (player_core.gd:2021 — no budget spend, no drink cd armed; chain-chugging = permanent 25% DR on a gold faucet). It joins `ROTATION_POTIONS` and the gate like everything else.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| F | Defective Elixir of Warding | −8% incoming damage, 4s | 330g |
| E | Apprentice's Elixir of Warding | −10% incoming damage, 4s | 950g |
| D | Journeyman's Elixir of Warding | −12% incoming damage, 5s | 3,000g |
| C | Accordmark Elixir of Warding | −15% incoming damage, 5s | 9,500g |
| B | Master's Elixir of Warding | −18% incoming damage, 5s | 34,000g |
| A | Masterwork Elixir of Warding | −21% incoming damage, 6s | 125,000g |
| S | Adamant | −25% incoming damage, 6s | 200,000g |

- F: "The skin prickles, and some blows land softer. Some."
- E: "An apprentice's warding draught. Better than a held breath."
- D: "Reliable proofing for the caravans that still run the Emberward road."
- C: "The shield-in-a-bottle the Accord sells to people who can't afford shields."
- B: "A master's proofing, steel-gray and bitter. The seal-keepers drank it before every descent."
- A: "The Accord's best answer to a falling mountain."
- S: "Openly coveted, never counterfeited. Theory holds it is one half of a greater synthesis — the half the seal-makers kept."

### Black-market lane — sting: heavy proofing (move speed reduced while it holds)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| F | Gutterhide | −8% incoming damage, 4s | −15% move speed | 215g |
| E | Mule's Hide | −10% incoming damage, 4s | −15% move speed | 620g |
| D | Ironmonger's Hide | −12% incoming damage, 5s | −20% move speed | 1,950g |
| C | Bricklayer's Hide | −15% incoming damage, 5s | −20% move speed | 6,200g |
| B | Millstone Hide | −18% incoming damage, 5s | −25% move speed | 22,000g |
| A | Gravestone Hide | −21% incoming damage, 6s | −25% move speed | 81,000g |

- F: "Thick as old boots and about as nimble."
- E: "You'll take the hit fine. Catching the next one is your problem."
- D: "Skin like shop shutters. Moves like them too."
- C: "Set yourself like Crownfall masonry and let them chip."
- B: "Grinds every blow to flour. Grinds you slow to match."
- A: "Stand still long enough and the sexton starts his arithmetic."

## 8. RENEWAL — the premium burst (C→S)

Instant, % of MAX hp. The clean lane's identity is the pure spike; the laced lane is the loan — the owner-liked bleed-back sting, consistent across the ladder: the miracle now, some of it collected back.

### Accord lane
| Grade | Name | Effect | Price |
|---|---|---|---|
| C | Accordmark Draught of Renewal | restore 18% of max HP, instantly | 14,000g |
| B | Master's Draught of Renewal | restore 25% of max HP, instantly | 50,000g |
| A | Masterwork Draught of Renewal | restore 33% of max HP, instantly | 190,000g |
| S | Dawnmend | restore 45% of max HP, instantly | 300,000g |

- C: "The Accord's costliest license — life itself, decanted."
- B: "A master's life-work in a flask. Drink it at death's door."
- A: "Priced like a Crown Plaza address, because it has rebuilt more than one bloodline."
- S: "Legend says its maker mended a dying Crown-bearer at the first fall — and vanished before the thanks. Alchemists theorize it could be synthesized into something greater still."

### Black-market lane — sting: the loan (bleed a slice of max HP back over 10s)
| Grade | Name | Effect | Sting | Price |
|---|---|---|---|---|
| C | Graverobber's Mercy | restore 18% of max HP, instantly | bleed 6% max HP back over 10s | 9,100g |
| B | Sawbones' Miracle | restore 25% of max HP, instantly | bleed 8% max HP back over 10s | 32,500g |
| A | Deathbed Bargain | restore 33% of max HP, instantly | bleed 10% max HP back over 10s | 123,000g |

- C: "Half a resurrection at a quarter the price. The other half comes due."
- B: "A Sable Court miracle, stitched in a cellar. The thread pulls itself back out."
- A: "You walked away from that one. Mórwyn's ledger doesn't lose entries — it follows, and it collects."

## 9. The Black Market (where the laced lane lives)

- Accord lane: every regular merchant, every act — no gates (owner ruling); shelf breadth varies by merchant personality/markup as today.
- Laced lane: sold ONLY by black-market vendors. Proposal: a **fence in the Sable Court's shadow-market** (the Cinderborn ward already reads like the place Crownfall doesn't ledger) + an **occasional road smuggler** spawn on route maps — cheap bottles far from town, exactly when you're desperate.
- The lane's open secret (lore, §0): the discount is blightwater. Every sting is the rot doing what the rot does — the fence will tell you it's fine, and the fence is lying by less than you'd hope.
- Drops/renown caches: clean lane only (the world's loot isn't cut with gutter water). Laced is a *purchase decision* — you chose the discount.
- S tier: Accord lane only, full price, plus rare boss/renown drop. No counterfeit exists.
- Held in reserve: a mana bleed-back sting (gain the blue, some drains away) is owner-approved palette but currently unassigned — available if a third mana variant ever ships.

## 10. Wiring notes (build-time)

- Makers take (family, shape, grade, lane); prices and effects move to per-family curve tables in `balance.gd` (knob rule) — no bare numbers. Duration is a per-grade knob on the over-time ladders.
- Sting hooks in player_core, small timed self-debuff vars alongside the existing elixir pair: damage-taken-up, self-move-slow, damage-dealt-down, healing-received-down, bleed-back DoT, true-damage self-hit. All map to existing damage/heal paths. Over-time shapes tick on current-missing per second (self-damping).
- Health potions stop being a special counter → graded bag units (`potions_free` → F-grade Potion units, spent first, same expiring precedent). HUD/touch HUD shows active bottle + grade frame. No save-migration work (standing rule) — unknown old ids drop on load.
- Icons: one per family+shape per lane (laced gets the grimier bottle), grade via frame color; art.gd keys per id.
- Codex: consumable reference gains all lanes (codex staleness rule); the Sable Court fence joins the roster docs.
- Tests: autotest consumable sections re-anchored to graded ids; sting debuffs and over-time drips get wall-clock waits; econ_audit re-run after pricing.

## 11. Open taste calls

1. **Top-end sanity vs late-act income**: F (250g) is anchored to measured ch1/ch2 income; the 90k–300k S band is a statement of intent with no Act 2/3 economy to check it against yet. Re-run econ_audit when Act 2 gold exists and re-fit D→A so the mid-grades track actual wealth bands.
2. **Exact-bottle loadout slots** (my rec — plan the specific entry) vs slot-the-family, drink-cheapest-first.
3. **Names/flavor red-pen** — the eight S uniques (Heartsblood / Everbloom / Stormglass / Starwater / Giantsblood / Adamant / Dawnmend), the "Accordmark" C-tier prefix (renamed from Guildmark in v9), and the street lanes' voice.
4. **Black-market placement** — the Sable Court fence + road smuggler, or somewhere else?
