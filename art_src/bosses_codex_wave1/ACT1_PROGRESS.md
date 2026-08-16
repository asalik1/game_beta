# Act 1 boss Codex regeneration — progress tracker (SoT for the autonomous run)

## ✅ COMPLETE 2026-08-15 — all 21 Act 1 bosses done (18 this run + fangmaw/cinderhide/morwen prior).
Desktop + mobile compile gates green; `verify_art` 0 fail on all 18 (every WARN is a
legacy bypassed directional sheet). Both trees synced (249 files mirrored). Owner
in-game QA pending. Two clips needed a hardened-identity re-roll (nullwarden `beam`,
stormmouth `enrage`) after the generic roar/beam prompt drifted to a neighbouring
design; vess `bolt` re-rolled for a row-overlap. **Walks deferred for all 18** (idle-
only). Not committed (owner reviews first).


Owner asked (2026-08-15): "work on all bosses in act 1, complete them ... follow
the phase sequences." Won't return until ALL Act 1 bosses are done.

## Scope decided
- **Act 1 = chapters 1–7, 21 bosses.** Fangmaw / Cinderhide / Morwen already done.
- Per boss: regen a Codex **idle** + a Codex strip for **every distinct action its
  kit plays** (from `boss.gd`), built with `build_codex_2x2_strip.py`, front-facing.
- Identity = the boss's existing installed `<sprite>_anim.png` passed as the Codex
  image reference (re-animate the owner-approved design, don't redesign).
- **WALK is DEFERRED for all 18** (following the phase plan: bipedal leg-cycle walks
  are the Phase-2 risk). Each boss is marked idle-only, so it idle-breathes while
  repositioning. Fast-follow if the owner wants walks.
- Wire each: add sprite to `Art.BOSS_FLAT_ANIMATION_LOCOMOTION`, set
  `Art.BOSS_ACTION_FALLBACK` to a representative clip, `Art.BOSS_ACTION_FPS` for slow
  one-shots, `Art.MOB_IDLE_ONLY_LOCOMOTION` (walk deferred).
- Build preset (front-facing humanoid/beast): `--self` (idle) then
  `--anchor bbox --scale-ref area --scale-frame 1 --valign hem` for clips
  (bbox = body-mass, immune to a raised weapon/arm pulling a band).

## Roster + status  (D=done pre-run, [ ]=todo, [~]=in progress, [x]=installed)

| ch | boss kind | sprite | scale | clips (kit) | status |
|----|-----------|--------|------:|-------------|--------|
| 1 | fangmaw | fangmaw | 8.5 | pack slam charge leap | **D** |
| 1 | morwen | morwen | 9 | attack ring rain blink | **D** |
| 1 | vargoth | vargoth | 13 | enrage slam blade | **[x]** |
| 2 | stormwarden | korrag | 9.5 | pack storm lash | **[x]** |
| 2 | choirmother | choirmother | 8.5 | enrage summon bolt cast blink ring | **[x]** |
| 2 | nullwarden | nullwarden | 10.5 | enrage beam slam piston | **[x]** |
| 3 | sexton | sexton | 9 | summon slam surface | **[x]** |
| 3 | vess | vess | 8.5 | enrage ring blink bolt wail | **[x]** |
| 3 | saint_varo | saint_varo | 10.5 | enrage slam blade summon toll | **[x]** |
| 4 | forgemistress | forgemistress | 8.5 | throw lash quench | **[x]** |
| 4 | cinderhide | cinderhide | — | enrage breath rain charge | **D** |
| 4 | ashpriest | ashpriest | 10.5 | enrage rain bolt summon verdict | **[x]** |
| 5 | whitepelt | hrolgar | 9 | pack slam melee charge | **[x]** |
| 5 | icebound | serane | 8.5 | enrage bolt blink freeze beam | **[x]** |
| 5 | sleepkeeper | halla | 11 | enrage bolt freeze hymn summon | **[x]** |
| 6 | auroch | auroch_minotaur | 11.5 | melee slam charge | **[x]** |
| 6 | gardener | rotmaw | 10.2 | enrage bolt summon lash | **[x]** |
| 6 | curetwisted | kaethra | 10.5 | ring bolt stab throw slam shift | **[x]** |
| 7 | veyx | veyx | — | enrage ring storm arc summon | **[x]** |
| 7 | echo | echo | 10 | enrage blink throw split | **[x]** |
| 7 | stormmouth | stormmouth | 15 | enrage cast bolt | **[x]** |

Harness: `tools/art/act1_brief_lib.py` (identity + per-verb storyboards + brief
emitter). Masters/briefs/QA per boss under `art_src/bosses_codex_wave1/<sprite>/`.
