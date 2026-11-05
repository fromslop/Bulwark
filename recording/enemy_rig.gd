## A Hoardsman foe as a HeadnHands character: its real model (the same Enemy the game
## builds), performed by you. Your hands are its hands, your head its head; what the
## recorder's mirror shows is what the player sees, so it's a faces_player rig.
##
##   your right hand   its weapon hand (Body/RightHand, on the player's right)
##   your left hand    its off hand (Body/LeftHand)
##   your head         its head, turning and leaning (the game layers this over its
##                     gaze at the player's cursor; see Enemy.clip_head)
##
## One rig serves every foe: each character scene sets enemy_id.
## (tools/make_recording_characters.gd writes the scenes.)
extends HHRig

## The EnemyDefs id this character performs.
@export var enemy_id := "Footman"
## Turns the controller's pointing direction into the hand's: a held weapon runs along
## the hand's +Y, a controller points along its -Z. Degrees about each axis.
@export var grip_offset_deg := Vector3(-90, 0, 0)

var model: Enemy
var _head_rest := Vector3.ZERO
var _rest := {}  # rig-space hand rest relative to the head, by side


func _bind() -> void:
	faces_player = true
	model = Enemy.new()
	model.name = "Model"
	model.setup(EnemyDefs.scale_def(HoardsmanCues.def_of(enemy_id).duplicate(true), 0), null)
	model.active = false
	model.set_process(false)
	model.set_physics_process(false)
	model.rotation.y = PI  # it faces the rig's front (-Z), towards the recorder's mirror
	add_child(model)
	if profile == null:
		profile = HHProfile.new()
	profile.display_name = str(model.data.name)
	_head_rest = rig_xform(model.head).origin
	var r := rig_xform(model.right_hand).origin - _head_rest
	var l := rig_xform(model.left_hand).origin - _head_rest
	# (a frame's "left" is the reflection of your right hand: it lands on the weapon hand)
	_rest = {"left": r, "right": l}


func drive(raw: HHFrame, dt: float) -> void:
	var f := mirror_in(raw)
	var p := profile
	var head_q := head_rotation(f)
	var head_pos := follow_vec3("head_pos", dt, _head_rest + head_offset(f) * 0.5, p.head_frequency, p.head_damping, p.head_response)
	_place(model.head, head_pos)
	set_rig_rotation(model.head, follow_quat("head", dt, head_q, p.head_frequency, p.head_damping, p.head_response))
	model.torso.rotation.y = model.head.rotation.y * 0.35  # (the game does the same: the body lags the head)
	var grip := Quaternion.from_euler(grip_offset_deg * PI / 180.0)
	for side in ["left", "right"]:
		var node: Node3D = model.right_hand if side == "left" else model.left_hand
		var target := head_pos + hand_offset(f, side, _rest[side])
		_place(node, follow_vec3(side + "_hand", dt, target, p.hand_frequency, p.hand_damping, p.hand_response))
		set_rig_rotation(node, follow_quat(side + "_rot", dt, hand_rotation(f, side) * grip, p.hand_frequency * 1.5, p.hand_damping, p.hand_response))


func baked_nodes() -> Array[Node3D]:
	return [model.head, model.right_hand, model.left_hand]


## Puts a node at a rig-space point (whatever its parents are doing).
func _place(node: Node3D, rig_pos: Vector3) -> void:
	node.position = rig_xform(node.get_parent()).affine_inverse() * rig_pos
