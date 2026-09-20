# Painted gems in Inventory

Inventory gem stacks, the item's **From your bag** picker and filled socket
buttons now use the existing 128px gem masters with linear filtering. This
removes the visibly coarse edges from the previous 32px nearest-filtered UI.
The controls retain their 48px bag/picker and 40px socket dimensions, count
badges, eligibility rules and existing input handlers. No assets were generated
or replaced. World, merchant, mail and drag-preview icon paths are unchanged.

`Art.gem_codex_icon` retains its existing stat/level cache and missing-master
fallback. Its behavior and the synthesis/socketing economy did not change.
Codex already uses these masters; no content or reference entry was added.
The static asset census finds all 140 existing gem variants have a 128px master.
This file/dimension check is separate from the selected native visual probes.

## Native checks

Run through the existing muted compile-first runner with isolated APPDATA:

```
shot.bat gems --equip-touch --timeout=300
shot.bat gems --synthesis-caps --timeout=300
```

Add `--mobile --renderer=gl_compatibility --touch` for the mobile source on the
development host. This does not constitute physical-device testing.

Both fixtures now share `scripts/tests/gem_ui_art_probe.gd`. Strict runs verify
the exact imported master, linear filtering, actual/minimum control geometry
and grouped counts. Picker observations use the detail overlay explicitly,
identify tooltip semantics before comparing pixels and retain eligibility
checks. Bag cells are matched to the fixture's ordered gem records; sockets
are matched by tooltip identity. These fixtures use the Gems filter and one
socketed gem per item, not arbitrary multi-socket loadouts. Missing masters
and null readbacks fail. The old gameplay, touch, scroll, stale-input, ledger
and restoration checks remain in place; historical baseline runs skip only
the new art observations.

The synthesis route adds one temporary factory-created special gem after its
maximum-level checks and a tenth screenshot. The next existing seed replaces
that loan; fixture cleanup restores the caller's original gem bag. Equipment,
currency and progression are controlled fixtures, not earned campaign play.

## Evidence and review

Session evidence lives under `build/qa/session-sept20/gem-ui-fidelity-next/`.
`acceptance.json` is written only after all required gates, exact source hashes,
preservation checks and reviews of native originals pass. Its commit receipt
is `build/qa/session-sept20/gem-ui-fidelity-commit-receipt.json`.

Actual Claude supplied the three production opt-ins and initial QA draft.
Actual DeepSeek supplied QA corrections and an evidence-collector draft.
Root rejected inaccurate selectors, optional missing-master/report checks and
copied historical evidence paths, retaining the raw drafts and correcting the
integrated implementation. An additional Claude source review was independently
checked against the actual menu code. Provider approval alone is not acceptance.

This is a narrow artwork improvement. Small equipment-stat text, coarse bag
capacity icons, very dim ineligible picker gems and compact detail actions
remain follow-up work. It does not establish whole-game visual quality,
worst-case cache performance or ordinary progression. ENet UI regressions do
not prove persistence roundtrips or real-scene disconnect cleanup.

Accepted checkpoint validation: desktop compile/quick/full; scoped mobile
sync/import/compile/strict quick; all seven strict preflight categories.
Equipment touch passes 70 checks on each project, synthesis 175 desktop / 179
host-mobile, Inventory 290 each and paired ENet UI 24 each. Eight final native
episodes provide 60 originals; actual Claude opened every original and root
reviewed selected images and provider findings independently. Existing renderer
texture-RID / RenderingServer and suite ObjectDB shutdown diagnostics remain
under the established verdict rules. Rejected drafts and the incorrectly scoped
first ENet visual brief are preserved separately, not counted as acceptance.
