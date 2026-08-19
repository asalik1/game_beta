Generated once with the built-in `image_gen` tool.

- [Raw master](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\rat_rogue_attack\rat_rogue_attack_master_v1.png) — **1254×1254**, copied byte-for-byte without resizing.
- [Keyed RGBA master](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\pcmobs\rat_rogue_attack\rat_rogue_attack_master_v1_keyed.png) — auto-key border sampling and despill enabled.

Audit:

- Complete poses: **4**
- Wholly inside quadrants with clear gutters: **No.** The lower-left tail crosses the centerline by **42 pixels**. The other three poses and the strike weapon/arc are contained.
- Strike travels left: **Yes**
- Ready pose matches Image 1’s height: **No.** Generated height is **367 px** versus **146 px** in Image 1—about **2.5× too tall**.
- Per-row ground lines: aligned.
- Foot/torso anchor locking: imperfect; the figures drift within their cells.

Other defects:

- The raw background is neither uniform nor exact `#00ff00`. Auto-key sampled `#10f315`; a corner test contained 135 green variants and zero exact `#00ff00` pixels.
- The keyed output retains conspicuous green edge fringing and isolated green specks despite despill.
- Pixel clusters and outlines are substantially larger/thicker than the reference treatment.
- The slash streak is brighter and pinker than the requested dull rusty-weapon color.

No slicing or installation was performed, and nothing under the MMO project was touched. The final prompt retained the complete supplied brief, normalized only to explicitly map ready/wind-up/strike/follow-through to top-left/top-right/bottom-left/bottom-right.