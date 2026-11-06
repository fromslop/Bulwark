class_name Enemy
extends Node3D
## Placeholder enemy shaped like a HeadnHands rig: a Head and two floating hands
## (LeftHand, RightHand) are the performers; the waist-up torso just follows the head.
## Attacks are procedural hand poses for now. Recorded act_ clips replace them later,
## driving the same three nodes.

signal strike(attack: Dictionary)
signal died
signal armor_fell(screen_pos: Vector2)  # a pauldron broke off; it drops into the play field
signal broke  # the stagger meter filled
signal ignited  # superheated hits set it alight

const REST_R := [Vector3(0.3, 1.2, 0.25), Vector3(0.2, 0, -0.2)]
const REST_L := [Vector3(-0.3, 1.2, 0.25), Vector3(0.2, 0, 0.3)]
# each pose: right hand [position, rotation] at wind-up and at the hit; "l" = left hand joins (two-handed)
const POSES := {
	"high_right": {"wind": [Vector3(0.55, 1.85, 0.05), Vector3(0, 0, -0.6)], "hit": [Vector3(-0.45, 1.6, 0.45), Vector3(0, 0, 1.4)]},
	"high_left": {"wind": [Vector3(-0.5, 1.85, 0.05), Vector3(0, 0, 0.6)], "hit": [Vector3(0.5, 1.6, 0.45), Vector3(0, 0, -1.4)]},
	"low": {"wind": [Vector3(0.55, 1.1, 0.0), Vector3(0, 0, -1.6)], "hit": [Vector3(-0.45, 1.05, 0.45), Vector3(0, 0, 1.6)]},
	"overhead_l": {"wind": [Vector3(-0.2, 2.0, -0.1), Vector3(-0.5, 0, 0)], "hit": [Vector3(-0.25, 1.15, 0.5), Vector3(2.0, 0, 0)], "l": true},
	"overhead_r": {"wind": [Vector3(0.25, 2.0, -0.1), Vector3(-0.5, 0, 0)], "hit": [Vector3(0.25, 1.15, 0.5), Vector3(2.0, 0, 0)], "l": true},
	"thrust": {"wind": [Vector3(0.3, 1.4, -0.15), Vector3(1.57, 0, 0)], "hit": [Vector3(0.0, 1.45, 0.75), Vector3(1.57, 0, 0)]},
	"sweep": {"wind": [Vector3(0.6, 1.6, -0.1), Vector3(0, 0, -1.2)], "hit": [Vector3(-0.6, 1.3, 0.5), Vector3(0, 0, 1.8)], "l": true},
	"slam": {"wind": [Vector3(0.0, 2.05, -0.1), Vector3(-0.3, 0, 0)], "hit": [Vector3(0.0, 1.0, 0.5), Vector3(2.3, 0, 0)], "l": true},
	# the fencer's lunge: blade drawn back level, then the whole arm shoots forward
	"lunge": {"wind": [Vector3(0.55, 1.4, -0.3), Vector3(1.57, 0, 0)], "hit": [Vector3(-0.1, 1.42, 0.85), Vector3(1.57, 0, 0)]},
	"low_left": {"wind": [Vector3(-0.55, 1.05, 0.0), Vector3(0, 0, 1.6)], "hit": [Vector3(0.45, 1.0, 0.45), Vector3(0, 0, -1.6)]},
	# the head rears back, then jerks forward: the spit comes from the mouth, the hands stay low
	"spit": {"wind": [Vector3(0.35, 1.0, 0.1), Vector3(0.3, 0, -0.3)], "hit": [Vector3(0.35, 1.0, 0.1), Vector3(0.3, 0, -0.3)], "head": true},
	# both hands open, reaching out of the screen towards the player's hand
	"grasp": {"wind": [Vector3(0.45, 1.5, -0.2), Vector3(1.2, 0, -0.5)], "hit": [Vector3(0.25, 1.45, 0.9), Vector3(1.57, 0, 0)], "l": true, "mirror": true},
	# the shield arm swings across and shoves
	"bash": {"wind": [Vector3(0.3, 1.3, 0.2), Vector3(0, 0, -0.6)], "hit": [Vector3(-0.4, 1.35, 0.8), Vector3(0, 0, 0.9)], "shield": true},
	# the off hand's own blade: a cut from the left while the right stays ready ("shield": the left hand moves)
	"off_high": {"wind": [Vector3(-0.55, 1.85, 0.05), Vector3(0, 0, 0.7)], "hit": [Vector3(0.45, 1.55, 0.45), Vector3(0, 0, -1.4)], "shield": true},
	"off_low": {"wind": [Vector3(-0.55, 1.1, 0.0), Vector3(0, 0, 1.6)], "hit": [Vector3(0.45, 1.05, 0.45), Vector3(0, 0, -1.6)], "shield": true},
	# on guard: the blade held level across the body, the off hand on it ("wind" and "hit" alike)
	"guard": {"wind": [Vector3(0.2, 1.52, 0.35), Vector3(0, 0.2, 1.62)], "hit": [Vector3(0.2, 1.52, 0.35), Vector3(0, 0.2, 1.62)], "l": true},
	# a pole held in both hands, the head swung round low and wide
	"reap": {"wind": [Vector3(-0.65, 1.2, -0.05), Vector3(0, 0, 1.3)], "hit": [Vector3(0.6, 1.15, 0.45), Vector3(0, 0, -1.3)], "l": true},
}
# hit locations: damage multiplier, how armored it is (wear on your weapon), local radius in metres
const REGIONS := {
	"weak": {"mult": 3.0, "armor": 0.0, "radius": 0.09},
	"exposed": {"mult": 1.6, "armor": 0.2, "radius": 0.11},
	"head": {"mult": 1.3, "armor": 0.6, "radius": 0.19},
	"right_hand": {"mult": 0.8, "armor": 0.5, "radius": 0.12},
	"left_hand": {"mult": 0.8, "armor": 0.5, "radius": 0.12},
	"torso": {"mult": 1.0, "armor": 1.0, "radius": 0.3},
}

var data: Dictionary
var hp := 100.0
var max_hp := 100.0
var speed := 1.0
var state := "idle"  # idle, windup, recover, stagger, guarding, broken, dead
var guard_time := 0.0  # guarding: how much longer it holds the guard
var _guard_total := 1.0
# Recorded clips (HeadnHands, baked to res://animations/<model>/<clip>.res). When a foe has
# a clip for what it's doing, its hands play it instead of the procedural pose; its head
# keeps watching the player's cursor, with the clip's head motion layered on top.
const CLIP_DIR := "res://animations"
const CLIP_STRIKE := 0.7  # where a clip's blow lands, as a fraction of it, when it isn't marked
const CLIP_HEAD := {"idle": 0.5, "other": 0.85}  # how much of the clip's own head motion shows
static var _clip_cache := {}  # path -> Animation (or null: no clip)
var clip_name := ""  # the clip playing now ("" = procedural)
var clip_time := 0.0
var _clip: Animation
var _gaze := Vector3.ZERO  # the head's own aim at the cursor (pitch, yaw, lean), before any clip layer
const CLIP_BLEND := 0.15  # seconds to crossfade the hands from one clip to the next
const CLIP_SNAP := 0.06   # ...or into a stagger, a break or death: near enough a snap
const GAME_CAM := Vector3(0.0, 1.45, 1.5)  # the game's camera, relative to a foe (main.gd sets it)
## A foe with a long weapon stands further back, so its blows have room: this much of its
## reach past a sword's (STAND_BACK_FROM), at most STAND_BACK_MAX. The recording studio's
## swing pane stands the same distance further out (EnemyRig.tip_frame_depth), so the pane
## is the player's screen for every foe alike, wherever its weapon's tip naturally swings.
const STAND_BACK_FROM := 0.9
const STAND_BACK_K := 0.72
const STAND_BACK_MAX := 0.8
var stand_back := 0.0  # how far back this foe stands (metres; see setup)
const GAME_FOV := 40.0
const TORSO_FOLLOW := 0.85  # how much of the head's travel the torso takes (it stays under it)
var _blend_t := 0.0
var _blend_len := CLIP_BLEND
var _blend_from: Array = []  # the hands as they were when the clip changed (a procedural pose fades from this)
var _from_clip: Animation  # ...or the clip they were playing, which plays on under the crossfade
var _from_time := 0.0
## A one-shot clip (a blow's follow-through, a stagger's recovery) plays out into the idle
## rather than being cut where the game's own timer ends: it runs on until this long before
## its end, then crossfades into the idle over that time.
const CLIP_SETTLE := 0.4
## A hit that doesn't stagger plays the foe's flinch on top of whatever it's doing: the
## recoil in the flinch clip (from its first frame) added to the hands and head, this much
## of it (less in a wind-up, so the blow still reads).
const FLINCH_GAIN := 1.0
const FLINCH_GAIN_WINDUP := 0.5
var _flinch_t := -1.0  # how far into the flinch layer (-1: none)
var _flinch_old_t := -1.0  # a flinch a new hit cut into, fading out under it
var _flinch_old_w := 0.0
const FLINCH_HANDOVER := 0.2  # seconds for a cut-into flinch to fade
var _flinch_gain := FLINCH_GAIN  # eased between FLINCH_GAIN and FLINCH_GAIN_WINDUP as it starts and ends a wind-up
var _combo_next := ""  # the second blow of the combo clip playing
var _combo_t0 := -1.0
var _aim_last := Vector3.ZERO
var _aim_hands := Vector2(1, 0)
var _head_rest := Vector3(0, 1.68, 0)   # where the head and torso sit at rest (after dressing:
var _torso_rest := Vector3(0, 1.22, 0)  # a modelled foe may set its own)
var _guarded_last := false  # (never two guards in a row: it has to swing in between)
var _guard_knocked := false  # a wind-up guard knocked aside (Guardbreaker): open until it strikes
var active := true
var current: Dictionary = {}
var progress := 0.0
var slow_time := 0.0
var look_target := Vector2(0.5, 0.5)  # normalized screen point the head watches
var camera: Camera3D
var body: Node3D
var torso: Node3D
var head: Node3D
var left_hand: Node3D
var right_hand: Node3D
var weak_spot: MeshInstance3D
var off_balance := 0.0  # after a clean block: hits do more for a moment
var _exposed: Array[MeshInstance3D] = []  # raw patches where armour was stripped
# Stagger: fills from damage the player prevents (parries count double) and deals. It isn't
# shown as a number: the enemy wobbles more as it fills. Full = broken: it slumps, the weak
# spot opens and hits do double damage for a few seconds.
var stagger_meter := 0.0
var broken_time := 0.0
var _since_stagger := 0.0
const BROKEN_TIME := 2.5
# Superheated weapons build heat on the enemy (it glows); full heat sets it on fire.
const BURN_TIME := 5.0
const BURN_DPS := 4.0
var heat := 0.0
var burning_time := 0.0
var _burn_tick := 0.0
# Corrosive weapons eat armour: corrosion strips pauldrons on its own scale (CORRODE_BREAKS).
var corrosion := 0.0
const ARMOR_BREAKS := [0.6, 0.9]  # HP lost at which a pauldron is beaten off
const CORRODE_BREAKS := [0.25, 0.5]  # corrosion at which one rusts through
# Poisoned weapons: damage over time, refreshed by each poisoned hit.
const POISON_DPS := 2.5
var poison_time := 0.0
var _poison_tick := 0.0
const STAGGER_DECAY := 4.0  # per second, once the pressure lets up for a moment
var rng := RandomNumberGenerator.new()
var _timer := 1.5
var _windup_total := 1.0
var _last_attack := ""
var _tween: Tween
var _mats: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _pauldrons: Array[MeshInstance3D] = []
var _flash := 0.0
# Character: what it does next besides picking at random. A queued attack is a follow-up
# (a combo's second half, a riposte after you block clean) that goes before anything else.
var _feint_at := -1.0  # this wind-up is a feint: at this progress it breaks off into another attack
var _queued := ""
var _queued_windup := -1.0
var clean_blocks := 0  # in a row: the Castellan loses patience with a tidy defence
var shield_arm: Node3D  # the Castellan's off-hand shield, when it carries one
var gummed := 0.0  # a sticky block gums the blade: the next wind-up is slower


func setup(d: Dictionary, cam: Camera3D) -> void:
	data = d
	camera = cam
	max_hp = d.hp
	hp = max_hp
	speed = d.speed
	rng.randomize()
	_build(d.color)
	stand_back = clampf((weapon_reach() - STAND_BACK_FROM) * STAND_BACK_K, 0.0, STAND_BACK_MAX)
	position.z = -stand_back


## The game's camera relative to this foe's body (GAME_CAM, plus the room its weapon needs).
func cam_rel() -> Vector3:
	return GAME_CAM + Vector3(0, 0, stand_back)


## How far what the weapon hand holds reaches along the hand's +Y (its bounds' far end).
func weapon_reach() -> float:
	var reach := 0.3
	var todo: Array = right_hand.get_children()
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		if n is MeshInstance3D:
			# (its transform up to the hand, walked by hand: the foe may be out of the tree)
			var t := (n as Node3D).transform
			var p := n.get_parent()
			while p != right_hand:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			reach = maxf(reach, (t * (n as MeshInstance3D).get_aabb()).end.y)
	return reach


## Speed right now: an enraged Brute swings faster the more it bleeds.
func cur_speed() -> float:
	var s := speed
	if data.has("enrage") and hp / max_hp < float(data.enrage.below):
		s *= float(data.enrage.speed)
	return s


func is_enraged() -> bool:
	return data.has("enrage") and hp / max_hp < float(data.enrage.below)


## The off-hand shield is up: the torso is covered until the enemy is reeling or broken.
func guard_up() -> bool:
	return data.get("guard", false) and state in ["idle", "windup", "recover", "guarding"] and off_balance <= 0.0


## On guard: weapons and fists glance off it (see main's _check_weapon_hit).
## A foe that always guards (the Castellan) is on guard whenever it's standing ready: it
## only drops the guard to swing, or when it's knocked off balance, staggered or broken.
## A knight guards with its blade on the wind-up ("windup_guard"): from the moment it starts
## to wind up until the blow comes down it's on guard; it strikes open, and between attacks
## it's open too.
func is_guarding() -> bool:
	if data.get("windup_guard", false):
		return state == "windup" and off_balance <= 0.0 and not _guard_knocked
	if data.get("always_guard", false):
		return state == "idle" and off_balance <= 0.0
	return state == "guarding"


## Between attacks, a foe with a guard stance sometimes stands on guard instead: blade
## level across the body, for a second or two. Then it attacks.
func _begin_guard() -> void:
	var g: Dictionary = data.guard_stance
	state = "guarding"
	guard_time = rng.randf_range(float(g.time[0]), float(g.time[1]))
	_guard_total = guard_time
	_guarded_last = true
	var pose: Dictionary = POSES.guard
	if shield_arm:
		_move({"rest": REST_R}, "rest", 0.25, Tween.EASE_OUT)  # the shield does the guarding (see _update_posture)
	else:
		_move(pose, "wind", 0.25, Tween.EASE_OUT)
	Sfx.play("clack", -6.0, 0.8)


## The guard comes down (its time is up, or a Guardbreaker knocked it aside).
func drop_guard(after: float = 0.3) -> void:
	if state == "windup" and data.get("windup_guard", false):
		_guard_knocked = true  # (the swing carries on, open)
		return
	if state != "guarding":
		return
	state = "idle"
	_timer = after
	_settle()


## The skeleton every design shares: the performers (Head, LeftHand, RightHand) plus a
## Torso that follows the head. Meshes are hung on it by _dress(), one design at a time.
func _build(_col: Color) -> void:
	body = Node3D.new()
	body.name = "Body"  # (recorded clips address Body/Head, Body/RightHand, Body/LeftHand)
	add_child(body)
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 1.22, 0)
	body.add_child(torso)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.68, 0)
	body.add_child(head)
	right_hand = Node3D.new()
	right_hand.name = "RightHand"
	body.add_child(right_hand)
	left_hand = Node3D.new()
	left_hand.name = "LeftHand"
	body.add_child(left_hand)
	_place(right_hand, REST_R)
	_place(left_hand, REST_L)
	_dress()
	_head_rest = head.position
	_torso_rest = torso.position


## Swap to the design currently picked with F8, keeping any armour already knocked off.
func rebuild_look() -> void:
	var lost := 0
	for pd in _pauldrons:
		if not pd.visible:
			lost += 1
	for n in [torso, head, right_hand, left_hand]:
		for c in n.get_children():
			n.remove_child(c)  # out of the way now, so the new parts can take the old names
			c.queue_free()
	_mats.clear()
	_base_colors.clear()
	_pauldrons.clear()
	_dress()
	_exposed.clear()
	for k in mini(lost, _pauldrons.size()):
		_pauldrons[k].visible = false
		_expose(_pauldrons[k])
	_update_wounds()


func _dress() -> void:
	var col: Color = data.color
	shield_arm = null
	model_loaded = false
	_dress_character(col)  # its model, or its primitive build where there's none
	if data.get("boss", false) and not model_loaded:  # a modelled boss has its crown built in
		_crown()
	weak_spot = _box(torso, Vector3(0.09, 0.09, 0.02), Vector3(0, 0, 0.17), Color(1.0, 0.8, 0.2))
	weak_spot.visible = state == "broken"
	if data.get("ink", false):
		_ink(self)


## The Errata: every surface in wet black ink, with a sheen. The weak spot stays gold.
func _ink(n: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.05)
	mat.roughness = 0.15
	mat.metallic = 0.4
	mat.rim_enabled = true
	mat.rim = 0.6
	for c in n.get_children():
		if c is MeshInstance3D and c != weak_spot:
			(c as MeshInstance3D).material_override = mat
		_ink(c)


# --- modelled bodies ------------------------------------------------------------------
# tools/enemy_models.py (Blender) writes one glTF per character to assets/enemies/<slug>.glb,
# split into objects named for the rig: Torso, Head, RightHand, LeftHand, PauldronL,
# PauldronR, Weapon (right hand) and Shield (left hand). Any other object called
# <Part>_<thing> hangs on that part. The files are read at runtime with GLTFDocument, so no
# editor import step is needed and the tests see them headless.

const MODEL_DIR := "res://assets/enemies/"
const MODEL_SLOTS := {"Torso": "torso", "Head": "head", "RightHand": "right_hand", "LeftHand": "left_hand",
	"PauldronL": "torso", "PauldronR": "torso", "Weapon": "right_hand", "Shield": "left_hand"}
static var _model_cache := {}  # path -> the parsed scene (a Node kept out of the tree), or null if the file is missing
var model_loaded := false  # this rig wears a modelled body rather than primitives


## Where a character's model lives: its display name, lower case, spaces to underscores.
static func model_path(d: Dictionary) -> String:
	if d.has("model"):
		return "res://assets/enemies/%s.glb" % str(d.model)
	return MODEL_DIR + str(d.get("name", "")).to_lower().replace(" ", "_") + ".glb"


static func _parse_model(path: String) -> Node:
	if not FileAccess.file_exists(path):
		# an exported game has no raw .glb, only Godot's imported copy of it: load that (without
		# this every foe in a release fell back to its primitive build)
		if ResourceLoader.exists(path):
			var ps := load(path) as PackedScene
			if ps:
				return ps.instantiate()
		return null
	# (running from source: read the file itself, as the model tool last wrote it)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_warning("Hoardsman: couldn't read enemy model %s (%s)" % [path, error_string(err)])
		return null
	return doc.generate_scene(state)


## Hang the character's modelled parts on the rig. False if there's no file (or it has no
## usable parts), in which case the procedural builder dresses it instead.
func _load_model() -> bool:
	var path := model_path(data)
	if not _model_cache.has(path):
		_model_cache[path] = _parse_model(path)
	var proto: Node = _model_cache[path]
	if proto == null:
		return false
	var root: Node = proto.duplicate()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var slots := {"torso": torso, "head": head, "right_hand": right_hand, "left_hand": left_hand}
	var found := {}
	for mi in meshes:
		var mname := String(mi.name)  # read before reparenting: a clash with a part still being freed renames it
		var key := mname.get_slice("_", 0)  # Head_Hat hangs on the Head
		if not MODEL_SLOTS.has(key):
			continue
		var xf := mi.transform
		mi.get_parent().remove_child(mi)
		slots[MODEL_SLOTS[key]].add_child(mi)
		mi.transform = xf
		_adopt_materials(mi)
		found[mname] = mi
	root.free()
	if not (found.has("PauldronL") and found.has("PauldronR") and found.has("Torso") and found.has("Head")):
		push_warning("Hoardsman: enemy model %s is missing rig parts (%s)" % [path, found.keys()])
		for mi in found.values():
			mi.free()
		_mats.clear()
		_base_colors.clear()
		return false
	_pauldrons.append(found.PauldronL)
	_pauldrons.append(found.PauldronR)
	if found.has("Shield"):
		shield_arm = found.Shield
	_swingers.clear()
	for mname in found:
		if String(mname).ends_with("_Bell"):  # (it hangs from its origin: see swing_parts)
			_swingers.append({"node": found[mname], "rest": (found[mname] as Node3D).position, "fresh": true})
	model_loaded = true
	return true


## Parts that hang free (a bell on a pole): each swings from where it's hung like a
## pendulum, under gravity, off however its holder moves. Live, never baked: whatever the
## clip or the game does with the hand, the bell follows through on its own.
const SWING_LENGTH := 0.24  # pivot to the bell's weight, metres
const SWING_DAMP := 1.4  # how fast a swing dies away (per second)
var _swingers: Array = []


func swing_parts(dt: float) -> void:
	if _swingers.is_empty() or dt <= 0.0 or not is_inside_tree():
		return
	for s in _swingers:
		var n: Node3D = s.node
		if not is_instance_valid(n):
			continue
		var parent := n.get_parent() as Node3D
		var pg := parent.global_transform
		var k := pg.basis.get_scale().x
		var pivot: Vector3 = pg * (s.rest as Vector3)
		var length := SWING_LENGTH * k
		if s.fresh or (s.bob as Vector3).distance_to(pivot) > length * 3.0:  # (first, or the foe jumped)
			s.bob = pivot + Vector3.DOWN * length
			s.prev = s.bob
			s.fresh = false
		var bob: Vector3 = s.bob
		var moved := (bob - (s.prev as Vector3)) * exp(-SWING_DAMP * dt)
		var next := bob + moved + Vector3(0, -9.8, 0) * dt * dt
		var arm := next - pivot
		next = pivot + (arm.normalized() if arm.length() > 0.0001 else Vector3.DOWN) * length
		s.prev = bob
		s.bob = next
		# turned so it hangs from the pivot towards its weight, keeping its face to the holder's
		var y := (pivot - next).normalized()
		var z := pg.basis.x.normalized().cross(y)
		if z.length() < 0.01:
			z = pg.basis.z.normalized()
		z = z.normalized()
		var x := y.cross(z)
		n.global_transform = Transform3D(Basis(x * k, y * k, z * k), pivot)


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect_meshes(c, out)


## Give the part its own copies of the file's materials, so wounds darken this rig alone:
## tint_* takes the character's colour, glow_* lights itself and is left out of the wounds.
## The outline every modelled foe wears: the mesh drawn again a little fatter, back faces
## only, in near-black (an inverted hull). Shared by every surface.
static var _outline: StandardMaterial3D
const OUTLINE_WIDTH := 0.014  # metres


static func _outline_mat() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color(0.02, 0.015, 0.01)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = OUTLINE_WIDTH
	return _outline


func _adopt_materials(mi: MeshInstance3D) -> void:
	var col: Color = data.color
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m: StandardMaterial3D = src.duplicate()
		var mname := src.resource_name
		m.roughness = 1.0
		m.metallic = 0.0
		m.next_pass = _outline_mat()  # a dark outline: the figure reads against the room without lighting it up
		m.emission_enabled = true
		if mname.begins_with("glow"):
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 3.0
		else:
			if mname.begins_with("tint"):
				m.albedo_color = col.lerp(m.albedo_color, 0.5)
			m.emission = Color(1, 0.9, 0.8)
			m.emission_energy_multiplier = 0.0
			_mats.append(m)
			_base_colors.append(m.albedo_color)
		mi.set_surface_override_material(i, m)


## A boss wears a crown, whatever it is.
func _crown() -> void:
	var gold := Color(0.95, 0.75, 0.2)
	_mesh(head, _cyl(0.14, 0.13, 0.06, 8), Vector3(0, 0.2, 0), gold)
	for k in 5:
		var spike := _mesh(head, PrismMesh.new(), Vector3(sin(k * TAU / 5.0) * 0.12, 0.27, cos(k * TAU / 5.0) * 0.12), gold)
		spike.scale = Vector3(0.03, 0.08, 0.03)


## The weapon in its hand, by the enemy's character rather than by the design. `blade`
## and `guard` are the design's own palette; `glow` draws the blade as something lit.
func _weapon(blade: Color, guard: Color, glow: bool = false) -> void:
	var draw_blade := func(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
		return _glow(parent, size, pos, c) if glow else _box(parent, size, pos, c)
	match data.get("weapon", "sword"):
		"maul":
			_box(right_hand, Vector3(0.07, 0.9, 0.07), Vector3(0, 0.45, 0), Color(0.35, 0.25, 0.15))
			_box(right_hand, Vector3(0.3, 0.24, 0.24), Vector3(0, 0.92, 0), Color(0.3, 0.3, 0.32))
			_box(right_hand, Vector3(0.33, 0.04, 0.27), Vector3(0, 0.82, 0), Color(0.2, 0.2, 0.22))
		"rapier":
			draw_blade.call(right_hand, Vector3(0.025, 1.0, 0.012), Vector3(0, 0.6, 0), blade.lightened(0.1))
			_mesh(right_hand, _sphere(0.07, 6), Vector3(0, 0.09, 0), guard)  # cup guard
			_box(right_hand, Vector3(0.02, 0.1, 0.02), Vector3(0, -0.1, 0), guard.darkened(0.3))
		"rusted":
			var rust := Color(0.45, 0.25, 0.12)
			_box(right_hand, Vector3(0.05, 0.75, 0.02), Vector3(0, 0.47, 0), rust)
			_box(right_hand, Vector3(0.06, 0.2, 0.025), Vector3(0.02, 0.55, 0), rust.darkened(0.3))  # pitted, jagged
			_box(right_hand, Vector3(0.04, 0.12, 0.025), Vector3(-0.025, 0.3, 0), rust.lightened(0.15))
			_box(right_hand, Vector3(0.22, 0.035, 0.05), Vector3(0, 0.09, 0), rust.darkened(0.4))
		"flail":
			_box(right_hand, Vector3(0.05, 0.5, 0.05), Vector3(0, 0.3, 0), Color(0.3, 0.22, 0.12))
			for k in 4:
				_box(right_hand, Vector3(0.02, 0.06, 0.02), Vector3(0, 0.6 + k * 0.07, 0), Color(0.25, 0.25, 0.27))  # chain
			_glow(right_hand, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.95, 0), Color(1.0, 0.45, 0.1))  # the brazier, full of coals
			_box(right_hand, Vector3(0.2, 0.03, 0.2), Vector3(0, 0.86, 0), Color(0.2, 0.2, 0.2))
		"none":
			for hand in [right_hand, left_hand]:
				for k in 4:
					_glow(hand, Vector3(0.015, 0.14, 0.015), Vector3(-0.045 + k * 0.03, -0.14, 0.03), Color(0.5, 0.7, 1.0))  # long cold fingers
		"axe":
			_box(right_hand, Vector3(0.06, 1.1, 0.06), Vector3(0, 0.5, 0), Color(0.3, 0.2, 0.12))
			var head_mi := _box(right_hand, Vector3(0.34, 0.3, 0.03), Vector3(0.12, 0.95, 0), blade)
			_box(head_mi, Vector3(0.36, 0.04, 0.035), Vector3(0, -0.15, 0), blade.lightened(0.3))  # the edge
			_box(right_hand, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.95, 0), guard)
		"staff":
			_box(right_hand, Vector3(0.04, 1.2, 0.04), Vector3(0, 0.55, 0), Color(0.25, 0.2, 0.15))
			_box(right_hand, Vector3(0.14, 0.18, 0.14), Vector3(0, 1.15, 0), Color(0.2, 0.2, 0.22))  # the lantern's cage
			_glow(right_hand, Vector3(0.1, 0.14, 0.1), Vector3(0, 1.15, 0), blade)  # and its light
			_mesh(right_hand, _cyl(0.0, 0.08, 0.06, 6), Vector3(0, 1.27, 0), Color(0.2, 0.2, 0.22))
		"halberd":
			_box(right_hand, Vector3(0.045, 1.8, 0.045), Vector3(0, 0.55, 0), Color(0.32, 0.22, 0.12))  # the pole, both hands on it
			draw_blade.call(right_hand, Vector3(0.24, 0.2, 0.025), Vector3(0.12, 1.32, 0), blade)  # the axe blade
			_box(right_hand, Vector3(0.12, 0.08, 0.025), Vector3(-0.1, 1.36, 0), blade.darkened(0.2))  # the hook behind it
			draw_blade.call(right_hand, Vector3(0.035, 0.3, 0.02), Vector3(0, 1.58, 0), blade.lightened(0.1))  # the spike
		"twin":
			for hand in [right_hand, left_hand]:
				draw_blade.call(hand, Vector3(0.045, 0.75, 0.015), Vector3(0, 0.48, 0), blade)  # a sabre in each hand
				_box(hand, Vector3(0.16, 0.03, 0.05), Vector3(0, 0.09, 0), guard)
		"bell":
			_box(right_hand, Vector3(0.05, 1.0, 0.05), Vector3(0, 0.45, 0), Color(0.3, 0.22, 0.14))  # the bell's pole
			_mesh(right_hand, _cyl(0.1, 0.22, 0.32, 10), Vector3(0, 0.95, 0), Color(0.35, 0.55, 0.45))  # the bell, verdigris bronze
			_box(left_hand, Vector3(0.04, 0.85, 0.04), Vector3(0, 0.35, 0), Color(0.32, 0.24, 0.14))  # the spade's haft
			_box(left_hand, Vector3(0.2, 0.24, 0.02), Vector3(0, 0.85, 0), Color(0.4, 0.4, 0.42))  # and its blade
		"mace":
			_box(right_hand, Vector3(0.05, 0.65, 0.05), Vector3(0, 0.33, 0), Color(0.3, 0.22, 0.14))
			_mesh(right_hand, _sphere(0.11, 8), Vector3(0, 0.7, 0), blade.darkened(0.2))
			for k in 6:
				var flange := _box(right_hand, Vector3(0.03, 0.2, 0.09), Vector3(0, 0.7, 0), blade)
				flange.rotation = Vector3(0, k * PI / 6.0, 0)
		"shield":
			draw_blade.call(right_hand, Vector3(0.05, 0.85, 0.02), Vector3(0, 0.52, 0), blade)
			_box(right_hand, Vector3(0.22, 0.035, 0.05), Vector3(0, 0.09, 0), guard)
			shield_arm = _box(left_hand, Vector3(0.5, 0.75, 0.04), Vector3(0.05, 0.2, 0.08), guard.lightened(0.1))
			_box(left_hand, Vector3(0.1, 0.12, 0.03), Vector3(0.05, 0.3, 0.11), Color(0.95, 0.75, 0.2))  # a boss on its face
		_:
			draw_blade.call(right_hand, Vector3(0.05, 0.85, 0.02), Vector3(0, 0.52, 0), blade)
			_box(right_hand, Vector3(0.22, 0.035, 0.05), Vector3(0, 0.09, 0), guard)


## Character: each enemy gets its own model, built to say who it is at a glance. The
## footman is quilted cloth under a kettle hat; the brute is bare arms and a fur mantle;
## the duelist a slim coat and a feathered hat; and so on. Pauldrons (two per model) are
## whatever that character wears on its shoulders. The modelled body in assets/enemies is
## used when it exists; these primitive builders are the fallback.
func _dress_character(col: Color) -> void:
	if _load_model():
		return
	match data.get("name", ""):
		"Knight", "Vault Warden":
			_dress_great_helm(col)
		"Wraith":
			_dress_wraith(col)
		"Footman":
			_dress_footman(col)
		"Brute":
			_dress_brute(col)
		"Duelist":
			_dress_duelist(col)
		"The Rusted":
			_dress_rusted(col)
		"Pyre Zealot":
			_dress_zealot(col)
		"Castellan":
			_dress_castellan(col)
		"Headsman":
			_dress_headsman(col)
		"Lamplighter":
			_dress_lamplighter(col)
		_:
			_dress_great_helm(col)


## A quilted gambeson, a kettle hat, a scruffy face, leather gloves and leather shoulder pads.
func _dress_footman(col: Color) -> void:
	var cloth := col.lerp(Color(0.6, 0.5, 0.35), 0.5)
	var leather := Color(0.35, 0.22, 0.12)
	var skin := Color(0.8, 0.62, 0.5)
	_mesh(torso, _cyl(0.26, 0.3, 0.5, 7), Vector3.ZERO, cloth)
	for k in 5:
		_mesh(torso, _cyl(0.272, 0.292, 0.012, 7), Vector3(0, -0.2 + k * 0.1, 0), cloth.darkened(0.3))  # quilting
	_box(torso, Vector3(0.5, 0.08, 0.3), Vector3(0, -0.28, 0), leather)  # belt
	_box(torso, Vector3(0.08, 0.06, 0.02), Vector3(0, -0.28, 0.16), Color(0.6, 0.55, 0.4))  # buckle
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.2, 0.08, 0.3), Vector3(0.3 * side, 0.22, 0), leather.lightened(0.1))
		pd.rotation.z = -0.25 * side
		_pauldrons.append(pd)
	_box(head, Vector3(0.24, 0.3, 0.24), Vector3(0, -0.02, 0), skin)
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(-0.06, 0.03, 0.125), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(0.06, 0.03, 0.125), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.14, 0.05, 0.03), Vector3(0, -0.09, 0.12), Color(0.3, 0.2, 0.12))  # a beard
	_mesh(head, _cyl(0.06, 0.16, 0.14, 8), Vector3(0, 0.18, 0), Color(0.4, 0.4, 0.42))  # kettle hat
	_mesh(head, _cyl(0.24, 0.24, 0.025, 8), Vector3(0, 0.12, 0), Color(0.35, 0.35, 0.37))  # its brim
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.1, 0.12, 0.1), Vector3.ZERO, leather)
		_box(hand, Vector3(0.11, 0.04, 0.07), Vector3(0, -0.06, 0.04), leather.darkened(0.2))
	_weapon(Color(0.6, 0.6, 0.62), Color(0.3, 0.25, 0.18))


## Huge: a wide bare chest, a fur mantle, an iron collar, spiked iron shoulder plates, a
## bald head with a heavy jaw, and fists like hams.
func _dress_brute(col: Color) -> void:
	var skin := col.lerp(Color(0.75, 0.55, 0.42), 0.5)
	var fur := Color(0.25, 0.18, 0.12)
	var iron := Color(0.3, 0.3, 0.33)
	_box(torso, Vector3(0.8, 0.6, 0.4), Vector3(0, -0.02, 0), skin)
	_box(torso, Vector3(0.3, 0.3, 0.02), Vector3(0, 0.05, 0.21), skin.darkened(0.15))  # pecs line
	_box(torso, Vector3(0.9, 0.18, 0.5), Vector3(0, 0.3, -0.02), fur)  # mantle
	_mesh(torso, _cyl(0.17, 0.19, 0.08, 8), Vector3(0, 0.36, 0), iron)  # collar
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.26, 0.1, 0.36), Vector3(0.42 * side, 0.3, 0), iron)
		_pauldrons.append(pd)
		for k in 2:
			var spike := _mesh(pd, PrismMesh.new(), Vector3(0.0, 0.1, -0.1 + k * 0.2), iron.lightened(0.2))
			spike.scale = Vector3(0.06, 0.12, 0.06)
	_box(torso, Vector3(0.7, 0.14, 0.4), Vector3(0, -0.34, 0), Color(0.3, 0.2, 0.1))  # belt
	_mesh(head, _sphere(0.19, 8), Vector3(0, 0.02, 0), skin)
	_box(head, Vector3(0.26, 0.14, 0.22), Vector3(0, -0.1, 0.03), skin.darkened(0.1))  # jaw
	_box(head, Vector3(0.05, 0.025, 0.02), Vector3(-0.07, 0.04, 0.17), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.05, 0.025, 0.02), Vector3(0.07, 0.04, 0.17), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.2, 0.03, 0.02), Vector3(0, 0.09, 0.17), Color(0.2, 0.12, 0.08))  # brow
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.17, 0.18, 0.16), Vector3.ZERO, skin)
		_box(hand, Vector3(0.18, 0.06, 0.1), Vector3(0, -0.08, 0.05), skin.darkened(0.2))
		_box(hand, Vector3(0.19, 0.06, 0.19), Vector3(0, 0.1, 0), Color(0.3, 0.2, 0.1))  # wrist wrap
	_weapon(Color(0.3, 0.3, 0.32), Color(0.35, 0.25, 0.15))


## A fencer: a slim coat, puffed sleeves at the shoulder, a wide-brimmed hat with a feather,
## a thin mask, fine gloves.
func _dress_duelist(col: Color) -> void:
	var coat := col.lerp(Color(0.45, 0.15, 0.3), 0.5)
	var cream := Color(0.85, 0.8, 0.7)
	_mesh(torso, _cyl(0.17, 0.2, 0.54, 8), Vector3.ZERO, coat)
	_box(torso, Vector3(0.04, 0.5, 0.02), Vector3(0, 0, 0.19), cream)  # buttons
	for k in 4:
		_mesh(torso, _sphere(0.015, 4), Vector3(0, -0.18 + k * 0.12, 0.2), Color(0.9, 0.8, 0.3))
	for side in [-1.0, 1.0]:
		var pd := _mesh(torso, _sphere(0.11, 6), Vector3(0.24 * side, 0.2, 0), coat.lightened(0.15))  # puffed sleeve
		_pauldrons.append(pd)
	_box(torso, Vector3(0.36, 0.06, 0.22), Vector3(0, -0.26, 0), Color(0.2, 0.12, 0.08))  # sash
	_box(head, Vector3(0.2, 0.26, 0.2), Vector3(0, -0.02, 0), Color(0.82, 0.66, 0.54))
	_box(head, Vector3(0.22, 0.07, 0.03), Vector3(0, 0.03, 0.1), Color(0.05, 0.05, 0.05))  # mask
	_box(head, Vector3(0.08, 0.02, 0.02), Vector3(0, -0.08, 0.11), Color(0.3, 0.15, 0.1))  # a thin moustache
	_mesh(head, _cyl(0.3, 0.3, 0.02, 10), Vector3(0, 0.13, 0), coat.darkened(0.3))  # hat brim
	_mesh(head, _cyl(0.12, 0.13, 0.14, 8), Vector3(0, 0.2, 0), coat.darkened(0.3))
	var feather := _mesh(head, PrismMesh.new(), Vector3(0.14, 0.26, -0.05), Color(0.9, 0.85, 0.7))
	feather.scale = Vector3(0.02, 0.22, 0.08)
	feather.rotation.z = -0.6
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.08, 0.1, 0.08), Vector3.ZERO, cream)
		_box(hand, Vector3(0.09, 0.05, 0.1), Vector3(0, 0.07, 0), coat)  # cuff
	_weapon(Color(0.85, 0.87, 0.92), Color(0.75, 0.6, 0.25))


## Plate that has rotted on the body: a helm sitting crooked, a breastplate holed through,
## green-brown rust on everything, pauldrons hanging by a strap.
func _dress_rusted(_col: Color) -> void:
	var rust := Color(0.42, 0.26, 0.14)
	var rot := Color(0.3, 0.33, 0.18)
	_mesh(torso, _cyl(0.24, 0.3, 0.5, 6), Vector3.ZERO, rust)
	for k in 3:
		_box(torso, Vector3(0.08 + k * 0.02, 0.06, 0.06), Vector3(-0.1 + k * 0.1, -0.12 + k * 0.09, 0.26), Color(0.03, 0.02, 0.02))  # holes
	_box(torso, Vector3(0.3, 0.1, 0.02), Vector3(0.05, 0.1, 0.29), rot)  # a stain
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.22, 0.08, 0.3), Vector3(0.32 * side, 0.2 - (0.05 if side > 0 else 0.0), 0), rust.darkened(0.15))
		pd.rotation.z = -0.4 * side
		pd.rotation.x = 0.3 * side
		_pauldrons.append(pd)
	_mesh(head, _cyl(0.16, 0.16, 0.34, 7), Vector3(0.02, 0, 0), rust.lightened(0.1))
	head.get_child(head.get_child_count() - 1).rotation.z = 0.2  # crooked
	_box(head, Vector3(0.22, 0.03, 0.02), Vector3(0.02, 0.03, 0.16), Color(0.01, 0.01, 0.01))
	_glow(head, Vector3(0.04, 0.02, 0.01), Vector3(-0.04, 0.03, 0.165), Color(0.5, 1.0, 0.3))  # something glows in the slit
	_box(head, Vector3(0.12, 0.06, 0.05), Vector3(-0.08, -0.12, 0.1), rot)
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.11, 0.12, 0.11), Vector3.ZERO, rust.darkened(0.1))
		_box(hand, Vector3(0.05, 0.05, 0.05), Vector3(0.03, -0.02, 0.06), Color(0.03, 0.02, 0.02))
	_weapon(rust, rust.darkened(0.4))


## Robes, a deep hood, a chain of beads, bare hands wrapped in cloth, and the brazier.
func _dress_zealot(col: Color) -> void:
	var robe := col.lerp(Color(0.55, 0.2, 0.08), 0.5)
	var wrap := Color(0.75, 0.65, 0.5)
	_mesh(torso, _cyl(0.22, 0.34, 0.6, 7), Vector3(0, -0.05, 0), robe)
	_box(torso, Vector3(0.06, 0.55, 0.02), Vector3(0, -0.05, 0.3), robe.darkened(0.35))  # the robe's seam
	for k in 6:
		_mesh(torso, _sphere(0.02, 4), Vector3(-0.1 + k * 0.04, 0.22 - absf(k - 2.5) * 0.03, 0.26), Color(0.25, 0.15, 0.1))  # beads
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.2, 0.08, 0.28), Vector3(0.3 * side, 0.24, 0), robe.darkened(0.2))
		_box(pd, Vector3(0.06, 0.03, 0.06), Vector3(0, 0.05, 0.08), Color(0.8, 0.6, 0.25))  # a brass stud
		_pauldrons.append(pd)
	_mesh(head, _cyl(0.05, 0.22, 0.4, 7), Vector3(0, 0.02, -0.02), robe.darkened(0.3))  # hood
	_box(head, Vector3(0.18, 0.2, 0.06), Vector3(0, -0.02, 0.1), Color(0.6, 0.45, 0.35))  # the face inside
	_box(head, Vector3(0.04, 0.02, 0.01), Vector3(-0.045, 0.02, 0.135), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.04, 0.02, 0.01), Vector3(0.045, 0.02, 0.135), Color(0.05, 0.03, 0.02))
	_box(head, Vector3(0.06, 0.02, 0.01), Vector3(0, -0.06, 0.135), Color(0.4, 0.15, 0.1))  # singing
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.1, 0.12, 0.1), Vector3.ZERO, wrap)
		_box(hand, Vector3(0.11, 0.02, 0.11), Vector3(0, 0.02, 0), wrap.darkened(0.25))
		_box(hand, Vector3(0.11, 0.02, 0.11), Vector3(0, -0.03, 0), wrap.darkened(0.25))
	_weapon(Color(0.4, 0.3, 0.2), Color(0.3, 0.2, 0.1))


## The Castellan: the heaviest plate there is, a blue tabard, and his tower shield.
func _dress_castellan(col: Color) -> void:
	var steel := col.lerp(Color(0.55, 0.58, 0.65), 0.5)
	var cloth := Color(0.15, 0.25, 0.55)
	_mesh(torso, _cyl(0.27, 0.33, 0.52, 6), Vector3.ZERO, steel)
	_box(torso, Vector3(0.3, 0.44, 0.02), Vector3(0, -0.04, 0.3), cloth)
	_box(torso, Vector3(0.1, 0.1, 0.01), Vector3(0, 0.0, 0.31), Color(0.95, 0.75, 0.2))  # the keep's badge
	_mesh(torso, _cyl(0.15, 0.17, 0.1, 8), Vector3(0, 0.3, 0), steel.darkened(0.2))
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.26, 0.14, 0.36), Vector3(0.34 * side, 0.22, 0), steel.lightened(0.1))
		_box(pd, Vector3(0.28, 0.04, 0.38), Vector3(0, 0.08, 0), steel.lightened(0.2))  # layered
		_pauldrons.append(pd)
	_mesh(head, _cyl(0.17, 0.17, 0.38, 8), Vector3.ZERO, steel.lightened(0.15))
	_mesh(head, _cyl(0.0, 0.17, 0.08, 8), Vector3(0, 0.23, 0), steel.lightened(0.1))
	_box(head, Vector3(0.26, 0.03, 0.02), Vector3(0, 0.03, 0.17), Color(0.01, 0.01, 0.01))
	for k in 3:
		_box(head, Vector3(0.015, 0.1, 0.02), Vector3(-0.05 + k * 0.05, -0.08, 0.17), Color(0.01, 0.01, 0.01))  # breaths
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.13, 0.13, 0.13), Vector3.ZERO, steel)
		_box(hand, Vector3(0.12, 0.09, 0.14), Vector3(0, -0.1, -0.02), steel.darkened(0.1))
	_weapon(Color(0.82, 0.84, 0.9), steel.darkened(0.1))


## The headsman: a black hood with eye holes, a leather apron over a broad chest, bare
## arms, straps for shoulders, and the axe.
func _dress_headsman(_col: Color) -> void:
	var skin := Color(0.7, 0.55, 0.45)
	var leather := Color(0.25, 0.15, 0.08)
	_box(torso, Vector3(0.7, 0.56, 0.36), Vector3.ZERO, skin)
	_box(torso, Vector3(0.44, 0.6, 0.03), Vector3(0, -0.06, 0.19), leather)  # apron
	_box(torso, Vector3(0.4, 0.06, 0.02), Vector3(0, 0.1, 0.21), Color(0.45, 0.1, 0.08))  # stained
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.1, 0.06, 0.4), Vector3(0.22 * side, 0.3, 0), leather.lightened(0.15))  # straps
		_pauldrons.append(pd)
	_box(head, Vector3(0.28, 0.36, 0.28), Vector3(0, 0.02, 0), Color(0.06, 0.05, 0.05))  # hood
	_box(head, Vector3(0.05, 0.04, 0.02), Vector3(-0.06, 0.04, 0.145), Color(0.6, 0.5, 0.4))  # the eyes behind
	_box(head, Vector3(0.05, 0.04, 0.02), Vector3(0.06, 0.04, 0.145), Color(0.6, 0.5, 0.4))
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.15, 0.16, 0.14), Vector3.ZERO, skin)
		_box(hand, Vector3(0.16, 0.05, 0.16), Vector3(0, 0.09, 0), leather)
	_weapon(Color(0.5, 0.5, 0.52), leather)


## The Lamplighter: a long dark coat, a tall hat, a thin pale face with eyes that glow, and
## its staff with the lantern on it.
func _dress_lamplighter(col: Color) -> void:
	var coat := col.lerp(Color(0.12, 0.15, 0.25), 0.6)
	_mesh(torso, _cyl(0.16, 0.26, 0.62, 7), Vector3(0, -0.04, 0), coat)
	for k in 5:
		_mesh(torso, _sphere(0.013, 4), Vector3(0.03, -0.2 + k * 0.1, 0.21), Color(0.7, 0.6, 0.3))
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.16, 0.06, 0.26), Vector3(0.22 * side, 0.26, 0), coat.lightened(0.2))  # epaulettes
		_box(pd, Vector3(0.14, 0.02, 0.02), Vector3(0, 0.04, 0.12), Color(0.7, 0.6, 0.3))
		_pauldrons.append(pd)
	_box(head, Vector3(0.18, 0.3, 0.18), Vector3(0, -0.03, 0), Color(0.78, 0.78, 0.72))
	_glow(head, Vector3(0.04, 0.02, 0.02), Vector3(-0.05, 0.03, 0.095), Color(0.6, 0.85, 1.0))
	_glow(head, Vector3(0.04, 0.02, 0.02), Vector3(0.05, 0.03, 0.095), Color(0.6, 0.85, 1.0))
	_mesh(head, _cyl(0.2, 0.2, 0.02, 8), Vector3(0, 0.13, 0), coat.darkened(0.3))
	_mesh(head, _cyl(0.11, 0.12, 0.3, 8), Vector3(0, 0.29, 0), coat.darkened(0.3))  # tall hat
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.08, 0.11, 0.08), Vector3.ZERO, Color(0.2, 0.2, 0.22))
	_weapon(Color(0.5, 0.75, 1.0), Color(0.3, 0.25, 0.18), true)


## Great Helm: a proper low-poly knight. Bucket helm with a cross visor and plume,
## a tapered breastplate under a tabard, domed pauldrons, articulated gauntlets.
func _dress_great_helm(col: Color) -> void:
	var steel := col.lerp(Color(0.6, 0.62, 0.68), 0.6)
	var cloth := Color(0.55, 0.12, 0.1)
	_mesh(torso, _cyl(0.24, 0.31, 0.5, 6), Vector3.ZERO, steel)
	_box(torso, Vector3(0.3, 0.42, 0.02), Vector3(0, -0.04, 0.27), cloth)  # tabard
	_mesh(torso, _cyl(0.13, 0.15, 0.08, 8), Vector3(0, 0.29, 0), steel.darkened(0.2))  # gorget
	for side in [-1.0, 1.0]:
		var pd := _mesh(torso, _sphere(0.15, 6), Vector3(0.32 * side, 0.2, 0), steel.lightened(0.1))
		pd.scale = Vector3(1.0, 0.6, 1.1)
		_pauldrons.append(pd)
	_mesh(head, _cyl(0.16, 0.16, 0.36, 8), Vector3.ZERO, steel.lightened(0.15))
	_mesh(head, _cyl(0.0, 0.16, 0.06, 8), Vector3(0, 0.21, 0), steel.lightened(0.1))  # domed top
	_box(head, Vector3(0.24, 0.03, 0.02), Vector3(0, 0.03, 0.16), Color(0.01, 0.01, 0.01))  # eye slit
	_box(head, Vector3(0.03, 0.14, 0.02), Vector3(0, -0.06, 0.16), Color(0.01, 0.01, 0.01))  # breaths
	var plume := _mesh(head, PrismMesh.new(), Vector3(0, 0.34, -0.05), cloth)
	plume.scale = Vector3(0.05, 0.22, 0.28)
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.12, 0.12, 0.12), Vector3.ZERO, steel)
		_box(hand, Vector3(0.13, 0.05, 0.08), Vector3(0, -0.06, 0.05), steel.darkened(0.2))  # fingers
		_box(hand, Vector3(0.1, 0.08, 0.13), Vector3(0, -0.1, -0.02), steel.darkened(0.1))  # cuff
	_weapon(Color(0.82, 0.84, 0.9), Color(0.35, 0.3, 0.2))


## Wraith: no body. A hooded helm with burning eyes and two floating gauntlets over a
## ragged cloak. The head and hands are all there is.
func _dress_wraith(col: Color) -> void:
	var dark := Color(0.06, 0.05, 0.07)
	var bone := Color(0.7, 0.68, 0.62)
	_mesh(torso, _cyl(0.1, 0.4, 0.8, 7), Vector3(0, -0.12, -0.05), dark)  # cloak
	for side in [-1.0, 1.0]:
		var pd := _box(torso, Vector3(0.16, 0.05, 0.22), Vector3(0.34 * side, 0.26, 0.02), col.darkened(0.3))
		pd.rotation.z = -0.3 * side
		_pauldrons.append(pd)
	_mesh(head, _cyl(0.04, 0.21, 0.42, 7), Vector3(0, 0.03, -0.02), dark)  # hood
	_box(head, Vector3(0.2, 0.24, 0.05), Vector3(0, -0.01, 0.12), Color(0.02, 0.02, 0.02))
	for side in [-1.0, 1.0]:
		_glow(head, Vector3(0.045, 0.02, 0.02), Vector3(0.05 * side, 0.02, 0.15), Color(1.0, 0.25, 0.1))
	for hand in [right_hand, left_hand]:
		_box(hand, Vector3(0.1, 0.11, 0.1), Vector3.ZERO, bone)
		for k in 4:
			_box(hand, Vector3(0.018, 0.08, 0.018), Vector3(-0.04 + k * 0.027, -0.08, 0.03), bone.darkened(0.2))
	_weapon(Color(0.4, 0.6, 1.0), Color(0.15, 0.15, 0.18), true)


func _cyl(top: float, bottom: float, h: float, sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


func _sphere(r: float, segs: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = maxi(2, int(segs / 2.0))
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, col)


func _mesh(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.8)
	mat.emission_energy_multiplier = 0.0
	mesh.material = mat
	_mats.append(mat)
	_base_colors.append(col)
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## Something that glows on its own (eyes, an enchanted blade): not darkened by wounds.
func _glow(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


func _place(n: Node3D, pose: Array) -> void:
	n.position = pose[0]
	n.rotation = pose[1]


func _process(delta: float) -> void:
	swing_parts(delta)
	var glow := heat * 0.6 + (0.9 + sin(Time.get_ticks_msec() * 0.03) * 0.3 if burning_time > 0.0 else 0.0)
	if _flash > 0.0 or glow > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		for m in _mats:
			m.emission = Color(1, 0.9, 0.8).lerp(Color(1.0, 0.4, 0.1), clampf(glow, 0.0, 1.0)) if _flash < glow else Color(1, 0.9, 0.8)
			m.emission_energy_multiplier = maxf(_flash, glow)
	if burning_time > 0.0 and state != "dead":
		burning_time -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			take_hit(BURN_DPS * 0.5, "torso", false)
	heat = maxf(0.0, heat - delta * 0.05)
	if poison_time > 0.0 and state != "dead":
		poison_time -= delta
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 0.5
			take_hit(POISON_DPS * 0.5, "torso", false)
		for i in _mats.size():
			_mats[i].albedo_color = _mats[i].albedo_color.lerp(Color(0.35, 0.7, 0.25), delta * 0.5)
	if state == "dead" or not active:
		return
	slow_time = maxf(0.0, slow_time - delta)
	off_balance = maxf(0.0, off_balance - delta)
	gummed = maxf(0.0, gummed - delta)
	var dt := delta * (0.5 if slow_time > 0.0 else 1.0)
	if _tween:
		_tween.set_speed_scale(0.5 if slow_time > 0.0 else 1.0)
	_timer -= dt
	_since_stagger += dt
	if _since_stagger > 3.0 and state != "broken":
		stagger_meter = maxf(0.0, stagger_meter - STAGGER_DECAY * dt)
	_update_gaze(delta)
	_update_posture(delta)
	match state:
		"idle":
			if _timer <= 0.0:
				if data.has("guard_stance") and _queued == "" and not _guarded_last and rng.randf() < float(data.guard_stance.chance):
					_begin_guard()
				else:
					_guarded_last = false
					_begin_attack()
		"guarding":
			guard_time -= dt
			if guard_time <= 0.0:
				drop_guard(0.2)
		"windup":
			progress = clampf(1.0 - _timer / _windup_total, 0.0, 1.0)
			_shape_zone()
			if _feint_at >= 0.0 and progress >= _feint_at:
				_feint()
			elif _timer <= 0.0:
				_strike()
		"broken":
			broken_time -= dt
			if broken_time <= 0.0:
				state = "idle"
				weak_spot.visible = false
				_timer = 0.8 / cur_speed()
				_settle()
		"recover", "stagger":
			if _timer <= 0.0:
				state = "idle"
				var rest: Array = data.rest
				_timer = rng.randf_range(rest[0], rest[1]) / cur_speed()
				if _queued != "":
					_timer = minf(_timer, 0.15)  # a follow-up doesn't wait
	_update_clip(dt)


# --- recorded clips ---------------------------------------------------------------

## A baked clip of this foe's, or null if it hasn't been recorded.
func clip(name: String) -> Animation:
	var path := "%s/%s/%s.res" % [CLIP_DIR, model_path(data).get_file().get_basename(), name]
	if not _clip_cache.has(path):
		_clip_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _clip_cache[path]


## Forget loaded clips (after baking new ones while the game runs).
static func reload_clips() -> void:
	_clip_cache.clear()


## Which clip goes with what it's doing now. A combo plays one clip across both blows
## (act_combo_<first>) when it has one, through the pause between them too.
func _clip_wanted() -> String:
	var combo := clip_name.begins_with("act_combo_") and _combo_next != ""
	match state:
		"windup":
			var id := str(current.get("id", ""))
			if combo and id == _combo_next:
				return clip_name  # the second blow of the combo it's playing
			if current.has("next") and clip("act_combo_" + id) != null:
				return "act_combo_" + id
			return "act_" + id
		"recover":
			return clip_name if clip_name.begins_with("act_") and clip_name != "act_guard" else ""  # the blow's follow-through
		"guarding":
			return "act_guard"
		"stagger":
			return "act_stagger"
		"broken":
			return "act_broken"
		"dead":
			return ""  # it goes over like a cardboard cutout (_die): no clip
		"idle":
			if combo and _queued == _combo_next:
				return clip_name  # between a combo's two blows
			if _playing_out():
				return clip_name  # a follow-through or a recovery, running into the idle
			return "idle_" + str(data.get("idle", "steady"))
	return ""


## The one-shot clip playing (a blow, a stagger, a break) still has more than its settle
## to go: back in the idle, it plays on rather than being cut.
func _playing_out() -> bool:
	return _clip != null and clip_name.begins_with("act_") and clip_name != "act_guard" \
		and _clip.loop_mode == Animation.LOOP_NONE and clip_time < _clip.length - CLIP_SETTLE


## Plays the clip for what it's doing, if there is one: hands from the clip, the head the
## cursor gaze with the clip's head motion on top. Changing clip crossfades the hands
## (quickly: a stagger still snaps); an attack aimed at the player's hand is bent towards
## it; a combo's second blow lands on the clip's second strike mark.
func _update_clip(dt: float) -> void:
	var want := _clip_wanted()
	if want != clip_name:
		var had := _clip != null
		var old_clip := _clip
		var old_time := clip_time
		var settling := clip_name.begins_with("act_") and want.begins_with("idle_")
		clip_name = want
		clip_time = 0.0
		_clip = clip(want) if want != "" else null
		_combo_next = str(current.get("next", "")) if want.begins_with("act_combo_") else ""
		_combo_t0 = -1.0
		if had and _clip == null and state != "dead":
			_settle()  # back to the procedural pose, from wherever the clip left the hands
		if _clip == null and state == "recover":
			clip_name = ""
		if _clip != null:
			# crossfade from what the hands were doing: the old clip playing on, or (from the
			# procedural pose) where they were
			# (changed again mid-crossfade: fade from where the hands are, not the old clip's own pose)
			_from_clip = old_clip if had and _blend_t <= 0.0 else null
			_blend_len = CLIP_SNAP if state in ["stagger", "broken", "dead"] else (CLIP_SETTLE if settling else CLIP_BLEND)
			_blend_t = _blend_len
			_blend_from = [right_hand.position, right_hand.quaternion, left_hand.position, left_hand.quaternion, head.position]
			_from_time = old_time
	if _clip == null:
		return
	var length := _clip.length
	match state:
		"windup":
			if clip_name.begins_with("act_combo_") and str(current.get("id", "")) == _combo_next:
				if _combo_t0 < 0.0:
					_combo_t0 = clip_time  # the second blow's wind-up starts here in the clip
				var s2 := float(_clip.get_meta("strike2", lerpf(_combo_t0, length, 0.7)))
				clip_time = lerpf(_combo_t0, s2, progress)
			else:
				clip_time = progress * strike_time(_clip)  # the blow lands when the game's strike does
		"guarding":
			clip_time = clampf(1.0 - guard_time / _guard_total, 0.0, 1.0) * length
		_:
			# (a blow's follow-through at the foe's pace: a fast or enraged one recovers faster)
			var attack_tail := clip_name.begins_with("act_") and not clip_name in ["act_stagger", "act_broken", "act_guard"]
			clip_time += dt * (cur_speed() if attack_tail else 1.0)
			if _clip.loop_mode != Animation.LOOP_NONE:
				clip_time = fmod(clip_time, maxf(length, 0.001))
			else:
				clip_time = minf(clip_time, length)
	if _tween and _tween.is_valid():
		_tween.kill()  # the clip has the hands now
	var aim := _aim_offset(dt)
	_blend_t = maxf(0.0, _blend_t - dt)
	var w := smoothstep(0.0, 1.0, 1.0 - _blend_t / maxf(_blend_len, 0.001))
	if _from_clip and w < 1.0:
		_from_time += dt
		_from_time = fmod(_from_time, maxf(_from_clip.length, 0.001)) if _from_clip.loop_mode != Animation.LOOP_NONE else minf(_from_time, _from_clip.length)
	var i := 0
	for part in [["RightHand", right_hand], ["LeftHand", left_hand]]:
		var node: Node3D = part[1]
		var tr := _clip_tracks(_clip, part[0])
		var pos := node.position
		var rot := node.quaternion
		if tr.x >= 0:
			pos = _clip.position_track_interpolate(tr.x, clip_time) + (aim[i] as Vector3)
		if tr.y >= 0:
			rot = _clip.rotation_track_interpolate(tr.y, clip_time)
		if w < 1.0 and _blend_from.size() >= 4:
			var from_pos: Vector3 = _blend_from[i * 2]
			var from_rot: Quaternion = _blend_from[i * 2 + 1]
			var ft := _clip_tracks(_from_clip, part[0]) if _from_clip else Vector2i(-1, -1)
			if ft.x >= 0:
				from_pos = _from_clip.position_track_interpolate(ft.x, _from_time)
			if ft.y >= 0:
				from_rot = _from_clip.rotation_track_interpolate(ft.y, _from_time)
			pos = from_pos.lerp(pos, w)
			rot = from_rot.slerp(rot, w)
		node.position = pos
		node.quaternion = rot
		i += 1
	var ht := _clip_tracks(_clip, "Head")
	if ht.x >= 0:
		var hp := _clip.position_track_interpolate(ht.x, clip_time)  # the recorded lean and duck...
		if w < 1.0 and _blend_from.size() == 5:  # (crossfaded like the hands: the body doesn't jump)
			var fh := _clip_tracks(_from_clip, "Head") if _from_clip else Vector2i(-1, -1)
			var from_head: Vector3 = _from_clip.position_track_interpolate(fh.x, _from_time) if fh.x >= 0 else _blend_from[4]
			hp = from_head.lerp(hp, w)
		head.position = hp
		follow_head_with_torso()  # ...with the body under it
	if ht.y >= 0:
		var rest := _clip.rotation_track_interpolate(ht.y, 0.0)
		var now := _clip.rotation_track_interpolate(ht.y, clip_time)
		var hw: float = CLIP_HEAD.idle if state == "idle" else CLIP_HEAD.other
		head.quaternion = head.quaternion * Quaternion.IDENTITY.slerp(rest.inverse() * now, hw)
	_flinch_layer(dt)


## A hit lands without staggering it: the flinch plays over whatever it's doing, from the
## moment the recorded recoil starts (a take begins with the performer waiting for it). A
## hit during a flinch starts a new one; the old one fades out under it.
func flinch() -> void:
	var fl := clip("act_flinch")
	if state in ["dead", "broken", "stagger"] or fl == null:
		return
	if _flinch_t >= 0.0:
		_flinch_old_t = _flinch_t
		_flinch_old_w = 1.0
	_flinch_t = flinch_onset(fl)


## When a flinch clip's recoil starts: the first moment its weapon hand (or head) is moving
## at speed, a frame or two early. Worked out once per clip.
static func flinch_onset(fl: Animation) -> float:
	if fl.has_meta("onset"):
		return fl.get_meta("onset")
	var at := 0.0
	var parts := [_clip_tracks(fl, "RightHand"), _clip_tracks(fl, "Head")]
	var t := 1.0 / 30.0
	while t < fl.length * 0.6 and at == 0.0:
		for tr in parts:
			if tr.x < 0:
				continue
			var v := fl.position_track_interpolate(tr.x, t).distance_to(fl.position_track_interpolate(tr.x, t - 1.0 / 30.0)) * 30.0
			var turn := 0.0
			if tr.y >= 0:
				turn = fl.rotation_track_interpolate(tr.y, t).angle_to(fl.rotation_track_interpolate(tr.y, t - 1.0 / 30.0)) * 30.0
			if v > 0.25 or turn > 1.5:  # (a quarter metre a second, or most of a turn a second)
				at = maxf(t - 0.06, 0.0)
				break
		t += 1.0 / 30.0
	fl.set_meta("onset", at)
	return at


## The flinch clip's recoil (each hand and the head, from where they are in its first frame),
## added on top of the hands and head as they are this frame, easing in fast and out slowly.
func _flinch_layer(dt: float) -> void:
	var fl := clip("act_flinch")
	if fl == null or state in ["dead", "broken", "stagger"]:
		_flinch_t = -1.0
		_flinch_old_t = -1.0
		return
	_flinch_gain = lerpf(_flinch_gain, FLINCH_GAIN_WINDUP if state == "windup" else FLINCH_GAIN, 1.0 - exp(-8.0 * dt))
	var gain := _flinch_gain
	if _flinch_old_t >= 0.0:
		_flinch_old_w -= dt / FLINCH_HANDOVER
		if _flinch_old_w <= 0.0 or _flinch_old_t > fl.length:
			_flinch_old_t = -1.0
		else:
			_add_flinch(fl, _flinch_old_t, gain * smoothstep(0.0, 1.0, _flinch_old_w))
			_flinch_old_t += dt
	if _flinch_t >= 0.0:
		if _flinch_t > fl.length:
			_flinch_t = -1.0
		else:
			_add_flinch(fl, _flinch_t, gain)
			_flinch_t += dt
	follow_head_with_torso()


## One flinch's recoil at `t` into its clip, `w` of it (eased in from its onset, out at its end).
func _add_flinch(fl: Animation, t: float, w: float) -> void:
	var t0 := flinch_onset(fl)
	var env := w * smoothstep(t0, t0 + 0.05, t) * (1.0 - smoothstep(lerpf(t0, fl.length, 0.45), fl.length, t))
	for part in [["RightHand", right_hand], ["LeftHand", left_hand], ["Head", head]]:
		var tr := _clip_tracks(fl, part[0])
		var node: Node3D = part[1]
		if tr.x >= 0:
			node.position += (fl.position_track_interpolate(tr.x, t) - fl.position_track_interpolate(tr.x, t0)) * env
		if tr.y >= 0 and part[0] != "Head":  # (the head keeps its gaze: only its recoil moves it)
			var d := fl.rotation_track_interpolate(tr.y, t) * fl.rotation_track_interpolate(tr.y, t0).inverse()
			node.quaternion = (Quaternion.IDENTITY.slerp(d, env) * node.quaternion).normalized()


## The torso travels with the head (leaning, ducking, rearing back) so it stays under it.
## It doesn't turn: it keeps squared up to the player.
func follow_head_with_torso() -> void:
	torso.position = _torso_rest + (head.position - _head_rest) * TORSO_FOLLOW


## How far to bend the hands of a blow aimed at the player's hand: a clip is performed at
## the attack's usual spot, so it's moved by however far the game moved the field (the
## hand's there now), building up over the wind-up and easing off after the blow.
## [right hand, left hand] offsets.
func _aim_offset(dt: float) -> Array:
	if state == "windup" and (current.get("track", false) or current.has("chase")):
		var id := str(current.get("id", ""))
		var from := zone_point(_centre(EnemyDefs.ATTACKS[id].zone if EnemyDefs.ATTACKS.has(id) else current.zone), 0.5, cam_rel())
		var to := zone_point(_centre(current.zone), 0.5, cam_rel())
		var pose: Dictionary = POSES.get(current.get("pose", ""), {})
		var off_hand: bool = pose.get("shield", false)
		var both: bool = pose.get("l", false) or pose.get("mirror", false)
		_aim_hands = Vector2(0.0 if off_hand else 1.0, 1.0 if off_hand or both else 0.0)
		_aim_last = (to - from) * smoothstep(0.0, 1.0, progress)
	elif state == "recover":
		_aim_last = _aim_last.move_toward(Vector3.ZERO, dt * 1.5)
	else:
		_aim_last = Vector3.ZERO
	return [_aim_last * _aim_hands.x, _aim_last * _aim_hands.y]


static func _centre(zone: Array) -> Vector2:
	var c := Vector2.ZERO
	for p in zone:
		c += p
	return c / maxf(zone.size(), 1.0)


## Where a point of the player's screen (0..1 each way) lands in front of a foe, in its own
## space: on a plane `depth` metres in front of it, seen from the game's camera (main.gd
## frames foes from GAME_CAM with a GAME_FOV vertical field of view, at 16:9).
static func zone_point(p: Vector2, depth := 0.5, cam := GAME_CAM) -> Vector3:
	var ty := tan(deg_to_rad(GAME_FOV * 0.5))
	var ndc := Vector2(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0)
	var d := cam.z - depth
	return Vector3(ndc.x * ty * (16.0 / 9.0) * d, cam.y + ndc.y * ty * d, depth)


## When a clip's blow lands: its "strike" mark (the recording suite sets it), or CLIP_STRIKE.
static func strike_time(a: Animation) -> float:
	return float(a.get_meta("strike", a.length * CLIP_STRIKE))


## A clip's [position, rotation] track indices for one of the performers (-1 if none).
static func _clip_tracks(a: Animation, part: String) -> Vector2i:
	var key := "tracks_" + part
	if a.has_meta(key):
		return a.get_meta(key)
	var out := Vector2i(-1, -1)
	for i in a.get_track_count():
		if not str(a.track_get_path(i)).ends_with("Body/" + part):
			continue
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			out.x = i
		elif a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			out.y = i
	a.set_meta(key, out)
	return out


## Head watches the player's hand when idle and the target zone while winding up;
## the torso lags behind it (eyes fast, head medium, body slow).
func _update_gaze(delta: float) -> void:
	var look := look_target
	if state == "windup" and not current.is_empty():
		var c := Vector2.ZERO
		for p in current.zone:
			c += p
		look = c / current.zone.size()
	var yaw := (look.x - 0.5) * 0.9
	var pitch := (0.45 - look.y) * 0.6
	var rear := 0.0
	if state == "windup" and not current.is_empty() and POSES[current.pose].get("head", false):
		rear = -0.5 + progress * 0.9  # rears back, then lunges forward to spit
	_gaze.y = lerp_angle(_gaze.y, yaw, 1.0 - exp(-delta * 8.0))
	_gaze.x = lerp_angle(_gaze.x, -pitch + rear, 1.0 - exp(-delta * 8.0))
	head.rotation = _gaze
	torso.rotation.y = lerp_angle(torso.rotation.y, yaw * 0.35, 1.0 - exp(-delta * 2.0))


## Wounds show in the body: it hunches and sinks as HP drops, and reels while off balance.
## Between swings each character carries itself its own way (data.idle).
func _update_posture(delta: float) -> void:
	var worn := 1.0 - hp / max_hp
	var t := Time.get_ticks_msec() * 0.001
	var reel := sin(t * 12.0) * 0.12 if off_balance > 0.0 else 0.0
	# the fuller the stagger meter, the more it sways and its head lolls
	var dizzy := stagger_fraction()
	reel += sin(t * 5.0) * 0.08 * dizzy
	var k := 1.0 - exp(-delta * 6.0)
	var slump := 0.0
	if state == "broken":
		slump = 1.0
		reel = sin(t * 3.0) * 0.05
	var hunch := 0.0
	var bob := sin(t * 3.0) * (0.015 + 0.03 * worn)  # breathing gets heavier as it's worn down
	var sway := 0.0
	var tilt := 0.0
	match data.get("idle", "steady"):
		"heavy":
			bob = sin(t * 2.0) * (0.03 + 0.04 * worn)
			if is_enraged():
				bob += sin(t * 14.0) * 0.012  # shaking with it
				tilt = sin(t * 9.0) * 0.04
		"bounce":
			bob = absf(sin(t * 6.0)) * 0.035  # up on its toes
			sway = sin(t * 3.0) * 0.06
		"shamble":
			hunch = 0.3
			tilt = 0.2
			sway = sin(t * 1.3) * 0.03
		"drift":
			bob = sin(t * 1.5) * 0.06
			sway = sin(t * 0.9) * 0.04
		"guard":
			hunch = 0.05
	if state == "idle" or state == "recover":
		body.position.y = bob
		body.position.x = lerpf(body.position.x, sway, k)
	torso.rotation.x = lerpf(torso.rotation.x, worn * 0.25 + slump * 0.25 + hunch, k)
	body.rotation.z = lerpf(body.rotation.z, reel + tilt * 0.3, k)
	body.position.y = lerpf(body.position.y, -0.1 * slump, k) if state == "broken" else body.position.y
	head.position.y = lerpf(head.position.y, 1.68 - worn * 0.08 - slump * 0.12 - hunch * 0.1, k)
	_gaze.z = lerpf(_gaze.z, sin(t * 2.3) * 0.25 * dizzy + slump * 0.3 + tilt, k)
	head.rotation = _gaze
	if shield_arm and state != "dead":
		# the Castellan keeps the wall up: the shield covers the torso until it's rattled
		var up: bool = guard_up() and not (state == "windup" and current.get("pose", "") == "bash")
		var target := Vector3(-0.25, 1.2, 0.45) if up else REST_L[0]
		if state == "idle" or state == "recover":
			left_hand.position = left_hand.position.lerp(target, k)
			left_hand.rotation = left_hand.rotation.lerp(Vector3(0.15, 0.6, 0.0) if up else REST_L[1], k)


func stagger_fraction() -> float:
	return clampf(stagger_meter / float(data.get("stagger", 40.0)), 0.0, 1.0)


## Pressure from the player: prevented damage (parries count double) and damage dealt.
func add_stagger(amount: float) -> void:
	if state == "dead" or state == "broken" or amount <= 0.0:
		return
	stagger_meter += amount
	_since_stagger = 0.0
	if stagger_meter >= float(data.get("stagger", 40.0)):
		_break()


func _break() -> void:
	state = "broken"
	broken_time = BROKEN_TIME
	stagger_meter = 0.0
	current = {}
	_queued = ""  # broken: the follow-up it had coming is lost
	_queued_windup = -1.0
	progress = 0.0
	weak_spot.position = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.12), 0.17)
	weak_spot.visible = true
	_move({"s": [Vector3(0.35, 0.95, 0.15), Vector3(1.2, 0, -0.4)]}, "s", 0.25, Tween.EASE_OUT)
	broke.emit()


## Where armour came off, raw flesh shows: hits there land harder for the rest of the fight.
func _expose(pd: MeshInstance3D) -> void:
	var patch := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.08, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.12, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.15, 0.1)
	mat.emission_energy_multiplier = 0.6
	bm.material = mat
	patch.mesh = bm
	patch.position = pd.position + Vector3(0, -0.02, 0)
	pd.get_parent().add_child(patch)
	_exposed.append(patch)


## A superheated hit: heat builds until it catches fire. A fireproof character shrugs it off.
func heat_up(amount: float) -> void:
	if state == "dead" or data.get("fireproof", false):
		return
	heat += amount
	if heat >= 1.0:
		heat = 0.0
		burning_time = BURN_TIME
		ignited.emit()


func poison(secs: float) -> void:
	poison_time = maxf(poison_time, secs)


## A corrosive hit eats into the armour (the Rusted's rotten plate goes twice as fast).
func corrode(amount: float) -> void:
	corrosion = minf(1.0, corrosion + amount * float(data.get("corrode_mult", 1.0)))
	_update_wounds()


func _update_wounds() -> void:
	var hurt := clampf(1.0 - hp / max_hp, 0.0, 1.0)
	var worn := maxf(hurt, corrosion)
	for i in _mats.size():
		_mats[i].albedo_color = _base_colors[i].darkened(hurt * 0.45).lerp(Color(0.35, 0.45, 0.2), corrosion * 0.4)
	# Plate is hard to beat off: a pauldron only gives way late in a fight (60% and 90% of
	# its HP lost). Corrosion eats it on its own, much faster scale (a quarter and a half),
	# so a corrosive weapon is how you get at the flesh under it early.
	var lost := 0
	for pd in _pauldrons:
		if not pd.visible:
			lost += 1
	var breaks: Array = data.get("armor_breaks", ARMOR_BREAKS)
	var should := 0
	var by_rot := 0
	for b in breaks:
		if hurt >= float(b):
			should += 1
	for b in CORRODE_BREAKS:
		if corrosion >= b:
			by_rot += 1
	should = maxi(should, by_rot)
	while lost < mini(should, _pauldrons.size()):
		var pd := _pauldrons[lost]
		pd.visible = false
		_expose(pd)
		armor_fell.emit(camera.unproject_position(pd.global_position))
		lost += 1


## The player blocked. Clean blocks are what the characters react to: the Duelist answers
## with a riposte, the Castellan loses patience after a few and bashes the pile apart.
func on_blocked(clean: bool) -> void:
	if state == "dead":
		return
	if not clean:
		clean_blocks = 0
		return
	clean_blocks += 1
	if _queued != "":
		return  # a follow-up's already promised (and shown): it comes first; the bash keeps
	if data.has("riposte"):
		queue_attack(data.riposte, float(data.get("riposte_windup", 0.45)))
	if data.has("bash_after") and clean_blocks >= int(data.bash_after):
		clean_blocks = 0
		queue_attack("shield_bash", 0.8)


## The blade hit something sticky: it comes away gummed, and the next wind-up is slower.
func gum_up(secs: float) -> void:
	gummed = maxf(gummed, secs)


func queue_attack(id: String, windup: float = -1.0) -> void:
	if state == "dead" or state == "broken" or not EnemyDefs.ATTACKS.has(id):
		return
	_queued = id
	_queued_windup = windup


## Picks the next attack (a queued follow-up first), never the same one twice running.
## Tracking attacks centre their zone on wherever the player's hand is right now.
func _begin_attack(forced: String = "", windup: float = -1.0) -> void:
	var id := forced
	if id == "" and _queued != "":
		id = _queued
		windup = _queued_windup
		_queued = ""
		_queued_windup = -1.0
	if id == "":
		var pool: Array = data.attacks
		id = pool[rng.randi() % pool.size()]
		if id == _last_attack and pool.size() > 1:
			id = pool[(pool.find(id) + 1) % pool.size()]
	_last_attack = id
	current = EnemyDefs.ATTACKS[id].duplicate(true)
	current.id = id
	current.damage *= data.get("power", 1.0)
	if current.get("track", false):
		current.zone = _tracked_zone(current.zone)
	current.base_zone = (current.zone as Array).duplicate()
	current.base_dir = current.dir
	# a combo: some foes follow a particular attack with another (shown ahead, faintly)
	var combos: Dictionary = data.get("combos", {})
	if combos.has(id) and windup < 0.0 and not current.has("next") and rng.randf() < float(data.get("combo_chance", 0.5)):
		current.next = combos[id]
		current.next_windup = float(data.get("combo_windup", 0.55))
	# a feint: only an attack it chose itself (never a follow-up, never a feint's answer)
	_feint_at = -1.0
	if forced == "" and windup < 0.0 and data.has("feint") and rng.randf() < float(data.feint.chance):
		_feint_at = float(data.feint.at)
	var w: float = current.windup if windup < 0.0 else windup
	if gummed > 0.0:
		w *= 1.4
		gummed = 0.0
	_windup_total = w / cur_speed()
	_timer = _windup_total
	progress = 0.0
	state = "windup"
	_guard_knocked = false  # (every wind-up comes with its guard up)
	var pose: Dictionary = POSES[current.pose]
	_move(pose, "wind", _windup_total * 0.85, Tween.EASE_OUT)
	Sfx.play("windup", -14.0, 0.7 * (1.2 if is_enraged() else 1.0))
	if current.has("pan"):
		Sfx.play("scrape", -16.0, randf_range(0.85, 1.1))  # (a weapon dragged across: you hear it travel)
	_shape_zone()  # (a chasing or sliding field starts where it should, not at its raw spot)


## Shift a zone so its centre sits on the player's hand, kept on screen.
## A field that moves while it winds up, the way the weapon does. pan: it slides this far
## (screen fractions) by the time it lands, a polearm's head dragged across or a blade drawn
## along the floor; turn: it swings round its middle this far (radians), a flail's chain;
## chase: until this much of the wind-up it follows the player's hand (along chase_axis, both
## ways if none), then commits where it is. The blow lands where the field ends up.
func _shape_zone() -> void:
	var a := current
	if not (a.has("pan") or a.has("turn") or a.has("chase")):
		return
	var t := progress * progress * (3.0 - 2.0 * progress)
	var zone: Array = (a.base_zone as Array).duplicate()
	var dir: Vector2 = a.base_dir
	if a.has("chase"):
		if progress >= float(a.chase) and not a.has("locked_sound"):
			a.locked_sound = true
			Sfx.play("lock", -10.0, 1.0)  # the field stops following and commits: hear the moment
		if progress < float(a.chase):
			var axis: Vector2 = a.get("chase_axis", Vector2.ONE)
			var shift: Vector2 = ((_tracked_zone(zone)[0] as Vector2) - (zone[0] as Vector2)) * axis
			for i in zone.size():
				zone[i] = (zone[i] as Vector2) + shift
			a.locked = zone.duplicate()
		elif a.has("locked"):
			zone = (a.locked as Array).duplicate()
	if a.has("pan"):
		for i in zone.size():
			zone[i] = (zone[i] as Vector2) + (a.pan as Vector2) * t
	if a.has("turn"):
		var c := Vector2.ZERO
		for p in zone:
			c += p
		c /= zone.size()
		var ang: float = float(a.turn) * t
		var aspect := Vector2(16.0 / 9.0, 1.0)  # turn on the screen, not in stretched fractions
		for i in zone.size():
			zone[i] = c + (((zone[i] as Vector2) - c) * aspect).rotated(ang) / aspect
		dir = (dir * aspect).rotated(ang) / aspect
	a.zone = zone
	a.dir = dir


## A feint: the wind-up breaks off and a different attack comes instead, quicker. The
## telegraph moves with it: read the new one, not the old.
func _feint() -> void:
	var from: String = current.id
	var pool: Array = (data.attacks as Array).filter(func(x: String) -> bool: return x != from and not EnemyDefs.ATTACKS[x].get("track", false))
	if pool.is_empty():
		_feint_at = -1.0
		return
	_begin_attack(pool[rng.randi() % pool.size()], float(data.feint.windup))
	current.feinted_from = from
	Sfx.play("feint", -8.0, 1.0)


func _tracked_zone(zone: Array) -> Array:
	var c := Vector2.ZERO
	for p in zone:
		c += p
	c /= zone.size()
	var lo := Vector2(1, 1)
	var hi := Vector2.ZERO
	for p in zone:
		lo = lo.min(p - c)
		hi = hi.max(p - c)
	var target := look_target.clamp(Vector2(0.03, 0.03) - lo, Vector2(0.97, 0.97) - hi)
	var out: Array = []
	for p in zone:
		out.append(p - c + target)
	return out


func _strike() -> void:
	var atk := current
	current = {}
	state = "recover"
	_timer = 0.55 / cur_speed()
	_move(POSES[atk.pose], "hit", 0.09, Tween.EASE_IN)
	get_tree().create_timer(0.2).timeout.connect(_settle)
	if atk.has("next"):
		queue_attack(atk.next, float(atk.get("next_windup", 0.6)))
	if atk.has("sound"):
		Sfx.play(str(atk.sound[0]), float(atk.sound[1]), float(atk.sound[2]))  # a weapon with a voice of its own (the Sexton's bell)
	else:
		match str(atk.get("trait", "")):  # what the blow carries, heard as it lands
			"charged":
				Sfx.play("zap", -8.0, 0.8)
			"burning":
				Sfx.play("crack", -8.0, 0.6)
			"corrosive":
				Sfx.play("soft", -6.0, 0.5)
		if float(atk.get("impact", 1.0)) >= 2.4:
			Sfx.play("thud", -6.0, 0.6)  # a crushing blow lands heavy
	strike.emit(atk)


func _settle() -> void:
	if state == "dead" or state == "windup" or state == "broken":
		return
	_move({"rest": REST_R}, "rest", 0.35, Tween.EASE_IN_OUT)


func _move(pose: Dictionary, key: String, dur: float, ease: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	var r: Array = pose[key]
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	if pose.get("shield", false):
		# the shield arm does the moving; the sword hand stays put
		_tween.tween_property(left_hand, "position", r[0], dur)
		_tween.tween_property(left_hand, "rotation", r[1], dur)
		return
	_tween.tween_property(right_hand, "position", r[0], dur)
	_tween.tween_property(right_hand, "rotation", r[1], dur)
	var l_pos: Vector3 = REST_L[0]
	var l_rot: Vector3 = REST_L[1]
	if pose.get("mirror", false):
		l_pos = Vector3(-r[0].x, r[0].y, r[0].z)
		l_rot = Vector3(r[1].x, -r[1].y, -r[1].z)
	elif pose.get("l", false):
		l_pos = r[0] + Vector3(-0.12, -0.12, 0.02)
	_tween.tween_property(left_hand, "position", l_pos, dur)
	_tween.tween_property(left_hand, "rotation", l_rot, dur)


## Hit-location circles in screen pixels, in the order weapons should check them.
func regions() -> Array:
	var out: Array = []
	if weak_spot.visible:
		out.append(_region("weak", weak_spot))
	for pd in _pauldrons:
		if not pd.visible:
			out.append(_region("exposed", pd))
	out.append(_region("head", head))
	out.append(_region("right_hand", right_hand))
	out.append(_region("left_hand", left_hand))
	out.append(_region("torso", torso))
	return out


func _region(id: String, n: Node3D) -> Dictionary:
	var info: Dictionary = REGIONS[id]
	var p := n.global_position
	var c := camera.unproject_position(p)
	var edge := camera.unproject_position(p + camera.global_basis.x * float(info.radius))
	var mult: float = info.mult
	var armor: float = info.armor
	if id == "torso" and guard_up():
		mult *= 0.4  # the shield is in the way
		armor = 1.6
	return {"id": id, "center": c, "radius": c.distance_to(edge), "mult": mult, "armor": armor}


## How much a weapon's hit does to this character: a Wraith lets plain steel through it but
## not lightning or fire; the Zealot can't stand the cold.
func weapon_mult(it: Item) -> float:
	var elemental: bool = it.charge > 0.3 or it.heat > 0.3 or it.cold > 0.3
	if elemental:
		return float(data.get("elemental_mult", 1.0))
	return float(data.get("weapon_mult", 1.0))


func punch_mult() -> float:
	return float(data.get("punch_mult", 1.0))


## Returns the region hit, so the caller can show it.
## `stagger_mult` scales how much the hit fills the stagger meter: weapon hits barely do
## (blocking is what breaks an enemy), the rest count in full.
func take_hit(dmg: float, region: String = "torso", can_stagger: bool = true, stagger_mult: float = 1.0) -> void:
	if state == "dead":
		return
	if state == "broken":
		dmg *= 1.5
	elif off_balance > 0.0:
		dmg *= 1.5
	add_stagger(dmg * stagger_mult)
	hp -= dmg
	_flash = 1.0
	_update_wounds()
	if region == "weak":
		weak_spot.visible = false  # one big hit, then it closes
	if hp <= 0.0 and float(data.get("revive", 0.0)) > 0.0 and not has_meta("revived"):
		set_meta("revived", true)  # it puts itself back together, once
		hp = max_hp * float(data.revive)
		_flash = 1.0
		stagger()
		return
	if hp <= 0.0:
		_die()
		return
	# knocking the attacking hand mid-swing is the easiest way to interrupt it
	var poise: float = data.poise * (0.5 if region == "right_hand" else 1.0)
	if can_stagger and state == "windup" and dmg >= poise:
		stagger()
	else:
		flinch()


## The swing was stopped cold: the enemy reels, leaving an opening (longer for the nervous).
func throw_off_balance(t: float) -> void:
	if state == "dead" or state == "broken":
		return
	off_balance = t * float(data.get("flinch", 1.0))
	_timer = maxf(_timer, off_balance)


func stagger() -> void:
	if state == "dead" or state == "broken":
		return
	state = "stagger"
	current = {}
	_queued = ""  # staggered: whatever it meant to follow with is lost
	_queued_windup = -1.0
	progress = 0.0
	_timer = float(data.get("stagger_time", 0.9))
	_move({"s": [Vector3(0.45, 1.5, -0.1), Vector3(0.6, 0, -0.8)]}, "s", 0.15, Tween.EASE_OUT)
	get_tree().create_timer(0.4).timeout.connect(_settle)


func _die() -> void:
	state = "dead"
	current = {}
	weak_spot.visible = false
	if _tween:
		_tween.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(body, "rotation:x", -1.3, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position:y", -0.6, 0.8)
	died.emit()
