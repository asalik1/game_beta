Generated with the built-in ImageGen tool:

- [cast_nw_v1.png](C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/cast_nw/cast_nw_v1.png) — raw, 2172×724
- [cast_nw_v1_keyed.png](C:/Users/asali/Projects/MMO/.claude/worktrees/focused-bhaskara-90aea6/art_src/warlock_unify_imagegen_2026-08-24/cast_nw/cast_nw_v1_keyed.png) — RGBA, auto-key sampled `#05f905`, soft matte and despill enabled

Blunt QA:

- All nine figures were produced in one row, with visibly different poses and clean 28–57 px gutters.
- The warlock stayed lean/slender and consistently rear-left/NW-facing. Hooded face remained hidden; frame 9 did not flip.
- Anchoring and scale are good: body heights vary only 313–316 px and head/feet move by roughly 2 px.
- Major defect: this is not nine equal square cells. The 2172×724 canvas is 3:1 and is not divisible into nine equal-width cells. Nominal equal cuts intersect frames 4, 5, 6, and 9.
- The figures occupy only about 44% of canvas height, not the requested 66%.
- The raw background is not uniform `#00ff00`; it contains thousands of slight green variations around `#05f905`. The keyed result removes the visible green contamination.
- The vertical dark-gold tabard/chest treatment is largely missing, so robe fidelity drifted.
- The grimoire disappears or morphs into a casting hand in frames 3, 4, 6, and 7. It was not swapped with the skull; it is simply absent.
- The skull remains on the correct side throughout. No obvious extra limbs or large forbidden rift effect.
- The “both hands tearing” action is inconsistent because several frames read as one-hand casting. Frame 6 reads as the peak, but frame 5’s total silhouette is one pixel wider.
- No character or effect touches the outer canvas edge.

Final prompt was the supplied nine-frame Void Rift brief, normalized into labeled sections with the reference roles and facing lock reinforced.