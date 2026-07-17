# DISTRIBUTION.md — cutting and shipping the friends build (owner playbook)

*MP-18. The friends-.exe phase: hand a zip to 1–3 friends, they join by lobby code. No
Steam, no store, no accounts. The design rationale lives in **MULTIPLAYER.md §7**
(distribution) and **§3.2** (noray now / self-host later). This file is the operational
checklist plus the decisions that are yours to make.*

---

## 1. One-command release

```bat
make_build.bat
```

From the repo root. It fails loudly at every step, in this order (house rule — compile gate
first, always):

1. **Compile gate** (`check_compile.gd`) — surfaces any parse error in ~3s.
2. **`test_quick.bat`** — gate + boot + one class kit + systems + UI smoke + pause menu.
3. **Audio manifest** — regenerates `game/assets/asset_manifest.json` (exported builds can't
   scan the sound/music folders; they read this manifest). Best-effort: falls back to the
   committed manifest if Python is absent, but fails if the manifest is missing entirely.
4. **Headless export** — Godot 4.4.1 exports the **Windows Desktop** preset to
   `build/Crownless.exe` (single self-contained exe — see §3).
5. **Zip** — bundles the exe + `FRIENDS_README.txt` + `CREDITS.txt` into
   `build/Crownless_<NET_VERSION>_win64.zip`.

`build/` is gitignored. The zip name's version is read live from `NET_VERSION` so it can
never drift from the gate the game actually enforces.

> Not to be confused with **`export_all.bat`** — that's the older multi-platform *solo
> playtest* pipeline (Windows/macOS/Linux → `executables/`). `make_build.bat` is the
> co-op **friends zip** flow specifically. Both drive the same `game/export_presets.cfg`.

### What's in the zip (and why)
| File | Why it's there |
|---|---|
| `Crownless.exe` | The whole game — a single self-contained executable (pck embedded). |
| `FRIENDS_README.txt` | Non-technical setup: extract-first, the one-time SmartScreen click, how to join by code, "same version" note, three-line troubleshooting. |
| `CREDITS.txt` | Third-party license notices (Godot + netfox, both MIT). Ships next to the exe **and** is baked into the pck — see §6. |

---

## 2. Before you cut a build: bump `NET_VERSION`?

**The one constant that gates cross-build play:** `NET_VERSION` in
`game/scripts/net/net_manager.gd` (currently `"0.1.0"`).

- The join handshake (`net_manager.gd`, `_on_auth_received`) compares it **exactly**. A
  mismatch is a clean refusal that **names both versions** ("host runs 0.1.0, you run 0.1.1")
  — never a half-join, never a silent desync.
- It's printed on the **title screen** ("build 0.1.0"), and in the Host/Join lobby panels and
  the codex co-op page. Every one of those reads the const directly (verified — no drifted
  literals anywhere), so bumping the const updates all of them at once.

**Bump it whenever a change breaks cross-build play** — any netcode change (RPC shape, sync
packet layout, session flow) or any content/seed change that would make two builds diverge
(world-gen, enemy stats, loot). Skip the bump only for changes that can't desync a session
(a title-screen typo, a sound swap). When in doubt, bump — the cost of a needless bump is
"everyone re-downloads"; the cost of a missed bump is a corrupt-looking session.

**Reship the whole zip on every bump.** Because the pck is embedded, there's no "just send
the new pck" — and the handshake requires matched builds anyway, so partial updates were
never on the table.

---

## 3. Preset decisions (`game/export_presets.cfg`, preset "Windows Desktop")

- **`embed_pck=true` → one self-contained `Crownless.exe` (~260 MB).** Chosen over exe+loose-pck
  for a non-technical audience: a friend physically *cannot* separate the exe from its data
  and hit the classic "it won't launch" failure. One file in, one file out. The size penalty
  (~97 MB engine template baked in) is irrelevant for a zip shared among friends. Trade-off
  accepted: no pck-only hot-patching — but the version gate forbids mixed builds regardless.
- **`export_filter="all_resources"`**, architecture **x86_64**, release template.
- **`include_filter`** force-packs the non-resource files (Godot only auto-packs *resources*):
  `assets/asset_manifest.json` (runtime audio list) **and** the license notices
  (`addons/CREDITS.txt`, both netfox `LICENSE` files) — see §6.
- A `.console.exe` sidecar may be produced by the export (the preset keeps the console
  wrapper for the solo playtest flow). `make_build.bat` deliberately zips **only**
  `Crownless.exe`, so it never reaches friends.
- **Owner nicety, not blocking:** the exe's *file* icon is the Godot default
  (`application/icon` is empty — a custom one needs a `.ico`; the in-game window/taskbar icon
  already comes from `icon.svg`). Add a `.ico` here later if you want the branded desktop icon.
- **Expected non-fatal export warning:** *"Could not start rcedit executable."* The preset has
  `Application > Modify Resources` on (to stamp the exe's Windows file metadata — company /
  product / version — which the filled-in `company_name`/`product_name` clearly intend), but
  Godot needs the external **rcedit** tool to write it, and it isn't configured. The export
  still succeeds; only the exe's Properties → Details metadata (and a custom `.ico`) go
  unstamped. To clear it: install rcedit and set its path in *Editor Settings → Export →
  Windows → rcedit*. (Or set `application/modify_resources=false` to silence it and forgo the
  metadata — not recommended given the intent above.)

---

## 4. SmartScreen & antivirus — the reality, and the escalation ladder

Unsigned indie exes trip two things. Both are expected; neither means anything is wrong.

- **SmartScreen** ("Windows protected your PC") fires **once per build** because the exe is
  unsigned and has no reputation. Fix: *More info → Run anyway*. `FRIENDS_README.txt` says
  exactly this. Tell friends in the same message as the join code.
- **AV false positives** occasionally quarantine Godot exports (a known engine-wide heuristic
  issue, not specific to us). Fix: restore from quarantine + exclude the folder.

**Escalation ladder — climb it only as distribution widens:**
1. **Now (friends):** do nothing. The one-time click is fine; submitting false positives isn't
   worth it at this scale.
2. **If an AV keeps flagging it:** submit the exe as a false positive to Microsoft (and the
   offending vendor). Free, clears that engine/heuristic combo for a while.
3. **If you hand it past your friend circle (itch, a wider beta):** **Azure Artifact Signing**
   (formerly Trusted Signing) — ~$10/mo, open to individuals. Signing attaches a publisher
   name and builds SmartScreen reputation faster. Note: even signed builds start *cold* with
   SmartScreen until reputation accrues.
4. **Steam:** the problem vanishes — Steam-installed games don't hit SmartScreen at all.

---

## 5. noray posture — public now, self-host later (**owner decision**)

Join codes ride **noray** (NAT punchthrough + relay fallback). See **MULTIPLAYER.md §3.2**.

- **Now (friends):** the **free public instance `tomfol.io:8890`** (in `net_manager.gd`:
  `NORAY_ADDRESS`/`NORAY_PORT`) — explicitly offered by the netfox author for prototyping,
  exactly the friends phase. **$0.** No uptime guarantee, which is fine here.
- **Self-host becomes REQUIRED before** (a) distribution widens past friends / the public
  instance's limits pinch, **or** (b) the mobile port ships (cross-play leans on noray
  permanently — §3.2). This is your call on timing.
- **The self-host is one Docker evening** (from §3.2): run the noray image on a ~$5/mo VPS,
  expose **TCP 8890/8891** + a **UDP range**, point `NORAY_ADDRESS` at your host. A fully
  *relayed* 4-player session is <1 Mbps — rounding error against a 20 TB/mo allowance.
  Budget: **$0 now, ~$5/mo later.**

Rejected alternatives are logged in §3.2 (UPnP, IP-encoded codes, GD-Sync, EOS, W4/Nakama) —
don't re-litigate them without a new reason.

---

## 6. License compliance — Godot + netfox (both MIT)

MIT requires the copyright + permission notice to ship with any distributed copy. Status:
**compliant, two ways over.**

- **Authoritative:** `CREDITS.txt` ships **inside the zip**, next to the exe — human-readable,
  guaranteed present in the distribution. It carries the netfox MIT notice (Gálffy Tamás) and
  the full Godot Engine MIT notice. Source of truth: `game/addons/CREDITS.txt`.
- **Belt-and-braces:** the preset's `include_filter` now also **bakes** `addons/CREDITS.txt`
  and both netfox `LICENSE` files into the pck (verified present in the exported exe). This is
  what an in-game credits reader would surface later.
  - *Why this needed fixing:* under `all_resources`, Godot packs **resources** but not plain
    `.txt`/`LICENSE` files — those must be named in `include_filter`. Before MP-18 the filter
    listed only the audio manifest, so the notices weren't in the pck. Now they are.
- **If you add a third-party asset/library:** add its notice to `game/addons/CREDITS.txt` (and
  its `LICENSE` path to `include_filter` if it's a new addon). Asset-license rules live in
  `CLAUDE.md` → "Asset sourcing" (CC0 / permissive only; this game ships commercially).

---

## 7. The futures this is already shaped for (read before re-architecting)

Nothing here needs a rewrite to reach the next milestones — the seams exist by construction:

- **Steam transport** — `SteamMultiplayerPeer` drops in behind `NetworkManager`; lobby codes
  become Steam invites; all `@rpc`/sync code is unchanged. On Steam, SmartScreen is moot.
  Read **MULTIPLAYER.md §3.2** ("Later (Steam)") and **§10 (1)**.
- **Mobile port** — the same netcode compiles for Android/iOS and joins the same sessions via
  the same noray path (the noray/ENet transport is kept *permanently* as the cross-play seam,
  even after the Steam swap). The `NET_VERSION` handshake fences the frozen `mobile/` snapshot
  out of live sessions until it's re-cut from the same revision. **§10** — and remember
  `mobile/` stays frozen (`CLAUDE.md`) until you explicitly greenlight mobile work.
- **Dedicated server / MMO** — every gameplay branch keys on `multiplayer.is_server()`, never
  "am I player 1," so a headless server is a deployment change, not a redesign. **§10 (2–3)**.

---

*Quick reference: `make_build.bat` (cut it) · `FRIENDS_README.txt` (what friends read) ·
`game/export_presets.cfg` (the preset) · `net_manager.gd` `NET_VERSION` (the gate) ·
MULTIPLAYER.md §3.2/§7/§10 (the reasoning).*
