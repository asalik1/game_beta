Created with built-in ImageGen and the skill’s chroma-key helper using border auto-sampling, soft matte, and despill.

- Raw: [cast_master_2x2_v1.png](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/stormmouth_cast_n/cast_master_2x2_v1.png) — **1254×1254 px**
- Keyed RGBA: [cast_master_2x2_v1_keyed.png](C:/Users/asali/Projects/MMO/art_src/drift_fix_2026-08-24/stormmouth_cast_n/cast_master_2x2_v1_keyed.png)

Blunt review:

- TL: **BACK view; face hidden.** Correct faint wind-up. No extra limbs or edge contact.
- TR: **BACK view; face hidden.** Distinct gathered lattice. No extra limbs or edge contact.
- BL: **BACK view; face hidden.** Strongest strike pose. No extra limbs; effect does not touch the edge, but has only **6 px** top clearance.
- BR: **BACK view; face hidden.** Clear release pose with fading motes. No extra limbs or edge contact.

Issues:

- Mild identity drift: armor is more symmetrical and slightly simplified versus the references; the chest core itself is hidden by the rear view.
- No obvious resizing, but both bottom-row figures slide upward by roughly **30–32 px** relative to the top row.
- The raw background failed the exact-color constraint: it is green but neither perfectly uniform nor exact `#00ff00`. The keyed result removes it cleanly, with no green-dominant visible pixels detected.
- No slicing or installation was performed. Only the two requested staging outputs were written.

The generation prompt was the supplied brief normalized into labeled production sections, with Image 1 locked as orientation and Images 2–3 restricted to identity/detail reference.