## The player's view: what the game's camera sees of you-as-the-foe, live, with the picked
## attack's field drawn over it exactly as the game draws it, and the path the foe's weapon
## hand is taking across the player's screen (a cyan trail): the same hand the frame in
## front of you maps, so the two always agree. If the blow reads here, it reads in the game.
##
## During an attack take the field fills as the wind-up builds and flashes at the strike,
## the way the game telegraphs it.
##
## Two of these hang in the studio: PLAYER'S VIEW to the right (with the attack's notes)
## and AIM, front and centre above the foe, to swing by. AIM shows PLAYER'S VIEW's picture
## (one render, two windows).
class_name StudioPlayerView
extends HHPanel

const RES := Vector2i(1280, 720)  # the game's own screen
const TRAIL_SECONDS := 0.9

var studio
var source: StudioPlayerView  # the view whose camera this one shows (null: its own)
var cam_vp: SubViewport
var cam: Camera3D
var _screen: TextureRect
var _overlay: Control
var _name: Label
var _notes: Label
var _zone: PackedVector2Array
var _dir := Vector2.ZERO
var _trail: Array = []  # [seconds, Vector2 0..1 on the player's screen]


func _init(p_studio, p_title := "Player's view", p_size := Vector2(0.66, 0.445), p_source: StudioPlayerView = null) -> void:
	super._init(p_title, p_size)
	studio = p_studio
	source = p_source
	if source == null:
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
	var inner := p_size.x * HHStyle.PX_PER_M - HHStyle.PAD * 2.0 - 4.0
	_screen.custom_minimum_size = Vector2(0, inner * 9.0 / 16.0)  # 16:9 across the panel
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
	_screen.texture = (source.cam_vp if source else cam_vp).get_texture()


func the_camera() -> Camera3D:
	return source.cam if source else cam


func _process(_d: float) -> void:
	var model: Enemy = studio.stage_model()
	if source == null:
		cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if model and visible else SubViewport.UPDATE_DISABLED
		if model:
			cam.global_transform = model.global_transform * Transform3D(Basis(), model.cam_rel())
	# the weapon tip's path across the player's screen
	var now := Time.get_ticks_msec() / 1000.0
	if model and visible:
		var c := the_camera()
		var tip: Vector3 = studio.weapon_tip()
		if not c.is_position_behind(tip):
			_trail.append([now, c.unproject_position(tip) / Vector2(RES / 2)])
	while not _trail.is_empty() and now - float(_trail[0][0]) > TRAIL_SECONDS:
		_trail.pop_front()
	_overlay.queue_redraw()


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
	set_subtitle("GAME CAMERA  ·  40°  ·  WEAPON TIP")
	_overlay.queue_redraw()


## How strongly the field shows: faint at rest, building through a take's wind-up like
## the game's telegraph, a flash at the strike.
func _field_alpha() -> float:
	var g: StudioGuide = studio.guide
	if g == null or not studio.is_recording():
		return 0.2
	var t: float = studio.recording_time()
	for s in ([g.strike_at(), g.strike2_at()] if g.is_combo() else [g.strike_at()]):
		if t >= s and t - s < 0.2:
			return 0.75
	match g.phase(t):
		"windup", "windup2":
			return 0.15 + 0.4 * g.progress(t)
	return 0.12


func _draw_field() -> void:
	var sz := _overlay.size
	# the game's frame: thirds, faintly, so placement reads
	for k in [1, 2]:
		_overlay.draw_line(Vector2(sz.x * k / 3.0, 0), Vector2(sz.x * k / 3.0, sz.y), Color(1, 1, 1, 0.05), 2.0)
		_overlay.draw_line(Vector2(0, sz.y * k / 3.0), Vector2(sz.x, sz.y * k / 3.0), Color(1, 1, 1, 0.05), 2.0)
	if _zone.size() >= 3:
		var pts := PackedVector2Array()
		for p in _zone:
			pts.append(p * sz)
		_overlay.draw_colored_polygon(pts, Color(HHStyle.FIELD, _field_alpha()))
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
	# the weapon tip's trail: fading behind it, a bright dot where it is now
	if _trail.size() >= 2:
		var now := Time.get_ticks_msec() / 1000.0
		for i in range(1, _trail.size()):
			var a: float = 1.0 - (now - float(_trail[i][0])) / TRAIL_SECONDS
			_overlay.draw_line((_trail[i - 1][1] as Vector2) * sz, (_trail[i][1] as Vector2) * sz, Color(HHStyle.ACCENT, a * 0.9), 2.0 + 6.0 * a, true)
		var head: Vector2 = (_trail.back()[1] as Vector2) * sz
		_overlay.draw_circle(head, 11.0, Color(HHStyle.ACCENT, 0.35))
		_overlay.draw_circle(head, 6.0, HHStyle.TEXT)
