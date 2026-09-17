# Inventory card touch gestures

Touching an equipped item opens its card on release. Moving farther than the
existing drag threshold scrolls the equipped list without opening item details.
Socket buttons keep their own tap/scroll behavior. A physical mouse opens on
press in either layout.

The card tracks the actual touch ID, suppresses synthetic duplicate events, and
abandons a tap after a second contact, cancellation, focus loss, or replacement
of its menu shell. Multiple-contact gestures cannot re-arm until every contact
is released. It retains the existing PASS propagation and gear drag/drop path.

Use the compile-gated muted runner with fresh APPDATA under build/qa:
`shot.bat gems --equip-touch --timeout=180`.
Add `--mobile --renderer=gl_compatibility --touch` for the mobile source on the
host. The helper explicitly exercises touch/mouse emulation combinations; this
is not physical-device multi-touch or OS cancellation testing.

The fixture lends a legal B weapon with an additional regular socket through
Items.can_add_socket/add_socket, embeds one gem through the production API, and
freezes the hero while operating the real UI. It uses actual viewport touch,
drag and mouse events. Same-frame and freed-shell replacements are controlled
programmatic rebuilds, separately labeled. Owned gear/progression and input
modes are restored. No gear/crafting reward, purchase or save migration is claimed.

Claude Fable 5 supplied the original gesture implementation and QA through the
authenticated CLI. Codex reviewed and coauthored the accepted candidate. Raw
versions, corrections and independent reviews are preserved under
build/qa/session-sept17/claude-inventory-touch-candidate/.

Rejected baseline1 could not roll its assumed two-socket B weapon; B rolls one.
Baseline2 reached the actual drag defect but incorrectly required the shared
Unequip action to disappear on the Gems tab. Baseline3 confirmed sockets and
scrolling but left touch-from-mouse emulation enabled for its nominal desktop
control. Each is preserved. Corrected baseline4 requires ordinary desktop input
separately from mixed-input controls and reproduces exactly body_drag/opened in
13 checks and four native images. These are test corrections, not game fixes.

Strict final1 completed its scenarios but rejected two malformed canceled-press
assertions. Trace1 on the actual Godot4.4.1 runtime confirmed that canceled=true
makes the pressed getter false even after requesting pressed=true. The unknown
canceled contact was therefore ended; a subsequent fresh finger was legitimate.
Both rejected receipts, trace events and source versions remain preserved.
The corrected fixture checks unknown cancellation without opening, a fresh
nonzero-ID tap, and cancellation of an actually held primary while a second
contact remains. The second contact stays inert until release; a later fresh
gesture works. The production branch was simplified to match this observed
getter behavior. Ordinary cancellation and both release orders remain strict.

A broader gem run forced touch layout on the desktop project without enabling
host touchscreen capability. Its socket drag stayed at zero; the exact committed
menus control failed identically. Both rejected receipts are preserved. The
established desktop mouse regression and host mobile touch regression remain
strict, alongside the focused equipment helper that establishes its own touch
capability. No production change was made for this environment mismatch.

The final2 desktop focused probe passes 48 checks with no findings/failures and
five native originals. The completed broader validation is recorded below.

Validated desktop quick 146/full 226, mobile quick 146, exact three-source sync and strict preflight. Equipment probes pass 48/48 checks with 5/5 originals (desktop/host mobile); desktop mouse/mobile touch gem regressions pass 36/40 checks with 9/9 originals. Every final original was independently inspected at original resolution; root inspected selected originals. No new network path or physical-device claim.

The first closure script incorrectly required identical desktop/mobile helper
UIDs. The established sync tool deliberately preserves each project's own IDs;
it copied zero files during the attempted follow-up. Both IDs stayed unchanged.
The closure check now pins them separately. An extra mobile import, compile and
strict quick run was retained; equip-final2-uid-policy-review.json records the
correction. This was an audit-script error, not a game or metadata defect.

Final source, gates, native counts/images, known limits and the resulting commit
are bound by build/qa/session-sept17/equip-touch-checkpoint-validation.json.
