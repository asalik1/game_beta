# Each hero's chapter ending

MP-24 restores the existing illustrated chapter endings to co-op. Chapters
1–7 already have a closer for every class; each player now reads their own
class's paintings and narration before their results card. Later chapters
retain their authored text fallback. No art is regenerated in this pass.

The host sends victory immediately after banking its own rewards and run
record. Guests bank their own chapter credit, unlocks, weekly reward and run
record on receipt, while autosave still accepts the playing state. Reading
does not extend the run clock. A dedicated authority resolves its readerless
ending immediately and keeps the existing delayed advance behavior.

The live two-reader test caught a same-frame ordering regression: first-clear
mail was deferred, but victory synchronously marked the chapter complete.
The mail helper then correctly rejected that already-completed chapter.
Victory now joins the same ordered deferred queue as boss awards, board
credit, loot recovery and first-clear mail. Its record and autosave therefore
observe the settled rewards. The queued presentation also rejects a changed
chapter or ended session before running.

Each game owns a ChapterFinale lifecycle. It waits behind an open menu, NPC
conversation, choice, chat field, pending online conversation request or
older cinematic dissolve. Existing interactions finish through their normal
callbacks, including consequences and claim release. The personal ending
itself takes no NPC claim, party gathering lock or mirrored story beat.

Dialogue and the final dissolve hold the existing overlay input gate. Touch
controls disappear through the whole pending ending. Every page and choice
checks the ending's generation before continuing. Duplicate victory messages
are ignored while reading and after dismissing the results, until a world
change resets the lifecycle.

The reader's survival clocks stop while the ending holds their input. Late
owner-side damage is rejected, and downed timers cannot bleed a reader out
behind the artwork. This protection ends when the reader finishes or the
ending is cancelled. Other players and the shared world keep their ordinary
simulation; remote shells keep forwarding damage to the correct owner.
The host's wipe census also waits during its active finale, so a final boss
finished by a lingering hit cannot turn a won chapter into a party wipe.

Party travel and session teardown retire the old artwork and dialogue. An
interrupted pending interaction releases its active/pending online claim
without executing its old quest callback. Old pages and completion callbacks
cannot paint over the new chapter's opener. A dedicated server's delayed
advance also checks the captured generation, so an old timer cannot advance
a later victory.

The solo victory branch retains its existing closer and results ordering.
The first-conquest regression rig independently exercises its real boss
death, first/replay mail packages and illustrated result transition.

The quick contract covers independent lifecycle
state, exactly-once completion, held-intent clearing, cancellation, duplicate
messages and absent-art/dedicated fallback. The new `coop_closers` ShotRig
uses two real games with separate SubViewports and ENet API scopes in one
engine, keeping machine memory bounded. It drives real boss-death victory,
conversation-claim and advance RPCs. Its host-loss check invokes the actual
production teardown callback after an ENet run; it is not a transport-loss
simulation or mobile hardware test.


Final validation: desktop 190-script compile, 114
quick checks and 194 full checks; mobile editor import,
190-script compile and 114 quick checks. All
headless suites pass their strict script/resource checks. Desktop Forward+
and mobile Compatibility each pass ten two-reader captures and five solo
real-boss captures. The original seven-capture actual ENet personal-history
and reconnect rig also passes. Both connected heroes receive one first-clear
package; duplicate victory messages change neither rewards nor run records.
The live rig covers final-fade and same-chapter rebuild cancellation, pending
and active NPC claim release, home preservation, touch gates and class art.
With god mode disabled, direct and real ENet damage cannot injure the reader;
survival/cooldown clocks hold, then resume after card dismissal. The legacy
network suite's guest reader setup is exercised in this same one-engine rig.

Cinematic presentation now retires an unfinished boss entrance splash and
hides party frames, arrows, battle meters and downed/revive markers, including
on later HUD refreshes. The party proposal UI keeps its existing behavior.
19 frozen source files match mobile, with three independent UID pairs.
Source preflight reports zero failures and twelve known structural warnings;
the engine Codex data check passes. Network version is 0.3.12. No new art,
mobile hardware claims, transport-loss simulation or commits.


Calibrated desktop and mobile Compatibility captures were visually reviewed:
the warrior and mage see their own artwork, narration is readable, pending
touch choices remain usable, and party markers/boss splashes do not cover
the ending. Screenshot runs still print the known renderer shutdown texture
diagnostics; their strict script/runtime verdict passes. Native Android/iOS
hardware was not exercised. Work is paused at the user's request after this
completed feature; follow-up companion networking is only a plan.
