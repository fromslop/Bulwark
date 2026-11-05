class_name Tooltip
extends CanvasLayer
## Hold Alt to inspect. The game freezes, the hand becomes a magnifying glass and:
##  - the item under it (or the one you're holding) gets an inspect card: a big title in the
##    material's colour, the price as a coin, stat bars with icons, material swatches,
##    colour-coded modifier chips, and a keycap showing what Space does with it;
##  - your worn rings appear down the left side (hover one for its card);
##  - your own stats appear in a strip along the top (hover one to read what it does);
##  - an enemy under the glass gets a card: its name, what it is, its health, stagger and
##    the rest, and its quirks in plain words.
## Nothing shows when Alt isn't held.

const W := 300.0
const PAD := 10.0
const MOD_COLORS := {
	"electrified": Color(0.45, 0.75, 1.0), "superheated": Color(1.0, 0.5, 0.15), "frosty": Color(0.6, 0.95, 1.0),
	"sticky": Color(0.8, 0.9, 0.3), "magnetic": Color(0.95, 0.3, 0.3), "corrosive": Color(0.45, 0.95, 0.35),
	"volatile": Color(1.0, 0.25, 0.15), "regenerating": Color(0.5, 1.0, 0.6), "weightless": Color(0.85, 0.95, 1.0),
	"heavy": Color(0.55, 0.55, 0.58), "reinforced": Color(0.75, 0.72, 0.65),
	"bouncy": Color(1.0, 0.55, 0.8), "spiked": Color(0.8, 0.82, 0.86),
	"poisoned": Color(0.4, 0.9, 0.3), "oiled": Color(0.75, 0.6, 0.3), "tempered": Color(0.6, 0.8, 1.0),
	"small": Color(0.75, 0.6, 1.0), "large": Color(0.75, 0.6, 1.0), "huge": Color(0.75, 0.6, 1.0),
}
const INK := Color(0.93, 0.88, 0.78)
const EPIC := Color(0.78, 0.5, 1.0)  # epic modifiers: violet, past the rares' gold
const DIM := Color(0.62, 0.57, 0.5)

var _card: Card
var _panels: Panels
var _game: Node
var _froze := false  # we froze the game (so we're the ones to let it go)


func _ready() -> void:
	layer = 106  # above the grain so the card stays crisp
	process_mode = Node.PROCESS_MODE_ALWAYS  # it works while the game is frozen
	_game = get_parent()
	_card = Card.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_panels = Panels.new()
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panels.visible = false
	add_child(_panels)
	add_child(_card)


func _process(_delta: float) -> void:
	if not _game.is_inside_tree():
		return
	var hand: Hand = _game.hand
	_freeze(hand.inspecting())
	_panels.visible = hand.inspecting()
	if not hand.inspecting():
		_card.visible = false
		return
	_panels.game = _game
	_panels.queue_redraw()
	var finger := _panels.ring_at(hand.position, hand)
	var stat := _panels.stat_at(hand.position, hand) if finger < 0 else ""
	if stat == "" and finger < 0 and hand.held == null and _game.get("props") != null:
		stat = _game.props.info_at(hand.position)
	var it: Item = null
	if finger < 0 and stat == "":
		it = hand.held if hand.held else hand.item_near(hand.position)
	var foe: Enemy = _enemy_at(hand.position) if finger < 0 and stat == "" and it == null else null
	if finger >= 0:
		_card.show_ring(finger, _game)
	elif stat != "":
		_card.show_stat(stat, _game)
	elif it:
		_card.show_item(it, _game)
	elif foe:
		_card.show_enemy(foe, _game)
	else:
		_card.visible = false
		return
	_card.visible = true
	var pos := hand.position + Vector2(34, 10)
	if pos.x + _card.size.x > 1272:
		pos.x = hand.position.x - _card.size.x - 34
	pos.y = clampf(pos.y, 8, 712 - _card.size.y)
	_card.position = pos


## Inspecting stops the world, so there's time to read. Never fights the pause menu: only
## lets go of a freeze it made itself.
func _freeze(on: bool) -> void:
	var menu := get_tree().get_first_node_in_group("pause_menu")
	var menu_open: bool = menu != null and menu.is_open()
	if on and Settings.inspect_pauses and not get_tree().paused and not menu_open:
		get_tree().paused = true
		_froze = true
	elif not on and _froze:
		_froze = false
		if not menu_open:
			get_tree().paused = false


## The living enemy under the glass: any of its body parts, or near its chest.
func _enemy_at(p: Vector2) -> Enemy:
	if not _game.has_method("living"):
		return null
	var best: Enemy = null
	var best_d := 170.0
	for e in _game.living():
		for r in e.regions():
			if p.distance_to(r.center) <= r.radius + 12.0:
				return e
		var d := p.distance_to(_game.camera.unproject_position(e.torso.global_position))
		if d < best_d:
			best_d = d
			best = e
	return best


## Shared drawing kit: icons, coins, segmented bars and the iron plate frame.
class Drawn:
	extends Control

	var font: Font = ThemeDB.fallback_font

	func _bar(r: Rect2, v: float, col: Color, segs: int = 10) -> void:
		var sw := r.size.x / segs
		for i in segs:
			var filled := v * segs - i
			var cell := Rect2(r.position.x + i * sw, r.position.y, sw - 2, r.size.y)
			draw_rect(cell, Color(1, 1, 1, 0.07))
			if filled > 0.0:
				draw_rect(Rect2(cell.position, Vector2(cell.size.x * clampf(filled, 0.0, 1.0), cell.size.y)), col)

	func _plate(r: Rect2, accent: Color) -> void:
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.45))
		draw_rect(r, Color(0.09, 0.07, 0.06, 0.96))
		draw_rect(r, accent.darkened(0.3), false, 2.0)
		draw_rect(r.grow(-3.0), Color(1, 1, 1, 0.06), false, 1.0)
		for p in [r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5), Vector2(r.position.x + 5, r.end.y - 5), r.end - Vector2(5, 5)]:
			draw_circle(p, 2.0, accent.darkened(0.5))

	func _keycap(at: Vector2, label: String, w: float = 46.0) -> void:
		draw_rect(Rect2(at, Vector2(w, 16)), Color(0.22, 0.2, 0.18))
		draw_rect(Rect2(at + Vector2(0, 13), Vector2(w, 3)), Color(0.1, 0.09, 0.08))
		draw_rect(Rect2(at, Vector2(w, 16)), Color(0.5, 0.46, 0.4), false, 1.0)
		draw_string(font, at + Vector2(0, 11), label, HORIZONTAL_ALIGNMENT_CENTER, w, 9, INK)

	func _ring_icon(c: Vector2, r: float, gem: Color, ready: float) -> void:
		draw_arc(c, r, 0.0, TAU, 20, Color(0.55, 0.4, 0.1), r * 0.5)
		draw_arc(c, r, 0.0, TAU, 20, Color(0.98, 0.78, 0.25), r * 0.3)
		draw_circle(c + Vector2(0, -r), r * 0.45, gem.darkened(0.8 * (1.0 - ready)))
		if ready < 1.0:
			# a dial sweeping round as it recharges
			draw_arc(c, r * 1.45, -PI / 2, -PI / 2 + TAU * ready, 24, Color(1, 1, 1, 0.5), 2.0)

	func _icon(icon: String, c: Vector2, col: Color) -> void:
		match icon:
			"shield":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(5, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), col)
			"sword":
				draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), col, 2.0)
				draw_line(c + Vector2(-5, 0), c + Vector2(0, 5), col, 2.0)
			"hourglass":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -6), c + Vector2(4, -6), c]), col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 6), c + Vector2(4, 6), c]), col)
			"weight":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -4), c + Vector2(3, -4), c + Vector2(6, 5), c + Vector2(-6, 5)]), col)
				draw_arc(c + Vector2(0, -5), 2.0, PI, TAU, 6, col, 1.5)
			"brick":
				draw_rect(Rect2(c + Vector2(-6, -5), Vector2(12, 10)), col)
				draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color(0, 0, 0, 0.6), 1.0)
				draw_line(c + Vector2(0, -5), c + Vector2(0, 0), Color(0, 0, 0, 0.6), 1.0)
			"heart":
				draw_circle(c + Vector2(-2.5, -2), 3.0, col)
				draw_circle(c + Vector2(2.5, -2), 3.0, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5.5, -1), c + Vector2(5.5, -1), c + Vector2(0, 6)]), col)
			"fist":
				draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 9)), col)
				for k in 3:
					draw_line(c + Vector2(-2 + k * 3, -4), c + Vector2(-2 + k * 3, -1), Color(0, 0, 0, 0.5), 1.0)
			"wave":
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(c + Vector2(-6 + k * 2, sin(k * 1.4) * 3.0))
				draw_polyline(pts, col, 2.0)

	func _coin(c: Vector2, r: float) -> void:
		draw_circle(c, r, Color(0.65, 0.45, 0.1))
		draw_circle(c, r - 1.5, Color(0.98, 0.78, 0.25))
		draw_arc(c, r * 0.55, 0.0, TAU, 12, Color(0.75, 0.55, 0.15), 1.5)


## Shown while Alt is held: the stats strip along the top and the ring slots down the left.
class Panels:
	extends Drawn

	const SLOT := 46.0
	const SLOT_X := 14.0
	const SLOT_Y := 150.0
	const FINGERS := ["INDEX", "MIDDLE", "RING", "LITTLE", "THUMB"]
	var game: Node

	## Which worn ring the point is over, or -1.
	func ring_at(p: Vector2, hand: Hand) -> int:
		for i in hand.rings.size():
			if _slot_rect(i).grow(4.0).has_point(p):
				return i
		return -1

	func _slot_rect(i: int) -> Rect2:
		return Rect2(SLOT_X, SLOT_Y + i * (SLOT + 8.0), SLOT, SLOT)

	func _draw() -> void:
		if game == null:
			return
		var hand: Hand = game.hand
		_draw_stats(hand)
		for i in Hand.MAX_RING_SLOTS:
			var r := _slot_rect(i)
			if i >= hand.ring_slots:
				# a finger without a fitting yet
				draw_rect(r, Color(0, 0, 0, 0.35))
				draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
				draw_string(font, r.position + Vector2(0, SLOT * 0.5 + 4), "—", HORIZONTAL_ALIGNMENT_CENTER, SLOT, 12, DIM)
				continue
			_plate(r, Color(0.85, 0.65, 0.3))
			draw_string(font, r.position + Vector2(3, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
			if i < hand.rings.size():
				var u: Dictionary = ItemDefs.UPGRADES[hand.rings[i]]
				var cd: float = u.cooldown
				var ready := 1.0 if cd <= 0.0 else 1.0 - hand.ring_cds[i] / cd
				_ring_icon(r.get_center() + Vector2(0, 3), 10.0, u.gem, ready)

	## What each entry of the stat strip means, for its card.
	const STAT_INFO := {
		"HAND": ["Hand", "Your health. Blows that get past your gear hurt it, and so does holding something shocked, burning or frozen. At zero the run ends. Each shop visit heals 40; salves raise it."],
		"GRIP": ["Grip", "How hard you can pull. The heavier the thing you hold, the more grip it takes to move it quickly and swing it hard. Gauntlets and Iron Tonic raise it."],
		"SWING": ["Swing", "How hard your weapon swings. A faster swing hits harder."],
		"STEADY": ["Steady", "How steady your hand stays as it gets hurt. A badly hurt hand trembles; steadier hands tremble less."],
		"HASTE": ["Haste", "Weapons recover this much faster between swings (Quicksilver Drop)."],
		"SKIN": ["Skin", "Blows that get through to the hand hurt this much less (Troll Marrow)."],
		"RINGS": ["Rings", "Rings worn, out of ring slots. Point at a ring on the left to read it. The shop sells more slots, up to one per finger."],
		"COINS": ["Coins", "The gold lying in your pile. Pick up something in the shop to buy it; the price comes out of the pile. Some rings and utilities pay off for having lots."],
	}

	## The stat strip's entries and where each sits: [key, rect].
	func _stat_rects(hand: Hand) -> Array:
		var wide := hand.haste < 1.0 or hand.resilience < 1.0
		var r := Rect2(230, 8, 820, 40) if wide else Rect2(330, 8, 620, 40)
		var keys := ["HAND", "GRIP", "SWING", "STEADY"] + (["HASTE", "SKIN"] if wide else [])
		var out: Array = []
		var x := r.position.x + 14
		for k in keys:
			out.append([k, Rect2(x, r.position.y + 4, 100, 32)])
			x += 104
		out.append(["RINGS", Rect2(x, r.position.y + 4, 66, 32)])
		out.append(["COINS", Rect2(x + 70, r.position.y + 4, 70, 32)])
		return out

	## Which stat-strip entry the point is over, or "".
	func stat_at(p: Vector2, hand: Hand) -> String:
		for e in _stat_rects(hand):
			if (e[1] as Rect2).has_point(p):
				return e[0]
		return ""

	func _draw_stats(hand: Hand) -> void:
		var r := Rect2(330, 8, 620, 40)
		if hand.haste < 1.0 or hand.resilience < 1.0:
			r = Rect2(230, 8, 820, 40)
		_plate(r, Color(0.85, 0.65, 0.3))
		var x := r.position.x + 14
		var y := r.position.y + 13
		var health := 1.0 - hand.hurt_fraction()
		var entries := [
			["heart", "HAND", health, Color(0.9, 0.25, 0.2).lerp(Color(0.45, 0.9, 0.4), health)],
			["fist", "GRIP", clampf(hand.grip() / 2.0, 0.0, 1.0), Color(0.85, 0.75, 0.6)],
			["sword", "SWING", clampf(hand.swing_power / 2.0, 0.0, 1.0), Color(1.0, 0.45, 0.35)],
			["wave", "STEADY", clampf(1.0 - hand.steadiness * 0.5, 0.0, 1.0), Color(0.6, 0.8, 1.0)],
		]
		if hand.haste < 1.0 or hand.resilience < 1.0:
			entries.append(["hourglass", "HASTE", clampf((1.0 - hand.haste) * 2.5, 0.0, 1.0), Color(1.0, 0.85, 0.4)])
			entries.append(["brick", "SKIN", clampf((1.0 - hand.resilience) * 2.5, 0.0, 1.0), Color(0.5, 0.8, 0.4)])
		for e in entries:
			_icon(e[0], Vector2(x + 6, y + 5), e[3])
			draw_string(font, Vector2(x + 15, y + 9), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
			_bar(Rect2(x + 15, y + 13, 70, 7), e[2], e[3], 7)
			x += 104
		_ring_icon(Vector2(x + 8, y + 9), 6.0, Color(1, 1, 1), 1.0)
		draw_string(font, Vector2(x + 20, y + 14), "%d/%d" % [hand.rings.size(), hand.ring_slots], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		x += 70
		_coin(Vector2(x + 8, y + 9), 8.0)
		draw_string(font, Vector2(x + 21, y + 15), str(game.coin_total()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.35))


## The inspect card itself: everything laid out and drawn by hand.
class Card:
	extends Drawn

	var item: Item
	var game: Node
	var finger := -1  # >= 0: showing a worn ring instead of an item
	var stat := ""  # showing a stat-strip entry
	var foe: Enemy  # showing an enemy

	func show_item(it: Item, g: Node) -> void:
		item = it
		game = g
		finger = -1
		stat = ""
		foe = null
		size = Vector2(W, _layout(false))
		queue_redraw()

	func show_ring(f: int, g: Node) -> void:
		item = null
		game = g
		finger = f
		stat = ""
		foe = null
		size = Vector2(W, _layout_ring(false))
		queue_redraw()

	func show_stat(key: String, g: Node) -> void:
		item = null
		game = g
		finger = -1
		stat = key
		foe = null
		size = Vector2(W, _layout_stat(false))
		queue_redraw()

	func show_enemy(e: Enemy, g: Node) -> void:
		item = null
		game = g
		finger = -1
		stat = ""
		foe = e
		size = Vector2(W, _layout_enemy(false))
		queue_redraw()

	func _draw() -> void:
		if stat != "":
			_layout_stat(true)
		elif foe and is_instance_valid(foe):
			_layout_enemy(true)
		elif finger >= 0:
			_layout_ring(true)
		elif item and is_instance_valid(item):
			_layout(true)

	## Wrapped text at (x, y) (top of the first line); draws it when painting. Returns its height.
	func _text(text: String, x: float, y: float, width: float, size: int, col: Color, paint: bool) -> float:
		var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
		if paint:
			draw_multiline_string(font, Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, col)
		return h

	## The largest size (down to 14) at which a title fits on one line.
	func _title_size(text: String, width: float) -> int:
		var size := 20
		while size > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			size -= 1
		return size

	## A stat-strip entry: what it is and what it does.
	func _layout_stat(paint: bool) -> float:
		var info: Array = game.props.describe(stat) if stat.begins_with("prop:") else Panels.STAT_INFO[stat]
		var accent := Color(0.85, 0.65, 0.3)
		var body_h := _text(info[1], PAD, 0, W - PAD * 2, 12, INK, false)
		var h := PAD + 30 + body_h + PAD
		if paint:
			_plate(Rect2(Vector2.ZERO, Vector2(W, h)), accent)
			draw_string(font, Vector2(PAD, PAD + 18), str(info[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
			_text(info[1], PAD, PAD + 28, W - PAD * 2, 12, INK, true)
		return h

	## An enemy: name in its colour, boss or not, its description, its numbers as bars, what
	## it's doing right now, and its quirks in plain words.
	func _layout_enemy(paint: bool) -> float:
		var d: Dictionary = foe.data
		var accent := (d.get("color", Color(0.8, 0.8, 0.8)) as Color).lightened(0.45)
		var tag := "BOSS" if d.get("boss", false) else "ENEMY"
		if int(d.get("prestige", 0)) > 0:
			tag += "   PRESTIGE %d" % int(d.prestige)
		var bio := str(d.get("bio", ""))
		var bio_h := _text(bio, PAD, 0, W - PAD * 2, 12, INK, false)
		var now := _enemy_state()
		var traits := _enemy_traits(d)
		var traits_h := 0.0
		for t in traits:
			traits_h += _text("• " + t, PAD, 0, W - PAD * 2, 11, DIM, false) + 3
		var bars := [
			["heart", "HEALTH  %d/%d" % [ceili(foe.hp), ceili(foe.max_hp)], foe.hp / foe.max_hp, Color(0.9, 0.25, 0.2)],
			["wave", "STAGGER", foe.stagger_fraction(), Color(1.0, 0.8, 0.3)],
			["sword", "DAMAGE", clampf(float(d.get("power", 1.0)) / 3.5, 0.03, 1.0), Color(1.0, 0.45, 0.35)],
			["hourglass", "SPEED", clampf(foe.cur_speed() / 2.5, 0.03, 1.0), Color(0.6, 0.8, 1.0)],
			["brick", "POISE", clampf(float(d.get("poise", 10.0)) / 120.0, 0.03, 1.0), Color(0.8, 0.7, 0.55)],
			["shield", "ARMOUR", clampf(float(d.get("armor", 0.0)), 0.0, 1.0), Color(0.7, 0.72, 0.8)],
		]
		var h := PAD + 46 + bio_h + 8 + bars.size() * 18 + (20 if now != "" else 0) + 6 + traits_h + PAD
		if paint:
			_plate(Rect2(Vector2.ZERO, Vector2(W, h)), accent)
			draw_rect(Rect2(2, 2, W - 4, 42), Color(accent.r, accent.g, accent.b, 0.12))
			var name := str(d.get("name", "Enemy"))
			draw_string(font, Vector2(PAD, PAD + 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_size(name, W - PAD * 2), accent)
			draw_string(font, Vector2(PAD, PAD + 36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
			var y := PAD + 46
			_text(bio, PAD, y, W - PAD * 2, 12, INK, true)
			y += bio_h + 8
			for b in bars:
				_icon(b[0], Vector2(PAD + 7, y + 7), b[3])
				draw_string(font, Vector2(PAD + 18, y + 11), b[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)
				_bar(Rect2(PAD + 132, y + 2, W - PAD * 2 - 132, 10), b[2], b[3])
				y += 18
			if now != "":
				draw_string(font, Vector2(PAD, y + 13), now, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.75, 0.35))
				y += 20
			y += 6
			for t in traits:
				y += _text("• " + t, PAD, y, W - PAD * 2, 11, DIM, true) + 3
		return h

	func _enemy_state() -> String:
		var bits: Array = []
		if foe.state == "broken":
			bits.append("BROKEN: hits do x1.5")
		elif foe.off_balance > 0.0:
			bits.append("REELING: hits do x1.5")
		elif foe.state == "windup":
			bits.append("WINDING UP")
		if foe.burning_time > 0.0:
			bits.append("BURNING")
		if foe.poison_time > 0.0:
			bits.append("POISONED")
		if foe.corrosion > 0.0:
			bits.append("CORRODED %d%%" % roundi(foe.corrosion * 100.0))
		var clock: float = game.clock if game and game.get("clock") != null else 0.0
		if float(foe.get_meta("vulnerable_until", 0.0)) > clock:
			bits.append("VULNERABLE: hits do x1.5")
		var marks: Dictionary = foe.get_meta("marks", {})
		for el in marks:
			if float(marks[el]) > clock:
				bits.append("MARKED: " + str(el).to_upper())
		return "   ".join(bits)

	## Its quirks, from its definition, in plain words.
	func _enemy_traits(d: Dictionary) -> Array:
		var out: Array = []
		var cleaves := false
		for a in d.get("attacks", []):
			if float(EnemyDefs.ATTACKS[a].get("cleave", 0.0)) > 0.0:
				cleaves = true
		if cleaves:
			out.append("Its blows cleave: they chew through the front of your pile into what's behind.")
		if float(d.get("stagger", 40.0)) >= 150.0:
			out.append("Very hard to stagger. Only a lot of blocking will break it.")
		elif float(d.get("stagger", 40.0)) <= 30.0:
			out.append("Staggers easily: block it a few times and it breaks.")
		if float(d.get("flinch", 1.0)) > 1.2:
			out.append("Flinches badly: a clean block leaves it open for longer.")
		if d.has("enrage"):
			out.append("Enrages below %d%% health and swings faster." % roundi(float(d.enrage.below) * 100.0))
		if d.has("riposte"):
			out.append("Answers a clean block with a riposte at your hand.")
		if d.get("guard", false):
			out.append("Its shield covers its torso until it's reeling or broken.")
		if d.has("bash_after"):
			out.append("After %d clean blocks in a row it bashes your pile apart." % int(d.bash_after))
		if float(d.get("weapon_mult", 1.0)) < 1.0:
			out.append("Plain steel does only %d%% to it." % roundi(float(d.weapon_mult) * 100.0))
		var em := float(d.get("elemental_mult", 1.0))
		if em > 1.0:
			out.append("Charged, hot or cold weapons do %d%% more." % roundi((em - 1.0) * 100.0))
		elif em < 1.0:
			out.append("Charged, hot or cold weapons do %d%% less." % roundi((1.0 - em) * 100.0))
		if float(d.get("punch_mult", 1.0)) <= 0.0:
			out.append("Punches pass straight through it.")
		if d.get("fireproof", false):
			out.append("Can't be set alight.")
		if d.get("cold_stagger", false):
			out.append("Cold hits stagger it outright.")
		if d.get("shockproof", false):
			out.append("Lightning doesn't bother it.")
		if d.get("dark", false):
			out.append("Puts the lights out.")
		if d.get("greedy", false):
			out.append("Its blows swallow any coin in their path, and it heals on them.")
		if d.get("distractible", false):
			out.append("A gold coin flung past it mid-swing makes it drop the swing to chase it.")
		if float(d.get("revive", 0.0)) > 0.0:
			out.append("Comes back once when it's killed.")
		if d.get("ink", false):
			out.append("A misprint: it fights like the last foe you met.")
		if float(d.get("corrode_mult", 1.0)) > 1.0:
			out.append("Its rotten plate corrodes twice as fast.")
		var traits := {"corrosive": "What blocks it rusts.", "burning": "What blocks it comes away hot.", "charged": "What blocks it is left charged."}
		var seen := {}
		for a in d.get("attacks", []):
			var tr: String = EnemyDefs.ATTACKS[a].get("trait", "")
			if traits.has(tr) and not seen.has(tr):
				seen[tr] = true
				out.append(traits[tr])
		return out

	## A worn ring: its name in the gem's colour, which finger, what it does, how to fire it.
	func _layout_ring(paint: bool) -> float:
		var hand: Hand = game.hand
		if finger >= hand.rings.size():
			return 40.0
		var uid: String = hand.rings[finger]
		var u: Dictionary = ItemDefs.UPGRADES[uid]
		var gem: Color = u.gem
		var accent := gem.lightened(0.2)
		var desc := str(u.desc).trim_prefix("RMB: ")
		desc = desc.substr(0, 1).to_upper() + desc.substr(1) + "."
		var desc_h := _text(desc, PAD, 0, W - PAD * 2, 12, INK, false)
		var h := PAD + 46 + desc_h + 8 + 20 + PAD
		if paint:
			_plate(Rect2(Vector2.ZERO, Vector2(W, h)), accent)
			_ring_icon(Vector2(W - 24, 24), 9.0, gem, 1.0)
			draw_string(font, Vector2(PAD, PAD + 20), str(u.title), HORIZONTAL_ALIGNMENT_LEFT, -1, _title_size(str(u.title), W - 60), accent)
			draw_string(font, Vector2(PAD, PAD + 36), "RING   %s FINGER" % Panels.FINGERS[finger], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
			_text(desc, PAD, PAD + 44, W - PAD * 2, 12, INK, true)
			var ky := PAD + 46 + desc_h + 8
			if u.cooldown > 0.0:
				_keycap(Vector2(PAD, ky), "RMB", 34)
				_keycap(Vector2(PAD + 40, ky), str(finger + 1), 20)
				var ready := 1.0 - hand.ring_cds[finger] / float(u.cooldown)
				_icon("hourglass", Vector2(PAD + 74, ky + 8), Color(1.0, 0.85, 0.4))
				_bar(Rect2(PAD + 84, ky + 3, W - PAD * 2 - 84, 10), ready, Color(1.0, 0.85, 0.4))
			else:
				var c := Color(0.6, 0.9, 0.6)
				draw_rect(Rect2(PAD, ky, 64, 16), Color(c.r, c.g, c.b, 0.2))
				draw_rect(Rect2(PAD, ky, 64, 16), c, false, 1.0)
				draw_string(font, Vector2(PAD, ky + 12), "PASSIVE", HORIZONTAL_ALIGNMENT_CENTER, 64, 11, c)
		return h

	## Lays out (and, when painting, draws) the card; returns its height.
	func _layout(paint: bool) -> float:
		var d: Dictionary = item.def
		var main_mat := Materials.get_mat(d.get("material", "wood"))
		font = ThemeDB.fallback_font
		var accent: Color = d.gem if d.has("gem") else main_mat.color
		accent = accent.lightened(0.25)
		var rarity: int = d.get("rarity", 0)
		if rarity > 0:
			accent = ItemDefs.RARITY_COLORS[rarity]  # uncommon and up wear their rarity colour
		if paint:
			_frame(accent)
		var y := PAD
		# title row: name, then the price as a coin (red when you can't afford it)
		var price_w := 0.0 if item.owned or not item.has_meta("price") else 54.0  # (a chip off shop stock isn't for sale)
		var shown := item.display_name()
		if paint:
			draw_string(font, Vector2(PAD, y + 20), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_size(shown, W - PAD * 2 - price_w), accent)
			if price_w > 0.0:
				var have: int = game.coin_total()
				var cost: int = int(item.get_meta("price"))
				var px := W - PAD - price_w + 4
				_coin(Vector2(px + 9, y + 13), 9.0)
				draw_string(font, Vector2(px + 22, y + 20), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
					Color(1.0, 0.85, 0.35) if have >= cost else Color(1.0, 0.35, 0.3))
		y += 26
		if paint:
			draw_string(font, Vector2(PAD, y + 10), _kind_tag(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
		y += 16
		# a named piece shows what it really is, and what it has slain
		if d.has("custom_name") or int(d.get("boss_kills", 0)) > 0 or int(d.get("kills", 0)) > 0:
			var line := ""
			if d.has("custom_name"):
				line = str(d.name)
			var foes := int(d.get("kills", 0))
			if foes > 0:
				line += ("   " if line != "" else "") + ("slew %d foe%s" % [foes, "" if foes == 1 else "s"])
			var kills := int(d.get("boss_kills", 0))
			if kills > 0:
				line += (", " if foes > 0 else ("   " if line != "" else "")) + ("%d boss%s" % [kills, "" if kills == 1 else "es"])
			if paint:
				draw_string(font, Vector2(PAD, y + 10), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.75, 0.35))
			y += 16
		# materials as swatches
		var mats := {}
		for c in item.cells:
			mats[item.cells[c].mat] = true
		var x := PAD
		for m in mats:
			var mc: Color = d.gem if m == "gem" and d.has("gem") else Materials.get_mat(m).color
			var label := str(m).capitalize()
			var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if x + 14 + lw > W - PAD and x > PAD:
				x = PAD  # too many materials for one row: wrap
				y += 18
			if paint:
				draw_rect(Rect2(x, y + 2, 10, 10), mc)
				draw_rect(Rect2(x, y + 2, 10, 10), Color(0, 0, 0, 0.6), false, 1.0)
				draw_string(font, Vector2(x + 14, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
			x += 14 + lw + 12
		y += 22
		# what a utility does, in plain words
		if d.has("effect"):
			y += _text(str(d.effect), PAD, y, W - PAD * 2, 12, Color(0.85, 0.95, 0.75), paint) + 6
		# stat bars
		for st in _stats(d):
			if paint:
				_stat_row(y, st[0], st[1], st[2], st[3])
			y += 17
		# modifiers as colour-coded chips, each with its one-line effect
		if not d.modifiers.is_empty():
			y += 4
			for m in d.modifiers:
				var rare: bool = ItemDefs.MODIFIERS[m].get("rare", false)
				var epic: bool = ItemDefs.MODIFIERS[m].get("epic", false)
				var col: Color = EPIC if epic else (Color(1.0, 0.82, 0.3) if rare else MOD_COLORS.get(m, INK))
				var mname := ("EPIC: " if epic else ("RARE: " if rare else "")) + str(ItemDefs.MODIFIERS[m].get("name", m)).to_upper()
				var cw := font.get_string_size(mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
				if paint:
					draw_rect(Rect2(PAD, y, cw, 16), Color(col.r, col.g, col.b, 0.22))
					draw_rect(Rect2(PAD, y, cw, 16), col, false, 1.0)
					draw_string(font, Vector2(PAD + 6, y + 12), mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
				# the effect wraps under the chip, as many lines as it needs
				y += 18 + _text(str(ItemDefs.MODIFIERS[m].desc), PAD + 2, y + 18, W - PAD * 2 - 2, 11, DIM, paint) + 6
		# what Space does with it, as a keycap
		var verb := _verb(d)
		if verb != "":
			y += 4
			if paint:
				_keycap(Vector2(PAD, y), "SPACE")
			y += maxf(20.0, _text(verb, PAD + 54, y + 1, W - PAD * 2 - 54, 12, INK, paint) + 4)
		return y + PAD - 2

	func _kind_tag(d: Dictionary) -> String:
		var rarity: int = d.get("rarity", 0)
		var prefix: String = "" if rarity == 0 else ItemDefs.RARITY_NAMES[rarity].to_upper() + "   "
		return prefix + _kind_name(d)

	func _kind_name(d: Dictionary) -> String:
		match d.kind:
			"crate":
				return "CRATE   " + "★".repeat(int(d.get("loot", 1))) + "   contents: ?"
			"coin":
				return "COIN"
			"upgrade":
				return "RING" if ItemDefs.UPGRADES[d.upgrade].get("ring", false) else "HAND UPGRADE"
			"menu":
				return "HOME"
		return str(d.kind).to_upper()

	func _verb(d: Dictionary) -> String:
		if item and is_instance_valid(item) and item.def.has("parts") and game and game.hand.held == item:
			d = item.part_at_local(game.hand.grab_local)  # a glued thing does what the part you hold does
		match d.kind:
			"weapon":
				for m in ["electrified", "superheated", "frosty"]:
					if d.modifiers.has(m):
						return "swing (hold it by the wrapped handle: safe)"
				return "swing"
			"upgrade":
				return "put on: " + str(ItemDefs.UPGRADES[d.upgrade].desc)
			"shield":
				return "brace: for a moment every block is a parry"
			"potion":
				if d.get("liquid", "") == "homeward":
					return "break it: the nearest thing goes home"
				return "smash it: it spills where it breaks"
			"menu":
				if d.get("menu", "") == "codex" and game and game.get("codex") != null:
					var pr: Array = game.codex.progress(int(d.get("tab", 0)))
					return "open it (%d of %d found)" % [pr[0], pr[1]]
				return "open it" if d.get("menu", "") == "codex" else "try another gauntlet"
			"consumable":
				if d.has("heal"):
					return "bind your hand"
				if d.has("applies"):
					return "make what it touches " + str(d.applies)
		return ""

	## [icon, short label, 0..1, bar colour]
	func _stats(d: Dictionary) -> Array:
		var out: Array = []
		if d.kind == "coin":
			return out
		var block := 0.0
		for c in item.cells:
			var cell: Dictionary = item.cells[c]
			block += Materials.get_mat(cell.mat).block * (0.85 + 0.15 * clampf(cell.hp / cell.max, 0.0, 1.0))
		block = block / maxf(1.0, item.cells.size()) * d.get("guard", 1.0)
		out.append(["shield", "BLOCK", clampf((block - 0.4) / 0.6, 0.0, 1.0), Color(0.55, 0.75, 1.0)])
		if d.kind == "weapon":
			var dmg: float = d.swing_damage * Materials.get_mat(d.material).sharp * item.edge_condition()
			out.append(["sword", "DAMAGE", clampf(dmg / 35.0, 0.0, 1.0), Color(1.0, 0.45, 0.35)])  # relative: same scale for every weapon
			out.append(["hourglass", "SPEED", clampf(1.0 - (float(d.cooldown) - 0.7) / 1.1, 0.05, 1.0), Color(1.0, 0.85, 0.4)])
		out.append(["weight", "WEIGHT", clampf(item.mass / 250.0, 0.03, 1.0), Color(0.7, 0.65, 0.6)])
		out.append(["brick", "TOUGH", clampf(log(maxf(item.max_total, 1.0)) / log(4000.0), 0.03, 1.0), Color(0.8, 0.7, 0.55)])
		var cond := item.health_ratio()
		out.append(["heart", "CONDITION", cond, Color(0.9, 0.25, 0.2).lerp(Color(0.45, 0.9, 0.4), cond)])
		return out

	func _stat_row(y: float, icon: String, label: String, v: float, col: Color) -> void:
		_icon(icon, Vector2(PAD + 7, y + 7), col)
		draw_string(font, Vector2(PAD + 18, y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)
		_bar(Rect2(PAD + 82, y + 2, W - PAD * 2 - 82, 10), v, col)

	## Dark iron plate with a material-coloured border, a tinted title band and rivets.
	func _frame(accent: Color) -> void:
		_plate(Rect2(Vector2.ZERO, size), accent)
		draw_rect(Rect2(2, 2, size.x - 4, 42), Color(accent.r, accent.g, accent.b, 0.12))  # title band
		if item.def.kind == "coin":
			_coin(Vector2(size.x - 22, 22), 10.0)
			draw_string(font, Vector2(size.x - 58, 28), str(item.def.value), HORIZONTAL_ALIGNMENT_RIGHT, 30, 18, Color(1, 0.85, 0.35))
