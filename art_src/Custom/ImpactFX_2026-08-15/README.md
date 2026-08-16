# Ability-impact FX masters (2026-08-15)

Follow-on to the poison-mist fix: a shot_kit survey of every class (keep
terrain, base + themes) showed the same "simplistic" pattern behind the
biggest impacts — `_ring_fx` thin ring + `game.burst` square particles. The
two worst, both ult/theme signatures, got generated strips:

| subdir | master | strip | cells | role |
|---|---|---|---|---|
| `meteor/` | `meteor_master_4x2_v1(_keyed).png` 1536x1024 green key | `meteor_impact.png` 2048x256 | 8 x 256 | Meteor landing: flash → fireball dome + shockwave ring → plume → cracked scorch. Hue-shifted per mage theme (ice lands blue). |
| `earthslam/` | `earthslam_master_4x2_v1(_keyed).png` | `earth_slam.png` 2048x256 | 8 x 256 | Earth warrior: Shield Bash end-slam + Berserk seismic roar — cracks, heaved slabs, rock chunks, dust ring, rubble. |

Both are ground-radial bursts with a rising plume, so they are cut with
`--valign widest`: each frame's WIDEST row (the ground ring's equator = the
impact centre) is anchored on one shared row and the builder prints the
sprite offset that puts that row on the spawn position (meteor −33, earth −9;
`METEOR_IMPACT_OFFSET` / `EARTH_SLAM_OFFSET` in player_combat.gd).

Green-key spill: semi-transparent dust/smoke over the key came back
yellow-green; `--despill green` remaps low-blue yellow-greens toward tan
(G ≤ 0.84 R, B ≥ 0.5 R). Judge on `*_qa.png` (dark + grey backdrops).

Reproduce:

```
python tools/art/build_fx_strip.py art_src/Custom/ImpactFX_2026-08-15/meteor/meteor_master_4x2_v1_keyed.png       <out>/meteor_impact.png --cols 4 --rows 2 --cell 256 --fill 0.85 --despill green --valign widest
python tools/art/build_fx_strip.py art_src/Custom/ImpactFX_2026-08-15/earthslam/earthslam_master_4x2_v1_keyed.png <out>/earth_slam.png    --cols 4 --rows 2 --cell 256 --fill 0.85 --despill green --valign widest
```

Runtime: `player_combat.gd` `_meteor_impact_fx` (called from
`player_kit_mage._meteor_at`'s landing) and `_earth_slam_fx` (warrior a2
`end_slam`, ult `awaken_slam`). Verified with `game/shot_fx_series.tscn
--class=mage [--theme=ice]` and `--class=warrior --theme=earth` (muted rig).

Survey findings NOT fixed (ring + squares, lower stakes): paladin Aegis ring,
warlock Dark Pact ring, archer Arrow Storm's green ring, warrior Whirlwind's
big ring, base Berserk's red flash + red squares. Same recipe applies.
