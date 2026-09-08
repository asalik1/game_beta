# Road Choices

September 8, 2026 — autonomous pass 23, after Party Appearance. No commits.

Road strangers now offer explicit actions with their gold, health and Accord
consequences. Toll mercy names the coins actually in a short purse. The courier
disables treatment when it is unaffordable and separates robbery from leaving.
The wager explains its 1-in-3 odds, stake and harmless exit. All three offers
can be dismissed without changing the hero.

An online decision holds its own twelve-second offer window while the player
reads. Another menu does not. Re-entering cannot stack identical strangers.
Every action validates the actor and its world before changing money or
standing; queued/freed actors, duplicate clicks, old menu roots, incapacity,
guest authority and changed room/chapter/seed/world cannot settle a choice.
Invalid decisions close themselves without dismissing a replacement menu.

The existing economy is preserved. Old Codex text promising a toll fight or
consuming a potion was corrected; healing and purse-cut tuning moved to
Balance. Existing NPC portraits supply the art. Chromas and skin artwork are
outside this pass.

Validation:
- Desktop import/compile194, quick116 and full196 pass. The suite's intentional
  malformed Fangmoot-code diagnostic and established bare ObjectDB shutdown
  warning remain; no new script errors or resource-leak failures.
- Mobile import/compile194 and strict quick116 pass.
- Eight desktop and eight mobile Compatibility captures exercise actual offer
  actors/buttons, costs, safe leave/back, once-only payment, touch bounds and
  actor-loss cleanup. A real hosted ENet session exercises the complete online
  timer window and expiry under an unrelated inventory. This feature adds no
  new RPCs and does not claim a two-peer network test.
- Preflight: zero failures, twelve source warnings. Eleven are established
  lines; the new one is multiplication by 100 to display a percentage, not a
  gameplay tuning value. Engine-backed Codex data gate passes.
- Nine source mirrors and three independent desktop/mobile UID pairs verified.

The regression fixture owns its Game/Player/Menus and restores the shared tree
pause state even on failures. The live rig now waits for the chapter opener's
final callback to hand control to gameplay before opening its first menu;
dialogue_active alone ends earlier than that callback. The earlier black
background captures were an incomplete rig boot, not a game rendering defect.

Evidence: build/qa/road-choice-audit.md, road-choice-implementation.md,
road-choices-*.log, road-choices-source-freeze.json and road-choices-uids.json.
The final capture logs contain the isolated APPDATA output folders.

Next: The Crooked Trail, a shared optional tracking/quarry Road Deck encounter.
Initial design and lifecycle contracts: build/qa/road-hunt-plan.md.
