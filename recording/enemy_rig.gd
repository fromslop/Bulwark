## A Hoardsman foe as a HeadnHands character: its real model (the same Enemy the game
## builds), performed by you. Your hands are its hands, your head its head; what the
## recorder's mirror shows is what the player sees, so it's a faces_player rig.
##
##   your right hand   its weapon hand (Body/RightHand, on the player's right)
##   your left hand    its off hand (Body/LeftHand). Hold the LEFT GRIP and it snaps onto
##                     the weapon: on its line, sliding along the haft with your hand, for
##                     two-handed blows. Let go and it comes away.
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
## Depth squash: reaching towards the player counts for this much (sideways and up/down
## count in full). The game's camera is close, so a blow pushed at it balloons on screen;
## squashed, a full extension reads as a lunge, not a fist over the lens, and a swing
## covers the same part of the screen as its field.
@export_range(0.1, 1.0, 0.05) var depth_squash := 0.45
## However far you reach, the hands stop this far in front of the foe (metres; the
## game's camera is 1.5 m off).
@export var reach_limit := 0.8

var model: Enemy
var _head_rest := Vector3.ZERO
var _rest := {}  # rig-space hand rest relative to the head, by side
var _rest_z := {}  # each hand's rest depth in the foe's own space (+ is towards the player)
var _haft := 0.6  # how far along the weapon (its hand's +Y) the off hand can slide
const SNAP_ON := 0.6  # how hard to squeeze the grip to snap the off hand on
const HEAD_FOLLOW := 0.8  # how much of your head's travel its head takes...
const HEAD_SIDE := 0.18   # ...eased into these limits, metres
const HEAD_DEPTH := 0.15
const HEAD_DOWN := 0.25
const HEAD_UP := 0.08
const HAND_RADIUS := 0.07  # a hand stays this far in front of the chest...
const FRAME_REACH := 0.45  # the player's screen stands this far in front of your face (metres)
const CHEST_EDGE := 0.12   # ...fading out over this much past the chest's outline
var _home := Vector3.INF  # where the performer's head started this take (at eye height)
var _start := Vector3.INF  # ...and where it actually was (standing taller or lower than eye height)
var _chest := AABB()  # the torso's bounds (pauldrons and all), in the torso's own space
var _torso_rest_z := 0.0
var _frame_d := 0.5  # the frame's depth in front of the foe (frame_depth(), worked out once)
var _tip_d := 0.9  # the weapon tip's frame depth (tip_frame_depth(), worked out once)
var debug_tip := []  # [how far your tip is off the frame, the screen factor, the foe's tip, the shift] (the last frame's)
const TIP_REACH := 0.9  # the frame you swing the weapon's tip through stands this far in front of your face (metres)
const TIP_GAP := 0.2  # the tip stops this far short of the game's camera
var _cam := Enemy.GAME_CAM  # the game's camera relative to the foe (further back for a long weapon: Enemy.stand_back)
const TIP_FADE := Vector2(0.04, 0.25)  # behind the frame, the tip's correction fades out over this depth (metres)
const TIP_FADE_FRONT := Vector2(0.15, 0.6)  # ...and in front of it, over this (a thrust through the frame keeps its aim)
## How the hand follows the tip's screen correction. The correction depends on the tip's
## depth, and a fast blow carries the tip through the frame in a frame or two: followed
## outright, the hand would jump (40 cm in one frame at a Knight's overhead). Instead it
## eases after it (TIP_SHIFT_RATE per second: there in about a tenth of a second), never
## faster than TIP_SHIFT_SPEED: exact while you aim or hold, a few frames behind in a swing
## too fast to see it. (Not a spring: this behaves the same live at 90 Hz and baked at 30.)
const TIP_SHIFT_RATE := 12.0
const TIP_SHIFT_SPEED := 2.5  # metres per second
var _tip_shift := Vector3.INF  # the correction as the hand has it now (INF: snap to it)
var _chest_push := {}  # by side: how far out of the chest the hand is being pushed now


func _bind() -> void:
	faces_player = true
	model = Enemy.new()
	model.name = "Model"
	model.setup(EnemyDefs.scale_def(HoardsmanCues.def_of(enemy_id).duplicate(true), 0), null)
	model.active = false
	model.set_process(false)
	model.set_physics_process(false)
	_cam = model.cam_rel()
	reach_limit += model.stand_back  # (a foe standing back for a long weapon has that much more room to reach into)
	model.position = Vector3.ZERO  # (the stage stands where it stands: the room a long weapon needs is in _cam)
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
	_rest_z = {"left": model.right_hand.position.z, "right": model.left_hand.position.z}
	_haft = model.weapon_reach()
	_chest = _bounds_under(model.torso, model.torso)
	_torso_rest_z = model.torso.position.z
	_frame_d = frame_depth()
	_tip_d = tip_frame_depth()


func begin(p_eye_height := 0.0) -> void:
	super.begin(p_eye_height)
	_home = Vector3.INF  # (the next frame is where the performer stands)
	_start = Vector3.INF
	_tip_shift = Vector3.INF
	_chest_push.clear()


## Where YOUR right controller has to be (in the recorder's space: your floor mark's) for
## the foe's weapon hand to be at `m` (a point in the foe's own space): the rig run
## backwards, with your head where it started the take. The studio puts the player's
## screen in front of you through this, so a stab through its middle is a stab through
## the middle of the player's screen.
func performer_hand_for(m: Vector3) -> Vector3:
	return _performer_for(m, true)


## Where the TIP of the ghost weapon on your right controller has to be (in the recorder's
## space) for the foe's weapon tip to be at `m`. The tip maps through the same mirror as
## the hand; the depth squash only moves it nearer or further, and the tip's screen
## correction (drive()) makes its place on the player's screen independent of depth, so
## it isn't undone here. The studio builds the frame you swing through with this.
func performer_tip_for(m: Vector3) -> Vector3:
	return _performer_for(m, false)


func _performer_for(m: Vector3, unsquash: bool) -> Vector3:
	var rest_z: float = _rest_z["left"]
	var z := m.z
	if unsquash and z > rest_z:  # (undo the depth squash)
		var room := maxf(reach_limit - rest_z, 0.01)
		z = rest_z + room * atanh(clampf((z - rest_z) / room, -0.999, 0.999)) / depth_squash
	var rig := model.transform * (model.body.transform * Vector3(m.x, m.y, z))
	var perf_rest := profile.performer_rest_hand
	perf_rest.x = -perf_rest.x  # (a mirrored frame's "left" is your right hand)
	# (standing taller or lower than your eye height moves its head a little: that's in the frame too)
	var travel := _travel(_start - _home) if _start != Vector3.INF else Vector3.ZERO
	var rel := (rig - _head_rest - travel - (_rest["left"] as Vector3)) / profile.reach_scale + perf_rest
	rel.x = -rel.x  # mirrored back to you
	# (_start was taken from a mirrored frame: side to side, you stood on the other side)
	var head := Vector3(-_start.x, _start.y, _start.z) if _start != Vector3.INF else Vector3(0.0, eye_height, 0.0)
	return head + rel


## Screen-space reach: the hand's height and side-to-side are set by where it shows on
## the player's screen, not where it is in the room. The game's camera is close, so a hand
## further out (nearer the lens) moves further across the screen for the same move; here
## it's pulled in (or pushed out) to land on screen where it would at the frame's depth.
## So the frame in front of you holds at any reach, and a swing towards the camera keeps
## its height.
func _on_screen(p: Vector3) -> Vector3:
	var cam := _cam
	var k := (cam.z - p.z) / maxf(cam.z - _frame_d, 0.05)
	return Vector3(p.x * k, cam.y + (p.y - cam.y) * k, p.z)


## How far in front of the foe the player's screen stands for you to swing through: where
## its weapon hand gets to when you reach FRAME_REACH in front of your face (never inside
## its chest).
func frame_depth() -> float:
	var rest_z: float = _rest_z["left"]
	var reach := (FRAME_REACH + profile.performer_rest_hand.z) * profile.reach_scale
	var d := _squash(rest_z + reach, rest_z)
	if _chest.size != Vector3.ZERO:
		d = maxf(d, _chest.end.z + _torso_rest_z + HAND_RADIUS + 0.02)
	return d


## The same, for the weapon's TIP: what leaves the player's screen is the far end of the
## blade, not the fist. The tip's height and side-to-side on screen are set by where it is
## across the frame you swing through: the whole hand shifts so the tip lands on screen
## where it would at tip_frame_depth(). On the camera's side of the frame that pulls it in
## (a lunge doesn't balloon). Behind the frame it would push the hand OUT, further than
## yours moved (a raised blade, a follow-through pulled back), so there it fades out over
## TIP_FADE and the hand goes where yours does.
func _tip_on_screen(hand: Vector3, q: Quaternion, reached: float, dt: float) -> Vector3:
	var tip := hand + q * Vector3(0, _haft, 0)
	# how far YOUR tip is off the frame (the depth squash and the chest move the foe's tip in
	# depth, not yours): what decides how much of the correction applies
	var off := reached + (q * Vector3(0, _haft, 0)).z - _tip_d
	var nearest := _cam.z - TIP_GAP
	if tip.z > nearest:  # (never into the lens)
		hand.z -= tip.z - nearest
		tip.z = nearest
	var cam := _cam
	var k := maxf((cam.z - tip.z) / maxf(cam.z - _tip_d, 0.05), 0.0)
	if off < 0.0:  # (yours is behind the frame: a raised blade, a follow-through)
		k = lerpf(k, 1.0, smoothstep(TIP_FADE.x, TIP_FADE.y, -off))
	else:  # (in front: a long weapon well past the frame isn't hauled in across the screen)
		k = lerpf(k, 1.0, smoothstep(TIP_FADE_FRONT.x, TIP_FADE_FRONT.y, off))
	var want := Vector3(tip.x * k, cam.y + (tip.y - cam.y) * k, tip.z)
	var target := want - tip
	if _tip_shift == Vector3.INF or dt <= 0.0:
		_tip_shift = target
	else:
		var step := (target - _tip_shift) * (1.0 - exp(-TIP_SHIFT_RATE * dt))
		_tip_shift += step.limit_length(TIP_SHIFT_SPEED * dt)
	var shift := _tip_shift
	debug_tip = [off, k, tip, shift]
	return hand + shift


## How far in front of the foe its weapon TIP crosses the player's screen when yours
## crosses the frame: TIP_REACH in front of your face, plus as much again as a long weapon
## makes the foe stand back (Enemy.stand_back), so the frame is where its tip swings.
func tip_frame_depth() -> float:
	var rest_z: float = _rest_z["left"]
	var d := rest_z + (TIP_REACH + model.stand_back + profile.performer_rest_hand.z) * profile.reach_scale
	return clampf(d, rest_z + 0.1, _cam.z - TIP_GAP - 0.15)


## The game camera relative to the foe (Enemy.cam_rel()).
func game_cam() -> Vector3:
	return _cam


## Where a point of the player's screen (0..1 each way) lands in front of this foe, `depth` out.
func screen_point(p: Vector2, depth: float) -> Vector3:
	return Enemy.zone_point(p, depth, _cam)


## How far the head has moved from where you started (not from the floor mark: nobody
## stands exactly on it), eased into limits so a big lean or an overhead swing moves the
## foe's head a little, never out of frame.
func _head_travel(f: HHFrame) -> Vector3:
	if _home == Vector3.INF:
		_home = Vector3(f.head.origin.x, eye_height, f.head.origin.z)
		_start = f.head.origin
	return _travel(f.head.origin - _home)


static func _travel(moved: Vector3) -> Vector3:
	var d := moved * HEAD_FOLLOW
	return Vector3(_ease(d.x, HEAD_SIDE, HEAD_SIDE), _ease(d.y, HEAD_DOWN, HEAD_UP), _ease(d.z, HEAD_DEPTH, HEAD_DEPTH))


static func _ease(v: float, below: float, above: float) -> float:
	var lim := above if v > 0.0 else below
	return lim * tanh(v / lim)


## The chest's push on a hand, eased like the tip's correction: a hand reaching behind the
## body and sliding past the chest's edge would otherwise be thrown 70 cm in a frame.
func _ease_push(side: String, target: float, dt: float) -> float:
	if not _chest_push.has(side) or dt <= 0.0:
		_chest_push[side] = target
	else:
		var now: float = _chest_push[side]
		var step := (target - now) * (1.0 - exp(-TIP_SHIFT_RATE * 1.5 * dt))
		_chest_push[side] = now + clampf(step, -TIP_SHIFT_SPEED * 1.5 * dt, TIP_SHIFT_SPEED * 1.5 * dt)
	return _chest_push[side]


## A hand's depth kept out of the chest: in front of the body (within its outline, with a
## little give at the edges) a hand can't go deeper than the chest's front. The chest moves
## with the head, so its front does too.
func _outside_chest(p: Vector3) -> float:
	if _chest.size == Vector3.ZERO:
		return p.z
	var box := _chest
	box.position += model.torso.position
	var out_x := maxf(box.position.x - p.x, p.x - box.end.x)
	var out_y := maxf(box.position.y - p.y, p.y - box.end.y)
	var w := 1.0 - smoothstep(0.0, CHEST_EDGE, maxf(out_x, out_y))
	var front := box.end.z + HAND_RADIUS
	return lerpf(p.z, maxf(p.z, front), w)


## The bounds of every mesh under `n`, in the space of `space` (walked by hand: the rig
## may be out of the tree).
func _bounds_under(n: Node, space: Node) -> AABB:
	var out := AABB()
	var first := true
	var todo: Array = n.get_children()
	while not todo.is_empty():
		var c: Node = todo.pop_back()
		todo.append_array(c.get_children())
		if c is MeshInstance3D:
			var t := (c as Node3D).transform
			var up := c.get_parent()
			while up != space:
				t = (up as Node3D).transform * t
				up = up.get_parent()
			var box: AABB = t * (c as MeshInstance3D).get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func drive(raw: HHFrame, dt: float) -> void:
	var f := mirror_in(raw)
	var p := profile
	var head_q := head_rotation(f)
	var head_pos := follow_vec3("head_pos", dt, _head_rest + _head_travel(f), p.head_frequency, p.head_damping, p.head_response)
	_place(model.head, head_pos)
	model.follow_head_with_torso()
	model.head.quaternion = _in_model(follow_quat("head", dt, head_q, p.head_frequency, p.head_damping, p.head_response))
	model.torso.rotation = Vector3.ZERO  # the body moves with the head but always squares up to the player
	var grip := Quaternion.from_euler(grip_offset_deg * PI / 180.0)
	for side in ["left", "right"]:
		var node: Node3D = model.right_hand if side == "left" else model.left_hand
		node.quaternion = _in_model(follow_quat(side + "_rot", dt, hand_rotation(f, side) * grip, p.hand_frequency * 1.5, p.hand_damping, p.hand_response))
		var target := head_pos + hand_offset(f, side, _rest[side])
		_place(node, follow_vec3(side + "_hand", dt, target, p.hand_frequency, p.hand_damping, p.hand_response))
		var reached := node.position.z  # (where your hand's reach puts it, before the squash)
		node.position.z = _squash(node.position.z, float(_rest_z[side]))
		node.position.z += _ease_push(side, _outside_chest(node.position) - node.position.z, dt)
		# (the weapon hand is placed by its tip; the off hand by itself)
		node.position = _tip_on_screen(node.position, node.quaternion, reached, dt) if side == "left" else _on_screen(node.position)
	_snap_off_hand(f, dt)
	model.swing_parts(dt)  # (the bell hangs and sways off the pole live, as in the game)


func baked_nodes() -> Array[Node3D]:
	return [model.head, model.right_hand, model.left_hand]


## A turn of yours (you face -Z) as the same turn for the foe, which faces you (+Z in its
## own space, the model being turned round): look straight ahead and so does it, at you.
## (Set straight onto its head and hands: their parent, the body, sits square in the model.)
static func _in_model(q: Quaternion) -> Quaternion:
	var r := Quaternion(Vector3.UP, PI)
	return (r.inverse() * q * r).normalized()


## Two hands on one weapon: while the off hand's grip is held (a mirrored frame's "right"
## is your left hand), the off hand moves onto the weapon's line, where yours is along it
## (between just below the weapon hand and most of the way up the haft), and takes the
## weapon hand's turn. It eases on and off, so it doesn't jump.
func _snap_off_hand(f: HHFrame, dt: float) -> void:
	var held := 1.0 if f.right_grip > SNAP_ON else 0.0
	var w := clampf(follow_float("snap", dt, held, 12.0, 1.0, 0.0), 0.0, 1.0)
	if w < 0.001:
		return
	var main := model.right_hand
	var off := model.left_hand
	var axis := main.basis.y.normalized()
	var along := clampf((off.position - main.position).dot(axis), -0.15, _haft * 0.85)
	off.position = off.position.lerp(main.position + axis * along, w)
	off.quaternion = off.quaternion.slerp(main.quaternion, w)


## A hand's depth with the reach towards the player squashed, and stopped short of the camera.
func _squash(z: float, rest: float) -> float:
	if z <= rest:
		return z
	var out := rest + (z - rest) * depth_squash
	var room := maxf(reach_limit - rest, 0.01)
	return rest + room * tanh((out - rest) / room)  # (eases into the limit)


## Puts a node at a rig-space point (whatever its parents are doing).
func _place(node: Node3D, rig_pos: Vector3) -> void:
	node.position = rig_xform(node.get_parent()).affine_inverse() * rig_pos
