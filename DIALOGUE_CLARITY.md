# Dialogue clarity

Pass 33, 2026-09-09. The reviewed correction is installed and mirrored. Native acceptance and desktop/mobile suites pass; full repository preflight passed without findings.

## Behavior

Fenna's choice panel previously covered LOG, SKIP and AUTO. The reader row now sits above the highest visible dialogue or choice panel, using the controls' measured sizes. The styled buttons are 66 × 31 pixels, despite their factory requesting a height of 28. Their fonts, widths and input handlers are preserved. The row follows the existing entrance tween and returns to its plain-line position when choices close.

Opening LOG brings the existing backlog above the choices for both drawing and pointer handling. A shared choice guard also blocks number-key selections while the backlog is open. Closing it leaves the decision pending. SKIP and AUTO retain their existing choice and online rules; no story callback or outcome changes.

Long body text and wrapped options now use Label's complete shaped minimum height, including line spacing. The advance hint stays at its original position when the text fits. Otherwise it moves just below the text, and the frame's footer extends enough to contain it. The frame bottom is therefore a minimum rather than an unconditional fixed edge. A short successor restores the original text, frame and hint positions. Fonts, text widths, wrapping and all dialogue strings remain unchanged. This is a bounded layout correction, not paging or a promise that arbitrarily long text fits one screen.

## Baseline evidence

| Run | Checks | Strict failures | Expected findings | Native images |
| --- | ---: | ---: | ---: | ---: |
| Desktop baseline 1 | 105 | 0 | 22 | 16 |
| Mobile-source baseline 1 | 106 | 0 | 22 | 16 |

Evidence lives in `build/qa/dialogue-desktop-baseline1.log`, `dialogue-mobile-baseline1.log`, and their corresponding `-user/Godot/app_userdata/Crownless/shots/dialogue_clarity/` directories. Both used the old production HUD and prior QA source. A baseline runner pass allows the explicitly recorded defects; it is not a clean UI verdict. The desktop log also contains the established renderer shutdown diagnostics, so it is not clean stderr.

The native `solo_long_four_options.png` shows body text through the lower border and under the advance hint. The original rectangle checks did not detect this. The revised QA keeps that exact five-repeat paragraph and four wrapped choices, and adds complete-text, minimum-height, hint, frame, viewport, option-target, hover and row-gap checks. The QA caption moves to y678 so it stays below the longer footer.

## Verification limits

The fixture first opens the actual spawned Fenna with bound E. It captures her untouched callback, then intercepts outcomes before negative-input probes. Later choices and long text use labeled QA-only callbacks. It exercises real mouse or ScreenTouch input, LOG/CLOSE, SKIP/AUTO, hidden keyboard/pointer attempts, visible choice controls and the long-choice-to-short-line reset.

Each run covers solo and an empty loopback host bound to 127.0.0.1. There are no guests or remote replication claims. Mobile is the handheld source rendered on this host with Compatibility and ScreenTouch events, not physical-device evidence. Godot's character bounds are shaped layout cells, not a raster ink mask; native images remain necessary for glyph and outline review. The isolated no-saves fixture restores borrowed state and releases owned inputs.

## Corrected regression and final fixture check

Desktop fixed2 passed 191 checks and mobile fixed1 passed 192, both with zero failures/findings and ten unique native images. They cover actual reader input in solo and an unpaused empty loopback host, with preserved state and no story outcomes. All 20 corrected images were reviewed in `build/qa/dialogue-fixed-native-review.md`.

The earlier fixed1 desktop completed its solo layout/input probes with zero findings but failed to create its derived-port ENet host; its five frames and failed log remain preserved. Windows reserves ranges inside that derived range, but the failed process's exact port was not recorded, so the precise cause is not established. Both successful corrected runs used a separately verified `--port=44550` override.

The fixture now defaults to port 0, asks the OS for a free loopback UDP port and records `get_host().get_local_port()` before attaching the owned peer. Explicit overrides remain available. This is a QA-only reliability change; production network behavior is unchanged. Final desktop/mobile runs passed 192/193 checks with zero failures/findings and ten unique native images each, including OS-assigned ports 59627/61091. The accepted explicit-port runs remain the override control. All 20 final images were reviewed in `build/qa/dialogue-final-native-review.md`; they match the earlier corrected images byte-for-byte. All relevant production and QA source hashes match the final freeze. Desktop compile225/quick125/full205 and mobile import/compile225/strictquick125 pass; full preflight passed without findings.

## Reproduction

Use fresh isolated QA homes beneath this worktree's build/qa and the standard muted, compile-gated runner:

    shot.bat dialogue_clarity --timeout=300
    shot.bat dialogue_clarity --timeout=300 --mobile --renderer=gl_compatibility --touch

Do not pass `--baseline` for acceptance. Both runs must have zero strict failures and no presentation findings, with native review of actual Fenna, LOG, the unchanged long fixture and its short successor. Inspect entrance placement as well as settled frames. Mobile source parity and full repository preflight are verified.

Initial corrected source hashes are recorded in `build/qa/checkpoint33-source-freeze1.json`: HUD `acad8fed…a89100b`, QA `859aaeff…c62e911`. The final QA-only port update is `133c1643…24295a52` in `build/qa/checkpoint33-source-freeze.json`. The applied patch normalizes line endings relative to the reviewed HUD candidate; normalized source text is identical, as recorded in `checkpoint33-published-line-endings.json`. Runtime verdicts bind to the installed byte hashes.
