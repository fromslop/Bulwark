class_name Scrying
extends Node2D
## The shop gong's face shows what waits beyond it. The next fight is rolled when the shop
## opens (main._plan_fight); this renders that arena and its foe, live and idling, into a
## small off-screen view, and paints it onto the gong through shaders/gong_face.gdshader:
## mirrored, bulged, rippling, graded through the next setting's colours, washed in bronze.
## Faint until the hand leans in. A boss makes the gong tremble; a secret place gives the
## face a slow gold sweep. No words: it's for those who look.

const SIZE := 192
const NEAR := 70.0  # hand this close: as clear as it gets
const FAR := 300.0  # and from this far: barely there
const FAINT := 0.16
const CLEAR := 0.85

var game: Node
var boss := false
var secret := false
var _view: SubViewport
var _face: Sprite2D
var _reveal := FAINT
var _foes: Array = []


func setup(g: Node, plan: Dictionary) -> void:
	game = g
	z_index = 2
	_view = SubViewport.new()
	_view.size = Vector2i(SIZE, SIZE)
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_view)
	var place: String = plan.place
	var env := Environment.new()
	var e: Dictionary = Backdrop.ENV.get(place, {"fog": 0.15, "fog_color": Color(0.02, 0.02, 0.02), "ambient": 0.4})
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = float(e.ambient) + 0.15
	env.fog_enabled = float(e.fog) > 0.0
	env.fog_light_color = e.fog_color
	env.fog_density = float(e.fog) * 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 50.0  # wide enough for the whole figure, standing in its place
	cam.position = Vector3(0, 1.35, 3.1)
	cam.rotation = Vector3(-0.04, 0, 0)
	_view.add_child(cam)
	var lamp := OmniLight3D.new()  # the light you'd bring: so even a dark place shows something
	lamp.position = Vector3(0.6, 2.0, 1.2)
	lamp.light_color = Color(1.0, 0.75, 0.5)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	_view.add_child(lamp)
	_view.add_child(Backdrop.create(place))
	var defs: Array = plan.defs
	for i in defs.size():
		var foe := Enemy.new()
		foe.setup((defs[i] as Dictionary).duplicate(true), cam)
		foe.active = false
		if defs.size() > 1:
			foe.position.x = -0.6 + 1.2 * i
			foe.scale = Vector3.ONE * 0.9
		_view.add_child(foe)
		_foes.append(foe)
		boss = boss or defs[i].get("boss", false)
	secret = plan.vault or plan.hidden != ""
	_face = Sprite2D.new()
	_face.texture = _view.get_texture()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/gong_face.gdshader")
	var look: Dictionary = Backdrop.LOOK.get(place, Backdrop.LOOK["Dungeon Cell"])
	for k in 5:
		mat.set_shader_parameter("c%d" % k, look.c[k])
	mat.set_shader_parameter("shimmer", 1.0 if secret else 0.0)
	_face.material = mat
	add_child(_face)
	_place_face()


func _place_face() -> void:
	var g: Dictionary = game.overlay.gong
	if g.is_empty():
		visible = false
		return
	visible = true
	_face.position = game.overlay.gong_center()
	var face_d: float = float(g.radius) * 2.0 * 0.86  # inside the rim
	_face.scale = Vector2.ONE * face_d / SIZE


func _process(delta: float) -> void:
	if game == null:
		return
	game.overlay.gong_tremble = 1.2 if boss else 0.0
	_place_face()
	var d: float = game.hand.position.distance_to(_face.position)
	var want := lerpf(CLEAR, FAINT, clampf((d - NEAR) / (FAR - NEAR), 0.0, 1.0))
	_reveal = move_toward(_reveal, want, delta * 1.5)
	var mat := _face.material as ShaderMaterial
	mat.set_shader_parameter("reveal", _reveal)
	mat.set_shader_parameter("ripple", game.overlay._gong_swing)


func _exit_tree() -> void:
	if game and is_instance_valid(game.overlay):
		game.overlay.gong_tremble = 0.0
