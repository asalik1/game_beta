# Complete prompts around bodies and HUD panels

Selected factory interaction prompts can use clear space above, beside or below
their owner and the local hero. The previous rule considered one position above
both bodies; a blocked upper position sent the complete label back onto its
authored anchor, where it could cover the hero. Scenery prompts such as the
whispering chest did not participate in that rule at all.

The shared factory now records an authored anchor for ordinary scenery as well
as citizens. The selected-label pre-draw pass first tries that exact anchor,
then the upper, right, left and lower positions. If all five are obstructed, it
tries nearby vertical positions along the two side lanes, ordered by distance
from the authored position. These positions come from HUD/body rectangle edges
and viewport bounds; the game does not scan image pixels or move actors. A
candidate must fit the viewport and clear the declared HUD and body bounds.

When no candidate fits, the complete prompt stays at its authored anchor. It is
never truncated, resized or faded to make the check pass. Overlay, incapacitated
hero and stale-world guards remain in place. Reach, nearest-entry selection,
callbacks, input, combat, camera and world geometry retain their own behavior.
Marked landmarks retain their specialized placement. Victory arches remove the
generic anchor from their hidden book hotspots so the actual arch's lifted
label remains authoritative, including after key remapping.

## Limits of the presentation rule

NPC/prop bounds are conservative sprite cells; the hero uses the existing HUD
body proxy. Full prompt bounds include its pill and shaped text. The declared
HUD list includes the vitals/info/minimap, quest/party and target family, but
does not exhaustively include bottom abilities, touch controls or transient
reward text. The solver does not inspect pixel occlusion from foliage or other
world objects. The bounded side lanes can miss available space elsewhere, and
changes between candidates can snap as the body or HUD moves. No-fit overlap is
still possible. Native visual review remains necessary; this is not universal
world/HUD clearance or a proof for every actor pose.

## Native checks and their scope

All routes use the existing compile-gated, muted `shot.bat` runner and separate
fresh profiles. Capital routes require `capital-arrival-native-candidate` in
the profile path. Shortcut routes require
`build/qa/session-sept20/claude-shortcuts`. Add host mobile
`--mobile --renderer=gl_compatibility` separately; these are Windows renders,
not physical-device tests.

```powershell
shot.bat capital_arrival --npc-prompt --npc-prompt-alternatives --timeout=300
shot.bat shortcuts --corridor-camera --corridor-hot --arrival-readability --world-prompt-probe --timeout=300
shot.bat controller --victory-arch-prompt --generic-prop-prompt --timeout=300
```

The NPC route follows actual solo Pause travel and keyboard movement to the
original Clerk Voss. Inventory/Escape and E/Leave use real input. Independent
painted hero/NPC bounds and complete text geometry establish the observed
placement. Optional alternatives borrow the vitals-panel position and camera
offset to block the old upper lane. A separate oversized-label loan makes a
fit impossible and requires complete authored fallback, followed by restoration.
That deliberately unreadable image is supplemental fallback evidence, not an
accepted player-facing layout. The dialogue portrait hides the world, so held
prompt coordinates under dialogue do not establish visible-world readability.
The old `--npc-prompt-controls` retains its historical above-only fallback
contract; it is not the alternatives acceptance route.

The chest route extends the existing controlled hot-S corridor journey. The
source room clearance, starting pose and terrain timer are fixture loans; the
destination is originally unbuilt/unvisited/uncleared, with live spawning, AI
and a vulnerable hero. At settled arrival, the probe requires the actual nearest
selected original whispering chest, immutable authored copy, current world
ownership and the unexpired ordinary offer Timer. No respawn, reroll or lifespan
extension is used. Missing or expired chest evidence is incomplete and fails.
The complete prompt is checked against independently measured painted bodies,
the viewport and declared HUD rectangles. One current interaction-key edge
opens the actual confirmation; native mouse input activates its actual Cancel
button. Full economic/curse snapshots and entry/reach/Callable/style identity
remain unchanged. Health is excluded because the encounter remains live.

The arch route uses the actual victory-gate factory in a controlled peaceful
village. Native movement selects the gate; the test does not earn a boss victory
or invoke the gate action. It records the actual factory lift before normal
draws and verifies that the hidden hotspot's prompt retains it. Real Controls
capture changes E to F3, then the long `ON-SCREEN KEYBOARD` label, then E. Both
synchronous remap coordinates and later drawn text are observed. Exact settings
and keybind main/bak/tmp bytes are restored, and only synchronously owned
factory nodes/memberships are removed.

`--generic-prop-prompt` requires the arch mode and adds an owned non-landmark
factory book stand-in. It proves generic anchoring/remapping, full text and
positive/negative native reach selection. The visibly low-resolution, floating
stand-in is **prompt/remap/reach evidence only**, not artwork or scene-quality
acceptance. No ordinary visible book asset is added by this change; production
victory-arch book hotspots remain hidden. Generic authored-clear anchor retention
and independently painted generic-book body/HUD clearance are not established
by this fixture. The actual chest and NPC episodes own their clearance claims.

Separate fountain and interaction-copy routes retain their existing landmark,
copy and input contracts. The final validation plan includes real paired ENet
shortcut regression, desktop compile/quick/full, scoped mobile sync/import/
compile/quick, focused native routes and strict preflight. That ENet regression
does not establish every guest prompt or moving online overlay case.

## Retained development evidence and attribution

Evidence root: `build/qa/session-sept20/prompt-clearance-next/`.

- `root-validation/capital-arrival-native-candidate/root-npc-before-v1`:
  108 strict rows, 101 pass and seven failures. There is no baseline waiver.
- `root-npc-after-pilot-v1`: retained failed approach, 35 rows/32 pass/three
  failures. The hero stopped after 23 ordinary movement steps and never selected
  Voss. Existing evidence does not establish the reason; focus/input loss is a
  hypothesis, not a verified production defect or a reason to waive the run.
- `root-npc-after-diagnostic-v2`: 108 rows/104 pass/four failures. The diagnostic
  input observations retain the same one-second movement contract. The remaining
  viewport alternative covered both bodies; this motivated the side-slide
  production correction.
- `root-npc-after-slide-v3`: 108/108 pilot rows pass. This is pilot evidence,
  separate from final acceptance.

The production solver is locally authored. The earlier Fable implementation
attempt timed out without a usable patch. A separate actual Claude Fable call
provided the alternatives QA draft, which received local source corrections and
native review. Raw output and corrections are retained under `qa-claude-v1/`.

Actual DeepSeek Flash supplied the chest implementation scaffold; its first
draft failed independent source review, including an invented API and incorrect
geometry/selection checks. The requested revision hit its output limit. The
bounded integrated helper is a substantial local correction, with both rejected
raw outputs preserved under `chest-provider-v1/`. Actual DeepSeek Flash and
v4-pro supplied arch drafts; both required substantial local corrections for
invented APIs, native input, state restoration and scope. Their raw outputs and
reviewed derivative remain under `arch-provider-v1/`. Do not attribute the final
implementation wholesale to a provider, or treat provider prose as runtime
acceptance.

## Final checkpoint acceptance

All 20 stages pass: desktop compile/quick/full, scoped mobile sync/import/
compile/strict quick, six native episodes per project and all seven strict
preflight categories. Per project: NPC 108, arch/generic 99, chest 37,
fountain 69, interaction-copy 191 plus five native rows, and paired ENet
33 completed scenario witnesses with real wire receipts and save restoration.

Actual Claude Fable opened all 126 final originals in 18 bounded review calls.
Final V2 review has no blockers or parsing corrections.
Root directly inspected critical originals. Earlier V1 review findings were
resolved with exact image/source-bound dispositions:
the borrowed empty HUD backdrop is intentional; settled/selected and
first-entry/first-hot chest images can show the same frame and do not count as
independent temporal observations. Selection is established by the original
entry checks and actual native confirmation/cancel flow, not a new highlight.
Root also corrected a false clipped-head observation against the original;
the borrowed camera does let the minimap cover the actors' lower bodies.
The earlier V1 review needed three recorded syntax-only JSON normalizations.
Raw provider text, failed verification and findings are retained. V1 passed
all native episodes but failed strict preflight on a structural two-pass loop
literal. The loop now explicitly enumerates the same [0, 1] passes; final V2
repeats the complete validation against that exact source. No check was waived.

This accepts prompt placement and the specified regressions, not whole-scene
art quality. The generic legacy book remains visibly coarse/floating fixture
art, oversized fallback remains deliberately unreadable, and prop grounding,
hero/chest overlap, faint reward text and existing confirmation-panel layout
remain outside this improvement. Mobile checks are host Compatibility renders,
not physical devices. Existing permitted renderer-shutdown diagnostics remain.

Final source-bound logs and originals:
`build/qa/session-sept20/claude-shortcuts/root-prompt-final-v2/capital-arrival-native-candidate/`.
Acceptance and exact image/source/evidence pins:
`build/qa/session-sept20/prompt-clearance-next/root-validation/acceptance.json`.
Final commit and post-commit local state:
`build/qa/session-sept20/prompt-clearance-commit-receipt.json`.
All rejected/partial evidence and 46 unrelated preserved files remain separate.
