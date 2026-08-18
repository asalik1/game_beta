# Codex headless — the MMO layer

**Read the machine-wide guide first: `C:\Users\asali\Projects\CODEX_HEADLESS.md`** (Projects root,
shared by every project on this box). It owns: where `codex.exe` is and how to resolve it, the
canonical `codex exec` call and the prompt-on-STDIN rule, what a run prints/returns (`-o`, `--json`,
`--output-schema`, token floor), the full flag table for the installed version, `resume/fork/review`,
the config defaults every run inherits, the RAM/timing limits of batching on this shared machine
(§7 there — read it before launching more than one job), image_gen behaviours, sandbox quirks.
None of that is repeated here. This page is only what the MMO adds on top.

## Authorization and division of labour

- The built-in Codex `image_gen` tool is the project's DEFAULT generated-art lane (CLAUDE.md
  "Generated art tool authorization"), so an agent driving `codex exec` needs no extra
  permission. PixelLab is the opposite: explicit-request-only.
- **Codex generates into a staging dir; the agent vets and installs.** Never point a brief at
  `game/assets/`. Vet = LOOK at the image, `python tools/art/verify_art.py <base>` after install,
  tonemap check (Forward+ renders PNGs darker — pre-brighten ~gamma 0.78, judge in-game), then the
  matching `install_*.py`. Asset licence rules in CLAUDE.md apply to what Codex was shown as refs.

## Repo tooling

| tool | role |
|---|---|
| `tools/codex_bin.py` | the binary resolver (root guide §1) as a ready-made module: `python tools/codex_bin.py [--version]`, or `from codex_bin import resolve`. `CODEX=$(python tools/codex_bin.py)` in bash loops. |
| `tools/art/run_codex_batch.ps1` | the batch runner; implements the root guide's §7 staging layout (`codex_brief.txt` on stdin, `refs/*.png` → `-i`, `-o codex_result.md`, `codex_log.txt`), resolves the binary itself (`Resolve-Codex`), prints OK/FAIL per stage. `-Stages "d1,d2,…" [-MaxParallel N] [-MinFreeGB G] [-TimeoutSec S] [-ExtraArgs "…"]`. **On this box, beside a Godot suite or other agents: `-MaxParallel 1 -MinFreeGB 1.3`.** Defaults = legacy all-at-once. Verified 2026-08-17 (two stages, one with a 256×256 `-i` ref, `-MaxParallel 1`): both `OK`. |
| brief generators | `art_src/Custom/{HazardFX,RingFX,SkinFX}_2026-08-15/make_briefs.py`, `tools/art/alt_swing_pipeline.py`, `tools/art/act1_brief_lib.py` (Act 1 boss verbs), `tools/art/floorgen_prompts.py` (palette-anchored floor tiles) — each writes `<stage>/codex_brief.txt` + `refs/`. |
| readers | `tools/art/scan_drift.py` keys on each job's `codex_result.md` self-report to pre-filter identity drift in a directional wave. Prefer `--output-schema` (root guide §3) for any NEW script that reads Codex verdicts. |
| strip/sheet builders | what turns a Codex master into an engine strip: `build_codex_2x2_strip.py`, `build_fx_strip.py`, `build_mob_walk_repairs.py`, `install_critter.py`, `install_prop_anim.py`, `install_ground_field.py`, … — one line each in `tools/INDEX.md` "Art — generate & install". |

## Prompt playbooks (MMO-specific craft, not repeated in the root guide)

- `tools/art/IMAGEGEN_SPRITE_PIPELINE.md` — the end-to-end sprite/animation playbook (identity
  contract, prompts, extraction, directional repairs, wiring, QA, mobile sync).
- CLAUDE.md "Codex built-in ImageGen walk-animation observations" — bipedal walks = ONE ROW of
  EIGHT gait-labelled figures, never a 2×2; ask Codex to report leg-lead per frame.
- `BOSS_REGENERATION.md` + `art_src/bosses_codex_wave1/<boss>/README.md` — how the Act 1 boss
  waves were run (4 + 4 parallel sessions when the machine was free) and reproduced per boss.
- Despill: every ImageGen-keyed strip carries a 2 px dark-green rim →
  `build_mob_walk_repairs.remove_green` / `build_fx_strip.py --despill`; check `G > max(R,B)+20`
  on the rim, not just the semi-alpha BLEED gate.

## Adding a driver

Resolve the binary through `tools/codex_bin.py` (or copy `Resolve-Codex`), follow the root
guide's staging layout so `scan_drift.py`/the runner can read your stages, add one row to
`tools/INDEX.md`, and link the root guide from the docstring instead of pasting flag lore.
