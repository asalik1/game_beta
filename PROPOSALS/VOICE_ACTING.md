# Voiced dialogue via ElevenLabs TTS — working proposal

_Drafted 2026-08-23 from a live session with the owner while cutting the marketing trailer. This doc is the **SoT for the dialogue-voiceover system** (voice casting, the generation pipeline, engine playback, cost, phasing). It is **seeded by the trailer VO work**: the trailer's voice-map + hash-cached generator + ffmpeg mux is the v0 of the same three primitives this proposal scales into the game. Nothing here is built yet — it is a plan._

---

## 0. The idea in one line

Every authored line the player reads — `Story.ALL_CONVOS[<convo>].nodes[<node>].text` — is **spoken by a per-character ElevenLabs voice**, played under the existing on-screen subtitle, produced by a **hash-cached offline pipeline** so only new or edited lines ever cost money. Not runtime TTS — pre-generated audio assets shipped with the build.

## 0.1 Rulings ledger (fill in as the owner rules)

**OPEN — needs an owner call (see §8):**
1. Is the **protagonist voiced**, or silent-protagonist (only NPCs/Narrator speak)? _Recommend: silent protagonist — player CHOICES stay text._
2. Are **player choice options** voiced? _Recommend: no (they're the player's mouth)._
3. **Scope of v1**: Act 1 openings + bosses only, or all main-path dialogue? _Recommend: phase it (§6), gate on the real bill._
4. **Mobile**: ship the audio in the mobile bundle, or PC-only / optional download? (Bundle-size + the mobile sync.)
5. **Budget cap** per generation pass, and who holds the ElevenLabs account/plan.

**AGREED IN SESSION (owner floated it, I'm recommending the shape — red-pen if wrong):**
- Voicing in-game dialogue is a real, wanted direction; the trailer VO is deliberately the first brick so the pipeline is reused, not rebuilt.

---

## 1. Why it's cheap to start

The marketing-trailer voiceover already stands up all three primitives in miniature (`scratchpad/build_hero.py` + `trailer_lib.py`):
- a **voice map** (one narrator today; a dict tomorrow),
- a **generator** that turns lines → audio (SAPI placeholder now; the ElevenLabs REST call is a one-function swap),
- a **mux/playback** step (ffmpeg over the trailer; the engine over dialogue).

So this is not a from-scratch system — it is generalizing a thing that already works.

## 2. Architecture (three pieces)

### 2.1 Voice map — `voice_map.json`
`{ speaker → { voice_id, stability, similarity, style, filter } }`, keyed by the `who` field the dialogue already carries (Narrator, Bren, Elder Maren, Vargoth, …). One consistent voice per character. `filter` is an optional post-process (e.g. a low/reverb pass for bosses, a whisper bed for the Echo). A `_default` entry catches unmapped one-off speakers so nothing is ever silent-by-omission.

### 2.2 The generator — `tools/voice/gen_vo.py` (offline, idempotent)
1. Load content (`Story.load_content()` via a headless Godot dump, or a parallel GDScript exporter) → flat list of `(convo_id, node_id, who, text)`.
2. **Sanitize** each line (§3) → the *spoken* string.
3. `key = sha1(voice_id + spoken_text)`. If `voice/<key>.ogg` exists, skip (no bill). Else call ElevenLabs, save.
4. Emit a **manifest** `voice/index.json`: `{ "<convo>/<node>": "<key>.ogg" }` for the engine to look up. Also emit a `MISSING`/`REGEN` report (lines whose text changed since last pass).

Idempotent + hash-keyed means: edit one line, re-run, pay for **one** line. This is the whole cost-control story.

### 2.3 Engine playback — `hud`/dialogue
The dialogue box already renders the node text as a subtitle. On showing a node, look up `voice/index.json["<convo>/<node>"]`, play the clip on a dedicated `voice` bus. Advancing before it finishes stops it (matches how players skim). A **settings toggle** (Voice: on/off, volume) on the voice bus. In co-op, voice is **local-only** (like other juice, `game.gd` §follow-the-local-player) — never networked.

## 3. Data model & text hygiene

`CONVOS[id] = {"start": n, "nodes": {n: {"who", "text", "cue"?, "next"|"choices"}}}` (confirmed in `story.gd`).
- **Strip stage directions** before TTS: `Kneel. "I'm sorry, Bren…"` → speak only the quoted part; parentheticals `(The door is standing.)` are non-diegetic — drop or voice as narrator, per a rule.
- **Narrator vs speaker**: `who == "Narrator"` → narrator voice; named `who` → that character's voice.
- **Choices** carry `text` too — unvoiced by default (§0.1 Q2).
- Fantasy proper nouns get a **pronunciation table** (`Vargoth`, `Emberfall`, `Crownfall`, `Cyrraeth`…) applied as ElevenLabs phoneme tags or spelled-out respellings, so they don't get mangled.

## 4. Casting (first-pass voice map)
- **Narrator** — deep, gravelly, measured (the trailer's voice).
- **Bosses** — distinct + processed: Vargoth hollow/reverbed, Veyx crackling, Morwen breathy, the Echo a doubled whisper. (Mirrors the existing per-boss *music* identity.)
- **Named NPCs** — a small rotating cast of voices assigned by role (elder, cleric, soldier, merchant, child), reused across minor NPCs to bound the voice count.
- **Protagonist / choices** — silent (recommended, §0.1).

## 5. Cost model & controls
- ElevenLabs bills **per character of text**. A full RPG script is tens of thousands of characters → a real (but not crazy) one-time bill, near-zero on edits thanks to the cache.
- Controls: (a) **hash cache** — only changed lines re-bill; (b) **phasing** (§6) — measure the Act 1 bill before committing to everything; (c) a **budget guard** in `gen_vo.py` that estimates characters and refuses to exceed a cap without `--confirm`; (d) reuse voices across minor NPCs.
- **Licensing gate:** commercial use of ElevenLabs output requires an eligible **paid plan** (their commercial terms grant usage/ownership of generated audio on paid tiers). This is a hard prerequisite before any shipped line — the game sells on Steam, so it must clear the same "commercial-safe" bar as every other asset (CLAUDE.md Asset sourcing). Confirm the plan/terms first.

## 6. Phasing
- **P0 — Trailer VO** (this session): the pipeline's proof of concept.
- **P1 — Act 1 spine**: chapter openings + boss lines + the handful of key story NPCs. Small, high-impact, and it's the bill you use to decide the rest.
- **P2 — Named NPCs, main path**: the authored cast across Act 1–3.
- **P3 — Side quests / ambient**: the long tail.
- **P4 — Localization / re-voice**: same pipeline, new voice map per language.

## 7. Gotchas & risks
- **Pre-generate, never runtime.** No live API calls in the shipped game (latency, cost, offline play, key exposure). Audio is a build asset.
- **Text drift**: dialogue is actively edited (casual house-style pass, humanization branch). The hash cache handles it, but a `REGEN` report should surface changed lines each pass so nothing ships stale-voiced.
- **Storage / bundle size**: thousands of OGG clips add up — matters most for the **mobile bundle** (§0.1 Q4); consider PC-bundled + mobile-optional-download.
- **Consistency across regens**: same text + same voice + same settings → keep it deterministic (pin `voice_id`, model, settings in the map) so a re-run doesn't subtly re-voice everything.
- **Determinism vs the "re-roll cheap gens" doctrine**: unlike art, a re-rolled VO line costs money and drifts consistency — prefer accepting a good take and only re-gen on a text change.

## 8. Open questions (owner)
1. Protagonist voiced or silent? Choices voiced? (§0.1)
2. v1 scope — Act 1 slice vs all main-path?
3. Mobile inclusion + delivery (bundled vs download)?
4. ElevenLabs plan/account + budget cap per pass?
5. Ship voiced dialogue with a content update, or hold for a "voiced edition" beat?

## 9. Relationship to other docs
- **Seeded by** the marketing-trailer VO (`scratchpad/build_hero.py`, `trailer_lib.py`) — same voice-map + hash-cached generator.
- **Dialogue text** is owned by the story/content modules + the casual house-style ruling (no em dashes, casual voice) — this doc voices that text, it does not author it.
- **Boss voice identity** rhymes with the per-boss music themes (`music.gd`) and the dev-morph/live-boss recast note.
