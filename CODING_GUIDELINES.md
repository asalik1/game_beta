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
- **§38c Inheritance-chain splits**: Game/Player/tests are `_base ← … ← final(class_name)` chains; code moves verbatim; calls flow derived→base; ALL vars in the base layer. Unavoidable upward call → `call("method")` + comment naming the resolving layer (keep to a minimum; currently one: `set_flag`→`_recheck_gates`).
- **§38d Equality**: Dictionary/Array `==` is DEEP in Godot 4; `Array.has(dict)` matches twins — compare counts or `is_same()` for identity.
- **§38e Deferred/async**: re-check `is_instance_valid` INSIDE deferred callbacks. Timed-effect tests poll wall-clock (`await create_timer`), not frames.
- **§38f Knobs vs data**: tuning numbers → `balance.gd`; content tables stay in domain files; no bare tuning numbers in logic.
- **§38g Autotest**: snapshot + restore shared state, never `.clear()`. Content-module tests via the CONTENT-MODULE TEST HOOK. Seeded behavior → tests derive the expected branch from the same seed helper the game uses (e.g. `social_holds_elite`).

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
