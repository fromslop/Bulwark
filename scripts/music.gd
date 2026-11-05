class_name Music
extends Node
## The score, in layers on one bar clock (120 BPM, 4/4: a bar is 2 s). Music.set_mode() from
## anywhere; the rest is timing.
##
## - BASE: bass + pluck, one 61-bar loop that runs for the whole run (fights and shops).
## - DRUMS: kick-only, full kit and claps loops. They run silently alongside the base from the
##   start of the run and are faded in and out on bar lines, so they can never drift from it.
##   A fight builds up (kick, then full kit, then claps on top); a boss starts at full.
## - LEADS: only in a boss fight, once the drums are up: a melody, the bridge, an arp, the
##   bridge, the next melody, and round again. One-shots with their tails, alternated
##   between two players so a tail can ring under the next phrase.
## - AMBIENCE: the fire and the tunnel at home and after a defeat, instead of the score.
##
## Files are res://assets/music/<name>.ogg, cut by tools/make_music.py. A missing file is just
## a silent layer, so the game runs (and the clock still keeps time) before the stems exist.

enum Mode { AMBIENT, CALM, FIGHT, BOSS }

const DIR := "res://assets/music/"
const BAR := 2.0
const BASE_BARS := 61
const PRE_ROLL := 0.05  # silence at the head of every lead file (tools/make_music.py)
const LOOKAHEAD := 0.03  # act this early so a late frame still lands on the line
const SWITCH := 0.03  # drum layer crossfade at a bar line

## Layer levels in dB, on top of the stems' own mix.
const LEVEL := {"base_bass": -6.0, "base_pluck": -6.0, "drum_kick": -6.0, "drum_full": -6.0,
		"drum_claps": -6.0, "lead": -6.0, "amb_cinder": -8.0, "amb_tunnel": -10.0,
		"amb_night": -4.0}

## A normal fight: kick alone, then the full kit, then the claps join (bars after the first line).
const FULL_AFTER := 2
const CLAPS_AFTER := 4
## A boss: bars of full drums before the first melody.
const LEAD_AFTER := 4

## How long each lead is, in bars: the clip's own length in Live. The files run on past it
## (the guitar's delay repeats the phrase at nearly full level, the last note ringing on), so
## each phrase is damped right at its clip's end (CUT_FADE) and the next comes in on time.
const LEADS := {"forge": 2, "battle": 2, "minstrel": 2, "bridge": 1, "arp_a": 2, "arp_b": 4}
const CUT_FADE := 0.12  # the damp at a phrase's end: quick, but not a click
const MELODIES := ["forge", "battle", "minstrel"]
const ARPS := ["arp_a", "arp_b"]
## The boss cycle: [kind, bars it fills]. Each step plays its phrase at least once, and
## again while there are bars left to fill.
const CYCLE := [["melody", 4], ["bridge", 3], ["arp", 4], ["bridge", 3]]

const LOOPS := ["base_bass", "base_pluck", "drum_kick", "drum_full", "drum_claps"]
const DRUMS := ["drum_kick", "drum_full", "drum_claps"]
## Home is a night in by the fire: the hearth crackling, crickets outside (tools/make_night.py).
## The cinder and tunnel recordings play over a death.
const AMBIENCE := ["amb_cinder", "amb_tunnel", "amb_night"]
const HOME_AMBIENCE := "amb_night"
const DEATH_AMBIENCE := ["amb_cinder", "amb_tunnel"]  # the old recordings: for a death

static var _inst: Music
## The hand at death's door: the whole score (and ambience) narrows to a band, lows and highs
## cut away, like hearing it through the ringing in your ears. The game sets this every frame
## (main: a fight, and the hand below a quarter); it eases in and out.
static var critical := false
const CRIT_LOW_PASS := 1400.0  # the highs gone above this (Hz), at full effect
const CRIT_HIGH_PASS := 380.0  # the lows gone below this
const CRIT_IN := 1.6  # per second: closes in over a moment...
const CRIT_OUT := 0.8  # ...and opens back up slower, as you come round
var _crit := 0.0
var _crit_fx: Array = []  # [low pass, high pass] on the Music bus

var mode := Mode.AMBIENT
var _mode_set := false  # has anyone asked for a mode yet
var _amb_now: Array = []  # the ambience AMBIENT mode is playing
var trace: Array = []  # [clock, what] for tests (the last TRACE_MAX)
const TRACE_MAX := 400

var _players := {}  # layer -> AudioStreamPlayer
var _gain := {}  # layer -> current linear gain
var _target := {}  # layer -> linear gain it's heading for
var _rate := {}  # layer -> gain per second
var _events: Array = []  # [time, layer, gain, fade]; fire at `time`
var _lead_players: Array[AudioStreamPlayer] = []
var _lead_cut: Array[float] = []  # per lead player: clock time its phrase ends (-1: none)
var _lead_streams := {}
var _lead_turn := 0

var _running := false
var _clock := 0.0
var _last_pos := 0.0
var _wraps := 0
var _heard_mark := 0.0
var _moving := 0.0  # seconds the audio has kept advancing
var _stall := 0.0  # seconds since the audio position last moved
var _pace_t := 0.0  # frame time since the last pace check
var _pace_heard := 0.0  # where the audio was then
var _audio_real := false  # the audio has been keeping real time: trust it as the clock
var _step_check := 0.0  # time to the next look at whether every stem is still in step
var _bass_at_check := -1.0
const STEP_EVERY := 2.0
const STEP_SLACK := 0.04  # seconds a stem may drift from the bass before it's put back

var _lead_at := -1.0  # clock time of the next lead phrase's downbeat; -1 = none planned
var _cycle_i := 0
var _step_left := 0  # bars left in this step of the cycle
var _step_lead := ""
var _last_melody := ""
var _last_arp := ""


## `ambience`: which ambient recordings play in AMBIENT mode (home's night by default; a
## death gets the old cinder and tunnel).
static func set_mode(m: Mode, ambience: Array = []) -> void:
	if _inst:
		_inst._set_mode(m, ambience)


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # the score plays on under the pause menu
	for layer in LOOPS + AMBIENCE:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = _load(layer, true)
		add_child(p)
		_players[layer] = p
		_gain[layer] = 0.0
		_target[layer] = 0.0
		_rate[layer] = 1.0
		_apply(layer)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = LEVEL.lead
		add_child(p)
		_lead_players.append(p)
		_lead_cut.append(-1.0)
	for k in LEADS:
		_lead_streams[k] = _load("lead_" + k, false)


func _tick_critical(delta: float) -> void:
	var want := 1.0 if critical else 0.0
	if _crit == want and (_crit_fx.is_empty() or want == 0.0):
		return
	_crit = move_toward(_crit, want, delta * (CRIT_IN if critical else CRIT_OUT))
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	if _crit_fx.is_empty():
		var lp := AudioEffectLowPassFilter.new()
		var hp := AudioEffectHighPassFilter.new()
		AudioServer.add_bus_effect(bus, lp)
		AudioServer.add_bus_effect(bus, hp)
		_crit_fx = [lp, hp]
	var on := _crit > 0.0
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) in _crit_fx:
			AudioServer.set_bus_effect_enabled(bus, i, on)
	var t := _crit * _crit * (3.0 - 2.0 * _crit)  # smoothstep
	(_crit_fx[0] as AudioEffectLowPassFilter).cutoff_hz = exp(lerpf(log(20000.0), log(CRIT_LOW_PASS), t))
	(_crit_fx[1] as AudioEffectHighPassFilter).cutoff_hz = exp(lerpf(log(20.0), log(CRIT_HIGH_PASS), t))


## How far the critical filter has closed in (0 open, 1 full), for the tests.
static func critical_amount() -> float:
	return _inst._crit if _inst else 0.0


func _exit_tree() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) in _crit_fx:
				AudioServer.remove_bus_effect(bus, i)
	_crit_fx.clear()
	for p in get_children():
		if p is AudioStreamPlayer:
			p.stop()
			p.stream = null
	if _inst == self:
		_inst = null


func _load(name: String, loop: bool) -> AudioStream:
	var path := DIR + name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = loop
	return s


# --- modes -----------------------------------------------------------------------

func _set_mode(m: Mode, ambience: Array = []) -> void:
	var amb: Array = ambience if not ambience.is_empty() else [HOME_AMBIENCE]
	# (the first request always applies: a fresh player starts in AMBIENT on paper, with
	# nothing actually faded in, so "already ambient" would leave home silent after a reload)
	if _mode_set and m == mode and _running == (m != Mode.AMBIENT) and (m != Mode.AMBIENT or amb == _amb_now):
		return
	_amb_now = amb
	_mode_set = true
	mode = m
	trace.append([_clock, "mode " + Mode.keys()[m]])
	_lead_at = -1.0  # whatever phrase is ringing finishes; nothing new is planned
	_events.clear()
	if m == Mode.AMBIENT:
		for layer in AMBIENCE:
			_fade(layer, 1.0 if amb.has(layer) else 0.0, 3.0)
		for layer in LOOPS:
			_fade(layer, 0.0, 2.0)
		return
	for layer in AMBIENCE:
		_fade(layer, 0.0, 2.0)
	var line := _start_run() if not _running else _next_line()
	_fade("base_bass", 1.0, 0.5)
	_fade("base_pluck", 1.0, 0.5)
	match m:
		Mode.CALM:
			for layer in DRUMS:  # the drums ride out the bar they're in, then a bar's fade
				_at(line, layer, 0.0, BAR)
		Mode.FIGHT:
			_at(line, "drum_kick", 1.0, SWITCH)
			_at(line, "drum_full", 0.0, SWITCH)
			_at(line, "drum_claps", 0.0, SWITCH)
			_at(line + FULL_AFTER * BAR, "drum_kick", 0.0, SWITCH)
			_at(line + FULL_AFTER * BAR, "drum_full", 1.0, SWITCH)
			_at(line + CLAPS_AFTER * BAR, "drum_claps", 1.0, SWITCH)
		Mode.BOSS:
			_at(line, "drum_kick", 0.0, SWITCH)
			_at(line, "drum_full", 1.0, SWITCH)
			_at(line, "drum_claps", 1.0, SWITCH)
			_cycle_i = 0
			_step_left = 0
			_lead_at = line + LEAD_AFTER * BAR


## Every loop starts on the same frame from its top, silent except what the mode fades in, so
## the whole score stays sample-locked. Returns the first bar line (now).
func _start_run() -> float:
	_running = true
	_clock = 0.0
	_last_pos = 0.0
	_wraps = 0
	_heard_mark = 0.0
	_moving = 0.0
	for layer in LOOPS:
		_gain[layer] = 0.0
		_target[layer] = 0.0
		_apply(layer)
		var p: AudioStreamPlayer = _players[layer]
		if p.stream:
			p.play()
	trace.append([_clock, "start"])
	return 0.0


func _next_line() -> float:
	return ceilf((_clock + LOOKAHEAD) / BAR) * BAR


func _at(time: float, layer: String, gain: float, fade: float) -> void:
	# a fade in finishes on the line; a fade out starts on it
	_events.append([time - fade if gain > _target_at(layer, time) else time, layer, gain, fade])


## What the layer will be heading for just before `time`, counting events already planned.
func _target_at(layer: String, time: float) -> float:
	var g: float = _target[layer]
	for e in _events:
		if e[1] == layer and e[0] <= time:
			g = e[2]
	return g


func _fade(layer: String, gain: float, seconds: float) -> void:
	_target[layer] = gain
	_rate[layer] = 1.0 / maxf(seconds, 0.001)


func _apply(layer: String) -> void:
	_players[layer].volume_db = linear_to_db(maxf(_gain[layer], 0.0001)) + LEVEL[layer]


# --- the clock ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_clock(delta)
	_tick_critical(delta)
	var now := _clock + LOOKAHEAD
	while not _events.is_empty():
		_events.sort_custom(func(a, b): return a[0] < b[0])
		if _events[0][0] > now:
			break
		var e: Array = _events.pop_front()
		_fade(e[1], e[2], e[3])
		trace.append([_clock, "%s -> %.0f" % [e[1], e[2]]])
	if _lead_at >= 0.0 and now + PRE_ROLL >= _lead_at:
		_play_lead()
	_damp_leads()
	for layer in _gain:
		if _gain[layer] != _target[layer]:
			_gain[layer] = move_toward(_gain[layer], _target[layer], _rate[layer] * delta)
			_apply(layer)
	_run_out()
	_ambience_on()
	if mode == Mode.CALM:
		for layer in DRUMS:
			# no drums in the shop, whatever happened to the fade that was planned
			if _target[layer] > 0.0 and not _drum_event_pending(layer):
				_fade(layer, 0.0, BAR)
	_step_check -= delta
	if _step_check <= 0.0:
		_step_check = STEP_EVERY
		_keep_in_step()


## Music time in seconds since the run's loops started. Read off the bass player while its
## position is moving (it's the audio clock); otherwise counted in frames, so tests and a missing file
## still keep time.
func _tick_clock(delta: float) -> void:
	if not _running:
		return
	_clock += delta
	var p: AudioStreamPlayer = _players.base_bass
	if not (p.stream and p.playing):
		return
	var pos := p.get_playback_position() + AudioServer.get_time_since_last_mix()
	if pos < _last_pos - BAR:
		_wraps += 1
	_last_pos = pos
	var heard := _wraps * BASE_BARS * BAR + pos
	# The audio is the truth while it's really running. It moves in mix-sized steps (most
	# frames see no change), so it counts as stalled only after a quarter second without
	# moving; and it's trusted only once a whole second of it has kept pace with the frames
	# (a sped-up headless test, or a stalled device, never does), then frame time carries on.
	if heard > _heard_mark + 0.0001:
		_stall = 0.0
		_heard_mark = heard
	else:
		_stall += delta
	_moving = _moving + delta if _stall < 0.25 else 0.0
	_pace_t += delta
	if _pace_t >= 1.0:
		var ratio := (heard - _pace_heard) / _pace_t
		_audio_real = _stall < 0.25 and ratio > 0.8 and ratio < 1.25
		_pace_t = 0.0
		_pace_heard = heard
	if _audio_real and (absf(heard - _clock) < 0.25 or _moving > 1.0):
		_clock = heard


func _drum_event_pending(layer: String) -> bool:
	for e in _events:
		if e[1] == layer:
			return true
	return false


## Every stem started on the same frame from its top, so where each one should be is the
## bass's place in the music, wrapped to the stem's own length. Any stem that has drifted
## (or stopped) is put back in step. Only while the audio is really running: the headless
## driver never advances, and there's nothing to line up then.
func _keep_in_step() -> void:
	if not _running:
		return
	var bass: AudioStreamPlayer = _players.base_bass
	if not (bass.stream and bass.playing):
		return
	var at := bass.get_playback_position()
	var moved := absf(at - _bass_at_check) > 0.5
	_bass_at_check = at
	if not moved or not _audio_real:
		return  # (headless, or a stalled device: nothing real to line up)
	var base_len := bass.stream.get_length()
	var heard := _wraps * base_len + bass.get_playback_position()
	for layer in LOOPS:
		if layer == "base_bass":
			continue
		var p: AudioStreamPlayer = _players[layer]
		if p.stream == null:
			continue
		var length := p.stream.get_length()
		if length <= 0.0:
			continue
		var want := fmod(heard, length)
		if not p.playing:
			p.play(want)
			trace.append([_clock, "%s restarted in step" % layer])
			continue
		var off := p.get_playback_position() - want
		off -= roundf(off / length) * length  # the short way round the loop
		if absf(off) > STEP_SLACK:
			p.seek(want)
			trace.append([_clock, "%s back in step (%.3f s off)" % [layer, off]])


## Once the score has faded out at home, stop it, so the next run starts from bar 1.
func _run_out() -> void:
	if not _running or mode != Mode.AMBIENT:
		return
	for layer in LOOPS:
		if _gain[layer] > 0.0:
			return
	for layer in LOOPS:
		_players[layer].stop()
	_running = false
	trace.append([_clock, "stopped"])


func _ambience_on() -> void:
	for layer in AMBIENCE:
		var p: AudioStreamPlayer = _players[layer]
		if p.stream and not p.playing and _target[layer] > 0.0:
			p.play()
		elif p.playing and _gain[layer] <= 0.0 and _target[layer] <= 0.0:
			p.stop()


# --- the boss's guitar -----------------------------------------------------------------

func _play_lead() -> void:
	if _step_left <= 0:
		var step: Array = CYCLE[_cycle_i % CYCLE.size()]
		_cycle_i += 1
		_step_left = step[1]
		_step_lead = _pick(step[0])
	var bars: int = LEADS[_step_lead]
	var p := _lead_players[_lead_turn]
	_lead_cut[_lead_turn] = _lead_at + bars * BAR
	_lead_turn = (_lead_turn + 1) % _lead_players.size()
	var s: AudioStream = _lead_streams[_step_lead]
	if s:
		p.stream = s
		p.volume_db = LEVEL.lead
		p.play(maxf(_clock - (_lead_at - PRE_ROLL), 0.0))
	trace.append([_lead_at, "lead " + _step_lead])
	if trace.size() > TRACE_MAX:
		trace = trace.slice(trace.size() - TRACE_MAX)
	_lead_at += bars * BAR
	_step_left -= bars


## A phrase past its clip's end is damped: no delay repeats, no last note ringing on.
func _damp_leads() -> void:
	for i in _lead_players.size():
		var cut := _lead_cut[i]
		var p := _lead_players[i]
		if cut < 0.0 or not p.playing or _clock < cut:
			continue
		var k := (_clock - cut) / CUT_FADE
		if k >= 1.0:
			p.stop()
			p.volume_db = LEVEL.lead
			_lead_cut[i] = -1.0
		else:
			p.volume_db = LEVEL.lead + linear_to_db(maxf(1.0 - k, 0.001))


func _pick(kind: String) -> String:
	match kind:
		"melody":
			var options := MELODIES.filter(func(m): return m != _last_melody)
			_last_melody = options.pick_random()
			return _last_melody
		"arp":
			var options := ARPS.filter(func(a): return a != _last_arp)
			_last_arp = options.pick_random()
			return _last_arp
	return kind
