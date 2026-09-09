extends RefCounted
## Diagnostic only. Wrappers execute the original native operations exactly once.
## Counts describe these instrumented callsites, never uninstrumented timings.
static var sites: Dictionary = {}
static var _phase: String = ""
static var _counts: Dictionary = {}


static func note_site(site: String) -> void:
	sites[site] = true


static func begin_phase(label: String) -> bool:
	if _phase != "":
		return false
	_phase = label
	_counts = {}
	return true


static func finish_phase() -> Dictionary:
	var result: Dictionary = {"phase": _phase, "by_site": _counts.duplicate(true)}
	_phase = ""
	_counts = {}
	return result


static func _add(site: String, operation: String, pixels: int) -> void:
	if _phase == "":
		return
	if not _counts.has(site):
		_counts[site] = {"readbacks": 0, "scans": 0, "read_pixels": 0, "scan_pixels": 0}
	var row: Dictionary = _counts[site]
	row[operation] = int(row[operation]) + 1
	var pixel_key: String = "read_pixels" if operation == "readbacks" else "scan_pixels"
	row[pixel_key] = int(row[pixel_key]) + pixels


static func readback(texture: Texture2D, site: String) -> Image:
	_add(site, "readbacks", texture.get_width() * texture.get_height())
	return texture.get_image()


static func used_rect(image: Image, site: String) -> Rect2i:
	_add(site, "scans", image.get_width() * image.get_height())
	return image.get_used_rect()
