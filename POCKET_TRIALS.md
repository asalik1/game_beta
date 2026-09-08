# Pocket trials

Two portal arenas now have enforced rules: Molten Court warns alternating
hot floor halves, with a cold center seam. The hot stone also melts the
guardian's obsidian plates, so positioning opens its damage window; Still Larder seals potion use
before bottle, budget or fight-record consumption. Class healing works.

Painted entry/return stones survive revisits/reloads and appear on guests.
Victory leaves time to collect spoils; the exit also offers a free retreat.
An empty arena resets the guardian. The return point is saved as a finite
room-relative offset. Nearby floating coordinates avoid whole-pixel movement
quantization; old pocket hero/drop positions migrate when loaded.

Named guardians own completion separately from their reused campaign kit.
Host-owned trial clocks and participant rewards replicate; late joins receive
completion, origin and phase. NET_VERSION 0.3.10. Gold/gem/Renown amounts are unchanged. Optional
guardians now pay zero XP, following the fixed chapter/event-spawn doctrine.

Validated: desktop 179-script compile, 107 quick and
187 full checks; mobile editor import, 179-script compile
and 107 quick checks. All 21 scoped files match;
five new script UID pairs independently generated. Thirteen polished live captures
cover both portals, real entry/exit buttons, floor armor shedding, potion rules,
pause, save/reload, retreat/reset, exact return, no forced victory teleport,
completed reentry and touch. Real two-peer ENet verifies clock/settlement authority,
late lazy builds, bad-state rejection and participant rewards once.

Visual QA corrected rectangular portal-strip slicing and restored the named
guardians' painted HUD portraits. Source preflight: zero failures, eleven warnings
(existing structural/moved values plus a phase enum comparison); no new art. Explicit paths staged, no commits.
Unopened chest persistence remains a separate existing gap found during this audit
and is the next active pass. Logs/screenshots: build/qa/pocket-*.
