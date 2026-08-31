"""Stage the Vargoth N-facing ability regen (attack_n + blade_n front-view defect).

Builds the two codex stages' refs:
  ref1_identity_back.png  = frames 0+3 of the FIXED vargoth_walk_codex_n (helm-fix
                            re-roll, 2026-08-31 — taken from the main checkout's
                            working tree; also copied to walk_fixed_n_reference.png
                            here for provenance since that fix is not committed yet)
  ref2_action_front.png   = the strip whose choreography/palette the regen keeps
                            (attack: the outgoing attack_n; blade: blade_s — the
                            cleanest read of the skyblade raise; outgoing blade_n
                            is a byte-copy of blade_e)
Backs up the outgoing strips into old_backup/.
"""
from pathlib import Path

from PIL import Image

JOB = Path(__file__).resolve().parent
WT = JOB.parents[1]                      # the worktree root
MAIN = Path("C:/Users/asali/Projects/MMO")  # fixed walk lives only in main's dirty tree
SPRITES = WT / "game" / "assets" / "sprites"

FIXED_WALK_N = MAIN / "game" / "assets" / "sprites" / "vargoth_walk_codex_n.png"


def crop_frames(strip_path: Path, idx: list[int]) -> Image.Image:
    im = Image.open(strip_path).convert("RGBA")
    w, h = im.size
    n = max(1, round(w / h))
    fw = w // n
    frames = [im.crop((i * fw, 0, (i + 1) * fw, h)) for i in idx]
    out = Image.new("RGBA", (fw * len(frames), h), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        out.alpha_composite(f, (k * fw, 0))
    return out


def main() -> None:
    (JOB / "old_backup").mkdir(parents=True, exist_ok=True)
    for name in ("vargoth_attack_n.png", "vargoth_blade_n.png"):
        src = SPRITES / name
        dst = JOB / "old_backup" / name
        if not dst.exists():
            dst.write_bytes(src.read_bytes())
            print(f"backed up {name}")

    walk_copy = JOB / "walk_fixed_n_reference.png"
    walk_copy.write_bytes(FIXED_WALK_N.read_bytes())
    print(f"copied fixed walk_n reference ({FIXED_WALK_N})")

    ref1 = crop_frames(walk_copy, [0, 3])
    for stage, action_src in (("attack_n", SPRITES / "vargoth_attack_n.png"),
                              ("blade_n", SPRITES / "vargoth_blade_s.png")):
        refs = JOB / stage / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        ref1.save(refs / "ref1_identity_back.png")
        (refs / "ref2_action_front.png").write_bytes(action_src.read_bytes())
        print(f"staged {stage}: ref1 {ref1.size}, ref2 <- {action_src.name}")


if __name__ == "__main__":
    main()
