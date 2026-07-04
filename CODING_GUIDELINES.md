# Pre-Review Self-Check (Compressed)

> Language/framework-agnostic. Confirm every item before presenting code.

---

## §1 No Hardcoded Identifiers
- No hardcoded paths, URLs, resource IDs, or env-specific values in app code.
- Dynamic fetch failure → return error; never fall through to a stale constant.
- Required config/env vars → fail loudly when missing; never silently default.
  - **§1a Config-key safety**: Use safe lookup (`get`/`find` + null check) for env-dependent keys to avoid import-time crashes; give a clear skip-reason when missing.

## §2 Input Validation — Allowlist Over Blocklist
- Prefer allowlist (regex matching known-good format) over blocklist. Blocklists are fragile.
- Known-format identifiers (hex UUID, ISO date, slug) → strict `fullmatch` regex; reject non-matches.
- Validate **all** user-controlled params feeding path/query construction, not just the obvious one. The unvalidated param is the attack surface.
- Document expected format of each external input in signature/docstring.

## §3 Response Field Semantics
- Field names must unambiguously describe what is counted. `"total"` is ambiguous → use `"total_matching"`, `"page_size"`, `"total_unfiltered"`, etc.
- Document what each response field represents, especially pagination fields.
- When renaming a response field, update all consumers (tests, UI, docs).

## §4 Ownership of Mutable State
- Every shared mutable state piece has **one clear owner** for set/clear.
- If cleanup occurs in multiple paths (cancel AND completion), verify no conflict or double-fire.
- Guard mutations on shared refs so only the owning operation modifies:
  ```
  if shared_ref == this_instance:
      shared_ref = null
  ```

## §5 Stale State in Async/Deferred Callbacks
- Values captured by deferred ops that can change before execution → re-check after async boundary.
- After async resolves, compare captured inputs to current state; discard if mismatched.
- Enumerate ALL inputs influencing the result; verify ALL still valid after the async gap.

## §6 Cleanup Blocks (finally/defer/destructors)
- Cleanup runs unconditionally, including after early returns. Verify side-effect correctness for EVERY exit path.
- Do NOT use unconditional cleanup for conditional logic; prefer explicit cleanup at each exit.
- Verify cleanup cannot conflict with concurrent operation state mutations.

## §7 String/URL/Path Construction
- Verify separators for all input shapes (empty, leading/trailing separator, none).
- Document when segments are intentionally unencoded; state assumed-safe characters.
- Values containing delimiters (`?`, `#`, `/`, spaces, shell metacharacters) → encode/validate at boundary.
- Shell interpolation → use proper escaping even for "trusted" sources.
- Prefix/suffix normalization must be **idempotent** (don't double-apply).
  - **§7a Empty-string edge-cases**: Constructed strings feeding APIs with non-empty constraints → handle empty case (reject with error or skip component).

## §8 Counts, Indices, Off-by-One
- Capture counts **before** filtering when displaying to users.
- Post-filter length ≠ pre-filter count.
- Verify boundaries: empty, single-element, exactly-at-limit.
- Rename-on-collision: (a) renamed value rechecked for collisions, (b) loop terminates. Prefer deterministic uniqueness (always suffix with index).
- Values crossing serialization boundaries (int→str→CLI→int) → verify lossless round-trip.
  - **§8a Negative/underflow index**: Slice/offset calculations → ensure non-negative (clamp to 0) unless negative is intentional.

## §9 Duplication
- After adding a definition, **search codebase** for existing ones with same name/purpose.
- Never define same identifier/block twice in one file.
- Copy-paste → verify original removed or copies intentionally different.
- Tests: verify every mock/patch/stub is exercised; every import is used.
  - **§9a Style inheritance**: Adopt the safer variant already present in the file; don't introduce less-safe variations.
  - **§9b Existing patterns ≠ excuse**: "Matches existing pattern" is NOT a pass. If your diff repeats a block, extract a shared constant/helper/component AND fold pre-existing copies into that single source of truth. If truly out of scope, leave `# TODO:` and note in review summary.
  - **§9c Destructuring consistency**: In a block destructuring fields, access ALL fields via destructured vars — never mix destructured + direct property access on the same object in the same scope.

## §10 Null/None/Undefined Safety
- Guard null in one expression → apply same guard everywhere that var is used in scope.
- Extract guarded value to local and reuse: `items = value ?? []; filtered = items.filter(pred)`
- Empty collection → verify downstream handles explicitly; no silent no-ops.

## §11 Cache/Lookup Integrity
- Hash keys can collide → store original key material alongside cached data; verify on read.
- Document invalidation strategy and owner.
- Cached values must not mask upstream changes the caller needs.

## §12 Error Handling
- Catch narrowest exception type possible. Never swallow all errors silently.
- Preserve original cause when wrapping.
- Swallowed non-critical errors must not mask critical-path failures.

## §13 Concurrency & Race Conditions
- Every shared mutable variable → enumerate all writers; can two run simultaneously?
- Check-then-act → verify flag can't change between check and act.
- After acquiring resource → verify released on ALL exit paths.

## §14 API Contracts & Boundary Assumptions
- Handle upstream data shape mismatches (missing fields, null, wrong type).
- Return type change → verify ALL callers handle new shape.
- Multiple mode flags → verify mutual exclusion; add explicit conflict check.
  - **§14a External library callbacks**: Don't assume single event shape. Enumerate ALL values the callback can emit; handle or explicitly discard each. Silent ignoring → invisible failures.
  - **§14b Backend capability constraints**: Verify data types/options per backend before applying uniformly. Option valid for one backend may be illegal on another. Branch config by backend.
  - **§14c Remote access side-effects**: Enabling remote fetches → document security/deployment implications; specify which external hostnames must be whitelisted in network policy/CSP. Missing entry silently blocks fetches.

## §15 Early Filtering — Skip Expensive Work
- Before a loop with expensive body → how many iterations needed vs happening?
- Filter/short-circuit BEFORE the expensive operation, not after.
- N inputs → ≪N outputs → move disqualifying check above the costly step.

## §16 Function Independence
- Each function → verify no dependency on external mutable state or call-ordering side-effects.
- Adding condition to existing function → revisit every test; tighten isolation.
- New function alongside similar ones → explicitly diff for structural parity.
  - **§16a Dead guards**: After refactoring so caller enforces an invariant, remove guards inside callee that relied on the old weaker invariant.

## §17 Test Robustness — Decouple from External Data
- Never hardcode expected counts/names/IDs from live config. Load config at test time; compute expected values dynamically.
- Test asserting specific entry → derive expectation from config, not string literal.
- Count assertion → trace source. If from externally-modified file, compute from file contents.
- Prefer test-controlled fixtures over shared production configs; when using shared configs, derive from their contents.

## §18 Resource Management
- Every exit path (normal, timeout, exception) → same acquire → use → release.
- Code acquiring resources → enumerate all exit paths; verify each releases.
- Asymmetry (one function has cleanup, similar one doesn't) → likely a bug.

## §19 Comments & Documentation
- Brevity preferred; verbosity actively discouraged.
- Comment the *why*, not the *what*. If comment explains what code does, rewrite the code.
- Never reference internal guideline numbers or design docs in code comments.
- Narrating mechanism ("this checks X then does Y") → noise. Simplify or name descriptively.

## §20 Name Collision in Generated Artifacts
- After char-replacement normalization (`.`→`_`, `/`→`_`) → verify distinct inputs can't collapse to same output.
- Incorporate unique discriminator (index) as tie-breaker when collision possible.
- Track generated names in a set; assert uniqueness. Silent overwrites > loud collision error.

## §21 Auth & User Identity in Concurrent Contexts
- Use **request-scoped/context-local** identity — never process-global/module-level.
- Trace where "current user" comes from; verify no contamination by concurrent ops.
- Identity lookup → null/anonymous → handle explicitly; don't produce empty filter returning everything.

## §22 Cache Invalidation Completeness
- Every write path (create, update, **delete**) → verify cache invalidated.
- Multiple mutation code paths → each must invalidate or delegate to shared write function.
- Cache entry references deleted resource → invalidate stale entry; fall back gracefully.
- Long-lived process caches → document invalidation strategy; "populated once at startup" only if data truly immutable for process lifetime.

## §23 Access-Control — Default Deny
- Unfiltered listing → still enforce access control. Never return all records because no filter supplied.
- Trace every filter-param combination; verify private resources only visible to authorized callers in **each** combo.
- Scoping filter without required qualifier → restrict to caller's own scope.
- Document and test "no params" case explicitly — highest-risk for data leakage.

## §24 Single Source of Truth for Shared Logic
- Same transformation in two modules → extract to shared utility; both import it.
- "Applies same rules as X" in a comment → signal to import X.
- After extracting shared logic → remove unused imports from original locations.
- Canonical logic on a class but needed outside → extract to standalone function in shared module; class delegates to it.

## §25 Synchronous vs Asynchronous State — Guard Timing
- Guard checked inside callback/event handler → could callback fire before async update propagates?
- Flag must be readable synchronously → write it in **same call** as async state update:
  ```
  function setStatus(next):
      statusFlag = next      // sync — visible immediately
      asyncStateUpdate(next) // async — triggers downstream
  ```
- Never rely on side-effect observers (`watch`/`effect`/`subscribe`) to keep sync flag in sync — always ≥1 scheduling cycle of lag = race window.
- Teardown + replacement → set guard flag to "not ready" **before** releasing old resource reference.

## §26 Message-Passing Channel Lifecycle (Workers, Subprocesses, Queues)
- **One channel, one job.** Channel always recreated per config → remove dead in-channel "same config" guards.
- **Discard superseded responses.** Old channel may deliver queued messages after teardown:
  ```
  onMessage(msg):
      if activeChannel != thisChannel: return  // superseded
  ```
- **Use cancellation flag over identity guard.** Cleanup nulling `activeChannel` before `terminate()` breaks identity check. Fix: boolean `cancelled` flag scoped to channel closure, set `true` in cleanup, checked first in handler:
  ```
  cancelled = false
  onMessage(msg):
      if cancelled: return
  cleanup():
      cancelled = true       // before nulling ref
      activeChannel = null
      channel.terminate()
  ```
- **In-flight flags released on every path.** Channel killed mid-flight → reset busy flag unconditionally in teardown, not only on successful response.
- **Every handler branch sends a reply.** Including error and no-op paths. Silent returns leave caller permanently blocked.

## §27 Recursive vs Shallow Listing
- One level of children needed → use non-recursive listing. `recursive=True` when only one level exists → silently wrong if sub-objects added later.
- Full-path returns → verify extracting correct path component (immediate child, not deeper descendant).
- `recursive=False` returns nothing but `recursive=True` does → objects nested deeper than expected; investigate layout.

## §28 N+1 Query Patterns — Batch Where Possible
- Per-item metadata requiring separate round-trip per item → find batch/bulk alternative.
- Symptoms: loop calling `get_count(item)` per item; one SELECT per parent row.
- Fix: single query returning all items with counts (`GROUP BY`, single recursive `ls`, `walk` with projection).
- No batch API → document as known limitation; add `# TODO: batch`.

## §29 Exploit Source Ordering — Avoid Full Scans for Extrema
- Data source already ordered (dates reverse-chrono, IDs monotonic) → answer in first/last bucket; don't scan all.
- Full scan unavoidable → limit to smallest scope (first/last partition).
- "Latest by timestamp" + date-partitioned most-recent-first → scan only first date's partition.

## §30 Boundary-Aware Scans — Partition Keys vs Sort Keys
- Record near partition boundary (23:55 day N, stored under day N) may have sort-key exceeding all values in adjacent partition → scan **both** adjacent partitions.
- Limiting to "top N partitions" → document boundary assumption; choose N for worst-case overlap (typically N=2 for date partitions spanning midnight).

## §31 Filter Push-Down — Skip Partitions When Filters Allow
- Filter value identifies single partition (e.g. `date_filter="2024-01-15"`, data partitioned by date) → skip all other partitions; don't scan everything and discard post-hoc.
- Applies to any hierarchical/partitioned store: date dirs, tenant prefixes, shard keys.

## §32 Connection/Resource Reuse Within Request
- Verify whether resource re-acquisition is cheap (cached, same instance) or expensive (new TCP connection).
- Even when cheap, avoid redundant re-acquisition in same scope when already holding reference — obscures data flow; breaks if caching changes.
- Prefer passing already-acquired resource into helpers over each helper independently acquiring.

## §33 Hard-Coded Structural Indices — Derive from Schema
- Never hardcode positional index based on specific known prefix. Root path change → silently extracts wrong component.
- Derive dynamically: `root_depth = len(PurePosixPath(ROOT).parts)` then `parts[root_depth]`.
- Assert expected depth as guard; don't silently return wrong results on structural mismatch.

## §34 Spawner/Job-Graph Consistency
- New job in spawner/job-graph → compare config against all analogous existing jobs. Field present in others but absent from new job → likely oversight.
- Intentional omission → add comment explaining why.

## §35 No Blocking Calls in Bounded Thread/Worker Pools
- Never use blocking sleeps (`time.sleep`, `Thread.sleep`) in bounded-concurrency contexts. Blocked workers → pool starvation → cascade latency.
- Retry needed → (a) non-blocking alternative (`asyncio.sleep`, event-loop timers), or (b) remove retry; let caller handle.
- Retry constants → document execution context. Bounded pool → warn that increasing retries reduces throughput.
- Audit hidden blocking: DNS, sync HTTP without timeouts, file locks, subprocess waits. Ensure short timeouts relative to pool capacity.
- Prefer "fail fast, let caller decide" over "retry silently inside helper."

## §36 Client/Server Call-Contract Parity
- **Match HTTP method.** Open server handler; confirm verb (`get`/`post`/`put`). `post_json()` against `get()` handler → `405`.
- **Match parameter names exactly.** Keys client sends must be exact names handler reads. Renamed/abbreviated key silently dropped.
- **Match required parameters.** Handler requires field → client must require it too.
- **Match GET vs body placement.** GET → query string; POST/PUT → JSON body. Wrong placement → values never arrive.
- **Missing verb helper → add it.** Don't force wrong verb through existing helper.

### Audit ALL call sites once a contract bug is found
- One mismatch found → enumerate every other call site using same client helper; cross-check each against server handler (verb + param names + required fields).
- Build map: per call `(method, endpoint, params sent)` vs handler `(method, params read, required)`. Diff row by row.
- Newly-required param added to client signature → grep all callers (including bundled frontend outside repo); flag uninspectable callers for manual verification.

## §37 Blocking I/O in Tornado Async Handlers — Always Use run_in_executor

In Tornado/asyncio, `async def get/post/put/delete` runs on single-threaded event loop. Any blocking call blocks the entire process.

**Blocking in our stack:** `gromit.ns.*`, `gromit.ns.db.readobj`/`ls`, `container.read_content()` (S3/boto3), any helper calling these.

**Rule:** Extract blocking work into `@staticmethod` (no `self`); dispatch via `run_in_executor`:
```python
# ✗ blocks event loop
async def get(self) -> None:
    data = self._fetch_from_db(path)

# ✓ correct
async def get(self) -> None:
    data = await asyncio.get_running_loop().run_in_executor(
        None, lambda: self._fetch_from_db(path)
    )

@staticmethod
def _fetch_from_db(path: str) -> dict:
    return gromit.ns.db.readobj(path)
```

**`@staticmethod` prevents** accidentally capturing non-thread-safe `self` (Tornado handler) in thread-pool worker.

**Thread-safe module caches:** Guard check-and-set with `threading.Lock`:
```python
import threading
_cache: set[str] | None = None
_cache_lock = threading.Lock()

def _get_cache() -> set[str]:
    global _cache
    with _cache_lock:
        if _cache is None:
            _cache = set(gromit.ns.db.ls(FOLDER))
        return _cache

def invalidate_cache() -> None:
    global _cache
    with _cache_lock:
        _cache = None
```

Checklist:
- Every async handler calling gromit/S3/blocking helper → `run_in_executor`.
- Blocking logic in `@staticmethod` — never inline gromit in coroutine body.
- Module-level `None`-init cache written by executor threads → guarded by `threading.Lock`.
- `invalidate_cache()` also holds lock when clearing.

---

# Per-File Audit Checklist

For every file modified:

1. **Re-read diff** — anything defined twice? Unused imports? Leftover debug? Dead mocks?
2. **Shared mutable writes** — who else writes? Two writers simultaneous?
3. **Async/deferred ops** — what can change while pending? All verified after resolution?
4. **Path/URL/query from variables** — substitute edge cases (empty, no prefix, special chars, shell metacharacters).
5. **User-facing counts** — captured before or after filtering?
6. **Cleanup blocks** — list ALL paths reaching it; correct for every one?
7. **Caught errors** — too broad? Silently hiding failure?
8. **Loops** — how many iterations produce output? Skip rest earlier?
9. **Multiple mode flags** — what if >1 supplied? Explicit mutual-exclusion check?
10. **Rename-on-collision/dedup loops** — renamed value rechecked? Loop can't run forever?
11. **Listing/query endpoints** — unauthenticated/no-filter call returns what? Data leakage?
12. **Cache reads** — cached key references deleted resource? Stale case handled?
13. **Duplicated logic** — canonical version exists? Use it. Pre-existing copies → fold into single source of truth.
14. **Guard flags in callbacks** — updated sync or async? Callback fires in lag window?
15. **Message-passing channels** — dead guards assuming caller-enforced invariants? Every handler branch sends reply? `cancelled` flag (not just identity check) guards post-cleanup messages?
16. **Third-party callbacks** — all event shapes enumerated from docs/source, not just happy path?
17. **Config applied uniformly across backends** — every backend supports that value? Branch where support differs.
18. **Remote access enabled** — whitelisted hostnames documented in network policy/CSP? Missing entry silently fails?
19. **Object destructuring + property access** — every field via destructured var, no mixed access?
20. **Recursive/hierarchical listing** — recursion depth matches data model? Immediate children → non-recursive.
21. **O(N) scan for single best result** — source already ordered? Limit to first bucket.
22. **Per-item count endpoint** — single batch query possible instead of one-per-item loop?
23. **User input in path/query** — allowlist validated? ALL params, not just obvious one?
24. **API response field names** — unambiguous? Could consumer misinterpret?
25. **Sleep/blocking delay** — runs in bounded pool? Non-blocking alternative or document pool-starvation risk.
26. **Client→server calls** — verb matches handler? Param names exact? Required params supplied? GET→query string, POST→body?
27. **One contract mismatch found** → audit ALL sibling call sites. Newly-required param → grep all callers; flag uninspectable ones.
