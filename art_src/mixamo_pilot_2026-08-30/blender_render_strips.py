# Blender headless: Mixamo walk FBX -> 8-direction frame renders (mixamo pilot
# 2026-08-30). Run:
#   blender --background --python blender_render_strips.py -- \
#       --fbx archer_walk.fbx --out renders --frames 8 --cell 429 \
#       [--yaw0 0] [--ortho 2.4] [--feet 0.06]
# Renders <out>/<dir>/f<i>.png (transparent, cell x cell) for the 8 game
# facings sampled evenly over the action's loop. --yaw0 calibrates which way
# the model faces (Mixamo rigs vary): adjust after the first render so "s"
# shows her front. Assembly into engine strips + grading happens outside
# Blender (Claude's side).
import bpy
import math
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default

FBX = Path(arg("--fbx", "archer_walk.fbx")).resolve()
OUT = Path(arg("--out", "renders")).resolve()
N = int(arg("--frames", "8"))
CELL = int(arg("--cell", "429"))
YAW0 = float(arg("--yaw0", "0"))     # degrees; calibrate facing
ORTHO = float(arg("--ortho", "2.4")) # camera ortho scale (world units shown)
FEET = float(arg("--feet", "0.06"))  # feet line inset from frame bottom (frac)

# game facing name -> camera yaw relative to model front (deg, CCW from front)
DIRS = [("s", 0), ("se", 45), ("e", 90), ("ne", 135),
        ("n", 180), ("nw", 225), ("w", 270), ("sw", 315)]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") else "BLENDER_EEVEE"
sc.render.film_transparent = True
sc.render.resolution_x = CELL
sc.render.resolution_y = CELL
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"

bpy.ops.import_scene.fbx(filepath=str(FBX))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
act = arm.animation_data.action
f0, f1 = act.frame_range
loop = f1 - f0

# frame the model: measure its bounds from the meshes
import mathutils
mins = mathutils.Vector((1e9, 1e9, 1e9)); maxs = -mins
for o in bpy.data.objects:
    if o.type == "MESH":
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            mins = mathutils.Vector(map(min, mins, w))
            maxs = mathutils.Vector(map(max, maxs, w))
height = maxs.z - mins.z
center = (mins + maxs) / 2

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = height * ORTHO / 2.0
# scale-proof clipping: Mixamo FBX imports at cm scale (~180 units tall), so
# the default clip_end=100 sits INSIDE the camera orbit and renders nothing.
cam_data.clip_start = height * 0.01
cam_data.clip_end = height * 20.0
print("MODEL height", height, "center", tuple(round(v, 2) for v in center))
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam

# light: key top-left (the game convention), soft fill, faint rim
def add_sun(name, rot, energy):
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy
    o = bpy.data.objects.new(name, d)
    o.rotation_euler = rot
    sc.collection.objects.link(o)
add_sun("key", (math.radians(55), 0, math.radians(-30)), 3.0)
add_sun("fill", (math.radians(70), 0, math.radians(140)), 1.0)
add_sun("rim", (math.radians(-60), 0, math.radians(180)), 0.7)

def eval_center():
    """Evaluated world-space bbox center this frame — the walk may carry root
    travel (an un-ticked In Place, or hip curves); the camera follows the
    character exactly like the game's camera does."""
    dg = bpy.context.evaluated_depsgraph_get()
    lo = mathutils.Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        for c in ev.bound_box:
            w = ev.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, w))
            hi = mathutils.Vector(map(max, hi, w))
    return (lo + hi) / 2, lo.z

dist = height * 4
elev = math.radians(18)  # slight top-down, matching the game's 3/4 view
for dname, rel in DIRS:
    yaw = math.radians(YAW0 + rel)
    (OUT / dname).mkdir(parents=True, exist_ok=True)
    for i in range(N):
        sc.frame_set(int(round(f0 + loop * i / N)))
        c_now, floor_z = eval_center()
        cx = c_now.x + dist * math.cos(elev) * math.sin(yaw)
        cy = c_now.y - dist * math.cos(elev) * math.cos(yaw)
        cz = c_now.z + dist * math.sin(elev)
        cam.location = (cx, cy, cz)
        look = mathutils.Vector((c_now.x, c_now.y, floor_z + height * (0.5 - FEET))) - cam.location
        cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(OUT / dname / f"f{i}.png")
        bpy.ops.render.render(write_still=True)
    print(f"[{dname}] {N} frames")
print("RENDER DONE ->", OUT)
