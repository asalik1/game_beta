extends SceneTree
## DEV AUDIT (not part of the game): for every terrain prop/accent/landmark,
## compute the effective RESOLUTION the game renders it at — native source px
## vs the on-screen render width. scale = authored_w / native_w (props in
## Balance.SCENERY_RENDER_WIDTH) or native*3 (legacy default). scale > 1 = the
## source is UPSCALED (blocky); the bigger, the worse. Now that floors are
## native-res, the high-scale props read low-res beside them.
## Run: godot --headless --path game --script res://dump_prop_res.gd -- <out.csv>


func _collect_names() -> Array:
	# Only the SCATTER props (obstacles/decor/accents) + their variants — these
	# are sized by SCENERY_RENDER_WIDTH. Ecology/structures/capital are composite
	# LANDMARKS sized by _structure_sprite (explicit target_w), audited elsewhere.
	var seen := {}
	for tid in Terrains.DATA:
		var t: Dictionary = Terrains.DATA[tid]
		for tier in ["obstacles", "decor", "accents"]:
			for raw in t.get(tier, []):
				var n := String(raw)
				if not n.is_empty():
					seen[n] = true
					for v in Terrains.prop_family(n):
						seen[String(v)] = true
	return seen.keys()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://prop_res.csv"
	var rows: Array = []
	for name in _collect_names():
		var nm := String(name)
		var frames := 1
		var tex: Texture2D = null
		var anim: Dictionary = Art.anim_info(nm)
		var animated := not anim.is_empty()
		if animated:
			tex = anim["tex"]
			frames = int(anim["frames"])
		else:
			tex = Art.tex(nm)
		if tex == null:
			continue
		var native_w := float(tex.get_width()) / maxf(1.0, float(frames))
		# the game sizes a variant by its FAMILY BASE's authored width
		var base_nm := Terrains.prop_base(nm)
		var authored_w: float = float(Balance.SCENERY_RENDER_WIDTH.get(base_nm, native_w * 3.0))
		var scale := authored_w / maxf(1.0, native_w)
		var has_png := ResourceLoader.exists("res://assets/sprites/%s.png" % nm) \
			or (animated and ResourceLoader.exists("res://assets/sprites/%s_anim.png" % nm))
		var in_dict := Balance.SCENERY_RENDER_WIDTH.has(nm)
		var verdict := "crisp"
		if scale >= 2.6:
			verdict = "BLOCKY"
		elif scale >= 1.6:
			verdict = "soft"
		rows.append({"name": nm, "src": ("PNG" if has_png else "proc"),
			"anim": animated, "native_w": int(native_w), "render_w": int(authored_w),
			"scale": scale, "in_dict": in_dict, "verdict": verdict})
	rows.sort_custom(func(a, b): return a["scale"] > b["scale"])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_line("name,src,anim,native_w,render_w,scale,in_dict,verdict")
	for r in rows:
		f.store_line("%s,%s,%s,%d,%d,%.2f,%s,%s" % [r["name"], r["src"], r["anim"],
			r["native_w"], r["render_w"], r["scale"], r["in_dict"], r["verdict"]])
	f.close()
	# console summary: worst offenders
	print("=== PROP RESOLUTION AUDIT (%d props) — worst (most upscaled) first ===" % rows.size())
	var blocky := 0
	var soft := 0
	for r in rows:
		if r["verdict"] == "BLOCKY":
			blocky += 1
		elif r["verdict"] == "soft":
			soft += 1
	print("BLOCKY(>=2.6x): %d | soft(1.6-2.6x): %d | crisp: %d" % [blocky, soft, rows.size() - blocky - soft])
	for r in rows:
		if r["verdict"] != "crisp":
			print("  %-24s %s%s native=%d render=%d  %.1fx  %s" % [r["name"], r["src"],
				(" anim" if r["anim"] else "    "), r["native_w"], r["render_w"], r["scale"], r["verdict"]])
	print("CSV -> ", ProjectSettings.globalize_path(out_path))
	quit(0)
