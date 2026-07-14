# iOS — sideload to your OWN iPhone (no Mac, no $99)

Goal: get Emberfall running on **your** iPhone to feel the touch controls,
before spending a cent on an Apple Developer account. Compilation happens on
a rented macOS CI runner; signing + install happen on your Windows PC with a
free Apple ID.

> For getting it onto **friends'** phones, this route does NOT scale (each
> person needs their own PC + refresh). That's when the $99 Apple Developer
> account + TestFlight becomes worth it — a separate pipeline.

## The two halves

### 1. Cloud build (GitHub Actions) → produces an unsigned `.ipa`

Workflow: [`.github/workflows/mobile-builds.yml`](.github/workflows/mobile-builds.yml)

1. Push this branch to `origin` (GitHub).
2. GitHub → **Actions** tab → enable workflows if prompted.
3. Run **"Mobile builds"** → **Run workflow** → set **platform = ios** (default
   is `android`, so you must switch it to build the IPA).
4. When green, open the run → download the **`Emberfall-ios-unsigned-ipa`**
   artifact (a zip containing `Emberfall-unsigned.ipa`) to your PC.

Cost: private-repo macOS minutes bill at **10×** — roughly 8–13 free builds
a month. First run may go red once (see the workflow's "FIX POINT" note).

### 2. Windows sideload (free Apple ID) → installs to your iPhone

**Sideloadly** (simplest) or **AltStore** (auto-refreshes past the 7-day limit):

1. Install Apple's **Devices/iTunes** driver (Sideloadly + AltStore both need
   it to talk to the phone) — the non-Microsoft-Store version.
2. **Sideloadly:** plug in iPhone → drop in `Emberfall-unsigned.ipa` → sign in
   with a free Apple ID → Start. It re-signs (rewrites the bundle id) and
   installs. On the phone: Settings → General → VPN & Device Management →
   trust your Apple ID's developer cert.
3. **AltStore (optional, better):** install AltServer on the PC, keep it
   running on the same Wi-Fi; it refreshes the app every few days so it
   doesn't die.

## The limits (so they don't surprise you)

- **Free Apple ID app certs expire after 7 days** → the app stops opening
  until re-signed. Sideloadly = re-run it; AltStore = auto-refresh.
- Free tier allows a small number of sideloaded apps / registered devices.
- Push notifications and some entitlements are unavailable on free signing —
  irrelevant for a game.

## If the CI route fights you

Any Mac for one hour is Plan B: plug the iPhone in, sign with a free Apple ID
as a "personal team", build straight from Xcode. Same 7-day limit, far less
setup. The CI route only wins if you have **zero** Mac access at all.
