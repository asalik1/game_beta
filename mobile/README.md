# Crownless — Mobile (iOS / Android)

This folder holds everything specific to the mobile release of Crownless.
The desktop game lives in `game/` and is the source of truth; **nothing in
`game/` should ever be changed for mobile's sake.**

> **Agent policy (also in CLAUDE.md):** the mobile version is **kept in sync**
> with `game/` (unfrozen 2026-07-15, once on-device deployment was proven).
> `game/` stays the **source of truth** — fix desktop issues there and re-sync
> here, never patch `mobile/` directly. Re-sync = re-copy `game/` over
> `mobile/game/`, re-apply the deltas listed below, compile-gate + `test_quick`
> on `mobile/game`, commit.

---

## Framework: Godot native mobile export (no engine switch)

Crownless is built in **Godot 4.4**, and Godot exports natively to both
Android and iOS from the same project. We do **not** rewrite or wrap the
game in another framework (Unity, Flutter, Capacitor, etc.) — we use
Godot's own export pipeline. The mobile version is a **snapshot fork of
the `game/` project** that lives here and is kept in sync with it (see the
agent policy above).

### How the pieces fit

```
mobile/
├── README.md            ← this file
├── game/                ← snapshot copy of the desktop project, adapted for mobile
│   ├── project.godot    ← mobile renderer + touch settings (diverges from desktop)
│   ├── export_presets.cfg  ← Android + iOS export presets (desktop's holds Win/mac/Linux)
│   └── ...
└── builds/              ← output .apk / .aab / .ipa (git-ignored)
```

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

## Mobile deltas (applied 2026-07-13; re-verified 2026-07-16)

The snapshot is a copy of `game/` with these — and only these — divergences.
On a re-sync (re-copy `game/` over `mobile/game/`), re-apply this exact list:

1. **`project.godot`** — the only source-of-truth file that still forks:
   - `[rendering] renderer/rendering_method="mobile"` +
     `renderer/rendering_method.mobile="gl_compatibility"` (Vulkan, GLES3 fallback).
   - `config/features=PackedStringArray("4.4", "Mobile")` (desktop: `"Forward Plus"`).
   - `[display]` add `window/stretch/aspect="expand"` and
     `window/handheld/orientation="landscape"`.
   - `[input_devices] pointing/emulate_touch_from_mouse=true` (lets the touch
     HUD be driven by the mouse on desktop for verification).
2. **`export_presets.cfg`** — this snapshot's copy holds the **Android + iOS**
   presets; `game/export_presets.cfg` holds Windows/macOS/Linux. Same filename,
   different content: a re-sync must NOT copy the desktop one over it.
3. **Mobile-only dev scenes** (not in `game/`): `shot_touch.gd/.tscn`,
   `shot_sf2.gd/.tscn`.
4. **`*.uid` files** — never copy these across. Godot mints resource UIDs
   per project, so the two trees legitimately hold different ones
   (`scripts/ui/touch_hud.gd.uid` is `dphdbd1k4na7b` in `game/`, `c4m34x3nb0j4r`
   here), and the mobile-only scenes in (3) resolve their scripts by **this**
   tree's UID. Copying `game/`'s over them breaks `shot_touch.tscn`. Sync the
   `.gd`, leave the `.uid`. (`.import` files are safe to copy — their `uid=`
   lines already agree.)

A correct re-sync leaves exactly these differences and nothing else: the files
in (1)-(2), and the (3)/(4) entries above. See "Verifying a re-sync" below for
how to compare without line endings hiding the drift.

### No longer deltas — the touch layer now lives in `game/` too

Commit `2fc4e72` ("unified Keyboard/Touch control scheme (works on desktop too)")
promoted the whole touch layer to the desktop project, so a re-sync just carries
these across like any other file. **Do not re-apply them as deltas, and do not
delete them from `game/` thinking they are mobile-only:**

- `scripts/mobile_input.gd` (autoload: analog move + held ability/action flags)
  and `scripts/ui/touch_hud.gd` (`class_name TouchHud`) — in BOTH projects.
- `[autoload] MobileInput="*res://scripts/mobile_input.gd"` — in BOTH
  `project.godot` files.
- `scripts/player_core.gd`'s `_poll_local_intents()` MobileInput merge (the §10
  touch seam) and `scripts/game.gd`'s `TouchHud` mount — identical in both.
  Desktop reaches touch mode via the `--touch` dev arg or the `touch_controls`
  setting (`game_base.gd`), not just `OS.has_feature("mobile")`.

The touch HUD is pure presentation: it only ever writes an intent seam, so no
gameplay/netcode forks per platform.

### Verifying a re-sync

`diff -rq game mobile/game -x .godot` is **blinded by line endings** — some
`game/` files are CRLF while their synced copies are LF, so whole files report
as differing and real drift hides in the noise. Compare content-only:

```
diff <(tr -d '\r' < game/scripts/foo.gd) <(tr -d '\r' < mobile/game/scripts/foo.gd)
```

(The `.uid` files for `mobile_input.gd`/`touch_hud.gd` differ between the two
projects and that is harmless — each project generates its own; nothing
references them by `uid://`.)

## Build commands

Run from the repo root with the bundled engine (`tools\Godot_v4.4.1-stable_win64_console.exe`):

```
# Reimport after any re-sync (new class_name / autoload → mandatory)
tools\Godot_v4.4.1-stable_win64_console.exe --headless --import --quit --path mobile/game

# Verify on THIS desktop first — mouse drives the touch controls:
tools\Godot_v4.4.1-stable_win64.exe --path mobile/game -- --touch

# Android APK (sideload testing) — needs the toolchain below configured:
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --export-release "Android" ../builds/Crownless.apk

# iOS (emits an Xcode project; sign + archive on a Mac):
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --export-release "iOS" ../builds/ios/Crownless.ipa
```

### Android toolchain — INSTALLED + wired (2026-07-13)

The Windows box now builds a signed debug APK end to end. Installed this session:

- **JDK 17** (Microsoft OpenJDK) → `C:\Users\asali\Java\jdk-17.0.19+10`.
- **Android SDK** (cmdline-tools + `platform-tools`, `build-tools;34.0.0`,
  `platforms;android-34`) → `%LOCALAPPDATA%\Android\Sdk`.
- **Debug keystore** → `%APPDATA%\Godot\keystores\debug.keystore` (alias
  `androiddebugkey`, store/key pass `android`).
- **Godot editor settings** (`%APPDATA%\Godot\editor_settings-4.4.tres`):
  `export/android/android_sdk_path`, `java_sdk_path`, and the `debug_keystore*`
  keys all point at the above.

Build the test APK (prebuilt-template path — no gradle needed):

```
set JAVA_HOME=C:\Users\asali\Java\jdk-17.0.19+10
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path mobile/game --export-debug "Android" mobile/builds/Crownless.apk
```

Produced `mobile/builds/Crownless.apk` (~361 MB, arm64-v8a, min SDK 21 / target
34, signed v1+v2+v3). Install on a plugged-in phone (USB debugging on):
`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe install -r mobile\builds\Crownless.apk`.

Note: `gradle_build/min_sdk` was emptied — the prebuilt template fixes min SDK
at 21 (a custom min like API 26 needs `use_gradle_build=true`).

### Still needing the owner's accounts

- **Android Play Store `.aab`:** flip `gradle_build/use_gradle_build=true` +
  `export_format=1`, install the Godot **Android build template**, then a Google
  Play dev account ($25 one-time) + a **release** keystore (keep it forever).
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
- [x] Android toolchain installed + signed debug APK builds locally (2026-07-13)
- [x] Cloud builds: GitHub Actions **"Mobile builds"**
      (`.github/workflows/mobile-builds.yml`) produces a signed-debug APK and an
      unsigned iOS `.ipa`; both install/run on-device via sideload (see
      `IOS_SIDELOAD.md`)
- [ ] Android Play Store `.aab` (gradle build template + Google Play account)
- [ ] iOS App Store signing (Apple Developer account — sideload works today)
- [ ] Store listings

This folder is **kept in sync** with `game/` — see the agent policy at the top.
