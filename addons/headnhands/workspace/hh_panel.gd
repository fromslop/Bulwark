## A window in the headset: an ordinary Godot UI (Controls) drawn into a SubViewport and
## shown on a pane of dark glass in the room. The workspace points at it, clicks it,
## scrolls it and lets you grab it and put it somewhere else.
##
## Build a panel's contents under `body` (a VBoxContainer below the title strip). Size is
## in metres; the UI is laid out in pixels at HHStyle.PX_PER_M.
class_name HHPanel
extends Node3D

signal grabbed
signal released

@export var title := "Panel"
@export var size_m := Vector2(0.7, 0.5)

var viewport: SubViewport
var frame: PanelContainer   # the glass
var header: HBoxContainer   # the title strip
var title_label: Label
var subtitle_label: Label
var body: VBoxContainer     # put the panel's contents here
var quad: MeshInstance3D
var hovered := false
var _hover_px := Vector2(-1, -1)
var _mat: StandardMaterial3D


func _init(p_title := "Panel", p_size := Vector2(0.7, 0.5)) -> void:
	title = p_title
	size_m = p_size
	name = p_title.to_pascal_case().validate_node_name()
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(roundi(size_m.x * HHStyle.PX_PER_M), roundi(size_m.y * HHStyle.PX_PER_M))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	viewport.msaa_2d = Viewport.MSAA_4X
	add_child(viewport)
	frame = PanelContainer.new()
	frame.theme = HHStyle.theme()
	frame.add_theme_stylebox_override("panel", HHStyle.glass())
	viewport.add_child(frame)
	# (sized outright, not anchored: anchored to a SubViewport it took the window's stretch
	# and came out twice the size of the glass)
	frame.position = Vector2.ZERO
	frame.size = Vector2(viewport.size)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	# the title strip: what this window is, and a quiet line of status on the right
	var strip := PanelContainer.new()
	var hs := HHStyle.fill(HHStyle.HEADER, HHStyle.RADIUS)
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	hs.content_margin_left = HHStyle.PAD
	hs.content_margin_right = HHStyle.PAD
	hs.content_margin_top = 14
	hs.content_margin_bottom = 14
	strip.add_theme_stylebox_override("panel", hs)
	outer.add_child(strip)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	strip.add_child(header)
	var tick := ColorRect.new()  # the accent tick before the title
	tick.color = HHStyle.ACCENT
	tick.custom_minimum_size = Vector2(6, 30)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tick)
	title_label = HHStyle.label(title.to_upper(), HHStyle.SIZE_SMALL + 2, HHStyle.TEXT_DIM, HHStyle.bold())
	header.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	subtitle_label = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.mono())
	header.add_child(subtitle_label)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, HHStyle.PAD)
	outer.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	# the glass in the room
	quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size_m
	quad.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat.render_priority = 1
	_mat.no_depth_test = false
	quad.material_override = _mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


func _ready() -> void:
	_mat.albedo_texture = viewport.get_texture()


## The quiet status line in the title strip.
func set_subtitle(text: String) -> void:
	subtitle_label.text = text


## Where a ray meets this panel: {"t": distance, "px": pixel in the panel} or {}.
func hit(origin: Vector3, dir: Vector3) -> Dictionary:
	if not visible:
		return {}
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 0.00001:
		return {}
	var t := -o.z / d.z
	if t <= 0.0:
		return {}
	var p := o + d * t
	var half := size_m * 0.5
	if absf(p.x) > half.x or absf(p.y) > half.y:
		return {}
	var px := Vector2((p.x + half.x) / size_m.x, (half.y - p.y) / size_m.y) * Vector2(viewport.size)
	var world := global_transform * p
	return {"t": origin.distance_to(world), "px": px, "point": world}


## The pointer moved over (or off: px < 0) the panel.
func pointer_move(px: Vector2) -> void:
	hovered = px.x >= 0.0
	if px == _hover_px:
		return
	_hover_px = px
	var e := InputEventMouseMotion.new()
	e.position = px if hovered else Vector2(-1000, -1000)
	e.global_position = e.position
	viewport.push_input(e)


func pointer_button(px: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = px
	e.global_position = px
	viewport.push_input(e)


## Scroll a list under the pointer (stick or wheel): + is down.
func pointer_scroll(px: Vector2, amount: float) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if amount > 0.0 else MOUSE_BUTTON_WHEEL_UP
	e.factor = absf(amount)
	e.pressed = true
	e.position = px
	e.global_position = px
	viewport.push_input(e)


## A little brighter while it's being pointed at or held.
func set_lit(on: bool) -> void:
	_mat.albedo_color = Color(1.08, 1.08, 1.08) if on else Color.WHITE
