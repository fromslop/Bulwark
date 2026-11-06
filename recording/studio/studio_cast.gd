## The cast board: every foe you can perform, where it turns up, and how many of its clips
## are recorded. Pick one to step into it. Ordered as the roster is (the way down first).
class_name StudioCast
extends HHPanel

var studio
var _scroll: ScrollContainer
var _list: VBoxContainer
var _total: Label


func _init(p_studio) -> void:
	super._init("Cast", Vector2(0.56, 0.78))
	studio = p_studio
	_total = HHStyle.label("", HHStyle.SIZE_BODY, HHStyle.TEXT_DIM, HHStyle.mono())
	body.add_child(_total)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var all_done := 0
	var all := 0
	for pair in HoardsmanCues.foes():
		var d: Dictionary = pair[1]
		var id := HoardsmanCues.slug(d)
		if not studio.character_ids.has(id):
			continue
		var cues := HHCues.all(id).filter(func(c: Dictionary) -> bool: return not c.get("shared", false) and not c.get("skipped", false))
		var done := cues.filter(func(c: Dictionary) -> bool: return c.recorded).size()
		all_done += done
		all += cues.size()
		_list.add_child(_row(id, str(d.name), Codex.foe_where(d), done, cues.size(), id == studio.character_id()))
	_total.text = "%d of %d clips recorded" % [all_done, all]
	set_subtitle("%d%%" % roundi(100.0 * all_done / maxf(all, 1.0)))


func _row(id: String, title: String, where: String, done: int, total: int, picked: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", HHStyle.fill(HHStyle.ROW_PICKED if picked else HHStyle.ROW, 12, HHStyle.ACCENT if picked else Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", HHStyle.fill(HHStyle.ROW_HOVER, 12, HHStyle.GLASS_EDGE))
	b.add_theme_stylebox_override("pressed", HHStyle.fill(HHStyle.ROW_PICKED, 12, HHStyle.ACCENT))
	b.pressed.connect(func() -> void: studio.select_character_id(id))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var n := HHStyle.label(title, HHStyle.SIZE_BODY, HHStyle.TEXT, HHStyle.bold())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	var c := HHStyle.label("%d/%d" % [done, total], HHStyle.SIZE_SMALL, HHStyle.OK if done == total else HHStyle.TEXT_DIM, HHStyle.mono())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(c)
	var w := HHStyle.label(where, HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT)
	w.clip_text = true
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(w)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.max_value = maxi(total, 1)
	bar.value = done
	bar.add_theme_stylebox_override("background", HHStyle.fill(Color(1, 1, 1, 0.06), 3))
	bar.add_theme_stylebox_override("fill", HHStyle.fill(HHStyle.OK, 3))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	return b
