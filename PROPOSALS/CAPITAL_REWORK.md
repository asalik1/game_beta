# Capital Rework — Crownfall as the game's home base (2026-07-25)

Owner brief (overnight, decisions delegated): the capital is redundant — NPCs
overlap with landmark interactions, the shop duplicates the chapter shop, and
25 rooms of flavor bury the ~8 things a player actually does between runs.
Compress it, give it a real economic identity, and make it the place the
campaign *sends* you rather than a dev-panel curiosity.

Genre reference points used for judgment calls: WoW capitals (services live at
NPCs, city = between-session ritual), Diablo town loop (kill → town → vendor /
socket / stash → portal out), and the MT4 postmortem rule (never freeze the
frontier — the capital must never become mandatory *friction*, only mandatory
*ritual*).

## 1. Compression: 25 rooms → 9 (3×3 grid)

```
 Fangmoot Circle    Wayfinder Sanctum    Rot-Chapel
 (Wildfang ward)    (3 mode portals)     (Choir ward)

 The Ashen Tankard  CROWN PLAZA          The Grand Archive
 (tavern + party)   (all core services)  (codex/journal/records)

 Accord Commons     Emberward Gate       The Sable Court
 (Accord ward)      (leave the city)     (Cinderborn ward)
```

- **Crown Plaza** (room_scale 1.0, the only grand room) holds every everyday
  service, ringed around the fountain: Petra's forge (reforge), the Lapidary
  (gems), the vault coffer (stash), the bazaar stall (merchant + wardrobe),
  the alembic (potion loadout), the alms desk (daily), a mail stall, and the
  hearth corner. One room = the Diablo town ritual with zero walking tax.
- Every branch room is exactly one door from the plaza. The four faction wards
  keep their two principals each (Callis+Ottar, Ilse+Vela, Maren+Kesh,
  Aldric+Vessa) and their contracts desk — they are the social-layer hooks and
  stay, but at one room per faction instead of three.
- **Cut**: rampart/causeway/stables/warren/digger/waiting/hospice/menders/
  wellspring/foundry/bastion and their casts. Pure flavor duplication; the
  survivors keep the city's voice (the convos were the best part and remain,
  trimmed to the rooms that earn them).

## 2. Redundancy rule: ONE access point per function

The old capital had "two ways to open the shop" (NPC + landmark). New rule,
enforced by the generator: **a function is owned by exactly one interaction**
— an NPC where a person makes sense (services with favor attribution), a prop
where it doesn't (portals, vault chest, archive desks). Landmarks whose action
duplicated an NPC are now scenery.

- HUD stash icon **removed** — the vault coffer in the plaza is the stash.
  (Stash was already account storage; giving it a street address is the WoW
  bank pattern and makes the capital a *reason*, not a shortcut.)
- Reforge + gem socketing **leave the bag screen**. The Info tab stays
  readable anywhere; the Gems/Reforge tabs work only in Crownfall (Petra and
  the Lapidary). Outside the city the tabs explain where to go. This is the
  strongest "capital is core" lever in the brief and matches WoW/D3 precedent
  (no field reforging). Loadout decisions become pre-run decisions.

## 3. Shop economy: the capital is the shop

- **Chapter-start shops are gone.** Campaign chapters no longer spawn the
  static start-room merchant. You provision in Crownfall, then leave.
- **The capital bazaar restocks at dawn** (its own refresh timer, daily epoch
  on the trusted clock): 5 rolled gear pieces + bags, fair prices, resonance
  haggle still applies. The shop UI shows the countdown. Special = fresh, not
  cheaper.
- **Mid-run merchants become the treat**: safe-room camps and wandering
  merchants still appear inside chapters, but charge **road prices** — a
  seeded bell-curve markup, mean 15%, σ 2.5%, clamped to [10%, 20%]
  (per-merchant, per-run; distributions are curves, not uniform rolls). The
  shop header names the markup so it never reads as a bug. Sell prices are
  untouched (no sell-spiral interaction). The Depths prep camp keeps fair
  prices — it is its own designed economy.

## 4. NPC favorability (v1 — small, real, visible)

Per-character `npc_favor` (rides the save like resonance). Earned by:
- **Spending**: 1 favor per 25g spent at that artisan's service (Petra =
  reforge bench, Lapidary = gem work).
- **Quests**: intro quests pay a favor chunk on turn-in.
- **Resonance tie-in**: favor gains ×1.25 on a steady shard, ×0.75 tempted —
  the same shard-reading the merchant already does, now city-wide.

Tiers: Stranger → Regular (25) → Friend (75) → Confidant (150). Effects are
visible discounts at that artisan (2%/4%/6% off their bench costs), shown on
the bench UI next to the tier name. No silent effects.

v1 scope is deliberately just Petra + Lapidary: the mechanic exists, has
teeth, and the owner can taste it. Expansion candidates (NOT built): ward
favor from faction contracts, tavern favor from party play, favor-gated
cosmetics/recipes at Confidant. See §7 open questions.

## 5. Onboarding: first ch1 clear routes to Crownfall

- Solo: after the ch1 first-clear results card, the run travels to Crownfall
  (one scripted arrival, once per character). Co-op: the victory portals spawn
  and the Crownfall portal carries the quest mark instead (no yank).
- First arrival: Factor Imre carries the ❢ and points at the services. Intro
  quests, each turned in AT the giver (reward + favor):
  1. **The Lapidary — "A Stone Well Set"**: accept → receive a training gem;
     socket it into equipped gear; return. (Gems don't drop until ch4 — the
     quest supplies one, teaching the system early.)
  2. **Smith Petra — "Tempered Once"**: reforge any affix at her bench;
     return. Reward refunds the first bench fee, plus favor.
  3. **Marshal Corin — "The Marshal's Approval"**: spend a talent point;
     return.
- Service NPCs pulse gently until first spoken to (per-character `cap_met_*`
  flags); quest givers use the existing ❢ mark. `cap_` joins the
  character-scoped kept-flag prefixes so progress survives chapter wipes and
  stays per-head in co-op.

## 6. End of chapter: portals, not a wall

The blocking "ENTER to advance / R to replay" card is replaced by **three
gates in the boss arena** after the results card is dismissed: Return to
Crownfall · Replay the chapter · Onward to the next chapter. The results card
(grades, PBs) still shows — it just closes back into the world.

Co-op: the ready-check machinery is untouched — the host using a gate opens
the existing reprise picker + MP-20 ready check (same flow as the capital's
Wayfinder portal_story); guests at a gate are told the leader picks the road.
The dedicated server keeps its linger-then-advance behavior. No NET_VERSION
bump expected (no new messages; the victory fan already carries everything).

## 6b. Morning-review fixes (2026-07-25, owner's first pass)
Three reports from the owner's first in-game look, all fixed same morning:
- **Prompts floated below their landmarks and fired from too far** (the
  fountain screenshot): prop hotspots now carry a tighter reach
  (`PROP_HOTSPOT_REACH` 70 vs 80 for people), the prompt label anchors ON
  the landmark art (mid-height over the station's own x — the Archive's
  three desks still label their own doors), and the fountain stand-point
  hugs the basin. The victory way-gates were rebuilt on the structure path
  in the same pass (the NPC render path would have drawn the 512px arch ~5×).
- **A structure prompt stacked on Old Fenna** ("Warm yourself" read as her
  talking): NPCs who own several functions are now GOSSIP HUBS — one press
  opens the CQ splash dialogue with options (mouse / number keys / tap).
  Fenna offers the hearth warm-up + chat; Nix offers "Find a company"
  (opens Play Together via the new `hub_action` convo-choice key) + news;
  Petra / the Lapidary / Corin offer bench + quest line + leave. Pure
  structure stations (alembic, archive desks, portals) stay prop hotspots.
- **Walkable building interiors** (the tavern screenshot): the big capital
  halls only had the default 34px base-strip collider — body colliders
  authored for tankard/forge/archive/chapel/longhouse/sable/chartered
  halls, and the city-edge arcade backdrop gained one shallow base strip
  (the room walls never actually owned that edge).
- **Invisible walls** (the fangmoot screenshot): the inverse defect — some
  authored colliders hung 22–74px BELOW their art's lowest opaque row
  (padded 512px sources render their visual bottom above the base anchor),
  so the block stood in visually empty grass. Retuned: fangmoot
  (circle→platform rect — it also under-covered the sides), fountain,
  forge, longhouse, market stall, gate piers, spire piers, crucible piers
  (caught by the new contract test, not by eye); plaza spawn nudged clear
  of the fountain's corrected body.
- **Stand-points now DERIVE from colliders** (round 3 — "prompt still far
  below / doesn't show when I hug the structure"): the authored hotspot
  offsets were tuned against the old oversized colliders, so once colliders
  hugged the art, standing against it fell OUTSIDE the trigger band. Every
  landmark hotspot now stands `PROP_HOTSPOT_STAND` (34px) south of its
  collider's south edge — adjacency always triggers; the archive desks and
  market stalls had the same latent gap and are cured by the same rule.
- **Art self-alignment** (round 4 — "his head is overlapped by the hearth"):
  the third face of the padding disease — the drawn base floated above the
  y-sort anchor, so a hero standing in the phantom band sorted BEHIND the
  structure. `_add_structure`/`_add_backdrop` now measure each art's bottom
  padding (cached alpha scan) and shift the sprite so its lowest opaque row
  sits at the +12 grounding line — pixels, collision and y-sort agree for
  EVERY structure, chapters included (tight-cropped art is unchanged).
  Collider contract v2 became pure data: south edge ≤ the grounded line.
- **Battle seals are visible gates now** (round 5 — "no visual indicator
  that the room is locked"): the hot-room door seal parks a step OUTSIDE
  the room, beyond the camera clamp — its red glow was literally off-screen.
  Each seal now renders ch1-style gate bars AT the door line (red-tinted,
  pulsing) so a locked exit is always visibly barred.
- Intro-quest fix caught by the suite: the Lapidary's gem quest was
  uncompletable for a fresh ch1 hero (socket floor is C-grade; F/E gear
  can't socket, and the random gem could roll a special). She now hands a
  training KIT — a socketed C-grade keepsake + a guaranteed-regular stone.

## 7. Open questions for the owner
- Flow nit: after the first-clear route to Crownfall, the Wayfinder story
  gate returns to the COMPLETED ch1 world (its way-gates still stand at the
  arena, so ch2 is two hops away). Should the story gate instead offer the
  next chapter directly when the chapter you came from is complete?
- Ward favorability: wire faction contracts (bounty attribution) as favor
  sources next, or keep favor artisan-only until the social layer lands?
- Should the capital bazaar guarantee one item at the account's highest
  unlocked act cap per restock (a "come home daily" hook), or stay pure-roll?
- Field socketing is now impossible — if playtests say a mid-run gem drop
  feels dead in the bag, option: allow *socketing into empties* anywhere but
  keep unsocket/reforge/add-socket city-only (Diablo compromise).
- The cut capital NPCs (Suli, Sera, Haim, Osk, Brann, Vasse, Ashe, Dov, Osla,
  Sighne, Palla…) are gone from the city, not the game. Rebuild any as ward
  depth later?

## Implementation map
- `tools/content/gen_capital.py` → 9-room grid, NPC-owned services,
  single-access rule (regenerates `capital_hub.gd`).
- `balance.gd` §capital: favor rates/tiers/discounts, markup curve consts,
  bazaar restock size.
- `game_base.gd`: `npc_favor` api (`favor_add/favor_tier/favor_mult`),
  `shop_markup(zone)`; save.gd persists `npc_favor`; `cap_` kept-flag prefix
  in game_flow.
- `menus.gd`: shop header (markup line / restock countdown), capital-gated
  Gems/Reforge tabs with travel hints, favor meters on the benches, favor
  credit on spend.
- `hud.gd`: stash icon removed.
- `game_flow.gd`: victory portals + first-clear routing; `game_world.gd`:
  portal props at the arena, NPC pulse markers.
- `story.gd`/content: capital intro quests (`cap_q_*` character flags, NPC
  turn-in), Imre arrival beat.
- Tests: autotest capital section updated to the 9-room contract; ch1/ch2
  merchant expectations updated (no start-room shop); new sections for
  markup curve, favor math, restock epoch, intro-quest chain, victory
  portals.
