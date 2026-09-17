# Potion cycling respects owned Health stock

Cycling potions with R or the touch cycle control now skips generic Health when
the hero owns no instant Health draughts. Previously an unused room allowance
could select that empty Health slot even while a stocked Mana potion was active.
Stocked Health remains selectable, spent room allowances remain unavailable,
specific potion IDs still require their own stock, and a fully dry plan remains
unchanged. Cycling spends neither a bottle nor its room allowance.

Generic Health uses the existing potion_count() contract: every owned potion with
family=health and shape=instant counts across grades and lanes. This matches the
generic drinker's stock family without changing its existing drink-first order,
potion effects, room budgets, loadout editing or drinking rules.

Desktop quick 147/full 227 and mobile quick 147 passed; both compiles, exact three-source mobile sync, strict preflight, focused cycle input and default real drinking regressions passed. Baseline has 28 checks and the sole emptyhealth/selection finding; strict desktop/mobile have 28/28 checks with zero findings/failures. All 24 baseline/final originals were independently reviewed. New helper UIDs are pinned per project; existing wrapper/player UIDs remain unowned.

The optional fixture is `shot.bat potion_hud --cycle-stock --timeout=240` under
fresh isolated APPDATA. Five legal two-slot Chapter 3 cases cover empty Health,
stocked Health, spent Health allowance, an empty specific Mana slot, and both
types dry. The first four produce native originals. Actual R/ScreenTouch input
drives the cycle; a physics observer witnesses the normal swap debounce even
when selection correctly remains unchanged. Two ordinary setup frames allow
the normal touch HUD to observe the loaned rotation before input.

Baseline permits only emptyhealth/selection, and only when actual selection is
exactly the old generic Health value. Stock, room allowance, HP/MP/economy,
native input delivery, HUD icon/count, cleanup and all other selections stay
strict. Baseline must contain exactly that one finding; strict mode permits
none. Use `--mobile --renderer=gl_compatibility --touch` for the host-rendered
mobile project. Run the unmodified default potion_hud route separately: its six
originals cover stocked/drunk/spent/empty Health, selected Mana and a legal
triple-digit stack through actual Q/touch drinking.

Stock, room allowances and full resources are loaned in a real safe room. These
are controlled no-save fixtures with normal Game/player processing, not earned
brewing, gathering or ordinary combat. No physical-device, controller or network
authority claim is made. Value assertions do not establish clipping/readability;
the actual originals require separate visual inspection. Allowed screenshot
runner shutdown diagnostics do not imply an error-free renderer teardown.

The production predicate originated in actual DeepSeek v4-pro output. Rejected
native proposals, raw requests/responses and reviewed-v1 are preserved under
build/qa/session-sept17/deepseek-consumable-candidate. The reviewed native helper
and wrapper are local corrective work, including the two normal setup frames
and accurate cycling-only outer metadata; they are not unmodified model output.

Mobile syncing excludes .uid files. Each project's new helper UID is committed
and pinned separately. Existing player_core and shot_potion_hud UIDs remain
unchanged and outside this checkpoint's owned paths. Exact source/dependency
pins, receipts, original-image reviews, preserved attempts and final commit are
recorded in build/qa/session-sept17/potion-cycle-stock-checkpoint-validation.json.

The default rig also preserves two native-size HUD derivatives per full frame.
An outer parser initially counted these as extra full frames; its failure and
all original bytes remain preserved. A corrected evidence-only audit validates
the exact six originals and twelve declared derivatives, without rerunning the
game or changing assertions. All derivative hashes are retained in the receipt.
