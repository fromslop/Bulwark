class_name PauseMenu
extends CanvasLayer
## Esc pauses and shows Resume / Settings / Restart run / Quit. R restarts the run at any time;
## F11 toggles fullscreen. Sits above the presentation-style layer so it stays crisp in every
## style. The settings page applies and saves each change as it's made.

var _panel: Control
var _main: Control
var _settings: Control
var _controls: Control
var _refresh: Array[Callable] = []  # re-read each control's value when the page opens


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(540, 220)
	box.size = Vector2(200, 280)
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_main = box
	for entry in [["Resume", _resume], ["Settings", _open_settings], ["Controls", _open_controls], ["Restart run", _restart], ["Reset save", _reset_save], ["Quit", _quit]]:
		var b := _button(entry[0], entry[1])
		if entry[0] == "Reset save":
			_reset_button = b
		box.add_child(b)
	_build_settings()
	_build_controls()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _build_settings() -> void:
	var frame := PanelContainer.new()
	frame.position = Vector2(370, 70)
	frame.custom_minimum_size = Vector2(540, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.95)
	sb.border_color = Color(0.45, 0.38, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", sb)
	frame.visible = false
	_panel.add_child(frame)
	_settings = frame
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	frame.add_child(col)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	_heading(grid, "Display")
	_toggle(grid, "Fullscreen (F11)", func() -> bool: return Settings.fullscreen,
		func(v: bool) -> void: Settings.fullscreen = v; Settings.apply_display())
	_toggle(grid, "VSync", func() -> bool: return Settings.vsync,
		func(v: bool) -> void: Settings.vsync = v; Settings.apply_display())
	var caps: Array = Settings.FPS_CAPS.map(func(c: int) -> String: return "Unlimited" if c == 0 else str(c))
	_choice(grid, "Frame rate cap", caps, func() -> int: return maxi(0, Settings.FPS_CAPS.find(Settings.fps_cap)),
		func(i: int) -> void: Settings.fps_cap = Settings.FPS_CAPS[i]; Settings.apply_display())

	_heading(grid, "Audio")
	_slider(grid, "Master volume", func() -> float: return Settings.master,
		func(v: float) -> void: Settings.master = v; Settings.apply_audio())
	_slider(grid, "Music", func() -> float: return Settings.music,
		func(v: float) -> void: Settings.music = v; Settings.apply_audio())
	_slider(grid, "Effects", func() -> float: return Settings.sfx,
		func(v: float) -> void: Settings.sfx = v; Settings.apply_audio(); Sfx.play("ting", -6.0))
	_toggle(grid, "Mute when in background", func() -> bool: return Settings.mute_unfocused,
		func(v: bool) -> void: Settings.mute_unfocused = v)

	_heading(grid, "Gameplay")
	_slider(grid, "Screen shake", func() -> float: return Settings.shake,
		func(v: float) -> void: Settings.shake = v)
	_toggle(grid, "Damage numbers", func() -> bool: return Settings.damage_numbers,
		func(v: bool) -> void: Settings.damage_numbers = v)
	_toggle(grid, "Inspecting (Alt) pauses", func() -> bool: return Settings.inspect_pauses,
		func(v: bool) -> void: Settings.inspect_pauses = v)

	var back := _button("Back", _close_settings)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)


const CONTROLS := [
	["Left mouse", "grab and hold (let go to drop); grab shop stock to buy it"],
	["Space", "use what you hold: swing a weapon, brace a shield, open a menu, smash a potion; punch with an empty hand"],
	["Right mouse / 1-5", "use your rings"],
	["Q / E", "rotate what you hold (turn the index's pages)"],
	["Alt (hold)", "inspect: the item, foe, prop or stat under the hand (pauses the game)"],
	["Enter", "at home, name the thing you hold"],
	["Esc", "pause"],
	["R", "restart the run"],
	["F11", "fullscreen"],
]


func _build_controls() -> void:
	var frame := PanelContainer.new()
	frame.position = Vector2(290, 120)
	frame.custom_minimum_size = Vector2(700, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.95)
	sb.border_color = Color(0.45, 0.38, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", sb)
	frame.visible = false
	_panel.add_child(frame)
	_controls = frame
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	frame.add_child(col)
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for row in CONTROLS:
		_label(grid, row[0], 17, Color(0.95, 0.7, 0.35))
		var l := Label.new()
		l.text = row[1]
		l.add_theme_font_size_override("font_size", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		grid.add_child(l)
	var back := _button("Back", _close_controls)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)


func _open_controls() -> void:
	_main.visible = false
	_controls.visible = true


func _close_controls() -> void:
	_controls.visible = false
	_main.visible = true


func _label(grid: GridContainer, text: String, size: int = 17, color: Color = Color(0.9, 0.86, 0.8)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(220, 0)
	grid.add_child(l)


func _heading(grid: GridContainer, text: String) -> void:
	_label(grid, text, 19, Color(0.95, 0.7, 0.35))
	grid.add_child(Control.new())


func _toggle(grid: GridContainer, text: String, get_v: Callable, set_v: Callable) -> void:
	_label(grid, text)
	var c := CheckButton.new()
	c.toggled.connect(func(v: bool) -> void: set_v.call(v); Settings.save_file())
	grid.add_child(c)
	_refresh.append(func() -> void: c.set_pressed_no_signal(get_v.call()))


func _slider(grid: GridContainer, text: String, get_v: Callable, set_v: Callable) -> void:
	_label(grid, text)
	var row := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(220, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(52, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0)
		set_v.call(v))
	s.drag_ended.connect(func(_changed: bool) -> void: Settings.save_file())
	row.add_child(s)
	row.add_child(pct)
	grid.add_child(row)
	_refresh.append(func() -> void:
		s.set_value_no_signal(get_v.call())
		pct.text = "%d%%" % roundi(s.value * 100.0))


func _choice(grid: GridContainer, text: String, options: Array, get_v: Callable, set_v: Callable) -> void:
	_label(grid, text)
	var o := OptionButton.new()
	for t in options:
		o.add_item(t)
	o.item_selected.connect(func(i: int) -> void: set_v.call(i); Settings.save_file())
	grid.add_child(o)
	_refresh.append(func() -> void: o.select(get_v.call()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Settings.apply_audio(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Settings.apply_audio(true)


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if _settings.visible:
			_close_settings()
		elif _controls.visible:
			_close_controls()
		elif _panel.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_F11:
		Settings.toggle_fullscreen()
		for r in _refresh:
			r.call()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_R and not _settings.visible:
		get_viewport().set_input_as_handled()  # before the reload: after it this menu is gone
		_restart()


func is_open() -> bool:
	return _panel.visible


func _pause() -> void:
	_panel.visible = true
	_main.visible = true
	_settings.visible = false
	_controls.visible = false
	get_tree().paused = true


func _resume() -> void:
	_settings.visible = false
	_controls.visible = false
	_panel.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	for r in _refresh:
		r.call()
	_main.visible = false
	_settings.visible = true


func _close_settings() -> void:
	Settings.save_file()
	_settings.visible = false
	_main.visible = true


## Wipe the save: the home, the codex, the tallies and the cups, all of it (settings and
## looks are kept). Asks once more first: the button changes to a warning for a few
## seconds, and only a second click does it.
var _reset_button: Button
var _reset_armed := false


func _reset_save() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Erase everything?"
		_reset_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		get_tree().create_timer(3.0, true).timeout.connect(func() -> void:
			if is_instance_valid(_reset_button):
				_reset_armed = false
				_reset_button.text = "Reset save"
				_reset_button.remove_theme_color_override("font_color"))
		return
	SaveData.wipe()
	get_tree().paused = false
	if get_tree().reload_current_scene() != OK:
		SaveData.wiping = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()
