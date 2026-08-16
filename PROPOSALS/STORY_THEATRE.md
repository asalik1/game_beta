# Story Theatre — replaying opening scenes from the codex (WANTED, not built)

Status: owner-wanted future feature (2026-08-15). Not scheduled. Owner ruling
on the one hard question: **a replayed choice is never saved.**

## What it is

A "Theatre" shelf in the codex (beside Story so far) that lets the player
re-PLAY a chapter's opening scene: the cutscene/dialogue as staged, with its
choices offered again, in the class refraction they are playing. Today the
codex only re-READS: `Story so far` renders the Journal's transcript archive
(every conversation and choice as it was actually played).

## Why it isn't just "run the opener again"

An opener is not inert. Through `hud` dialogue and `game_flow` it can:

- set flags (`chose_*`, quest starts, opener flags — `Story.chapter_opener_flags()`),
- change Resonance / faction standing off a choice,
- grant items, gold, gems, titles, achievements, codex lore unlocks,
- spawn, teleport, or re-theme the room, start music, gate doors,
- autosave.

Replaying it live would rewrite the character's story state. So the feature IS
the sandbox, and the sandbox is the whole cost.

## The sandbox contract (what "not saved" has to mean)

1. **Flag layer**: every `set_flag` / `get_flag` during a Theatre run reads
   through the real flags but WRITES to a scratch dictionary that is discarded
   on exit. Same for Resonance deltas, standings, quest starts, kill/lore
   counters, achievements and codex unlocks.
2. **Economy off**: `give_loot`, `add_renown`, gold and gem grants,
   `unlock_achievement`, titles — all no-ops (or diverted to the scratch layer)
   while the Theatre is up. Autosave suppressed.
3. **World off**: the scene plays over the CURRENT room; anything the opener
   would spawn/teleport/gate is skipped or staged in a throwaway layer that is
   freed on exit. Music may play (it is presentation) and must restore.
4. **Exit is total**: ESC / end of scene → scratch layer dropped, HUD/state
   restored exactly, no autosave. Dying inside is impossible (no combat).
5. **Co-op**: solo only (a shared world can't pause into someone's theatre) —
   gate on `net_online()` like the endgame trials.
6. **What CAN persist** (allowed, cosmetic): the archive may note "replayed",
   and Gallery portraits met in a replay may hang (they are account meta, not
   story state) — owner call when built.

## Build sketch (when scheduled)

- `game_base`: a `theatre` mode flag + `_theatre_flags` scratch dict; route the
  flag/resonance/standing/economy setters through it (one guard each — audit
  every setter, this is the risky part).
- `hud` dialogue: unchanged; it already reads/writes through the game API.
- Codex: a `theatre` rail entry under Reference (`UICodex.SECTIONS` +
  `_build_page`), one row per chapter whose opener has been SEEN, "Play" →
  `game_flow.theatre_play(chid)`; the row shows the class refraction and the
  choice you actually made (from the archive) beside "replay".
- Autotest: enter a theatre run, make the OTHER choice, exit, assert no flag /
  resonance / gold / achievement changed and the archive still shows the real
  choice.

## Why later

The archive gives re-reading today for free; the theatre is a nice-to-have on
top of a setter audit that touches every state-writing seam. Do it after Act 2
openers exist, so the audit is done once for all of them.
