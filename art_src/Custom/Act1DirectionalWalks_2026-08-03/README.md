# Act 1 directional walk repair (2026-08-03)

> Superseded for final gait timing by
> `Act1DirectionalWalkCycles_2026-08-03/README.md`.  These compound masters are
> retained as the direction/identity source, not accepted as proof of foot
> alternation by themselves.

Built with Codex's built-in image tool from the committed
`MobRedesign_2026-07-25` identity masters (plus the live spider art).

Each `*_directional_walk_master.png` contains five authored facings in rows
`S, SW, W, NW, N`, with four locomotion phases per row. The production builder
mirrors the western rows for `SE, E, NE`, removes the green screen, segments
the actual alpha bands (not assumed gutters), preserves each mob's live body
scale and ground line, and writes square 256px directional strips.

`royal_knight_north_walk_override.png` replaces the rejected north row from
the otherwise accepted 5x4 sheet. The rejected edit remains only in the
generator's external history and is not a project asset.

Rebuild all reviewed walks with:

```powershell
python tools/art/build_act1_directional_walks.py
```

Or rebuild selected keys with `--keys spider skeleton ...`.

Floating (`banshee`), rooted (`fungus_long`), quadruped (`stone_base`), and
multi-legged (`spider`) bodies use anatomy-specific locomotion rather than a
forced humanoid foot cycle. Runtime selection is movement-only: flat legacy
idles remain in place, while `enemy.gd` selects these directional strips once
the mob moves.
