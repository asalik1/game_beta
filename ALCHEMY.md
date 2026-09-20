# Alchemy — Kesh's brewing bench

The active Alchemist can turn carried herbs and reagents into one clean potion
at a time in Crownfall. Open Kesh's Professions service, then **Alchemy bench**.
Every character can inspect recipes before locking a trade. Seven
potion families share the existing consumable catalog: 39 recipes across F–A,
with Renewal beginning at C. Ordinary brewing produces no S, Grand, laced or
teaching bottles. Grand Synthesis remains Kesh's separate service.

The recipe rail and grade buttons show the complete bottle name and effect,
exact ingredient counts and shortfalls, fee, mastery requirement and blueprint
status. The Brewable filter retains the selected recipe when it becomes
unavailable. Selection, filter, reading scroll and focus survive a brew or
quote refresh. Back, Escape, controller Back, X and outside dismissal return to
Professions; cancelling a blueprint confirmation restores its recipe.
The footer points to Inventory → Potions to choose the carried bottles, and
explains that slot changes apply at the next door. Brewing never silently
changes the character's room plan.

## Ingredients and progression

Each bottle needs 2/3/4/5/6/7 herbs at F/E/D/C/B/A respectively, plus one reagent
of that same grade. Ingredients must be carried; mailed ingredients must first
be claimed. No gathering nodes, material shop or starter ingredient grants are
introduced. Plant and fungal creatures in Sporewood and the Blooming Deep
provide F/E herbs, with E/D from elites. Beasts, humanoids and void creatures can
provide reagents. C/B ingredients come from boss supply chests or bundles.
A ingredients first enter the supply tables at NG+1 Chapter 4 or NG+2 Chapter 1;
the first journey cannot supply them. These are current loot-source limits,
not a claim that every kill or chest yields the desired ingredient.

The existing Alchemist mastery track gates grades: Novice F/E, Adept D at 30,
Expert C at 90, Artisan B at 220 and Master A at 500. Brewing earns the existing
grade-based 5/7/11/18/30/48 mastery. Existing charm/glove crafting also advances
that same track. Mastery survives trade swaps.

B and A each require their own generic recipe for the selected potion family.
Kesh sells deterministic access, including before the mastery requirement is
met. Learning spends gold and adds knowledge; it grants neither a bottle,
mastery nor favor. The existing per-character blueprint array stores fourteen
`potion/<family_shape>:<grade>` keys without a new save field or schema version.
The gear blueprint shelf accepts only gear slots.

Campaign boss reward packs have an independent 12% potion-blueprint draw,
appended after the existing gear and Codex draws. It leaves those earlier draws
unchanged for the same reset RNG seed, but naturally changes later RNG state.
The existing owner award channel distributes and validates the resulting
recipe. Protocol version 0.3.16 distinguishes this shared award vocabulary.
Duplicates do not add knowledge twice. This does not add general reward-packet
deduplication or make a selected recipe a frequent boss drop.

## Costs and settlement

The service fee is `ceil(0.70 × intrinsic bottle price)` minus the ingredients'
intrinsic value, followed by Kesh's favor discount and a minimum of one gold.
This uses the canonical bottle price, not road or resonance shelf markup.
Blueprint prices use the existing 30,000/75,000 B/A baseline, scaled by the
potion's price relative to the same-grade Health Potion. Blueprint purchases
receive no favor discount; brewing fees earn and receive normal Kesh favor.

A prepared order binds the character, game, world instance and world seed.
Settlement rechecks living/playing capital ownership, active trade, current
quote terms, mastery, knowledge, exact valid ingredient stacks and gold. Both
ingredient deductions are planned before either is applied. A settled order
can execute only once. If consuming ingredients leaves the pack full, the one
canonical bottle goes to the existing mailbox. The normal autosave path keeps
guest character progress in that character's home save.

The Alchemy panel independently rejects callbacks from old shells. Its live
watcher defers refreshing while a pointer is held; releasing a stale quote
cannot spend at outdated terms. Professions' lock, swap, gear craft and
blueprint actions now also require their original live panel and world, with
one action per panel. The shared menu X has a 44 × 44 target at its
previous optical center.

## Professions workshop

The September 20 workshop replaces the scrolling trade/craft/blueprint ledger
with a trade rail and one selected recipe. Trade browsing never activates a
profession or spends resources. The separate Choose/Activate action shows the
current cost; inactive trades remain inspectable, including their own mastery.
Craft gear and Blueprints use the same slot selection, with separate grade
selectors. Recipe costs, carried ingredients and the first blocking requirement
remain on screen together. Learning and crafting still require the selected
trade to be active in Crownfall; callbacks recheck that requirement at payment.

Fresh active-trade views prefer the highest currently craftable grade for the
selected slot, otherwise F. Explicit recipe selection survives a transaction,
including when its last ingredients are consumed. Focus returns to that action
when usable, or to a harmless selection control when exhausted/already known.
It never advances to another payable recipe. Results and gold/pack counts share
the footer, including the existing full-pack mail fallback.

The workshop uses the existing painted 128px bottle and gear masters. Material
recipes without a suitable painted master use readable text rather than an
enlarged 32px fallback. The generic potion UI resolver also uses the painted
bottle. Navigation has subdued surfaces and the primary action carries the gold
fill. The shared header rule now fades to its intended muted endpoint.

The September 20 workshop passes desktop compile/quick/full, mobile import/
compile/strict quick and strict preflight. Native transaction checks pass
1043/1043 on each project, Alchemy 391/391 and actual paired ENet UI 24/24.
Original screenshots were inspected, including seven preview states and nine
transaction states. Mobile rendering used Compatibility on the development
host, not physical devices. Fixtures loan resources/mastery; UI-only ENet does
not establish persistence or ordinary progression. Its separate child-scene
disconnect diagnostic remains unaccepted. Exact receipts and rejected attempts:
`build/qa/session-sept20/workshop-checkpoint-validation.json`.

## Historical September 9–10 validation

The September 9–10 checkpoint installed the original Alchemy implementation. Desktop
compile, quick (127) and full (207) pass, including a shared domain check for all 39 recipes,
exact quotes/inputs, one-use orders, live ownership/terms, overflow and recipe
awards. Professions native acceptance passes 347/347, including 46 retained
callback probes and seven complete active-caption observations. Its baseline
had 53 expected findings; all five before and five after frames were reviewed.
These controlled callbacks establish lifetime guards, not an ordinary-click
exploit through an already closed panel.

Alchemy native UI passes 389/389 with mouse, touch and controller input; all
seven final native frames were reviewed by root and an independent agent. Desktop
receipts are `alchemy-native-after2-validation.json` and
`profession-lifetime-after1-validation.json` under `build/qa/session-sept10/`.

The read-only runtime economy audit checks all 39 prices and samples 27 route
scenarios at 500 repetitions each. Across 25,000 campaign boss packs it observes
zero mismatches in the existing gear-recipe draw prefix, 4,477 gear blueprints
and 3,001 potion blueprints, with no invariant failures. The tightest fee/resale
case is F Health Tonic: 91g with maximum current favor versus 87g strongest
current resale, before the 3g ingredient sale opportunity cost. These estimates
omit combat failure, actual walking, inventory pressure and earned gold; they
do not establish time to brew or prove arbitrary future greed bonuses safe.

The desktop full suite passes 207 checks. The final paired fixture passes seven
actual-file/ENet milestones: solo and guest brewing and learning, save/load,
overflow recovery, party travel, recipe reward fanout and reconnect ownership.
Every isolated file is restored. Its exact home-file boundary is the last solo
save immediately before first host snapshot dispatch; intervening own-chapter
writes have an unbroken SHA256 chain. Caller stacks were empty on this engine,
so the upstream cause of those writes is not identified.

The paired live UI branch passes 24 strict checks for real recipe delivery,
live clocks, blocked movement/touch, held quote invalidation and party travel.
Its separate disconnect diagnostic cannot reproduce actual current-scene
replacement because the two Games are fixture children. A retained child can
still settle after disconnect; this is excluded from acceptance and does not
demonstrate a shipped exploit. Reconnect ownership is covered by the domain
branch. All seven final paired frames were reviewed; exact receipts are
`brewing-persistence-after5-validation.json` and
`brewing-persistence-ui3-validation.json`.

Ordinary-input samples are incomplete. The initial local navigation driver
stalled during Mills loot collection. The bounded path correction collected
every remaining Mills drop and crossed the real door, then the normal mage
fell in Howling Fields at 54.076 seconds. This was a posed level-6/chapter-2
hero with empty gear, not a character progressed through Chapter 1. No brewed
bottle or complete collection-to-use journey is claimed from those runs. Their
failures do not justify a favorable loot reroll or a combat/brewing balance cut.

A separate fresh level-1 mage sample clears and collects Darkwood Road,
Wolfpaths and Deep Darkwood in 28.266, 17.338 and 21.033 seconds respectively.
Four native upkeep steps spend available points and equip actual drops. The
mage reaches level 5, then falls in Fangmaw's Hollow at 161.522 seconds with no
herbs or brewed bottle. All five frames were reviewed. This is a failed,
incomplete journey, not a balance verdict: it omits the optional opening chest,
uses a bounded combat driver, and no-save mode suppresses skippable tutorials.
Its first attempt stopped on a missed polled Skills key; the QA-only correction
is verified by the second run's actual menu/point spending. Journey scripts
remain an uncommitted experiment; the accepted feature checks above are separate.

The mobile source passes explicit import, compile and strict quick (127).
Its six native runs pass Professions 347, Alchemy 389, persistence seven
milestones, live ENet UI 24, production network admission 34 and menu returns
158. All 30 mobile frames were reviewed. These use Compatibility rendering on
the development host; no physical-device test is claimed. The desktop menu
regression also passes 158 with eight reviewed frames. The 44px X preserves
the existing return routes and input behavior.

The admission fixture uses three production NetworkManagers and actual ENet
inside one engine. It proves current-version admission, prior-version refusal,
exact refusal reasons, clean leave/rejoin and recovery after refusal. Its
34 checks pass on both projects with clean strict shutdown after correcting a
QA observer reference cycle. The three boards per run display diagnostics;
they are not player lobby screenshots.

The shared save path still ignores failed atomic writes. Brewing and its costs
remain together in memory, but persistence failure has no player-facing warning.
This inherited gap is a separate reliability follow-up; successful saves and
actual guest-home routing are covered above.

Final desktop full (207), mobile import/compile (245)/strict quick (127),
scoped source sync and all seven preflight categories pass. Exact source and
commit fingerprints: `build/qa/session-sept10/alchemy-checkpoint-validation.json`.
