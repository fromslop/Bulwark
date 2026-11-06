class_name Storage
extends CanvasLayer
## The storage cupboard at home (the tall one in the left corner). Let go of something over
## it and it's put away; Space on it (hand empty) opens its doors: every stored thing on its
## own cubby, drawn as it is (its own pixels, chips and all). Click one to see it, and TAKE
## OUT (or click it again) to have it back: it tumbles out in front of the cupboard. Space,
## Esc or a right-click closes it. What's stored is kept in the save (SaveData.storage) and
## stays home when you set out on a run.

const CAPACITY := 40
const COLS := 8
const PANEL := Rect2(90, 70, 1100, 590)
const GRID := Rect2(116, 132, 720, 500)  # the cubbies
const SIDE := Rect2(860, 132, 304, 500)  # the picked thing
const NOT_STORED := ["menu", "trophy", "coin", "debris"]

var _game: Node
var _page: Page
var picked := -1
var _pics: Array = []  # per stored thing: {cells: {Vector2i: Color}, lo, hi}, rebuilt when the contents change


func setup(game: Node) -> void:
	_game = game
	layer = 107
	_page = Page.new()
	_page.storage = self
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)


func is_open() -> bool:
	return _page.visible


func contents() -> Array:
	return _game.save.storage


func toggle() -> void:
	_page.visible = not _page.visible
	if _page.visible:
		picked = 0 if not contents().is_empty() else -1
		_rebuild_pics()
		Sfx.play("clack", -6.0, 0.7)  # the doors
	else:
		Sfx.play("clack", -8.0, 0.9)


## Can this go in the cupboard? (Not the furniture, the cups, coins or scraps.)
static func storable(it: Item) -> bool:
	return it != null and it.owned and not it.def.kind in NOT_STORED


## Put a thing away. False if it can't go in, or the cupboard is full.
func store(it: Item) -> bool:
	if not storable(it) or contents().size() >= CAPACITY:
		return false
	var e := SaveData.pack(it)
	e.erase("pos")
	e.slot = -1
	contents().append(e)
	_rebuild_pics()
	return true


## Take the `i`th thing out: it tumbles out in front of the cupboard.
func take_out(i: int) -> Item:
	if i < 0 or i >= contents().size():
		return null
	var e: Dictionary = contents()[i]
	var d := SaveData.unpack(e)
	contents().remove_at(i)
	if d.is_empty():
		_rebuild_pics()
		return null  # (something that no longer exists: it's just gone)
	var it: Item = _game._spawn(d, _game.STORAGE_OUT)
	it.rotation = float(e.get("rot", 0.0))
	SaveData.apply_health(it, float(e.get("health", 1.0)))
	it.linear_velocity = Vector2(randf_range(160, 260), -220)
	picked = mini(i, contents().size() - 1)
	_rebuild_pics()
	_game.on_storage_changed()
	return it


## Each stored thing's pixels, made from the real thing (built, read and thrown away).
func _rebuild_pics() -> void:
	_pics.clear()
	for e in contents():
		var d := SaveData.unpack(e)
		var pic := {"cells": {}, "lo": Vector2i.ZERO, "hi": Vector2i.ONE, "damage": -1.0}
		if not d.is_empty():
			var it := Item.create(d)
			SaveData.apply_health(it, float(e.get("health", 1.0)))
			if d.get("kind", "") == "weapon":
				pic.damage = it.hit_damage()
			var lo := Vector2i(1 << 20, 1 << 20)
			var hi := -lo
			for c in it.cells:
				var mat: String = it.cells[c].mat
				var col: Color = Materials.get_mat(mat).color
				if mat == "gem" and d.has("gem"):
					col = d.gem
				elif mat == "glass" and d.has("liquid_color"):
					col = (d.liquid_color as Color).lerp(Color(1, 1, 1), 0.2)
				elif mat == "prestigium":
					col = Item.PRESTIGIUM_FROM.lerp(Item.PRESTIGIUM_TO, float(c.y) / 12.0)
				pic.cells[c] = col * float(it.cells[c].get("shade", 1.0))
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			pic.lo = lo
			pic.hi = hi
			it.free()
		_pics.append(pic)


func _input(e: InputEvent) -> void:
	if not _page.visible:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE, KEY_ESCAPE:
			toggle()
		KEY_LEFT, KEY_A:
			_step(-1)
		KEY_RIGHT, KEY_D:
			_step(1)
		KEY_UP, KEY_W:
			_step(-COLS)
		KEY_DOWN, KEY_S:
			_step(COLS)
		KEY_ENTER, KEY_KP_ENTER:
			take_out(picked)
		_:
			return
	get_viewport().set_input_as_handled()


func _step(d: int) -> void:
	if contents().is_empty():
		return
	picked = clampi(picked + d, 0, contents().size() - 1)
	Sfx.play("soft", -12.0, 1.6)


func _process(_delta: float) -> void:
	if _page.visible:
		_page.queue_redraw()


## The cupboard, open.
class Page:
	extends Tooltip.Drawn

	const WOOD := Color(0.3, 0.17, 0.09)
	const WOOD_DARK := Color(0.16, 0.09, 0.05)
	const BACK := Color(0.11, 0.07, 0.05)
	const BRASS := Color(0.85, 0.66, 0.3)
	const INK2 := Color(0.93, 0.88, 0.78)
	const DIM2 := Color(0.66, 0.58, 0.48)

	var storage: Storage
	var _hits: Array = []

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			storage.toggle()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			for i in range(_hits.size() - 1, -1, -1):
				var h: Array = _hits[i]
				if (h[0] as Rect2).has_point(mb.position):
					_act(h[1], h[2])
					break
		accept_event()

	func _act(what: String, arg: Variant) -> void:
		match what:
			"close":
				storage.toggle()
			"pick":
				if storage.picked == int(arg):
					storage.take_out(int(arg))  # a second click on what's picked takes it out
				else:
					storage.picked = int(arg)
					Sfx.play("soft", -12.0, 1.6)
			"take":
				storage.take_out(storage.picked)

	func _hit(r: Rect2, what: String, arg: Variant = null) -> void:
		_hits.append([r, what, arg])

	func _draw() -> void:
		_hits.clear()
		var mouse := get_local_mouse_position()
		var items: Array = storage.contents()
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
		# the cupboard's carcass, its doors swung open either side
		var p := PANEL
		draw_rect(Rect2(p.position + Vector2(8, 10), p.size), Color(0, 0, 0, 0.5))
		for side in [-1, 1]:
			var door := Rect2(p.position.x - 70.0 if side < 0 else p.end.x + 6.0, p.position.y + 14.0, 64.0, p.size.y - 28.0)
			draw_rect(door, WOOD.darkened(0.25))
			draw_rect(door.grow(-8), WOOD.darkened(0.4), false, 2.0)
			for hy in [0.18, 0.82]:
				draw_rect(Rect2(door.position.x + (door.size.x - 24 if side < 0 else 0), door.position.y + door.size.y * hy - 5, 24, 10), Color(0.2, 0.19, 0.18))  # iron strap hinges
		draw_rect(p, WOOD)
		draw_rect(p.grow(-6), WOOD_DARK, false, 3.0)
		draw_string(font, p.position + Vector2(26, 40), "Storage Cupboard", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK2)
		draw_string(font, p.position + Vector2(246, 40), "%d / %d stored" % [items.size(), Storage.CAPACITY], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM2)
		var tip := "click to pick  ·  click again or TAKE OUT to have it back  ·  SPACE closes"
		draw_string(font, Vector2(p.position.x, p.position.y + 40), tip, HORIZONTAL_ALIGNMENT_RIGHT, p.size.x - 70, 11, DIM2)
		var close := Rect2(p.end.x - 50, p.position.y + 14, 32, 32)
		draw_rect(close, Color(0.15, 0.1, 0.08, 0.9) if not close.has_point(mouse) else Color(0.45, 0.15, 0.1))
		draw_rect(close, Color(BRASS, 0.7), false, 1.0)
		draw_line(close.position + Vector2(10, 10), close.end - Vector2(10, 10), INK2, 2.0)
		draw_line(Vector2(close.end.x - 10, close.position.y + 10), Vector2(close.position.x + 10, close.end.y - 10), INK2, 2.0)
		_hit(close, "close")
		# the cubbies: a pigeonhole each, the back in shadow, the thing sitting in it
		var g := Storage.GRID
		draw_rect(g.grow(4), WOOD_DARK)
		var rows := ceili(float(Storage.CAPACITY) / Storage.COLS)
		var cw := g.size.x / Storage.COLS
		var ch := g.size.y / rows
		for i in Storage.CAPACITY:
			var r := Rect2(g.position.x + (i % Storage.COLS) * cw + 3, g.position.y + int(i / Storage.COLS) * ch + 3, cw - 6, ch - 6)
			draw_rect(r, BACK)
			draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), WOOD.darkened(0.1))  # the shelf it sits on
			if i >= items.size():
				continue
			var on := i == storage.picked
			var over := r.has_point(mouse)
			if on or over:
				draw_rect(r, Color(BRASS, 0.18 if on else 0.08))
			_pic(i, Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 16)))
			if on:
				draw_rect(r, BRASS, false, 2.0)
			var rar := int((items[i] as Dictionary).get("rarity", ItemDefs.rarity_of(str(items[i].get("id", "")))))
			if rar > 0:
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), ItemDefs.RARITY_COLORS[clampi(rar, 0, 3)])
			_hit(r, "pick", i)
		if items.is_empty():
			draw_string(font, Vector2(g.position.x, g.get_center().y), "Empty. Carry something here and let go of it over the cupboard to put it away.", HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 14, DIM2)
		_side(mouse)

	## The picked thing: its picture, its name and what it is, and the way to take it out.
	func _side(mouse: Vector2) -> void:
		var s := Storage.SIDE
		draw_rect(s, BACK)
		draw_rect(s, WOOD_DARK, false, 2.0)
		var items: Array = storage.contents()
		if storage.picked < 0 or storage.picked >= items.size():
			draw_string(font, Vector2(s.position.x, s.get_center().y), "Nothing picked", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, 13, DIM2)
			return
		var e: Dictionary = items[storage.picked]
		var d := SaveData.unpack(e)
		var x := s.position.x + 16
		var w := s.size.x - 32
		_pic(storage.picked, Rect2(s.position.x + 16, s.position.y + 16, w, 170))
		var y := s.position.y + 210
		var name := str(e.get("custom_name", d.get("name", "Something")))
		var rar := int(d.get("rarity", 0))
		var accent: Color = ItemDefs.RARITY_COLORS[clampi(rar, 0, 3)] if rar > 0 else INK2
		draw_string(font, Vector2(x, y), name, HORIZONTAL_ALIGNMENT_LEFT, w, 18 if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= w else 14, accent)
		y += 20
		var tag := ("%s   %s" % [ItemDefs.RARITY_NAMES[clampi(rar, 0, 3)], str(d.get("kind", "")).capitalize()]).to_upper()
		draw_string(font, Vector2(x, y), tag, HORIZONTAL_ALIGNMENT_LEFT, w, 11, DIM2)
		y += 22
		var rows: Array = [["Condition", "%d%%" % roundi(float(e.get("health", 1.0)) * 100.0)]]
		var dmg: float = storage._pics[storage.picked].damage if storage.picked < storage._pics.size() else -1.0
		if dmg >= 0.0:
			rows.push_front(["Damage", "%d" % roundi(dmg)])
		if int(e.get("boss_kills", 0)) > 0 or int(e.get("kills", 0)) > 0:
			rows.append(["Slain", "%d (%d boss%s)" % [int(e.get("kills", 0)), int(e.get("boss_kills", 0)), "" if int(e.get("boss_kills", 0)) == 1 else "es"]])
		for row in rows:
			draw_string(font, Vector2(x, y + 12), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM2)
			draw_string(font, Vector2(x, y + 13), row[1], HORIZONTAL_ALIGNMENT_RIGHT, w, 14, INK2)
			draw_line(Vector2(x, y + 17), Vector2(x + w, y + 17), Color(INK2, 0.12), 1.0)
			y += 20
		var mods: Array = e.get("modifiers", [])
		if not mods.is_empty():
			y += 4
			var mx := x
			for m in mods:
				var label := str(ItemDefs.MODIFIERS.get(m, {}).get("name", m)).to_upper()
				var mw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10
				if mx + mw > x + w:
					mx = x
					y += 18
				var col: Color = Tooltip.MOD_COLORS.get(m, INK2)
				draw_rect(Rect2(mx, y, mw, 15), Color(col, 0.2))
				draw_rect(Rect2(mx, y, mw, 15), col, false, 1.0)
				draw_string(font, Vector2(mx + 5, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
				mx += mw + 4
			y += 20
		# take it out
		var b := Rect2(x, s.end.y - 52, w, 36)
		var over := b.has_point(mouse)
		draw_rect(b, BRASS.darkened(0.15) if over else BRASS.darkened(0.35))
		draw_rect(b, BRASS, false, 1.5)
		draw_string(font, Vector2(b.position.x, b.position.y + 24), "TAKE OUT", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 16, Color(0.12, 0.07, 0.03))
		_hit(b, "take")

	## A stored thing, pixel for pixel, fitted into `r`.
	func _pic(i: int, r: Rect2) -> void:
		if i >= storage._pics.size():
			return
		var pic: Dictionary = storage._pics[i]
		var lo: Vector2i = pic.lo
		var span: Vector2i = pic.hi - lo + Vector2i.ONE
		var px := minf(8.0, minf(r.size.x / span.x, r.size.y / span.y))
		var org := r.get_center() - Vector2(span) * px * 0.5
		for c in pic.cells:
			draw_rect(Rect2(org + Vector2(c - lo) * px, Vector2(px, px) + Vector2(0.5, 0.5)), pic.cells[c])
