# Emberfall — Boss Bible: Early Game to Level 40

Design companion to DESIGN.md. Covers every boss from the end of Chapter 2
(~L16, Warden Null) to the end of early game — and early game IS Act 1:
**Act 1 = L1–40, Act 2 = mid game ~40–70, Act 3 = endgame ~70–100**
(level cap 100, one act per third). Everything in this doc is Act 1;
Cyrraeth at L41 is the ACT 1 finale. Stats are FIRST-PASS anchors on the
existing growth curve — retune each chapter against the XP budget rule
(DESIGN.md round 5) when the chapter is actually built.

> DECIDED 2026-07-04: acts = level thirds, ~7 chapters per act, and the
> authored-campaign budget raised 15–20h → 25–35h. DESIGN.md updated.
> The point is content that matches the design — baseline first, even
> if it takes time.

## Shipped bosses (the vocabulary we build on)

| Boss | Lv | Kit summary |
|---|---|---|
| Fangmaw the Ravener | 5 | telegraphed charge, pounce, 50% pack summon |
| Morwen the Blightcaller | 8 | bolt spreads/rings, blink, blight-rain telegraphs |
| King Vargoth the Hollow | 12 | shockwave rings, blade storm, 30% enrage |
| Korrag, Stormwarden Broken | 8 | lightning lash line, pack calls 66/33%, storm-break enrage |
| The Choir Mother | 10 | requiem rings, verse volleys, hymn self-heal, 60% adds |
| Warden Null, the Last Sentinel | 16 | piston grid, beam spoke, 50% armor shed, 25% overdrive |

Existing engine verbs: `game.telegraph` circles (color/sword variants),
hostile bolts (spreads/rings/lines), summon adds (0 xp/gold, force_aggro),
HP%-threshold phases (enrage / armor shed / pack calls), blink, charge,
pounce tween, small self-heal, terrain events (magma_rain, grave_spawn,
gust, lightning, shard) and hazard patches (lava, ice, poison, heal, slow).

## The arc: the Waking, heard before it is seen

Canon spine (DESIGN.md): the Concord of Ash bound FIVE god-kings into
mortal vessels; Mórwyn the Hollow Flame is waking and cracking the other
four seals. The map opens as the Waking spreads — across Act 1's back
half, chapter by chapter.

**Canon (decided 2026-07-04, mirrored in DESIGN.md):** the other four
god-kings, each mapped to a terrain family so each of Act 1's later
chapters is one seal straining. They are known ONLY by epithet — 600
years of the Concord meant 600 years of not saying their names; Mórwyn's
is known precisely because her seal broke first. Learning a true name
is an Act 2/3 reveal beat (natural quest shape, one per god-king):

| God-king | Domain | Terrain family | Heard through |
|---|---|---|---|
| Mórwyn, the Hollow Flame | blight/decay-as-truth | everywhere (the blight itself) | Hollow Choir (already shipped) |
| **The Molten Judge** | fire, verdicts, the forge | magma / Scorched Wastes | Cinderborn foundries |
| **The Still Queen** | ice, sleep, preservation | ice / Frozen Expanse | the Long Sleep cult |
| **The Pale Root** | growth without death | bog + spore | the blight's GREEN twin |
| **The Storm Tongue** | storm, the unkept word | storm + void | Korrag's old order (retroactive: the storm that "broke" him in Ch2 was this seal straining — Ch2 foreshadowed the back half of the act for free) |

Act 1 bosses are **heralds and casualties** of the seals — the god-kings
themselves stay off-screen for Acts 2–3 (mid game: their vessels and
armies; endgame: the Hollow Throne). Early-game bosses never outrank a
god-king; they're the ripples. Act 1's shape: shard awakens (Ch1–2) →
factions sharpen their pitches over the fallout (Ch3–4) → the Waking
becomes undeniable, seal by seal (Ch5–7) → the first seal CRACKS and
mid game begins.

> Morwen/Mórwyn canon (DECIDED 2026-07-04): TWO entities, linked.
> Morwen the Blightcaller (Ch1 boss, corrupted Guard battle-healer) was
> the Hollow Flame's chosen VESSEL-CANDIDATE — she heard Mórwyn first
> and took her goddess's name, as Choir tradition does. Killing her in
> Ch1 is WHY the god-king was forced into an unprepared blacksmith.
> One Aldric line sells it; Ch2's veneration of Morwen deepens
> retroactively; the near-identical spelling becomes the point
> (cultists take the name). The blacksmith is, uncomfortably, the
> player's fault — Act 2 gets to say so.

## Chapter / level map

All Act 1. Ch7 is the act finale; L40 closes early game.

| Ch | Working title | Terrain | Levels | Bosses |
|---|---|---|---|---|
| 3 | The Unburied Vale | graveyard (mono) | 16→22 | Sexton 17 · Widow 19 · **Saint Varo 22** |
| 4 | The Slagfields | magma (mono) | 22→28 | Forgemistress 23 · Cinderhide 25 · **Ashpriest Ordo 28** |
| 5 | The Long Sleep | ice (mono) | 28→33 | Whitepelt 29 · Serane 31 · **Mother Halla 33** |
| 6 | The Blooming Deep | bog + spore (first blend) | 33→37 | Auroch 34 · Rotmaw 35 · **Kaethra 37** |
| 7 | The Breaking Sky | storm + void (blend) | 37→41 | Veyx 38 · Echo 39 · **Cyrraeth 41** (ACT 1 FINALE) |

Mono-family-not-mono-look rule applies (graveyard chapter drifts misty
fields → barrows → crypt stone → boss cathedral, per DESIGN.md).

---

# Chapter 3 — The Unburied Vale (graveyard, L16–22)

The Hollow Choir's heartland after the Choir Mother's death: a funeral
that never ends, because the Choir does not bury its dead. The factions
(joinable since Ch2) sharpen their pitches over the Vale's ashes — the
mid-act pivot where alignment starts to matter.

### The Sexton — L17 · mid boss · melee brute
**Lore:** He dug graves for the Choir before he understood they'd never
be filled. Now he digs for the enemy — every hole in the Vale is his,
and every hole has something in it.
**Codex line:** *"Every grave he ever dug stands open. He remembers who
he meant each one for."*
**Kit (WoW ref: Unholy corpse mechanics / Rotface add flow):**
- **Shovelwork** (signature): burrows — untargetable ~1.5s — then a line
  of eruption telegraphs tears toward the player, surfacing under them.
- **The Vale answers:** amplified `grave_spawn` — shamblers claw up near
  the player on a steady timer, all fight (not HP-gated: the pressure IS
  the fight). Zero xp/gold as usual.
- **Corpse bloom (the mechanic that teaches positioning):** any add that
  dies within ~180px of another corpse detonates both (telegraphed).
  Kill shamblers SPREAD OUT or the floor chains. Boss deliberately walks
  toward corpse clusters to force it.
- No enrage; his threat is arithmetic — ignore adds and drown.
**Engine needs:** burrow/untargetable state (new, reused later by the
Auroch), corpse-position tracking (positions of recent add deaths).

### Vess the Unburied, First Widow — L19 · mid boss · ranged magic
**Lore:** The first person the Choir ever refused to bury — she asked
them to, over her husband's body, and they sang no. She has been
screaming so long the scream became the liturgy.
**Codex line:** *"The Choir's first hymn was a widow told 'no.' She is
still singing her half of it."*
**Kit (WoW ref: banshee wail / Deathwhisper; the SAFE-SPOT debut):**
- **The Silence** (signature): she inhales (2s wind-up, arena-wide
  visual), then the WHOLE arena takes heavy damage EXCEPT one marked
  quiet circle (inverse telegraph). Stand in the silence when the wail
  lands — the user-requested "right spot at the right time" mechanic,
  introduced at its gentlest here.
- **Grief cones:** 3-bolt fans that echo — each fan repeats once, 0.8s
  later, from where she cast it (dodge the memory, not just the cast).
- **Blink** away from melee (Morwen lineage — she IS the Choir's grief
  for Morwen's era).
- 30% — **Keening:** two quiet circles spawn per Silence but one is a
  LIE (flickers, then fills with damage). The real one is steady.
**Engine needs:** inverse telegraph / safe-zone (new — reused by Serane,
Ashpriest, Cyrraeth), delayed echo-cast (trivial: re-fire stored volley).

### Saint Varo the Unrotting — L22 · CHAPTER FINALE · slow holy-horror juggernaut
**Lore:** The Choir venerates decay as the land's one honest truth — and
their greatest saint CANNOT ROT. His flesh refuses. They built the
cathedral around his shame and he has knelt in it for sixty years,
begging the blight to take him. It won't. You're the next best thing.
**Codex line:** *"The Choir's holiest relic is the one thing in Vaelscar
the rot refuses. He prays daily that this is not what it means."*
**Kit (WoW ref: kill-the-adds-to-stop-the-heal, bell = Icecrown Spire tolls):**
- **Censer-bearers:** 3 stationary censer adds ring the arena at pull
  (speed 0, modest HP, zero rewards). While any censer lives, Varo
  channels their incense: **regenerates ~1.5% max HP/s**. Killing all
  three stops the heal — the DPS-priority lesson. At 60% and 30% the
  congregation relights them (respawn, staggered).
- **The Toll** (signature): the cathedral bell rings — arena-wide
  shockwave EXCEPT behind the standing pillars (existing `pillar`
  obstacles become cover; implemented as safe-zones placed on the
  pillar shadows). Each toll CRACKS one pillar; the arena has more
  pillars than he has tolls, barely.
- **Reliquary slam:** Vargoth-lineage shockwave ring + sword-rain
  telegraph set, slow and heavy.
- 25% — **He stands up.** First time in sixty years. Speed +50%, tolls
  come faster, and he weeps the whole time. (Enrage, but make it hurt
  emotionally too — one spawn_text line: "SAINT VARO STANDS.")
**Engine needs:** channel-heal tied to living adds (distance/alive
check), pillar-shadow safe zones (reuses inverse telegraph), destructible
scenery count-down.

---

# Chapter 4 — The Slagfields (magma, L22–28)

The Waking arc opens. The Molten Judge's seal strains under Cinderborn foundries
built directly over it — the empire's heirs are smelting Crown-grade
weapons with heat they don't understand, and the heat is starting to
answer back. Natural Cinderborn recruitment chapter.

### Forgemistress Calda — L23 · mid boss · melee skirmisher
**Lore:** Cinderborn's finest smith, forging blades for the heir-to-come.
She quenches them in living slag because ordinary water started feeling
like an insult. The Judge whispers tolerances no mortal forge can hold.
**Codex line:** *"Her blades never break. Lately, neither do her
mistakes."*
**Kit (WoW ref: Blackrock Foundry quench mechanics):**
- **White-hot:** her weapon heats over ~12s (visual: sprite modulate
  ramps). At full heat her hits burn (existing burn debuff) and her
  telegraphs widen 40%.
- **Quench** (signature): she marches to one of 3 slag pools at the
  arena edge to quench — resetting heat AND gaining a stacking damage
  buff. **You can body-block the pool:** if the player stands on the
  pool when she arrives, she quenches THROUGH you (heavy telegraphed
  hit you must heal through or dodge at the last moment) and gets NO
  buff. Deny the buff or eat the fight's hardest hit — player's choice
  every cycle.
- **Hammer lines:** Korrag-style lash telegraphs, forge-orange.
- No adds; she works alone. Her fight is the heat clock.
**Engine needs:** boss walk-to-point behavior with interception check
(new, reused by Ashpriest's ember adds and Halla's dreamers).

### Cinderhide the Unquenched — L25 · mid boss · armored beast
**Lore:** A slag-beast that crawled out of the deep vents when the
foundries woke the Judge's furnace. Its hide is cooled obsidian a
meter thick. The foundry crews call it unkillable. They're almost right.
**Codex line:** *"The foundry lost four crews learning that steel
doesn't bite it. The fifth crew learned what does."*
**Kit (the environmental-positioning boss — WoW ref: Magmadar + reverse Hodir):**
- Near-immune while plated (FLAT ~82% pen-proof damage wall via `plate_dr`,
  NOT a resist number — the old +60 resist read as only ~41% DR and a DPS
  build could skip the mechanic): the arena's `lava` patches are the
  answer — **standing in lava MELTS its plating** (stacking meter while
  it's in lava; at full melt the wall drops and only the honest base
  resist ~25 / ~17% DR remains, ~10s window). It avoids lava; you LURE
  it (it charges like Fangmaw — bait the charge across a pool). Its own
  vent-breath lava is tagged `no_melt` and never melts it; while plated
  its charge + vent breath come faster/harder (a rampaging tank you
  outlast, not a safe DPS pause).
- **Vent breath:** cone of lava telegraphs.
- **Tantrum** at each plate-shed: magma_rain event burst while
  vulnerable — the damage window isn't free.
- 30% — plates stop regrowing; it enrages, fight becomes a Fangmaw-style
  chase with double magma rain.
**Engine needs:** terrain-patch-contact tracking on a boss (new),
conditional resist swap (Warden Null armor-shed generalized).

### Ashpriest Ordo, Voice of the Molten Judge — L28 · CHAPTER FINALE · ranged herald
**Lore:** First herald of a waking god-king. A Cinderborn chaplain who
listened to the forge-deep too long; now his sermons deliver VERDICTS,
and the Judge's verdicts are always guilty. The Cinderborn leadership
publicly disowns him and privately takes notes.
**Codex line:** *"Every sermon ends the same way. 'Guilty.' The fires
agree."*
**Kit (WoW ref: Ragnaros Sons of Flame + arena-half verdicts):**
- **The Verdict** (signature): the arena splits down the middle
  (visual line); after 2.5s one half is judged — full-half eruption,
  the other half is safe. He announces it ("GUILTY: THE WEST").
  At 50%+below, verdicts come in pairs — dodge two rulings in sequence.
- **Sons of the Judge:** at 66% and 33%, 4 ember adds spawn at arena
  edges and MARCH slowly toward him. Each one that reaches him is
  consumed: +8% max-HP heal and permanently faster verdicts. Kill or
  slow them before they arrive (they're slow, low-HP, zero rewards —
  pure intercept pressure).
- **Brand volleys:** Choir-Mother-grade bolt fans between mechanics.
- 20% — **The Judge attends:** magma_rain runs continuously; verdicts
  keep coming. Soft enrage — finish the sermon or be sentenced.
**Engine needs:** half-arena telegraph (rect zone — new shape, reused by
Cyrraeth's quadrants), marching-add consume (reuses Calda's walk-to-point).

---

# Chapter 5 — The Long Sleep (ice, L28–33)

The Still Queen's seal. In the Frozen Expanse, whole villages have gone
to sleep and not died — preserved, dreaming, cold. A cult of the
bereaved carries their sleeping kin TOWARD the deep ice, because the
Queen's whisper promises they'll wake when she does. Wildfang's winter
clans are caught in the middle.

### Hrolgar Whitepelt — L29 · mid boss · pack brute
**Lore:** Wildfang winter-clan chieftain of the "we are what we are"
camp. He's not corrupted and not evil — he's DEFENDING the sleeping
valley because the cult pays his clan in food through a famine winter,
and he doesn't ask what the wagons carry. Killing him should feel like
policy, not triumph — Wildfang standing shifts either way.
**Codex line:** *"He knows exactly what he's guarding. That's the price
of feeding a clan through winter: knowing, and guarding it anyway."*
**Kit (WoW ref: bait-the-charge, Fangmaw matured onto ice physics):**
- **Ice charge** (signature): Fangmaw-lineage charge, but on ice patches
  he CANNOT STOP — overshoots and slams the arena wall (2.5s stun +
  vuln window). Bait his charge across ice, punish the skid. On bare
  ground the charge is safe for him — arena reading is the skill.
- **Pack calls** at 66/33% (Korrag lineage — he IS what Korrag was).
  His wolves also slide on ice; kite fights onto patches.
- **Pelt drums:** shockwave ring when you're too close too long.
- No enrage. When he dies his pack STOPS FIGHTING and drags him away
  (despawn walk — one spawn_text: "The pack does not leave its dead.").
**Engine needs:** charge-slide on ice patches + wall-slam stun (extends
existing charge + patch contact from Cinderhide).

### Serane the Icebound — L31 · mid boss · frozen caster
**Lore:** An Ember Guard mage who volunteered, 600 years ago, to be the
Still Queen's LOCK — frozen alive at the seal's keystone, her own ember
the bolt on the door. The seal straining means SHE is straining. She
fights you because anyone reaching the keystone is, as far as six
centuries of frozen vigilance can tell, here to open it.
**Codex line:** *"She has held one door for six hundred years. She is
not going to take your word for it."*
**Kit (WoW ref: HODIR — Flash Freeze, this is the homage chapter):**
- **Flash Freeze** (signature): 3s wind-up, arena-wide freeze — stand in
  a thawed steam-vent circle (2–3 safe zones marked during wind-up;
  inverse telegraph again, now with multiple spots and a longer arena
  cross). Caught outside = frozen solid (stun ~2.5s) + vulnerability
  while frozen. Survivable at full HP — brutal if she combos it.
- **Shatter lance:** she roots the player (slow-patch burst underfoot),
  then sends a piercing line telegraph at the rooted spot. Move the
  instant the root breaks.
- **Icicle rain:** Morwen-lineage scatter telegraphs, constant.
- 40% — **the keystone cracks:** permanent `ice` patches spread from
  the arena edges inward (shrinking safe footing; the slide is now
  everyone's problem), and Flash Freezes come 30% faster.
**Engine needs:** player root/freeze status (new status effect),
mid-fight patch spawning (reuses fight-owned zones from Ch3 corpse work).
**Lore hook:** killing her weakens the very seal — she TELLS you so as
she dies. The Waking arc's tragedy in one fight: every herald you stop,
you also strip a lock. Feeds directly into the mid-game (Act 2) stakes.

### Mother Halla, Keeper of the Long Sleep — L33 · CHAPTER FINALE · lullaby herald
**Lore:** The cult's shepherd. She lost three children to the famine and
carried them to the ice; the Queen's whisper told her they were the
lucky ones. Now she gathers everyone's grief and walks it north. She is
gentle, absolutely sincere, and the most dangerous thing in the chapter.
**Codex line:** *"She has never raised her voice. Ask the villages she
emptied."*
**Kit (the DON'T-STAND-STILL boss — inversion of every safe-spot fight so far):**
- **Lullaby aura:** standing still (or slow-patched) for >1.5s stacks
  Drowse (move speed down); 5 stacks = Asleep (3s stun) — and **while
  you carry ANY Drowse she regenerates** (visible channel line to you).
  The entire fight punishes standing; after two chapters of learning to
  stand in circles, the finale teaches you to never stop. (WoW ref:
  Sindragosa's chilled-to-the-bone logic inverted.)
- **Dreamers:** sleepwalker adds drift slowly toward HER (walk-to-point
  reuse); each arrival thickens the aura (Drowse stacks faster). They
  never attack. Killing them is free — and feels terrible, because the
  codex is clear they're villagers who might have woken. **The chapter's
  Resonance room right before her arena asks what you'll do about that;
  the fight makes you answer twice.**
- **Frost hymnal:** slow big-radius telegraphs that leave slow patches —
  she paves the arena against you.
- 25% — **the Queen turns over in her sleep:** one Flash Freeze (Serane
  callback, single safe vent) then aura radius grows until kill.
**Engine needs:** stillness detection + stacking debuff (new), channel
visual, everything else reused.

---

# Chapter 6 — The Blooming Deep (bog + spore, L33–37, first blended chapter)

The Pale Root's seal. The blight KILLS things; in the deep bog something
has started making things GROW — wrong, huge, and permanently. The
terrain blend is the story beat (DESIGN.md: corruption merging): Hollow
Choir pilgrims arrive expecting holy rot and find its opposite, and
their crisis of faith is the chapter's social content. Wildfang's
cure-seeker camp is here too, because a force of pure growth looks a
lot like a cure — from a distance.

### The Drowned Auroch — L34 · mid boss · submerging beast
**Lore:** A great bog-bull that drowned a century ago and did not stop
growing. The Root got into it the way rings get into a tree. It is not
angry; it is a WEATHER SYSTEM with horns.
**Codex line:** *"The bog keeps what it drowns. Lately it keeps things
growing."*
**Kit (WoW ref: Ouro/Leviathan submerge cycles):**
- **Submerge cycle** (signature): every ~25s it sinks (untargetable —
  Sexton's burrow tech at scale). While under: pursuing eruption-line
  telegraphs chase the player + 2 bog-spawn adds surface. It resurfaces
  under the player's position (big telegraph) — keep moving or tank it.
- **Gore rush:** surface-phase charge; in bog water it's slowed —
  fight near water when it's up, on land when it's down. Terrain
  reading as the core skill, blended terrain earning its keep.
- **Wallow:** shockwave ring + poison patches splash out.
- No enrage; submerge cycles just shorten as HP drops (soft clock).
**Engine needs:** none new — burrow + walk-to-point + patch spawning all
exist by now. This boss is deliberately CHEAP: the chapter's engine
budget goes to Kaethra.

### Rotmaw the Gardener — L35 · mid boss · zone-control caster
**Lore:** A Choir deacon who came on pilgrimage, saw the Blooming, and
converted on the spot — if rot is the land's truth, growth-without-death
is its LIE, and lies this beautiful must be tended. He gardens now.
The garden is carnivorous.
**Codex line:** *"He still keeps Choir vows. He just tends a different
congregation, and waters it with pilgrims."*
**Kit (the arena-denial boss — WoW ref: creeping-void floor fights):**
- **Blooms:** stationary bulb adds (speed 0, no rewards) sprout on a
  timer; each living bloom SPREADS drifting poison patches around
  itself (existing spore-drift tech). Unchecked, the floor fills — the
  fight is a garden you must keep weeding while he punishes you for it.
- **Vine lash** (signature): root the player (Serane's root reuse) +
  a closing ring of telegraphs — break line to the outside before it
  closes.
- **Compost:** if a bloom is destroyed within 150px of him, he EATS it —
  +4% heal. Weed the far garden first; near-blooms need him kited away
  (Sexton's corpse-positioning lesson, graduated).
- 30% — **full bloom:** all current patches surge one size, blooms
  sprout in pairs. Soft enrage via floor space.
**Engine needs:** none new (bloom = censer + drift patches + Compost =
Corpse-bloom distance check). Second deliberately-cheap boss.

### Kaethra Cure-Twisted — L37 · CHAPTER FINALE · two-form tragedy
**Lore:** Wildfang's best shaman, leader of the cure-seeker camp — the
one Maren hoped would broker the Accord alliance. She found the Pale
Root's power and tested the cure the only ethical way: on herself.
It worked. The beast in her blood is GONE — replaced. Now the Root
wears her the way corruption once wore her ancestors, and both Wildfang
camps agree, for the first time in a generation, that she cannot be
allowed to leave the Deep. The "cure or acceptance" question the whole
faction is built on gets its answer: it was a false choice, and she
paid full price for asking honestly.
**Codex line:** *"She cured the beast. Read that sentence again,
carefully, and ask what's left."*
**Kit (WoW ref: two-form druid bosses / Lady Malande-style form swaps):**
- **Two forms, hard swap at HP thresholds (80/60/40/20%):**
  - **Huntress form** (melee): Whitepelt-lineage — charges, pack drums,
    fast pursuit. NO adds; she is alone in a way that should be felt.
  - **Bloom form** (ranged): rooted in place — literally; visible roots
    (2 destructible root adds). While any root lives she channels:
    **heals ~2%/s** and rains Rotmaw-pattern spore volleys. Kill the
    roots to force her back to Huntress early. (Kill-the-heal, third
    and final evolution of the Varo lesson.)
- Each swap, one line of dialogue — she's lucid the whole fight. The
  fight IS the cutscene. Final line on death differs by your Wildfang
  standing (both camps' epilogues hinge here).
- No enrage. At 10% the Root abandons her and the FIGHT ends (decided
  2026-07-04): she swaps to a final non-attacking form (form-swap tech,
  no new combat machinery) and the existing convo system runs with a
  kill option — **strike or sheathe, binary, diegetic, no timer.** She
  dies either way; the divergence is a flag + Resonance nudge +
  epilogue lines. The one Resonance beat in the game that arrives
  while your hands are still shaking.
**Engine needs:** form-swap (stat/sprite/kit switch — the chapter's one
big engine spend), in-fight dialogue lines (spawn_text or convo hook),
end-of-fight choice via the EXISTING convo system (no mid-combat
branching — the 10% form is just a form that doesn't fight back).

---

# Chapter 7 — The Breaking Sky (storm + void, L37–41, ACT 1 FINALE)

The Storm Tongue's seal — the one Korrag's order was founded to tend,
which is why his storm "broke" back in Ch2 (retroactive continuity, one
codex entry ties it). Over the Thunder Plains the sky has started
tearing at the edges: void showing through the storm. Both joinable
factions converge here for the act's political climax; the chapter ends
with the first seal CRACKING — not open, but cracked — early game ends
here, and the mid-game (Act 2) clock starts.

### Veyx, the Unchained Current — L38 · mid boss · storm elemental
**Lore:** Not a herald — a piece of the Storm Tongue's own voice that
slipped through the strained seal and is now loose, delighted, and
wearing weather like a body. First contact with god-king-grade power,
deliberately at its smallest possible dose.
**Codex line:** *"It isn't angry. It's a syllable of something that
hasn't finished speaking for six hundred years, and it's HAPPY."*
**Kit (WoW ref: THORIM lightning-conductor phases):**
- **Conductor rods:** 4 lightning rods stand in the arena (destructible,
  Varo censer tech). Veyx's **Arc** (signature) chains to the player
  UNLESS a rod is nearer — stand near a rod to feed it the arc. BUT
  each redirected arc charges that rod; at 3 charges it EXPLODES
  (big telegraph). Rotate rods, manage charges — use the mechanic,
  don't camp it. Destroying rods removes the option: player chooses
  fewer-but-safer or more-but-hotter.
- **Static field:** terrain `lightning` event runs all fight, faster
  when no rods remain.
- **Squall:** `gust` shove during arc wind-ups — positioning under
  pressure.
- 30% — rods respawn all at once, arcs come in pairs.
**Engine needs:** nearest-conductor arc targeting + rod charge counter
(new, small), everything else is terrain events.

### The Echo of the Unnamed — L39 · mid boss · shadow duelist
**Lore:** The void bleeding through the seal has a memory in it: the
Guard founder whose name was ERASED — the Assassin ember's betrayer
(DESIGN.md). Erasure, it turns out, is not deletion; the void kept a
copy. It doesn't want the throne. It wants to be REMEMBERED, and it
will settle for being remembered as your death. (Assassin-class players
get bespoke dialogue: it recognizes its own ember. Seeds the class's
endgame shard-bearer questline early.)
**Codex line:** *"The Guard erased one name from every record. The void
returns everything we throw away."*
**Kit (WoW ref: mirror-image duels; the clone-hunt fight):**
- **Unnaming** (signature): vanishes and spawns 3 mirror copies (adds
  with its sprite, 1-HP, zero rewards); all four telegraph the same
  dagger-fan SIMULTANEOUSLY but the real one's telegraph is MIRRORED
  (flipped left-right vs the copies). Read the tell, hit the real one;
  hitting a copy detonates it (small void zone underfoot).
- **Void zones:** every mechanic leaves persistent slow+damage patches
  (fight-owned zones); the arena shrinks all fight — hesitate and the
  clone-hunt happens in a corridor.
- **Blink-strike:** Morwen blink but AGGRESSIVE — teleports ONTO the
  player when they linger in void patches.
- 25% — copies stop dying in one hit (real HP bars, tiny pools), pick
  the real one by the mirror tell alone.
**Engine needs:** mirrored-telegraph flag + clone spawns (small), void
zone lifecycle exists by now.

### Cyrraeth, Mouth of the Storm — L41 · ACT 1 FINALE · three-phase herald
**Lore:** Last Speaker of the order Korrag once guarded beasts for —
the order that kept the Storm Tongue's seal by RECITING it: an unbroken
600-year relay of vow-keepers speaking the binding aloud. Cyrraeth is
the first to stop mid-sentence and LISTEN instead. The god-king has
been dictating through him ever since. Kill him and no one alive knows
the recitation — the seal cracks as he dies. The victory IS the crisis:
the mid game's inciting incident, earned by the player's own hand.
(Serane taught this lesson quietly; Cyrraeth makes it the plot.)
**Codex line:** *"Six hundred years of speakers kept the vow. He is the
first to hear what it was silencing — and agree with it."*
**Kit (three phases, the act's mechanics-exam — WoW ref: council-of-phases finales):**
- **P1 (100–60%) — The Speaker:** Korrag's kit MATURED (deliberate
  echo): lightning-lash lines, whip telegraphs, storm bolts. Any Ch2
  veteran reads it instantly — then it's faster and it feints (every
  second lash re-aims mid-sequence).
- **P2 (60–25%) — The Mouth:** he stops fighting and RECITES; the
  god-king answers. Arena-wide rotating storm: the arena quarters light
  up in sequence and detonate — one QUIET QUADRANT rotates (rect-zone
  tech from Ordo's verdicts, now moving); stay in the eye as it walks
  around the arena. Between rotations: Veyx-style arcs (a rod pair
  remains — old tools, final exam). Sleepwalker-style vow-keeper adds
  (Halla tech) drift toward him; each one that reaches him SPEAKS IN
  HIS PLACE for ten seconds — pausing the rotation (breathing room!)
  before dissolving. The adds HELP you — protect-by-permitting, the
  inversion of every intercept mechanic in the act.
- **P3 (25–0%) — The Word Unfinished:** vessel burning out. Storm
  rotation accelerates, quiet quadrant shrinks to a quiet OCTANT,
  lash feints return, continuous `lightning` event. Soft enrage —
  the sentence is ending whether you finish him or it finishes you.
- On death: no loot fanfare first — the sky CRACKS (screen effect,
  one still beat), THEN rewards. Act 1 — early game — ends on the sound.
**Engine needs:** rotating rect/sector zones (extends Ordo tech),
phase-scripted add behavior; everything else is the act's toolbox.

---

# The shared toolbox (build once, in this order)

New engine primitives, ordered by first use; each amortizes across the
act — no boss needs more than ONE new trick beyond the pool:

| Primitive | Debuts | Reused by |
|---|---|---|
| Inverse telegraph (safe-zone) | Vess (Ch3) | Varo, Serane, Halla, Cyrraeth |
| Burrow/untargetable phase | Sexton (Ch3) | Auroch |
| Corpse/position-proximity triggers | Sexton (Ch3) | Rotmaw's Compost |
| Add-channel heal (censers) | Varo (Ch3) | Kaethra's roots, Veyx's rods |
| Walk-to-point adds + intercept | Calda (Ch4) | Ordo, Halla, Cyrraeth |
| Terrain-patch contact on bosses | Cinderhide (Ch4) | Whitepelt, Auroch |
| Rect/half-arena zones | Ordo (Ch4) | Cyrraeth (rotating) |
| Player root/freeze status | Serane (Ch5) | Rotmaw, Kaethra |
| Stillness detection + stack debuff | Halla (Ch5) | — |
| Fight-owned persistent zones | Serane (Ch5) | Rotmaw, Echo |
| Form swap | Kaethra (Ch6) | (Act 3 will want it badly) |
| Mirrored-telegraph clones | Echo (Ch7) | — |

Mechanic-type coverage vs. the brief: minion spawners (Sexton, Ordo,
Whitepelt, Auroch), self-healers you must interrupt via adds (Varo,
Rotmaw, Kaethra, Halla), stand-in-the-right-spot (Vess, Varo, Serane,
Ordo, Cyrraeth), NEVER-stand-still (Halla), environment-as-weapon
(Cinderhide, Whitepelt, Auroch), intercept (Calda, Ordo), clone-hunt
(Echo), conductor management (Veyx), form-swap tragedy (Kaethra).

> BUILT 2026-07-06: all five chapters (Ch3–Ch7) are authored and
> registered — 21 rooms each (13-room spine + 8 side), per-chapter
> trash kinds, camp briefings, faction pitches, two resonance rooms
> per chapter, per-chapter wanderer pools, and Kaethra's
> strike-or-sheathe wired through the convo system. Boss XP was
> re-anchored during the build (Ch5–7 first-pass values paid 1–2.5
> LEVELS each; now mids ~65–80% / finales ~85% of a level, gold
> untouched) so full clears land at boss level per the DESIGN r5 rule.
> The hp/dmg/speed table below is otherwise still live.

# First-pass stat anchors (ENEMIES schema)

On the shipped curve (Warden Null L16: 2400 hp / 55 dmg, growth
0.14–0.15 hp / 0.13–0.14 dmg, compounding). Finale bosses sit fat,
mid bosses lean. ALL numbers get retuned against the chapter XP budget
(sum authored pack XP through 30+22·lvl; land boss rooms at boss level).

| kind | Lv | hp | dmg | speed | type | notes |
|---|---|---|---|---|---|---|
| sexton | 17 | 2700 | 58 | 120 | phys melee | high VIT |
| widow | 19 | 3300 | 66 | 100 | magic ranged | high INT, eva |
| saint_varo | 22 | 5800 | 88 | 70→105 | phys melee | Null-grade physres |
| forgemistress | 23 | 5900 | 96 | 150 | phys melee | AGI/STR skirmisher |
| cinderhide | 25 | 7600 | 110 | 135 | phys melee | base res 25; plated = flat ~82% pen-proof wall (plate_dr) |
| ashpriest | 28 | 11500 | 150 | 95 | magic ranged | finale |
| whitepelt | 29 | 12000 | 160 | 155 | phys melee | pack boss |
| icebound | 31 | 15000 | 190 | 90 | magic ranged | high magres |
| sleepkeeper | 33 | 21000 | 230 | 85 | magic ranged | finale, aura fight |
| auroch | 34 | 22500 | 250 | 130 | phys melee | submerge windows pad EHP |
| gardener | 35 | 24500 | 270 | 80 | magic ranged | zone fight |
| curetwisted | 37 | 33000 | 330 | 145/85 | phys/magic | per-form stats |
| stormdrake_veyx | 38 | 34500 | 350 | 115 | magic ranged | arcs are the threat |
| unnamed_echo | 39 | 36500 | 375 | 170 | phys melee | low hp, high eva/crit |
| stormmouth | 41 | 54000 | 460 | 105 | magic ranged | act finale |

# Per-boss shipping checklist (from the Ch2 selftest contract)

Each boss needs, or the content-module selftest fails:
- sprite key (Dungeon Crawl probe first, per asset rules)
- `roar_<kind>` voice (OpenGameArt; semantic fit > quality; no human
  grunts, no melodic jingles)
- `music` track key (`boss_<kind>` or a shared per-chapter boss theme —
  RECOMMENDATION: one boss theme per chapter + unique FINALE themes
  only; 15 unique boss tracks is audio-sourcing hell for no payoff)
- `lore` codex blurb (drafted above)
- entry merged into `Story.ALL_ENEMIES` via a `chN_bosses.gd` content
  module + one `Story.CONTENT_MODULES` line
- CONTENT-MODULE TEST HOOK selftest: signature fires, phase trips,
  rogue-kill doesn't touch story state

# Canon decisions (all locked 2026-07-04 — Ch3 authoring is unblocked)

1. **God-king epithets approved** (Molten Judge, Still Queen, Pale
   Root, Storm Tongue) — and the epithet-only rule is itself canon:
   no one alive knows their true names; each name-learning is an
   Act 2/3 reveal quest. Mórwyn is the exception because her seal
   broke first.
2. **Morwen/Mórwyn = two entities**, vessel-candidate link (see the
   arc section note). DESIGN.md's "same character — standardize" note
   superseded.
3. **Acts = level thirds:** Act 1 = L1–40 (Ch1–Ch7), Act 2 ~40–70,
   Act 3 ~70–100; seven chapters per act; authored budget 25–35h.
   DESIGN.md updated.
4. **Kaethra's spare-or-kill is GO**, scoped cheap: the fight ends at
   10%, her final form doesn't fight back, the choice runs through the
   existing convo system. Strike or sheathe, binary, no timer.
