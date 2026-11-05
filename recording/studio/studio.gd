## Hoardsman's recording studio: the HeadnHands recorder with a workspace of windows round
## you, so a whole session happens in the headset.
##
##   front, low     SLATE         what you're performing now, its direction, and the state
##                                (ready / 3-2-1 / recording): read it without looking
##                                away from the mirror
##   left           CUES          the character's clips, grouped, with what's recorded
##   far left       CAST          every foe and how far along its clips are
##   right          PLAYER'S VIEW the game camera's view of you-as-the-foe, with the
##                                attack's field drawn where the game puts it
##   far right      DECK          record, replay, view, play-along, punch-in, last take
##
## On the stage itself: the attack's field floats in front of the character, where the
## blow has to pass, and your controllers carry the foe's weapon (a ghost of it) so you
## feel its length.
##
## Run recording/studio/studio.tscn with --xr-mode on and the headset on Link. At the desk
## (no headset) the mouse works the windows (see HHWorkspace).
extends HHRecorder

const KIND_ORDER := ["idle", "attack", "guard", "reaction", "death"]

var workspace: HHWorkspace
var slate: StudioSlate
var cue_board: StudioCueBoard
var cast: StudioCast
var view: StudioPlayerView
var deck: StudioDeck
var field: StudioField
var right_aim: XRController3D
var _weapons: Array[Node3D] = []
var _sig := ""
var _who := "-"  # the character the windows were last built for
var _defaults := {}


func _ready() -> void:
	super._ready()
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
	_defaults = {
		slate.name: HHWorkspace.arc(0.0, 1.0, -0.62),
		cue_board.name: HHWorkspace.arc(36.0, 1.15, -0.12),
		cast.name: HHWorkspace.arc(72.0, 1.2, -0.1),
		view.name: HHWorkspace.arc(-36.0, 1.15, -0.08),
		deck.name: HHWorkspace.arc(-70.0, 1.2, -0.18),
	}
	for p in [slate, cue_board, cast, view, deck]:
		workspace.add_panel(p, _defaults[p.name])
	field = StudioField.new()
	add_child(field)
	_on_character()


func _process(delta: float) -> void:
	super._process(delta)
	var sig := "%s|%d|%d|%s|%s|%s|%s|%s" % [character_id(), cue_index, state, mirror_view, play_along,
		punch_group(), replay != null, last_take_path]
	if character_id() != _who:
		_on_character()
		sig = "%s|%d" % [sig, cue_index]
	if sig != _sig:
		_sig = sig
		refresh()
	slate.tick()
	field.follow(self)


## Everything that shows the state of things, redrawn.
func refresh() -> void:
	for p in [slate, cue_board, cast, view, deck]:
		p.refresh()
	field.show_cue(self, current_cue())


## The studio keeps the whole list (recorded ones too, to redo), not just what's missing,
## and starts on the first clip still to do.
func _on_character() -> void:
	if character == null:
		cues = []
		cue_index = -1
	else:
		cues = HHCues.all(character_id())
		cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return KIND_ORDER.find(a.kind) < KIND_ORDER.find(b.kind))
		cue_index = cues.find_custom(func(c: Dictionary) -> bool: return not c.recorded)
	_who = character_id()
	_dress_controllers()
	_sig = ""


func _finish_recording() -> void:
	var picked := current_cue()
	super._finish_recording()
	# (the recorder narrows the list to what's missing: keep it whole, and move on from
	# the clip just recorded to the next one still to do)
	if character:
		cues = HHCues.all(character_id())
		cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return KIND_ORDER.find(a.kind) < KIND_ORDER.find(b.kind))
		var at := cues.find_custom(func(c: Dictionary) -> bool: return c.clip == picked.get("clip", ""))
		var next := -1
		for i in cues.size():
			var k := (at + 1 + i) % cues.size()
			if not cues[k].recorded:
				next = k
				break
		cue_index = next if next >= 0 else at
	_sig = ""


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
		ghost.basis = grip
		for m in _meshes(pair[0]):
			var copy := MeshInstance3D.new()
			copy.mesh = m.mesh
			copy.transform = (pair[0] as Node3D).global_transform.affine_inverse() * m.global_transform
			copy.material_override = _ghost_mat()
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.add_child(copy)
		(pair[1] as Node3D).add_child(ghost)
		_weapons.append(ghost)


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
