# Controller play

Connect a standard mapped gamepad and press a button. Settings → Controller
contains an illustrated layout, a live stick preview, deadzone adjustment,
cursor speed and Auto / Xbox / PlayStation labels. Using the keyboard, mouse
or touchscreen switches the prompts back. Mobile touch controls reappear
when touched; a controller does not change the saved touch preference.

| Control (Xbox layout) | During play |
|---|---|
| Left stick | Analog movement; gentle tilt walks |
| RT / LT / RB / LB | Basic / second / third / ultimate ability |
| A | Interact, hold to revive, confirm dialogue |
| X / Y | Drink selected potion / cycle potions |
| R3 | Lock or cycle a combat target |
| Right-stick flick | Select a target in that direction; recenter before another flick |
| B | Release target lock |
| D-pad ↑ / ← / → / ↓ | Field atlas / inventory / skills / Codex |
| Menu / View | Pause / inventory |
| L3 | Party chat in co-op |

Menus use a local cursor: left stick moves, D-pad snaps to visible buttons
and cards, A clicks or holds a drag, and right stick scrolls at the cursor.
Over the atlas, scrolling zooms. B follows the same back path as Escape.
Focus a text field and press X for the on-screen keyboard. The keyboard
includes names, numbers and connection-code punctuation; Y backspaces, B
closes it, and Done sends party chat when that is the active field.

At a fishing nook, RT casts, strikes and holds the reel. Release it when
the fish warns or surges. Lures and the catch journal use the menu cursor.

The adapter writes the existing local movement and held-action intents and
the 180 ms ability buffer. There is no controller-specific combat simulation,
extra RPC, balance change or save format. A radial deadzone preserves analog
speed and caps diagonals. Trigger hysteresis prevents noise around the press
threshold from creating repeated buffered attacks. Menus, dialogue, chat and
choices gate gameplay even when the co-op world is unpaused. Release held
controls after leaving an overlay to resume combat. Focus loss and device
disconnect clear local input; disconnect opens the pause menu when available.

Implementation:

- `scripts/gamepad.gd`: device selection, raw state, context routing, intent
  adapter, button labels, trigger edges and disconnect/focus cleanup.
- `scripts/ui/gamepad_cursor.gd`: viewport-local pointer, spatial snapping,
  scroll, safe interrupted drags, text keyboard and device hints.
- `scripts/ui/controller_settings.gd`: original vector controller diagram
  and persisted comfort settings. All input tuning lives in `balance.gd`.
- `scripts/tests/test_gamepad.gd`: radial response, invalid axes and inactive
  device isolation; `shot_controller` drives actual Godot input and GUI paths.

Reproduce the rendered checks with `shot.bat controller --timeout=240`.
Captures go to `user://shots/controller/`. The desktop and mobile source
projects share the implementation. Physical Windows/Steam Deck, Android and
iOS controller testing remains a hardware validation step; simulated input
does not establish Steam Deck verification or device-driver compatibility.

Platform references: [Steam Deck compatibility](https://partner.steamgames.com/doc/steamhardware/compat),
[Apple controllers](https://support.apple.com/en-gb/111099),
[Android controller testing](https://developer.android.com/games/sdk/game-controller/testing_controller).
Pointer routing follows Godot 4.4's [Viewport input API](https://docs.godotengine.org/en/4.4/classes/class_viewport.html#class-viewport-method-push-input).

## Validation — 2026-09-07

- Desktop quick suite: PASS. Full campaign suite: 178 checks passed.
- Mobile editor import, compile gate and quick suite: 97 checks passed.
- `shot_controller`: PASS, nine rendered captures. Real input events cover
  analog motion, trigger hysteresis and buffering, held-input release across
  pause, an unpaused overlay, native clicks and sliders, scroll followed by
  text entry, selection replacement/backspace, keyboard handoff, interrupted
  clicks, atlas zoom, dialogue selection, directional locks, fishing, touch
  handoff, focus loss and disconnect.
- Preflight: zero failures, six existing numeric-lint warnings. Seventeen
  desktop/mobile files compared byte-for-byte with zero drift.
- The renderer still emits its existing texture-RID shutdown diagnostics;
  the final rig has no script errors, negative-frame errors or new warnings.

Evidence lives in `build/qa/controller-full-verified.log`,
`controller-mobile-final.log`, `controller-mobile-suite.log`,
`controller-visual-verified2.log`, `controller-preflight-final.log` and
`controller-mobile-parity.json`. Final images are under
`build/qa/controller-final-render-user/Godot/app_userdata/Crownless/shots/controller/`.
