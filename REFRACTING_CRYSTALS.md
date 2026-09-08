# Refracting crystals

Existing crystal clusters and spires in ordinary combat rooms now carry a
blue ring and four facet marks. A projectile that strikes one bends toward
the nearest visible opponent. Enemy shots seek heroes by the same rule, so a
missed bolt can become dangerous again. Solid cover blocks target selection.

The nearest crystal shows a short trajectory guide when approached. This uses
the game's existing automatic targeting rather than introducing a separate
mouse-only aiming mode. When no opponent is visible within the shot's remaining
range, a deterministic diagonal facet supplies the reflection direction.

The same projectile node continues flying. Damage, status effects, owner,
custom visual children, impact listeners, pierce history and homing are kept.
Banking does not fire a hit callback. Separation from the collider is deferred
until physics contacts finish and charged against the original lifetime.
Repeated contacts are reserved once; a shot can bank from at most two different
crystals. An exhausted bank budget falls back to the ordinary wall impact.

Visual-only network copies use the same terrain reaction and remain unable to
deal damage. No new flags, RPCs, currency, reward rolls or save fields. As with
existing projectile visuals, target motion and latency may produce small
cosmetic differences between peers. Boss arenas, PvP, weekly and endgame rooms
are excluded. The painted crystal art and scenery placement are unchanged.

`test_prism.gd` covers all fallback angles, finite guards, contact reservation,
identity/payload/history preservation, bank limits and original range.
`shot.bat prism --timeout=200` captures six live states and exercises a real
corner shot with its slow effect, solid-cover filtering, hostile damage,
cosmetic-copy isolation, pause, ordinary walls and the touch guide.
Logs: `build/qa/prism-*`; final suite results: `AUTONOMOUS_STATUS.md`.
