# Audio startup: synthesize only missing recordings

The desktop startup path now validates recorded overrides before building the
fallback banks. A valid recording keeps its exact `AudioStream` object; only a
missing or invalid base key invokes its procedural generator. The clean live
comparison passed **60 checks, 0 failures, 3 captures** on Godot 4.4.1 stable,
Forward+, with isolated QA user data and muted output.

## Implementation and preservation contract

- `game/scripts/game.gd` retains `_override_files` enumeration, manifest/export
  behavior, recording validation and loop setup. Recording dictionaries feed
  `Sfx.build_all(overrides)` and `Music.build_all(overrides)` before playback.
- Both builders retain their complete no-argument behavior. Their optional
  observer records actual generator calls during QA; normal startup supplies
  no observer, and there is no new per-frame work.
- Base keys retain their original insertion order. Valid override-only keys
  append in recording order; invalid extra values are omitted. Null and
  wrong-type base overrides cannot suppress synthesis. Variant arrays preserve
  their order and existing selection behavior.
- The 56 SFX recipes and 16 music specifications, synthesis bodies, local RNG
  seeds, notes, gain, buses and loops are unchanged. No audio asset changed,
  including `ult_mage.wav`; village, story and boss track content is unchanged.

The live call observer counted **35 SFX generators and 3 music generators**
(`darkwood`, `marsh`, `keep`). Thus 21 SFX and 13 music base generators were
actually skipped; these counts are not inferred from timing.

## Evidence

Reports are under `build/qa/`, each in
`<run>-user/Godot/app_userdata/Crownless/shots/audio_startup/observations.json`:

| Run | Result | Purpose |
| --- | --- | --- |
| `audio-startup-baseline2` | 28 checks, 0 failures, 3 captures | Original production startup and full fallback reference |
| `audio-startup-optimized1` | 57 checks, 4 diagnostic failures | All in-run PCM/order/identity/call checks passed; historical JSON comparison exposed numeric serialization differences |
| `audio-startup-optimized2` | 60 checks, 0 failures, 3 captures | Corrected historical comparator; all baseline2 comparisons passed |

The final run verifies actual boot banks against a full legacy-build-plus-
override reference, recorded resource identity, bank/variant order, every
fallback PCM hash, loop/settings signatures, invalid/null/missing override
fallback, valid override precedence, extra keys, and unchanged caller inputs.
Cover, roster and class menus also settle onto the expected streams and gains
while paused. Captures accompany their recorded state.

All three reports share this stable boot signature:

```text
444e8a59f140813d4ce6d18b19585841ce4219a568e7c2c954f2c638c263a1b3
```

The optimized1 historical failures were diagnostic serialization only:
independent parsed comparison found 2,266 leaves with zero value changes,
including all 72 fallback PCM hashes. Godot parses JSON integer-looking numbers
as floats. The diagnostic now accepts equal int/float leaves only in historical
report comparisons, while retaining dictionary keys, ordered arrays, hashes,
types and existing same-type serialization precision. Sanity checks prove that
changed sample counts, gains, fractional values, hashes, array order, missing
fields and bool/string substitutions still fail. In-run comparison is unchanged.

## Measured phases and limits

Elapsed milliseconds below come from separate calls inside the same rig process.
The default mode boots the real game first, then runs the full reference and
selective microbenchmarks. Signature hashing and invalid-override fixtures run
after these timed phases.

| Phase | Baseline2 | Optimized1 | Optimized2 |
| --- | ---: | ---: | ---: |
| Full no-argument SFX synthesis | 885.076 | 853.846 | 947.019 |
| Selective SFX synthesis + QA observer | — | 604.402 | 591.764 |
| Full no-argument music synthesis | 2,886.652 | 2,784.188 | 2,876.287 |
| Selective music synthesis + QA observer | — | 451.121 | 446.929 |
| Recorded SFX enumeration/loading | 3.709 | 3.723 | 4.220 |
| Recorded music enumeration/loading | 2.539 | 2.864 | 2.110 |
| Real `boot_game()` to return | 44,057.247 | 6,416.644 | 7,336.768 |

The generator counts and independent phase measurements demonstrate avoided
synthesis work. They do **not** establish an equivalent player-visible boot
improvement. Host load makes total boot timing noisy: an earlier original-path
baseline took about 10.7 seconds, versus 44.1 seconds in baseline2.
`boot_game()` includes scene load/instantiation, synchronous `Game._ready`,
deferred flow and ten process frames. It excludes process launch and does not
separate engine, shader, resource, player or world work. First-post-draw marks
are engine render boundaries, not OS window presentation.

Recordings remain referenced after real boot, so their later load measurements
are cache-warm and are not cold disk-I/O estimates. Full and selective calls
have fixed order; import/OS caches and GC are uncontrolled. Independent phases
must not be added or subtracted to apportion total boot time.

Current noise generators use explicitly seeded local RNGs, and same-engine PCM
parity is measured. This is not a future guarantee for generators that consume
global randomness: skipping such recipes could change later fallback bytes or
gameplay RNG consumption. Keep musical definitions and seeds unchanged.

## Repeating the diagnostic and remaining integration

Run through `shot.bat audio_startup --timeout=300` with isolated `APPDATA` and
`LOCALAPPDATA`, retaining the runner's Dummy audio driver. Add
`--compare=<absolute baseline2 observations.json path>` for historical parity.
Use a fresh output directory so the preserved baseline is not overwritten.
The rig inherits `ShotRig`'s Master mute, watchdog and `no_saves` behavior.
`--mode=boot` omits microbenchmarks; `--mode=phases` runs phases before game boot.

The mobile source is synchronized and imported. Its Compatibility diagnostic,
`audio-startup-mobile1`, passed 60 checks and three captures against baseline2,
including the same boot-bank, menu and fallback PCM comparisons. Integrated
strict mobile quick2 passed 125 checks and final desktop full passed205, both
after compile224. Full preflight reported no findings. Frozen source, explicit
paths and checkpoint identity use the `checkpoint31-` prefix under `build/qa/`,
including `checkpoint31-validation.json`. These are host-renderer/source
checks; no packaged-build or physical device performance claim is made.
