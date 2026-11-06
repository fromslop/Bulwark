class_name Codex
extends CanvasLayer
## The collections at home. Each object on the wall opens its own book, made for what it holds:
##
## - Armoury Ledger (gear): a ruled ledger. Bookmarks sort the gear by kind; a scrolling grid
##   of every piece (found ones drawn, the rest as dark silhouettes); the facing page shows
##   the real thing, live, in each metal it comes in, with its numbers and what it does.
## - Rune Tablet (modifiers and reactions): carved slate with two faces. The runes: every
##   modifier, elemental ones first, then common, then rare in gold. Turned over, the element
##   circle: the five elemental runes round a pentagon, a groove between every pair for the
##   reaction those two set off, lit once you've seen it. The facing side shows a rune on a
##   real piece of gear, or a reaction's two runes side by side, and what it does.
## - Bestiary (foes): bone and vellum, foes by where you meet them; the facing page has a
##   live portrait, their measure, and every attack: click one and the portrait winds it up
##   and swings it, with a little map of where on the screen it lands.
## - Wall Map (places): the way down drawn as a map; each place, clicked, shows through a
##   window on the facing side, with what's there to use and who you meet there.
##
## Open one by pressing Space on it (hand empty, or holding it). Click to pick, the wheel or
## arrow keys to move, Q / E or the spines along the top for the next book, Space or Esc to
## close.

const TABS := ["GEAR", "MODIFIERS", "FOES", "PLACES"]
const BOOKS := [
	{"title": "Armoury Ledger", "item": "codex", "mat": "leather",
		"cover": Color(0.33, 0.19, 0.1), "paper": Color(0.86, 0.79, 0.64), "ink": Color(0.2, 0.13, 0.08),
		"dim": Color(0.46, 0.37, 0.26), "accent": Color(0.66, 0.2, 0.12)},
	{"title": "Rune Tablet", "item": "rune_tablet", "mat": "stone",
		"cover": Color(0.17, 0.17, 0.19), "paper": Color(0.31, 0.32, 0.34), "ink": Color(0.88, 0.92, 0.96),
		"dim": Color(0.62, 0.66, 0.7), "accent": Color(0.55, 0.8, 1.0)},
	{"title": "Bestiary", "item": "bestiary", "mat": "bone",
		"cover": Color(0.78, 0.74, 0.64), "paper": Color(0.8, 0.75, 0.65), "ink": Color(0.17, 0.09, 0.07),
		"dim": Color(0.44, 0.33, 0.27), "accent": Color(0.58, 0.07, 0.07)},
	{"title": "Wall Map", "item": "wall_map", "mat": "cloth",
		"cover": Color(0.36, 0.27, 0.18), "paper": Color(0.78, 0.7, 0.52), "ink": Color(0.24, 0.16, 0.09),
		"dim": Color(0.48, 0.38, 0.25), "accent": Color(0.7, 0.24, 0.14)},
]
const GEAR_SHELVES := [["all", "All"], ["weapon", "Weapons"], ["shield", "Shields"], ["utility", "Utility"],
	["consumable", "Kits & potions"], ["crate", "Crates & junk"], ["ring", "Rings"], ["upgrade", "Hand"]]
const ELEMENTS := ["fire", "frost", "storm", "rot", "venom"]  # (round the circle)
const ELEMENT_RUNE := {"fire": "superheated", "frost": "frosty", "storm": "electrified", "rot": "corrosive", "venom": "poisoned"}
const ELEMENT_OF := {"superheated": "fire", "frosty": "frost", "electrified": "storm", "corrosive": "rot", "poisoned": "venom"}
## Where each element comes from, for a reaction's page.
const ELEMENT_SOURCES := {
	"fire": "a red-hot or burning piece (superheated; held in a wall torch or the forge's heat; set alight)",
	"frost": "a frosty or chilled piece (frosty; dipped in the quench barrel)",
	"storm": "a charged piece (electrified; held to the storm glass; the Ring of the Storm)",
	"rot": "a corrosive piece (corrosive; held in the rust grate)",
	"venom": "a poisoned piece (poisoned; held in a fungus bloom)",
}
const ATTACK_NAMES := {"slash_high_r": "High slash, from the right", "slash_high_l": "High slash, from the left",
	"slash_low": "Low slash", "overhead_l": "Overhead, left", "overhead_r": "Overhead, right", "thrust": "Thrust",
	"sweep": "Rising sweep", "slam": "Slam", 
	"comet": "Comet", "orbit": "Orbit", "unmoor": "Unmooring",
	"chop_l": "Chop, left", "chop_r": "Chop, right", "hew": "Hew", "fell": "Fell", "ground_pound": "Ground pound",
	"maul_low_l": "Low maul, left", "maul_low_r": "Low maul, right", "cut_tl": "Cut, top left", "cut_tr": "Cut, top right",
	"cut_ml": "Cut, middle left", "cut_mr": "Cut, middle right", "cut_tc": "Cut, top centre", "jab": "Jab", "lunge": "Lunge",
	"flick_high": "High flick", "riposte": "Riposte", "drag_low": "Low drag", "rake": "Rake", "spit": "Spit",
	"flail_arc": "Flail arc", "ember_rain": "Ember rain", "brand": "Brand", "grasp": "Grasp", "shroud_l": "Shroud, left",
	"shroud_r": "Shroud, right", "cleave": "Cleave", "low_cleave": "Low cleave", "spark": "Spark", "arc_lash": "Arc lash",
	"lantern_swing": "Lantern swing", "shield_bash": "Shield bash", "tower_slam": "Tower slam"}

# the two pages of every book
const BOOK := Rect2(26, 66, 1228, 640)
const LEFT := Rect2(46, 80, 700, 612)
const RIGHT := Rect2(764, 80, 472, 612)
const VIEW := Vector2i(432, 243)  # the picture window on the right-hand page: the screen's shape
const SHARP := 2  # the window renders at twice its size and is drawn down: crisp lines
const REPLAY_GAP := 1.3  # s after an attack lands before the bestiary swings it again

var _game: Node
var _page: Page
var _hint: Hint
var tab := 0
var selected: Array = ["", "", "", ""]  # per book: the id picked
var scroll: Array = [0.0, 0.0, 0.0, 0.0]
var tablet_face := 0  # the rune tablet: 0 the runes, 1 turned over to the element circle
var shelf := "all"  # the ledger's bookmark
var gear_mat := ""  # the metal the ledger is showing the picked piece in
var attack_pick := -1  # the bestiary's picked attack
var _preview: SubViewport
var _shown := ""  # what the picture window holds (rebuilt when this changes)
var _foe: Enemy
var _swing_t := -1.0  # replaying an attack in the portrait: time since it began
var _telegraph: ZoneOverlay  # the fight's own telegraph, over the portrait
var _replay: Dictionary = {}  # the attack being shown: {zone (px), dir, lanes, windup}


func setup(game: Node) -> void:
	_game = game
	layer = 108
	_preview = SubViewport.new()
	_preview.size = VIEW * SHARP
	_preview.transparent_bg = true
	_preview.own_world_3d = true
	_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_preview)
	_page = Page.new()
	_page.codex = self
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # (the window, drawn down)
	_page.visible = false
	add_child(_page)
	_hint = Hint.new()
	_hint.codex = self
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


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
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _page.visible else SubViewport.UPDATE_DISABLED
	if _page.visible:
		Sfx.play("soft", -6.0, 1.1)
		_pick_default()
	else:
		_clear_preview()
		Sfx.play("soft", -8.0, 0.8)


## Open straight at one book (each object at home opens its own).
func open_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	if not _page.visible:
		toggle()
	else:
		_pick_default()
	_page.reveal_selected = true


func turn(step: int) -> void:
	tab = posmod(tab + step, TABS.size())
	attack_pick = -1
	_pick_default()
	Sfx.play("soft", -8.0, 1.4)


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
	if k == null or not k.pressed or k.echo and not k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_A, KEY_D]:
		return
	match k.keycode:
		KEY_Q:
			turn(-1)
		KEY_E:
			turn(1)
		KEY_SPACE, KEY_ESCAPE:
			toggle()
		KEY_UP, KEY_W:
			_step(-_cols())
		KEY_DOWN, KEY_S:
			_step(_cols())
		KEY_LEFT, KEY_A:
			_step(-1)
		KEY_RIGHT, KEY_D:
			_step(1)
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _page.visible:
		_hint.queue_redraw()
		return
	_page.queue_redraw()
	_sync_preview()
	if _swing_t >= 0.0 and _foe and is_instance_valid(_foe) and not _replay.is_empty():
		_swing_t += delta
		var wind: float = _replay.windup
		var atk: Dictionary = _foe.current
		if _swing_t < wind and (_foe.current.has("pan") or _foe.current.has("turn") or _foe.current.has("chase")):
			# a field that moves: shape it as the wind-up goes, as in a fight
			_foe.progress = _swing_t / wind
			_foe._shape_zone()
			var z := PackedVector2Array()
			for v in _foe.current.zone:
				z.append((v as Vector2) * Vector2(1280, 720))
			_replay.zone = z
			_replay.dir = (_foe.current.dir as Vector2).normalized()
			_replay.lanes = Lanes.build(z, _replay.dir)
			_replay.open = (_replay.lanes as Array).map(func(_l): return 1.0)
		if _swing_t < wind:
			# winding up: the zone fills and the lanes march, as in a fight (and a recorded
			# clip winds up with it, its blow landing where the game's does)
			_foe.progress = clampf(_swing_t / wind, 0.0, 1.0)
			_telegraph.atk = _foe.current
			_telegraph.show_zone(_replay.zone, _swing_t / wind, _replay.dir, clampf(float(atk.get("damage", 30.0)) / 30.0, 0.4, 1.6), str(atk.get("trait", "")))
			_telegraph.lanes = _replay.lanes
			_telegraph.cover = _replay.open
		elif _swing_t - delta < wind:
			# it lands: the flash and every lane lit open (nothing of yours in the way here)
			if _foe.clip_name != "":
				_foe.state = "recover"  # the recorded blow plays its follow-through
			elif Enemy.POSES.has(str(atk.get("pose", ""))):
				_foe._move(Enemy.POSES[atk.pose], "hit", 0.15, Tween.EASE_IN)
			_telegraph.flash(_replay.zone, 1.0)
			_telegraph.lane_result(_replay.lanes, _replay.open)
			_telegraph.clear_zone()
			Sfx.play("swing", -12.0, 0.9)
		if _swing_t >= wind + 0.6 and _foe.state in ["windup", "recover"]:
			_foe.state = "idle"  # (a clip plays its follow-through out into the idle)
			if _foe.clip_name == "":
				_foe._settle()
		if _swing_t >= wind + REPLAY_GAP and attack_pick >= 0:
			play_attack(_replay.id)  # again, so it can be studied
	if _foe and is_instance_valid(_foe):
		# the portrait isn't in a fight (its state machine is off: the book drives it), so its
		# recorded clips are played from here, idle and attacks alike
		_foe._update_clip(delta)


# --- what each book holds ---------------------------------------------------------------

var _cache := {}  # [tab, frame] -> entries: one build per book per frame


## Everything a book lists: [id, known, title, text, kind, def-or-null]
func entries() -> Array:
	var key := "%d:%d" % [tab, Engine.get_process_frames()]
	if not _cache.has(key):
		if _cache.size() > 8:
			_cache.clear()
		_cache[key] = _build_entries()
	return _cache[key]


func _build_entries() -> Array:
	var save: SaveData = _game.save
	var out: Array = []
	match TABS[tab]:
		"GEAR":
			var ids := ItemDefs.DEFS.keys().filter(func(k: String) -> bool:
				return ItemDefs.DEFS[k].kind not in ["coin", "menu", "trophy"] \
					and (not ItemDefs.DEFS[k].get("retired", false) or save.knows("items", k)))  # (retired: only if already found)
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
				out.append([m, save.knows("modifiers", m), str(ItemDefs.MODIFIERS[m].get("name", str(m).capitalize())), str(ItemDefs.MODIFIERS[m].desc), "mod", ItemDefs.MODIFIERS[m]])
			for key in Main.REACTIONS:
				var rx: Dictionary = Main.REACTIONS[key]
				out.append([key, save.knows("reactions", key), str(rx.name).capitalize(), str(key).replace("+", " + ") + ": " + str(rx.desc), "reaction", rx])
		"FOES":
			for id in EnemyDefs.ENEMIES:
				var d: Dictionary = EnemyDefs.ENEMIES[id]
				out.append([d.name, save.knows("foes", d.name), d.name, str(d.get("bio", "")), "boss" if d.get("boss", false) else "foe", d])
			out.append([EnemyDefs.WARDEN.name, save.knows("foes", EnemyDefs.WARDEN.name), EnemyDefs.WARDEN.name, str(EnemyDefs.WARDEN.bio), "foe", EnemyDefs.WARDEN])
		"PLACES":
			for nm in _place_names():
				out.append([nm, save.knows("places", nm), nm, str(Backdrop.BLURB.get(nm, "")), "place", null])
	return out


## The reaction two elements set off, by its key (either way round).
static func reaction_key(a: String, b: String) -> String:
	return a + "+" + b if Main.REACTIONS.has(a + "+" + b) else b + "+" + a


## "the Knight", but "The Astronomer" as it is.
static func the(name: String) -> String:
	return name if name.begins_with("The ") else "the " + name


static func _place_names() -> Array:
	var names: Array = []
	for t in ["early", "middle", "late"]:
		for nm in Backdrop.TIERS[t]:
			if not names.has(nm):
				names.append(nm)
	names.append("Hidden Vault")
	for nm in Secrets.STAGES:
		names.append(nm)
	return names


## The entries the left-hand page shows, in order (the ledger's bookmark applied).
func listed() -> Array:
	var es := entries()
	match TABS[tab]:
		"GEAR":
			if shelf != "all":
				es = es.filter(func(e: Array) -> bool: return _shelf_of(e) == shelf)
		"FOES":
			es = es.duplicate()  # (entries() is cached: sort a copy, by tier then name, the same every time)
			es.sort_custom(func(a: Array, b: Array) -> bool:
				var oa := _foe_order(a[5])
				var ob := _foe_order(b[5])
				return oa < ob if oa != ob else str(a[2]) < str(b[2]))
		"MODIFIERS":
			# the runes' list: elemental, then common, then rare (reactions are on the circle)
			es = es.filter(func(e: Array) -> bool: return e[4] == "mod")
			var rank := func(e: Array) -> int:
				if ELEMENT_OF.has(e[0]):
					return ELEMENTS.find(ELEMENT_OF[e[0]])
				return 30 if e[5].get("epic", false) else (20 if e[5].get("rare", false) else 10)
			es.sort_custom(func(a: Array, b: Array) -> bool: return rank.call(a) < rank.call(b))
	return es


static func _shelf_of(e: Array) -> String:
	match str(e[4]):
		"weapon", "shield", "utility", "ring", "upgrade":
			return str(e[4])
		"consumable", "potion":
			return "consumable"
	return "crate"


## Foes by where you meet them: the way down stage by stage, then deeper, the bosses, the
## guardians of secret places, the vault.
static func _foe_order(d: Dictionary) -> int:
	var nm: String = d.name
	for i in EnemyDefs.TIERS.size():
		if Codex._names(EnemyDefs.TIERS[i]).has(nm):
			return i * 10
	if d.has("prestige"):
		return 50 + int(d.get("tier", 0))
	for i in EnemyDefs.BOSSES.size():
		if Codex._names(EnemyDefs.BOSSES[i]).has(nm):
			return 60 + i
	if d.get("secret", false):
		return 70
	return 80


static func foe_where(d: Dictionary) -> String:
	var nm: String = d.name
	for i in EnemyDefs.TIERS.size():
		if Codex._names(EnemyDefs.TIERS[i]).has(nm):
			return "Stage %d of the way down" % (i + 1)
	if d.has("prestige"):
		return "Deeper runs: prestige %d and on, from stage %d" % [int(d.prestige), int(d.get("tier", 0)) + 1]
	for i in EnemyDefs.BOSSES.size():
		if Codex._names(EnemyDefs.BOSSES[i]).has(nm):
			return "Boss of the fifth stage" + (" (prestige 1 and on)" if i > 0 and not Codex._names(EnemyDefs.BOSSES[0]).has(nm) else "")
	for st in Secrets.STAGES:
		if Secrets.STAGES[st].foe == nm:
			return "Guards the " + str(st)
	return "Guards the Hidden Vault"


func _foe_home(d: Dictionary) -> String:
	var nm: String = d.name
	for st in Secrets.STAGES:
		if Secrets.STAGES[st].foe == nm:
			return st
	if d == EnemyDefs.WARDEN or nm == EnemyDefs.WARDEN.name:
		return "Hidden Vault"
	var o := _foe_order(d)
	if o < 10:
		return "Dungeon Cell"
	if o < 30:
		return "Corridor" if o < 20 else "Cistern"
	if o < 60:
		return "Catacombs"
	return "Crypt Chapel"


func _cols() -> int:
	return 6 if TABS[tab] == "GEAR" else 1


func _pick_default() -> void:
	var es := listed()
	if es.is_empty():
		selected[tab] = ""
		return
	for e in es:
		if e[0] == selected[tab]:
			return
	selected[tab] = es[0][0]
	for e in es:
		if e[1]:
			selected[tab] = e[0]
			break
	gear_mat = ""
	attack_pick = -1


func pick(id: String) -> void:
	if selected[tab] != id:
		selected[tab] = id
		gear_mat = ""
		attack_pick = -1
		Sfx.play("soft", -12.0, 1.6)


func _step(d: int) -> void:
	var es := listed()
	if TABS[tab] == "PLACES":
		es = entries()
	if es.is_empty():
		return
	var i := 0
	for k in es.size():
		if es[k][0] == selected[tab]:
			i = k
	pick(es[clampi(i + d, 0, es.size() - 1)][0])
	_page.reveal_selected = true


func entry(id: String) -> Array:
	for e in entries():
		if e[0] == id:
			return e
	return []


static var _lane_counts := {}  # attack id -> lanes (they never change)


# --- the picture window -----------------------------------------------------------------

## Keep the picture window showing whatever's picked: a live item, a foe, a place.
func _sync_preview() -> void:
	var e := entry(selected[tab])
	var want := ""
	if not e.is_empty():
		match TABS[tab]:
			"GEAR":
				want = "item:%s:%s:%s" % [e[0], _gear_material(e), str(e[1])]
			"MODIFIERS":
				want = "%s:%s:%s" % [e[4], e[0], str(e[1])]
			"FOES":
				want = "foe:%s" % e[0] if e[1] else ""
			"PLACES":
				want = "place:%s" % e[0] if e[1] else ""
	if want == _shown:
		return
	_clear_preview()
	_shown = want
	if want == "":
		return
	match TABS[tab]:
		"GEAR":
			var d: Dictionary
			if e[4] in ["ring", "upgrade"]:
				d = ItemDefs.make_upgrade(e[0])
			else:
				d = ItemDefs.make(e[0], _gear_material(e))
			_show_item(d, not e[1])
		"MODIFIERS":
			if e[4] == "reaction":
				# the two runes that make it, side by side
				var pair: Array = []
				for el in str(e[0]).split("+"):
					pair.append(ItemDefs.make("dagger", "iron", [ELEMENT_RUNE[el]]))
				_show_items(pair, false)
				return
			var m: String = e[0]
			var md: Dictionary = e[5]
			var base := "round_shield" if md.get("kinds", []).has("shield") else ("longsword" if md.get("rare", false) else "shortsword")
			if m in ["small", "large", "huge", "weightless", "heavy", "bouncy", "magnetic", "volatile"]:
				base = "buckler"
			_show_item(ItemDefs.make(base, "iron", [m]), not e[1])
		"FOES":
			_show_foe(e[5])
		"PLACES":
			_show_place(e[0])


func _gear_material(e: Array) -> String:
	if e[4] in ["ring", "upgrade"]:
		return str(e[5].get("material", "gold"))
	var mats: Array = e[5].get("materials", ["wood"])
	return gear_mat if mats.has(gear_mat) else str(mats[mats.size() - 1])


func _clear_preview() -> void:
	_shown = ""
	_foe = null
	_telegraph = null
	_replay = {}
	_swing_t = -1.0
	for c in _preview.get_children():
		_preview.remove_child(c)
		c.queue_free()


## A real item, frozen in the window, its effects moving; a silhouette if not found yet.
func _show_item(d: Dictionary, silhouette: bool) -> void:
	_show_items([d], silhouette)


## Real items side by side in the window (long ones lying across it), framed together.
func _show_items(defs: Array, silhouette: bool) -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	var x := 0.0
	for d in defs:
		var it := Item.create(d)
		it.remove_from_group("items")  # (not part of the game: nothing counts or touches it)
		it.remove_from_group("coins")
		it.remove_from_group("debris")
		it.owned = false
		it.freeze = true
		var a := Vector2(INF, INF)
		var b := -a
		for c in it.cells:
			a = a.min(it.cell_pos(c))
			b = b.max(it.cell_pos(c))
		if b.y - a.y > (b.x - a.x) * 1.4 and defs.size() == 1:
			it.rotation = PI / 2.0  # a long thing alone lies across the window
		a = Vector2(INF, INF)
		b = -a
		for c in it.cells:
			var p: Vector2 = it.transform * it.cell_pos(c)
			a = a.min(p)
			b = b.max(p)
		it.position = Vector2(x - a.x, 0)
		lo = lo.min(a + it.position)
		hi = hi.max(b + it.position)
		x += (b.x - a.x) + 60.0
		if silhouette:
			it.modulate = Color(0.05, 0.04, 0.04, 0.85)
		_preview.add_child(it)
	var size := hi - lo + Vector2(Item.CELL, Item.CELL)
	var cam := Camera2D.new()
	cam.position = (lo + hi) * 0.5
	var zoom := clampf(minf(VIEW.x * 0.75 / size.x, VIEW.y * 0.72 / size.y), 0.5, 4.0) * SHARP
	cam.zoom = Vector2(zoom, zoom)
	_preview.add_child(cam)
	cam.make_current()


func _env3d(place: String, bright: float) -> void:
	var e: Dictionary = Backdrop.ENV.get(place, {"fog": 0.15, "fog_color": Color(0.02, 0.02, 0.02), "ambient": 0.4})
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = float(e.ambient) + bright
	env.fog_enabled = float(e.fog) > 0.0
	env.fog_light_color = e.fog_color
	env.fog_density = float(e.fog) * 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_preview.add_child(we)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.9, 2.2, 1.0)
	lamp.light_color = Color(1.0, 0.72, 0.45)
	lamp.light_energy = 2.2
	lamp.omni_range = 6.0
	_preview.add_child(lamp)


## A foe in the kind of place you meet it, seen exactly as in a fight (the fight's camera,
## the screen's shape), so its attacks' telegraphs land where they would on your screen.
func _show_foe(d: Dictionary) -> void:
	var home := _foe_home(d)
	_env3d(home, 0.25)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(0, 1.45, 1.5)
	_preview.add_child(cam)
	_preview.add_child(Backdrop.create(home))
	var foe := Enemy.new()
	foe.setup(d.duplicate(true), cam)
	foe.active = false
	_preview.add_child(foe)
	_foe = foe
	var screen := Node2D.new()  # the play field, shrunk into the window
	screen.scale = Vector2.ONE * float(VIEW.x * SHARP) / 1280.0
	_preview.add_child(screen)
	_telegraph = ZoneOverlay.new()
	screen.add_child(_telegraph)
	if attack_pick < 0:
		attack_pick = 0
	play_attack(str(attack_ids(d)[attack_pick]))


## A place, as you'd see it standing in it.
func _show_place(nm: String) -> void:
	_env3d(nm, 0.1)
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.position = Vector3(0, 1.45, 1.9)
	_preview.add_child(cam)
	_preview.add_child(Backdrop.create(nm))


## The bestiary's attack, played in the portrait: wound up with its telegraph over the
## screen, lanes and all, at its real speed, then swung; and again, till another is picked.
func play_attack(id: String) -> void:
	if _foe == null or not is_instance_valid(_foe) or not EnemyDefs.ATTACKS.has(id):
		return
	_foe.state = "idle"
	_foe.look_target = Vector2(0.5, 0.55)  # (an attack that aims at your hand aims mid-screen)
	_foe._begin_attack(id)
	var zone := PackedVector2Array()
	for v in _foe.current.zone:
		zone.append((v as Vector2) * Vector2(1280, 720))
	var dir: Vector2 = (_foe.current.dir as Vector2).normalized()
	var lanes := Lanes.build(zone, dir)
	var open: Array = []
	for l in lanes:
		open.append(1.0)
	_replay = {"id": id, "zone": zone, "dir": dir, "lanes": lanes, "open": open, "windup": _foe._windup_total}
	_swing_t = 0.0


## The names foes go by (as the save and the codex know them) for a list of their keys.
static func _names(keys: Array) -> Array:
	return keys.map(func(k: String) -> String: return str(EnemyDefs.ENEMIES[k].name) if EnemyDefs.ENEMIES.has(k) else k)


## A foe's attacks, each once (a pool repeats an attack to make it more likely).
static func attack_ids(d: Dictionary) -> Array:
	var out: Array = []
	for id in d.attacks:
		if not out.has(id):
			out.append(id)
	return out


## How many lanes an attack comes down (the arrows its telegraph shows).
static func lane_count(id: String) -> int:
	if _lane_counts.has(id):
		return _lane_counts[id]
	_lane_counts[id] = _count_lanes(id)
	return _lane_counts[id]


static func _count_lanes(id: String) -> int:
	var a: Dictionary = EnemyDefs.ATTACKS[id]
	var zone := PackedVector2Array()
	for v in a.zone:
		zone.append((v as Vector2) * Vector2(1280, 720))
	return Lanes.build(zone, (a.dir as Vector2).normalized()).size()


func preview_texture() -> Texture2D:
	return _preview.get_texture()


## Space on a collection at home, hand empty: what the little prompt over it says.
class Hint:
	extends Tooltip.Drawn

	var codex: Codex

	func _draw() -> void:
		var game: Node = codex._game
		if game == null or game.state != game.State.HOME or game.hand.held != null or game.hand.inspecting():
			return
		var it: Item = game.hand.item_under(game.hand.position)
		if it == null or it.def.kind != "menu":
			return
		var label := "%s   ·   SPACE to open" % it.def.title
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20
		var at := (it.global_position + Vector2(-w * 0.5, 34)).clamp(Vector2(8, 8), Vector2(1272 - w, 690))
		draw_rect(Rect2(at, Vector2(w, 22)), Color(0.08, 0.06, 0.05, 0.85))
		draw_rect(Rect2(at, Vector2(w, 22)), Color(0.85, 0.65, 0.3, 0.6), false, 1.0)
		draw_string(font, at + Vector2(10, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


## The open book.
class Page:
	extends Tooltip.Drawn

	var codex: Codex
	var reveal_selected := false
	var _hits: Array = []  # [Rect2, action, arg] laid down by the last draw
	var _list_h := 0.0  # how tall the scrolling list is (for the scroll limits)
	var _list_rect := Rect2()
	var _sel_rect := Rect2()
	var _b: Dictionary  # the open book's look

	# --- input ---------------------------------------------------------------------------

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll(-48.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(48.0)
			MOUSE_BUTTON_LEFT:
				for i in range(_hits.size() - 1, -1, -1):
					var h: Array = _hits[i]
					if (h[0] as Rect2).has_point(mb.position):
						_act(h[1], h[2], mb.position)
						break
			MOUSE_BUTTON_RIGHT:
				codex.toggle()
		accept_event()

	func _scroll(d: float) -> void:
		var t := codex.tab
		codex.scroll[t] = clampf(float(codex.scroll[t]) + d, 0.0, maxf(0.0, _list_h - _list_rect.size.y))

	func _act(what: String, arg: Variant, at: Vector2) -> void:
		match what:
			"book":
				codex.tab = int(arg)
				codex.attack_pick = -1
				codex._pick_default()
				Sfx.play("soft", -8.0, 1.4)
			"close":
				codex.toggle()
			"face":
				codex.tablet_face = int(arg)
				codex.scroll[1] = 0.0
				Sfx.play("clang", -16.0, 1.6)  # the slab turned over
			"pick":
				codex.pick(str(arg))
			"shelf":
				codex.shelf = str(arg)
				codex.scroll[0] = 0.0
				codex._pick_default()
				Sfx.play("soft", -10.0, 1.8)
			"mat":
				codex.gear_mat = str(arg)
				Sfx.play("ting", -14.0, 1.6)
			"attack":
				codex.attack_pick = int(arg)
				var d: Dictionary = codex.entry(codex.selected[codex.tab])[5]
				codex.play_attack(str(Codex.attack_ids(d)[int(arg)]))
			"bar":
				var r := arg as Rect2
				var f := clampf((at.y - r.position.y) / r.size.y, 0.0, 1.0)
				codex.scroll[codex.tab] = f * maxf(0.0, _list_h - _list_rect.size.y)

	func _hit(r: Rect2, what: String, arg: Variant = null) -> void:
		_hits.append([r, what, arg])

	# --- the book ------------------------------------------------------------------------

	func _draw() -> void:
		_hits.clear()
		_b = Codex.BOOKS[codex.tab]
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
		_spines()
		_cover()
		match Codex.TABS[codex.tab]:
			"GEAR":
				_ledger()
			"MODIFIERS":
				_tablet()
			"FOES":
				_bestiary()
			"PLACES":
				_map()
		if reveal_selected:
			reveal_selected = false
			_keep_in_view(_sel_rect)

	func _keep_in_view(r: Rect2) -> void:
		if r.size == Vector2.ZERO or _list_rect.size == Vector2.ZERO:
			return
		var t := codex.tab
		if r.position.y < _list_rect.position.y:
			_scroll(r.position.y - _list_rect.position.y - 8.0)
		elif r.end.y > _list_rect.end.y:
			_scroll(r.end.y - _list_rect.end.y + 8.0)

	## The five books along the top: the open one pulled out, the rest to click.
	func _spines() -> void:
		var mouse := get_local_mouse_position()
		var x := 34.0
		for i in Codex.BOOKS.size():
			var bk: Dictionary = Codex.BOOKS[i]
			var label: String = bk.title
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 52
			var on := i == codex.tab
			var r := Rect2(x, 22 if on else 28, w, 44 if on else 36)
			var over := r.has_point(mouse)
			draw_rect(r, (bk.cover as Color).lightened(0.12 if over and not on else 0.0))
			draw_rect(r, (bk.accent as Color) if on else Color(0, 0, 0, 0.5), false, 2.0 if on else 1.0)
			_mask_pic(ItemDefs.DEFS[bk.item].shape, bk.mat, Rect2(r.position + Vector2(6, 5), Vector2(28, 26)), {})
			var tc: Color = Color(0.95, 0.9, 0.8) if (bk.cover as Color).get_luminance() < 0.5 else Color(0.15, 0.1, 0.05)
			var found: Array = codex.progress(i)
			draw_string(font, r.position + Vector2(40, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)
			draw_string(font, r.position + Vector2(40, 30), "%d / %d" % [found[0], found[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tc, 0.65))
			_hit(r, "book", i)
			x += w + 6
		# how it works, and the way out
		var tip := "click to pick   ·   wheel or arrows to move   ·   Q / E next book   ·   SPACE closes"
		draw_string(font, Vector2(x + 14, 50), tip, HORIZONTAL_ALIGNMENT_LEFT, 1230 - x - 60, 10, Color(0.75, 0.7, 0.62))
		var close := Rect2(1222, 26, 32, 32)
		draw_rect(close, Color(0.15, 0.1, 0.08, 0.9) if not close.has_point(mouse) else Color(0.45, 0.15, 0.1))
		draw_rect(close, Color(0.85, 0.65, 0.3, 0.7), false, 1.0)
		draw_line(close.position + Vector2(10, 10), close.end - Vector2(10, 10), INK, 2.0)
		draw_line(Vector2(close.end.x - 10, close.position.y + 10), Vector2(close.position.x + 10, close.end.y - 10), INK, 2.0)
		_hit(close, "close")

	## The binding and the two pages, in the book's own materials.
	func _cover() -> void:
		var cover: Color = _b.cover
		var paper: Color = _b.paper
		draw_rect(Rect2(BOOK.position + Vector2(6, 8), BOOK.size), Color(0, 0, 0, 0.5))
		draw_rect(BOOK, cover)
		draw_rect(BOOK.grow(-4), cover.darkened(0.25), false, 2.0)
		for pg in [LEFT, RIGHT]:
			var r: Rect2 = pg
			draw_rect(r.grow(4), paper.darkened(0.18))
			draw_rect(r, paper)
		# the gutter between the pages
		var gx := (LEFT.end.x + RIGHT.position.x) * 0.5
		draw_rect(Rect2(gx - 9, LEFT.position.y - 4, 18, LEFT.size.y + 8), cover.darkened(0.35))
		for i in 12:
			draw_line(Vector2(gx - 9 + i, LEFT.position.y), Vector2(gx - 9 + i, LEFT.end.y), Color(0, 0, 0, 0.04 * (12 - i)), 1.0)

	func _title(at: Vector2, text: String, size: int = 22) -> void:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _b.ink)

	func _text(at: Vector2, text: String, width: float, size: int = 12, col: Variant = null, lines: int = -1) -> float:
		var c: Color = _b.dim if col == null else col
		draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, lines, c)
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, lines)
		return sz.y

	## The picture window on the right-hand page, framed in the book's way.
	func _window(at: Vector2, empty_text: String) -> Rect2:
		var r := Rect2(at, Vector2(Codex.VIEW))
		draw_rect(r.grow(5), (_b.cover as Color).darkened(0.2))
		draw_rect(r, Color(0.05, 0.045, 0.04))
		if codex._shown != "":
			draw_texture_rect(codex.preview_texture(), r, false)
		else:
			draw_string(font, r.position + Vector2(0, r.size.y * 0.5 + 6), empty_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(0.5, 0.45, 0.4))
		draw_rect(r, Color(1, 1, 1, 0.08), false, 1.0)
		return r

	func _scrollbar() -> void:
		if _list_h <= _list_rect.size.y:
			return
		var track := Rect2(_list_rect.end.x + 4, _list_rect.position.y, 6, _list_rect.size.y)
		draw_rect(track, Color(0, 0, 0, 0.12))
		var f: float = float(codex.scroll[codex.tab]) / maxf(1.0, _list_h - _list_rect.size.y)
		var h := maxf(30.0, track.size.y * _list_rect.size.y / _list_h)
		draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - h) * f, 6, h), Color(_b.accent, 0.7))
		_hit(track.grow(4), "bar", track)

	## How much of a row is inside the scrolling list: 0 none, 1 some, 2 all. A row only partly
	## in draws as just its clipped background, as if sliding under the edge of the page.
	func _shown(r: Rect2) -> int:
		if r.end.y <= _list_rect.position.y or r.position.y >= _list_rect.end.y:
			return 0
		if r.position.y < _list_rect.position.y or r.end.y > _list_rect.end.y:
			draw_rect(r.intersection(_list_rect), Color(_b.ink, 0.05))
			return 1
		return 2

	func _counter(text: String) -> void:
		draw_string(font, Vector2(LEFT.end.x - 220, LEFT.end.y - 10), text, HORIZONTAL_ALIGNMENT_RIGHT, 210, 11, _b.dim)

	# --- Armoury Ledger ------------------------------------------------------------------

	func _ledger() -> void:
		var ink: Color = _b.ink
		var mouse := get_local_mouse_position()
		# the ledger's ruling: a red margin and pale lines
		for y in range(int(LEFT.position.y) + 34, int(LEFT.end.y), 22):
			draw_line(Vector2(LEFT.position.x, y), Vector2(LEFT.end.x, y), Color(0.3, 0.45, 0.7, 0.1), 1.0)
		draw_line(Vector2(LEFT.position.x + 30, LEFT.position.y), Vector2(LEFT.position.x + 30, LEFT.end.y), Color(0.75, 0.2, 0.15, 0.35), 1.0)
		draw_arc(Vector2(LEFT.end.x - 70, LEFT.end.y - 60), 34.0, 0.4, 5.6, 32, Color(0.45, 0.3, 0.15, 0.12), 6.0)  # a mug's ring
		# bookmarks: the shelves of the armoury
		var x := LEFT.position.x + 8
		for s in Codex.GEAR_SHELVES:
			var w := font.get_string_size(s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18
			var on: bool = codex.shelf == s[0]
			var r := Rect2(x, LEFT.position.y + 6, w, 24)
			draw_rect(r, Color(_b.accent, 0.85) if on else Color(ink, 0.08 if not r.has_point(mouse) else 0.16))
			draw_string(font, r.position + Vector2(9, 17), s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.85) if on else ink)
			_hit(r, "shelf", s[0])
			x += w + 4
		# the grid of gear
		var es := codex.listed()
		_list_rect = Rect2(LEFT.position.x + 10, LEFT.position.y + 40, LEFT.size.x - 30, LEFT.size.y - 66)
		var tile := Vector2(108, 112)
		var cols := 6
		_list_h = ceilf(es.size() / float(cols)) * tile.y
		var top := _list_rect.position.y - float(codex.scroll[0])
		var known := 0
		_sel_rect = Rect2()
		for i in es.size():
			var e: Array = es[i]
			if e[1]:
				known += 1
			var r := Rect2(Vector2(_list_rect.position.x + (i % cols) * tile.x, top + int(i / cols) * tile.y), tile - Vector2(8, 8))
			var sel: bool = e[0] == codex.selected[0]
			if sel:
				_sel_rect = r
			if _shown(r) < 2:
				continue
			var over := r.has_point(mouse) and _list_rect.has_point(mouse)
			var rar := ItemDefs.rarity_of(e[0]) if ItemDefs.DEFS.has(e[0]) else 1
			draw_rect(r, Color(1, 1, 1, 0.35 if sel else (0.22 if over else 0.12)))
			draw_rect(r, Color(_b.accent, 0.9) if sel else Color(ink, 0.25), false, 2.0 if sel else 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), ItemDefs.RARITY_COLORS[rar] if e[1] else Color(ink, 0.15))
			var pic := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 62))
			_gear_pic(e, pic, e[1])
			var title: String = e[2] if e[1] else "???"
			draw_string(font, r.position + Vector2(4, r.size.y - 22), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 11, ink if e[1] else Color(ink, 0.35))
			if e[1]:
				draw_string(font, r.position + Vector2(4, r.size.y - 8), ItemDefs.RARITY_NAMES[rar].to_lower() if ItemDefs.DEFS.has(e[0]) else str(e[4]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 9, _b.dim)
			if _list_rect.has_point(mouse):
				_hit(r, "pick", e[0])
		_scrollbar()
		_counter("%d of %d in the ledger" % [known, es.size()])
		_gear_detail()

	func _gear_detail() -> void:
		var e := codex.entry(codex.selected[0])
		var x := RIGHT.position.x + 16
		var w := RIGHT.size.x - 32
		if e.is_empty():
			return
		var d: Dictionary = e[5]
		var known: bool = e[1]
		var rar := ItemDefs.rarity_of(e[0]) if ItemDefs.DEFS.has(e[0]) else 1
		_title(Vector2(x, RIGHT.position.y + 30), e[2] if known else "Not found yet")
		var kind_line := "%s %s" % [ItemDefs.RARITY_NAMES[rar], _kind_name(e)] if known else "Something you haven't laid hands on"
		if known and ItemDefs.PRESTIGE.has(e[0]):
			kind_line += "   ·   from prestige %d" % ItemDefs.PRESTIGE[e[0]]
		draw_string(font, Vector2(x, RIGHT.position.y + 48), kind_line, HORIZONTAL_ALIGNMENT_LEFT, w, 12, ItemDefs.RARITY_COLORS[rar].darkened(0.35) if known else _b.dim)
		var win := _window(Vector2(x + (w - Codex.VIEW.x) * 0.5, RIGHT.position.y + 60), "")
		var y := win.end.y + 16
		if not known:
			_text(Vector2(x, y + 10), "Its shape is all the ledger has. Find one in a shop, a crate or a fight and it's written in.", w, 13)
			return
		# the metals it comes in: click one to see it in that
		var mats: Array = d.get("materials", []) if not e[4] in ["ring", "upgrade"] else []
		if mats.size() > 1:
			var mx := x
			var cur := codex._gear_material(e)
			for m in mats:
				var label := str(m)
				var mw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 26
				var r := Rect2(mx, y, mw, 20)
				var on: bool = m == cur
				draw_rect(r, Color(_b.ink, 0.12) if not on else Color(_b.accent, 0.25))
				draw_rect(r, Color(_b.accent, 0.9) if on else Color(_b.ink, 0.3), false, 1.0)
				draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(10, 10)), Materials.get_mat(m).color)
				draw_string(font, r.position + Vector2(19, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.ink)
				_hit(r, "mat", m)
				mx += mw + 4
			y += 30
		var mdesc: String = Materials.DESC.get(codex._gear_material(e), "")
		if mdesc != "" and not e[4] in ["ring", "upgrade"]:
			draw_string(font, Vector2(x, y + 8), "%s: %s" % [codex._gear_material(e).capitalize(), mdesc], HORIZONTAL_ALIGNMENT_LEFT, w, 11, _b.dim)
			y += 18
		# numbers: a fresh one in the material shown (damage: a full swing, before rings)
		var rows: Array = []
		if d.has("swing_damage"):
			var dmg: float = ItemDefs.fresh_damage(e[0], codex._gear_material(e)) if ItemDefs.DEFS.has(e[0]) else float(d.swing_damage) * ItemDefs.WEAPON_DAMAGE
			rows.append(["Damage", "%d" % roundi(dmg)])
			rows.append(["Swing speed", "%.0f" % float(d.get("swing_speed", 10.0))])
			rows.append(["Recovery", "%.1fs" % float(d.get("cooldown", 1.0))])
		if e[4] in ["shield", "weapon"]:
			var mat := Materials.get_mat(codex._gear_material(e))
			rows.append(["Blocks", "%d%%" % roundi(float(mat.block) * 100.0)])
			rows.append(["Toughness", "%.0f" % float(mat.hp)])
		if d.has("heal"):
			rows.append(["Heals", "%d" % int(d.heal)])
		var price: int = int(d.get("price", d.get("cost", 0)))
		if price > 0:
			rows.append(["Price", "%d" % price])
		y += _ledger_figures(Vector2(x, y), w, 2, rows) + 8
		var txt: String = e[3]
		if d.has("ascended_effect"):
			txt += "\n" + str(d.ascended_effect)
		if d.has("fixed_mods"):
			txt += "\nAlways: " + ", ".join(PackedStringArray(d.fixed_mods))
		if txt.strip_edges() != "":
			_text(Vector2(x, y + 12), txt, w, 12, _b.ink, maxi(1, int((RIGHT.end.y - y - 10) / 15.0)))

	static func _kind_name(e: Array) -> String:
		match str(e[4]):
			"upgrade":
				return "hand upgrade"
			"consumable":
				return "kit"
		return str(e[4])

	## A piece's pixel picture: its mask in its own materials (a dark silhouette if not found).
	func _gear_pic(e: Array, r: Rect2, known: bool) -> void:
		var d: Dictionary = e[5]
		var mat: String = d.get("material", d.materials[d.materials.size() - 1] if d.has("materials") else "wood")
		_mask_pic(str(d.get("shape", "")), mat, r, d, not known)

	func _mask_pic(shape: String, mat: String, r: Rect2, d: Dictionary, dark: bool = false) -> void:
		var mask := ItemDefs.shape_mask(shape)
		if mask.is_empty():
			return
		var w := mask[0].length()
		var h := mask.size()
		var px := minf(6.0, minf(r.size.x / w, r.size.y / h))
		var org := r.get_center() - Vector2(w, h) * px * 0.5
		for yy in h:
			for xx in w:
				var ch: String = mask[yy][xx]
				if ch == ".":
					continue
				var m: String = mat if ch == "M" else (ItemDefs.grip_mat(mat) if ch == "h" else ItemDefs.MASK_MATS.get(ch, mat))
				var col: Color = d.gem if ch == "g" and d.has("gem") else Materials.get_mat(m).color
				if m == "glass" and d.has("liquid_color"):
					col = (d.liquid_color as Color).lerp(Color(1, 1, 1), 0.2)  # a potion shows what's in it
				if dark:
					col = Color(0.12, 0.09, 0.07, 0.75)
				draw_rect(Rect2(org + Vector2(xx, yy) * px, Vector2(px, px)), col)

	# --- Rune Tablet ---------------------------------------------------------------------
	# Two faces: the runes, every modifier carved in a list (elemental, common, rare); and,
	# turned over, the element circle: the five elemental runes round a pentagon, a groove
	# between every pair for the reaction they set off, lit once you've seen it.

	func _tablet() -> void:
		var ink: Color = _b.ink
		var mouse := get_local_mouse_position()
		# carved slate: a chiselled border and a crack
		draw_rect(LEFT.grow(-6), Color(0, 0, 0, 0.18), false, 3.0)
		draw_rect(RIGHT.grow(-6), Color(0, 0, 0, 0.18), false, 3.0)
		draw_polyline(PackedVector2Array([Vector2(LEFT.end.x - 30, LEFT.position.y), Vector2(LEFT.end.x - 44, LEFT.position.y + 14), Vector2(LEFT.end.x - 38, LEFT.position.y + 26), Vector2(LEFT.end.x - 52, LEFT.position.y + 36)]), Color(0, 0, 0, 0.3), 1.5)
		# the two faces, as carved tabs along the top
		var x := LEFT.position.x + 12
		for i in 2:
			var label: String = ["RUNES", "THE ELEMENT CIRCLE"][i]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 26
			var r := Rect2(x, LEFT.position.y + 8, w, 26)
			var on := codex.tablet_face == i
			draw_rect(r, Color(_b.accent, 0.3) if on else Color(0, 0, 0, 0.15 if not r.has_point(mouse) else 0.25))
			draw_rect(r, Color(_b.accent, 0.9) if on else Color(ink, 0.25), false, 1.0)
			draw_string(font, r.position + Vector2(13, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink if on else _b.dim)
			_hit(r, "face", i)
			x += w + 6
		var es := codex.entries()
		var known := 0
		for e in es:
			if e[1]:
				known += 1
		_counter("%d of %d read" % [known, es.size()])
		if codex.tablet_face == 0:
			_rune_list(mouse)
		else:
			_element_circle(mouse)
		_tablet_detail()

	func _rune_list(mouse: Vector2) -> void:
		var ink: Color = _b.ink
		var es := codex.listed()
		_list_rect = Rect2(LEFT.position.x + 14, LEFT.position.y + 44, LEFT.size.x - 34, LEFT.size.y - 70)
		var y := _list_rect.position.y - float(codex.scroll[1])
		var start_y := y
		var group := ""
		_sel_rect = Rect2()
		for e in es:
			var md: Dictionary = e[5]
			var g := "elemental" if Codex.ELEMENT_OF.has(e[0]) else ("epic" if md.get("epic", false) else ("rare" if md.get("rare", false) else "common"))
			if g != group:
				group = g
				if y >= _list_rect.position.y and y + 30 <= _list_rect.end.y:
					var head: String = {"elemental": "ELEMENTAL RUNES  ·  each marks a foe; two marks react (the circle, over the page)",
						"common": "COMMON RUNES  ·  on any gear", "rare": "RARE RUNES  ·  conditional: meet the condition and they pay out big",
						"epic": "EPIC RUNES  ·  the rarest: they bend to whatever element the piece carries"}[g]
					draw_string(font, Vector2(_list_rect.position.x + 4, y + 22), head, HORIZONTAL_ALIGNMENT_LEFT, _list_rect.size.x - 8, 12, Tooltip.EPIC if g == "epic" else (Color(1.0, 0.8, 0.35) if g == "rare" else _b.accent))
				y += 32
			var r := Rect2(_list_rect.position.x, y, _list_rect.size.x, 38)
			var sel: bool = e[0] == codex.selected[1]
			if sel:
				_sel_rect = r
			if _shown(r) == 2:
				var over := r.has_point(mouse) and _list_rect.has_point(mouse)
				draw_rect(r, Color(1, 1, 1, 0.14 if sel else (0.08 if over else 0.03)))
				if sel:
					draw_rect(r, Color(_b.accent, 0.8), false, 1.5)
				var col: Color = _rune_color(e[0], md)
				_rune(r.position + Vector2(22, 19), col if e[1] else Color(0, 0, 0, 0.35), e[0])
				draw_string(font, r.position + Vector2(46, 16), e[2] if e[1] else "???", HORIZONTAL_ALIGNMENT_LEFT, 180, 14, ink if e[1] else Color(ink, 0.35))
				if Codex.ELEMENT_OF.has(e[0]):
					var el: String = Codex.ELEMENT_OF[e[0]]
					var tw := font.get_string_size(el, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12
					var tag := Rect2(r.end.x - tw - 8, r.position.y + 6, tw, 16)
					draw_rect(tag, Color(Main.ELEMENT_COLORS[el], 0.35))
					draw_string(font, tag.position + Vector2(6, 12), el, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Main.ELEMENT_COLORS[el].lightened(0.3))
				if e[1]:
					draw_string(font, r.position + Vector2(46, 31), e[3], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 10, _b.dim)
				if _list_rect.has_point(mouse):
					_hit(r, "pick", e[0])
			y += 42
		_list_h = y - start_y
		_scrollbar()

	## The five elemental runes round a pentagon; a groove between every pair for the
	## reaction those two set off, lit in both colours once you've seen it; and every
	## reaction named on a chip below, to pick.
	func _element_circle(mouse: Vector2) -> void:
		var ink: Color = _b.ink
		_list_rect = Rect2()
		_list_h = 0.0
		var c := Vector2(LEFT.position.x + LEFT.size.x * 0.5, LEFT.position.y + 232)
		var rad := 158.0
		var pos := {}
		for i in Codex.ELEMENTS.size():
			var ang := -PI / 2.0 + TAU * i / Codex.ELEMENTS.size()
			pos[Codex.ELEMENTS[i]] = c + Vector2(cos(ang), sin(ang)) * rad
		draw_arc(c, rad + 34.0, 0.0, TAU, 64, Color(0, 0, 0, 0.2), 3.0)
		draw_arc(c, rad - 34.0, 0.0, TAU, 64, Color(0, 0, 0, 0.12), 2.0)
		var sel: String = codex.selected[1]
		# the grooves: one per reaction
		var hover_key := ""
		for key in Main.REACTIONS:
			var els: PackedStringArray = str(key).split("+")
			var a: Vector2 = pos[els[0]]
			var b: Vector2 = pos[els[1]]
			var e := codex.entry(key)
			var near := Geometry2D.get_closest_point_to_segment(mouse, a, b).distance_to(mouse) < 9.0 and mouse.distance_to(a) > 30.0 and mouse.distance_to(b) > 30.0
			if near:
				hover_key = key
			var lit: bool = e[1]
			var on: bool = sel == key or near
			var width := 5.0 if on else 3.0
			draw_line(a, b, Color(0, 0, 0, 0.35), width + 3.0)
			if lit:
				var n := 16
				for k in n:
					var t0 := float(k) / n
					var t1 := float(k + 1) / n
					var col: Color = Main.ELEMENT_COLORS[els[0]].lerp(Main.ELEMENT_COLORS[els[1]], (t0 + t1) * 0.5)
					draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(col, 0.95 if on else 0.7), width)
			else:
				_dashed_line(a, b, Color(ink, 0.45 if on else 0.22), 6.0, width - 1.0)
		# the runes at the corners
		for el in Codex.ELEMENTS:
			var p: Vector2 = pos[el]
			var rune: String = Codex.ELEMENT_RUNE[el]
			var e := codex.entry(rune)
			var col: Color = Main.ELEMENT_COLORS[el]
			var on: bool = sel == rune
			draw_circle(p, 30.0, Color(0, 0, 0, 0.45))
			draw_circle(p, 27.0, (_b.paper as Color).darkened(0.25))
			if on or p.distance_to(mouse) < 28.0:
				draw_arc(p, 31.0, 0.0, TAU, 32, _b.accent, 2.0)
			_rune(p, col if e[1] else Color(0, 0, 0, 0.4), rune)
			var dir := (p - c).normalized()
			var lp := p + dir * 46.0
			draw_string(font, lp + Vector2(-60, 5), el.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, col.lightened(0.2))
			draw_string(font, lp + Vector2(-60, 19), str(e[2]) if e[1] else "???", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, _b.dim)
			_hit(Rect2(p - Vector2(30, 30), Vector2(60, 60)), "pick", rune)
		if hover_key != "":
			_hit(Rect2(mouse - Vector2(9, 9), Vector2(18, 18)), "pick", hover_key)
		draw_string(font, Vector2(c.x - 150, c.y + 4), "a mark, then a strike", HORIZONTAL_ALIGNMENT_CENTER, 300, 10, Color(ink, 0.4))
		# every reaction on a chip, two rows of five
		var top := LEFT.position.y + 470
		draw_string(font, Vector2(LEFT.position.x + 18, top - 8), "REACTIONS  ·  hit a foe marked with one element with another", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _b.accent)
		var keys: Array = Main.REACTIONS.keys()
		var cw := (LEFT.size.x - 36 - 4 * 6) / 5.0
		for i in keys.size():
			var key: String = keys[i]
			var e := codex.entry(key)
			var els: PackedStringArray = key.split("+")
			var r := Rect2(LEFT.position.x + 18 + (i % 5) * (cw + 6), top + int(i / 5) * 46, cw, 40)
			var on := sel == key or hover_key == key or r.has_point(mouse)
			draw_rect(r, Color(0, 0, 0, 0.22 if on else 0.12))
			draw_rect(Rect2(r.position, Vector2(5, r.size.y * 0.5)), Main.ELEMENT_COLORS[els[0]])
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(5, r.size.y * 0.5)), Main.ELEMENT_COLORS[els[1]])
			if on:
				draw_rect(r, Color(_b.accent, 0.9), false, 1.5)
			draw_string(font, r.position + Vector2(12, 17), str(Main.REACTIONS[key].name).capitalize() if e[1] else "???", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 11, ink if e[1] else Color(ink, 0.4))
			draw_string(font, r.position + Vector2(12, 32), "%s + %s" % [els[0], els[1]], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 10, _b.dim)
			_hit(r, "pick", key)

	func _dashed_line(a: Vector2, b: Vector2, col: Color, dash: float, width: float) -> void:
		var n := maxi(1, int(a.distance_to(b) / (dash * 2.0)))
		for i in n:
			draw_line(a.lerp(b, float(i * 2) / (n * 2)), a.lerp(b, float(i * 2 + 1) / (n * 2)), col, width)

	## The facing side: a rune on real gear (an elemental one with its reactions), or a
	## reaction: the two runes that make it, side by side, and what it does.
	func _tablet_detail() -> void:
		var e := codex.entry(codex.selected[1])
		if e.is_empty():
			return
		var x := RIGHT.position.x + 16
		var w := RIGHT.size.x - 32
		var ink: Color = _b.ink
		if e[4] == "reaction":
			_reaction_detail(e, x, w)
			return
		var md: Dictionary = e[5]
		_title(Vector2(x, RIGHT.position.y + 30), e[2] if e[1] else "An unread rune")
		var kinds: Array = md.get("kinds", ["weapon"])
		var line := (("Epic" if md.get("epic", false) else "Rare") + ", on %s" % " and ".join(PackedStringArray(kinds.map(func(k): return str(k) + "s")))) if md.get("rare", false) else "Common, on any gear"
		if not md.get("rolls", true):
			line = "Only from glue: never on gear from a shop or a crate"
		if Codex.ELEMENT_OF.has(e[0]):
			line = "Elemental rune: %s  ·  on any gear" % Codex.ELEMENT_OF[e[0]]
		draw_string(font, Vector2(x, RIGHT.position.y + 48), line, HORIZONTAL_ALIGNMENT_LEFT, w, 12, _b.dim)
		_window(Vector2(x + (w - Codex.VIEW.x) * 0.5, RIGHT.position.y + 60), "")
		var y := RIGHT.position.y + 60 + Codex.VIEW.y + 18
		if not e[1]:
			_text(Vector2(x, y + 10), "You haven't seen this rune on anything yet.", w, 13, _b.dim)
			return
		var desc := str(md.desc)
		y += _text(Vector2(x, y + 12), desc.left(1).to_upper() + desc.substr(1), w, 13, ink) + 10
		var facts := "Price  x%.1f" % float(md.get("price", 1.0))
		var g: String = md.get("group", "")
		if g != "":
			var others: Array = []
			for k in ItemDefs.MODIFIERS:
				if k != e[0] and ItemDefs.MODIFIERS[k].get("group", "") == g:
					others.append(str(ItemDefs.MODIFIERS[k].get("name", k)))
			facts += "   ·   never with " + ", ".join(PackedStringArray(others))
		y += _text(Vector2(x, y + 12), facts, w, 11, _b.dim) + 10
		if not Codex.ELEMENT_OF.has(e[0]):
			return
		# an elemental rune: what it marks, and what each of its pairings does
		var el: String = Codex.ELEMENT_OF[e[0]]
		draw_string(font, Vector2(x, y + 12), "ITS REACTIONS  ·  a %s mark, and then..." % el, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.accent)
		y += 20
		var mouse := get_local_mouse_position()
		for other in Codex.ELEMENTS:
			if other == el:
				continue
			var key := Codex.reaction_key(el, other)
			var re := codex.entry(key)
			var r := Rect2(x, y, w, 26)
			if r.end.y > RIGHT.end.y - 4:
				break
			draw_rect(r, Color(0, 0, 0, 0.18 if r.has_point(mouse) else 0.08))
			draw_circle(r.position + Vector2(13, 13), 7.0, Main.ELEMENT_COLORS[other])
			draw_string(font, r.position + Vector2(28, 17), "%s:  %s" % [other, str(Main.REACTIONS[key].name).capitalize() if re[1] else "?"], HORIZONTAL_ALIGNMENT_LEFT, w - 34, 12, ink if re[1] else _b.dim)
			_hit(r, "pick", key)
			y += 30

	func _reaction_detail(e: Array, x: float, w: float) -> void:
		var ink: Color = _b.ink
		var els: PackedStringArray = str(e[0]).split("+")
		var rx: Dictionary = Main.REACTIONS[e[0]]
		_title(Vector2(x, RIGHT.position.y + 30), str(rx.name).capitalize() if e[1] else "A reaction not yet seen")
		draw_string(font, Vector2(x, RIGHT.position.y + 48), "%s + %s" % [els[0], els[1]], HORIZONTAL_ALIGNMENT_LEFT, w, 12, Main.ELEMENT_COLORS[els[0]].lerp(Main.ELEMENT_COLORS[els[1]], 0.5).lightened(0.2))
		var win := _window(Vector2(x + (w - Codex.VIEW.x) * 0.5, RIGHT.position.y + 60), "")
		# under each rune in the window, its element
		for i in 2:
			draw_string(font, Vector2(win.position.x + win.size.x * (0.25 + 0.5 * i) - 60, win.end.y - 10), els[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Main.ELEMENT_COLORS[els[i]].lightened(0.3))
		var y := win.end.y + 18
		if e[1]:
			y += _text(Vector2(x, y + 12), str(rx.desc).left(1).to_upper() + str(rx.desc).substr(1) + ".", w, 14, ink) + 14
		else:
			y += _text(Vector2(x, y + 12), "Not set off yet. Two elements on one foe make it.", w, 13, _b.dim) + 14
		draw_string(font, Vector2(x, y + 10), "HOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.accent)
		y += _text(Vector2(x, y + 28), "Hit a foe with one and it's marked for %ds; hit it with the other while the mark lasts and they react (either way round; a foe can react again %.1fs later)." % [int(Main.MARK_TIME), Main.REACT_COOLDOWN], w, 12, ink) + 22
		for el in els:
			y += _text(Vector2(x, y + 12), "%s: %s" % [el.capitalize(), Codex.ELEMENT_SOURCES[el]], w, 11, _b.dim) + 6

	func _rune_color(m: String, md: Dictionary) -> Color:
		if Codex.ELEMENT_OF.has(m):
			return Main.ELEMENT_COLORS[Codex.ELEMENT_OF[m]]
		if md.get("epic", false):
			return Tooltip.EPIC
		if md.get("rare", false):
			return Color(1.0, 0.8, 0.3)
		if Item.MOD_LOOKS.has(m):
			return Item.MOD_LOOKS[m][1]
		return Tooltip.MOD_COLORS.get(m, Color(0.85, 0.9, 1.0))

	## A carved rune: a little glyph made from the modifier's name.
	func _rune(c: Vector2, col: Color, seed_text: String) -> void:
		var h := absi(seed_text.hash())
		draw_circle(c, 14.0, Color(0, 0, 0, 0.25))
		draw_arc(c, 14.0, 0.0, TAU, 20, col, 1.5)
		var pts := PackedVector2Array()
		for i in 4:
			var a := TAU * float((h >> (i * 3)) % 8) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * (5.0 + float((h >> (i * 2)) % 3) * 2.5))
		draw_polyline(pts, col, 2.0)

	# --- Bestiary ------------------------------------------------------------------------

	func _bestiary() -> void:
		var ink: Color = _b.ink
		var mouse := get_local_mouse_position()
		# bone clasps at the corners, claw marks on the vellum
		for p in [LEFT.position, Vector2(LEFT.end.x, LEFT.position.y), Vector2(LEFT.position.x, LEFT.end.y), LEFT.end]:
			draw_circle(p, 10.0, (_b.cover as Color).darkened(0.15))
		for i in 3:
			draw_line(Vector2(LEFT.end.x - 120 + i * 9, LEFT.end.y - 80), Vector2(LEFT.end.x - 90 + i * 9, LEFT.end.y - 30), Color(0.45, 0.1, 0.08, 0.18), 2.0)
		var es := codex.listed()
		_list_rect = Rect2(LEFT.position.x + 14, LEFT.position.y + 14, LEFT.size.x - 34, LEFT.size.y - 40)
		var y := _list_rect.position.y - float(codex.scroll[2])
		var start_y := y
		var group := ""
		var known := 0
		_sel_rect = Rect2()
		for e in es:
			var d: Dictionary = e[5]
			if e[1]:
				known += 1
			var o := Codex._foe_order(d)
			var g := "THE WAY DOWN" if o < 50 else ("FURTHER IN" if o < 60 else ("BOSSES" if o < 70 else ("GUARDIANS OF SECRET PLACES" if o < 80 else "THE VAULT")))
			if g != group:
				group = g
				if y >= _list_rect.position.y and y + 30 <= _list_rect.end.y:
					draw_string(font, Vector2(_list_rect.position.x + 4, y + 22), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _b.accent)
					draw_line(Vector2(_list_rect.position.x + 4, y + 27), Vector2(_list_rect.end.x - 10, y + 27), Color(_b.accent, 0.4), 1.0)
				y += 34
			var r := Rect2(_list_rect.position.x, y, _list_rect.size.x, 50)
			var sel: bool = e[0] == codex.selected[2]
			if sel:
				_sel_rect = r
			if _shown(r) == 2:
				var over := r.has_point(mouse) and _list_rect.has_point(mouse)
				draw_rect(r, Color(0, 0, 0, 0.1 if sel else (0.05 if over else 0.0)))
				if sel:
					draw_rect(r, Color(_b.accent, 0.8), false, 1.5)
				_foe_icon(d, r.position + Vector2(8, 4), e[1], e[4] == "boss")
				draw_string(font, r.position + Vector2(62, 21), e[2] if e[1] else "???", HORIZONTAL_ALIGNMENT_LEFT, 220, 15, ink if e[1] else Color(ink, 0.35))
				draw_string(font, r.position + Vector2(62, 38), Codex.foe_where(d), HORIZONTAL_ALIGNMENT_LEFT, 300, 10, _b.dim)
				if e[1]:
					draw_string(font, r.position + Vector2(r.size.x - 150, 21), "%d attacks" % Codex.attack_ids(d).size(), HORIZONTAL_ALIGNMENT_RIGHT, 140, 11, _b.dim)
				if _list_rect.has_point(mouse):
					_hit(r, "pick", e[0])
			y += 54
		_list_h = y - start_y
		_scrollbar()
		_counter("%d of %d met" % [known, es.size()])
		_foe_detail()

	## Figures in the book's hand: a grid of [label, number], the label small on the left, the
	## number on the right of its cell, each cell ruled off underneath. Returns the height.
	func _ledger_figures(at: Vector2, w: float, cols: int, rows: Array) -> float:
		var gap := 14.0
		var cw := (w - gap * (cols - 1)) / cols
		var rh := 19.0
		for i in rows.size():
			var cx := at.x + (i % cols) * (cw + gap)
			var cy := at.y + int(i / cols) * rh
			draw_string(font, Vector2(cx, cy + 12), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.dim)
			draw_string(font, Vector2(cx, cy + 13), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, cw, 14, _b.ink)
			draw_line(Vector2(cx, cy + 17), Vector2(cx + cw, cy + 17), Color(_b.ink, 0.15), 1.0)
		return ceili(float(rows.size()) / cols) * rh

	func _foe_detail() -> void:
		var e := codex.entry(codex.selected[2])
		if e.is_empty():
			return
		var d: Dictionary = e[5]
		var x := RIGHT.position.x + 16
		var w := RIGHT.size.x - 32
		_title(Vector2(x, RIGHT.position.y + 28), e[2] if e[1] else "Not met yet")
		draw_string(font, Vector2(x, RIGHT.position.y + 45), Codex.foe_where(d), HORIZONTAL_ALIGNMENT_LEFT, w, 12, _b.accent if e[4] == "boss" else _b.dim)
		var win := _window(Vector2(x + (w - Codex.VIEW.x) * 0.5, RIGHT.position.y + 54), "a page of scratches: you haven't met it")
		var y := RIGHT.position.y + 54 + Codex.VIEW.y + 10
		if not e[1]:
			return
		if not codex._replay.is_empty():
			# the wind-up as a bar under the window: how long you have to get something there
			var wind: float = codex._replay.windup
			var f := clampf(codex._swing_t / wind, 0.0, 1.0)
			var bar := Rect2(win.position.x, win.end.y + 3, win.size.x, 5)
			draw_rect(bar, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(1.0, 0.35, 0.2) if f < 1.0 else Color(1, 0.95, 0.8))
			draw_string(font, Vector2(win.end.x - 200, win.position.y + 16), "%s   %d lanes   %.1fs" % [str(Codex.ATTACK_NAMES.get(codex._replay.id, codex._replay.id)), (codex._replay.lanes as Array).size(), wind], HORIZONTAL_ALIGNMENT_RIGHT, 194, 11, Color(1, 0.95, 0.85))
			y += 6
		# its measure
		var stats := [["Health", "%d" % roundi(float(d.hp))], ["Armour", Tooltip.Drawn.pct(float(d.armor))],
			["Speed", Tooltip.Drawn.times(float(d.speed))], ["Strength", Tooltip.Drawn.times(float(d.get("power", 1.0)))],
			["Poise", "%d" % roundi(float(d.poise))], ["Bounty", "%d" % int(d.get("reward", 0))]]
		y += _ledger_figures(Vector2(x, y), w, 3, stats) + 4
		y += _text(Vector2(x, y + 10), str(d.get("bio", "")), w, 11, _b.ink, 2) + 4
		# every attack: click one to see it swung
		draw_string(font, Vector2(x, y + 12), "ATTACKS  ·  click one to see it", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.accent)
		y += 18
		var atks: Array = Codex.attack_ids(d)
		var row_h := clampf((RIGHT.end.y - y - 6) / maxf(1.0, atks.size()), 26.0, 44.0)
		var mouse := get_local_mouse_position()
		for i in atks.size():
			var id: String = atks[i]
			var a: Dictionary = EnemyDefs.ATTACKS[id]
			var r := Rect2(x, y, w, row_h - 3)
			if r.end.y > RIGHT.end.y:
				break
			var on := codex.attack_pick == i
			draw_rect(r, Color(0, 0, 0, 0.14 if on else (0.07 if r.has_point(mouse) else 0.03)))
			if on:
				draw_rect(r, Color(_b.accent, 0.8), false, 1.5)
			var map := Rect2(r.position + Vector2(4, 3), Vector2((r.size.y - 6) * 16.0 / 9.0, r.size.y - 6))
			_zone_map(a, map)
			var tx := map.end.x + 10
			draw_string(font, Vector2(tx, r.position.y + r.size.y * 0.5 - 2), str(Codex.ATTACK_NAMES.get(id, id.replace("_", " ").capitalize())), HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 4, 12, _b.ink)
			var lanes_n := Codex.lane_count(id)
			var notes: Array = ["%d damage" % roundi(float(a.damage) * float(d.get("power", 1.0))), "%.1fs wind-up" % (float(a.windup) / maxf(0.1, float(d.speed))),
				("a thrust: %d point%s" % [lanes_n, "s" if lanes_n > 1 else ""]) if (a.dir as Vector2) == Vector2.ZERO else ("%d lane%s" % [lanes_n, "s" if lanes_n > 1 else ""])]
			if float(a.get("impact", 1.0)) >= 2.0:
				notes.append("hard on gear")
			if a.has("cleave"):
				notes.append("cuts through %d%%" % roundi(float(a.cleave) * 100.0))
			if a.get("track", false):
				notes.append("aims at your hand")
			if a.has("chase"):
				notes.append("follows your hand, then commits")
			if a.has("pan"):
				notes.append("slides as it comes")
			if a.has("turn"):
				notes.append("swings round as it comes")
			if a.has("next"):
				notes.append("then a second blow")
			if a.has("trait"):
				notes.append(str(a.trait))
			draw_string(font, Vector2(tx, r.position.y + r.size.y * 0.5 + 11), "  ·  ".join(PackedStringArray(notes)), HORIZONTAL_ALIGNMENT_LEFT, w - (tx - x) - 4, 10, _b.dim)
			_hit(r, "attack", i)
			y += row_h

	## Where on the screen an attack lands: a little map of the play field, the zone shaded,
	## an arrow the way the blade travels (a thrust: rings on its point).
	func _zone_map(a: Dictionary, r: Rect2) -> void:
		draw_rect(r, Color(0.12, 0.1, 0.09, 0.85))
		var pts := PackedVector2Array()
		for p in a.zone:
			pts.append(r.position + (p as Vector2) * r.size)
		var col: Color = Main.ELEMENT_COLORS.get(_trait_element(str(a.get("trait", ""))), Color(1.0, 0.45, 0.3))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(col, 0.55))
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= maxf(1.0, pts.size())
		var dir: Vector2 = a.dir
		if dir == Vector2.ZERO:
			draw_arc(c, 4.0, 0.0, TAU, 12, Color(1, 1, 0.9), 1.5)
			draw_arc(c, 7.0, 0.0, TAU, 12, Color(1, 1, 0.9, 0.5), 1.0)
		else:
			var d := dir.normalized() * minf(r.size.x, r.size.y) * 0.4
			draw_line(c - d, c + d, Color(1, 1, 0.9), 1.5)
			draw_colored_polygon(PackedVector2Array([c + d, c + d - d.normalized() * 5.0 + d.orthogonal().normalized() * 3.0, c + d - d.normalized() * 5.0 - d.orthogonal().normalized() * 3.0]), Color(1, 1, 0.9))
		draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)

	static func _trait_element(t: String) -> String:
		match t:
			"charged":
				return "storm"
			"corrosive":
				return "rot"
			"burning":
				return "fire"
		return "none"

	func _foe_icon(d: Dictionary, at: Vector2, known: bool, boss: bool) -> void:
		var box := Rect2(at, Vector2(44, 42))
		draw_rect(box, Color(0, 0, 0, 0.12))
		var col: Color = d.color if known else Color(0.15, 0.12, 0.1)
		draw_rect(Rect2(at + Vector2(15, 6), Vector2(14, 14)), col.lightened(0.15) if known else col)
		draw_rect(Rect2(at + Vector2(8, 22), Vector2(28, 18)), col)
		if known:
			draw_rect(Rect2(at + Vector2(17, 11), Vector2(10, 2)), Color(0.02, 0.02, 0.02))
		if boss and known:
			for k in 3:
				draw_rect(Rect2(at + Vector2(15 + k * 5, 1), Vector2(2, 5)), Color(0.95, 0.75, 0.2))

	# --- Wall Map ------------------------------------------------------------------------

	## The way down drawn as a map: home at the top, the stages below it, the deep places off
	## the side, the vault behind its keyhole, the secret places in the torn corners.
	const SPOTS := {"Homestead": Vector2(0.5, 0.07),
		"Dungeon Cell": Vector2(0.3, 0.24), "Corridor": Vector2(0.7, 0.24),
		"Cistern": Vector2(0.3, 0.44), "Catacombs": Vector2(0.7, 0.44),
		"Crypt Chapel": Vector2(0.22, 0.64), "Forge": Vector2(0.5, 0.66), "Ossuary": Vector2(0.78, 0.64), "Star Chamber": Vector2(0.5, 0.84),
		"Hidden Vault": Vector2(0.9, 0.34),
		"Clockwork Orrery": Vector2(0.09, 0.12), "Ink Margin": Vector2(0.91, 0.12),
		"Molten Core": Vector2(0.72, 0.9)}

	func _map() -> void:
		var ink: Color = _b.ink
		var mouse := get_local_mouse_position()
		var area := LEFT.grow(-14)
		# the cloth: fold lines and a compass rose
		for f in [0.33, 0.66]:
			draw_line(Vector2(area.position.x + area.size.x * f, area.position.y), Vector2(area.position.x + area.size.x * f, area.end.y), Color(0, 0, 0, 0.07), 2.0)
		draw_line(Vector2(area.position.x, area.get_center().y), Vector2(area.end.x, area.get_center().y), Color(0, 0, 0, 0.07), 2.0)
		var rose := Vector2(area.end.x - 60, area.get_center().y + 120)
		for i in 4:
			var a := i * PI / 2.0
			draw_colored_polygon(PackedVector2Array([rose + Vector2(cos(a), sin(a)) * 26.0, rose + Vector2(cos(a + 0.4), sin(a + 0.4)) * 6.0, rose + Vector2(cos(a - 0.4), sin(a - 0.4)) * 6.0]), Color(ink, 0.35))
		draw_string(font, rose + Vector2(-4, -30), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.5))
		_list_rect = Rect2()
		_list_h = 0.0
		# the roads
		var pos := func(nm: String) -> Vector2: return area.position + (SPOTS.get(nm, Vector2(0.5, 0.5)) as Vector2) * area.size
		var roads := [["Homestead", "Dungeon Cell"], ["Homestead", "Corridor"], ["Dungeon Cell", "Cistern"], ["Corridor", "Catacombs"],
			["Dungeon Cell", "Catacombs"], ["Corridor", "Cistern"], ["Cistern", "Crypt Chapel"], ["Cistern", "Forge"], ["Catacombs", "Forge"],
			["Catacombs", "Ossuary"], ["Forge", "Star Chamber"]]
		for rd in roads:
			_dashed(pos.call(rd[0]), pos.call(rd[1]), Color(ink, 0.45), 8.0)
		_dashed(pos.call("Corridor"), pos.call("Hidden Vault"), Color(_b.accent, 0.4), 4.0)
		for i in 3:
			var label: String = ["STAGES 1-2", "STAGES 3-4", "THE DEEP"][i]
			draw_string(font, Vector2(area.position.x + 6, area.position.y + area.size.y * [0.24, 0.44, 0.7][i] + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ink, 0.4))
		# the places
		var known := 0
		var es := codex.entries()
		for e in es:
			var nm: String = e[0]
			var p: Vector2 = pos.call(nm)
			var secret := Secrets.STAGES.has(nm)
			if e[1]:
				known += 1
			var sel: bool = codex.selected[3] == nm
			var r := Rect2(p - Vector2(60, 24), Vector2(120, 48))
			var over := r.has_point(mouse)
			if secret and not e[1]:
				# a torn corner, nothing drawn on it
				draw_circle(p, 18.0, Color(0, 0, 0, 0.12))
				draw_string(font, p + Vector2(-20, 7), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(ink, 0.35))
			else:
				var look: Dictionary = Backdrop.LOOK.get(nm, Backdrop.LOOK["Dungeon Cell"])
				var stops: Array = look.c
				var col: Color = stops[3] if e[1] else Color(ink, 0.15)
				draw_circle(p, 15.0 if sel else 12.0, Color(0, 0, 0, 0.35))
				draw_circle(p, 13.0 if sel else 10.0, col)
				if sel:
					draw_arc(p, 19.0, 0.0, TAU, 24, _b.accent, 2.0)
				var label: String = nm if e[1] else "???"
				draw_string(font, p + Vector2(-70, 28), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12 if not over else 13, ink if e[1] else Color(ink, 0.4))
			_hit(r, "pick", nm)
		var home: Vector2 = pos.call("Homestead")
		draw_rect(Rect2(home - Vector2(9, 6), Vector2(18, 12)), Color(ink, 0.7))
		draw_colored_polygon(PackedVector2Array([home + Vector2(-11, -6), home + Vector2(11, -6), home + Vector2(0, -16)]), Color(_b.accent, 0.85))
		draw_string(font, home + Vector2(-50, 28), "Home", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, ink)
		_counter("%d of %d places charted" % [known, es.size()])
		_place_detail()

	func _dashed(a: Vector2, b: Vector2, col: Color, dash: float) -> void:
		var n := int(a.distance_to(b) / (dash * 2.0))
		for i in n:
			draw_line(a.lerp(b, float(i * 2) / (n * 2)), a.lerp(b, float(i * 2 + 1) / (n * 2)), col, 2.0)

	func _place_detail() -> void:
		var e := codex.entry(codex.selected[3])
		if e.is_empty():
			return
		var nm: String = e[0]
		var x := RIGHT.position.x + 16
		var w := RIGHT.size.x - 32
		_title(Vector2(x, RIGHT.position.y + 28), nm if e[1] else "Uncharted")
		var when := _place_when(nm)
		draw_string(font, Vector2(x, RIGHT.position.y + 45), when, HORIZONTAL_ALIGNMENT_LEFT, w, 12, _b.dim)
		_window(Vector2(x + (w - Codex.VIEW.x) * 0.5, RIGHT.position.y + 54), "fog: you haven't been")
		var y := RIGHT.position.y + 54 + Codex.VIEW.y + 12
		if not e[1]:
			if Secrets.STAGES.has(nm):
				_text(Vector2(x, y + 12), "Somewhere off the map. Nobody's drawn the way there.", w, 12, _b.dim)
			return
		y += _text(Vector2(x, y + 12), str(Backdrop.BLURB.get(nm, "")), w, 12, _b.ink) + 14
		var props := Props.layout(nm)
		if not props.is_empty():
			draw_string(font, Vector2(x, y + 10), "WHAT'S HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.accent)
			y += 16
			for k in props:
				var info: Array = Props.INFO.get(k, [k, ""])
				y += _text(Vector2(x, y + 12), "%s: %s" % [info[0], info[1]], w, 11, _b.ink, 3) + 4
				if y > RIGHT.end.y - 60:
					break
		var who := _place_foes(nm)
		if who != "" and y < RIGHT.end.y - 30:
			draw_string(font, Vector2(x, y + 16), "WHO YOU MEET", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _b.accent)
			_text(Vector2(x, y + 32), who, w, 11, _b.ink, 2)

	static func _place_when(nm: String) -> String:
		if Backdrop.RARE.has(nm):
			return "The deep: prestige %d and on, now and then" % int(Backdrop.RARE[nm].prestige)
		if (Backdrop.TIERS.early as Array).has(nm):
			return "Stages 1 and 2 of the way down"
		if (Backdrop.TIERS.middle as Array).has(nm):
			return "Stages 3 and 4"
		if (Backdrop.TIERS.late as Array).has(nm):
			return "The fifth stage, and deeper runs"
		if nm == "Hidden Vault":
			return "Behind a hidden keyhole"
		return "A secret place"

	func _place_foes(nm: String) -> String:
		var save: SaveData = codex._game.save
		var names: Array = []
		if Secrets.STAGES.has(nm):
			names = [Secrets.STAGES[nm].foe]
		elif nm == "Hidden Vault":
			names = [EnemyDefs.WARDEN.name]
		elif (Backdrop.TIERS.early as Array).has(nm):
			names = Codex._names(EnemyDefs.TIERS[0] + EnemyDefs.TIERS[1])
		elif (Backdrop.TIERS.middle as Array).has(nm):
			names = Codex._names(EnemyDefs.TIERS[2] + EnemyDefs.TIERS[3])
		else:
			names = Codex._names(EnemyDefs.BOSSES[0] + EnemyDefs.BOSSES[1])
		var out: Array = []
		var seen := {}
		for n in names:
			if not seen.has(n):
				seen[n] = true
				out.append(n if save.knows("foes", n) else "???")
		return ", ".join(PackedStringArray(out))
