extends SceneTree
## Dev probe: load every assets/videos/*.ogv and report; catches a file the
## theora decoder chokes on before a windowed rig crashes on it.

func _init() -> void:
	var dir := DirAccess.open("res://assets/videos")
	if dir == null:
		print("NO VIDEOS DIR")
		quit(1)
		return
	var bad := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".ogv"):
			var vs: VideoStream = load("res://assets/videos/" + f)
			if vs == null:
				print("FAIL load: " + f)
				bad += 1
			else:
				var pb: VideoStreamPlayback = vs.instantiate_playback()
				if pb == null:
					print("NOPB " + f)
					bad += 1
				else:
					print("OK   " + f)
		f = dir.get_next()
	print("VIDEO CHECK DONE bad=%d" % bad)
	quit(1 if bad > 0 else 0)
