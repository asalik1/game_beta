"""Assemble the granular review README from the three hand-written parts + generated appendices."""
import json, re, subprocess, pathlib, collections

ROOT = pathlib.Path(r"C:\Users\asali\Projects\MMO\.claude\worktrees\epic-panini-3fd8fd")
ART = ROOT / "art_src"
QA = ART / "_qa_final"
GIFS = pathlib.Path(r"C:\Users\asali\Downloads\ba_gifs_visual_overhaul")
SPR = ROOT / "game" / "assets" / "sprites"
BASE = "7fd27a4"

parts = [(ART / f"_review_readme_part{i}.md").read_text(encoding="utf-8") for i in (1, 2, 3)]

# ---- subject -> gif stems, in folder order
subjects = []  # (cat, subject, [stems])
for cat in ("classes", "bosses", "mobs", "npcs", "capital", "props", "travel"):
    d = GIFS / cat
    if not d.exists():
        continue
    for sub in sorted(p for p in d.iterdir() if p.is_dir()):
        stems = sorted(g.stem for g in sub.glob("*.gif"))
        subjects.append((cat, sub.name, stems))


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def trunc(s, n=170):
    s = " ".join(s.split())
    if len(s) <= n:
        return s
    cut = s[:n].rsplit(" ", 1)[0]
    return cut + " ..."


# ---- Appendix A: per-subject change log from git
recentre_only = []  # mob subjects touched only by the seam-sweep commit
a_lines = []
for cat, sub, stems in subjects:
    if cat == "travel":
        continue
    files = []
    for st in stems:
        if cat == "travel":
            continue
        base = st.replace("_old_vs_new_travel", "").replace("__vs__1more_travel", "")
        p = SPR / f"{base}.png"
        if p.exists():
            files.append(str(p.relative_to(ROOT)).replace("\\", "/"))
        elif (SPR / "ground" / f"{base}.png").exists():
            files.append(str((SPR / "ground" / f"{base}.png").relative_to(ROOT)).replace("\\", "/"))
        else:
            # sprites in subfolders (skins, capital, ground tiles)
            hits = list(SPR.rglob(f"{base}.png"))
            files += [str(h.relative_to(ROOT)).replace("\\", "/") for h in hits]
    subs = [l for l in git("log", "--format=%s", f"{BASE}..HEAD", "--", *files).splitlines() if l.strip()] if files else []
    seen, uniq = set(), []
    for s in subs:
        if s not in seen:
            seen.add(s); uniq.append(s)
    a_lines.append(f"- **{cat}/{sub}** ({len(stems)} GIF{'s' if len(stems) != 1 else ''}: {', '.join(stems)})")
    for s in uniq:
        a_lines.append(f"  - {trunc(s)}")
    if cat == "mobs" and len(uniq) == 1 and uniq[0].startswith("Corpus seam sweep"):
        recentre_only.append(sub)
appendix_a = "\n".join(a_lines)

# ---- Appendix B + recentre-only table
rt = json.loads((QA / "_recenter_table.json").read_text(encoding="utf-8"))
idles, walks = rt["idles"], rt["walks"]


def table(rows, hdr):
    out = [f"| {hdr[0]} | {hdr[1]} |", "|---|---:|"]
    out += [f"| {a} | {b} |" for a, b in rows]
    return "\n".join(out)


b_idle = table(sorted(idles.items(), key=lambda x: -x[1]), ("idle strip", "drift px"))
b_walk = table(sorted(walks.items(), key=lambda x: -x[1]), ("legacy walk strip", "drift px"))
appendix_b = f"**Idles (68)**\n\n{b_idle}\n\n**Legacy walks (97 applied; the table lists the 111 measured, the 14 gait-lane walks were restored)**\n\n{b_walk}"

ro_rows = []
for sub in recentre_only:
    i = idles.get(f"{sub}_anim.png", idles.get(f"{sub}_anim_codex.png"))
    w = walks.get(f"{sub}_walk.png")
    ro_rows.append(f"| {sub} | {i if i is not None else '-'} | {w if w is not None else '-'} |")
recentre_table = "| subject | idle drift px | walk drift px |\n|---|---:|---:|\n" + "\n".join(ro_rows)
recentre_table += f"\n\n({len(recentre_only)} subjects; a dash means that strip was already on its grid.)"

# ---- Appendix C: audit findings with status
STATUS = {
    1: "FIXED: the two shards composited from the idle onto every frame",
    2: "FIXED: frame 2 dropped (5-frame glide)",
    3: "FIXED: slivers dropped",
    4: "FIXED: slivers dropped",
    5: "FIXED: v3 roll, a real stride (rear boot lifts 25 to 70 px)",
    6: "LEFT: your call; three rolls, the generator will not give back-view pauldron mass",
    7: "LEFT: your call (no rear crest from behind)",
    8: "FIXED: v3 carries the family's blue-steel plate",
    9: "FIXED: frame 2 dropped",
    10: "FIXED: frame 2 dropped",
    11: "FIXED: shards composited",
    12: "FIXED: slivers dropped",
    13: "FIXED: attack_walk_s shifted onto walk_s",
    14: "FIXED (stroke dropped); the 1 to 4 px keying specks LEFT, sub-pixel",
    15: "FIXED: pouch pasted onto all five idle frames",
    16: "FIXED: skull composited from frame 0",
    17: "FIXED: skull composited from frame 0",
    18: "FIXED: skull composited from frame 0",
    19: "FIXED: skull composited from frame 0",
    20: "FIXED: the W family re-mirrored from the fixed E",
    21: "SUPERSEDED: attack_walk_e family regenerated from the new profile walk; the trim still reads about 5 degrees yellower (Your calls)",
    22: "SUPERSEDED: same regen",
    23: "SUPERSEDED: same regen",
    24: "FIXED: attack_walk_n regenerated from walk_n",
    25: "FIXED: same regen",
    26: "LEFT: sub-pixel specks",
    27: "FIXED: frames 0/1/6 normalised to frame 2's body, re-installed",
    28: "FIXED: cast installed into a 320 px cell",
    29: "FIXED: pouch pasted onto cast frame 0",
    30: "FIXED: pouch pasted onto the idle",
    31: "FIXED: v2 attack roll, staff in the near hand",
    32: "FIXED: v2 roll, head-top 23 px in all seven frames",
    33: "LEFT: 5 percent vs the S idle after the pouch paste, inside the 8 percent bar",
    34: "FIXED: cycle rebuilt as frames 0 to 2 plus their mirrors",
    35: "LEFT: noted; your eye on the S to N turn",
    36: "LEFT: by design, the engine reads the frame count from the strip",
    37: "FIXED: 31 px fleck dropped from frames 0 and 3 (frame_fix --drop-orphans, the last edit on the branch)",
    38: "LEFT: alpha 1 to 38 residue, sub-pixel in play",
    39: "LEFT: pre-existing on main",
    40: "LEFT: 8.5 percent, at the bar",
    41: "FIXED: v3 stride",
    42: "LEFT: your call",
    43: "SUPERSEDED: v3 strip",
    44: "SUPERSEDED: v3 strip",
    45: "LEFT: your call (regen vs the re-sliced old cycle)",
    46: "LEFT: your call",
    47: "LEFT: your call",
    48: "LEFT: sub-pixel",
    49: "FIXED: idle centred (the later corpus recentre emptied its last frame; the centred version was restored)",
    50: "PARTLY: the plate tone fixed by v3; the bulk LEFT (your call)",
    51: "FIXED: tone-matched to the idle",
    52: "FIXED: tone-matched, E family copies and mirrors rebuilt",
    53: "LEFT: noted",
    54: "LEFT: P3",
    55: "LEFT: P3, pre-existing",
    56: "LEFT: P3, far-side occlusion is plausible",
    57: "LEFT: P3, pre-existing",
}
c_lines = []
for n, line in enumerate((QA / "_audit_findings.txt").read_text(encoding="utf-8").splitlines(), 1):
    m = re.match(r"\[(.*?)\]\s+(P\d)\s+(\S+)\s+(f\S+):\s*(.*)", line)
    if not m:
        continue
    subj, pri, fil, fr, claim = m.groups()
    c_lines.append(f"{n}. `{fil}` {fr} ({pri}, {subj}): {trunc(claim, 230)}\n   {STATUS[n]}")
appendix_c = "\n".join(c_lines)

doc = "\n".join(parts)
doc = doc.replace("{{RECENTRE_ONLY_TABLE}}", recentre_table)
doc = doc.replace("{{APPENDIX_A}}", appendix_a).replace("{{APPENDIX_B}}", appendix_b).replace("{{APPENDIX_C}}", appendix_c)
assert "{{" not in doc
total = sum(len(s) for _, _, s in subjects)
doc = doc.replace("__TOTAL_GIFS__", str(total))
(GIFS / "README.md").write_text(doc, encoding="utf-8")
(ART / "REVIEW_README_2026-09-05.md").write_text(doc, encoding="utf-8")
print(f"wrote {len(doc)} chars, {doc.count(chr(10))} lines, {total} gifs, recentre-only {len(recentre_only)}, findings {len(c_lines)}")
