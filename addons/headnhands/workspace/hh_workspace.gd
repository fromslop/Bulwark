## The windows round you in the headset, and how you work them.
##
##   point     a laser from your right hand's aim (not the grip you perform with), shown
##             only when it's over a window, so it never clutters the stage
##   trigger   click
##   grip      grab the window you're pointing at: it follows your hand, and turns to
##             face you when you let go
##   stick     scroll the list you're pointing at
##
## At the desk (no headset) the mouse does the same: point, left click, wheel to scroll,
## right-drag a window's title strip to move it, and middle-drag to look round.
##
## None of it works while a take is recording or counting down (can_point() says so):
## the triggers and grips are part of the performance then, and the laser hides.
## Window positions are remembered between sessions (user://headnhands_workspace.cfg).
class_name HHWorkspace
extends Node3D

const SAVE := "user://headnhands_workspace.cfg"
const REACH := 6.0  # metres the laser reaches

## Returns false while the pointer must stay out of the way (recording).
var can_point: Callable = func() -> bool: return true
var head: Node3D      # the camera: windows face it
var aim: XRController3D  # the hand that points (its "aim" pose)
var desk_camera: Camera3D  # at the desk, when there's no headset

var panels: Array[HHPanel] = []
var _hover: HHPanel
var _hover_px := Vector2(-1, -1)
var _held: HHPanel
var _held_offset := Transform3D()
var _held_by_mouse := false
var _held_mouse_depth := 0.0
var _trigger_down := false
var _grip_down := false
var _scroll_ready := true
var _beam: MeshInstance3D
var _dot: MeshInstance3D
var _looking := false


func _ready() -> void:
	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.0035, 0.0035, 1.0)
	_beam.mesh = bm
	_beam.material_override = _glow_mat(Color(HHStyle.ACCENT, 0.55))
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_dot = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.008
	dm.height = 0.016
	_dot.mesh = dm
	_dot.material_override = _glow_mat(HHStyle.ACCENT)
	add_child(_dot)
	_beam.visible = false
	_dot.visible = false


func add_panel(p: HHPanel, at: Transform3D) -> HHPanel:
	panels.append(p)
	add_child(p)
	p.global_transform = at
	_restore(p)
	return p


## Where a window goes by default: on an arc round the performer, `yaw_deg` from straight
## ahead (left is +), at eye level plus `rise`, `dist` metres away, turned to face them.
static func arc(yaw_deg: float, dist := 1.15, rise := -0.15, eye := 1.65) -> Transform3D:
	var a := deg_to_rad(yaw_deg)
	var pos := Vector3(-sin(a) * dist, eye + rise, -cos(a) * dist)
	var t := Transform3D(Basis(Vector3.UP, a), pos)
	return t.rotated_local(Vector3.RIGHT, deg_to_rad(-8.0) if rise < 0.0 else 0.0)


func _process(_delta: float) -> void:
	var allowed: bool = can_point.call()
	var ray := _ray()
	if not allowed or ray.is_empty():
		_set_hover(null, Vector2(-1, -1))
		_beam.visible = false
		_dot.visible = false
		if _held and not _held_by_mouse:
			_release()
		return
	var origin: Vector3 = ray.origin
	var dir: Vector3 = ray.dir
	if _held and not _held_by_mouse and aim:
		_held.global_transform = aim.global_transform * _held_offset
	# what's under the pointer
	var best: Dictionary = {}
	var best_panel: HHPanel = null
	for p in panels:
		var h := p.hit(origin, dir)
		if not h.is_empty() and (best.is_empty() or h.t < best.t):
			best = h
			best_panel = p
	_set_hover(best_panel, best.get("px", Vector2(-1, -1)))
	if aim:
		_show_beam(origin, best.get("point", Vector3.ZERO), best_panel != null or _held != null)
		_hand_buttons(best_panel, best)


func _ray() -> Dictionary:
	if aim and aim.get_has_tracking_data():
		return {"origin": aim.global_position, "dir": -aim.global_basis.z}
	if desk_camera:
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		return {"origin": desk_camera.project_ray_origin(m), "dir": desk_camera.project_ray_normal(m)}
	return {}


func _set_hover(p: HHPanel, px: Vector2) -> void:
	if _hover and _hover != p:
		_hover.pointer_move(Vector2(-1, -1))
		_hover.set_lit(false)
	_hover = p
	_hover_px = px
	if p:
		p.pointer_move(px)
		p.set_lit(true)


func _hand_buttons(p: HHPanel, h: Dictionary) -> void:
	var trig := aim.get_float("trigger")
	if not _trigger_down and trig > 0.65:
		_trigger_down = true
		if p:
			p.pointer_button(h.px, true)
	elif _trigger_down and trig < 0.35:
		_trigger_down = false
		if p:
			p.pointer_button(h.px, false)
	var grip := aim.get_float("grip")
	if not _grip_down and grip > 0.7:
		_grip_down = true
		if p:
			_held = p
			_held_by_mouse = false
			_held_offset = aim.global_transform.affine_inverse() * p.global_transform
			p.grabbed.emit()
	elif _grip_down and grip < 0.4:
		_grip_down = false
		if _held:
			_release()
	var stick := aim.get_vector2("primary")
	if p and absf(stick.y) > 0.25:
		p.pointer_scroll(h.px, -stick.y * 0.6)


func _release() -> void:
	var p := _held
	_held = null
	if p == null:
		return
	_face(p)
	_remember(p)
	p.released.emit()


## Turn a window upright and towards the head (yaw only, with a slight tilt back if it's
## below eye level), keeping where it is.
func _face(p: HHPanel) -> void:
	var eye: Vector3 = head.global_position if head else Vector3(0, 1.65, 0)
	var to := eye - p.global_position
	var yaw := atan2(to.x, to.z)
	var below := clampf((eye.y - p.global_position.y) / maxf(Vector2(to.x, to.z).length(), 0.1), -0.6, 0.6)
	p.global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -atan(below) * 0.8)


func _unhandled_input(e: InputEvent) -> void:
	if desk_camera == null or (aim and aim.get_has_tracking_data()):
		return
	if not can_point.call():
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_looking = mb.pressed
			return
		if _hover:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					_hover.pointer_button(_hover_px, mb.pressed)
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					if mb.pressed:
						_hover.pointer_scroll(_hover_px, 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0)
				MOUSE_BUTTON_RIGHT:
					if mb.pressed:
						_held = _hover
						_held_by_mouse = true
						_held_mouse_depth = desk_camera.global_position.distance_to(_hover.global_position)
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and _held_by_mouse:
			_release()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _looking:
			desk_camera.rotate_y(-mm.relative.x * 0.004)
			desk_camera.rotate_object_local(Vector3.RIGHT, -mm.relative.y * 0.004)
		elif _held and _held_by_mouse:
			var m := get_viewport().get_mouse_position()
			_held.global_position = desk_camera.project_ray_origin(m) + desk_camera.project_ray_normal(m) * _held_mouse_depth


func _show_beam(from: Vector3, to: Vector3, on: bool) -> void:
	_beam.visible = on
	_dot.visible = on and to != Vector3.ZERO
	if not on:
		return
	if to == Vector3.ZERO:
		to = from + (-aim.global_basis.z) * 0.6
	var mid := (from + to) * 0.5
	var len := from.distance_to(to)
	_beam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), mid).scaled_local(Vector3(1, 1, len))
	_dot.global_position = to


static func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if col.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.no_depth_test = true
	m.render_priority = 2
	return m


# --- remembering where you put things ------------------------------------------

func _remember(p: HHPanel) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("panels", p.name, p.global_transform)
	cfg.save(SAVE)


func _restore(p: HHPanel) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK and cfg.has_section_key("panels", p.name):
		p.global_transform = cfg.get_value("panels", p.name)


## Put every window back where it starts (forgets where you moved them).
func reset_layout(defaults: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.save(SAVE)
	for p in panels:
		if defaults.has(p.name):
			p.global_transform = defaults[p.name]
