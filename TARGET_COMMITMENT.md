# Keeping the committed target while retreating

Retreating into empty space keeps the current soft target. A deliberate switch
selects an enemy on the side the player steers toward; a closer enemy behind
the hero no longer qualifies through the initial-acquisition fallback.
Initial acquisition still permits its existing fallback. Target priorities,
keep range and hard-lock override retain their current rules.

The source change adds the direction check at the deliberate-switch seam. The
synchronous domain regression covers both retreat directions, same-side
commitment, deliberate switching, initial fallback, an overhead enemy,
hard-lock precedence and invalid-target recovery.

The native probe uses `shot.bat framing --soft-target --timeout=180` with fresh
isolated APPDATA. It poses a quiet Village Outskirts corridor, retires original
enemies without kill/reward credit, delays hazards and freezes factory enemy
AI. Their actual minimum levels are recorded. Walls, props, collision, local
player physics and real A/D input remain active. The helper never assigns a
target reference. Six original frames per probe show acquisition, retreat and
deliberate switching in both directions. Baseline permits exactly the two
mirrored retreat findings; strict runs permit none.

The rejected first baseline remains intact: both retreat movement checks and
one deliberate-switch movement check lacked the required render samples. It
already reproduced the target findings, but that did not make its fixture
valid. Version three samples physics-frame boundaries, retaining the minimum
sample and travel checks, rather than relaxing them. Those samples observe the
preceding completed step and do not prove every collision/contact instant.
Native screenshots remain ordinary rendered captures.

Desktop quick 147/full 227 and mobile quick 147 passed; exact five-source mobile sync, compile, strict preflight, default framing/controller and one-engine paired ENet regression passed. The accepted baseline has 37 rows with exactly two retreat findings; strict desktop/mobile probes have 35/35 rows, zero findings/failures and six originals each. All 44 baseline/final originals were independently inspected. UIDs are pinned per project, not equalized.

The desktop default framing and controller routes are separate regressions.
Host mobile uses Compatibility rendering and touch HUD, with A/D still driving
movement; this is not a touch-gesture or physical-device claim. Existing paired
ENet runs in one engine and checks its own controlled transport/authority
contract. It does not prove retreat targeting with natural moving enemies in
remote multiplayer, admission behavior or network latency.

Native logs retain the renderer shutdown diagnostics already permitted by the
established screenshot verdict. This is not an error-free teardown claim; the
verdict rules were not changed. Controlled NPC and board placement also remains
visible in the image reviews, separate from the target behavior being accepted.

One Archer hunt attempt cleared its natural-AI elite quarry in 21.288 seconds using synthetic keyboard movement/kit inputs after controlled sign/hero placement. Boot and combat-start L1 stats matched (100 HP,40 MP,11.66 attack,265 speed), with no equipped items or god mode. Sampled HP and ending HP stayed100; the hunt paid120 gold. All four originals were independently reviewed. This single-quarry episode is ordinary combat after setup, not a multi-target identity test, full exploration journey, physical-device or network validation.

The ordinary run remains separate from the posed/frozen native fixture. A
defeat or partial outcome is retained honestly, without retrying until a win or
turning fixture setup into an earned-clear claim.

Claude Code authored the initial production and domain proposal. Codex reviewed
the narrow condition, strengthened domain controls and authored/reviewed the
native probe and validation. Raw Claude output, earlier native candidates and
the failed baseline remain under
`build/qa/session-sept17/claude-combat-input-candidate/`.

The checkpoint owns five game sources, their five mobile mirrors, the two new
helpers' four project-specific UID files and three documentation paths. Mobile
sync excludes UID copying; each UID is pinned independently. Final sources,
validation, original-image reviews, ordinary outcome, rejected evidence and
commit are bound in `build/qa/session-sept17/target-checkpoint-validation.json`.
