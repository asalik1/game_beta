# Emberfall — Mobile (iOS / Android)

This folder holds everything specific to the mobile release of Emberfall.
The desktop game lives in `game/` and is the source of truth; **nothing in
`game/` should ever be changed for mobile's sake.**

> **Agent policy (also stated in CLAUDE.md):** the mobile version is
> frozen by default. Do NOT port desktop changes here, keep this folder in
> sync, or touch anything under `mobile/` unless the user explicitly asks
> for mobile work. Desktop agents can ignore this folder entirely.

---

## Framework: Godot native mobile export (no engine switch)

Emberfall is built in **Godot 4.4**, and Godot exports natively to both
Android and iOS from the same project. We do **not** rewrite or wrap the
game in another framework (Unity, Flutter, Capacitor, etc.) — we use
Godot's own export pipeline. The mobile version is a **snapshot fork of
the `game/` project** that lives here and gets updated only on request.

### How the pieces fit

```
mobile/
├── README.md            ← this file
├── game/                ← snapshot copy of the desktop project, adapted for mobile
│   ├── project.godot    ← mobile renderer + touch settings (diverges from desktop)
│   └── ...
├── export_presets.cfg   ← Android + iOS export presets (kept out of desktop project)
└── builds/              ← output .apk / .aab / .ipa (git-ignored)
```

(Only this README exists right now; the rest is created when mobile work
actually starts.)

### Why a snapshot copy instead of sharing `game/` directly

- Desktop uses the **Forward+** renderer with 2D HDR glow
  (`viewport/hdr_2d=true`). Forward+ does not run on phones — mobile must
  use Godot's **Mobile** renderer (Vulkan on Android, Metal via MoltenVK
  on iOS), with the **Compatibility** (GLES3) renderer as a fallback for
  older Android devices. That's a `project.godot` divergence that can't
  live in one shared project cleanly.
- Mobile needs its own input layer (touch), UI scale, and performance
  budget. Keeping those edits inside a copied project means zero risk of
  a mobile tweak leaking into the desktop build that two other agents are
  actively working on.
- Sync is deliberate and manual: when the user says "update mobile", we
  re-copy `game/` over `mobile/game/`, then re-apply the mobile deltas
  (renderer, input, UI). The deltas should stay small and be listed in
  this README as they're made.

## Platform targets

| | Android | iOS |
|---|---|---|
| Export format | `.aab` (Play Store) / `.apk` (sideload testing) | `.ipa` via Xcode project |
| Renderer | Mobile (Vulkan), Compatibility fallback | Mobile (Metal/MoltenVK) |
| Min version | Android 8 (API 26) | iOS 14 |
| Build needs | Android SDK + JDK 17, debug/release keystore | macOS + Xcode, Apple Developer account ($99/yr) |
| Store | Google Play ($25 one-time) | App Store |

Note: iOS builds require a Mac for the final Xcode signing step. Android
can be built entirely from this Windows machine.

## Mobile adaptation checklist (the actual port work, when it starts)

1. **Renderer switch** — `rendering_method="mobile"` (+ `mobile` fallback
   list); verify the HDR glow look. If 2D HDR glow is too costly or
   unsupported on target devices, replace with a cheaper canvas shader
   approximation — visual parity is a goal, not a requirement.
2. **Touch controls** — virtual joystick for movement + ability buttons
   (6 classes × several abilities means a radial/bar layout). Godot's
   `TouchScreenButton` + a small on-screen HUD layer. Desktop keybinds
   stay untouched; mobile adds `InputEventScreenTouch`/`Drag` mappings.
3. **UI scaling** — 1280×720 `canvas_items` stretch already helps;
   audit every menu/HUD screen for thumb-sized hit targets (≥ 44 px) and
   safe-area insets (notches) via `DisplayServer.get_display_safe_area()`.
4. **Performance budget** — target 60 fps on mid-tier devices; profile
   particle counts, glow, and audio channels; add a quality toggle.
5. **Save compatibility** — same save format as desktop; store under
   `user://` (Godot maps it correctly per-platform). Cloud sync is a
   later, multiplayer-era problem.
6. **Store compliance** — privacy policy, content rating questionnaires,
   Play Console + App Store Connect listings, icons/splash in all
   required sizes.

## Mobile deltas (applied 2026-07-13)

The snapshot is a copy of `game/` with these — and only these — divergences.
On a re-sync (re-copy `game/` over `mobile/game/`), re-apply this exact list:

1. **`project.godot`**
   - `[rendering] renderer/rendering_method="mobile"` +
     `renderer/rendering_method.mobile="gl_compatibility"` (Vulkan, GLES3 fallback).
   - `config/features=PackedStringArray("4.4", "Mobile")`.
   - `[display]` add `window/stretch/aspect="expand"` and
     `window/handheld/orientation="landscape"`.
   - `[input_devices] pointing/emulate_touch_from_mouse=true` (lets the touch
     HUD be driven by the mouse on desktop for verification).
   - `[autoload] MobileInput="*res://scripts/mobile_input.gd"`.
2. **New files** (mobile-only; do NOT port to desktop):
   - `scripts/mobile_input.gd` — autoload holding touch state (analog move +
     held ability/action flags).
   - `scripts/ui/touch_hud.gd` — the on-screen controls (`class_name TouchHud`).
3. **`scripts/player_core.gd`** — `_poll_local_intents()` OR-s `MobileInput`
   into the same `intent_*` fields the keyboard fills (the §10 touch seam),
   right before the downed/ghost gate.
4. **`scripts/game.gd`** — `_ready()` adds a `TouchHud` when
   `OS.has_feature("mobile")` or the `--touch` dev arg is present.
5. **`export_presets.cfg`** — Android + iOS presets (see below). NOT the
   desktop presets (those are excluded from the snapshot).

The touch HUD is pure presentation: it only ever writes an intent seam, so no
gameplay/netcode forks per platform.

## Build commands

Run from the repo root with the bundled engine (`tools\Godot_v4.4.1-stable_win64_console.exe`):

```
# Reimport after any re-sync (new class_name / autoload → mandatory)
tools\Godot_v4.4.1-stable_win64_console.exe --headless --import --quit --path mobile/game

# Verify on THIS desktop first — mouse drives the touch controls:
tools\Godot_v4.4.1-stable_win64.exe --path mobile/game -- --touch

# Android APK (sideload testing) — needs the toolchain below configured:
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --export-release "Android" ../builds/Emberfall.apk

# iOS (emits an Xcode project; sign + archive on a Mac):
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --export-release "iOS" ../builds/ios/Emberfall.ipa
```

### Producing device builds (toolchain — owner's machine/accounts)

The presets are scaffolding; a real artifact still needs, per platform:

- **Android `.apk`/`.aab`:** JDK 17 (this box has only Java 8), the Android SDK
  (`ANDROID_HOME`), the matching **Godot Android build template**, and a
  keystore configured under *Editor → Export*. For a Play Store `.aab`, flip
  `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` in
  `export_presets.cfg`. Google Play dev account: $25 one-time.
- **iOS `.ipa`:** a Mac with Xcode, an Apple Developer account ($99/yr), and a
  signing identity + provisioning profile filled into the iOS preset.
- **Store listings:** app icons/splash in all sizes, privacy policy, content
  rating questionnaires, Play Console + App Store Connect entries.

## Status

- [x] Folder + plan (this README)
- [x] Snapshot `game/` → `mobile/game/`
- [x] Renderer + project settings divergence
- [x] Touch input layer (Wild Rift joystick + ability arc + tap/swipe lock)
- [~] UI / safe-area pass (crude fixed inset in place; precise notch mapping via
  `DisplayServer.get_display_safe_area()` is a later refinement)
- [x] Android + iOS export presets (scaffolded)
- [ ] Android test build on a device (blocked on toolchain above)
- [ ] iOS Mac signing pipeline (blocked on Mac + Apple account)
- [ ] Store listings

Reminder: this folder stays frozen between explicit mobile-work requests.
