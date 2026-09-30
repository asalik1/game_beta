"""Materialize the diagnosis fixture locally without changing production code.

Fixture files remain disposable/untracked. Acceptance constants are copied
verbatim from 91853fe because that lane is not merged into this checkout.
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def source(path):
    return subprocess.check_output(["git", "show", "91853fe:" + path], cwd=ROOT).decode("utf-8")


test = source("game/scripts/tests/test_boss_walk.gd")
test = test.replace("Balance.BOSS_WALK_FEET_STEP_MAX", "0.005")
test = test.replace("Balance.BOSS_WALK_CENTER_STEP_MAX", "0.02")
rig = source("game/shot_boss_walk.gd")
rig = rig.replace('res://scripts/tests/test_boss_walk.gd', 'res://t60b_metrics.gd')
# Godot enables callbacks on tree entry. Disable after add_child as well;
# otherwise this presentation-only fixture enters AI with no world assigned.
rig = rig.replace('\t\tadd_child(e)\n', '\t\tadd_child(e)\n\t\te.set_physics_process(false)\n')
# An explicit baseline switch reads the archived original through Godot; all
# presentation transforms, timing and acceptance checks remain the lane's.
rig = rig.replace('\t\te._apply_strip(info)\n', '\t\te._apply_strip(info)\n'
    '\t\tif flag("before") and key in ["morwen", "korrag"]:\n'
    '\t\t\tvar old_name: String = "morwen_walk.png" if key == "morwen" else "korrag_walk_codex_s.png"\n'
    '\t\t\tvar old_image := Image.load_from_file(ProjectSettings.globalize_path("res://../art_src/t60b_walk_alignment_2026-09-29/before/" + old_name))\n'
    '\t\t\te.sprite.texture = ImageTexture.create_from_image(old_image)\n')
scene = source("game/shot_boss_walk.tscn").replace('shot_boss_walk.gd', 'shot_t60b_walk.gd')
for name, content in (("t60b_metrics.gd", test), ("shot_t60b_walk.gd", rig), ("shot_t60b_walk.tscn", scene)):
    (ROOT / "game" / name).write_text(content, encoding="utf-8")
print("Prepared isolated lane fixture. No production scripts or balance knobs changed.")
