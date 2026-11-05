## The picked attack's field, standing in the room in front of the character: the patch of
## the player's screen the blow sweeps, put back into 3D where the game's camera sees it,
## on a plane just in front of the foe (where its hands meet the pile). Chevrons show the
## way the blade travels; a ring means it's thrust straight out (or aimed at the hand).
## Swing through it and the clip will read right in the game.
class_name StudioField
extends Node3D

## The game's camera, relative to the foe (main.gd: framed waist-up). Zones are fractions
## of what it sees.
const CAM := Vector3(0.0, 1.45, 1.5)
const CAM_FOV := 40.0  # vertical
const ASPECT := 16.0 / 9.0
## How far in front of the foe the field stands, in metres (its blows land about here).
const DEPTH := 0.5

var _fill: MeshInstance3D
var _edges: Node3D
var _arrows: Node3D
var _caption: Label3D


func _init() -> void:
	name = "Field"
	_fill = MeshInstance3D.new()
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.layers = 2
	add_child(_fill)
	_edges = Node3D.new()
	add_child(_edges)
	_arrows = Node3D.new()
	add_child(_arrows)
	_caption = Label3D.new()
	_caption.font = HHStyle.bold()
	_caption.font_size = 48
	_caption.pixel_size = 0.0009
	_caption.modulate = HHStyle.FIELD
	_caption.outline_size = 0
	_caption.no_depth_test = true
	_caption.layers = 2
	add_child(_caption)
	visible = false


## Where a point of the player's screen (0..1 each way) lands on the field's plane, in the
## foe's own space.
static func zone_point(p: Vector2, depth := DEPTH) -> Vector3:
	var ty := tan(deg_to_rad(CAM_FOV * 0.5))
	var ndc := Vector2(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0)
	var d := CAM.z - depth
	return Vector3(ndc.x * ty * ASPECT * d, CAM.y + ndc.y * ty * d, depth)


## Sits on the stage foe (it's in the foe's space).
func follow(studio) -> void:
	var model: Enemy = studio.stage_model()
	if model == null:
		visible = false
		return
	global_transform = model.global_transform
	# fainter while you perform: a guide, not a wall
	var a := 0.55 if studio.is_recording() else 1.0
	_fill.transparency = 1.0 - a
	for n in _edges.get_children():
		(n as GeometryInstance3D).transparency = 1.0 - a


func show_cue(studio, cue: Dictionary) -> void:
	var atk: Dictionary = studio.cue_attack(cue)
	visible = not atk.is_empty() and studio.stage_model() != null
	if not visible:
		return
	var pts: Array[Vector3] = []
	for p in atk.zone:
		pts.append(zone_point(p))
	_fill.mesh = _polygon(pts)
	_fill.material_override = _mat(Color(HHStyle.FIELD, 0.16))
	for n in _edges.get_children():
		n.queue_free()
	for i in pts.size():
		_edges.add_child(_bar(pts[i], pts[(i + 1) % pts.size()], 0.006, Color(HHStyle.FIELD, 0.9)))
	for n in _arrows.get_children():
		n.queue_free()
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var dir := Vector3(atk.dir.x, -atk.dir.y, 0.0)
	if dir.length() < 0.01:
		# thrust or aimed: a ring on the target
		for k in 16:
			var a0 := k * TAU / 16.0
			var a1 := (k + 1) * TAU / 16.0
			_arrows.add_child(_bar(centre + Vector3(cos(a0), sin(a0), 0) * 0.06, centre + Vector3(cos(a1), sin(a1), 0) * 0.06, 0.008, HHStyle.FIELD))
	else:
		dir = dir.normalized()
		var side := Vector3(-dir.y, dir.x, 0.0)
		for k in 3:
			var tip := centre + dir * (-0.12 + k * 0.12)
			_arrows.add_child(_bar(tip, tip - dir * 0.05 + side * 0.04, 0.008, HHStyle.FIELD))
			_arrows.add_child(_bar(tip, tip - dir * 0.05 - side * 0.04, 0.008, HHStyle.FIELD))
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
	_caption.position = Vector3(centre.x, maxf(top.y, centre.y) + 0.05, DEPTH)


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
	m.layers = 2  # (on the stage only: the player's view draws its own)
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
