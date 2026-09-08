# A sanctuary that remembers its hero

Rescued creatures now travel in a hero's character save. Previously, the
sanctuary read world flags: joining a friend could display the friend's rescues,
while a rescue made as a guest unlocked its cosmetic but did not update that
hero's home sanctuary history.

`rescued_pets` records this hero's six possible discoveries independently of
the account's cosmetic ownership. Joining restores the guest's own history;
guest autosaves bring new rescues home while preserving home geography. The
sanctuary, roaming residents and rescue sites all read the same personal record.
Equipped companions keep their existing animation and follower behavior.

Older saves lift missing rescue history from their own saved home-world flags.
An explicit empty history stays empty. A purchased pet or one rescued by another
hero remains an owned cosmetic, without inventing a rescue for this character.
Only authored ids survive loading, and each appears once. Legacy rescue flags
are reconciled locally so existing story readers remain accurate.

No save-version or network-protocol change is needed. The sanctuary page and
its Codex view explain the personal history and shared cosmetic ownership.

Validation: isolated disk migration/character tests and a live
loopback ENet world-snapshot test with conflicting host/guest rescue histories,
followed by a new guest rescue, home save/resume, sanctuary residents, follower,
repeat reload, touch UI and an old-format home save. Tests restore their save
fixtures and sidecars on success and failure. Remote devices are not implied
by loopback transport testing on the development PC.

Final validation: desktop 183-script compile, 110 quick
checks and 190 full checks. Mobile editor import,
183-script compile and 110 quick checks. All
strict PASS without script errors. Desktop and mobile Compatibility live rigs
each passed five captures and the real loopback ENet world-snapshot checks.
All nine source files match frozen hashes and mobile mirrors, with two
independently generated UID pairs. Source preflight has zero failures and
12 known structural-number warnings; the engine Codex data gate passes.
No art changed, and no Android/iOS hardware was used in this pass.
