class_name StyleManager
extends Node
## The game's look, in three layers:
##   world   the thermal grade, drawn on a canvas layer *under* the 2D play field, so it
##           only sees the 3D room and enemy. Items, the hand and attack zones keep their
##           true colours on top.
##   grain   a light flickering grain over everything, tying the play field to the room.
##   dark    a stage modifier (off by default): only a pool of light around the hand;
##           danger, fire and gold still glow on their own. F4 toggles it for previewing.

const WORLD_SHADER := "res://shaders/thermal.gdshader"
const GRAIN_SHADER := "res://shaders/grain.gdshader"
const DARK_SHADER := "res://shaders/candle.gdshader"
# How much of the room's and the enemy's own colour survives the world grade. The grade used
# to replace every colour with the setting's ramp, which turned each character the same
# orange or green; this lets the modelled bodies keep their palettes. A setting's look can
# override it with its own "keep".
const KEEP_COLOUR := 0.35

const NORMAL_ENV := {"bg": Color(0, 0, 0), "ambient": 0.4, "fog": 0.0, "fog_color": Color(0, 0, 0),
	"light": Color(1, 0.9, 0.8), "energy": 1.0}
const DARK_ENV := {"bg": Color(0, 0, 0), "ambient": 0.15, "fog": 0.5, "fog_color": Color(0.01, 0.005, 0.0),
	"light": Color(1.0, 0.55, 0.25), "energy": 1.8}

var dark := false
var _base := NORMAL_ENV.duplicate()  # the current setting's fog and ambient light
var _game: Node
var _dark_rect: ColorRect
var _world_rect: ColorRect


func setup(game: Node) -> void:
	_game = game
	_world_rect = _layer_with(-1, WORLD_SHADER)
	_layer_with(100, GRAIN_SHADER)
	_dark_rect = _layer_with(101, DARK_SHADER)
	set_dark(false)


func _layer_with(layer_index: int, shader_path: String) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	rect.material = mat
	layer.add_child(rect)
	return rect


## A setting's colour palette and texture for the world grade.
func set_world_look(look: Dictionary) -> void:
	var mat := _world_rect.material as ShaderMaterial
	var stops: Array = look.c
	for i in 5:
		var col: Color = stops[i]
		mat.set_shader_parameter("c%d" % i, Vector3(col.r, col.g, col.b))
	for k in ["pixel", "noise", "gamma", "contrast"]:
		mat.set_shader_parameter(k, look[k])
	mat.set_shader_parameter("keep", look.get("keep", KEEP_COLOUR))


## A setting's own fog and ambient light (used whenever it isn't a dark stage).
func set_base_env(e: Dictionary) -> void:
	for k in e:
		_base[k] = e[k]
	set_dark(dark)


func set_dark(on: bool) -> void:
	dark = on
	_dark_rect.visible = on
	var e: Dictionary = DARK_ENV if on else _base
	var env: Environment = _game.env
	env.background_color = e.bg
	env.ambient_light_energy = e.ambient
	env.fog_enabled = e.fog > 0.0
	env.fog_density = e.fog
	env.fog_light_color = e.fog_color
	var torch: OmniLight3D = _game.torch
	torch.light_color = e.light
	torch.light_energy = e.energy


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F4:
		set_dark(not dark)


func _process(_delta: float) -> void:
	if dark and is_inside_tree():
		var hand: Node2D = _game.hand
		var mat := _dark_rect.material as ShaderMaterial
		mat.set_shader_parameter("hand_uv", hand.position / Vector2(1280, 720))
		var lamp := Vector2(-10, -10)
		for n in get_tree().get_nodes_in_group("items"):
			var it := n as Item
			if it and it.def.get("utility", "") == "lantern" and not it.is_queued_for_deletion():
				lamp = it.global_position / Vector2(1280, 720)
				break
		mat.set_shader_parameter("lamp_uv", lamp)
