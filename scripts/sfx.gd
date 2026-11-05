class_name Sfx
extends Node
## Bare-bones sound: every effect is synthesised at startup (no audio files yet) and played
## through a small pool of players. Sfx.play("clang", volume_db, pitch) from anywhere.
## A per-frame budget stops a settling pile from turning into a wall of noise.

const RATE := 22050
const VOICES := 16
const PER_FRAME := 5

static var _inst: Sfx

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _budget := PER_FRAME


static func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _inst:
		_inst._play(name, volume_db, pitch)


## The impact sound for a material.
static func impact_for(mat: String) -> String:
	match mat:
		"copper", "iron", "steel":
			return "clang"
		"gold", "gem":
			return "ting"
		"stone":
			return "clack"
		"leather", "cloth":
			return "soft"
	return "thud"


func _ready() -> void:
	_inst = self
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	_build()


func _exit_tree() -> void:
	# stop anything still ringing so its playback isn't left dangling at quit
	for p in _players:
		p.stop()
		p.stream = null
	_streams.clear()
	if _inst == self:
		_inst = null


func _process(_delta: float) -> void:
	_budget = PER_FRAME


func _play(name: String, volume_db: float, pitch: float) -> void:
	if not _streams.has(name) or _budget <= 0:
		return
	_budget -= 1
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch * randf_range(0.94, 1.06), 0.3, 3.0)
	p.play()


# --- synthesis -------------------------------------------------------------------

func _build() -> void:
	_streams.thud = _mix([_noise(0.12, 0.08, 30.0), _tone([90.0], [1.0], 0.12, 25.0)], [0.7, 0.6])
	_streams.clang = _mix([_tone([520.0, 1110.0, 1830.0, 2650.0], [1.0, 0.6, 0.4, 0.25], 0.5, 7.0), _noise(0.02, 0.6, 200.0)], [0.5, 0.4])
	_streams.clack = _mix([_noise(0.07, 0.3, 60.0), _tone([300.0], [1.0], 0.05, 60.0)], [0.7, 0.4])
	_streams.soft = _noise(0.1, 0.04, 35.0)
	_streams.ting = _tone([2400.0, 3600.0, 5100.0], [1.0, 0.5, 0.25], 0.25, 14.0)
	_streams.crack = _crackle(0.15)
	_streams.swing = _whoosh(0.22, 0.25)
	_streams.strike = _whoosh(0.35, 0.12)
	_streams.windup = _whoosh(0.5, 0.05)
	_streams.punch = _mix([_noise(0.1, 0.1, 35.0), _tone([70.0], [1.0], 0.1, 30.0)], [0.8, 0.8])
	_streams.hit = _mix([_noise(0.15, 0.2, 25.0), _tone([110.0, 160.0], [1.0, 0.5], 0.15, 20.0)], [0.6, 0.7])
	_streams.hurt = _mix([_tone([70.0], [1.0], 0.25, 12.0), _noise(0.2, 0.1, 15.0)], [0.8, 0.5])
	_streams.parry = _tone([1400.0, 2900.0, 4300.0], [1.0, 0.6, 0.3], 0.8, 5.0)
	_streams.gong = _tone([110.0, 175.0, 236.0, 330.0], [1.0, 0.7, 0.5, 0.3], 2.5, 1.5)
	_streams.boom = _mix([_noise(0.8, 0.03, 5.0), _tone([50.0], [1.0], 0.8, 4.0)], [0.9, 0.9])
	_streams.zap = _buzz(0.2)
	_streams.buy = _mix([_tone([2400.0, 3600.0], [1.0, 0.4], 0.3, 10.0), _delay(_tone([3200.0, 4800.0], [1.0, 0.4], 0.3, 10.0), 0.08)], [0.6, 0.6])
	_streams.deny = _tone([160.0, 170.0], [1.0, 1.0], 0.2, 12.0)
	_streams.scrape = _mix([_crackle(0.9), _noise(0.9, 0.15, 1.5)], [0.4, 0.35])  # a blade dragged along stone
	_streams.feint = _mix([_whoosh(0.12, 0.4), _tone([1800.0, 2700.0], [1.0, 0.5], 0.1, 40.0)], [0.8, 0.3])  # a flick: broken off
	_streams.lock = _mix([_tone([900.0, 1350.0], [1.0, 0.6], 0.06, 60.0), _noise(0.03, 0.5, 120.0)], [0.6, 0.5])  # a click: committed
	_streams.pain = _peak(_pain(0.7), 0.9)
	_streams.reward = _peak(_reward(0.45), 0.9)
	for k in _streams.keys():
		if _streams[k] is PackedFloat32Array:
			_streams[k] = _wav(_streams[k])


func _tone(freqs: Array, amps: Array, dur: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * amps[k]
		out[i] = v * exp(-t * decay) / freqs.size()
	return out


func _noise(dur: float, lowpass: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (randf_range(-1.0, 1.0) - y) * lowpass
		out[i] = y * exp(-t * decay) * 2.0
	return out


## Filtered noise that swells and fades, its brightness rising then falling: a whoosh.
func _whoosh(dur: float, bright: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var k := float(i) / n
		var env := sin(PI * k)
		y += (randf_range(-1.0, 1.0) - y) * bright * (0.3 + env)
		out[i] = y * env * 1.5
	return out


func _crackle(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (randf_range(-1.0, 1.0) if randf() < 0.15 else 0.0) * exp(-t * 20.0)
	return out


func _buzz(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 120.0, 1.0) < 0.5 else -1.0
		out[i] = (sq * 0.4 + randf_range(-0.3, 0.3)) * exp(-t * 10.0)
	return out


## The sting of a blow that got through: a low, clashing cluster (a minor second and a
## tritone, slightly detuned so it beats), driven into distortion, over a heavy thump.
## Played louder (and a touch lower) the harder the hit.
func _pain(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var freqs := [98.0, 104.0, 139.0, 146.5]
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			# a sawtooth-ish tone: a few harmonics, falling off
			for h in [1, 2, 3, 4]:
				v += sin(TAU * f * h * t + h) / (h * 1.4)
		v /= freqs.size()
		var env := minf(1.0, t * 120.0) * exp(-t * 4.0)
		var drive := tanh(v * 3.5) * env * 0.55
		var thump := sin(TAU * (60.0 - 25.0 * minf(1.0, t * 8.0)) * t) * exp(-t * 14.0) * 0.8
		y += (randf_range(-1.0, 1.0) - y) * 0.25
		var grit := y * exp(-t * 25.0) * 0.5
		out[i] = drive + thump + grit
	return out


## The sting of a hit that lands: a punchy thump that drops in pitch, a short bright crack,
## and over it a clean, consonant ring (root, fifth, octave, a major third up) that decays
## fast. Still an impact, but one that sounds good. Played louder the harder the hit.
func _reward(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ring := [880.0, 1320.0, 1760.0, 2217.0]
	var ring_amp := [1.0, 0.7, 0.5, 0.35]
	var y := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 55.0 + 95.0 * exp(-t * 30.0)  # 150 Hz falling to 55: the punch
		phase += TAU * f / RATE
		var thump := sin(phase) * exp(-t * 16.0) * 0.9
		y += (randf_range(-1.0, 1.0) - y) * 0.6
		var crack := y * exp(-t * 60.0) * 0.6
		var v := 0.0
		for k in ring.size():
			v += sin(TAU * ring[k] * t) * ring_amp[k]
		var shine := v / ring.size() * minf(1.0, t * 300.0) * exp(-t * 9.0) * 0.55
		out[i] = thump + crack + shine
	return out


## Scale a sound so its loudest sample sits at `level` (no clipping on the attack).
func _peak(a: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var top := 0.0
	for v in a:
		top = maxf(top, absf(v))
	if top <= 0.0:
		return a
	var k := level / top
	for i in a.size():
		a[i] *= k
	return a


func _delay(a: PackedFloat32Array, secs: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(secs * RATE))
	pad.append_array(a)
	return pad


func _mix(parts: Array, gains: Array) -> AudioStreamWAV:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for k in parts.size():
		var p: PackedFloat32Array = parts[k]
		for i in p.size():
			out[i] += p[i] * gains[k]
	return _wav(out)


func _wav(samples: Variant) -> AudioStreamWAV:
	var data: PackedFloat32Array = samples if samples is PackedFloat32Array else PackedFloat32Array()
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
