## The cue board: everything this character needs performed, grouped the way you'll work
## through it (idle, attacks, guard, reactions, death), each with its state and wind-up.
## Point and pull the trigger to pick one; the stick scrolls.
##
##   KNIGHT                                         9 / 15
##   ███████████████░░░░░░░░░░
##   ATTACKS
##   ✓  Overhead, left                              0.74 s
##   ▶  Thrust                                      0.87 s   <- picked
##   ○  High slash, from the right                  1.20 s
class_name StudioCueBoard
extends HHPanel

const KIND_TITLES := {"idle": "IDLE", "attack": "ATTACKS", "guard": "GUARD", "reaction": "REACTIONS", "death": "DEATH"}

var studio
var _name: Label
var _count: Label
var _bar: ProgressBar
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init(p_studio) -> void:
	super._init("Cues", Vector2(0.62, 0.78))
	studio = p_studio
	var top := HBoxContainer.new()
	body.add_child(top)
	_name = HHStyle.label("", HHStyle.SIZE_TITLE, HHStyle.TEXT, HHStyle.bold())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	_count = HHStyle.label("", HHStyle.SIZE_TITLE, HHStyle.TEXT_DIM, HHStyle.mono())
	top.add_child(_count)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.add_theme_stylebox_override("background", HHStyle.fill(Color(1, 1, 1, 0.06), 4))
	_bar.add_theme_stylebox_override("fill", HHStyle.fill(HHStyle.OK, 4))
	body.add_child(_bar)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var cues: Array = studio.cues
	if studio.character == null:
		_name.text = "No character"
		_count.text = ""
		_bar.value = 0
		set_subtitle("")
		return
	_name.text = studio.character.profile.display_name
	var done := cues.filter(func(c: Dictionary) -> bool: return c.recorded).size()
	_count.text = "%d / %d" % [done, cues.size()]
	_bar.max_value = maxi(cues.size(), 1)
	_bar.value = done
	set_subtitle("%d TO GO" % (cues.size() - done) if done < cues.size() else "ALL RECORDED")
	var kind := ""
	var picked_row: Control
	for i in cues.size():
		var c: Dictionary = cues[i]
		if c.kind != kind:
			kind = c.kind
			var head := HHStyle.label(KIND_TITLES.get(kind, kind.to_upper()), HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold())
			head.custom_minimum_size = Vector2(0, 52)
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			_list.add_child(head)
		var row := _row(i, c, i == studio.cue_index)
		_list.add_child(row)
		if i == studio.cue_index:
			picked_row = row
	if picked_row:
		_keep_in_view.call_deferred(picked_row)


## Scroll just enough to show the picked row (and its group's heading), once it's laid out.
func _keep_in_view(row: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(row):
		return
	var top := row.position.y - 60.0
	var bottom := row.position.y + row.size.y + 20.0
	var view := _scroll.size.y
	if top < _scroll.scroll_vertical:
		_scroll.scroll_vertical = int(maxf(top, 0.0))
	elif bottom > _scroll.scroll_vertical + view:
		_scroll.scroll_vertical = int(bottom - view)


## One cue: status glyph, its name, its wind-up. The whole row is the button.
func _row(i: int, c: Dictionary, picked: bool) -> Control:
	var b := Button.new()
	b.flat = false
	b.custom_minimum_size = Vector2(0, 62)
	b.focus_mode = Control.FOCUS_NONE
	var base := HHStyle.fill(HHStyle.ROW_PICKED if picked else Color(0, 0, 0, 0), 10, HHStyle.ACCENT if picked else Color(0, 0, 0, 0))
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", HHStyle.fill(HHStyle.ROW_HOVER, 10, HHStyle.GLASS_EDGE))
	b.add_theme_stylebox_override("pressed", HHStyle.fill(HHStyle.ROW_PICKED, 10, HHStyle.ACCENT))
	b.pressed.connect(func() -> void: studio.pick_cue(i))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var glyph := "▶" if picked else ("✓" if c.recorded else "○")
	var gcol: Color = HHStyle.ACCENT if picked else (HHStyle.OK if c.recorded else HHStyle.TEXT_FAINT)
	var g := HHStyle.label(glyph, HHStyle.SIZE_BODY, gcol, HHStyle.bold())
	g.custom_minimum_size = Vector2(30, 0)
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(g)
	var n := HHStyle.label(StudioSlate.clip_title(c), HHStyle.SIZE_BODY, HHStyle.TEXT if (picked or not c.recorded) else HHStyle.TEXT_DIM, HHStyle.bold() if picked else HHStyle.sans())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	var w := float(c.get("windup", 0.0))
	var t := HHStyle.label("%.2f s" % w if w > 0.0 else ("loop" if c.get("loops", false) else ""), HHStyle.SIZE_SMALL, HHStyle.WARN if picked and w > 0.0 else HHStyle.TEXT_FAINT, HHStyle.mono())
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	return b
