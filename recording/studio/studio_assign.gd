## The Assign window: who performs each foe's clips. Foes down the left; the picked foe's
## clips on the right, grouped, each with its source. Point at a clip and pull the trigger
## to open its choices inline:
##
##   AUTO        the studio decides: a foe with its own take keeps it, otherwise the first
##               foe with the same grip or build that has one lends it
##   OWN TAKE    this foe performs it itself
##   <A FOE>     that foe's take, baked to fit this one (✓: that foe has a take of it)
##   NOT NEEDED  no clip: the foe keeps the game's own motion for it
##
## Choices live in recording/assignments.cfg (HoardsmanCues.assign). After a change the
## studio's lists update at once and the shared clips are rebaked in the background.
##
##   FOES                    │  KNIGHT                         11 own · 4 shared · 1 off
##   Footman   9 · 6 · 0     │  ATTACKS
##   Knight   11 · 4 · 1  ◀  │  ✓  Overhead, left          ●  OWN TAKE
##   ...                     │  ·  Thrust                  ←  FROM FOOTMAN   AUTO
class_name StudioAssign
extends HHPanel

const KIND_TITLES := StudioCueBoard.KIND_TITLES
const LEFT_W := 470

var studio
var _foe := ""        # the foe whose clips are listed (a character id)
var _open := ""       # the clip whose choices are open ("" for none)
var _foes: VBoxContainer
var _foe_scroll: ScrollContainer
var _name: Label
var _counts: HBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init(p_studio) -> void:
	super._init("Assign", Vector2(1.1, 0.78))
	studio = p_studio
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	body.add_child(cols)
	# left: the foes
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	var lh := HBoxContainer.new()
	left.add_child(lh)
	var lt := HHStyle.label("FOES", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold())
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lt)
	lh.add_child(_legend())
	_foe_scroll = _scroller()
	left.add_child(_foe_scroll)
	_foes = _vlist(6)
	_foe_scroll.add_child(_foes)
	# the rule between
	var gap := MarginContainer.new()
	gap.add_theme_constant_override("margin_left", 22)
	gap.add_theme_constant_override("margin_right", 22)
	cols.add_child(gap)
	var rule := ColorRect.new()
	rule.color = Color(HHStyle.GLASS_EDGE, 0.25)
	rule.custom_minimum_size = Vector2(2, 0)
	gap.add_child(rule)
	# right: the picked foe's clips
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_name = HHStyle.label("", HHStyle.SIZE_TITLE, HHStyle.TEXT, HHStyle.bold())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	_counts = HBoxContainer.new()
	_counts.add_theme_constant_override("separation", 22)
	_counts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_counts)
	right.add_child(HHStyle.label("Point at a clip and pull the trigger to choose who performs it.", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT))
	_scroll = _scroller()
	right.add_child(_scroll)
	_list = _vlist(4)
	_scroll.add_child(_list)


## Which foe's clips are listed.
func show_foe(id: String) -> void:
	if id != _foe:
		_foe = id
		_open = ""
		refresh()
		_scroll.scroll_vertical = 0


func refresh() -> void:
	if _foe == "" or not studio.character_ids.has(_foe):
		_foe = studio.character_id()
	var by_foe := {}
	for c in HHCues.all():
		if not by_foe.has(c.character):
			by_foe[c.character] = []
		by_foe[c.character].append(c)
	_fill_foes(by_foe)
	_fill_clips(by_foe.get(_foe, []))


# --- the foes --------------------------------------------------------------------------

func _fill_foes(by_foe: Dictionary) -> void:
	_clear(_foes)
	var offs := 0
	var shared := 0
	for pair in HoardsmanCues.foes():
		var id := HoardsmanCues.slug(pair[1])
		if not studio.character_ids.has(id) or not by_foe.has(id):
			continue
		var n := _tally(by_foe[id])
		offs += n.skip
		shared += n.shared
		_foes.add_child(_foe_row(id, str(pair[1].name), n, id == _foe, id == studio.character_id()))
	set_subtitle("%d SHARED  ·  %d NOT NEEDED" % [shared, offs])


static func _tally(rows: Array) -> Dictionary:
	var n := {"own": 0, "shared": 0, "skip": 0}
	for c in rows:
		if c.get("skipped", false):
			n.skip += 1
		elif c.get("shared", false):
			n.shared += 1
		else:
			n.own += 1
	return n


func _foe_row(id: String, title: String, n: Dictionary, picked: bool, on_stage: bool) -> Control:
	var b := _row_button(72, picked)
	b.pressed.connect(func() -> void: show_foe(id))
	var h := _row_box(b, 18)
	var mark := HHStyle.label("◀" if picked else ("●" if on_stage else ""), HHStyle.SIZE_SMALL, HHStyle.ACCENT if picked else HHStyle.TEXT_FAINT, HHStyle.bold())
	mark.custom_minimum_size = Vector2(22, 0)
	_quiet(mark)
	var t := HHStyle.label(title, HHStyle.SIZE_BODY, HHStyle.TEXT if picked else HHStyle.TEXT_DIM, HHStyle.bold() if picked else HHStyle.sans())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	_quiet(t)
	h.add_child(t)
	for part in [[n.own, HHStyle.OK], [n.shared, HHStyle.ACCENT], [n.skip, HHStyle.TEXT_FAINT]]:
		var k := HHStyle.label(str(part[0]) if int(part[0]) > 0 else "·", HHStyle.SIZE_SMALL, part[1] if int(part[0]) > 0 else Color(HHStyle.TEXT_FAINT, 0.6), HHStyle.mono())
		k.custom_minimum_size = Vector2(40, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quiet(k)
		h.add_child(k)
	h.add_child(mark)
	return b


## The key to the three counts: own, shared, not needed.
static func _legend() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	for part in [["OWN", HHStyle.OK], ["SHR", HHStyle.ACCENT], ["OFF", HHStyle.TEXT_FAINT]]:
		var k := HHStyle.label(part[0], 18, Color(part[1], 0.8), HHStyle.mono())
		k.custom_minimum_size = Vector2(40, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(k)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(28, 0)  # (lines the key up over the rows' counts)
	h.add_child(pad)
	return h


# --- the picked foe's clips ------------------------------------------------------------

func _fill_clips(rows: Array) -> void:
	_clear(_list)
	_clear(_counts)
	_name.text = StudioCueBoard._who(_foe).to_upper() if _foe != "" else "No foe"
	if rows.is_empty():
		return
	var n := _tally(rows)
	for part in [["%d own" % n.own, HHStyle.OK], ["%d shared" % n.shared, HHStyle.ACCENT], ["%d not needed" % n.skip, HHStyle.TEXT_DIM]]:
		_counts.add_child(HHStyle.label(part[0], HHStyle.SIZE_SMALL, part[1], HHStyle.mono()))
	var groups := {}
	for c in rows:
		if not groups.has(c.kind):
			groups[c.kind] = []
		groups[c.kind].append(c)
	for kind in StudioCueBoard.KIND_TITLES.keys() + groups.keys():
		if not groups.has(kind):
			continue
		var head := HHStyle.label(KIND_TITLES.get(kind, str(kind).to_upper()), HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold())
		head.custom_minimum_size = Vector2(0, 48)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_list.add_child(head)
		for c in groups[kind]:
			_list.add_child(_clip_row(c))
			if c.clip == _open:
				_list.add_child(_choices(c))
		groups.erase(kind)


## What a clip's source reads as: [glyph, text, colour].
static func source_of(c: Dictionary) -> Array:
	if c.get("skipped", false):
		return ["–", "NOT NEEDED", HHStyle.TEXT_FAINT]
	if c.get("shared", false):
		return ["←", "FROM " + StudioCueBoard._who(str(c.owner)).to_upper(), HHStyle.ACCENT]
	return ["●", "OWN TAKE" if c.recorded else "OWN  ·  TO RECORD", HHStyle.OK if c.recorded else HHStyle.WARN]


func _clip_row(c: Dictionary) -> Control:
	var open: bool = c.clip == _open
	var b := _row_button(62, open)
	var clip: String = c.clip
	b.pressed.connect(func() -> void:
		_open = "" if _open == clip else clip
		refresh())
	var h := _row_box(b, 16)
	var skipped: bool = c.get("skipped", false)
	var done := HHStyle.label("✓" if c.recorded else "·", HHStyle.SIZE_SMALL, HHStyle.OK if c.recorded else HHStyle.TEXT_FAINT, HHStyle.bold())
	done.custom_minimum_size = Vector2(26, 0)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiet(done)
	h.add_child(done)
	var t := HHStyle.label(StudioSlate.clip_title(c), HHStyle.SIZE_BODY, HHStyle.TEXT_FAINT if skipped else HHStyle.TEXT, HHStyle.bold() if open else HHStyle.sans())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	_quiet(t)
	h.add_child(t)
	var src := source_of(c)
	var g := HHStyle.label(src[0], HHStyle.SIZE_SMALL, src[2], HHStyle.bold())
	_quiet(g)
	h.add_child(g)
	var s := HHStyle.label(src[1], HHStyle.SIZE_SMALL, src[2], HHStyle.mono())
	s.custom_minimum_size = Vector2(330, 0)
	_quiet(s)
	h.add_child(s)
	var how := HHStyle.label("AUTO" if str(c.get("assigned", "")) == "" else "SET", 16, HHStyle.TEXT_FAINT if str(c.get("assigned", "")) == "" else HHStyle.WARN, HHStyle.mono())
	how.custom_minimum_size = Vector2(56, 0)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quiet(how)
	h.add_child(how)
	return b


## The open clip's choices, as a row of chips under it.
func _choices(c: Dictionary) -> Control:
	var box := PanelContainer.new()
	var st := HHStyle.fill(Color(HHStyle.ACCENT, 0.06), 10, Color(HHStyle.ACCENT, 0.3))
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 14
	st.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	v.add_child(HHStyle.label("WHO PERFORMS IT?", 18, HHStyle.TEXT_FAINT, HHStyle.bold()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	v.add_child(flow)
	var now := str(c.get("assigned", ""))
	var clip: String = c.clip
	var auto := HoardsmanCues.auto_owner(_foe, clip)
	flow.add_child(_chip("Auto  ·  " + ("own take" if auto == _foe else StudioCueBoard._who(auto)), "", now == "", HHStyle.TEXT, clip))
	flow.add_child(_chip("Own take" + ("  ✓" if HoardsmanCues._has_take(_foe, clip) else ""), "own", now == "own", HHStyle.OK, clip))
	for s in HoardsmanCues.sources(_foe, clip):
		var who: String = s[0]
		flow.add_child(_chip(StudioCueBoard._who(who) + ("  ✓" if s[1] else ""), who, now == who, HHStyle.ACCENT if s[1] else HHStyle.TEXT_DIM, clip))
	flow.add_child(_chip("Not needed", "skip", now == "skip", HHStyle.TEXT_DIM, clip))
	return box


func _chip(text: String, pick: String, on: bool, col: Color, clip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", HHStyle.bold() if on else HHStyle.sans())
	b.add_theme_font_size_override("font_size", HHStyle.SIZE_SMALL)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, HHStyle.TEXT if on else col)
	var pad := func(sb: StyleBoxFlat) -> StyleBoxFlat:
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		return sb
	b.add_theme_stylebox_override("normal", pad.call(HHStyle.fill(HHStyle.ROW_PICKED if on else Color(1, 1, 1, 0.05), 25, HHStyle.ACCENT if on else Color(1, 1, 1, 0.1))))
	b.add_theme_stylebox_override("hover", pad.call(HHStyle.fill(HHStyle.ROW_HOVER, 25, HHStyle.GLASS_EDGE)))
	b.add_theme_stylebox_override("pressed", pad.call(HHStyle.fill(HHStyle.ROW_PICKED, 25, HHStyle.ACCENT)))
	b.pressed.connect(func() -> void: choose(clip, pick))
	return b


## Sets who performs the listed foe's clip ("" automatic, "own", "skip" or a foe's id).
func choose(clip: String, pick: String) -> void:
	HoardsmanCues.assign(_foe, clip, pick)
	_open = ""
	studio.assignments_changed()


# --- bits ------------------------------------------------------------------------------

static func _scroller() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s


static func _vlist(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", sep)
	return v


static func _row_button(height: int, picked: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", HHStyle.fill(HHStyle.ROW_PICKED if picked else Color(0, 0, 0, 0), 10, HHStyle.ACCENT if picked else Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", HHStyle.fill(HHStyle.ROW_HOVER, 10, HHStyle.GLASS_EDGE))
	b.add_theme_stylebox_override("pressed", HHStyle.fill(HHStyle.ROW_PICKED, 10, HHStyle.ACCENT))
	return b


static func _row_box(b: Button, sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	return h


static func _quiet(l: Label) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
