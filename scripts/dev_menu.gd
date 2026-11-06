class_name DevMenu
extends CanvasLayer
## The developer's menu (F3; only in a debug build: running from source, never an exported
## game). The game pauses while it's open. Two pages:
##   FIGHT     any place, any stage and prestige, any foe (or two): straight into that fight
##             (from home it starts a run first, starting kit and all)
##   CREATIVE  any item, ring or hand upgrade, in any material it comes in (or prestigium),
##             with any modifiers: spawned into the room, yours
## Esc or F3 closes it.

const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.62, 0.57, 0.5)
const BRASS := Color(0.85, 0.65, 0.3)
const PLATE := Color(0.09, 0.07, 0.06, 0.97)
const EPIC := Color(0.78, 0.5, 1.0)
const RARE := Color(1.0, 0.82, 0.3)

var _game: Node
var _root: PanelContainer
var _was_paused := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE
# fight
var _place: OptionButton
var _stage: SpinBox
var _prestige: SpinBox
var _foe: OptionButton
var _foe2: OptionButton
var _foe_ids: Array = []
# creative
var _search: LineEdit
var _items: ItemList
var _item_ids: Array = []  # [kind ("item"/"upgrade"), id] per list row
var _mat: OptionButton
var _count: SpinBox
var _mods: Dictionary = {}  # modifier -> CheckBox
var _picked_label: Label


func setup(game: Node) -> void:
	_game = game
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_was_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_items()
	else:
		get_tree().paused = _was_paused
		Input.mouse_mode = _was_mouse


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or not OS.is_debug_build():
		return
	if k.keycode == KEY_F3 or (k.keycode == KEY_ESCAPE and _root.visible):
		toggle()
		get_viewport().set_input_as_handled()


# --- the look ---------------------------------------------------------------------------

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	var panel := StyleBoxFlat.new()
	panel.bg_color = PLATE
	panel.border_color = BRASS
	panel.set_border_width_all(2)
	panel.set_content_margin_all(18)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.05, 0.04, 0.035)
	well.border_color = Color(BRASS, 0.35)
	well.set_border_width_all(1)
	well.set_content_margin_all(6)
	for c in ["LineEdit", "SpinBox", "ItemList"]:
		t.set_stylebox("normal", c, well)
		t.set_stylebox("panel", c, well)
		t.set_stylebox("focus", c, well)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.2, 0.14, 0.08)
	btn.border_color = Color(BRASS, 0.7)
	btn.set_border_width_all(1)
	btn.set_content_margin_all(8)
	var btn_hi := btn.duplicate() as StyleBoxFlat
	btn_hi.bg_color = Color(0.36, 0.25, 0.12)
	for c in ["Button", "OptionButton"]:
		t.set_stylebox("normal", c, btn)
		t.set_stylebox("hover", c, btn_hi)
		t.set_stylebox("pressed", c, btn_hi)
		t.set_stylebox("focus", c, btn_hi)
		t.set_color("font_color", c, INK)
		t.set_color("font_hover_color", c, Color(1, 0.95, 0.85))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_color", "ItemList", INK)
	t.set_color("font_selected_color", "ItemList", Color(0.1, 0.06, 0.02))
	var sel := StyleBoxFlat.new()
	sel.bg_color = BRASS
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(0.14, 0.1, 0.07)
	tab.set_content_margin_all(8)
	var tab_on := tab.duplicate() as StyleBoxFlat
	tab_on.bg_color = Color(0.3, 0.2, 0.1)
	tab_on.border_color = BRASS
	tab_on.border_width_bottom = 2
	t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("tab_hovered", "TabContainer", tab_on)
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color(1, 0.92, 0.75))
	t.set_color("font_unselected_color", "TabContainer", DIM)
	return t


func _label(text: String, size: int = 12, col: Color = DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _row(parent: Control, caption: String, control: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := _label(caption.to_upper(), 11)
	l.custom_minimum_size = Vector2(110, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	parent.add_child(h)


func _build() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_root = PanelContainer.new()
	_root.theme = _theme()
	_root.position = Vector2(110, 50)
	_root.size = Vector2(1060, 620)
	_root.custom_minimum_size = Vector2(1060, 620)
	holder.add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_label("DEV MENU", 22, BRASS))
	var tip := _label("   F3 or Esc closes it  ·  the game is paused while it's open  ·  debug builds only", 11)
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tip)
	v.add_child(head)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_fight_page())
	tabs.add_child(_creative_page())


# --- FIGHT -------------------------------------------------------------------------------

func _fight_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Fight"
	page.add_theme_constant_override("separation", 12)
	page.add_child(_label("Straight into any fight. From home, a run starts first (starting kit and all); from the shop, the shop closes.", 12))
	_place = OptionButton.new()
	for p in Backdrop.SETTINGS + ["Ossuary", "Star Chamber", "Hidden Vault"] + Secrets.STAGES.keys():
		_place.add_item(str(p))
	_row(page, "Place", _place)
	_stage = SpinBox.new()
	_stage.min_value = 1
	_stage.max_value = EnemyDefs.STAGES
	_stage.value = 1
	_stage.suffix = "  of %d (%d: the boss's)" % [EnemyDefs.STAGES, EnemyDefs.BOSS_STAGE + 1]
	_row(page, "Stage", _stage)
	_prestige = SpinBox.new()
	_prestige.min_value = 0
	_prestige.max_value = 8
	_row(page, "Prestige", _prestige)
	_foe = OptionButton.new()
	_foe2 = OptionButton.new()
	_foe2.add_item("(none)")
	_foe_ids = EnemyDefs.ENEMIES.keys()
	_foe_ids.append("Vault Warden")
	for id in _foe_ids:
		var nm := "Vault Warden" if id == "Vault Warden" else str(EnemyDefs.ENEMIES[id].name)
		var tag := ""
		if id != "Vault Warden":
			if EnemyDefs.ENEMIES[id].get("boss", false):
				tag = "   (boss)"
			elif EnemyDefs.ENEMIES[id].get("secret", false):
				tag = "   (guardian)"
		_foe.add_item(nm + tag)
		_foe2.add_item(nm + tag)
	_row(page, "Foe", _foe)
	_row(page, "Second foe", _foe2)
	var go := Button.new()
	go.text = "FIGHT"
	go.custom_minimum_size = Vector2(220, 44)
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(_go_fight)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(go)
	page.add_child(bar)
	return page


func _go_fight() -> void:
	var ids: Array = [_foe_ids[_foe.selected]]
	if _foe2.selected > 0:
		ids.append(_foe_ids[_foe2.selected - 1])
	var place := _place.get_item_text(_place.selected)
	toggle()
	_game.dev_fight(place, int(_stage.value), int(_prestige.value), ids)


# --- CREATIVE ----------------------------------------------------------------------------

func _creative_page() -> Control:
	var page := HBoxContainer.new()
	page.name = "Creative"
	page.add_theme_constant_override("separation", 16)
	# what: every item, ring and hand upgrade, searchable
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	_search = LineEdit.new()
	_search.placeholder_text = "search items, rings, upgrades..."
	_search.text_changed.connect(func(_t: String) -> void: _refresh_items())
	left.add_child(_search)
	_items = ItemList.new()
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.item_selected.connect(_on_item_picked)
	_items.item_activated.connect(func(_i: int) -> void: _spawn())
	left.add_child(_items)
	page.add_child(left)
	# how: material, count, modifiers
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	_picked_label = _label("Pick something on the left.", 18, INK)
	right.add_child(_picked_label)
	_mat = OptionButton.new()
	_row(right, "Material", _mat)
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 20
	_row(right, "How many", _count)
	right.add_child(_label("MODIFIERS  ·  gold: rare  ·  violet: epic  ·  clashes allowed here", 11))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	var order: Array = ItemDefs.MODIFIERS.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		var ra := _mod_rank(a)
		var rb := _mod_rank(b)
		return ra < rb if ra != rb else a < b)
	for m in order:
		var md: Dictionary = ItemDefs.MODIFIERS[m]
		var cb := CheckBox.new()
		cb.text = str(md.get("name", m))
		cb.tooltip_text = str(md.get("desc", ""))
		var col: Color = EPIC if md.get("epic", false) else (RARE if md.get("rare", false) else Tooltip.MOD_COLORS.get(m, INK))
		cb.add_theme_color_override("font_color", col)
		cb.add_theme_color_override("font_hover_color", col.lightened(0.2))
		cb.add_theme_color_override("font_pressed_color", col.lightened(0.3))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cb)
		_mods[m] = cb
	scroll.add_child(grid)
	right.add_child(scroll)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 10)
	var clear := Button.new()
	clear.text = "Clear modifiers"
	clear.pressed.connect(func() -> void:
		for m in _mods:
			(_mods[m] as CheckBox).button_pressed = false)
	bar.add_child(clear)
	var go := Button.new()
	go.text = "SPAWN"
	go.custom_minimum_size = Vector2(200, 44)
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(_spawn)
	bar.add_child(go)
	right.add_child(bar)
	page.add_child(right)
	return page


static func _mod_rank(m: String) -> int:
	var md: Dictionary = ItemDefs.MODIFIERS[m]
	return 2 if md.get("epic", false) else (1 if md.get("rare", false) else 0)


func _refresh_items() -> void:
	var q := _search.text.strip_edges().to_lower()
	var keep := _items.get_selected_items()
	var was: Array = _item_ids[keep[0]] if not keep.is_empty() and keep[0] < _item_ids.size() else []
	_items.clear()
	_item_ids.clear()
	var rows: Array = []
	for id in ItemDefs.DEFS:
		var d: Dictionary = ItemDefs.DEFS[id]
		if d.kind in ["menu", "trophy"]:
			continue
		rows.append(["item", id, str(d.title), str(d.kind)])
	for uid in ItemDefs.UPGRADES:
		var u: Dictionary = ItemDefs.UPGRADES[uid]
		rows.append(["upgrade", uid, str(u.title), "ring" if u.get("ring", false) else "upgrade"])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[3] < b[3] if a[3] != b[3] else a[2] < b[2])
	for r in rows:
		if q != "" and not (str(r[2]).to_lower().contains(q) or str(r[1]).to_lower().contains(q) or str(r[3]).contains(q)):
			continue
		var rar := ItemDefs.rarity_of(r[1]) if r[0] == "item" else 1
		var i := _items.add_item("%s   ·  %s%s" % [r[2], r[3], ("  ·  " + str(ItemDefs.RARITY_NAMES[rar]).to_lower()) if rar > 0 else ""])
		_item_ids.append([r[0], r[1]])
		if not was.is_empty() and was[0] == r[0] and was[1] == r[1]:
			_items.select(i)


func _on_item_picked(i: int) -> void:
	var pick: Array = _item_ids[i]
	_mat.clear()
	if pick[0] == "upgrade":
		_picked_label.text = str(ItemDefs.UPGRADES[pick[1]].title)
		_mat.add_item("(its own)")
		return
	var d: Dictionary = ItemDefs.DEFS[pick[1]]
	_picked_label.text = str(d.title)
	var mats: Array = (d.get("materials", ["wood"]) as Array).duplicate()
	if d.kind in ["weapon", "shield"] and not mats.has("prestigium"):
		mats.append("prestigium")
	for m in mats:
		_mat.add_item(str(m))
	_mat.select(maxi(0, mats.size() - 1 - (1 if mats.has("prestigium") and mats.size() > 1 else 0)))


func _spawn() -> void:
	var sel := _items.get_selected_items()
	if sel.is_empty():
		return
	var pick: Array = _item_ids[sel[0]]
	var mods: Array = []
	for m in _mods:
		if (_mods[m] as CheckBox).button_pressed:
			mods.append(m)
	for n in int(_count.value):
		if pick[0] == "upgrade":
			_game.dev_spawn(ItemDefs.make_upgrade(pick[1]), [], n)
		else:
			_game.dev_spawn(ItemDefs.make(pick[1], _mat.get_item_text(_mat.selected), mods.duplicate()), mods, n)
	Sfx.play("buy", -4.0, 1.1)
