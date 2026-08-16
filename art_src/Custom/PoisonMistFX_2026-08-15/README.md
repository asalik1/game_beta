# Poison mist FX masters (2026-08-15)

Owner complaint: the assassin's poison-theme "leftover circle" (the lingering
mist after Shadow Dash's Toxic Wake / Venom Bloom) and the "impact circle when
the knife throw connects" looked simplistic — the old `_mist` was six glow
blobs, square CPUParticles motes and a thin `_ring_fx` arrival ring.

Three ImageGen masters generated headless via Codex (`tools/art/run_codex_batch.ps1`,
one `codex_brief.txt` + `refs/` per subdir; each ran ~4 min):

| subdir | master | strip | cells | role |
|---|---|---|---|---|
| `cloud/` | `cloud_master_4x2_v1(_keyed).png` 1536x1024 magenta key | `poison_cloud.png` 2048x256 | 8 x 256 | looping toxic-gas mound (ping-pong loop in code) |
| `splash/` | `splash_master_4x2_v1(_keyed).png` | `poison_splash.png` 1536x192 | 8 x 192 | one-shot venom splat on arrival (the impact) |
| `pool/` | `pool_master_2x2_v1(_keyed).png` 1254x1254 | `poison_pool.png` 768x192 | 4 x 192 | bubbling venom puddle under the gas; outlives it as the stain |

The cloud's FIRST render came back on a green gradient (the model ignored the
magenta key); Codex self-corrected with one targeted background edit — the
kept `cloud_master_4x2_v1.png` is the corrected one.

Reproduce (from repo root; the strips here are the installed ones):

```
python tools/art/build_fx_strip.py art_src/Custom/PoisonMistFX_2026-08-15/cloud/cloud_master_4x2_v1_keyed.png  <out>/poison_cloud.png  --cols 4 --rows 2 --cell 256 --fill 0.75 --despill magenta --valign bottom
python tools/art/build_fx_strip.py art_src/Custom/PoisonMistFX_2026-08-15/splash/splash_master_4x2_v1_keyed.png <out>/poison_splash.png --cols 4 --rows 2 --cell 192 --fill 0.80 --despill magenta
python tools/art/build_fx_strip.py art_src/Custom/PoisonMistFX_2026-08-15/pool/pool_master_2x2_v1_keyed.png    <out>/poison_pool.png   --cols 2 --rows 2 --cell 192 --fill 0.80 --despill magenta --valign widest
```

`--fill` values are what `player_combat.gd`'s `_mist` assumes when it turns the
tick radius into sprite scale (cloud 0.75, splash/pool 0.80) — change both or
the art stops spanning the real reach.

Pool re-cut 2026-08-15 (hazard pass): `--valign widest` so the puddle's equator (row 112 → `MIST_POOL_OFFSET` −16) is the origin — the same strip now draws the bog/spore `poison` floor hazards (`game_world.HAZARD_STRIP`).

Runtime: `player_combat.gd` `_mist` (three cloud layers: body + second puff
UNDER the actors, thin veil over them; splash + round droplets on arrival; pool
at z −6 that dries out last; round glow-disc motes). Gameplay ticks untouched.
Verified with `game/shot_fx_series.tscn --class=assassin` (muted rig).
