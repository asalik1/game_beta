# Pre-Review Self-Check (Compressed)

> Language/framework-agnostic. Confirm every item before presenting code.

## §1 No Hardcoded Identifiers
No hardcoded paths/URLs/resource IDs/env values in app code. Dynamic fetch failure → error, never a stale constant. Required config/env → fail loudly, never silently default. **§1a**: safe lookup (`get` + null check) for env-dependent keys; clear skip-reason when missing.

## §2 Input Validation — Allowlist Over Blocklist
Allowlist (strict `fullmatch` regex for known formats: hex UUID, ISO date, slug) over fragile blocklists. Validate ALL user-controlled params feeding path/query construction — the unvalidated one is the attack surface. Document expected formats in signatures.

## §3 Response Field Semantics
Field names must say what is counted (`total_matching`, `page_size`, not `total`). Document pagination fields. Renaming a field → update all consumers (tests, UI, docs).

## §4 Ownership of Mutable State
One clear owner per shared mutable piece. Multiple cleanup paths (cancel AND completion) → verify no double-fire. Guard mutations: `if shared_ref == this_instance: shared_ref = null`.

## §5 Stale State in Async/Deferred Callbacks
Values captured by deferred ops can change before execution → re-check after the async boundary; discard on mismatch. Enumerate ALL inputs influencing the result; verify each still valid.

## §6 Cleanup Blocks (finally/defer/destructors)
Cleanup runs on EVERY exit path incl. early returns — verify side-effects for each. Don't use unconditional cleanup for conditional logic. Verify no conflict with concurrent mutations.

## §7 String/URL/Path Construction
Test separators for all shapes (empty, leading/trailing, none). Document intentionally-unencoded segments. Delimiters (`?#/` spaces, shell metachars) → encode/validate at the boundary; escape shell interpolation even from "trusted" sources. Prefix/suffix normalization must be idempotent. **§7a**: constructed strings feeding non-empty-constrained APIs → handle the empty case.

## §8 Counts, Indices, Off-by-One
Capture counts BEFORE filtering when shown to users. Verify boundaries: empty / single / at-limit. Rename-on-collision: recheck the renamed value, guarantee termination (prefer deterministic index suffix). Serialization round-trips (int→str→int) must be lossless. **§8a**: slice/offset math → clamp to 0 unless negative is intentional.

## §9 Duplication
After adding a definition, search for existing same-name/purpose ones. Never define an identifier twice in one file. Copy-paste → original removed or intentionally different. Tests: every mock exercised, every import used. **§9a**: adopt the file's safer existing variant. **§9b**: "matches existing pattern" is NOT a pass — extract shared helper AND fold pre-existing copies in (or leave `# TODO` + note). **§9c**: in a destructuring block, access ALL fields via destructured vars — never mixed.

## §10 Null/None/Undefined Safety
A null guard in one expression → same guard everywhere in scope; extract to a local (`items = value ?? []`). Empty collections → explicit downstream handling, no silent no-ops.

## §11 Cache/Lookup Integrity
Hash keys collide → store original key material with the value; verify on read. Document invalidation strategy + owner. Cached values must not mask upstream changes.

## §12 Error Handling
Catch the narrowest type; never swallow silently. Preserve cause when wrapping. Swallowed non-critical errors must not mask critical-path failures.

## §13 Concurrency & Race Conditions
Per shared mutable var: enumerate writers; can two run at once? Check-then-act → can the flag change between? Acquired resources released on ALL exit paths.

## §14 API Contracts & Boundary Assumptions
Handle upstream shape mismatches (missing/null/wrong type). Return-type changes → verify all callers. Multiple mode flags → explicit mutual-exclusion check. **§14a**: enumerate ALL callback event shapes; handle or explicitly discard each. **§14b**: verify options per backend; branch where support differs. **§14c**: remote fetches → document security implications + hostnames to whitelist.

## §15 Early Filtering
Filter/short-circuit BEFORE expensive loop bodies. N inputs → ≪N outputs → move the disqualifier above the costly step.

## §16 Function Independence
No hidden dependence on external mutable state or call order. New conditions → revisit tests. New function beside similar ones → diff for structural parity. **§16a**: after the caller enforces an invariant, delete the callee's dead guards.

## §17 Test Robustness
Never hardcode counts/names from live config — load config at test time and derive expectations. Trace count assertions to their source. Prefer test-controlled fixtures.

## §18 Resource Management
Every exit path (normal/timeout/exception): acquire → use → release. Asymmetry between similar functions (one cleans up, one doesn't) = likely bug.

## §19 Comments & Documentation
Brevity. Comment the WHY; if a comment explains what the code does, rewrite the code. Never reference guideline numbers/design docs in code comments. No mechanism narration.

## §20 Name Collision in Generated Artifacts
After char-replacement normalization, distinct inputs must not collapse to one output — add an index tie-breaker. Track generated names in a set; loud collision error over silent overwrite.

## §21 Auth & Identity in Concurrent Contexts
Request-scoped identity only, never process-global. Trace "current user" provenance. Null/anonymous → handle explicitly; never an empty filter that returns everything.

## §22 Cache Invalidation Completeness
Every write path (create/update/DELETE) invalidates or delegates to a shared writer. Stale entries referencing deleted resources → invalidate + graceful fallback. "Populated once at startup" only for truly immutable data.

## §23 Access-Control — Default Deny
Unfiltered listings still enforce access control. Verify private-resource visibility for EVERY filter-param combination. Document and test the "no params" case — highest leak risk.

## §24 Single Source of Truth
Same transformation in two modules → extract shared utility. "Applies same rules as X" in a comment = import X instead. Remove unused imports after extraction. Canonical class logic needed elsewhere → standalone shared function; class delegates.

## §25 Sync vs Async State — Guard Timing
Guards read in callbacks: could the callback fire before the async update lands? Sync-readable flags are written in the SAME call as the async update, never via watch/effect observers (≥1 cycle lag = race). Teardown+replace → set "not ready" BEFORE releasing the old reference.

## §26 Message-Passing Channel Lifecycle
One channel, one job (recreate per config; delete dead in-channel "same config" guards). Discard superseded responses (`if activeChannel != thisChannel: return`). Prefer a `cancelled` flag scoped to the channel closure over identity checks (cleanup nulls the ref before terminate): set it first in cleanup, check it first in handlers. In-flight/busy flags reset unconditionally in teardown. EVERY handler branch sends a reply — silent returns block the caller forever.

## §27 Recursive vs Shallow Listing
One level needed → non-recursive. Full-path returns → extract the right component (immediate child). `recursive=False` empty but `True` populated → data nested deeper than assumed; investigate.

## §28 N+1 Queries — Batch
Per-item round-trips in a loop → find the batch alternative (GROUP BY, single recursive ls, walk with projection). No batch API → document + `# TODO: batch`.

## §29 Exploit Source Ordering
Ordered sources (reverse-chrono, monotonic IDs) → answer from the first/last bucket, don't scan all. Unavoidable scans → smallest scope.

## §30 Boundary-Aware Partition Scans
Records near partition boundaries can out-sort the adjacent partition → scan BOTH neighbors (N=2 for date partitions spanning midnight). Document the boundary assumption.

## §31 Filter Push-Down
A filter identifying one partition → skip the rest; never scan-all-then-discard. Applies to date dirs, tenant prefixes, shard keys.

## §32 Resource Reuse Within Request
Know whether re-acquisition is cheap or a new connection. Either way, pass the already-acquired resource into helpers rather than re-acquiring in scope.

## §33 No Hard-Coded Structural Indices
Derive positions from schema (`root_depth = len(parts(ROOT))` then `parts[root_depth]`), assert expected depth; never a magic index tied to a known prefix.

## §34 Spawner/Job-Graph Consistency
New job → diff config against ALL analogous jobs; a field others have and yours lacks is likely an oversight (comment if intentional).

## §35 No Blocking Calls in Bounded Pools
No blocking sleeps in bounded-concurrency contexts (pool starvation → cascade latency). Retry → non-blocking primitives or push to caller. Audit hidden blocking (DNS, sync HTTP w/o timeout, file locks, subprocess waits). Prefer fail-fast.

## §36 Client/Server Call-Contract Parity
Match the handler's HTTP verb, exact parameter names, required params, and GET-query vs POST-body placement. Missing verb helper → add it, don't force the wrong one. **One mismatch found → audit ALL sibling call sites** (map verb/endpoint/params sent vs read/required, diff row by row); newly-required params → grep every caller, flag uninspectable ones.

## §37 Blocking I/O in Tornado Async Handlers
Single-threaded event loop: any blocking call (gromit.ns.*, db.readobj/ls, S3 read_content, helpers over them) blocks the process. Rule: blocking work in a `@staticmethod` (no `self` capture), dispatched via `await loop.run_in_executor(None, lambda: ...)`. Module caches written by executor threads → guard check-and-set AND invalidation with one `threading.Lock`. Checklist: every async handler touching blocking helpers uses the executor; no inline gromit in coroutine bodies.

## §38 GDScript / Godot Specifics (this project)
- **§38a Type inference**: `var x := obj.method()` on loosely-typed obj or Variant expressions (`Dictionary.get`) = parse error — annotate. One parse error breaks the whole chain and the headless suite hangs; run the compile gate (`test_quick.bat`) first, always.
- **§38b New scripts**: new `class_name` → `--import` before headless runs. Prefer path-based `extends "res://…"` for internal chain layers; `class_name` only for cross-file types.
- **§38c Inheritance-chain splits**: Game/Player/tests are `_base ← … ← final(class_name)` chains; code moves verbatim; calls flow derived→base; vars READ ACROSS LAYERS live in the base layer (private, layer-local caches may stay in their layer with a comment — e.g. game_flow's `_meta`). Unavoidable upward call → `call("method")` + comment naming the resolving layer (keep to a minimum; currently one: `set_flag`→`_recheck_gates`).
- **§38d Equality**: Dictionary/Array `==` is DEEP in Godot 4; `Array.has(dict)` matches twins — compare counts or `is_same()` for identity.
- **§38e Deferred/async**: re-check `is_instance_valid` INSIDE deferred callbacks. Timed-effect tests poll wall-clock (`await create_timer`), not frames.
- **§38f Knobs vs data**: tuning numbers → `balance.gd`; content tables stay in domain files; no bare tuning numbers in logic.
- **§38g Autotest**: snapshot + restore shared state, never `.clear()`. Content-module tests via the CONTENT-MODULE TEST HOOK. Seeded behavior → tests derive the expected branch from the same seed helper the game uses (e.g. `social_holds_elite`).
- **§38h Time & clocks**: never trust raw OS time for rewards/expiry — players roll the system clock. Use `game.trusted_now()` (persisted monotonic anchor; never decreases). Design timed features so a forward-rolled clock only hurts the roller.
- **§38i Comment idiom (overrides §19's design-doc clause)**: "playtest round N" references ARE this project's WHY convention — they anchor a tuning decision to its trigger. Keep them; still no §-number references in code.

## §39 UI / HUD / codex — player-facing views (this project)
The owner keeps flagging the SAME class of miss on new UI. Self-check these before shipping any player-facing view:
- **§39a Reference views show the FULL set, never a sample.** A codex/reference shelf enumerates EVERY entry (all 85 potions, every terrain, every relic) — a hand-picked "representative shelf" reads as missing content. For volume, add filter chips + grouping (family/lane/grade), don't truncate the data. (Curios shipped 10 of 85 draughts; that was the flag.)
- **§39b Every displayable entity carries its lore AND a wired icon.** A detail card shows the entity's flavor line, not just mechanical stats; a blank icon or stats-only card reads as a bug. Most flavor ALREADY EXISTS — `GearFlavor.of(item)` resolves potions/bags/gems/materials/uniques by name/band; terrains use `Terrains.TERRAIN_LORE`, NPCs `Story.NPC_LORE`. Surface existing flavor before authoring new copy, and pass it to `_open_detail_popover(icon, title, color, info, actions, flavor)`.
- **§39c World-placed content must be discoverable in the codex.** Anything the player SEES in-world (accents, landmarks, props, bags, items) belongs in the codex. Audit live placements vs codex registration, and NEVER leave live content `placeholder`-flagged — that hides it from the codex while the player still sees it in-world (garden_statue/fountain were the miss).
- **§39d Icon source resolution matches display size.** Never upscale small art into a bigger slot (32px art in a ~58px HUD slot reads blurry next to crisp neighbors). Install at/above the largest display size and downscale ONCE with LANCZOS/LINEAR — never a NEAREST downscale of hi-res (aliased), never force a small native size. `Art.consumable_icon` caps at `CONSUMABLE_ICON_MAX` (128) + LANCZOS; keep that seam.
- **§39e Framed UI shares one visual language.** Rounded `StyleBoxFlat` (corner radius + border + soft `shadow_size`) echoing the ability-medallion/chip look — NOT raw flat `ColorRect` squares. A blocky flat square next to polished elements is the recurring "looks off" flag. Recolor a stored stylebox per state (cf. `_set_ability_ring`), don't rebuild the widget.
- **§39f Player-facing items behave like items.** If the player can acquire it, it drops → picks up → sits in inventory → equips/swaps → sells, through the normal paths (`give_loot`, `_try_receive`, the Sell screen) — not an opaque system that auto-equips or auto-sells. (Bags auto-cashed spares; owner ruling: "auto sell shouldn't even be a thing.") Corollary: nearly everything should be sellable at a merchant — potions, consumables, bags — with intentional exceptions documented (gift potion, Grand potions).
- **§39g Reuse the codex/inventory scaffolding, don't fork it.** Codex = `SECTIONS` registry + `_chip_groups` filters + rows/detail; a new section is one SECTIONS row + a rows/detail builder. Drag-drop = `set_drag_forwarding(drag_fn, can_fn, drop_fn)` (gem→socket is the template; loose-bag→chip reused it verbatim). Inventory cells = `_bag_slot`; a mailed/dropped payload needs a matching `kind` case in `Pickup.drop_loot` + `_try_receive` + `mailbox` rendering (miss one and it renders as a generic glyph).

The 2026-08-15/16 UI pass (codex rework, stats sheet, ability variants, potion loadout, daily track) drew the SAME owner flags a dozen times. Treat these as failing lints, not taste:
- **§39h Idle whitespace is a defect.** A card whose right half is empty, a grid of near-blank 220×78 cards, a text list floating in a 620px panel — all flags. Fixes that worked: a LEDGER row (name expands, value flush right) instead of fixed left-heavy columns; a matrix of tight icon squares beside a detail pane instead of a card grid; a reference page as one 640–700px reading column; tiles for a 28-day track rather than 7 wide ones over a void. If a panel still has a void, fill it with content (legend, the base ability's text, the sheet), never with bigger paddings.
- **§39i Nothing touches an edge; columns end on one line.** Content inside a `ScrollContainer` gets a `MarginContainer` (`margin_right` ≥ 12) so cards clear the scrollbar; a card's last widget must not be pushed to its border (drop the widget or give the row `content_margin`); multi-column sheets get sections rebalanced by row count AND the last card in each column `SIZE_EXPAND_FILL` so bottoms align. Verify by measurement, not eye: shoot the screen and count bright pixels past the panel edge (the rig does this) — 0 or it isn't done.
- **§39j One encoding per state — no redundant markers.** If a frame/highlight/★ already says "assigned / primary / today", a ✓ or a caption saying the same thing is noise ("your class scales best here" beside ★; ✓ inside a highlighted card; 🛈 on every clickable row). State lives in the frame: thick + tinted = selected, pale = inspecting, dim = locked; the intro line explains the code once.
- **§39k Icons fill and centre their box.** A `Button` with an icon and empty text draws the icon LEFT — set `icon_alignment = CENTER` and `expand_icon`, and size the card TO the icon (72px square for 64px art), never a 44px icon adrift in a 120×62 card. Never a NEAREST downscale of hi-res art (§39d).
- **§39l Refusals and notices render INSIDE the panel.** A menu action must never explain itself with world `spawn_text` (it is behind the panel and reads as "nothing happened") — inline label, disabled control with a tooltip, or the state itself. (`_potion_msg`, `gem_socket_error` in-panel are the pattern.)
- **§39m Direct manipulation over a separate button; every target is a real target.** Where an object is on screen, acting on it IS the action: tap the day tile to claim, click a bottle to slot it, click a slot to free it — no "Claim" / "+ Slot" buttons beside a picture of the thing. Clickable rows are whole-row targets with hover feedback and a hand cursor; handle `InputEventScreenTouch` as well as the mouse (dedupe the emulated click by frame) so it is never PC-only.
- **§39n One shape per kind of content, one component per kind of number.** Collections = filter chips + ledger + detail (codex, uniques, potions); reference prose = a reading column, never in front of a catalogue; tools = tiles you click. A number the player reads in two places (inventory Stats vs Skills › Attributes) comes from ONE data source + ONE builder (`_stat_sheet_data` / `_stat_sheet_build`) so the two can't drift; polish and animation (the spent point pulses green) then land in both for free.
- **§39o Flexibility over rigid defaults.** A "helpful" default that the player cannot opt out of (a loadout slot forced to Health) reads as a trap. Default + explicit "empty" + assigned, each shown truthfully (a default that would pour nothing SAYS so), one click cycles them.
- **§39p Prove it with the muted rig before saying it's done.** Shoot the screen (`--audio-driver Dummy`, CLAUDE.md), read the shot at 1:1, drive the interaction in the rig (chip, search, row select, tile claim) and assert the state moved (`shot_gemcodex.gd` is the worked example) — then `test_quick`, then scoped `sync_mobile.py --paths`. A screen nobody has looked at is not shipped.

## §40 World props — art & animation (this project)
Owner ruling 2026-08-18 after a day of play-flags from `main` (a mushroom, a campfire, poison pools and a chain-rig "shift position"; a well and a shrine "keep dimming and brightening significantly"; a cactus, a fence, door torches and the mill "cartoonish"). None of it was caught because no rule said what a finished prop IS; the lanes judged contact sheets and measurable gates. Review every prop asset, strip, or scenery-placement change against these — they are failing lints, not taste:
- **§40a One style, judged beside siblings.** Every world prop matches the cast: painterly, soft-shaded, NO black outlines, muted palette, top-down three-quarter, light top-left. Resolution is not style — a 1024px cartoon is still a cartoon (cactus2, tree_teal2, grave_cross all passed the resolution audit). A regen brief names a painterly SIBLING as the style ref and the old asset only as the SUBJECT (silhouette, footprint, colour identity); if the subject is unreadable at 16px, describe it in words and drop the subject ref (clay_pot2 came back a shard, candelabra a cross). Judge on a contact sheet beside the siblings that will stand next to it in-world (`tools/art/asset_gallery.py` or a scratch sheet), never against the asset it replaces. Key green FIRST, then tone-match (-14% saturation, gamma 1.0), then `install_prop_hires` — the ImageGen masters run hot.
- **§40b Animate in place.** No frame translates the object. Rigid props (furnaces, wells, shrines, rigs, pools, statues) keep a byte-stable silhouette — colour-only motion (`derive_prop_anim.py` pulse/flicker/shimmer), bbox/baseline/centre drift 0. Only fire, cloth and foliage may change silhouette, and then anchored on frame 0's rigid band (logs, basin, rod — `audit_prop_anims.py` re-anchors and band-locks authored strips; a derived strip is re-derived, an authored one is NEVER regenerated from its static — that killed the campfire's fire once). Wind sway is an ALLOW-list of vegetation (`_wind_scenery`: trees, bush, grass, flower, cattail, reeds), never "everything that isn't a building". Hazard pools stay put (`Balance.HAZARD_POOLS_DRIFT`). Anything that swings or pendulums needs authored frames with real easing or NO animation — a 4-frame swing reads as fake (the magma chain-rig).
- **§40c Dim, don't strobe.** A prop looks STILL at a glance and alive on a second look. Luminance swing (max−min over max of the mean silhouette luminance across frames): glows and pulses ≤ 10-12% (`--amp 0.08-0.10`), open fire ≤ 25%, churning energy ≤ 18%, and never the whole sprite — bright/warm pixels only. The 0.35 default that reads "visible" on a contact sheet strobes in-game at 60 fps. Two braziers in one room must not breathe in unison (random phase).
- **§40d Gate every strip you touch, then WATCH it.** `tools/art/audit_prop_anims.py` (frames / canvas / outline drift of the rigid band / pulse) + `tools/art/verify_art.py <base>` (green rim, bleed, ghost chunks, rigid drift) must be clean; a NEW rigid animated prop joins autotest's `full_prop_anims` contract (frame == static canvas, baseline ≤ 1 px, centre ≤ 2 px). Metrics do not replace the loop: run it in a shot rig at 1× (`shot.bat polish --gif`) before calling it done — a subtle loop that looks static on a sheet is CORRECT; a strip that reads "alive" on a sheet is probably too strong.
- **§40e Placement is part of the asset.** A doorway prop must be visible from the room that owns it (door torches stepped `DOOR_TORCH_INSET` into the owning room after a north door showed only stems under the camera's play-rect limit); accents that would double in one room get `ACCENT_PROFILES` `max: 1`; a building drawn through the NPC hotspot path gets its footprint from `NPC_HEIGHT_BY_SPRITE` and a base shadow, not a person's disc.

---

# Per-File Audit Checklist
For every file modified:
1. Re-read diff — double definitions? unused imports? leftover debug? dead mocks?
2. Shared mutable writes — who else writes? simultaneous?
3. Async/deferred — what changes while pending? verified after?
4. Paths/URLs/queries from vars — edge cases (empty, no prefix, special/shell chars)?
5. User-facing counts — captured before filtering?
6. Cleanup blocks — correct for every path reaching them?
7. Caught errors — too broad? hiding failure?
8. Loops — filter earlier?
9. Multiple mode flags — mutual exclusion?
10. Rename/dedup loops — rechecked? terminates?
11. Listing endpoints — no-filter call leaks data?
12. Cache reads — stale/deleted-resource case handled?
13. Duplicated logic — use/fold into the canonical version.
14. Guard flags in callbacks — sync or lagging async?
15. Channels — dead guards? every branch replies? `cancelled` flag over identity?
16. Third-party callbacks — all event shapes enumerated?
17. Config across backends — every backend supports it?
18. Remote access — hostnames documented/whitelisted?
19. Destructuring — no mixed access.
20. Hierarchical listing — recursion depth matches the data model?
21. O(N) scan for one extremum — use source ordering.
22. Per-item count loop — batch query instead?
23. User input in path/query — allowlist-validated, ALL params?
24. Response field names — unambiguous?
25. Sleeps/blocking — bounded pool? non-blocking alternative?
26. Client→server — verb/params/placement match the handler?
27. One contract mismatch → audit all sibling call sites.
