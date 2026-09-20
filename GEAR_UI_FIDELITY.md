# Painted gear in Inventory

Inventory gear uses the existing 128px painted Codex artwork at its normal
control sizes: 48px bag cells, 38px equipped icons, 36px Stats paperdoll icons
and 40px detail headers. Linear filtering preserves smooth detail when scaled
down. Slot, grade, noun and named-item art all reach the existing resolver.
Item identity, grade accents, sockets, transactions and control geometry stay
unchanged. No artwork is generated or replaced for this change.

The opt-in is limited to Inventory and its gear details. The shared merchant
inspection branch retains its existing resolver. World drops and held weapons
continue to use their existing runtime artwork. The historical 32px runtime
policy remains applicable there; Inventory explicitly uses the established
painted masters. This is not whole-game art acceptance.

## Controlled native check

Run the existing compile-first, muted workflow with fresh APPDATA under build/qa:
`shot.bat material_ui --inventory-readability --gear-fidelity --timeout=300`.
Add `--mobile --renderer=gl_compatibility --touch` for the synchronized mobile
source on the development host. Gear fidelity requires Inventory readability.

The base eight views keep real browsing, scrolling and two material discard
checks. Gear probes compare actual texture pixels, filter modes and geometry.
The optional four-view gallery borrows The Red Pennon from Items.UNIQUES,
opens its bag detail, worn detail, Stats paperdoll and Stats detail with native
input, and restores its loan. Its explicit imported master is checked separately
from the family fallback. Import processing is respected: raw PNG bytes are
not a substitute for the imported resource's pixels.

Bag and equipment placement are controlled fixture assignments, not rewards or
an equip action. The gallery does not recalculate stats; it validates icons,
not stat accuracy. World-resolver dimensions are observed, but no world/held
rendering acceptance is claimed. Mobile checks use host rendering and emulated
touch, not a physical device. Native images require visual inspection alongside
strict logs.

Menu dispatch and four-frame settle times are diagnostic single-run samples.
A full 450-slot mixed-stock fixture checks a practical large inventory, not
every unique icon/cache combination or a statistical performance guarantee.

## Provenance and current validation

Actual Claude supplied the bounded production change and corrected the actual
DeepSeek QA drafts. Codex independently reviewed the source, preserved rejected
drafts, and corrected missing QA preload and raw/imported-image assumptions.
Raw provider outputs, executed sources, screenshots and failed attempts are in
`build/qa/session-sept20/gear-ui-fidelity/` and the earlier
`inventory-readability/gear-fidelity-*` directories.

Validated September20: desktop compile/quick/full, scoped mobile sync/import/
compile/strict quick and all seven strict preflight categories pass. Inventory
passes290 checks on desktop and host mobile, with12 views each. Existing material
pilots pass309 each; equipment gestures49 each; gem caps45/49; navigation158 each;
paired ENet UI24 each. All106 originals across12 native episodes were inspected
by actual Claude, with root independent selected-image review and corrections
to overbroad advisory claims. Native behavior is established by the strict
reports, not inferred from static screenshots.

The old-art and first painted iteration each pass146 checks. Maximum-bag first
open dispatch measured1.602s before and1.651s after in that single pair; repeat
open measured0.295s and0.258s. These are noisy diagnostic samples, not a speed
improvement or regression threshold. The expanded gallery has extra probes and
different cache history; its timings are not a like-for-like comparison.

The complete source, report, screenshot, review and provider bindings are in
`build/qa/session-sept20/gear-ui-fidelity/acceptance.json`; final commit and local
state are in the session's `gear-ui-fidelity-commit-receipt.json`. All46 unrelated
files,4625 icon PNGs and the older status tail remain byte-identical.

Limits remain: no ordinary progression, physical-device, whole-art-corpus or
world/held-renderer acceptance. ENet UI-only does not prove persistence or
real-scene disconnect cleanup. Legacy coarse gems/bags/Pitted Iron, twenty
missing material variants, small stat text, dim ineligible gems and compact
legacy popover controls remain follow-up. The separate gem candidate is private
and is not included in this checkpoint.
