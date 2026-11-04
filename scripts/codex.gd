class_name Codex
extends CanvasLayer
## The index: every piece of gear, modifier, foe and place, with the ones you've laid eyes
## on filled in and the rest as question marks. Opened by holding the Codex at home and
## pressing Space. Q / E turn to the next section; Space or Esc closes it.

const TABS := ["GEAR", "MODIFIERS", "FOES", "PLACES", "SECRETS"]
const COLS := 8
const CELL := Vector2(148, 62)
const GRID_AT := Vector2(50, 96)

var _game: Node
var _page: Page
var tab := 0


func setup(game: Node) -> void:
	_game = game
	layer = 108
	_page = Page.new()
	_page.codex = self
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.visible = false
	add_child(_page)


func is_open() -> bool:
	return _page.visible


## Name a kept piece of gear: a little plate with a text box over the item. Enter keeps
## the name, Esc keeps the old one.
var _rename_box: LineEdit
var _rename_target: Item


func rename(it: Item) -> void:
	if _rename_box == null:
		_rename_box = LineEdit.new()
		_rename_box.max_length = 24
		_rename_box.size = Vector2(260, 34)
		_rename_box.add_theme_font_size_override("font_size", 16)
		_rename_box.placeholder_text = "name it"
		_rename_box.text_submitted.connect(_on_renamed)
		_rename_box.visible = false
		add_child(_rename_box)
	_rename_target = it
	_rename_box.text = str(it.def.get("custom_name", ""))
	_rename_box.position = (it.global_position + Vector2(-130, -70)).clamp(Vector2(10, 10), Vector2(1010, 680))
	_rename_box.visible = true
	_rename_box.grab_focus()
	_rename_box.select_all()


func _on_renamed(text: String) -> void:
	_rename_box.visible = false
	_rename_box.release_focus()
	if _rename_target == null or not is_instance_valid(_rename_target):
		return
	var it := _rename_target
	it.def = it.def.duplicate(true)
	text = text.strip_edges()
	if text == "":
		it.def.erase("custom_name")
	else:
		it.def.custom_name = text
	it.queue_redraw()
	Sfx.play("soft", -6.0, 1.3)
	_game.overlay.ring(it.global_position, 40.0, Color(0.95, 0.75, 0.35), 0.4)
	if _game.state == _game.State.HOME:
		_game._save_home()


func _unhandled_key_input(e: InputEvent) -> void:
	# Esc while naming: keep the old name
	if _rename_box and _rename_box.visible and e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_rename_box.visible = false
		_rename_box.release_focus()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_page.visible = not _page.visible
	if _page.visible:
		Sfx.play("soft", -6.0, 1.1)


## Open straight at one collection (each object at home opens its own page).
func open_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	if not _page.visible:
		toggle()


## [found, total] in a collection, for the inspect card.
func progress(i: int) -> Array:
	var keep := tab
	tab = clampi(i, 0, TABS.size() - 1)
	var es := entries()
	tab = keep
	var known := 0
	for e in es:
		if e[1]:
			known += 1
	return [known, es.size()]


func _input(e: InputEvent) -> void:
	if not _page.visible:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_Q:
			tab = posmod(tab - 1, TABS.size())
		KEY_E:
			tab = posmod(tab + 1, TABS.size())
		KEY_SPACE, KEY_ESCAPE:
			_page.visible = false
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_d: float) -> void:
	if _page.visible:
		_page.queue_redraw()


## Everything a section lists: [id, known, title, text, kind, def-or-null]
func entries() -> Array:
	var save: SaveData = _game.save
	var out: Array = []
	match TABS[tab]:
		"GEAR":
			var ids := ItemDefs.DEFS.keys().filter(func(k: String) -> bool: return ItemDefs.DEFS[k].kind not in ["coin", "menu"])
			ids.sort_custom(func(a: String, b: String) -> bool:
				var ra := ItemDefs.rarity_of(a)
				var rb := ItemDefs.rarity_of(b)
				return ra < rb if ra != rb else a < b)
			for id in ids:
				var d: Dictionary = ItemDefs.DEFS[id]
				out.append([id, save.knows("items", id), d.title, str(d.get("effect", "")), d.kind, d])
			for uid in ItemDefs.UPGRADES:
				var u: Dictionary = ItemDefs.UPGRADES[uid]
				out.append([uid, save.knows("items", uid), u.title, str(u.desc), "ring" if u.get("ring", false) else "upgrade", u])
		"MODIFIERS":
			for m in ItemDefs.MODIFIERS:
				out.append([m, save.knows("modifiers", m), str(ItemDefs.MODIFIERS[m].get("name", str(m).capitalize())), str(ItemDefs.MODIFIERS[m].desc), "mod", null])
		"FOES":
			var all: Array = ItemDefs.DEFS.keys()  # placeholder to keep types happy
			all.clear()
			for id in EnemyDefs.ENEMIES:
				var d: Dictionary = EnemyDefs.ENEMIES[id]
				out.append([d.name, save.knows("foes", d.name), d.name, str(d.get("bio", "")), "boss" if d.get("boss", false) else "foe", d])
			out.append([EnemyDefs.WARDEN.name, save.knows("foes", EnemyDefs.WARDEN.name), EnemyDefs.WARDEN.name, str(EnemyDefs.WARDEN.bio), "foe", EnemyDefs.WARDEN])
		"PLACES":
			var names: Array = Backdrop.SETTINGS.duplicate()
			names.append_array(Backdrop.RARE.keys())
			names.append("Hidden Vault")
			for nm in names:
				out.append([nm, save.knows("places", nm), nm, str(Backdrop.BLURB.get(nm, "")), "place", null])
		"SECRETS":
			# a riddle until it's found, the plain condition after
			for nm in Secrets.STAGES:
				var st: Dictionary = Secrets.STAGES[nm]
				var known := save.knows("places", nm)
				out.append([nm, known, nm, (st.how + "  Guarded by the " + st.foe + ".") if known else st.hint, "secret", st])
			for id in Secrets.FINDS:
				var fd: Array = Secrets.FINDS[id]
				var known := save.knows("secrets", id)
				out.append([id, known, fd[0], fd[1] if known else fd[2], "secret", null])
			for key in Main.REACTIONS:
				var rx: Dictionary = Main.REACTIONS[key]
				out.append([key, save.knows("reactions", key), str(rx.name).capitalize(), str(key).replace("+", " + ") + ": " + str(rx.desc), "reaction", null])
	return out


## The page itself.
class Page:
	extends Tooltip.Drawn

	var codex: Codex

	func _draw() -> void:
		var game: Node = codex._game
		var save: SaveData = game.save
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		var frame := Rect2(30, 30, 1220, 660)
		_plate(frame, Color(0.85, 0.65, 0.3))
		# tabs along the top, the open one lit
		var x := 60.0
		for i in Codex.TABS.size():
			var label: String = Codex.TABS[i]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24
			var on := i == codex.tab
			draw_rect(Rect2(x, 44, w, 26), Color(0.85, 0.65, 0.3, 0.25 if on else 0.06))
			draw_rect(Rect2(x, 44, w, 26), Color(0.85, 0.65, 0.3, 1.0 if on else 0.3), false, 1.0)
			draw_string(font, Vector2(x + 12, 63), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK if on else DIM)
			x += w + 8
		_keycap(Vector2(x + 10, 49), "Q", 22)
		_keycap(Vector2(x + 36, 49), "E", 22)
		draw_string(font, Vector2(x + 66, 63), "turn the page", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		var entries: Array = codex.entries()
		var known := 0
		for e in entries:
			if e[1]:
				known += 1
		var right := "found %d of %d      deepest run: prestige %d" % [known, entries.size(), save.prestige_best]
		draw_string(font, Vector2(1230 - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 63), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
		# the grid
		var mouse := get_viewport().get_mouse_position()
		var hover: Array = []
		for i in entries.size():
			var e: Array = entries[i]
			var r := Rect2(Codex.GRID_AT + Vector2(i % Codex.COLS, int(i / float(Codex.COLS))) * Codex.CELL, Codex.CELL - Vector2(6, 6))
			if r.end.y > 600:
				break
			var known_e: bool = e[1]
			var over := r.has_point(mouse)
			if over and (known_e or e[4] == "secret"):
				hover = e  # a secret not yet found still shows its riddle
			draw_rect(r, Color(1, 1, 1, 0.1 if over else 0.04))
			draw_rect(r, Color(0.85, 0.65, 0.3, 0.5 if over else 0.15), false, 1.0)
			_thumb(e, r.position + Vector2(6, 6))
			var title: String = e[2] if known_e else "???"
			var col := INK if known_e else Color(0.35, 0.33, 0.3)
			if known_e and e[4] == "boss":
				col = Color(0.95, 0.6, 1.0)
			draw_string(font, r.position + Vector2(52, 24), title, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x - 56), 12, col)
			if known_e:
				var tag := _tag(e)
				draw_string(font, r.position + Vector2(52, 40), tag, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x - 56), 9, DIM)
		# what the mouse is over, spelled out at the bottom
		var box := Rect2(50, 612, 1180, 66)
		draw_rect(box, Color(0, 0, 0, 0.4))
		draw_rect(box, Color(0.85, 0.65, 0.3, 0.3), false, 1.0)
		if not hover.is_empty():
			draw_string(font, box.position + Vector2(12, 22), str(hover[2]) if hover[1] else "???  (a riddle)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			var text: String = hover[3]
			if hover[5] is Dictionary and hover[4] in ["weapon", "shield", "crate", "consumable", "potion", "utility", "junk"]:
				var d: Dictionary = hover[5]
				var extra: String = ItemDefs.RARITY_NAMES[ItemDefs.rarity_of(hover[0])]
				if ItemDefs.PRESTIGE.has(hover[0]):
					extra += ", from prestige %d" % ItemDefs.PRESTIGE[hover[0]]
				if d.has("swing_damage"):
					extra += "   damage %d   recovery %.1fs" % [int(d.swing_damage), d.cooldown]
				text = extra + ("   " + text if text != "" else "")
			draw_multiline_string(font, box.position + Vector2(12, 42), text, HORIZONTAL_ALIGNMENT_LEFT, 1150, 12, 2, DIM)
		else:
			draw_string(font, box.position + Vector2(12, 40), "hover over something you've found   ·   SPACE closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)

	func _tag(e: Array) -> String:
		match e[4]:
			"mod":
				return "modifier"
			"foe":
				return "foe"
			"boss":
				return "BOSS"
			"place":
				return "place"
			"secret":
				return "secret"
			"reaction":
				return "reaction"
			"ring":
				return "ring"
			"upgrade":
				return "hand upgrade"
		return ItemDefs.RARITY_NAMES[ItemDefs.rarity_of(e[0])].to_lower() + " " + str(e[4])

	## A little picture: the item's pixel mask, a modifier's colour chip, a foe's colour, a place's swatch.
	func _thumb(e: Array, at: Vector2) -> void:
		var known: bool = e[1]
		var box := Rect2(at, Vector2(40, 44))
		draw_rect(box, Color(0, 0, 0, 0.35))
		if not known:
			draw_string(font, at + Vector2(0, 30), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(0.3, 0.28, 0.25))
			return
		match e[4]:
			"mod":
				var col: Color = Tooltip.MOD_COLORS.get(e[0], INK)
				draw_rect(Rect2(at + Vector2(8, 10), Vector2(24, 24)), Color(col.r, col.g, col.b, 0.3))
				draw_rect(Rect2(at + Vector2(8, 10), Vector2(24, 24)), col, false, 2.0)
			"foe", "boss":
				var d: Dictionary = e[5]
				var col: Color = d.color
				draw_rect(Rect2(at + Vector2(12, 6), Vector2(16, 14)), col.lightened(0.15))  # head
				draw_rect(Rect2(at + Vector2(6, 22), Vector2(28, 18)), col)  # shoulders
				draw_rect(Rect2(at + Vector2(14, 10), Vector2(12, 2)), Color(0.02, 0.02, 0.02))
				if e[4] == "boss":
					for k in 3:
						draw_rect(Rect2(at + Vector2(12 + k * 6, 2), Vector2(2, 4)), Color(0.95, 0.75, 0.2))
			"secret":
				draw_string(font, at + Vector2(0, 31), "*", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color(1.0, 0.82, 0.3))
			"reaction":
				var els: PackedStringArray = str(e[0]).split("+")
				draw_circle(at + Vector2(13, 22), 9.0, Main.ELEMENT_COLORS[els[0]])
				draw_circle(at + Vector2(27, 22), 9.0, Main.ELEMENT_COLORS[els[1]])
			"place":
				var look: Dictionary = Backdrop.LOOK.get(e[0], Backdrop.LOOK["Dungeon Cell"])
				var stops: Array = look.c
				for i in stops.size():
					draw_rect(Rect2(at + Vector2(4 + i * 6.4, 8), Vector2(6, 28)), stops[i])
			_:
				var d: Dictionary = e[5]
				var shape: String = d.get("shape", "")
				var mat: String = d.get("material", d.materials[0] if d.has("materials") else "wood")
				var mask := ItemDefs.shape_mask(shape)
				var w := mask[0].length()
				var h := mask.size()
				var px := minf(4.0, minf(36.0 / w, 40.0 / h))
				var org := at + Vector2(20, 22) - Vector2(w, h) * px * 0.5
				for y in h:
					for x in w:
						var ch: String = mask[y][x]
						if ch == ".":
							continue
						var m: String = mat if ch == "M" else ItemDefs.MASK_MATS.get(ch, mat)
						var col: Color = d.gem if ch == "g" and d.has("gem") else Materials.get_mat(m).color
						draw_rect(Rect2(org + Vector2(x, y) * px, Vector2(px, px)), col)
