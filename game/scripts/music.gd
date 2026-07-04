class_name Music
## Procedural chiptune: looping background tracks synthesized at boot,
## one per zone plus a unique theme per boss. No audio files.
##
## A track spec is: bpm, root frequency, a melody (semitone offsets from
## the root, -99 = rest, one entry per 8th note) and a bass line (one
## entry per quarter note). Kick on every half bar, hats on off-beats.

const RATE := 16000


static func _synth(spec: Dictionary) -> AudioStreamWAV:
	var bpm: float = spec["bpm"]
	var step := 60.0 / bpm / 2.0  # 8th-note duration in seconds
	var mel: Array = spec["melody"]
	var bass: Array = spec["bass"]
	var steps := mel.size()
	var total := int(steps * step * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var root: float = spec["root"]

	# Timbre and intensity controls:
	#  square   0..1 — waveform edge (0 = soft sine, 1 = hard chip square)
	#  lead2    add a harmony voice a fifth up (tension / boss fights)
	#  bass_x2  bass hits every 8th note instead of every quarter (drive)
	#  hat_every / kick_every — drum density
	var sq: float = spec.get("square", 0.5)
	var lead2: bool = spec.get("lead2", false)
	var bass_x2: bool = spec.get("bass_x2", false)

	# ------------------------------------------------------------ melody
	for i in steps:
		var semi: int = mel[i]
		if semi <= -90:
			continue
		var freq := root * 2.0 * pow(2.0, semi / 12.0)  # one octave up
		var n := int(step * 0.92 * RATE)
		var start := int(i * step * RATE)
		var phase := 0.0
		var phase2 := 0.0
		for j in n:
			var idx := start + j
			if idx >= total:
				break
			phase += freq / RATE
			var s := sin(phase * TAU)
			s = signf(s) * sq + s * (1.0 - sq)
			var env := pow(1.0 - float(j) / n, 0.55)
			buf[idx] += s * 0.20 * env
			if lead2:  # harmony a fifth up, quieter
				phase2 += freq * 1.4983 / RATE
				var s2 := sin(phase2 * TAU)
				s2 = signf(s2) * sq + s2 * (1.0 - sq)
				buf[idx] += s2 * 0.09 * env

	# ----------------------------------------------------------- bassline
	var bass_step := 1 if bass_x2 else 2
	var b_i := 0
	while b_i * bass_step < steps:
		var semi: int = bass[b_i % bass.size()]
		b_i += 1
		if semi <= -90:
			continue
		var freq := root * pow(2.0, semi / 12.0)
		var n := int(step * bass_step * 0.9 * RATE)
		var start := int((b_i - 1) * bass_step * step * RATE)
		var phase := 0.0
		for j in n:
			var idx := start + j
			if idx >= total:
				break
			phase += freq / RATE
			var env := pow(1.0 - float(j) / n, 0.35)
			buf[idx] += sin(phase * TAU) * 0.26 * env

	# --------------------------------------------------- drums (kick + hat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kick_every: int = spec.get("kick_every", 8)
	var hat_every: int = spec.get("hat_every", 2)
	for i in steps:
		var start := int(i * step * RATE)
		if i % kick_every == 0:
			var n := int(0.10 * RATE)
			var phase := 0.0
			for j in n:
				var idx := start + j
				if idx >= total:
					break
				phase += lerpf(95.0, 40.0, float(j) / n) / RATE
				buf[idx] += sin(phase * TAU) * 0.4 * (1.0 - float(j) / n)
		if i % hat_every == hat_every - 1:  # hats
			var n2 := int(0.03 * RATE)
			for j in n2:
				var idx := start + j
				if idx >= total:
					break
				buf[idx] += (rng.randf() * 2.0 - 1.0) * 0.05 * (1.0 - float(j) / n2)

	# ------------------------------------------------ to 16-bit, soft-clip
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var v := int(tanh(buf[i]) * 30000.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream


## The whole soundtrack, keyed by track name.
static func build_all() -> Dictionary:
	var R := -99  # rest
	return {
		# Gentle, warm, major-pentatonic stroll (soft round tone).
		"village": _synth({"bpm": 92.0, "root": 220.0, "kick_every": 8, "square": 0.25,
			"melody": [0, R, 4, R, 7, R, 4, 2, 0, R, 2, R, 4, R, R, R,
				9, R, 7, R, 4, R, 2, 4, 0, R, R, R, R, R, R, R],
			"bass": [0, 0, -5, -5, -3, -3, -5, -5, 0, 0, -5, -5, -8, -8, -5, -5]}),
		# Tense forest march in minor (harder chip tone).
		"darkwood": _synth({"bpm": 108.0, "root": 196.0, "kick_every": 8, "square": 0.55,
			"melody": [0, R, 3, R, 5, R, 3, R, 7, R, 5, 3, 2, R, 3, R,
				0, R, 3, R, 5, R, 7, R, 10, R, 7, 5, 3, R, 2, R],
			"bass": [0, 0, 0, -2, -4, -4, -4, -2, 0, 0, 0, -2, -7, -7, -5, -5]}),
		# Slow, eerie phrygian sway (hollow soft tone, sparse drums).
		"marsh": _synth({"bpm": 82.0, "root": 174.6, "kick_every": 16, "square": 0.15, "hat_every": 4,
			"melody": [0, R, 1, R, R, R, 0, R, 5, R, 1, R, R, R, R, R,
				0, R, 1, R, 3, R, 1, R, 0, R, R, R, -4, R, R, R],
			"bass": [0, 0, 1, 1, 0, 0, -4, -4, 0, 0, 1, 1, -7, -7, -4, -4]}),
		# Low, dread-laden crawl through the keep (dark, buzzy).
		"keep": _synth({"bpm": 100.0, "root": 146.8, "kick_every": 8, "square": 0.65,
			"melody": [0, R, R, 3, R, R, 2, R, 0, R, R, R, -2, R, R, R,
				0, R, R, 3, R, R, 5, R, 3, R, 2, R, 0, R, R, R],
			"bass": [0, 0, 0, 0, -2, -2, -2, -2, -4, -4, -4, -4, -2, -2, -2, -2]}),
		# BOSS TENSION PACKAGE: hard square tone, a harmony voice a fifth
		# up, driving 8th-note bass, hats every step, kicks twice a bar.
		# Fangmaw: fast, snarling chase.
		"boss_fangmaw": _synth({"bpm": 156.0, "root": 196.0, "kick_every": 4,
			"square": 0.85, "lead2": true, "bass_x2": true, "hat_every": 1,
			"melody": [0, 0, 3, 0, 5, 0, 3, 0, 7, 7, 5, 3, 2, 3, 2, 0,
				0, 0, 3, 0, 5, 0, 3, 0, 10, 10, 7, 5, 3, 2, 3, 5],
			"bass": [0, 0, 0, 0, -2, -2, -2, -2, 0, 0, 0, 0, -4, -4, -2, -2]}),
		# Morwen: lurching, chromatic witch-waltz.
		"boss_morwen": _synth({"bpm": 132.0, "root": 185.0, "kick_every": 4,
			"square": 0.8, "lead2": true, "bass_x2": true, "hat_every": 1,
			"melody": [0, R, 1, R, 4, R, 1, 0, 6, R, 4, 1, 0, R, 1, R,
				0, R, 1, R, 4, R, 6, R, 7, 6, 4, 1, 0, 1, 0, R],
			"bass": [0, 1, 0, 1, -4, -4, -2, -2, 0, 1, 0, 1, -6, -6, -4, -4]}),
		# Vargoth: heavy, epic minor assault (kick every other 8th!).
		"boss_vargoth": _synth({"bpm": 144.0, "root": 130.8, "kick_every": 2,
			"square": 0.9, "lead2": true, "bass_x2": true, "hat_every": 1,
			"melody": [0, R, 0, 3, R, 3, 5, R, 7, R, 7, 8, R, 7, 5, 3,
				0, R, 0, 3, R, 3, 5, R, 12, R, 10, 8, 7, 5, 3, 2],
			"bass": [0, 0, 0, 0, -4, -4, -4, -4, -5, -5, -5, -5, -2, -2, -2, -2]}),
	}
