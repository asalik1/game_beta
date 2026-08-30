# Blender headless: any Meshy export (fbx/glb, extracted or not) -> Mixamo-ready
# zip (single mesh, no bones, <=50k tris, obj+mtl+texture). The three-failure
# lesson of 2026-08-30 mechanized: Mixamo's "unable to map your existing
# skeleton" fires (misleadingly) on armature stubs, on cinema-density meshes,
# AND on fused props/pose problems -- this script fixes the first two; the
# T-pose/no-prop half lives in PROMPT.txt at generation time.
#   blender --background --python prep_for_mixamo.py -- --in <model.fbx|.glb> \
#       [--tris 50000] [--out C:\Users\asali\Downloads\archer_mesh_for_mixamo]
# Writes <out>.zip. Texture: uses the model's base-color image if the importer
# binds one, else looks for a sibling .png next to the input.
import bpy
import os
import sys
import zipfile

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default

SRC = os.path.abspath(arg("--in", ""))
TRIS = int(arg("--tris", "50000"))
OUT = arg("--out", r"C:\Users\asali\Downloads\archer_mesh_for_mixamo")
WORK = OUT + "_work"
os.makedirs(WORK, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
if SRC.lower().endswith(".glb") or SRC.lower().endswith(".gltf"):
    bpy.ops.import_scene.gltf(filepath=SRC)
else:
    bpy.ops.import_scene.fbx(filepath=SRC)

for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.vertex_groups.clear()
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    dec = obj.modifiers.new("dec", "DECIMATE")
    dec.ratio = TRIS / tris
    bpy.ops.object.modifier_apply(modifier="dec")
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in obj.data.polygons))

# find the base color image bound to the material, save it beside the obj
tex_path = None
for mat in obj.data.materials:
    if not mat or not mat.use_nodes:
        continue
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            img = n.image
            tex_path = os.path.join(WORK, "archer_texture.png")
            img.filepath_raw = tex_path
            img.file_format = "PNG"
            img.save()
            break
    if tex_path:
        break
if not tex_path:
    sib = [f for f in os.listdir(os.path.dirname(SRC)) if f.lower().endswith(".png")]
    if sib:
        import shutil
        tex_path = os.path.join(WORK, "archer_texture.png")
        shutil.copyfile(os.path.join(os.path.dirname(SRC), sorted(sib)[0]), tex_path)

obj_path = os.path.join(WORK, "archer_mesh.obj")
bpy.ops.wm.obj_export(filepath=obj_path, export_materials=True, path_mode="COPY")
mtl_path = os.path.join(WORK, "archer_mesh.mtl")
if os.path.exists(mtl_path) and tex_path:
    lines = [l for l in open(mtl_path).read().splitlines()
             if not l.startswith(("map_Kd", "map_Ns", "map_refl", "map_Bump"))]
    lines.append("map_Kd archer_texture.png")
    open(mtl_path, "w").write("\n".join(lines) + "\n")

with zipfile.ZipFile(OUT + ".zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in ["archer_mesh.obj", "archer_mesh.mtl", "archer_texture.png"]:
        p = os.path.join(WORK, f)
        if os.path.exists(p):
            z.write(p, f)
print("MIXAMO PACKAGE ->", OUT + ".zip")
