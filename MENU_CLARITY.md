# Menu clarity

The menu changes are installed on desktop and mobile. Eight isolated native runs passed: online menu checks and cosmetic menu checks, before and after, on both renderers. The after runs have zero presentation findings. All 40 native images passed paired review. Desktop compile229/quick125/full205, recovery mobile compile229/strictquick125, and full repository preflight all passed. Both projects imported successfully. The final gate recovery completed after the deadline, as recorded below.

Opening the game menu during a live online session previously suggested that play had paused. The menu now says **Online — [chapter]**, uses **Return to game**, and states **World keeps running**, with the appropriate keyboard/mouse or touch close instructions. Its footer reads the actual pause state after opening: the existing already-paused victory exception says **Game paused**. Solo retains its existing Paused title, Resume game action and footer. The full chapter name, identity subtitle, layout, callbacks and pause rules remain. Other menus and arbitrary transport/state changes after opening are outside this copy-only scope.

The Wardrobe stops offering the retired chroma category. Its game-menu description instead advertises skins and pets bought with Renown; the Codex Renown card describes spending on skins, pets or the existing weekly supply cache. That also removes the misleading blanket claim that Renown can never affect gear or power. Classic, skin, companion, wallet and cache controls remain. Prices, ownership, purchasing/equipping, catalog data, save loading, shaders and artwork are unchanged. Legacy saved cosmetic state is kept, including an already worn chroma; it is not silently reset. The existing Classic action can still clear an equipped legacy look. Unexposed legacy helpers are retained.

## Input and native checks

Both modes separately extend the isolated, muted HUD dossier rig; its ordinary mode remains available.

- `--online-menu`: six native frames per renderer cover solo, a real empty loopback host, and a synthetic already-paused victory state, each with an open/return pair. Desktop uses Escape for ordinary entry; touch uses an actual ScreenTouch on Menu. Victory uses the real Menu button because Escape intentionally rejects that state. Primary return actions use mouse/ScreenTouch, with an additional host Escape open/return cycle. Checks cover actual opens/returns, pause/state retention, full copy, measured bounds and restoration.
- `--cosmetic-ui`: four native frames per renderer cover the actual game-menu Wardrobe action, skin catalog, companion row, and Codex Renown card. Actual Menu, Wardrobe, Codex and Records inputs must reach the intended screens. The Codex Open Wardrobe action must reopen the catalog. Explicit scroll-to-control setup brings the last companion and Renown card into view; this is not touch-drag coverage. No Buy, Wear, Doff or cache action is activated. The checks retain current offerings and compare cosmetic ownership/equipment, Renown, gold and cache state before/after.

Root published combined QA first, captured the old production behavior on both renderers, then applied narrow production patches after the committed hero geometry work. All Menus code outside `open_pause` remains exact. The accepted after commands were:

```text
shot.bat hud_dossier --online-menu --port=0 --timeout=240
shot.bat hud_dossier --cosmetic-ui --timeout=180
shot.bat hud_dossier --online-menu --port=0 --touch --mobile --renderer=gl_compatibility --timeout=240
shot.bat hud_dossier --cosmetic-ui --touch --mobile --renderer=gl_compatibility --timeout=180
```

The before runs add `--baseline` and use the old production files. Each run has a fresh isolated profile and temporary directory. Baseline findings allow expected presentation defects; input, setup, state preservation and cleanup remain strict. Each renderer recorded 67 online checks with six expected baseline findings and 37 cosmetic checks with three expected baseline findings. All four after runs retained the same check counts with zero findings. Across eight runs, 416 checks were logged and 40 full native PNGs were decoded. The 18 baseline findings are repeated presentation observations across two renderers, not 18 unique product defects.

SHA-bound observations, complete runner logs, source freezes and paired review receipts are under `build/qa/menu-clarity-execution1`; checkpoint gate results are recorded in `build/qa/checkpoint37-validation.json`. The exact three production pairs changed while QA, independent helper UIDs, Art and Player stayed fixed between before and after runs.

## Evidence limits

The online fixture has no remote clients or delivery claim; victory is synthetic, without a win award, real results card or story completion. Returning from that synthetic victory menu records the existing unpause behavior. Shared state/JSON-byte restoration does not roll back every world timer. The rig suppresses entrance motion, so these are settled views. Text character bounds measure shaping/layout, not painted ink. Existing small Codex rail targets are recorded rather than asserted to be 44px. Host mobile rendering and ScreenTouch delivery do not prove physical-device behavior. These cases do not validate purchases, complete catalog artwork, ordinary combat or other online overlays.

## Checkpoint recovery

The initial mobile quick process was no longer present when the continuation resumed at 14:43 UTC, after the 13:00 UTC deadline. Its log stops after eight checks without a pass marker or verdict; it is preserved and excluded. No production or QA code changed after the 11:35 UTC native-after freeze. Recovery completed the required mobile validation and preflight, followed by the explicit-path checkpoint commit of the installed change. Optional additional final-hour HUD/combat runs were not performed and are not claimed. This task's heartbeat was paused; other automations were left alone.
