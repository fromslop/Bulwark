## The player's view: what the game's camera sees of you-as-the-foe, live, with the picked
## attack's field drawn over it exactly as the game draws it. If the blow reads here, it
## reads in the game.
class_name StudioPlayerView
extends HHPanel

const RES := Vector2i(1280, 720)  # the game's own screen

var studio
var cam_vp: SubViewport
var cam: Camera3D
var _screen: TextureRect
var _overlay: Control
var _name: Label
var _notes: Label
var _zone: PackedVector2Array
var _dir := Vector2.ZERO


func _init(p_studio) -> void:
	super._init("Player's view", Vector2(0.66, 0.445))
	studio = p_studio
	cam_vp = SubViewport.new()
	cam_vp.size = RES / 2
	cam_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(cam_vp)
	cam = Camera3D.new()
	cam.fov = StudioField.CAM_FOV
	cam.cull_mask = 1  # (the stage's own field is on layer 2: the overlay draws it here)
	cam_vp.add_child(cam)
	var frame_box := PanelContainer.new()
	frame_box.add_theme_stylebox_override("panel", HHStyle.fill(Color(0, 0, 0, 0.6), 10, Color(1, 1, 1, 0.1)))
	body.add_child(frame_box)
	_screen = TextureRect.new()
	_screen.custom_minimum_size = Vector2(0, 557)  # 16:9 across the panel
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	frame_box.add_child(_screen)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_field)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_overlay)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	body.add_child(line)
	_name = HHStyle.label("", HHStyle.SIZE_BODY, HHStyle.FIELD, HHStyle.bold())
	line.add_child(_name)
	_notes = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_DIM)
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_notes.clip_text = true
	line.add_child(_notes)


func _ready() -> void:
	super._ready()
	_screen.texture = cam_vp.get_texture()


func _process(_d: float) -> void:
	var model: Enemy = studio.stage_model()
	cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if model and visible else SubViewport.UPDATE_DISABLED
	if model:
		cam.global_transform = model.global_transform * Transform3D(Basis(), StudioField.CAM)


func refresh() -> void:
	var cue: Dictionary = studio.current_cue()
	var atk: Dictionary = studio.cue_attack(cue)
	_zone = PackedVector2Array(atk.get("zone", []))
	_dir = atk.get("dir", Vector2.ZERO)
	if atk.is_empty():
		_name.text = "No field"
		_name.add_theme_color_override("font_color", HHStyle.TEXT_DIM)
		_notes.text = "the picked clip isn't an attack" if not cue.is_empty() else ""
	else:
		_name.text = StudioSlate.clip_title(cue)
		_name.add_theme_color_override("font_color", HHStyle.FIELD)
		var notes: Array = ["%.2f s wind-up" % float(cue.windup)]
		if atk.get("track", false):
			notes.append("aimed at the player's hand")
		if atk.has("chase"):
			notes.append("follows the hand %d%% of the way" % roundi(float(atk.chase) * 100.0))
		if atk.has("pan"):
			notes.append("the blade travels")
		if atk.has("turn"):
			notes.append("its line turns")
		if atk.has("trait"):
			notes.append(str(atk.trait))
		_notes.text = "   ·   ".join(PackedStringArray(notes))
	set_subtitle("GAME CAMERA  ·  40°")
	_overlay.queue_redraw()


func _draw_field() -> void:
	var sz := _overlay.size
	# the game's frame: thirds, faintly, so placement reads
	for k in [1, 2]:
		_overlay.draw_line(Vector2(sz.x * k / 3.0, 0), Vector2(sz.x * k / 3.0, sz.y), Color(1, 1, 1, 0.05), 2.0)
		_overlay.draw_line(Vector2(0, sz.y * k / 3.0), Vector2(sz.x, sz.y * k / 3.0), Color(1, 1, 1, 0.05), 2.0)
	if _zone.size() < 3:
		return
	var pts := PackedVector2Array()
	for p in _zone:
		pts.append(p * sz)
	_overlay.draw_colored_polygon(pts, Color(HHStyle.FIELD, 0.2))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_overlay.draw_polyline(loop, HHStyle.FIELD, 4.0, true)
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	if _dir.length() < 0.01:
		_overlay.draw_arc(c, 22.0, 0.0, TAU, 32, HHStyle.FIELD, 4.0, true)
		_overlay.draw_circle(c, 5.0, HHStyle.FIELD)
	else:
		var d := _dir.normalized()
		var s := Vector2(-d.y, d.x)
		for k in 3:
			var tip := c + d * (-40.0 + k * 40.0)
			_overlay.draw_polyline(PackedVector2Array([tip - d * 16.0 + s * 14.0, tip, tip - d * 16.0 - s * 14.0]), HHStyle.FIELD, 5.0, true)
