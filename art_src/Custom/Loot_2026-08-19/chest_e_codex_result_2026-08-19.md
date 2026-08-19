Generated exactly one unsliced master using built-in ImageGen.

- [Raw PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_e\chest_e_open_master_v1.png) — 1774×887 RGB
- [Keyed PNG](C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\e9942dba-d052-4194-9824-a200aaaa6d1b\scratchpad\loot\chest_e\chest_e_open_master_v1_keyed.png) — 1774×887 RGBA

Blunt QA:

- Complete figures: **5**, with clear gutters; none touch or are cropped.
- Body stability: **failed**. Ground line drifts downward 16 px from f1 to f5, the chest grows slightly, and its slot-relative position shifts. Later frames also become warmer.
- Lid progression: f1 closed; f2 is effectively closed with a glowing seam rather than a clearly visible crack; f3 opens, but appears below the requested 45°; f4 is fully open; f5 holds fully open with softer glow.
- Sparkle motes: **missing in f4**.
- Background: **failed exact specification**. It is variable green with zero exact `#00ff00` pixels; auto-key sampled `#08ef18`. The keyed output removes the green successfully with no strong-green figure pixels remaining.
- Style: prominent dark contours and polished 3D/game-icon shading remain. It does not match the softer outline-free painterly benchmark closely enough.
- No extra scenery, shadows, separators, text, UI, or watermark.

The supplied prompt was retained, with only corrupted punctuation normalized and the widest-landscape instruction made explicit.