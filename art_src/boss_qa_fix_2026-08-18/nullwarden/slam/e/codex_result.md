Generated exactly one master using built-in ImageGen.

Files:

- [slam_master_2x2_v1.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/slam/e/slam_master_2x2_v1.png) — raw, **1254×1254 px**
- [slam_master_2x2_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/boss_qa_fix_2026-08-18/nullwarden/slam/e/slam_master_2x2_v1_keyed.png) — RGBA, auto-key sampled with despill and soft matte

All four poses are visibly different:

1. Coiled overhead wind-up.
2. Fully stretched overhead peak.
3. Low two-fist ground slam.
4. Crouched recovery with hands lifting.

Defects:

- The raw background is not uniform `#00ff00`; it contains **zero exact `#00ff00` pixels** and has visible green variation. Auto-key sampled `#0bf805`.
- Anchor consistency fails: frames 3–4 sit about **80–81 px higher** than frames 1–2. Horizontal centers also drift by up to roughly 19 px.
- Frame 3 has an oversized cyan ground arc/shockwave, exceeding the permitted faint hand-contact spark.
- Frame 4 remains deeply crouched and only weakly communicates “rising back up.”
- The profile armor is recognizable and palette-consistent, but some shoulder/chest detailing drifts from the reference rather than being an exact rotation.
- No weapons, extra heads, obvious extra limbs, edge-touching effects, or wrong-facing frames were found.

Final prompt followed the supplied brief, with the later right-profile instruction explicitly treated as overriding the contradictory earlier front-facing wording.