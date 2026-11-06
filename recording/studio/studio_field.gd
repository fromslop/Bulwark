## The player's screen, standing in front of YOU at about arm's reach: the FRAME (its edges
## are the edges of what the player sees) and, inside it, the picked attack's FIELD, with
## chevrons for the way the blade travels or a ring for a thrust or a blow aimed at the hand.
##
## It's the screen run backwards through the rig (EnemyRig.performer_tip_for): wherever
## the TIP of the weapon on your right controller crosses it, the foe's weapon tip crosses
## that same point of the player's screen. Stab through its middle and the blow lands in
## the middle of the player's view; run the tip along its edge and the blade's end skims
## the edge of what the player sees. It's built from where you stood when the take (or the character) began,
## so it follows you if you move between takes.
class_name StudioField
extends Node3D

## The game's camera, relative to the foe (main.gd: framed waist-up). Zones are fractions
## of what it sees.
const CAM := Enemy.GAME_CAM
const CAM_FOV := Enemy.GAME_FOV  # vertical

var _frame: Node3D  # the player's screen's edges
var _attack: Node3D  # the picked attack's field (fill, edges, arrows, caption)
var _fill: MeshInstance3D
var _edges: Node3D
var _arrows: Node3D
var _caption: Label3D


func _init() -> void:
	name = "Field"
	_frame = Node3D.new()
	add_child(_frame)
	_attack = Node3D.new()
	add_child(_attack)
	_fill = MeshInstance3D.new()
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.layers = 2
	_attack.add_child(_fill)
	_edges = Node3D.new()
	_attack.add_child(_edges)
	_arrows = Node3D.new()
	_attack.add_child(_arrows)
	_caption = _label(HHStyle.FIELD)
	_attack.add_child(_caption)
	visible = false


## Where a point of the player's screen (0..1 each way) lands in front of the foe, in its
## own space, `depth` metres out.
static func zone_point(p: Vector2, depth := 0.5) -> Vector3:
	return Enemy.zone_point(p, depth)


## Fainter while you perform: a guide, not a wall.
func follow(studio) -> void:
	visible = studio.stage_model() != null and studio.character.has_method("performer_tip_for")
	var a := 0.55 if studio.is_recording() else 1.0
	_fill.transparency = 1.0 - a
	for n in _edges.get_children():
		(n as GeometryInstance3D).transparency = 1.0 - a


## Builds the frame and the cue's field in front of the performer.
func show_cue(studio, cue: Dictionary) -> void:
	var rig = studio.character
	if rig == null or studio.stage_model() == null or not rig.has_method("performer_tip_for"):
		return
	var origin: Transform3D = studio.get_node("XROrigin3D").global_transform
	var depth: float = rig.tip_frame_depth()
	var to_you := func(p: Vector2) -> Vector3: return origin * (rig.performer_tip_for(rig.screen_point(p, depth)) as Vector3)
	_build_frame(to_you)
	var atk: Dictionary = studio.cue_attack(cue)
	_attack.visible = not atk.is_empty()
	if atk.is_empty():
		return
	var pts: Array[Vector3] = []
	var flat := Vector2.ZERO
	for p in atk.zone:
		pts.append(to_you.call(p))
		flat += p
	flat /= atk.zone.size()
	_fill.mesh = _polygon(pts)
	_fill.material_override = _mat(Color(HHStyle.FIELD, 0.16))
	_clear(_edges)
	for i in pts.size():
		_edges.add_child(_bar(pts[i], pts[(i + 1) % pts.size()], 0.005, Color(HHStyle.FIELD, 0.9)))
	_clear(_arrows)
	var centre: Vector3 = to_you.call(flat)
	var d2: Vector2 = atk.dir
	if d2.length() < 0.01:
		# thrust or aimed: a ring on the target
		var right: Vector3 = (to_you.call(flat + Vector2(0.03, 0)) - centre).normalized()
		var up: Vector3 = (to_you.call(flat - Vector2(0, 0.03)) - centre).normalized()
		for k in 16:
			var a0 := k * TAU / 16.0
			var a1 := (k + 1) * TAU / 16.0
			_arrows.add_child(_bar(centre + (right * cos(a0) + up * sin(a0)) * 0.035, centre + (right * cos(a1) + up * sin(a1)) * 0.035, 0.006, HHStyle.FIELD))
	else:
		var dir: Vector3 = (to_you.call(flat + d2.normalized() * 0.05) - centre).normalized()
		var normal := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		var side := normal.cross(dir).normalized()
		for k in 3:
			var tip := centre + dir * (-0.07 + k * 0.07)
			_arrows.add_child(_bar(tip, tip - dir * 0.03 + side * 0.025, 0.006, HHStyle.FIELD))
			_arrows.add_child(_bar(tip, tip - dir * 0.03 - side * 0.025, 0.006, HHStyle.FIELD))
	var top := pts[0]
	for p in pts:
		if p.y > top.y:
			top = p
	var notes: Array = []
	if atk.get("track", false):
		notes.append("aimed at the hand")
	if atk.has("chase"):
		notes.append("follows the hand")
	if atk.has("pan"):
		notes.append("travels")
	if atk.has("turn"):
		notes.append("turns")
	_caption.text = StudioSlate.clip_title(cue).to_upper() + ("   ·   " + "  ·  ".join(PackedStringArray(notes)) if not notes.is_empty() else "")
	_caption.position = Vector3(centre.x, maxf(top.y, centre.y) + 0.035, centre.z)


## The player's screen's edges: a faint outline, bright corner brackets, a cross at its
## middle, and its name over the top left corner.
func _build_frame(to_you: Callable) -> void:
	_clear(_frame)
	var c: Array = [to_you.call(Vector2(0, 0)), to_you.call(Vector2(1, 0)), to_you.call(Vector2(1, 1)), to_you.call(Vector2(0, 1))]
	for i in 4:
		_frame.add_child(_bar(c[i], c[(i + 1) % 4], 0.003, Color(HHStyle.ACCENT, 0.35)))
	var arm := 0.06
	for i in 4:
		var here: Vector3 = c[i]
		for other in [c[(i + 1) % 4], c[(i + 3) % 4]]:
			_frame.add_child(_bar(here, here + ((other as Vector3) - here).normalized() * arm, 0.008, HHStyle.ACCENT))
	var mid: Vector3 = to_you.call(Vector2(0.5, 0.5))
	var r: Vector3 = (c[1] - c[0]).normalized() * 0.025
	var u: Vector3 = (c[0] - c[3]).normalized() * 0.025
	_frame.add_child(_bar(mid - r, mid + r, 0.004, Color(HHStyle.ACCENT, 0.7)))
	_frame.add_child(_bar(mid - u, mid + u, 0.004, Color(HHStyle.ACCENT, 0.7)))
	var label := _label(Color(HHStyle.ACCENT, 0.8))
	label.text = "PLAYER'S SCREEN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = c[0] + u * 1.2
	label.offset = Vector2(150, 0)
	_frame.add_child(label)


static func _label(col: Color) -> Label3D:
	var l := Label3D.new()
	l.font = HHStyle.bold()
	l.font_size = 36
	l.pixel_size = 0.0005
	l.modulate = col
	l.outline_size = 0
	l.no_depth_test = true
	l.layers = 2
	return l


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _polygon(pts: Array[Vector3]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.add_vertex(p)
	return st.commit()


## A thin bar from a to b (lines that still read in a headset).
static func _bar(a: Vector3, b: Vector3, thick: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thick, thick, maxf(a.distance_to(b), 0.001))
	m.mesh = box
	m.material_override = _mat(col)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.layers = 2  # (the room only: the player's view draws its own)
	var mid := (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(b - a, up), mid)
	return m


static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
