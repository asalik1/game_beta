# Loot across worlds

A full pack can leave items at the hero's feet. Those positions belong to the
current world. Previously, guest autosaves wrote them directly into the home
character; a lost host could leave those items stranded in unrelated home
geometry. Joining a friend's world also loaded home drops without spawning
them or immediately sending the promised mail.

Character-only home saves now make a detached snapshot with a positionless
**Dropped Loot** letter. The live pickups and mailbox stay available in the
host world. Each autosave rebuilds the snapshot, so a later collection or
graceful mail flush removes the pending recovery instead of stacking it.
The home chapter, world flags, seed and saved location remain intact.

Applying a character to a different world immediately mails its saved ground
loot. Same-world saves continue to restore physical drops. Save fixups work on
a deep copy; they cannot change a reusable caller snapshot. Old local pickup
nodes are reserved before deferred deletion on restore or mail flush, preventing
a queued contact from collecting an already-mailed reward. Other worlds' nodes
are excluded. Two equal potions are still two independently earned items.

The Codex's Bags field notes describe the travel behavior. No save-version,
network protocol, loot roll or mailbox-expiry change is required.

Validation:

- `test_loot_travel.gd` uses an isolated player/world and restores all test save
  files and atomic-write sidecars on success and failure. It checks disk home
  preservation, every supported payload type, repeated autosaves, equal bottles,
  real claim callbacks, immediate join mail, detached input and local drops.
- `shot.bat loot_travel --timeout=200` runs the production host-loss callback
  with a full pack, returns to the home save, claims through the real mailbox,
  checks another reload, and captures immediate join mail and touch controls.
  This invokes the real disconnect handler; it does not simulate network loss
  over a live remote connection.

Final validation: desktop 182-script compile, 109 quick
checks and 189 full checks. Mobile editor import,
182-script compile and 109 quick checks. All
strict PASS without script errors. The desktop and mobile Compatibility live
rigs each passed six captures. Renderer checks ran on the development PC;
no Android/iOS device hardware was used. All seven source files match their
frozen hashes and mobile mirrors, with two independently generated UID pairs.
Source preflight has zero failures and 12 known structural-number warnings;
the engine Codex data gate passes. No art changed in this pass.
