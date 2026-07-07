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


## Paladin ultimate (Chains of Wrath): chain links rattle taut — two
## quick metallic clanks — then a great bell tolls over a war-drum boom.
## A cathedral verdict, zero melody.
static func _make_ult_paladin() -> AudioStreamWAV:
	var b := _buf(1.0)
	_metal(b, 0.0, [1900.0, 2470.0, 3320.0], 0.10, 0.45)   # chain snap
	_metal(b, 0.14, [1700.0, 2260.0, 3080.0], 0.10, 0.40)  # second link
	_noise_sweep(b, 0.0, 0.28, 0.25, 900.0, 2600.0, 0.3)   # dragged links hiss
	_sine_sweep(b, 0.26, 110.0, 32.0, 0.55, 0.65)          # the verdict lands
	# Bell: inharmonic hum/prime/tierce/nominal partials, long decay.
	_metal(b, 0.28, [220.0, 440.0, 524.0, 880.0, 1174.0], 0.7, 0.5)
	return _to_wav(b)


## Warlock ultimate (Void Rift): space tears — a rising indrawn hiss
## sucked into silence, then a hollow sub-drop and a detuned dark shimmer.
static func _make_ult_warlock() -> AudioStreamWAV:
	var b := _buf(1.0)
	_noise_sweep(b, 0.0, 0.4, 0.4, 300.0, 5200.0, 0.75)    # the rift inhales
	_sine_sweep(b, 0.38, 180.0, 28.0, 0.55, 0.6)           # gravity drop
	_metal(b, 0.42, [1310.0, 1747.0, 2333.0, 3109.0], 0.5, 0.3)  # wrong-ratio shimmer
	_noise_sweep(b, 0.5, 0.45, 0.3, 2400.0, 200.0, 0.1)    # collapsing roar
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


## The KEENING: a banshee wail swelling for the Silence's whole window —
## detuned high glides over rising breath-noise. The swell IS the timer:
## the danger is audible even with your eyes on the bolts (readability
## pass 2026-07-07). No human vocal cords; semantic fit over melody.
static func _make_keen() -> AudioStreamWAV:
	var b := _buf(2.0)
	_sine_sweep(b, 0.0, 620.0, 1180.0, 2.0, 0.2)
	_sine_sweep(b, 0.05, 926.0, 1764.0, 1.95, 0.11)   # detuned twin — beats like grief
	_noise_sweep(b, 0.0, 2.0, 0.3, 1500.0, 5600.0, 0.85)  # long swell into the wail
	return _to_wav(b)


# ------------------------------------------------------- loot fanfare ---
# Per-grade pickup chimes (retention roadmap #3): rarity is AUDIBLE.
# Common is a polite blip; each step up gets longer, brighter, more
# metallic — S is an unmistakable bell-and-shimmer jackpot.

## F/E: a quiet, warm blip. Present, never demanding.
static func _make_loot_low() -> AudioStreamWAV:
	var b := _buf(0.14)
	_metal(b, 0.0, [1040.0, 1560.0], 0.13, 0.28)
	return _to_wav(b)


## D/C: a clean two-note chime up — "worth a look".
static func _make_loot_mid() -> AudioStreamWAV:
	var b := _buf(0.24)
	_metal(b, 0.0, [1180.0, 1770.0], 0.12, 0.3)
	_metal(b, 0.09, [1570.0, 2360.0], 0.14, 0.34)
	return _to_wav(b)


## B: a three-step metallic arpeggio — the first "real drop" sound.
static func _make_loot_b() -> AudioStreamWAV:
	var b := _buf(0.4)
	_metal(b, 0.0, [990.0, 1490.0], 0.14, 0.3)
	_metal(b, 0.1, [1320.0, 1980.0], 0.14, 0.32)
	_metal(b, 0.2, [1760.0, 2640.0], 0.19, 0.36)
	return _to_wav(b)


## A: the arpeggio plus a plucked-string flourish and a bright tail.
static func _make_loot_a() -> AudioStreamWAV:
	var b := _buf(0.6)
	_pluck(b, 0.0, 330.0, 0.3, 0.4)
	_metal(b, 0.05, [1320.0, 1980.0], 0.16, 0.3)
	_metal(b, 0.16, [1760.0, 2640.0], 0.18, 0.34)
	_metal(b, 0.28, [2350.0, 3520.0], 0.3, 0.38)
	return _to_wav(b)


## S: the jackpot — a deep bell toll under a rising shimmer. Reads across
## the room; nothing else in the bank sounds like it.
static func _make_loot_s() -> AudioStreamWAV:
	var b := _buf(1.0)
	_sine_sweep(b, 0.0, 160.0, 70.0, 0.4, 0.35)
	_metal(b, 0.02, [440.0, 660.0, 880.0, 1174.0], 0.75, 0.45)   # bell partials
	_metal(b, 0.3, [1760.0, 2640.0, 3520.0], 0.4, 0.3)           # high shimmer
	_noise_sweep(b, 0.25, 0.5, 0.15, 2500.0, 7000.0, 0.6)        # rising sparkle air
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
		"splash":   _make_splash(),  # river entry (Graphics & Ambience)
		"gate":     tone(120, 55, 0.5, 0.45, 0.7),
		"roar":     tone(95, 38, 0.75, 0.55, 0.5),
		"pdie":     tone(320, 45, 0.8, 0.45, 0.2),
		"victory":  jingle([523, 659, 784, 1047, 784, 1047], 0.16),
		"talk":     tone(700, 640, 0.035, 0.18),
		# Buff feedback (round 44): soft, low-volume cues so on-hit mends and
		# the arcane ward READ without drowning the swing. Replaceable by
		# assets/sounds/{mend,ward}.wav.
		"mend":     tone(560, 780, 0.09, 0.13),          # warm restorative blip
		"ward":     tone(1150, 1650, 0.14, 0.16),        # crystalline shimmer up
		# Synthesized fallbacks — normally replaced by assets/sounds/*.wav.
		"coin":     tone(900, 1400, 0.08, 0.25),
		"equip":    tone(300, 200, 0.12, 0.3, 0.4),
		"chest":    tone(200, 120, 0.15, 0.35, 0.5),
		"keen":     _make_keen(),
		# Loot fanfare chimes (rarity is audible; see loot_fanfare).
		"loot_low": _make_loot_low(),
		"loot_mid": _make_loot_mid(),
		"loot_b":   _make_loot_b(),
		"loot_a":   _make_loot_a(),
		"loot_s":   _make_loot_s(),
		"ult":      jingle([392, 523, 659, 784], 0.07, 0.4),  # rising power-up
		"ult_warrior":  _make_ult_warrior(),
		"ult_archer":   _make_ult_archer(),
		"ult_assassin": _make_ult_assassin(),
		"ult_paladin":  _make_ult_paladin(),
		"ult_warlock":  _make_ult_warlock(),
		"meteor":   _make_slam(),
		"roar_fangmaw": _make_growl(),  # synthesized beast, not a wolfman
	}


# --------------------------------------------------- ambient loops ---
# Per-biome ambience BEDS (Graphics & Ambience track): quiet layers
# under the music, not soundscapes. Seamless 8s loops — every LFO and
# sine period divides the loop length, so the seam never thumps.
# Taste rules apply: textures only, nothing melodic.

## A short wet splash: a bright noise burst collapsing into a low slosh.
static func _make_splash() -> AudioStreamWAV:
	var buf := _buf(0.4)
	_noise_sweep(buf, 0.0, 0.14, 0.5, 2600.0, 900.0, 0.02)
	_noise_sweep(buf, 0.08, 0.28, 0.3, 700.0, 250.0, 0.1)
	return _to_wav(buf)


## A soft wind bed: heavily low-passed noise breathing on two slow LFOs.
static func _amb_wind_bed(buf: PackedFloat32Array, vol: float, cutoff := 0.02) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var y := 0.0
	var dur := buf.size() / float(RATE)
	for i in buf.size():
		var t := float(i) / RATE
		# Both LFO periods divide the loop: 2 and 3 full cycles over dur.
		var lfo := 0.62 + 0.38 * sin(TAU * t * 2.0 / dur) * sin(TAU * t * 3.0 / dur)
		y += cutoff * (rng.randf_range(-1.0, 1.0) - y)
		buf[i] += y * vol * lfo * 8.0


static func make_ambient(kind: String) -> AudioStream:
	# Real recordings override the synth beds (same file-drop idea as
	# every other asset): assets/sounds/<kind>.ogg or .mp3, looped.
	for ext in ["ogg", "mp3"]:
		var path := "res://assets/sounds/%s.%s" % [kind, ext]
		if FileAccess.file_exists(path):
			var full := ProjectSettings.globalize_path(path)
			if ext == "ogg":
				var ogg := AudioStreamOggVorbis.load_from_file(full)
				if ogg:
					ogg.loop = true
					return ogg
			else:
				var mp3 := AudioStreamMP3.new()
				mp3.data = FileAccess.get_file_as_bytes(full)
				if not mp3.data.is_empty():
					mp3.loop = true
					return mp3
	var dur := 8.0
	var buf := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	match kind:
		"amb_birds":
			# Distant songbirds over the faintest breeze: sparse two-to-four
			# note twitters, high and quiet, clear of the loop seam.
			_amb_wind_bed(buf, 0.016)
			for i in 7:
				var at := rng.randf_range(0.4, dur - 0.7)
				var f0 := rng.randf_range(2300.0, 3300.0)
				for c in 2 + rng.randi_range(0, 2):
					_sine_sweep(buf, at + c * 0.11, f0 + rng.randf_range(-150.0, 150.0),
						f0 + rng.randf_range(250.0, 700.0), 0.055, 0.045)
		"amb_wind":
			_amb_wind_bed(buf, 0.05)
		"amb_cold":
			# Thinner, higher hiss — winter air, not summer grass.
			_amb_wind_bed(buf, 0.035, 0.06)
		"amb_crickets":
			# Marsh night: breeze + cricket trains (short high pings in
			# fast bursts, a few bursts per loop).
			_amb_wind_bed(buf, 0.012)
			for i in 5:
				var at := rng.randf_range(0.3, dur - 0.8)
				var f := rng.randf_range(3800.0, 4600.0)
				for c in 5 + rng.randi_range(0, 4):
					_sine_sweep(buf, at + c * 0.055, f, f, 0.028, 0.035)
		"amb_drone":
			# Stone / void / grave: a low three-partial drone breathing on
			# a loop-locked LFO. Frequencies are multiples of 1/8 Hz so the
			# loop point is phase-perfect.
			for i in buf.size():
				var t := float(i) / RATE
				var swell := 0.6 + 0.4 * sin(TAU * t / dur)
				buf[i] += (sin(TAU * 55.0 * t) * 0.030
					+ sin(TAU * 82.5 * t) * 0.018
					+ sin(TAU * 110.25 * t) * 0.010) * swell
		_:
			# Unknown kind without a file (e.g. amb_rain when its
			# recording is removed): fall back to the wind bed.
			_amb_wind_bed(buf, 0.05)
	var wav := _to_wav(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = buf.size()
	return wav
