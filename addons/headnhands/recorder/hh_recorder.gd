# The HeadnHands VR recorder: perform as a character, watch yourself in a
# live mirror, record takes, replay them, and bake them to animation clips.
# Run hh_recorder.tscn (or a scene inheriting it, to dress the stage) with
# the headset on.
#
# Controls (in the headset). X/Y/A/B only act as controls while NOT
# recording; during a take they're performance inputs (blink, flash, ...).
#
#   Left MENU        start the 3-2-1 countdown / stop recording
#                    (press during the countdown to cancel)
#   Left X           choose the character you're performing for
#   Left Y           play-along on/off: your previous take plays on its character
#                    while you record the next one (act a scene with yourself)
#   Right A          replay the last take on the character / back to live mirror
#   Right B          character view: mirror (facing you) <-> behind (facing away)
#   Right stick in   show/hide the cyan ghost cubes (raw recording)
#   Right stick L/R  step through the character's CUE LIST: the clips the
#                    project still needs from it (HHCues). With a cue picked,
#                    the next take is named and baked as that clip.
#                    Left/Right arrow keys do the same at the desk.
#   Left stick in    punch-in mode: off -> right arm -> left arm -> head -> face.
#                    While punching, the last take plays on the character and you
#                    re-perform ONLY that part; the result is comped into a
#                    new take (the old one is kept).
#   Space (keyboard) same as MENU, for testing at the desk
#
# Takes save to the takes folder (Project Settings > headnhands/paths). When a
# character is chosen, each take is also cleaned up and baked straight into
# <animations folder>/<character>/.
class_name HHRecorder
extends Node3D

enum State { IDLE, COUNTDOWN, RECORDING }

const COUNTDOWN_SECONDS := 3.0
## How far in front of the floor mark the mirror character stands, in meters.
## (Each character sets its own height: HHRig.mount_height.)
@export var stage_distance := 2.2
## Where the play-along character stands (to your front-right), on the floor.
@export var play_along_position := Vector3(1.6, 0.0, -1.3)

@onready var head: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var hud: Label3D = $Hud
@onready var beeper: AudioStreamPlayer = $Beeper
@onready var ghost: Node3D = $Ghost
@onready var ghost_head: Node3D = $Ghost/Head
@onready var ghost_left: MeshInstance3D = $Ghost/LeftHand
@onready var ghost_right: MeshInstance3D = $Ghost/RightHand
@onready var stage: Node3D = $Stage
@onready var play_along_spot: Node3D = $PlayAlongSpot

var state := State.IDLE
var countdown := 0.0
var record_start_usec := 0
var take: HHTake              # the take being recorded right now
var height_samples := PackedFloat32Array()
var calibrated_eye_height := 0.0

# Character you're performing for, and its live/replay rig.
var character_ids := PackedStringArray()
var character_index := -1              # -1 = no character (cubes only)
var character: HHRig
var smoother := HHFrameSmoother.new()
var mirror_view := true

# Replay of the last take.
var last_take: HHTake         # raw
var last_take_path := ""
var last_clean: HHTake        # cleaned, what gets baked
var replay: HHPlayback
var ghost_time := 0.0
var ghost_cubes_visible := true
var status_line := ""

# Punch-in.
const PUNCH_MODES := ["", "right", "left", "head", "face"]
var punch_index := 0
var punch_base: HHTake        # raw take being punched into
var punch_base_path := ""
var punch_preview: HHTake     # cleaned, for the live preview

# The cue list: clips still to perform for this character; -1 = a free take
# (named later, in the editor's Takes panel).
var cues: Array[Dictionary] = []
var cue_index := -1
var _stick_ready := true

# Play-along.
var play_along := false
var along_character: HHRig
var along_playback: HHPlayback
var along_path := ""

var beep_tick: AudioStreamWAV
var beep_go: AudioStreamWAV
var beep_stop: AudioStreamWAV


func _ready() -> void:
	_start_xr()
	beep_tick = _make_beep(660.0, 0.12)
	beep_go = _make_beep(1320.0, 0.3)
	beep_stop = _make_beep(440.0, 0.3)
	left_hand.button_pressed.connect(_on_left_button)
	right_hand.button_pressed.connect(_on_right_button)

	character_ids = HHCharacters.ids()
	_place_stage()
	play_along_spot.position = Vector3(play_along_position.x, 0.0, play_along_position.z)
	play_along_spot.look_at(Vector3.ZERO, Vector3.UP)
	_load_latest_take()
	# Start on the character of the newest take, if it has one.
	if last_take and character_ids.has(last_take.character_id):
		_select_character(character_ids.find(last_take.character_id))
	else:
		_select_character(0 if character_ids.size() > 0 else -1)


func _process(delta: float) -> void:
	var live := HHFrame.capture(head, left_hand, right_hand)
	match state:
		State.COUNTDOWN:
			_tick_countdown(delta)
			_drive_live(live, delta)
			if along_playback:
				along_playback.restart()   # hold at the first frame
				along_playback.step(0.0)
		State.RECORDING:
			_record_frame(live)
			_drive_live(live, delta)
			if along_playback:
				along_playback.step(delta)
		State.IDLE:
			_cue_stick(live.right_stick.x)
			if replay:
				replay.step(delta)
			elif character:
				_drive_live(live, delta)
			if along_playback and replay:
				along_playback.step(delta)
			_play_ghost(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_recording()
	if event is InputEventKey and event.pressed and not event.echo and state == State.IDLE:
		if event.keycode == KEY_RIGHT:
			step_cue(1)
		elif event.keycode == KEY_LEFT:
			step_cue(-1)


# --- Controls -------------------------------------------------------------

func _on_left_button(button_name: String) -> void:
	if button_name == "menu_button":
		_toggle_recording()
		return
	if state != State.IDLE:
		return
	if button_name == "ax_button":
		_select_character(character_index + 1 if character_index + 1 < character_ids.size() else -1)
		_stop_replay()
	elif button_name == "by_button":
		play_along = not play_along
		_setup_play_along()
	elif button_name == "primary_click":
		punch_index = (punch_index + 1) % PUNCH_MODES.size()


func _punch_group() -> String:
	return PUNCH_MODES[punch_index]


func _on_right_button(button_name: String) -> void:
	if state != State.IDLE:
		return
	match button_name:
		"ax_button":
			# Replaying -> back to the live mirror. Live -> replay from the start.
			if replay:
				_stop_replay()
				return
			ghost_time = 0.0
			if last_clean and character:
				_start_replay()
			if along_playback:
				along_playback.restart()
		"by_button":
			mirror_view = not mirror_view
			_place_stage()
			if replay:
				replay.mirrored = mirror_view
		"primary_click":
			ghost_cubes_visible = not ghost_cubes_visible
			ghost.visible = ghost_cubes_visible and last_take != null


func _toggle_recording() -> void:
	match state:
		State.IDLE:
			_stop_replay()
			state = State.COUNTDOWN
			countdown = COUNTDOWN_SECONDS
			height_samples.clear()
			ghost.visible = false
			_setup_play_along()
			_setup_punch()
			_beep(beep_tick)
		State.COUNTDOWN:
			state = State.IDLE
			ghost.visible = ghost_cubes_visible and last_take != null
		State.RECORDING:
			_finish_recording()


# --- Public controls (the workspace's buttons call these) ---------------------

func is_idle() -> bool:
	return state == State.IDLE


func is_recording() -> bool:
	return state == State.RECORDING


func recording_time() -> float:
	return (Time.get_ticks_usec() - record_start_usec) / 1_000_000.0 if state == State.RECORDING else 0.0


func toggle_recording() -> void:
	_toggle_recording()


func select_character_id(id: String) -> void:
	if state != State.IDLE:
		return
	_select_character(character_ids.find(id))
	_stop_replay()


func pick_cue(index: int) -> void:
	if state == State.IDLE:
		cue_index = clampi(index, -1, cues.size() - 1)


## Replay the last take on the character, or go back to the live mirror.
func toggle_replay() -> void:
	_on_right_button("ax_button")


func toggle_view() -> void:
	_on_right_button("by_button")


func toggle_play_along() -> void:
	_on_left_button("by_button")


func cycle_punch() -> void:
	_on_left_button("primary_click")


func toggle_ghost() -> void:
	_on_right_button("primary_click")


func punch_group() -> String:
	return _punch_group()


func character_id() -> String:
	return _character_id()


# --- Characters ---------------------------------------------------------------

func _select_character(index: int) -> void:
	if character:
		character.queue_free()
		character = null
	character_index = index
	if index < 0 or index >= character_ids.size():
		character_index = -1
		return
	character = HHCharacters.instantiate(character_ids[index])
	if character == null:
		character_index = -1
		return
	cues = HHCues.missing(character_ids[index])
	cue_index = -1
	stage.add_child(character)
	character.position.y = character.mount_height
	character.begin(calibrated_eye_height)
	smoother.reset()


# --- The cue list --------------------------------------------------------

## The cue picked for the next take ({} = a free take).
func current_cue() -> Dictionary:
	return cues[cue_index] if cue_index >= 0 and cue_index < cues.size() else {}


## Next / previous cue; past either end is "free take".
func step_cue(dir: int) -> void:
	if cues.is_empty():
		cue_index = -1
		return
	cue_index += dir
	if cue_index >= cues.size():
		cue_index = -1
	elif cue_index < -1:
		cue_index = cues.size() - 1


# A flick of the right stick steps once; it has to come back to the middle first.
func _cue_stick(x: float) -> void:
	if absf(x) < 0.3:
		_stick_ready = true
	elif _stick_ready and absf(x) > 0.7:
		_stick_ready = false
		step_cue(1 if x > 0.0 else -1)


## Names a fresh take after the picked cue: where it's saved and what it bakes as.
## Returns the path to save to (the timestamped one if there's no cue).
func _cue_path(default_path: String) -> String:
	var cue := current_cue()
	if cue.is_empty() or punch_base or take.character_id != str(cue.character):
		return default_path
	take.clip_name = str(cue.clip)
	if take.recipe == null:
		take.recipe = HHCleanupRecipe.new()
	take.recipe.loop = HHNamingRules.current().loops(str(cue.clip))
	return HHNaming._unique_path(HHTakeStore.takes_dir.path_join(take.character_id).path_join(str(cue.clip) + ".res"))


func _character_id() -> String:
	return character_ids[character_index] if character_index >= 0 else ""


# Mirror view: the character faces you and moves like your reflection.
# Behind view: the character faces away and copies you directly (like
# watching over its shoulder).
func _place_stage() -> void:
	if mirror_view:
		stage.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -stage_distance))
	else:
		stage.transform = Transform3D(Basis(), Vector3(0, 0, -stage_distance))
	smoother.reset()


func _drive_live(live: HHFrame, delta: float) -> void:
	if character == null:
		return
	var f := smoother.smooth(live, delta)
	# Punch-in: the old take drives everything except the part you're redoing.
	if punch_base and state != State.IDLE:
		var t := 0.0
		if state == State.RECORDING:
			t = (Time.get_ticks_usec() - record_start_usec) / 1_000_000.0
		f = HHComp.merge(punch_preview.sample(t), f, PackedStringArray([_punch_group()]))
	character.drive(character.view_frame(f, mirror_view), delta)


# Punch-in needs a previous take for the same character.
func _setup_punch() -> void:
	punch_base = null
	punch_preview = null
	punch_base_path = ""
	if _punch_group().is_empty():
		return
	if last_take == null or last_take.character_id != _character_id():
		status_line = "punch-in needs a previous take for this character - recording normally"
		return
	punch_base = last_take
	punch_base_path = last_take_path
	punch_preview = last_clean if last_clean else HHCleanup.run(last_take).take


func _start_replay() -> void:
	replay = HHPlayback.new(character, last_clean, mirror_view)


func _stop_replay() -> void:
	replay = null
	if character:
		character.begin(calibrated_eye_height)
		smoother.reset()


# Play-along uses the most recent take on its own character.
func _setup_play_along() -> void:
	if along_character:
		along_character.queue_free()
		along_character = null
	along_playback = null
	along_path = ""
	if not play_along or last_take == null or not character_ids.has(last_take.character_id):
		return
	along_character = HHCharacters.instantiate(last_take.character_id)
	if along_character == null:
		return
	play_along_spot.add_child(along_character)
	along_character.position.y = along_character.mount_height
	var clean: HHTake = last_clean if last_clean else HHCleanup.run(last_take).take
	along_playback = HHPlayback.new(along_character, clean, false)
	along_path = last_take_path


# --- Recording ------------------------------------------------------------

func _tick_countdown(delta: float) -> void:
	# Measure eye height during the last second (stand still on the mark).
	if countdown < 1.0:
		height_samples.append(head.position.y)
	var before := ceili(countdown)
	countdown -= delta
	if countdown <= 0.0:
		_begin_recording()
	elif ceili(countdown) < before:
		_beep(beep_tick)


func _begin_recording() -> void:
	if height_samples.size() > 0:
		var total := 0.0
		for h in height_samples:
			total += h
		calibrated_eye_height = total / height_samples.size()
	take = HHTake.new()
	take.created = Time.get_datetime_string_from_system()
	take.character_id = _character_id()
	take.eye_height = calibrated_eye_height
	if along_playback:
		take.overdub_of = PackedStringArray([along_path])
		along_playback.restart()
	record_start_usec = Time.get_ticks_usec()
	state = State.RECORDING
	_beep(beep_go)


func _record_frame(live: HHFrame) -> void:
	var t := (Time.get_ticks_usec() - record_start_usec) / 1_000_000.0
	take.append(t, live)


func _finish_recording() -> void:
	state = State.IDLE
	_beep(beep_stop)
	if take.frame_count() < 2:
		return
	var path := _cue_path(HHTakeStore.new_path())
	var cued := not current_cue().is_empty() and take.clip_name == str(current_cue().clip)
	if punch_base:
		# The raw punch recording is only a source for the comp: no character, so
		# "Bake all" skips it. Kept on disk in case you want to re-comp.
		take.character_id = ""
		take.note = "punch-in source (%s) for %s" % [_punch_group(), punch_base_path.get_file()]
	var err := HHTakeStore.save(take, path)
	if err != OK:
		status_line = "COULD NOT SAVE (error %d)" % err
		push_error("Could not save take to %s (error %d)" % [path, err])
		return
	if punch_base:
		var comp := HHComp.comp(punch_base, take, PackedStringArray([_punch_group()]), 0.0, take.duration())
		comp.created = take.created
		comp.overdub_of = PackedStringArray([punch_base_path, path])
		var comp_path := path.get_basename() + "_punch_%s.res" % _punch_group()
		HHTakeStore.save(comp, comp_path)
		take = comp
		path = comp_path
		punch_base = null
	last_take = take
	last_take_path = path
	last_clean = HHCleanup.run(take).take
	ghost_time = 0.0
	ghost.visible = ghost_cubes_visible
	status_line = "saved %s" % path.get_file()
	if character:
		var r := HHBaker.bake_to_library(take, path, take.character_id)
		status_line += "\nbaked %s/%s" % [take.character_id, r.clip] if r.ok else "\nBAKE FAILED"
		_start_replay()
		if cued and r.ok:   # that cue's done: the list moves on to the next one still missing
			var done := cue_index
			cues = HHCues.missing(take.character_id)
			cue_index = mini(done, cues.size() - 1)
	if along_playback:
		along_playback.restart()


func _load_latest_take() -> void:
	ghost.visible = false
	var path := HHTakeStore.newest()
	if path.is_empty():
		return
	var loaded := HHTakeStore.load_take(path)
	if loaded:
		last_take = loaded
		last_take_path = path
		last_clean = HHCleanup.run(loaded).take
		if loaded.eye_height > 0.0:
			calibrated_eye_height = loaded.eye_height
		ghost.visible = ghost_cubes_visible
		status_line = "loaded %s" % path.get_file()


# --- Ghost cubes (raw take, in place) -------------------------------------

func _play_ghost(delta: float) -> void:
	if last_take == null or last_take.frame_count() < 2:
		return
	ghost_time += delta
	if ghost_time > last_take.duration():
		ghost_time = 0.0
	var f := last_take.sample(ghost_time)
	ghost_head.transform = f.head
	ghost_left.transform = f.left
	ghost_right.transform = f.right
	_tint(ghost_left, f.left_trigger)
	_tint(ghost_right, f.right_trigger)


func _tint(cube: MeshInstance3D, trigger: float) -> void:
	var mat: StandardMaterial3D = cube.get_active_material(0)
	var c := Color(0.3, 0.9, 1.0).lerp(Color(1.0, 0.45, 0.05), trigger)
	c.a = 0.55
	mat.albedo_color = c


# --- HUD, sound, XR -------------------------------------------------------

func _update_hud() -> void:
	var character_name := "no character (cubes only)"
	if character:
		character_name = character.profile.display_name if character.profile else _character_id()
	match state:
		State.COUNTDOWN:
			hud.text = "%d\nstand on the mark, look ahead" % ceili(countdown)
		State.RECORDING:
			var t := (Time.get_ticks_usec() - record_start_usec) / 1_000_000.0
			var punch := "   PUNCH-IN: %s only" % _punch_group().to_upper() if punch_base else ""
			hud.text = "[REC]  %.1f s   %s%s\nleft MENU to stop" % [t, character_name, punch]
		State.IDLE:
			var lines := PackedStringArray()
			lines.append("READY  -  performing as: %s" % character_name)
			lines.append("MENU record   X character   Y play-along: %s   L-stick click punch-in: %s" % [
				"ON" if play_along else "off", _punch_group().to_upper() if _punch_group() else "off"])
			lines.append("A %s   B view: %s   R-stick click: ghost cubes   R-stick L/R: cue" % [
				"back to live" if replay else "replay", "mirror" if mirror_view else "behind"])
			var cue := current_cue()
			if cue.is_empty():
				lines.append(("CUE: free take (%d still needed for this character)" % cues.size()) if character else "CUE: free take")
			else:
				lines.append("CUE %d/%d: %s  (%s)\n  %s" % [cue_index + 1, cues.size(), cue.clip, cue.kind, cue.what])
			if last_take:
				lines.append("")
				lines.append("%s  %.1f s, %d frames, %.0f Hz" % [last_take_path.get_file(), last_take.duration(),
					last_take.frame_count(), last_take.sample_rate()])
			if not status_line.is_empty():
				lines.append(status_line)
			hud.text = "\n".join(lines)


func _beep(sound: AudioStreamWAV) -> void:
	beeper.stream = sound
	beeper.play()


# Builds a short sine-wave beep in memory, with 5 ms fades so it doesn't click.
func _make_beep(freq: float, length: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var fade := rate * 0.005
	for i in n:
		var env := minf(1.0, minf(i, n - i) / fade)
		var s := sin(TAU * freq * i / rate) * 0.4 * env
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _start_xr() -> void:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		push_error("OpenXR did not initialize. Is the headset on Link?")
