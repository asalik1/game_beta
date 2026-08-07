# Monetization split & cross-platform accounts — working proposal

_Drafted 2026-08-06 from a live design session with the owner. This doc is the **SoT for monetization mechanics** (SKUs, currency, tickets, catalog, accounts). `PORTFOLIO_AND_SHOT1_RESONANCE.md` §8 keeps the portfolio-lens principles (the "taste" rule, fenced-cut risk, walk-away) and now defers to this doc for the mechanics. Where the two disagreed, the delta is called out here, not papered over._

---

## 0. Rulings ledger (don't re-litigate)

**RULED — owner said it in his own words (2026-08-06):**
1. Every player can play the full story, **Act 1 → Act 3, free** (mobile). Premium content + cosmetics sit behind a premium layer.
2. **No cosmetics are given out without money.** They are a bonus reserved for paid players. Free players *can* acquire them — but only via **massive dedicated grind** (premium currency).
3. The $15 tier includes **Skin Tickets** — redeemable for a choice of Elite-tier skins.
4. Earn-rate shape: **~1 month of dedicated free play unlocks the first endless mode.**
5. Approved paid cosmetic categories beyond skins: **pets, trails, mists, dash effects, footsteps**, and (2026-08-06 follow-up) **custom emotes** — ship as chat-bubble/sticker emotes (zero class coupling); acted full-body emotes stay parked under the coupling tax.
6. **Renown = event-limited titles and borders** (earned, interface-layer). Its role as a cosmetic-store currency is retired.

**RULED — 2026-08-06 follow-ups (same session, later):**
- **Rewarded ads: CUT for v1, IAP-only.** Owner note, on the record: if the game is a success, ads are back on the table — at that scale, handing out freebies from ads is acceptable maintenance. Until then the grind lane serves the never-payers.
- **PvP duels stay free.** Confirmed.
- **Ticket count = 2.** Confirmed. (Which Elite subset tickets can redeem — all vs a launch set — still open, §9.)
- **"Finish first, run later"** — the P0→P1 phasing, §8.
- **Way-gate/portal effects: IN** (audience question code-verified in §3 — the portal is where the party gathers).
- **Starting currency grant: ≈ $5 equivalent**, sized to fully cover one entry-tier catalog item (never strands the buyer mid-item; keep a few items at/below the grant).

**AGREED IN SESSION — owner assented to the recommendation; red-pen if wrong:**
7. **One SKU, both platforms.** The $15 Steam purchase and the ~$15 mobile full-unlock IAP are the *same entitlement* (`full_game`). The only platform difference is where the paywall sits: Steam at install, mobile after the free story.
8. Launch story free is a **launch-scope promise, not a genre rule**: future expansion-sized story (Act 4+, whenever) is a **paid expansion for everyone**, PC and mobile alike, each shipping with its own endgame layer. Word the $15 offer as "the full game **as of today**."
9. Ticket constraints: tickets are **vouchers, never sold standalone**, attached to the **SKU not the platform** (mobile full-unlock gets the same tickets), **Elite tier only — Mythic is excluded from every bundle** (currency-only, forever).
10. **3 free character slots**, all 20 with premium. (Class refraction makes free alting a demo of the game's depth.)
11. **Waking Incursions are free, with reward tables identical for free and premium players.** It's the weekly heartbeat and the currency faucet; splitting loot by payment status is selling power through the back door.
12. Boundary rule for cosmetics: **anything rendered in the world costs money; interface prestige is earned** (titles/borders via Renown).
13. Explicit rejects: XP/gold/drop boosts (selling pace = selling power in a ladder game), anything touching resonance or special abilities (existing never-sell rulings), and **stash/bag capacity** — bags are *loot* in Crownless; selling capacity cannibalizes the drop economy. Every monetization reference will push stash tabs; the answer is no.

---

## 1. The model in one paragraph

One premium product, one cosmetic economy, identical on both platforms. **Steam:** $15 buys the app; owning it *is* the `full_game` entitlement — no store, no login friction, everything below unlocked day one. **Mobile:** F2P story (Acts 1–3, built complete, not teasing — §8's taste rule), with the same `full_game` sold as a single ~$15 IAP, and its pieces individually purchasable with premium currency for the grinder lane. Cosmetics cost premium currency on both platforms; premium currency costs money or a massive grind. Cross-platform sign-in means you own `full_game` or you don't, no matter where you bought it.

## 2. The split

| Tier | Contents |
|---|---|
| **FREE (universal)** | Acts 1–3 story (free forever — launch-scope promise); all 6 classes; co-op (standing ruling: co-op free); PvP proving-grounds duels (ruled free 2026-08-06); base skins; 3 character slots; **Waking Incursions** (weekly, identical rewards — the currency faucet); Renown lane: event-limited titles + borders. |
| **PREMIUM — `full_game`, $15, one SKU** | Crucible (Boss Rush); Waking Depths (Marathon); NG+ Nightmare + Torment tiers; all 20 character slots; **2 Elite Skin Tickets**; a starting premium-currency grant (ruled 2026-08-06: ≈ $5 equiv, fully covers one entry-tier catalog item). Everything "as of today" — future acts are expansions. |
| **CURRENCY CATALOG (both platforms, priced in premium currency)** | Individual endless-mode unlocks (the piecemeal grinder lane); extra character slots (cheap sink); Elite skins (~$8–10 equiv); **Mythic skins (currency-only, never bundled)**; pets; trails / mists / dash effects / footsteps; custom emotes (bubble/sticker form — substrate exists, MP-19 party chat renders via `chat_line`); way-gate/portal effects (each player's own effect plays as the party departs). |

## 3. Cosmetic catalog — the coupling-cost principle

The cost of a cosmetic category is dominated by **whether it touches the hero sprite**. Anything that modifies the hero multiplies by 6 classes × 8 directions × every skin that exists or ever will. Anything that *attaches* is one asset.

- **Skins = the expensive flagship.** Elite and Mythic tiers as today. Mythic is the prestige ceiling: currency-only, excluded from all bundles — a Mythic on a free player means something extreme.
- **Pets = the volume star.** One small walk cycle, zero class coupling, built with the existing mob/object pipelines. Signature line: **echo pets** — spectral miniatures of bosses you've felled (mini-Cyrraeth is an instant grail item; catalog grows automatically with every boss shipped). Purely cosmetic v1 — no gold pickup, no utility.
- **Trails / mists / dash effects / footsteps** — procedural palette-and-shape variants of FX that already exist (phantom trail + mist). Near-zero marginal art. Must preserve combat readability (no-silent-effects principle): player-only, whitelisted hue ranges.
- **Custom emotes** — ruled in (2026-08-06 follow-up). Ship as **chat-bubble/sticker emotes** riding the MP-19 chat layer: drawn stickers above the head, one asset each, zero class coupling. Visible in co-op, the capital, and duels.
- **Way-gate/portal effects — ruled in (2026-08-06; audience question code-verified):** the capital's Wayfinder portals appear in the party town and are the party's *content queue* — the host picks the road at `portal_story` and the MP-20 ready check gathers every head in the plaza (`game_world.gd _hub_action`). Departure at the portal is the **most-witnessed moment in co-op**, so a personal gate-departure effect has a real audience (each player's own effect plays on their own body as the party winks out). Crucible/Depths portals also stand in the party capital but **refuse online** — `enter_endgame` hard-returns if `net_online()` (endgame is solo-only v1, `game_flow.gd:847`) — so premium-gated portals never collide with the shared world today. If endgame ever goes multiplayer, decide then whose entitlement gates a party run.
- **Build requirement for ALL in-world cosmetics (pets, trails, emotes, portal FX):** the equipped-cosmetic loadout must **replicate over the wire** (join brief / `peer_chars` + a change event) or cosmetics are self-only in sessions and half the show-off value dies. Small protocol addition; spec it with the first catalog item.
- **Parked:** mounts (riding pose × 8 dir × 6 classes × all skins = a permanent tax on every future skin). The one someday-cheat: a **travel form** that *replaces* the sprite (mount + generic rider) instead of composing with it. Also parked: acted full-body emotes (same per-class pose tax), seasonal battle-pass track (live-ops commitment — post-launch question).

## 4. Skin Tickets

- In the `full_game` bundle: **2 tickets**, each redeemable for one Elite-tier skin of choice.
- **Vouchers, not currency**: never sold standalone, never priced. The moment tickets are purchasable they're premium currency with a second name.
- Attached to the **SKU, not Steam**: the mobile $15 buyer gets the same tickets. This is load-bearing — forking the SKU by platform breaks "one entitlement, legible everywhere" and muddies Apple's same-item-purchasable-in-app parity.
- Future homes: expansions and supporter packs may include tickets; Mythic never.

## 5. Premium currency

One currency, one store (Renown is no longer a store currency — §6).

**Earn shape (first pass; §8's grind:pay knob — final tuning needs mobile cohort data, ship generous):**
- **One-time firsts** ≈ $4–5 equivalent total (story bosses, first-clears, achievements) — front-loads a taste so the store feels real.
- **Weekly-capped sources** ≈ $1.25 equivalent per engaged week; the weekly Incursion is the natural home for the cap.
- **First endless mode** ≈ $9 in currency → unlocks around **week 4** of dedicated free play (the ruled 1-month shape). Full `full_game` equivalent ≈ 2.5–3 months. Elite skin ≈ 2 further months each ("massive dedicated grind," as ruled).
- The only equation that matters when tuning: **weeks-to-unlock = (currency price − firsts) ÷ weekly cap.**

**Structural rules (matter more than the numbers):**
- Sources are **capped, not farmable** — per-kill trickles invite botting and make the rate untunable.
- **Identical earn rate on PC** — owners earn toward cosmetics (goodwill + store habituation).
- **Grants are server-side only.** Earnable premium currency cannot ship before the account backend exists; client-trusted earning is a money printer. (This is the hard dependency that drives §8.)

## 6. Renown repurpose

Renown + Wardrobe shipped as an *earned event currency with a cosmetics store*. Under ruling 2 that faucet has no job. New job: **Renown buys event-limited titles and borders** — interface prestige, earned only, expiring with events (FOMO does retention work money can't). The wardrobe's in-world cosmetics move to the premium catalog. Note: this is a decision to **unbuild/re-lane a shipped system**, and it's clean only because the game is unreleased — no player has earned anything, so §8's "never retroactively wall existing grind rewards" is not violated. After release this door closes.

## 7. Accounts & entitlements (the technical layer)

Cross-buy strictly requires a shared account backend — platform cloud saves cannot express "this account paid."

- **Store policy: the model is explicitly legal.** Apple guideline 3.1.3(b) (Multiplatform Services) allows honoring purchases from other platforms *provided the same items are purchasable as IAP in-app* — the one-SKU model satisfies this by construction. Google is equivalent. Steam has no objection to honoring external cosmetics/currency in a game already bought.
- **Account model:** one game-account UUID; **guest-first** on mobile (auto-created, zero friction), link Google/Apple later. **Sign in with Apple becomes mandatory** (guideline 4.8) the moment Google sign-in exists on iOS. PC↔mobile linking via one-time code/QR shown in-game.
- **Steam identity is implicit:** the client presents a Steam session ticket; server verifies via Steam Web API, confirms app ownership, auto-grants `full_game`. The PC player never sees a login or a store.
- **Grants only via verified receipts** — Apple/Google receipts validated server-side; never client claims.
- **Server-authoritative surface = entitlements + currency balance ONLY.** Character saves stay client-authoritative local JSON (cheat surface accepted pre-MMO; MMO-era characters are born server-side, not migrated). Save-file cloud sync rides along on the same account (blobs are small JSON with `saved_at` already in them — last-write-wins + a pick-on-conflict prompt).
- **Backend candidate:** **Nakama** (official Godot 4 SDK; device/Google/Apple/Steam auth; per-user storage; built-in Apple/Google IAP validation; self-hosted ≈ $5–10/mo VPS) — and it's the seed of the MMO backend, not a throwaway. Zero-ops alternative: PlayFab.
- **Obligations that arrive with accounts:** in-app account deletion (both stores require it) + GDPR surface.
- **The asymmetry no backend fixes:** mobile → PC still pays $15 for the Steam copy; what carries is currency + cosmetics + tickets. (Partial hatch: free Steam keys for big-spender mobile players — Valve approval + fraud surface; treat as maybe-later, not a pillar.)

## 8. THE structural tension: cross-buy vs walk-away

`PORTFOLIO_AND_SHOT1_RESONANCE.md` §8/§9 establish walk-away as a prized property: serverless netcode, "no accounts, matchmaking, or persistence backend to bill or rot," cosmetics as a **fixed set**, not a refreshing store. **This doc's full model breaches that three ways:** a standing account backend, server-side currency grants, and a catalog that grows over time. That's not a detail to absorb silently — it's the biggest open decision this doc creates.

**RULED 2026-08-06 (owner): "finish first, run later" — P0 → P1 phasing accepted.**
- **P0 — walk-away-compatible (ships first):** no shared accounts. Per-platform purchases; Steam Cloud (near-free to adopt) + platform cloud saves when store-ready; store-native purchase restore covers delete/reinstall per platform; **no earnable premium currency** (can't be trusted client-side). Cross-buy doesn't exist yet.
- **P1 — the account milestone, PINNED TO THE MOBILE LAUNCH.** Mobile's own model already depends on the backend (grinder lane needs server-side grants; cross-buy is the pay-twice-review antidote), and the portfolio plan is PC-first anyway — so sequenced this way the P0 window has **zero user-visible gap**: Steam launch needs no server for anything, and by the time a second platform can take money, accounts exist. Mobile does not ship before the backend does.
- **Cost of the deferral (so it's priced, not vague):** ~1 day now, 2–4 focused weeks at P1 (Nakama setup, three auth flows, receipt validation, link-device UX, deletion flow, three-store testing), then ~$100/yr + a few hours/quarter of ops. No P0 work is thrown away (Steam Cloud config, IAP products, entitlement seam all survive). Given up meanwhile: cross-buy can't be a Steam-store-page selling point yet; grind:pay cohort data waits for mobile (already accepted in portfolio §8).
- **The 1-day insurance, REQUIRED in P0 builds:** one entitlement seam — every content gate asks `Entitlements.has("full_game")` (or per-mode key) and every currency touch goes through one wallet interface. P0 backs these with store receipts/local flags; P1 swaps the backing to server state and touches nothing else. Scattered `if purchased` checks are the only thing that would make P1 expensive — don't write any.

**Deltas vs §8, explicit:** (a) §8 said PC $15 includes *all cosmetics, no IAP* — superseded by rulings 2/3/9: cosmetics are one shared currency catalog on both platforms, $15 includes tickets + a grant, Mythic excluded; PC players participate in the store. (b) §8's "different monetization path per platform" is now "one SKU, different paywall location." (c) §8's rewarded-ads open decision is inherited unchanged below — the currency model works with or without the ads accelerator.

## 9. Open decisions

- ~~[DECISION] P0 vs P1 phasing / walk-away breach~~ — **RULED 2026-08-06: finish first, run later; P1 pinned to the mobile launch** (§8).
- ~~[DECISION] Rewarded ads~~ — **RULED 2026-08-06: CUT for v1, IAP-only; revisit if the game is a success** (§0).
- ~~[CONFIRM] PvP duels free~~ — **RULED 2026-08-06: free** (§0).
- ~~[DECISION] Ticket count~~ — **RULED 2026-08-06: 2** (§0). Still open: the Elite subset tickets can redeem (all Elites vs a launch set).
- ~~[DECISION] Way-gate/portal effects~~ — **RULED 2026-08-06: IN** (§3).
- ~~[DECISION] Starting currency grant~~ — **RULED 2026-08-06: ≈ $5 equivalent, fully covers one entry-tier item** (a basic pet or effect — full store loop, no stranding; keep a few catalog items at/below the grant). With PC earn caps live, grant + ~3 engaged weeks ≈ the first Elite skin.
- **[TEST] Grind:pay ratio** — mobile cohort data only (portfolio §8); the §5 numbers are a generous first guess.
- **[TEST] Mobile paywall sentiment** on fencing existing endgame (portfolio §8's pre-registered watch + fallback).
