class_name Sfx
## Procedural sound effects, synthesized at boot. Three real techniques
## instead of plain beeps:
##  - filtered NOISE SWEEPS (a low-pass filter gliding across white noise)
##    for whooshes, dashes and flames
##  - INHARMONIC METAL PARTIALS (detuned decaying sines) for blade shings
##  - KARPLUS-STRONG string synthesis (a physical model) for bow plucks
## Sounds are built as float buffers, layered, then converted to 16-bit.
##
## Like sprites, sounds can be overridden: drop <name>.ogg into
## assets/sounds/ and game.gd will load it instead (see Game._ready).

const RATE := 22050


## Load a PCM16 .wav file at runtime (RIFF parser — no import needed),
## so recorded CC0 sounds can override the synthesized ones.
static func load_wav(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var channels := 1
	var sample_rate := 44100
	var bits := 16
	var audio_format := 1
	var pcm := PackedByteArray()
	var pos := 12
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csize := bytes.decode_u32(pos + 4)
		if cid == "fmt ":
			audio_format = bytes.decode_u16(pos + 8)
			channels = bytes.decode_u16(pos + 10)
			sample_rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif cid == "data":
			pcm = bytes.slice(pos + 8, pos + 8 + csize)
		pos += 8 + csize + (csize & 1)
	if audio_format != 1 or pcm.is_empty() or not bits in [16, 24]:
		return null  # only uncompressed 16/24-bit PCM supported
	if bits == 24:
		# Convert 24-bit -> 16-bit: keep the top two bytes of each sample.
		var n := pcm.size() / 3
		var out := PackedByteArray()
		out.resize(n * 2)
		for i in n:
			out[i * 2] = pcm[i * 3 + 1]
			out[i * 2 + 1] = pcm[i * 3 + 2]
		pcm = out
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = pcm
	return stream


# ------------------------------------------------------------ primitives ---

static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(tanh(buf[i]) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## White noise through a gliding one-pole low-pass = a shaped "whoosh".
## attack is the fraction of the duration spent ramping up.
static func _noise_sweep(buf: PackedFloat32Array, at: float, dur: float, vol: float,
		cutoff_a: float, cutoff_b: float, attack := 0.15) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff_a) + int(dur * 1000.0)
	var n := int(dur * RATE)
	var start := int(at * RATE)
	var y := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / n
		var fc := lerpf(cutoff_a, cutoff_b, t)
		var k := 1.0 - exp(-TAU * fc / RATE)
		y += k * ((rng.randf() * 2.0 - 1.0) - y)
		var env := t / attack if t < attack else pow(1.0 - (t - attack) / (1.0 - attack), 1.4)
		buf[idx] += y * vol * env * 2.2


## Detuned decaying sine partials — the "shing" of struck metal.
static func _metal(buf: PackedFloat32Array, at: float, freqs: Array, dur: float, vol: float) -> void:
	var n := int(dur * RATE)
	var start := int(at * RATE)
	for f in freqs:
		var freq: float = f
		var phase := 0.0
		for i in n:
			var idx := start + i
			if idx >= buf.size():
				break
			phase += freq / RATE
			var t := float(i) / n
			buf[idx] += sin(phase * TAU) * vol * exp(-t * 7.0) / freqs.size()


## Karplus-Strong plucked string (physical model): a noise burst run
## through a feedback delay line. Sounds like an actual bowstring.
static func _pluck(buf: PackedFloat32Array, at: float, freq: float, dur: float, vol: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	var period := maxi(2, int(RATE / freq))
	var delay := PackedFloat32Array()
	delay.resize(period)
	for i in period:
		delay[i] = rng.randf() * 2.0 - 1.0
	var n := int(dur * RATE)
	var start := int(at * RATE)
	var pos := 0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var out := delay[pos]
		delay[pos] = (out + delay[(pos + 1) % period]) * 0.5 * 0.994
		pos = (pos + 1) % period
		buf[idx] += out * vol


## Simple sine sweep (kicks, thuds, rumbles).
static func _sine_sweep(buf: PackedFloat32Array, at: float, freq_a: float, freq_b: float,
		dur: float, vol: float) -> void:
	var n := int(dur * RATE)
	var start := int(at * RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / n
		phase += lerpf(freq_a, freq_b, t) / RATE
		buf[idx] += sin(phase * TAU) * vol * (1.0 - t)


# ------------------------------------------- legacy tone/jingle (UI etc) ---

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
		s = signf(s) * 0.6 + s * 0.4
		if noise > 0.0:
			s = lerpf(s, rng.randf() * 2.0 - 1.0, noise)
		var env := 1.0 - t
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


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
			data.encode_s16(idx * 2, int(clampf(s * (1.0 - t * 0.7) * vol, -1.0, 1.0) * 32000.0))
			idx += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


# ------------------------------------------------------- sound recipes ---

## Sharp blade thrust: an instant "tss" transient + metallic shing.
static func _make_stab() -> AudioStreamWAV:
	var b := _buf(0.18)
	_noise_sweep(b, 0.0, 0.05, 0.5, 5000.0, 8000.0, 0.06)
	_metal(b, 0.008, [2800.0, 4230.0, 6100.0, 7300.0], 0.16, 0.5)
	return _to_wav(b)


## Heavy sword swing: a broad rising-falling air whoosh.
static func _make_sword() -> AudioStreamWAV:
	var b := _buf(0.26)
	_noise_sweep(b, 0.0, 0.26, 0.5, 250.0, 1600.0, 0.4)
	return _to_wav(b)


## Thrown knife: quick air cut with a faint metallic edge.
static func _make_knife() -> AudioStreamWAV:
	var b := _buf(0.15)
	_noise_sweep(b, 0.0, 0.13, 0.4, 900.0, 4200.0, 0.2)
	_metal(b, 0.0, [5200.0, 6900.0], 0.09, 0.18)
	return _to_wav(b)


## Bowshot: real plucked-string model + release click + arrow whoosh.
static func _make_bow() -> AudioStreamWAV:
	var b := _buf(0.22)
	_noise_sweep(b, 0.0, 0.02, 0.35, 3000.0, 5000.0, 0.3)
	_pluck(b, 0.005, 130.0, 0.2, 0.55)
	_noise_sweep(b, 0.02, 0.12, 0.16, 1500.0, 3800.0, 0.3)
	return _to_wav(b)


## Flame launch: roaring noise + low rumble.
static func _make_fireball() -> AudioStreamWAV:
	var b := _buf(0.3)
	_noise_sweep(b, 0.0, 0.3, 0.4, 1400.0, 300.0, 0.15)
	_sine_sweep(b, 0.0, 130.0, 55.0, 0.28, 0.3)
	return _to_wav(b)


## Airy teleport/dash: fast rising hiss.
static func _make_blink() -> AudioStreamWAV:
	var b := _buf(0.2)
	_noise_sweep(b, 0.0, 0.2, 0.35, 500.0, 4800.0, 0.5)
	return _to_wav(b)


## Frost nova: icy crystalline burst.
static func _make_nova() -> AudioStreamWAV:
	var b := _buf(0.35)
	_noise_sweep(b, 0.0, 0.16, 0.4, 4500.0, 900.0, 0.05)
	_metal(b, 0.02, [2150.0, 3260.0, 4780.0, 6200.0], 0.32, 0.4)
	_sine_sweep(b, 0.0, 220.0, 90.0, 0.2, 0.2)
	return _to_wav(b)


## Ground slam: deep boom + debris crack.
static func _make_slam() -> AudioStreamWAV:
	var b := _buf(0.45)
	_sine_sweep(b, 0.0, 85.0, 28.0, 0.42, 0.65)
	_noise_sweep(b, 0.0, 0.12, 0.45, 700.0, 150.0, 0.05)
	return _to_wav(b)


## Beast growl: dark noise amplitude-modulated at ~26Hz (the pulsing
## "throat roughness" that reads as animal), over a sub rumble, with a
## snarl transient. No human vocal cords involved.
static func _make_growl() -> AudioStreamWAV:
	var b := _buf(1.15)
	var n := b.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var y := 0.0
	var am_phase := 0.0
	for i in n:
		var t := float(i) / n
		var fc := 520.0 - 260.0 * t  # darkens as the growl trails off
		var k := 1.0 - exp(-TAU * fc / RATE)
		y += k * ((rng.randf() * 2.0 - 1.0) - y)
		am_phase += (26.0 + 8.0 * sin(t * 9.0)) / RATE  # wobbling growl rate
		var am := 0.55 + 0.45 * sin(am_phase * TAU)
		var env := sin(minf(t * 5.0, 1.0) * PI / 2.0) * (1.0 - pow(t, 3.0))
		b[i] += y * am * env * 1.0
	_sine_sweep(b, 0.0, 55.0, 36.0, 1.05, 0.25)
	_noise_sweep(b, 0.0, 0.14, 0.35, 1900.0, 500.0, 0.1)
	return _to_wav(b)


## Warrior ultimate (Berserk): two taiko war-drum booms under a rising
## battle-roar of air and a deep anvil clang. Martial, zero melody.
static func _make_ult_warrior() -> AudioStreamWAV:
	var b := _buf(0.95)
	_sine_sweep(b, 0.0, 120.0, 30.0, 0.5, 0.7)
	_sine_sweep(b, 0.28, 100.0, 34.0, 0.45, 0.55)
	_noise_sweep(b, 0.0, 0.85, 0.4, 280.0, 1700.0, 0.5)
	_metal(b, 0.06, [520.0, 782.0, 1174.0], 0.6, 0.3)
	return _to_wav(b)


## Archer ultimate (Arrow Storm): the sky opens — a broad wind swell,
## four quick ascending bowstring plucks, and a thin arrow whistle.
static func _make_ult_archer() -> AudioStreamWAV:
	var b := _buf(0.85)
	_noise_sweep(b, 0.0, 0.85, 0.38, 400.0, 3600.0, 0.45)
	_pluck(b, 0.04, 130.0, 0.18, 0.5)
	_pluck(b, 0.14, 155.0, 0.18, 0.5)
	_pluck(b, 0.24, 185.0, 0.18, 0.5)
	_pluck(b, 0.34, 220.0, 0.2, 0.5)
	_sine_sweep(b, 0.15, 1100.0, 2300.0, 0.45, 0.1)
	return _to_wav(b)


## Assassin ultimate (Death Mark): a dark falling whoosh over a doom
## sub-pulse, then two echoing blade shings vanishing into a shadow hiss.
static func _make_ult_assassin() -> AudioStreamWAV:
	var b := _buf(0.9)
	_noise_sweep(b, 0.0, 0.5, 0.4, 2600.0, 320.0, 0.55)
	_sine_sweep(b, 0.0, 70.0, 36.0, 0.6, 0.5)
	_metal(b, 0.32, [3100.0, 4420.0, 5810.0], 0.22, 0.3)
	_metal(b, 0.52, [2600.0, 3840.0], 0.26, 0.18)
	_noise_sweep(b, 0.58, 0.3, 0.22, 3800.0, 7200.0, 0.35)
	return _to_wav(b)


## Build the whole sound bank the game uses.
static func build_all() -> Dictionary:
	return {
		# --- class ability sounds (synthesized, not beeped) ---
		"stab":     _make_stab(),
		"sword":    _make_sword(),
		"knife":    _make_knife(),
		"bow":      _make_bow(),
		"fireball": _make_fireball(),
		"blink":    _make_blink(),
		"nova":     _make_nova(),
		"slam":     _make_slam(),
		"slash":    _make_sword(),
		# --- world / UI ---
		"bolt":     tone(900, 300, 0.15, 0.3, 0.2),
		"ehit":     tone(260, 140, 0.09, 0.4, 0.5),
		"hurt":     tone(170, 80, 0.22, 0.45, 0.4),
		"edie":     tone(420, 50, 0.3, 0.4, 0.5),
		"levelup":  jingle([523, 659, 784, 1047]),
		"potion":   tone(400, 850, 0.16, 0.35),
		"gate":     tone(120, 55, 0.5, 0.45, 0.7),
		"roar":     tone(95, 38, 0.75, 0.55, 0.5),
		"pdie":     tone(320, 45, 0.8, 0.45, 0.2),
		"victory":  jingle([523, 659, 784, 1047, 784, 1047], 0.16),
		"talk":     tone(700, 640, 0.035, 0.18),
		# Synthesized fallbacks — normally replaced by assets/sounds/*.wav.
		"coin":     tone(900, 1400, 0.08, 0.25),
		"equip":    tone(300, 200, 0.12, 0.3, 0.4),
		"chest":    tone(200, 120, 0.15, 0.35, 0.5),
		"ult":      jingle([392, 523, 659, 784], 0.07, 0.4),  # rising power-up
		"ult_warrior":  _make_ult_warrior(),
		"ult_archer":   _make_ult_archer(),
		"ult_assassin": _make_ult_assassin(),
		"meteor":   _make_slam(),
		"roar_fangmaw": _make_growl(),  # synthesized beast, not a wolfman
	}
