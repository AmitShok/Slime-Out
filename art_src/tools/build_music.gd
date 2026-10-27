extends SceneTree
## Composes and renders the gameplay track "Slime Rush" to a seamless loop:
## assets/audio/music/slime_rush.wav (stereo, 44.1 kHz).
##   godot --headless --path <project> --script art_src/tools/build_music.gd
##
## Brief (from combat-music research): 150 BPM, E minor with a phrygian b2
## (F) for danger, a driving 16th-note bass ostinato with short notes,
## four-on-the-floor kick + backbeat snare, 16th arpeggios, a heroic lead.
## Form (8 bars each): A theme -> B chorus -> C breakdown (chromatic bass
## climb E..B under a snare build) -> D theme with a harmony line. Kick
## side-chains the music bus for pump; echo tails wrap across the loop.

const RATE := 44100
const BPM := 150.0
const STEP := 60.0 / BPM / 4.0  # one 16th note
const BAR := STEP * 16.0
const OUT := "res://assets/audio/music/slime_rush.wav"

## Chord per bar: [bass root midi, quality] (quality 0 = minor, 1 = major).
const A_CHORDS := [[40, 0], [36, 1], [38, 1], [35, 1], [40, 0], [36, 1], [38, 1], [35, 1]]
const B_CHORDS := [[45, 0], [41, 1], [43, 1], [35, 1], [45, 0], [41, 1], [43, 1], [35, 1]]
const C_ROOTS := [40, 41, 42, 43, 44, 45, 46, 47]

## Melodies: per bar, [start 16th, length 16ths, midi].
const THEME := [
	[[0, 4, 76], [4, 2, 71], [6, 2, 76], [8, 4, 79], [12, 2, 78], [14, 2, 76]],
	[[0, 6, 79], [6, 2, 81], [8, 4, 79], [12, 4, 76]],
	[[0, 4, 78], [4, 2, 74], [6, 2, 78], [8, 4, 81], [12, 2, 79], [14, 2, 78]],
	[[0, 8, 75], [8, 4, 78], [12, 4, 83]],
	[[0, 4, 83], [4, 2, 81], [6, 2, 79], [8, 4, 81], [12, 4, 83]],
	[[0, 6, 84], [6, 2, 83], [8, 4, 81], [12, 4, 79]],
	[[0, 4, 81], [4, 4, 78], [8, 4, 74], [12, 4, 78]],
	[[0, 8, 83], [8, 4, 78], [12, 4, 75]],
]
const CHORUS := [
	[[0, 2, 81], [2, 2, 84], [4, 4, 88], [8, 2, 86], [10, 2, 84], [12, 4, 83]],
	[[0, 6, 81], [6, 2, 79], [8, 4, 77], [12, 4, 81]],
	[[0, 2, 79], [2, 2, 83], [4, 4, 86], [8, 2, 84], [10, 2, 83], [12, 4, 81]],
	[[0, 4, 78], [4, 4, 75], [8, 4, 78], [12, 4, 81]],
	[[0, 4, 88], [4, 2, 86], [6, 2, 84], [8, 4, 83], [12, 4, 81]],
	[[0, 6, 84], [6, 2, 81], [8, 4, 77], [12, 4, 84]],
	[[0, 4, 83], [4, 2, 81], [6, 2, 79], [8, 4, 78], [12, 4, 79]],
	[[0, 16, 78]],
]
## Bass ostinato: 0 rest, 1 root, 2 octave, 3 fifth.
const BASS_DRIVE := [1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 2, 1, 1, 2, 3]
const BASS_BREAK := [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
const E_MINOR := [0, 2, 3, 5, 7, 8, 10]

var rng := RandomNumberGenerator.new()
var length := 0
var drums_l := PackedFloat32Array()
var drums_r := PackedFloat32Array()
var music_l := PackedFloat32Array()
var music_r := PackedFloat32Array()
var send_l := PackedFloat32Array()
var send_r := PackedFloat32Array()
var kicks: Array[float] = []


func _initialize() -> void:
	rng.seed = 150
	var bars := 32
	var loop_seconds := bars * BAR
	length = int((loop_seconds + 3.0) * RATE)
	for buffer in [drums_l, drums_r, music_l, music_r, send_l, send_r]:
		buffer.resize(length)

	for section in 4:
		for bar in 8:
			var index := section * 8 + bar
			var t := index * BAR
			_compose_bar(section, bar, t)
	print("notes rendered")
	var mix := _master(int(loop_seconds * RATE))
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	_save(mix)
	print("music baked: %.1fs loop" % loop_seconds)
	quit()


func _compose_bar(section: int, bar: int, t: float) -> void:
	var breakdown := section == 2
	var chord: Array
	if section == 1:
		chord = B_CHORDS[bar]
	elif breakdown:
		chord = [C_ROOTS[bar], 0]
	else:
		chord = A_CHORDS[bar]
	var root: int = chord[0]
	var major: bool = chord[1] == 1

	# --- Drums ---
	if breakdown and bar < 6:
		_kick(t)
		_kick(t + 8 * STEP)
		_snare(t + 8 * STEP, 0.9)
		for s in range(0, 16, 2):
			_hat(t + s * STEP, 0.5 if s % 4 else 0.3, false)
	else:
		for beat in 4:
			_kick(t + beat * 4 * STEP)
		if bar % 2 == 1:
			_kick(t + 10 * STEP, 0.7)
		if breakdown:
			# Snare build: 8ths, then 16ths with a crescendo, then the drop.
			var hits := 8 if bar == 6 else 16
			for h in hits:
				var at := t + h * (16.0 / hits) * STEP
				_snare(at, lerpf(0.35, 1.0, (bar - 6 + float(h) / hits) * 0.5))
			_riser(t, bar == 6)
		else:
			_snare(t + 4 * STEP, 1.0)
			_snare(t + 12 * STEP, 1.0)
			for s in 16:
				var open := s == 14 and bar % 4 == 3
				_hat(t + s * STEP, 0.9 if s % 4 == 2 else 0.45, open)
			if bar == 7:  # end-of-section fill
				for s in range(12, 16):
					_snare(t + s * STEP, 0.5 + (s - 12) * 0.15)
	if bar == 0 and section != 2:
		_crash(t)
	if section == 3 and bar == 4:
		_crash(t)

	# --- Bass ---
	var pattern: Array = BASS_BREAK if breakdown else BASS_DRIVE
	var cutoff_boost := float(bar) / 7.0 if breakdown else 0.5
	for s in 16:
		var kind: int = pattern[s]
		if kind == 0:
			continue
		var note: int = root + (12 if kind == 2 else (7 if kind == 3 else 0))
		_bass(t + s * STEP, note, STEP * 0.6, 0.55 if breakdown else 0.75, cutoff_boost)

	# --- Arpeggio (16ths over the chord, alternating pan) ---
	var arp_root := root + 24
	while arp_root > 71:
		arp_root -= 12
	var third := 4 if major else 3
	var tones := [0, third, 7, 12, 7, third, 0, 12]
	if breakdown:
		tones = [0, 3, 7, 12, 7, 3, 0, 12]
		arp_root = 64  # E minor arpeggio over the climbing bass = tension
	for s in 16:
		var note: int = arp_root + tones[s % tones.size()]
		_pulse(t + s * STEP, note, STEP * 0.7, 0.125, 0.11 if not breakdown else 0.14, -0.35 if s % 2 == 0 else 0.35, 0.35)

	# --- Pad under the chorus and final theme ---
	if section == 1 or section == 3:
		for tone in [0, third, 7]:
			_pad(t, root + 24 + tone, BAR, 0.05)

	# --- Lead ---
	var melody: Array = []
	if section == 0 or section == 3:
		melody = THEME[bar]
	elif section == 1:
		melody = CHORUS[bar]
	for n in melody:
		var start: float = t + n[0] * STEP
		var dur: float = n[1] * STEP
		_lead(start, n[2], dur, 0.2, 0.0)
		if section == 3:
			_lead(start, _third_below(n[2]), dur, 0.11, 0.25)


# --- Instruments --------------------------------------------------------------

func _kick(t: float, vel := 1.0) -> void:
	kicks.append(t)
	var n := int(0.32 * RATE)
	var phase := 0.0
	for i in n:
		var lt := float(i) / RATE
		phase += TAU * (48.0 + 120.0 * exp(-lt / 0.025)) / RATE
		var s := sin(phase) * exp(-lt / 0.13) + rng.randf_range(-1.0, 1.0) * exp(-lt / 0.002) * 0.3
		_add(drums_l, drums_r, t, i, tanh(s * 1.6) * 0.75 * vel, 0.0)


func _snare(t: float, vel := 1.0) -> void:
	var n := int(0.22 * RATE)
	var phase := 0.0
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var lt := float(i) / RATE
		phase += TAU * (190.0 + 60.0 * exp(-lt / 0.01)) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + noise - prev)
		prev = noise
		var s := sin(phase) * exp(-lt / 0.045) * 0.6 + hp * exp(-lt / 0.07) * 0.75
		_add(drums_l, drums_r, t, i, s * 0.42 * vel, 0.05)


func _hat(t: float, vel: float, open: bool) -> void:
	var decay := 0.11 if open else 0.022
	var n := int(decay * 5.0 * RATE)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var lt := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.6 * (hp + noise - prev)
		prev = noise
		_add(drums_l, drums_r, t, i, hp * exp(-lt / decay) * 0.16 * vel, 0.25)


func _crash(t: float) -> void:
	var n := int(1.6 * RATE)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var lt := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.75 * (hp + noise - prev)
		prev = noise
		var s := hp * exp(-lt / 0.45) * 0.22
		_add(drums_l, drums_r, t, i, s, -0.3)
		_add(send_l, send_r, t, i, s * 0.2, 0.3)


func _riser(t: float, first_half: bool) -> void:
	var n := int(BAR * RATE)
	var bp := Biquad.bandpass(800.0, 2.0)
	for i in n:
		var progress := (float(i) / n) * 0.5 + (0.0 if first_half else 0.5)
		if i % 64 == 0:
			bp.set_bandpass(lerpf(500.0, 7000.0, progress * progress), 2.0)
		_add(music_l, music_r, t, i, bp.process(rng.randf_range(-1.0, 1.0)) * progress * 0.12, 0.0)


## Bass: PolyBLEP 25% pulse + sub sine through an enveloped resonant lowpass.
func _bass(t: float, note: int, dur: float, vel: float, brightness: float) -> void:
	var freq := _hz(note)
	var n := int((dur + 0.03) * RATE)
	var lp := Biquad.lowpass(400.0, 2.5)
	var phase := 0.0
	for i in n:
		var lt := float(i) / RATE
		if i % 32 == 0:
			lp.set_lowpass(220.0 + (1400.0 + brightness * 1600.0) * exp(-lt / 0.05), 2.5)
		phase = fmod(phase + freq / RATE, 1.0)
		var pulse := _blep_pulse(phase, freq / RATE, 0.25)
		var s := lp.process(pulse) * 0.7 + sin(TAU * phase) * 0.55
		var env := minf(1.0, lt / 0.003) * (1.0 if lt < dur else exp(-(lt - dur) / 0.01))
		_add(music_l, music_r, t, i, tanh(s * 1.3) * env * 0.42 * vel, 0.0)


func _pulse(t: float, note: int, dur: float, duty: float, vel: float, pan: float, send: float) -> void:
	var freq := _hz(note)
	var n := int((dur + 0.02) * RATE)
	var phase := 0.0
	for i in n:
		var lt := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		var env := minf(1.0, lt / 0.002) * exp(-lt / (dur * 0.6))
		var s := _blep_pulse(phase, freq / RATE, duty) * env * vel
		_add(music_l, music_r, t, i, s, pan)
		_add(send_l, send_r, t, i, s * send, -pan)


func _pad(t: float, note: int, dur: float, vel: float) -> void:
	var n := int((dur + 0.3) * RATE)
	var lp := Biquad.lowpass(1200.0, 0.7)
	var p1 := rng.randf()
	var p2 := rng.randf()
	var f := _hz(note)
	for i in n:
		var lt := float(i) / RATE
		p1 = fmod(p1 + f * 1.004 / RATE, 1.0)
		p2 = fmod(p2 + f * 0.996 / RATE, 1.0)
		var saw := _blep_saw(p1, f / RATE) + _blep_saw(p2, f / RATE)
		var env := minf(1.0, lt / 0.08) * (1.0 if lt < dur else exp(-(lt - dur) / 0.1))
		var s := lp.process(saw) * env * vel
		_add(music_l, music_r, t, i, s, -0.2)
		_add(music_l, music_r, t, i, s, 0.2)


## Lead: two detuned PolyBLEP saws + a square an octave down, lowpassed,
## with delayed vibrato and an echo send.
func _lead(t: float, note: int, dur: float, vel: float, pan: float) -> void:
	var f := _hz(note)
	var n := int((dur + 0.08) * RATE)
	var lp := Biquad.lowpass(3400.0, 0.9)
	var p1 := 0.0
	var p2 := 0.37
	var p3 := 0.0
	for i in n:
		var lt := float(i) / RATE
		var vib := 1.0 + (0.012 * sin(TAU * 5.6 * lt) if lt > 0.16 else 0.0)
		var fv := f * vib
		p1 = fmod(p1 + fv * 1.003 / RATE, 1.0)
		p2 = fmod(p2 + fv * 0.997 / RATE, 1.0)
		p3 = fmod(p3 + fv * 0.5 / RATE, 1.0)
		var s := _blep_saw(p1, fv / RATE) * 0.5 + _blep_saw(p2, fv / RATE) * 0.5 + _blep_pulse(p3, fv * 0.5 / RATE, 0.5) * 0.25
		var env := minf(1.0, lt / 0.006) * (0.85 + 0.15 * exp(-lt / 0.08)) * (1.0 if lt < dur else exp(-(lt - dur) / 0.03))
		s = lp.process(s) * env * vel
		_add(music_l, music_r, t, i, s, pan)
		_add(send_l, send_r, t, i, s * 0.45, pan)


# --- Mix ----------------------------------------------------------------------

func _master(loop_samples: int) -> PackedFloat32Array:
	# Ping-pong echo on the send (dotted 8th).
	var delay := int(STEP * 3.0 * RATE)
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(length)
	out_r.resize(length)
	var echo_l := PackedFloat32Array()
	var echo_r := PackedFloat32Array()
	echo_l.resize(length)
	echo_r.resize(length)
	var lp_l := 0.0
	var lp_r := 0.0
	for i in length:
		var fb_l := echo_r[i - delay] if i >= delay else 0.0
		var fb_r := echo_l[i - delay] if i >= delay else 0.0
		lp_l += ((send_l[i] + fb_l * 0.42) - lp_l) * 0.35
		lp_r += ((send_r[i] + fb_r * 0.42) - lp_r) * 0.35
		echo_l[i] = lp_l
		echo_r[i] = lp_r
	# Side-chain pump from the kick onto music + echoes.
	var duck := PackedFloat32Array()
	duck.resize(length)
	duck.fill(1.0)
	for k in kicks:
		var start := int(k * RATE)
		for i in int(0.25 * RATE):
			var j := start + i
			if j < length:
				duck[j] = minf(duck[j], 1.0 - 0.45 * exp(-float(i) / RATE / 0.08))
	for i in length:
		out_l[i] = drums_l[i] + (music_l[i] + echo_l[i] * 0.6) * duck[i]
		out_r[i] = drums_r[i] + (music_r[i] + echo_r[i] * 0.6) * duck[i]
	# Wrap everything past the loop point back to the start: seamless loop.
	for i in range(loop_samples, length):
		out_l[i - loop_samples] += out_l[i]
		out_r[i - loop_samples] += out_r[i]
	var mix := PackedFloat32Array()
	mix.resize(loop_samples * 2)
	var peak := 0.0
	for i in loop_samples:
		var l := tanh(out_l[i] * 1.2)
		var r := tanh(out_r[i] * 1.2)
		mix[i * 2] = l
		mix[i * 2 + 1] = r
		peak = maxf(peak, maxf(absf(l), absf(r)))
	for i in mix.size():
		mix[i] *= 0.89 / peak
	return mix


func _add(left: PackedFloat32Array, right: PackedFloat32Array, t: float, i: int, s: float, pan: float) -> void:
	var j := int(t * RATE) + i
	if j >= length:
		return
	var angle := (pan + 1.0) * PI * 0.25
	left[j] += s * cos(angle) * 1.414
	right[j] += s * sin(angle) * 1.414


# --- Oscillators --------------------------------------------------------------

func _hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _third_below(note: int) -> int:
	var pc := posmod(note - 64, 12)
	var degree := E_MINOR.find(pc)
	if degree < 0:
		return note - 4  # D# (leading tone) -> B
	var target: int = E_MINOR[posmod(degree - 2, 7)]
	return note - posmod(pc - target, 12)


func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


func _blep_saw(phase: float, dt: float) -> float:
	return (2.0 * phase - 1.0) - _blep(phase, dt)


func _blep_pulse(phase: float, dt: float, duty: float) -> float:
	var s := 1.0 if phase < duty else -1.0
	s += _blep(phase, dt)
	s -= _blep(fmod(phase + 1.0 - duty, 1.0), dt)
	return s


func _save(interleaved: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(interleaved.size() * 2)
	for i in interleaved.size():
		data.encode_s16(i * 2, int(clampf(interleaved[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = true
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(OUT))


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
		f.set_lowpass(freq, q)
		return f

	static func bandpass(freq: float, q: float) -> Biquad:
		var f := Biquad.new()
		f.set_bandpass(freq, q)
		return f

	func set_lowpass(freq: float, q: float) -> void:
		var w := TAU * minf(freq, RATE * 0.45) / RATE
		var alpha := sin(w) / (2.0 * q)
		var c := cos(w)
		_coeffs((1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0, 1.0 + alpha, -2.0 * c, 1.0 - alpha)

	func set_bandpass(freq: float, q: float) -> void:
		var w := TAU * minf(freq, RATE * 0.45) / RATE
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
