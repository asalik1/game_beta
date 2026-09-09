# Hero geometry reuse

Hero strip bounds are reused during character and menu setup while preserving the existing size and footing. The desktop comparison, mobile geometry run, regression suites and preflight passed.

Art stores exact `Rect2i` bounds on each hero-requested strip texture. New strips are measured from their already loaded `Image` before texture creation. A strip first loaded for a non-hero is measured on its first hero request. Different gameplay/preview rectangles receive separate entries; an identical rectangle shares one scan. Normal non-hero callers retain their existing default and gain no eager scan.

The texture owns the record; there is no additional global texture owner or retained `Image`. The record checks source instance ID and dimensions, rejects copied metadata and holds no FPS, class scale or render offset. A fresh one-shot `changed` callback captures only a `WeakRef`; same-size `update`/`set_image` clears the record, and a later hero request reseeds it. Unregistered textures, Atlas wrappers and unusual size overrides retain direct measurement. Existing derived live-render caches are unchanged; this is not general hot-reload invalidation.

| Caller | Formula retained after raw-bounds lookup |
| --- | --- |
| Player | Used height and bottom both subtract one; class size and `CHAR_RENDER_SCALE` determine scale, with `HERO_FEET_ANCHOR` retained in the offset. |
| Class preview | Uses full nontransparent height and exclusive bottom; keeps the empty-frame fallback, 3× cap, stage floor and existing per-menu body cache. |
| Paper doll | Uses the nontransparent box midpoint only for horizontal centering; scale and vertical placement still use cell height. Nonpositive frame sizes retain the original Atlas path. |

No artwork, import settings, hero dimensions, animation rates, combat behavior or per-frame animation processing changes. Measurements describe setup work. They do not establish FPS, GPU-transfer-byte or whole-boot improvements; the seed scans must be counted as work even when Player readbacks disappear.

## Validation

The same fixed-order, six-base-class rig runs in four separate processes and isolated profiles. Clean runs supply elapsed method timings; instrumented runs count the actual selected `get_image`/`get_used_rect` callsites and their source pixels. Instrumented timings are perturbed and must not be used for a speedup claim.

| Phase | Source / evidence | Result at this draft |
| --- | --- | --- |
| Clean baseline | Original formulas; common rig | 150 checks, 0 failures, 25 PNGs, 119s; strict runner PASS. |
| Instrumented baseline | Original native operations with diagnostic wrappers | 296 checks, 0 failures, 25 PNGs, 105s; strict runner PASS. |
| Clean after | Raw-bounds reuse; after-only synthetic contracts | 174 checks, 0 failures, 25 PNGs, 91s; strict runner PASS. |
| Instrumented after | Same reuse with seed/lazy/new-rectangle work counted | 325 checks, 0 failures, 25 PNGs, 93s; strict runner PASS. |
| Mobile clean after | Synced clean source, Compatibility; all25 native images reviewed | 174 checks, 0 failures, 25 PNGs, 81s; strict runner PASS. |
| Final gates | Imports, desktop and mobile suites, preflight | Desktop compile228 / quick125 / full205; mobile compile228 / strict quick125; preflight PASS. |

Each completed desktop phase has 13 fullframes and 12 native crops: only warrior, mage and assassin receive controlled world/model screenshots. All six classes and their paper dolls have numeric geometry coverage. It is not a six-class screenshot set or paper-doll visual review. Poses and frame-zero models are explicit geometry fixtures, not ordinary combat or animation-playback evidence. Warrior is already warmed by boot; later class, preview and paper-doll measurements reuse process caches.

After-only contracts cover lazy/non-hero behavior, exact distinct regions, caller/return value isolation, equal-size replacement, same-backing Atlas fallback, copied-resource identity, same-size pixel updates and retirement without a new strong owner. Native work assertions additionally check one lazy read/scan, no warm work and one read/scan for a new region. Temporary entries were removed and all four geometry signatures exactly equal the clean baseline. These native contracts passed, including same-size update/set_image and weak lifetime. The dimension guard and reseeding without a changed signal are source-reviewed only; no runtime size-override/rearm contract is claimed.

Across 139 matched production phases, actual instrumented read calls fell from 1,433 to 425 and alpha scans from 1,008 to 400. Player measurement calls to both native operations fell 946→0, preview 56→0 and paper doll 6→0. The remaining 425 reads are unchanged `Art.override`; the after total includes all 400 `Art.hero_seed` scans on already loaded Images. Synthetic cache contracts, detached method-entry probes and independent reference operations are excluded from those matched totals.

In the single clean timing pair, six repeated real `set_class` calls totaled 1,917.589ms before and 11.616ms after. This is one sequential setup sample, with normal reset/recalculation included and retained caches; it does not establish stable cold-start, whole-boot or frame-rate gains. Root restored the exact clean-after source, with 967 asset/import/tuning hashes unchanged. The paired desktop review accepts all 50 clean before/after images: no new feet, size, shadow or model-placement regression. Six world crops are byte-identical; tiny preview differences remain in the dark stage background. This does not imply fullframe byte equality, ordinary combat or live shadow cadence. See `build/qa/hero-geometry-execution1/clean-paired-visual-review.md` and its 50-image receipt. The mobile Compatibility review also accepts all25 images and exact numeric parity; its preview floor glow is fainter than Forward+. No mobile baseline, physical-device, performance or touch-input claim follows. See `build/qa/hero-geometry-execution1/mobile-clean-after-visual-review.md`. Desktop and mobile regression gates and preflight passed.

## Reproduction and evidence

Run the existing compile-gated, muted `shot.bat` from the repository root. Run a normal headless editor import when publishing new QA scripts so each project generates its own UID sidecars. The shot runner only imports automatically when its shared ShotRig class is missing. Before each invocation, redirect `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP` to fresh absolute directories under `build/qa`, and restore the shell environment in `finally`. The rig refuses an ordinary profile before boot and uses `no_saves`; it is a disposable process, not a rollback of a live user session. Preserve logs, raw streams and complete `observations.json`; do not bypass import/compile, set fixed FPS or run another engine concurrently.

```bat
shot.bat hero_geometry --renderer=forward_plus --timeout=420
shot.bat hero_geometry --renderer=forward_plus --timeout=420 --compare=<absolute-clean-baseline-observations.json>
shot.bat hero_geometry --mobile --renderer=gl_compatibility --timeout=420 --compare=<absolute-clean-baseline-observations.json>
```

The first command records the currently installed clean implementation as a reference; the other commands require the corresponding installed clean implementation and synced mobile source. For the two instrumented phases, use their matching temporary source wrappers and add `--work-counters`; the flag alone does not instrument production. Restore clean source immediately afterward. Follow the verified source snapshots and phase order in `build/qa/hero-geometry-fix/execution-plan.md`; do not copy old full-file payloads over later changes.

Baseline artifacts: `build/qa/hero-geometry-execution1/clean-baseline/runner.log` and `profile/appdata/Godot/app_userdata/Crownless/shots/hero_geometry/observations.json`. JSON SHA256: `0aa24dbcc0774849a1a54e8cea66e7152611d64ac897883cfe6fe7c082c29ba9`. Geometry signature: `0216ba6eb5251d694f1749b300bc83010cec3b264bf982c8be2f77d4c0e1ac75`. The runner accepted its established renderer-shutdown diagnostics; this is not an error-free stderr claim. Source binding lives in each report and the execution snapshot receipts. The quartet receipts are the corresponding clean/instrumented baseline/after folders; `clean-restoration.json` binds the restored deliverable source. Final logs, all23 committed-path hashes and the actual commit identity are recorded in `build/qa/checkpoint36-validation.json`.
