extends ShotRig
## G2D BAKE RIG (2026-08-30, the 2D-skeletal pilot): assembles a cutout puppet
## from a parts kit + JSON rig spec, drives a parametric walk gait on its
## joints, and bakes the result into an ordinary engine strip PNG — the game
## never learns about bones; the rig is a strip factory. Run via shot.bat:
##
##   shot.bat g2d_bake --spec=<abs rig.json> --out=<abs strip.png>
##       [--frames=8] [--cell=429] [--feet=425] [--mirror]
##
## rig.json: {"scale": 1.0, "parts": [{"name","file","pivot":[x,y],
##   "parent":"" (root) | part name, "attach":[x,y] (joint pos in parent's
##   pivot space), "z": int}], "gait": {param overrides}}.
## The gait is pure math (per-phase joint rotations): hip swings drive the
## legs, knees flex on the swing, arms counter-swing, the cape lags, and the
## hips dip as the legs split — rotation about the hip makes the PLANTED foot
## sweep backward through the cell, which is the real treadmill stride.

var joints := {}          # part name -> Node2D (rotates about the joint)
var sprites := {}         # part name -> Sprite2D
var gait := {
	"hip_deg": 24.0,       # thigh swing amplitude
	"knee_deg": 34.0,      # swing-leg knee flexion
	"stance_knee_deg": 6.0,# planted-leg softening at load
	"arm_deg": 12.0,       # arm counter-swing
	"forearm_deg": 8.0,
	"torso_deg": 4.0,      # forward lean
	"torso_sway_deg": 1.5,
	"head_deg": 2.0,       # counter-rotation
	"cape_deg": 6.0,       # trailing lag
	"dip_px": 5.0,         # hips lower as the legs split
}

func _ready() -> void:
	step("load spec")
	var spec_path := arg("spec")
	var out_path := arg("out")
	var n := int(arg("frames", "8"))
	var cell := int(arg("cell", "429"))
	var feet_y := int(arg("feet", "425"))
	var f := FileAccess.open(spec_path, FileAccess.READ)
	if f == null:
		push_error("no spec at " + spec_path)
		finish(1)
		return
	var spec: Dictionary = JSON.parse_string(f.get_as_text())
	for k in spec.get("gait", {}):
		gait[k] = spec["gait"][k]

	step("build puppet")
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Node2D.new()   # the hips
	vp.add_child(root)
	var scale := float(spec.get("scale", 1.0))
	root.scale = Vector2(scale, scale)
	joints["root"] = root
	var base_dir := spec_path.get_base_dir()
	# Dependency-ordered build: a part may list a parent that appears later in
	# the spec (the head precedes the torso in slice order) — defer it until
	# the parent exists instead of dying on a missing joint key.
	var pending: Array = (spec["parts"] as Array).duplicate()
	while not pending.is_empty():
		var made := false
		for part in pending.duplicate():
			var pn := String(part.get("parent", ""))
			if not pn.is_empty() and not joints.has(pn):
				continue
			_build_part(part, base_dir)
			pending.erase(part)
			made = true
		if not made:
			push_error("unresolvable parent chain in rig spec")
			finish(1)
			return
		# (moved into _build_part)

	step("bake frames")
	var strip := Image.create(cell * n, cell, false, Image.FORMAT_RGBA8)
	for i in n:
		_pose(float(i) / float(n), cell, feet_y)
		await frames(2)
		var shotimg := vp.get_texture().get_image()
		strip.blit_rect(shotimg, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 0))
	if flag("mirror"):
		var m := Image.create(cell * n, cell, false, Image.FORMAT_RGBA8)
		for i in n:
			var c := strip.get_region(Rect2i(i * cell, 0, cell, cell))
			c.flip_x()
			m.blit_rect(c, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 0))
		strip = m
	strip.save_png(out_path)
	print("BAKED %d frames -> %s" % [n, out_path])
	finish(0)


func _build_part(part: Dictionary, base_dir: String) -> void:
	var img := Image.load_from_file(base_dir.path_join(part["file"]))
	var tex := ImageTexture.create_from_image(img)
	var joint := Node2D.new()
	var parent_name := String(part.get("parent", ""))
	var parent: Node2D = joints["root"] if parent_name.is_empty() else joints[parent_name]
	var attach: Array = part.get("attach", [0, 0])
	joint.position = Vector2(attach[0], attach[1])
	parent.add_child(joint)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.centered = false
	var pv: Array = part.get("pivot", [0, 0])
	spr.position = Vector2(-pv[0], -pv[1])  # pivot sits on the joint
	spr.z_index = int(part.get("z", 0))
	joint.add_child(spr)
	joints[part["name"]] = joint
	sprites[part["name"]] = spr


func _rot(name: String, deg: float) -> void:
	if joints.has(name):
		joints[name].rotation_degrees = deg


## One walk cycle over phase p in [0,1): right leg plants at p=0.
## Facing RIGHT; positive rotation swings a limb backward (clockwise).
func _pose(p: float, cell: int, feet_y: int) -> void:
	var w := TAU * p
	var hip: float = gait.hip_deg * sin(w)    # right thigh: + = back
	_rot("near_thigh", hip)
	_rot("far_thigh", -hip)
	# Knee: flexes while its leg swings forward (its thigh angle negative),
	# stays near-straight in stance with a soft load dip.
	var near_swing: float = clampf(-sin(w), 0.0, 1.0)
	var far_swing: float = clampf(sin(w), 0.0, 1.0)
	_rot("near_shin", -gait.knee_deg * near_swing - gait.stance_knee_deg * (1.0 - near_swing) * maxf(0.0, sin(w)))
	_rot("far_shin", -gait.knee_deg * far_swing - gait.stance_knee_deg * (1.0 - far_swing) * maxf(0.0, -sin(w)))
	_rot("near_upper_arm", -gait.arm_deg * sin(w))   # counter-swing
	_rot("far_arm", gait.arm_deg * sin(w))
	_rot("near_forearm", -gait.forearm_deg * sin(w) * 0.5)
	_rot("torso", 0.0)  # torso node carries the lean via root below
	_rot("cape", gait.cape_deg * sin(w - 0.9))       # trails the stride
	_rot("head", -gait.head_deg * sin(w) * 0.5)
	var root: Node2D = joints["root"]
	root.rotation_degrees = gait.torso_deg + gait.torso_sway_deg * sin(w * 2.0)
	# Hips dip as the legs split (double support), rise at the pass.
	var dip: float = gait.dip_px * absf(sin(w))
	root.position = Vector2(cell / 2.0, float(feet_y) - _leg_reach() + dip)


## Distance from hip joint to sole with legs vertical — sets the hips height
## so the planted sole rides the feet line. Measured once from the spec.
var _leg_len := -1.0
func _leg_reach() -> float:
	if _leg_len < 0.0:
		var thigh: Node2D = joints.get("near_thigh")
		var shin: Node2D = joints.get("near_shin")
		var boot: Sprite2D = sprites.get("near_shin")
		if thigh and shin and boot:
			_leg_len = thigh.position.y + shin.position.y \
				+ boot.position.y * -1.0 + boot.texture.get_height() \
				+ boot.position.y  # top offset + height = sole in joint space
			_leg_len = thigh.position.y + shin.position.y + (boot.texture.get_height() + boot.position.y)
		else:
			_leg_len = 180.0
	return _leg_len
