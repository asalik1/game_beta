# Crownless — Market, Retention & Social Strategy

Decision reference recorded 2026-07-18. This is not a balance log or story
canon: use `BALANCE_HISTORY.md` and `DESIGN.md` for those respectively.

## Objective assessment

Crownless has a credible foundation for a **niche co-op action RPG**: class
builds, meaningful faction and Resonance choices, seeded replayable chapters,
personal loot, reliable friends-first co-op, and post-campaign challenge modes.

That foundation does **not** by itself predict commercial success. The
action-RPG / roguelite space is crowded (SteamDB recorded more than 1,400
roguelike releases in 2026), so depth alone will not create visibility.

The realistic objective is to make a well-reviewed, sustainable niche indie
game. A breakout is possible but cannot be planned as an outcome. The biggest
commercial risks are:

1. weak first-ten-seconds presentation (trailer, screenshots, store capsule);
2. combat, onboarding, or co-op friction in a player's first session;
3. building a large live-service feature set before proving that strangers
   enjoy and recommend the core loop;
4. marketing too late to build a meaningful audience before launch.

## Positioning

Do **not** position Crownless as an MMO. That comparison creates an impossible
expectation of scale and operating support for an indie game.

Recommended promise:

> A dark-fantasy co-op action RPG where class builds and faction choices reshape
> a replayable campaign.

This accurately sells the game's strengths: action, buildcraft, story tension,
and friends-first co-op.

## Monetization

**Model: premium (paid up front). No cash shop, no sold power.** The base price
*is* the monetization, and it is the honest one — you pay once, you own the
whole game, and there is no store to distort it. This is not a compromise on the
anti-pay-to-win stance; it is the purest expression of it. The business model
must match the design philosophy, and everything already built (no power sale,
legible and stable depth, buy-once ownership) is a premium game.

**Why not cosmetics-only.** Cosmetics-only is a *scale* model: it works when a
small paying fraction sits on top of a very large free population (Fortnite, LoL,
Dota, PoE). Crownless has deliberately chosen niche-and-good over mass-and-free,
so that population will not exist by design. On a niche base, cosmetics alone is
rounding-error revenue — and reaching the population that would make them pay
means going free-to-play, which reintroduces every pressure the design exists to
avoid. Cosmetics are a garnish, never the foundation.

### Revenue architecture (the Diablo / Hades / Dead Cells shape)

1. **Base price — the core revenue.**
2. **Paid expansions — the recurring revenue, already designed.** DESIGN.md
   tags the Death Knight's grave-opening as "the expansion marketing beat" and
   the Summoner as the "headline addition later"; Act 2 and Act 3 are content
   drops. Expansions keep the frontier moving *and* pay for the work of moving
   it — the same content-drought answer that difficulty tiers give, at the
   business layer.
3. **Cosmetic DLC — optional garnish, post-launch.** Once an audience loves the
   game enough to want to flex it. The awakened-skin system already exists. Skin
   packs are additive and never necessary; this is where cosmetics belong.

### Pricing

A content-rich indie ARPG/roguelite with co-op and many hours of play credibly
launches in the **~$15–25** band. Unknown studios often anchor at $15–20 to
lower buy-in friction and accumulate early reviews, then raise the price later
(Dead Cells did exactly this). Decide the actual number **near launch**, from
real content volume and demo reception — the Next Fest demo response is the real
pricing signal, not a pre-launch guess.

### Parked (do not act on now)

- **Co-op discovery lever:** a later "friend pass" (one owner pulls a friend
  into co-op) is a strong word-of-mouth engine for co-op games.
- **The MMO fork:** premium does not box out the long-term MMO ambition. *If*
  Crownless ever becomes a true persistent-server game, that is the moment to
  revisit a subscription or hybrid model. For single-player plus friends-co-op
  on Steam, premium is unambiguously correct — do not price today for a server
  that does not exist.

## The retention loop to build

```
Weekly opportunity / party plan
        ->
Master a fight and advance a chosen build goal
        ->
Visible loot, mastery, lore, and social prestige
        ->
New challenge or shared goal next week
```

Retention must follow enjoyable moment-to-moment combat. It must not be used to
compensate for combat that is unclear, repetitive, or unrewarding.

### Design guardrails

- Social rewards should be additive: solo players can progress fully, while a
  party gains stories, coordination, and cosmetic prestige.
- Avoid power advantages for the winning faction, guild, or leaderboard tier.
  They create snowballing and make newcomers feel behind.
- Favor a specific, understandable next goal (a weapon, build, boss mastery,
  or weekly feat) over unbounded random-drop grinding.
- Avoid punishing daily pressure. The daily system should encourage a return
  without making a missed login feel like a lost obligation.

## Feature priority

### 1. Waking Incursions — highest priority

Implement the Waking Incursions described in `ACT2_DESIGN.md` before inventing
another mode. Three off-path, weekly mini-boss rooms in a cleared chapter use
existing maps, terrain, boss kits, rewards, and the weekly-seed infrastructure.
They are the best cost-to-retention feature currently designed.

The complete-all-three reward should include a cosmetic token as well as normal
loot. This gives the event a visible long-term reward without power creep.

### 2. Social weekly challenge

The fixed-seed weekly challenge exists, but its records are currently local.
Before guilds, make it a reason to contact friends:

- record separate solo-class and party time/grade records;
- produce a compact, shareable end-of-run result card;
- let a host send a friend-code challenge: “beat our Crucible time”; and
- award optional party feats (mixed classes, clean clear, rescue, etc.).

For the friends-build phase this can be code-based and local. Global rankings
should wait for persistent accounts plus trustworthy server/platform support.

### 3. S-weapon awakening quests

Implement the already-designed class-specific awakening trials. They turn an
S-weapon drop into a memorable mastery goal, class lore, and a permanent reward
rather than another random stat upgrade. This is a stronger long-term chase
than simply raising gear rarity.

### 4. Targeted build chase

After the above, give players controlled pursuit alongside random drops:

- domain/boss reliquaries that focus a slot or theme;
- a transparent pity track for S-grade drops; and
- limited affix locking or rerolling with a meaningful gold cost.

The desired player thought is “one more run for my Stormcaller bow,” not only
“maybe something good happens.”

### 5. Faction campaigns — needs an account/backend layer

Once persistent online identity exists, turn Accord/Cinderborn activity into
weekly community projects. Participation can unlock story vignettes, hub
visuals, faction cosmetics, or an event modifier. Do not let the leading
faction gain permanent combat advantages.

### 6. Companies / guilds — deliberately later

Do not build guilds before friend persistence, discovery, reliable identity,
and enough active players exist. When justified, keep Companies small
(roughly 6–12 players) and focused: a shared banner/hall, weekly expedition
board, cosmetic milestones, and contribution history. They should strengthen
friend groups rather than turn the game into administrative work.

## Immediate daily-reward revision

Replace “miss one calendar day and reset the seven-day streak” with a forgiving
cadence, such as five claims in a seven-day window or one grace day per cycle.
Keep the rewards modest and avoid exclusive power. The goal is a healthy habit,
not a chore players resent.

## Validation gates before expanding scope

Do not rely on internal enthusiasm. Run external playtests with players who are
not already invested in Crownless, ideally in pairs or small groups.

Measure:

- first-session completion of the opening ~20-minute loop;
- whether players understand their next build goal without explanation;
- whether they voluntarily start another run or invite a friend back;
- co-op failure/friction rate (joining, progression sync, revive flow);
- demo-to-wishlist conversion and wishlists accumulated before release;
- review sentiment about combat feel, clarity, performance, and co-op.

The go/no-go question is simple: after their first session, do players say
“let’s play again,” and can they explain why in one sentence?

## Go-to-market sequence

1. Polish one excellent vertical slice: class choice, memorable boss, visible
   loot/build change, and co-op invitation all within the demo.
2. Put up the Steam page early with a visually clear trailer and screenshots.
3. Run external playtests, fix the repeated first-hour problems, then publish a
   demo.
4. Use Steam Next Fest and relevant themed events only when the demo represents
   the game's intended quality.
5. Launch with a focused promise; continue with Incursions, build goals, and
   social events after core reviews prove the foundation.

Steam treats wishlists as a visibility input for upcoming-game discovery, and
Steam Next Fest is a demo-led opportunity rather than a substitute for quality.
Useful references: [Steamworks: Wishlists](https://partner.steamgames.com/doc/marketing/wishlist?language=english),
[Steamworks: Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest?l=english),
[SteamDB: Roguelike releases](https://steamdb.info/stats/releases/?tagid=1716).
