## The deck: the transport and the last take. Every control here is also on a button (shown
## beside it), so the panel teaches the shortcuts while you click.
##
##   [ ●  RECORD          MENU ]
##   [ ▶  Replay              A ]
##   [ ⧉  Play-along         Y ]   [ ✂  Punch-in: off  L-stick ]
##   [ ◌  Ghost cubes  R-stick ]
##   LAST TAKE
##   knight / act_thrust   2.4 s   144 frames   72 Hz   baked ✓
class_name StudioDeck
extends HHPanel

var studio
var _rec: Button
var _replay: Button
var _along: Button
var _punch: Button
var _ghost: Button
var _take_name: Label
var _take_stats: Label
var _status: Label


func _init(p_studio) -> void:
	super._init("Deck", Vector2(0.6, 0.52))
	studio = p_studio
	_rec = _button("●   RECORD", "MENU", func() -> void: studio.toggle_recording(), 92)
	body.add_child(_rec)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	_replay = _button("", "A", func() -> void: studio.toggle_replay())
	_along = _button("", "Y", func() -> void: studio.toggle_play_along())
	_punch = _button("", "L-STICK", func() -> void: studio.cycle_punch())
	_ghost = _button("", "R-STICK", func() -> void: studio.toggle_ghost())
	for b in [_replay, _along, _punch, _ghost]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	body.add_child(gap)
	body.add_child(HHStyle.label("LAST TAKE", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold()))
	_take_name = HHStyle.label("", HHStyle.SIZE_BODY, HHStyle.TEXT, HHStyle.bold())
	_take_name.clip_text = true
	body.add_child(_take_name)
	_take_stats = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_DIM, HHStyle.mono())
	body.add_child(_take_stats)
	_status = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.mono())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)


## A deck button: what it does on the left, its headset button on the right.
func _button(text: String, key: String, act: Callable, height := 72) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = text
	b.add_theme_font_override("font", HHStyle.bold())
	b.pressed.connect(act)
	var k := HHStyle.label(key, HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.mono())
	k.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	k.offset_left = -170
	k.offset_right = -16
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(k)
	return b


func refresh() -> void:
	var idle: bool = studio.is_idle()
	var rec: bool = not idle
	_rec.text = "■   STOP" if rec else "●   RECORD"
	var rc: Color = HHStyle.REC
	_rec.add_theme_stylebox_override("normal", HHStyle.fill(Color(rc, 0.28 if rec else 0.14), 14, Color(rc, 0.8)))
	_rec.add_theme_stylebox_override("hover", HHStyle.fill(Color(rc, 0.32), 14, rc))
	_rec.add_theme_color_override("font_color", HHStyle.TEXT if rec else rc)
	_rec.add_theme_color_override("font_hover_color", HHStyle.TEXT)
	_rec.add_theme_font_size_override("font_size", HHStyle.SIZE_TITLE)
	var has_take: bool = studio.last_clean != null and studio.character != null
	_replay.text = "■   Back to live" if studio.replay else "▶   Replay last take"
	_replay.disabled = not idle or not (has_take or studio.replay)
	_along.text = "◫   Play-along: %s" % ("on" if studio.play_along else "off")
	_along.disabled = not idle
	var punch: String = studio.punch_group()
	_punch.text = "◧   Punch-in: %s" % (punch if punch != "" else "off")
	_punch.add_theme_color_override("font_color", HHStyle.WARN if punch != "" else HHStyle.TEXT)
	_punch.disabled = not idle
	_ghost.text = "◇   Ghost cubes: %s" % ("on" if studio.ghost_cubes_visible else "off")
	_ghost.disabled = not idle
	if studio.last_take:
		var t: HHTake = studio.last_take
		var who := t.character_id if t.character_id != "" else "free"
		_take_name.text = "%s / %s" % [who, t.clip_name if t.clip_name != "" else str(studio.last_take_path).get_file().get_basename()]
		_take_stats.text = "%.1f s   ·   %d frames   ·   %.0f Hz" % [t.duration(), t.frame_count(), t.sample_rate()]
	else:
		_take_name.text = "No takes yet"
		_take_stats.text = ""
	_status.text = str(studio.status_line).replace("\n", "   ·   ")
	set_subtitle("REC" if rec else ("REPLAY" if studio.replay else "LIVE"))
