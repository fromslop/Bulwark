## Hoardsman's recording studio: the HeadnHands recorder with a workspace of windows round
## you, so a whole session happens in the headset.
##
##   front, low     SLATE         what you're performing now, its direction, and the state
##                                (ready / 3-2-1 / recording): read it without looking
##                                away from the mirror
##   left           CUES          the character's clips, grouped, with what's recorded
##   far left       CAST          every foe and how far along its clips are
##   right          PLAYER'S VIEW the game camera's view of you-as-the-foe, the attack's
##                                field over it, and your weapon tip's path across it
##   far right      DECK          record, replay, view, play-along, punch-in, last take
##   behind right   ASSIGN        who performs each foe's clips: itself, another foe, or
##                                nobody (StudioAssign)
##
## On the stage itself: the player's screen stands as a frame in front of the character
## (its edges are the edges of what the player sees), the attack's field floats in it, where the
## blow has to pass, your controllers carry the foe's weapon (a ghost of it) so you feel
## its length, and two faint spheres show where its hands rest (its idle's first pose):
## start and end an attack there and it flows out of the idle and back.
##
## An attack take runs to a beat (StudioGuide): settle, the wind-up over the game's own
## wind-up time, the strike (pull the trigger as your blow lands), the follow-through, and
## it stops by itself. Baking fits it so the game's blow lands on yours.
##
## Run recording/studio/studio.tscn with --xr-mode on and the headset on Link. At the desk
## (no headset) the mouse works the windows (see HHWorkspace).
extends HHRecorder

const KIND_ORDER := ["idle", "attack", "guard", "reaction", "death"]
## How far back in your room the floor mark (and the whole studio with it) stands from
## where the headset's floor origin is, metres. Takes don't care: the rig measures from
## where you stand when a take starts.
const MARK_BACK := 0.3

var workspace: HHWorkspace
var slate: StudioSlate
var cue_board: StudioCueBoard
var cast: StudioCast
var view: StudioPlayerView
var deck: StudioDeck
var assign_board: StudioAssign
var bake_on_assign := true  # (tests turn the background rebake off)
var one_take_per_clip := true  # a new take of a clip sends the last to the recycle bin (tests turn it off)
var _bake_at := -1.0  # when to rebake the shared clips after the last change to who performs what
var field: StudioField
var right_aim: XRController3D
var _weapons: Array[Node3D] = []
var _sig := ""
var _who := "-"  # the character the windows were last built for
var _defaults := {}
var shared_cues: Array[Dictionary] = []  # this foe's clips that another foe performs
var guide: StudioGuide  # the beat of the attack being recorded (null: not an attack take)
var plan: StudioGuide   # the beat the picked attack will be recorded to (shown before the take)
var _rest_ghosts: Array[MeshInstance3D] = []
var _beep_windup: AudioStreamWAV
var _beep_strike: AudioStreamWAV


func _ready() -> void:
	super._ready()
	$XROrigin3D.position.z = -MARK_BACK  # (the room's origin a foot forward: you stand a foot further back)
	hud.visible = false  # the windows say it all now
	right_aim = XRController3D.new()
	right_aim.name = "RightAim"
	right_aim.tracker = &"right_hand"
	right_aim.pose = &"aim"
	$XROrigin3D.add_child(right_aim)
	workspace = HHWorkspace.new()
	workspace.name = "Workspace"
	add_child(workspace)
	workspace.head = head
	workspace.aim = right_aim
	workspace.desk_camera = null if get_viewport().use_xr else head
	workspace.can_point = func() -> bool: return is_idle()
	slate = StudioSlate.new(self)
	cue_board = StudioCueBoard.new(self)
	cast = StudioCast.new(self)
	view = StudioPlayerView.new(self)
	deck = StudioDeck.new(self)
	assign_board = StudioAssign.new(self)
	_defaults = {
		slate.name: HHWorkspace.arc(0.0, 1.0, -0.62),
		cue_board.name: HHWorkspace.arc(36.0, 1.15, -0.12),
		cast.name: HHWorkspace.arc(72.0, 1.2, -0.1),
		view.name: HHWorkspace.arc(-36.0, 1.15, -0.08),
		deck.name: HHWorkspace.arc(-70.0, 1.2, -0.18),
		assign_board.name: HHWorkspace.arc(-118.0, 1.3, -0.1),
	}
	for p in [slate, cue_board, cast, view, deck, assign_board]:
		workspace.add_panel(p, _defaults[p.name])
	field = StudioField.new()
	add_child(field)
	_beep_windup = _make_beep(880.0, 0.14)
	_beep_strike = _make_beep(1760.0, 0.09)
	_on_character()


func _process(delta: float) -> void:
	super._process(delta)
	var sig := "%s|%d|%d|%s|%s|%s|%s|%s|%s" % [character_id(), cue_index, state, mirror_view, play_along,
		punch_group(), replay != null, last_take_path, character.get("_home") if character else null]
	if character_id() != _who:
		_on_character()
		sig = "%s|%d" % [sig, cue_index]
	if sig != _sig:
		_sig = sig
		refresh()
	if is_recording() and guide:
		_run_guide()
	slate.tick()
	field.follow(self)
	if _bake_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _bake_at:
		_bake_at = -1.0
		_bake_assignments()
	_show_rest_ghosts()


## Everything that shows the state of things, redrawn.
func refresh() -> void:
	var w := float(current_cue().get("windup", 0.0))
	var cue := current_cue()
	plan = StudioGuide.new(w, float(cue.get("windup2", 0.0)), float(cue.get("gap", 0.0))) if cue_attack(cue).size() > 0 and w > 0.0 else null
	for p in [slate, cue_board, view, deck]:
		p.refresh()
	if is_idle():  # (the boards over every foe wait while a take starts and runs: nothing on them can change then)
		cast.refresh()
		assign_board.refresh()
	field.show_cue(self, current_cue())


## The studio keeps the whole list (recorded ones too, to redo), not just what's missing,
## and starts on the first clip still to do. Clips another foe performs for this one
## (HoardsmanCues: shared by grip or build) aren't in it: they're in `shared_cues`.
func _on_character() -> void:
	if character == null:
		cues = []
		shared_cues = []
		cue_index = -1
	else:
		_load_cues()
		cue_index = cues.find_custom(func(c: Dictionary) -> bool: return not c.recorded)
	_who = character_id()
	assign_board.show_foe(_who)
	_dress_controllers()
	_sig = ""


## Picking a character (even the one already on the stage: the recorder makes it afresh,
## and narrows its list to what's missing) puts the studio's whole list back.
func _select_character(index: int) -> void:
	super._select_character(index)
	if assign_board:  # (the recorder picks the first one before the studio's windows are up: _ready does it then)
		_on_character()


# --- one view -----------------------------------------------------------------------

## The foe always faces you (the recorder's mirror view): the behind view only confused
## things, so B does nothing here.
func _on_right_button(button_name: String) -> void:
	if button_name == "by_button":
		return
	super._on_right_button(button_name)


func toggle_view() -> void:
	pass


# --- the beat -----------------------------------------------------------------------

func _begin_recording() -> void:
	super._begin_recording()
	if character and punch_base == null:
		character.begin(calibrated_eye_height)  # where you stand now is where the take starts from
		smoother.reset()
	guide = StudioGuide.new(plan.windup, plan.windup2, plan.gap) if plan and punch_base == null else null


func _run_guide() -> void:
	var t := recording_time()
	for beat in guide.tick(t, right_hand.get_float("trigger")):
		match beat:
			"windup":
				_beep(_beep_windup)
			"strike":
				_beep(_beep_strike)
				right_hand.trigger_haptic_pulse("haptic", 0.0, 0.8, 0.08, 0.0)
	if t >= guide.stop_at():
		toggle_recording()  # the follow-through's done: stop, save and bake


func _finish_recording() -> void:
	var picked := current_cue()
	if guide and take:
		# the beat's marks go in the take, and the recipe pins them to the game's timing
		take.marks = guide.marks()
		if take.recipe == null:
			take.recipe = HHCleanupRecipe.new()
		take.recipe.fit_marks = guide.fit()
	guide = null
	super._finish_recording()
	HoardsmanCues.invalidate()  # (a new take is on disk)
	# (the recorder narrows the list to what's missing: keep it whole, and move on from
	# the clip just recorded to the next one still to do)
	if character:
		# one take per clip: the new one replaces the last (which goes to the recycle bin)
		if one_take_per_clip and last_take and last_take.clip_name != "" and last_take_path.get_base_dir().get_file() == last_take.character_id:
			last_take_path = HHTakeStore.keep_only(last_take_path, last_take.clip_name)
		_load_cues()
		_bake_for_sharers(last_take_path)
		var at := cues.find_custom(func(c: Dictionary) -> bool: return c.clip == picked.get("clip", ""))
		var next := -1
		for i in cues.size():
			var k := (at + 1 + i) % cues.size()
			if not cues[k].recorded:
				next = k
				break
		cue_index = next if next >= 0 else at
	_sig = ""


# --- shared clips ---------------------------------------------------------------------

## This foe's own cues (sorted the way you work through them), and the ones it shares.
## Clips marked not needed (the Assign window) are in neither.
func _load_cues() -> void:
	var all := HHCues.all(character_id())
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return KIND_ORDER.find(a.kind) < KIND_ORDER.find(b.kind))
	cues = []
	shared_cues = []
	for c in all:
		if c.get("skipped", false):
			continue
		if c.get("shared", false):
			shared_cues.append(c)
		else:
			cues.append(c)


## Who performs what changed (the Assign window): the lists update now, staying on the
## picked clip if it's still this foe's to record, and the shared clips are rebaked a
## moment after the last change (so a few quick choices make one bake, not several).
func assignments_changed() -> void:
	if character:
		var picked: String = current_cue().get("clip", "")
		_load_cues()
		var at := cues.find_custom(func(c: Dictionary) -> bool: return c.clip == picked)
		cue_index = at if at >= 0 else cues.find_custom(func(c: Dictionary) -> bool: return not c.recorded)
	if bake_on_assign:
		_bake_at = Time.get_ticks_msec() / 1000.0 + 2.0
	_sig = ""


## Every foe's clips as assigned: own takes on their own foe, shared ones baked onto the
## foes that use them, and the clips nobody needs removed. A separate headless Godot does
## it, so the headset never stutters.
func _bake_assignments() -> void:
	var args := ["--headless", "--xr-mode", "off", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/bake_shared.gd"]
	OS.create_process(OS.get_executable_path(), args)
	status_line = "rebaking the shared clips in the background"


## A take of a clip other foes share is baked for each of them too, through their own
## rigs, by a separate headless Godot (so the headset never stutters while it works).
func _bake_for_sharers(take_path: String) -> void:
	if take_path == "" or last_take == null or last_take.clip_name == "":
		return
	if HoardsmanCues.sharers(last_take.character_id, last_take.clip_name).is_empty():
		return
	var args := ["--headless", "--xr-mode", "off", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/bake_shared.gd", "--", ProjectSettings.globalize_path(take_path)]
	OS.create_process(OS.get_executable_path(), args)
	status_line += "
baking it for: " + ", ".join(HoardsmanCues.sharers(last_take.character_id, last_take.clip_name))


# --- where the hands rest ---------------------------------------------------------

## Two faint spheres on the stage foe where its hands rest: its recorded idle's first
## frame, or the game's own rest pose if the idle isn't recorded yet. Shown while you line
## up an attack, a guard or a reaction, and through the settle beat; gone once you move.
func _show_rest_ghosts() -> void:
	var model := stage_model()
	var cue := current_cue()
	var want: bool = model != null and str(cue.get("kind", "")) in ["attack", "guard", "reaction"] 		and (is_idle() or state == State.COUNTDOWN or (guide != null and guide.phase(recording_time()) == "settle"))
	for i in range(_rest_ghosts.size() - 1, -1, -1):
		if not is_instance_valid(_rest_ghosts[i]):
			_rest_ghosts.remove_at(i)  # (they go with their foe)
	if not want:
		for g in _rest_ghosts:
			g.visible = false
		return
	if _rest_ghosts.is_empty() or _rest_ghosts[0].get_parent() != model.body:
		_make_rest_ghosts(model)
	for g in _rest_ghosts:
		g.visible = true


func _make_rest_ghosts(model: Enemy) -> void:
	for g in _rest_ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_rest_ghosts.clear()
	var idle := model.clip("idle_" + str(model.data.get("idle", "steady")))
	for part in [["RightHand", Enemy.REST_R[0]], ["LeftHand", Enemy.REST_L[0]]]:
		var at: Vector3 = part[1]
		if idle:
			var tr := Enemy._clip_tracks(idle, part[0])
			if tr.x >= 0:
				at = idle.position_track_interpolate(tr.x, 0.0)
		var g := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.14
		g.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(HHStyle.ACCENT, 0.18)
		m.no_depth_test = true
		g.material_override = m
		g.position = at
		g.layers = 2  # (the stage only, not the player's view)
		model.body.add_child(g)
		_rest_ghosts.append(g)


## Where the stage foe's weapon hand is, in the world.
func weapon_hand() -> Vector3:
	var model := stage_model()
	return model.right_hand.global_position if model else Vector3.ZERO


## Where the far end of the stage foe's weapon is, in the world (the player's view traces
## it: it's what the frame in front of you maps).
func weapon_tip() -> Vector3:
	var model := stage_model()
	if model == null:
		return Vector3.ZERO
	return model.right_hand.global_transform * Vector3(0, float(character.get("_haft")), 0)


## A cue that's a foe's attack: its EnemyDefs.ATTACKS entry, or {}.
func cue_attack(cue: Dictionary) -> Dictionary:
	var id: String = cue.get("attack", "")
	return EnemyDefs.ATTACKS.get(id, {}) if id != "" else {}


## The foe on the stage (the rig's model), or null.
func stage_model() -> Enemy:
	return character.get("model") if character else null


# --- the foe's weapon in your hands ----------------------------------------------

## A ghost of what the foe holds in each hand, on your controllers, at the grip the rig
## uses: you feel the reach of a halberd, or that the Duelist's rapier is long and thin.
func _dress_controllers() -> void:
	for w in _weapons:
		w.get_parent().remove_child(w)
		w.queue_free()
	_weapons.clear()
	var model := stage_model()
	if model == null:
		return
	var grip := Basis.from_euler((character.get("grip_offset_deg") as Vector3) * PI / 180.0)
	for pair in [[model.right_hand, right_hand], [model.left_hand, left_hand]]:
		var ghost := Node3D.new()
		ghost.name = "WeaponGhost"
		ghost.basis = grip * Basis(Vector3.UP, PI)  # (the half turn the mirror gives the foe's weapon: see tools/enemy_models.py export())
		for m in _meshes(pair[0]):
			var copy := MeshInstance3D.new()
			copy.mesh = m.mesh
			copy.transform = (pair[0] as Node3D).global_transform.affine_inverse() * m.global_transform
			copy.material_override = _ghost_mat()
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.add_child(copy)
		if pair[0] == model.right_hand:
			ghost.add_child(_tip_marker(float(character.get("_haft"))))
		(pair[1] as Node3D).add_child(ghost)
		_weapons.append(ghost)


## A bright point at the far end of the weapon in your right hand: it's what you swing
## through the frame (what crosses the frame there crosses the player's screen there).
static func _tip_marker(haft: float) -> Node3D:
	var dot := MeshInstance3D.new()
	dot.name = "TipMarker"
	var s := SphereMesh.new()
	s.radius = 0.012
	s.height = 0.024
	s.radial_segments = 12
	s.rings = 6
	dot.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = HHStyle.ACCENT
	m.no_depth_test = true
	m.render_priority = 2
	dot.material_override = m
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.position = Vector3(0, haft, 0)
	var halo := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.026
	hs.height = 0.052
	hs.radial_segments = 12
	hs.rings = 6
	halo.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(HHStyle.ACCENT, 0.25)
	hm.no_depth_test = true
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.add_child(halo)
	return dot


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


static func _ghost_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(HHStyle.ACCENT, 0.22)
	return m
