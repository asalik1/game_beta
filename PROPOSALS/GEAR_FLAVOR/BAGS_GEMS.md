# Gear Flavor — Bags & Gems (PROPOSAL)

Status: DRAFT v2 (2026-07-30). Content-writing only; nothing installed, no code touched.
Companion to the six per-class gear docs under this folder and to `BRIEF.md` (read that first).
Voice matches `PROPOSALS/MATERIALS.md` and `PROPOSALS/CONSUMABLE_GRADES.md`.

Keys are the EXACT strings the in-game display looks up:
- Bags → `Items.BAG_NAMES[grade]` (one line per grade, F→S).
- Gems → the display name in `Items.GEM_STATS[stat]["name"]` **plus a level band** (`Lv1-3` / `Lv4-6` /
  `Lv7-9` / `Lv10`). A gem runs Level 1–10 (`Items.GEM_MAX_LEVEL`); the display resolves the gem's
  current level to its band and shows that band's line, so the stone visibly "grows" as it is upgraded.
  Each gem type therefore has four lines — the same stone at four stages (rough → cut → fine →
  perfected), never four unrelated stones.

Ascending register for bags: F reads as scavenged junk, S as a legendary artifact. Gems: the nine
regular stones read as plain cut minerals that sharpen with level; the five **special** gems (Sunstone/
Sapphire/Opal/Tenacity/Vampire Eye — `Balance.SPECIAL_GEM_STATS`, and they only start dropping in Act 2)
hold a rarer, deeper register across all four bands, since a socket takes at most one of them.

## Bags

| Name (key) | Grade | Flavor |
|---|---|---|
| Frayed Pouch | F | A greasy drawstring bag gone soft with handling; whatever it first carried, the owner didn't live long enough to miss it. |
| Patched Satchel | E | More thread than leather now, mended by a dozen hands that each swore theirs would be the last patch. |
| Soldier's Knapsack | D | Standard column kit, sized for a week's rations and a spare edge; roomy, honest, and long out of issue since the Guard that carried it fell. |
| Knight's Rucksack | C | Oiled canvas on iron buckles, cut for a rider who expected to be a long way from any friendly wall for a long while. |
| Runed Haversack | B | Accord canvas stitched with a stay-shut ward, so the seam holds through a fall that would have spilled an ordinary bag down a ravine. |
| Dragonhide Duffel | A | Scaled hide that shrugs off ember and edge alike — a drake died badly so this one seam would never wear through. |
| Emberforged Hold | S | Bound in metal that fell burning the night the first Crown shattered; what you set inside it does not rot, does not cool, and does not leave until you reach for it. |

## Gems

Each gem is keyed by its display name + level band. Four lines per gem: Lv1-3 (rough / uncut chip),
Lv4-6 (cut / working stone), Lv7-9 (fine / near-flawless), Lv10 (perfected — the gem at its peak).

### Regular gems

#### Ruby — ATK (flat)
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough red chip, barely faceted, but it already lends a blade a little more of the same blunt directness — no cleverness, just more hit. |
| Lv4-6 | Cut clean now and darkened to arterial red, it rides an edge that finds meat with less apology. |
| Lv7-9 | Nearly flawless, and the weapon it sits in seems to swing of its own accord toward the killing weight. |
| Lv10 | A perfected drop of held blood that never dims — the plainest promise a stone can make, kept to the letter: your blow simply lands harder than the world expects. |

#### Garnet — HP%
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A dull garnet pebble, common as gravel in the Vale; still, armour set with even this rough chip holds together a breath longer than it ought. |
| Lv4-6 | Faceted and darkened to old-wine red, it lends the wearer the same stubbornness it shows — hard to chip, harder to break. |
| Lv7-9 | A deep, near-flawless stone that soaks up harm and keeps standing, the way the old levies were drilled to. |
| Lv10 | Perfected and heavy as a shield-boss, it teaches flesh the trick metal already knows: to take the blow and simply remain. |

#### Topaz — Crit
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough yellow chip with one accidental facet; hold it to the light and the eye begins noticing where things are thinnest. |
| Lv4-6 | Cut to a proper point now, it teaches the hand to arrive exactly where the flaw is. |
| Lv7-9 | Faceted to a single near-flawless edge of light, it finds the seam in anything and guides the strike straight into it. |
| Lv10 | Perfected to one unclouded point that never wavers — it does not help you aim so much as refuse to let you miss the weak place. |

#### Onyx — PhysRes
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough black nub, dense in the hand out of all proportion to its size, and it meets a knock the way stone meets rain. |
| Lv4-6 | Polished to a working sheen, it takes a blow the way an anvil takes a hammer — by declining to notice. |
| Lv7-9 | Black and near-flawless, so heavy the plate around it seems to thicken, and edges skate off where they used to bite. |
| Lv10 | Perfected to a mirror-dark boss of a stone; a full swing lands against it, spends itself, and the wearer walks on. |

#### Lapis — MagRes
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough blue lump, the sort priests once crushed into ward-paint; even uncut it makes a spell hesitate at the skin. |
| Lv4-6 | Cut and burnished, it turns a hostile working aside the way a good ward-wall does — quietly, before you feel the heat. |
| Lv7-9 | Deep near-flawless blue, and magic breaks across it like surf on a sea-wall, spent before it reaches the one behind. |
| Lv10 | Perfected to the blue the Concord's oldest seals were painted in; a curse arriving at the wearer finds the door already shut. |

#### Bloodstone — PhysPen
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough green chip freckled with rust-red; even this crude, it nudges a strike toward the joint instead of the plate. |
| Lv4-6 | Cut so the red flecks show like drops, it whets a blow to find the seam the smith swore he'd closed. |
| Lv7-9 | Near-flawless, and armour becomes a suggestion — the strike it guides slips through where the fittings meet. |
| Lv10 | Perfected, the red flecks bright as fresh blood; there is no gap it cannot find, because it treats every gap as already open. |

#### Amethyst — MagPen
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough violet chip that hums faintly against a warded thing, worrying at the weave like a loose thread. |
| Lv4-6 | Cut and clear, it hums until the ward slackens, then lets your magic follow into the give. |
| Lv7-9 | Near-flawless and colder than it looks; wards unravel where it points, and your spell walks through the unravelling. |
| Lv10 | Perfected to a deep unclouded violet — no weave holds against it, because it does not break the ward so much as convince it to open. |

#### Jade — EVA
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough green pebble, cool and slick and hard to keep hold of; the wearer picks up a little of the same slipperiness. |
| Lv4-6 | Polished smooth as a river-stone, it lends the body the trick of not quite being where the blow arrives. |
| Lv7-9 | Near-flawless and cold to the touch, and strikes meant for the wearer keep closing on empty air. |
| Lv10 | Perfected to a flawless green the eye slides off; a blow aimed true still somehow finds nothing there to hit. |

#### Amber — DEX
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough lump of old sap-stone with a gnat caught somewhere inside; the wearer's hands quicken, just short of noticing. |
| Lv4-6 | Polished until the trapped fly shows mid-wingbeat, and the reflexes it lends run just as fast, just as sudden. |
| Lv7-9 | Near-flawless golden amber, warm to hold, and the body it rides answers faster than thought quite allows. |
| Lv10 | Perfected — the ancient insect inside forever a heartbeat from flight, and the wearer forever that quick, that hard to catch. |

### Special gems (one per socket; Act 2 onward)

#### Sunstone — Damage
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough shard that holds a coal's worth of warmth against the palm; the Accord's cutters won't shape one under cloud, and already every wound the bearer deals runs a shade hotter. |
| Lv4-6 | Faceted on a clear morning as the guild demands, it glows from within, and harm dealt through it carries a heat that lingers in the wound. |
| Lv7-9 | Near-flawless, a splinter of trapped noon; the master who cuts one keeps the shutters open, and everything the bearer strikes burns a little on the way down. |
| Lv10 | Perfected to a captured sunrise that never sets — the Accord swears only a handful were ever finished true, and each makes its bearer's every blow a small act of the burning that took the Crown. |

#### Sapphire — Haste
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough blue chip the old lapidaries claimed catches a sliver of the very hour it was broken from the seam; even crude, it shaves a hair off the wait between blows. |
| Lv4-6 | Cut clean, and the pause the wearer used to spend recovering seems to belong to someone slower. |
| Lv7-9 | Near-flawless, and time grows generous around it — cooldowns close before the hand has finished the last motion. |
| Lv10 | Perfected, and the cutters' old story reads as plain truth: the stone has kept a whole stolen hour, and it spends that hour on you, one narrowed heartbeat at a time. |

#### Opal — Combo
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough opal with a single flicker buried in the milk of it; those who fight in chains say it helps one motion remember the next. |
| Lv4-6 | Cut and polished, and now a dozen fires shift across it — a stone for those who cannot afford to let a rhythm break. |
| Lv7-9 | Near-flawless, alive with colour that never repeats, and the bearer's blows fall into a cadence of their own accord. |
| Lv10 | Perfected, no two glances catching the same fire twice; the wearer stops stringing blows together and simply becomes the string, one unbroken motion end to end. |

#### Tenacity — Tenacity (damage reduction)
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough grey fleck the earth never grew — pressure made it, and even crude it passes a little of that hard-won refusal to break along to the wearer. |
| Lv4-6 | Cut from stone that survived being crushed and came out denser, it dulls the weight of every blow that lands. |
| Lv7-9 | Near-flawless and heavy beyond reason, it teaches the body its own history: to be pressed by the whole falling world and hold anyway. |
| Lv10 | Perfected, a fleck of the deep that outlasted the mountain above it; the blight breaks the Vale around the wearer and finds them, blow after blow, simply still standing. |

#### Vampire Eye — Lifesteal
| Band (key) | Flavor |
|---|---|
| Lv1-3 | A rough blood-dark chip the Hollow Choir's alchemists favour, still warm when it leaves the skin; gear set with it sips a little of what it spills. |
| Lv4-6 | Cut into a smooth dark cabochon, it drinks back a fuller measure of every wound the bearer opens. |
| Lv7-9 | Near-flawless and warm as a living thing, it turns spilled blood into the wearer's own, wound feeding hand. |
| Lv10 | Perfected, dark as a closed eye and never once cold; the Choir cut only the finest of these, and it repays every drop the bearer draws with a swallow of the same. |
