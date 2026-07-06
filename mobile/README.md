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

## Build commands (once presets exist)

```
# Android (from Windows, headless)
godot --headless --path mobile/game --export-release "Android" builds/emberfall.aab

# iOS (produces an Xcode project; sign + archive on a Mac)
godot --headless --path mobile/game --export-release "iOS" builds/emberfall-ios
```

## Status

- [x] Folder + plan (this README)
- [ ] Snapshot `game/` → `mobile/game/`
- [ ] Renderer + project settings divergence
- [ ] Touch input layer
- [ ] UI / safe-area pass
- [ ] Android export preset + test build on device
- [ ] iOS export preset + Mac signing pipeline
- [ ] Store listings

Nothing below "Folder + plan" happens until the user asks for mobile work.
