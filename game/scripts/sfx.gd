class_name Sfx
## Procedural sound effects. Like the art, every sound is synthesized
## in code at boot (little square-wave tones with a decay envelope),
## so the project needs zero audio files.

const RATE := 22050


## One tone that slides from freq_a to freq_b over dur seconds.
## noise mixes in white noise (0..1) for crunchy impact sounds.
static func tone(freq_a: float, freq_b: float, dur: float, vol := 0.4, noise := 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(freq_a, freq_b, t)
		phase += f / RATE
		var s := sin(phase * TAU)
		s = signf(s) * 0.6 + s * 0.4  # square-ish = retro
		if noise > 0.0:
			s = lerpf(s, rng.randf() * 2.0 - 1.0, noise)
		var env := 1.0 - t
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## A little melody: array of frequencies played back to back.
static func jingle(freqs: Array, note_dur := 0.14, vol := 0.35) -> AudioStreamWAV:
	var n_note := int(note_dur * RATE)
	var data := PackedByteArray()
	data.resize(n_note * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		var phase := 0.0
		for i in n_note:
			var t := float(i) / float(n_note)
			phase += float(f) / RATE
			var s := sin(phase * TAU)
			s = signf(s) * 0.5 + s * 0.5
			var env := 1.0 - t * 0.7
			var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
			data.encode_s16(idx * 2, v)
			idx += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## Build the whole sound bank the game uses.
static func build_all() -> Dictionary:
	return {
		"slash":    tone(700, 180, 0.12, 0.35, 0.55),
		"fireball": tone(320, 70, 0.28, 0.4, 0.35),
		"bolt":     tone(900, 300, 0.15, 0.3, 0.2),
		"ehit":     tone(260, 140, 0.09, 0.4, 0.5),
		"hurt":     tone(170, 80, 0.22, 0.45, 0.4),
		"edie":     tone(420, 50, 0.3, 0.4, 0.5),
		"levelup":  jingle([523, 659, 784, 1047]),
		"potion":   tone(400, 850, 0.16, 0.35),
		"gate":     tone(120, 55, 0.5, 0.45, 0.7),
		"roar":     tone(95, 38, 0.75, 0.55, 0.5),
		"blink":    tone(600, 1300, 0.12, 0.3),
		"slam":     tone(75, 28, 0.4, 0.55, 0.8),
		"pdie":     tone(320, 45, 0.8, 0.45, 0.2),
		"victory":  jingle([523, 659, 784, 1047, 784, 1047], 0.16),
		"talk":     tone(700, 640, 0.035, 0.18),
		# --- class-flavored ability sounds ---
		"sword":    tone(280, 90, 0.16, 0.4, 0.65),    # heavy whoosh (warrior)
		"stab":     tone(1400, 500, 0.06, 0.35, 0.3),  # sharp shink (assassin)
		"knife":    tone(950, 450, 0.09, 0.3, 0.5),    # thrown blade
		"bow":      tone(420, 130, 0.08, 0.4, 0.65),   # string release (archer)
		"cast":     tone(480, 980, 0.18, 0.3, 0.08),   # arcane shimmer (mage)
	}
