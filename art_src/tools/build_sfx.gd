extends SceneTree
## Designs the weapon foley the Ninja Adventure pack doesn't have and bakes
## it to 16-bit mono WAVs in assets/audio/sfx/. Deterministic (fixed seeds).
##   godot --headless --path <project> --script art_src/tools/build_sfx.gd
##
## Gunshots follow the layering used in shooter sound design:
##   MECH   - metal action click a few ms *before* the shot (slide / hammer)
##   CRACK  - ~1 ms broadband transient, hard-clipped (sets timing + bite)
##   BODY   - muzzle blast: noise through resonant band-passes, driven into
##            saturation and clipped like a real (overloaded) recording
##   SUB    - short pitch-dropping sine around 60-90 Hz for weight
##   TAIL   - outdoor slap-back + lowpassed reverb that fades in slightly
## Sub and tail stay short on fast guns so rapid fire doesn't smear.
## Metal parts (clicks, casings, magazines) use modal synthesis: a strike
## exciting inharmonic damped sine modes, like a real struck object.

const RATE := 44100
const OUT := "res://assets/audio/sfx/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var guns := {
		"shot_pistol": { "mech": 3300.0, "body": [650.0, 1500.0, 3200.0], "decay": 0.034, "drive": 4.0, "sub": 82.0, "sub_decay": 0.05, "tail": 0.55, "crack": 0.0, "gain": 1.0 },
		"shot_revolver": { "mech": 2100.0, "body": [420.0, 1050.0, 2600.0], "decay": 0.06, "drive": 5.0, "sub": 62.0, "sub_decay": 0.09, "tail": 0.95, "crack": 0.0, "gain": 1.0 },
		"shot_smg": { "mech": 3800.0, "body": [800.0, 1900.0, 4200.0], "decay": 0.024, "drive": 3.5, "sub": 95.0, "sub_decay": 0.035, "tail": 0.32, "crack": 0.0, "gain": 0.9 },
		"shot_rifle": { "mech": 2900.0, "body": [520.0, 1250.0, 3000.0], "decay": 0.045, "drive": 5.5, "sub": 70.0, "sub_decay": 0.07, "tail": 0.8, "crack": 1.0, "gain": 1.0 },
	}
	for gun_name in guns:
		for v in 3:
			rng.seed = hash(gun_name) + v * 7919
			_save(_gunshot(guns[gun_name]), "%s_%d" % [gun_name, v])
	for v in 3:
		rng.seed = 100 + v
		_save(_rocket(), "shot_rocket_%d" % v)
		rng.seed = 200 + v
		_save(_casing(), "casing_%d" % v)
		rng.seed = 300 + v
		_save(_drone_shot(), "drone_shot_%d" % v)
	rng.seed = 7
	_save(_mag_out(), "reload_out")
	_save(_mag_in_and_rack(), "reload_in")
	_save(_cylinder_open(), "reload_revolver_out")
	_save(_cylinder_close(), "reload_revolver_in")
	_save(_rocket_load(), "reload_rocket")
	_save(_dry_fire(), "empty_click")
	print("sfx baked")
	quit()


# --- Gunshot ------------------------------------------------------------------

func _gunshot(p: Dictionary) -> PackedFloat32Array:
	var total := 0.08 + float(p.tail) * 1.2
	var out := _buffer(total)
	var pre := 0.006  # mech leads the blast by a few ms

	# MECH: slide/hammer strike, a couple of ms early.
	_mix(out, _metal_hit(p.mech, 0.012, 0.35), 0.0)

	# CRACK: very short clipped noise burst (+ N-wave for supersonic rifles).
	var crack := _buffer(0.004)
	for i in crack.size():
		var t := float(i) / RATE
		crack[i] = clampf(rng.randf_range(-1.0, 1.0) * 3.0, -1.0, 1.0) * exp(-t / 0.0009)
	if p.crack > 0.0:
		var n_len := int(0.0006 * RATE)
		for i in n_len:
			crack[i] += lerpf(1.0, -1.0, float(i) / n_len) * 0.9
	_mix(out, crack, pre)

	# BODY: resonant noise blast, saturated.
	var body_len := float(p.decay) * 7.0
	var body := _buffer(body_len)
	var bands: Array = p.body
	var filters: Array[Biquad] = []
	for f in bands:
		filters.append(Biquad.bandpass(f, 1.1))
	for i in body.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		for k in filters.size():
			s += filters[k].process(n) * (1.0 - k * 0.22)
		var env := exp(-t / p.decay) * clampf(t / 0.0006, 0.0, 1.0)
		# Saturate first, envelope after: keeps the grit without flattening the decay.
		body[i] = tanh(s * p.drive) * env * 0.95
	_mix(out, body, pre + 0.0004)

	# SUB: pitch-dropping sine, tightly enveloped.
	var sub := _buffer(float(p.sub_decay) * 6.0)
	var phase := 0.0
	for i in sub.size():
		var t := float(i) / RATE
		phase += TAU * p.sub * (1.0 + 1.2 * exp(-t / 0.01)) / RATE
		sub[i] = sin(phase) * exp(-t / p.sub_decay) * 0.85
	_mix(out, sub, pre)

	# TAIL: outdoor slap-back (lowpassed echo) + diffuse lowpassed reverb.
	var dry := out.duplicate()
	var slap := _lowpass_copy(dry, 2200.0)
	_mix(out, _scaled(slap, 0.11), rng.randf_range(0.075, 0.11))
	_mix(out, _scaled(slap, 0.045), rng.randf_range(0.17, 0.23))
	var verb := _reverb(_lowpass_copy(dry, 3500.0), p.tail)
	for i in verb.size():
		# Fade the tail in slightly so the body has room to breathe.
		verb[i] *= clampf(float(i) / (0.02 * RATE), 0.0, 1.0)
	_mix(out, _scaled(verb, 0.1), 0.0)

	for i in out.size():
		out[i] = _clip(out[i] * p.gain)
	return _fade_tail(_highpass(out, 35.0))


func _rocket() -> PackedFloat32Array:
	var out := _buffer(1.1)
	_mix(out, _metal_hit(1400.0, 0.02, 0.4), 0.0)
	# Launch thump.
	var thump := _buffer(0.4)
	var phase := 0.0
	for i in thump.size():
		var t := float(i) / RATE
		phase += TAU * 55.0 * (1.0 + 1.6 * exp(-t / 0.03)) / RATE
		thump[i] = sin(phase) * exp(-t / 0.11)
	_mix(out, thump, 0.004)
	# Motor whoosh: band-pass noise sweeping up and away.
	var whoosh := _buffer(0.9)
	var bp := Biquad.bandpass(600.0, 0.8)
	for i in whoosh.size():
		var t := float(i) / RATE
		if i % 64 == 0:
			bp.set_bandpass(lerpf(500.0, 2600.0, minf(t / 0.5, 1.0)), 0.8)
		var env := (1.0 - exp(-t / 0.015)) * exp(-t / 0.28)
		whoosh[i] = bp.process(rng.randf_range(-1.0, 1.0)) * env * 2.2
	_mix(out, whoosh, 0.006)
	var verb := _reverb(_lowpass_copy(out.duplicate(), 2500.0), 0.9)
	_mix(out, _scaled(verb, 0.3), 0.0)
	for i in out.size():
		out[i] = _clip(out[i] * 1.3)
	return _fade_tail(out)


# --- Casings ------------------------------------------------------------------

## A spent brass case hitting the ground: bright inharmonic "tink" from the
## free-free bar modes (1 : 2.76 : 5.40), bouncing with shrinking gaps and
## energy, then a few tiny rolling ticks. Slightly dulled (it lands on dirt).
func _casing() -> PackedFloat32Array:
	var out := _buffer(0.6)
	var base := rng.randf_range(2700.0, 3400.0)
	var t := 0.0
	var gap := rng.randf_range(0.075, 0.1)
	var energy := 1.0
	for bounce in 6:
		var tilt := rng.randf_range(0.85, 1.15)  # each impact hits a different spot
		_mix(out, _scaled(_modal(base * tilt, [1.0, 2.76, 5.40], [0.045, 0.02, 0.008], [1.0, 0.5, 0.22], 0.0008), energy), t)
		t += gap
		gap *= rng.randf_range(0.55, 0.7)
		energy *= rng.randf_range(0.42, 0.55)
	for tick in 4:
		_mix(out, _scaled(_modal(base * 1.1, [1.0, 2.76], [0.008, 0.004], [1.0, 0.4], 0.0004), 0.05), t + tick * 0.022)
	return _fade_tail(_lowpass(out, 9000.0))


# --- Reloads ------------------------------------------------------------------
# Real reload foley is mostly mid-range (0.5-4 kHz) "clacks": a hard impact
# ringing through a few metal resonances, with a short body thud. Each
# event here is 30-80 ms long - long enough to read clearly in a fight.

## Pistol / SMG / rifle start: mag release press, mag scraping out of the
## well, then the empty mag clattering on the ground.
func _mag_out() -> PackedFloat32Array:
	var out := _buffer(0.62)
	_mix(out, _clack([2600.0, 4100.0, 5600.0], 0.012, 0.55), 0.0)       # release button
	_mix(out, _scrape(0.12, 1800.0, 0.9), 0.02)                       # mag sliding out
	_mix(out, _clack([1300.0, 2300.0, 3400.0], 0.02, 0.6), 0.13)       # mag clears the well
	_mix(out, _clack([700.0, 1150.0, 1900.0], 0.03, 0.75), 0.36)       # mag hits the ground
	_mix(out, _thud(170.0, 0.03, 0.5), 0.36)
	_mix(out, _clack([900.0, 1500.0, 2500.0], 0.018, 0.35), 0.43)      # small bounce
	return _fade_tail(out)


## Pistol / SMG / rifle end: new mag slides in and seats ("chk"), then the
## slide is pulled back and released forward ("cha-chak").
func _mag_in_and_rack() -> PackedFloat32Array:
	var out := _buffer(0.62)
	_mix(out, _scrape(0.07, 1600.0, 0.8), 0.0)
	_mix(out, _clack([1100.0, 1900.0, 2900.0, 4300.0], 0.035, 1.0), 0.07)  # mag seats
	_mix(out, _thud(140.0, 0.035, 0.7), 0.07)
	_mix(out, _scrape(0.08, 2600.0, 0.7), 0.24)                        # slide pulled back
	_mix(out, _clack([2000.0, 3300.0, 4800.0], 0.02, 0.6), 0.31)       # slide stops at rear
	_mix(out, _clack([1400.0, 2400.0, 3600.0, 5200.0], 0.045, 1.0), 0.38)  # slams forward
	_mix(out, _thud(120.0, 0.035, 0.75), 0.38)
	return _fade_tail(out)


func _cylinder_open() -> PackedFloat32Array:
	var out := _buffer(0.6)
	_mix(out, _clack([1800.0, 2900.0, 4300.0], 0.025, 0.8), 0.0)       # latch + swing out
	_mix(out, _scrape(0.06, 2200.0, 0.6), 0.03)
	for i in 4:                                                       # empties falling out
		_mix(out, _scaled(_modal(rng.randf_range(2800.0, 3300.0), [1.0, 2.76, 5.4], [0.035, 0.016, 0.006], [1.0, 0.5, 0.2], 0.0008), 0.55), 0.16 + i * rng.randf_range(0.035, 0.06))
	return _fade_tail(out)


func _cylinder_close() -> PackedFloat32Array:
	var out := _buffer(0.5)
	for i in 5:                                                       # rounds dropped in
		_mix(out, _clack([2400.0, 3800.0], 0.008, 0.4), i * 0.035)
	_mix(out, _clack([1300.0, 2200.0, 3500.0, 4900.0], 0.045, 1.0), 0.22)  # cylinder snaps shut
	_mix(out, _thud(150.0, 0.035, 0.7), 0.22)
	_mix(out, _clack([2800.0, 4400.0], 0.012, 0.5), 0.32)              # hammer cocked
	return _fade_tail(out)


func _rocket_load() -> PackedFloat32Array:
	var out := _buffer(0.7)
	_mix(out, _scrape(0.2, 900.0, 0.9), 0.0)
	_mix(out, _clack([600.0, 1000.0, 1700.0], 0.06, 1.0), 0.21)
	_mix(out, _thud(90.0, 0.06, 0.9), 0.21)
	_mix(out, _clack([1900.0, 3100.0], 0.018, 0.6), 0.38)
	return _fade_tail(out)


## Impact on a metal part: a 3 ms noise burst ringing through resonant
## band-passes (one per frequency), lightly saturated.
func _clack(freqs: Array, decay: float, gain: float) -> PackedFloat32Array:
	var out := _buffer(decay * 6.0 + 0.004)
	var filters: Array[Biquad] = []
	for f in freqs:
		filters.append(Biquad.bandpass(f * rng.randf_range(0.97, 1.03), 9.0))
	for i in out.size():
		var t := float(i) / RATE
		var excite := rng.randf_range(-1.0, 1.0) * exp(-t / 0.0015)
		var s := 0.0
		for k in filters.size():
			s += filters[k].process(excite) * (1.0 - k * 0.15)
		var ring := exp(-t / decay)
		out[i] = tanh((s * 9.0 * ring + excite * 0.35) * 1.5) * gain
	return out

func _dry_fire() -> PackedFloat32Array:
	var out := _buffer(0.08)
	_mix(out, _metal_hit(3900.0, 0.008, 0.7), 0.0)
	return _fade_tail(out)


func _drone_shot() -> PackedFloat32Array:
	var out := _buffer(0.16)
	var phase := 0.0
	var start := rng.randf_range(1500.0, 1700.0)
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(start, 380.0, minf(t / 0.09, 1.0)) / RATE
		out[i] = (1.0 if sin(phase) > 0.0 else -1.0) * exp(-t / 0.03) * 0.18
	_mix(out, _scaled(_metal_hit(4200.0, 0.006, 0.4), 0.4), 0.0)
	return _fade_tail(_lowpass(out, 7000.0))


# --- Building blocks ----------------------------------------------------------

## Struck metal part: noise-excited inharmonic modes (plate-like ratios).
func _metal_hit(freq: float, decay: float, gain: float) -> PackedFloat32Array:
	var ratios := [1.0, 1.59, 2.14, 2.83, 3.6]
	var decays := []
	var amps := []
	for k in ratios.size():
		decays.append(decay / (1.0 + k * 0.5))
		amps.append(1.0 / (1.0 + k * 0.7))
	var hit := _modal(freq * rng.randf_range(0.96, 1.04), ratios, decays, amps, 0.0012)
	return _scaled(hit, gain)


## Modal synthesis: a short noise strike exciting damped sine modes.
func _modal(freq: float, ratios: Array, decays: Array, amps: Array, strike: float) -> PackedFloat32Array:
	var longest := 0.0
	for d in decays:
		longest = maxf(longest, d)
	var out := _buffer(longest * 7.0 + strike)
	var phases := []
	for k in ratios.size():
		phases.append(rng.randf() * TAU)
	for i in out.size():
		var t := float(i) / RATE
		var s := 0.0
		for k in ratios.size():
			s += sin(phases[k] + TAU * freq * ratios[k] * t) * amps[k] * exp(-t / decays[k])
		s += rng.randf_range(-1.0, 1.0) * exp(-t / strike) * 0.6
		out[i] = s * 0.5
	return out


## Friction: random micro-impacts through a band-pass (metal sliding on metal).
func _scrape(duration: float, freq: float, gain: float) -> PackedFloat32Array:
	var out := _buffer(duration)
	var bp := Biquad.bandpass(freq, 1.4)
	for i in out.size():
		var t := float(i) / RATE
		var grain := rng.randf_range(-1.0, 1.0) * (1.0 if rng.randf() < 0.35 else 0.25)
		out[i] = tanh(bp.process(grain) * sin(PI * t / duration) * gain * 5.0)
	return out


func _thud(freq: float, decay: float, gain: float) -> PackedFloat32Array:
	var out := _buffer(decay * 6.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * freq * (1.0 + exp(-t / 0.006)) / RATE
		out[i] = sin(phase) * exp(-t / decay) * gain
	return out


## Small Schroeder reverb (4 combs + 2 all-passes) for open-air tails.
func _reverb(input: PackedFloat32Array, length: float) -> PackedFloat32Array:
	var out := _buffer(input.size() / float(RATE) + length)
	var comb_delays := [1116, 1188, 1277, 1356]
	var feedback := pow(0.001, (1356.0 / RATE) / maxf(length, 0.05))
	for d in comb_delays:
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		var damp := 0.0
		for i in out.size():
			var x := input[i] if i < input.size() else 0.0
			var y := line[idx]
			damp = y * 0.6 + damp * 0.4
			line[idx] = x + damp * feedback
			idx = (idx + 1) % d
			out[i] += y * 0.25
	for d in [225, 556]:
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		for i in out.size():
			var buffered := line[idx]
			var x := out[i]
			line[idx] = x + buffered * 0.5
			out[i] = buffered - x * 0.5
			idx = (idx + 1) % d
	return out


func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _mix(target: PackedFloat32Array, source: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	for i in source.size():
		var j := start + i
		if j >= target.size():
			break
		target[j] += source[i]


func _scaled(source: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out := source.duplicate()
	for i in out.size():
		out[i] *= gain
	return out


func _lowpass_copy(source: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	return _lowpass(source.duplicate(), cutoff)


func _lowpass(samples: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var f := Biquad.lowpass(cutoff, 0.707)
	for i in samples.size():
		samples[i] = f.process(samples[i])
	return samples


func _highpass(samples: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var f := Biquad.highpass(cutoff, 0.707)
	for i in samples.size():
		samples[i] = f.process(samples[i])
	return samples


## Clip before limiting keeps the attack sharp (soft knee above 0.6).
func _clip(x: float) -> float:
	var a := absf(x)
	if a < 0.6:
		return x
	return signf(x) * (0.6 + 0.4 * tanh((a - 0.6) / 0.4))


func _fade_tail(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade := mini(int(0.015 * RATE), samples.size())
	for i in fade:
		samples[samples.size() - 1 - i] *= float(i) / fade
	return samples


func _save(samples: PackedFloat32Array, file_name: String) -> void:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var norm := 0.9 / peak if peak > 0.0001 else 1.0
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(OUT + file_name + ".wav"))


## RBJ-cookbook biquad filter.
class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	static func lowpass(freq: float, q: float) -> Biquad:
		var f := Biquad.new()
		var w := TAU * freq / RATE
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		f._coeffs((1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0, 1.0 + alpha, -2.0 * c, 1.0 - alpha)
		return f

	static func highpass(freq: float, q: float) -> Biquad:
		var f := Biquad.new()
		var w := TAU * freq / RATE
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		f._coeffs((1.0 + c) / 2.0, -(1.0 + c), (1.0 + c) / 2.0, 1.0 + alpha, -2.0 * c, 1.0 - alpha)
		return f

	static func bandpass(freq: float, q: float) -> Biquad:
		var f := Biquad.new()
		f.set_bandpass(freq, q)
		return f

	func set_bandpass(freq: float, q: float) -> void:
		var w := TAU * freq / RATE
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		_coeffs(alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * c, 1.0 - alpha)

	func _coeffs(nb0: float, nb1: float, nb2: float, na0: float, na1: float, na2: float) -> void:
		b0 = nb0 / na0
		b1 = nb1 / na0
		b2 = nb2 / na0
		a1 = na1 / na0
		a2 = na2 / na0

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
