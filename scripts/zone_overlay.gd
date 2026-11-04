class_name ZoneOverlay
extends Node2D
## Draws the in-world layer under the items: the incoming attack zone, the enemy's weak
## spot, shop shelves and the gong, plus sparks and impact rings. No text, no numbers.

var poly := PackedVector2Array()
var progress := 0.0
var dir := Vector2.ZERO  # which way the blade will travel (zero = a thrust at the screen)
var weak: Dictionary = {}  # the weak spot's screen circle, when open (only while broken)
var exposed: Array = []    # screen circles where armour was stripped
var shelves: Array = []    # {rect, price, paid}: paid lights up the price pips
var gong: Dictionary = {}  # {pos, radius}
var dice: Dictionary = {}  # {pos, radius}: punch to reroll
var chute: Dictionary = {}  # {pos, radius}: the shop's scrap chute
var door: Dictionary = {}  # {pos, radius}: after a boss, the way home (punch it holding something)
var racks: Array = []      # home: {pos, kind, item} slots where kept gear hangs
var tint := Color(1, 0.3, 0.2)  # the telegraph's colour: red steel, green rot, orange fire, blue lightning
var zones: Array = []  # a second enemy's telegraph, when two are winding up at once: {poly, progress, dir, weight, trait, lanes, cover}
var lanes: Array = []  # the incoming blow's lanes (Lanes.build), drawn as arrows
var cover: Array = []  # per lane, how much of the blow your gear would let through right now (0..1)
var _result_lanes: Array = []  # the last blow's lanes, flashed by how each one ended
var _result_left: Array = []
var _result_t := 0.0
var wisps: Array = []  # Wisp Cannon fire in flight: {pos, color, size}
var storms: Array = []  # Stormcaller storms on a foe: {pos, kind, t, color}
var marks: Array = []  # element marks on foes: {pos, pips: [{color, left 0..1}]}
var dice_price := 0
var dice_paid := 0
var enemy_fire := Rect2()  # where to draw flames when the enemy is burning
var water_y := -1.0  # Cistern floodwater surface, when there is any
var hearth := Rect2()  # Forge hearth heat zone
var _gong_swing := 0.0
var _flash_poly := PackedVector2Array()
var _flash_t := 0.0
var _flash_leak := 0.0
var _sparks: Array = []  # {pos, vel, life, size, color}
var _rings: Array = []   # {pos, radius, life, max, color}
var _streaks: Array = []  # {a, b, width, life, max, color}
var _pulse := 0.0  # red edge-of-screen pulse when a blow gets through


var weight := 1.0  # how heavy the incoming blow is (thickens the outline)


const LANE_BLOCKED := Color(0.55, 0.85, 1.0)
const LANE_PARTIAL := Color(1.0, 0.75, 0.25)
const LANE_OPEN := Color(1.0, 0.25, 0.18)
const RESULT_TIME := 0.7
const TRAIT_TINT := {"corrosive": Color(0.55, 0.95, 0.3), "burning": Color(1.0, 0.55, 0.1), "charged": Color(0.55, 0.8, 1.0)}


func show_zone(p: PackedVector2Array, prog: float, d: Vector2 = Vector2.ZERO, w: float = 1.0, kind: String = "") -> void:
	poly = p
	progress = prog
	dir = d
	weight = w
	tint = TRAIT_TINT.get(kind, Color(1, 0.3, 0.2))


func clear_zone() -> void:
	poly = PackedVector2Array()
	lanes = []
	cover = []


## The blow landed: flash each lane by what was left of it at the end.
func lane_result(l: Array, left: Array) -> void:
	_result_lanes = l
	_result_left = left
	_result_t = RESULT_TIME


static func lane_color(left: float) -> Color:
	if left < 0.15:
		return LANE_BLOCKED
	if left < 0.6:
		return LANE_PARTIAL
	return LANE_OPEN


func flash(p: PackedVector2Array, leak: float) -> void:
	_flash_poly = p
	_flash_t = 0.3
	_flash_leak = leak


## Burst size and speed scale with momentum, so a heavy parry reads heavier.
const SPARK_CAP := 260


func sparks(at: Vector2, momentum: float, col: Color = Color(1, 0.9, 0.5)) -> void:
	var n := mini(clampi(int(momentum / 4000.0), 2, 24), SPARK_CAP - _sparks.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(100.0, 200.0 + momentum * 0.004)
		_sparks.append({"pos": at, "vel": v, "life": randf_range(0.2, 0.5), "size": clampf(momentum / 20000.0, 1.0, 4.0), "color": col})


## An expanding ring: hits, blocks and parries read by size and colour instead of text.
func ring(at: Vector2, radius: float, col: Color, life: float = 0.35) -> void:
	_rings.append({"pos": at, "radius": radius, "life": life, "max": life, "color": col})


## A slash streak, e.g. from where a blow landed to the hand it got through to.
func streak(a: Vector2, b: Vector2, width: float, col: Color, life: float = 0.35) -> void:
	_streaks.append({"a": a, "b": b, "width": width, "life": life, "max": life, "color": col})


func pulse(amount: float) -> void:
	_pulse = maxf(_pulse, clampf(amount, 0.0, 1.0))


## A starburst of rays: the parry flash.
func starburst(at: Vector2, radius: float, col: Color) -> void:
	for i in 12:
		var dir := Vector2.from_angle(i * TAU / 12.0 + randf() * 0.2)
		streak(at + dir * radius * 0.2, at + dir * radius * (0.8 + randf() * 0.5), 4.0, col, 0.3)


func ring_gong() -> void:
	_gong_swing = 1.0


func _process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	_result_t = maxf(0.0, _result_t - delta)
	_gong_swing = maxf(0.0, _gong_swing - delta * 0.6)
	for s in _sparks:
		s.pos += s.vel * delta
		s.vel = s.vel * 0.9 + Vector2(0, 600.0 * delta)
		s.life -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r.life > 0.0)
	for st in _streaks:
		st.life -= delta
	_streaks = _streaks.filter(func(st: Dictionary) -> bool: return st.life > 0.0)
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	_draw_shop()
	if hearth.size != Vector2.ZERO:
		var t := Time.get_ticks_msec() * 0.001
		for i in 4:
			var r := hearth.grow(-i * 18.0)
			draw_rect(r, Color(1.0, 0.45, 0.1, 0.05 + 0.02 * sin(t * 3.0 + i)))
		for i in 6:
			var x := hearth.position.x + fmod(t * 40.0 + i * 53.0, hearth.size.x)
			var y := hearth.end.y - fmod(t * 60.0 + i * 37.0, hearth.size.y)
			draw_line(Vector2(x, y), Vector2(x + sin(t * 4.0 + i) * 4.0, y - 10.0), Color(1, 0.6, 0.2, 0.3), 1.5)
	var mine := [poly, progress, dir, weight, tint, lanes, cover]
	for z in zones:
		poly = z.poly
		progress = z.progress
		dir = z.dir
		weight = z.weight
		tint = TRAIT_TINT.get(z.trait, Color(1, 0.3, 0.2))
		lanes = z.get("lanes", [])
		cover = z.get("cover", [])
		_draw_zone()
		_draw_lanes()
	poly = mine[0]
	progress = mine[1]
	dir = mine[2]
	weight = mine[3]
	tint = mine[4]
	lanes = mine[5]
	cover = mine[6]
	_draw_zone()
	_draw_lanes()
	_draw_lane_result()
	for e in exposed:
		draw_arc(e.center, e.radius, 0.0, TAU, 20, Color(1, 0.35, 0.25, 0.35), 1.5)
	if not weak.is_empty():
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.015)
		draw_arc(weak.center, weak.radius * (1.0 + 0.2 * pulse), 0.0, TAU, 20, Color(1, 0.8, 0.2, pulse), 2.0)
	if _flash_t > 0.0 and _flash_poly.size() >= 3:
		draw_colored_polygon(_flash_poly, Color(1, 1.0 - _flash_leak, 1.0 - _flash_leak, _flash_t * 2.0))
	for r in _rings:
		var k: float = 1.0 - r.life / r.max
		var col: Color = r.color
		col.a = 1.0 - k
		draw_arc(r.pos, r.radius * (0.3 + k), 0.0, TAU, 28, col, 3.0 * (1.0 - k) + 1.0)
	for st in _streaks:
		var k: float = st.life / st.max
		var col: Color = st.color
		col.a = k
		draw_line(st.a, st.b, Color(0, 0, 0, 0.5 * k), st.width * k + 3.0)
		draw_line(st.a, st.b, col, st.width * k + 1.0)
	if _pulse > 0.0:
		for i in 6:
			var w := 6.0 + i * 6.0
			var a := _pulse * 0.12 * (1.0 - i / 6.0)
			draw_rect(Rect2(0, 0, 1280, w), Color(0.8, 0.0, 0.0, a))
			draw_rect(Rect2(0, 720 - w, 1280, w), Color(0.8, 0.0, 0.0, a))
			draw_rect(Rect2(0, 0, w, 720), Color(0.8, 0.0, 0.0, a))
			draw_rect(Rect2(1280 - w, 0, w, 720), Color(0.8, 0.0, 0.0, a))
	if water_y > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		var pts := PackedVector2Array()
		for i in 33:
			var x := i * 40.0
			pts.append(Vector2(x, water_y + sin(t * 2.0 + i * 0.7) * 3.0))
		var poly := pts.duplicate()
		poly.append(Vector2(1280, 720))
		poly.append(Vector2(0, 720))
		draw_colored_polygon(poly, Color(0.1, 0.35, 0.3, 0.35))
		draw_polyline(pts, Color(0.6, 0.95, 0.85, 0.6), 2.0)
	for w in wisps:
		var wc: Color = w.color
		var k: float = w.size
		draw_circle(w.pos, 13.0 * k, Color(0, 0, 0, 0.4))
		draw_circle(w.pos, 11.0 * k, Color(wc.r, wc.g, wc.b, 0.45))
		draw_circle(w.pos, 7.0 * k, Color(wc.r, wc.g, wc.b, 0.9))
		draw_circle(w.pos, 3.5 * k, wc.lightened(0.6))
	_draw_storms()
	_draw_marks()
	for s in _sparks:
		var col: Color = s.color
		col.a = minf(1.0, s.life * 4.0)
		draw_rect(Rect2(s.pos - Vector2.ONE * s.size * 0.5, Vector2.ONE * s.size), col)


func _draw_dice() -> void:
	var p: Vector2 = dice.pos
	for k in 2:
		var c := p + Vector2(-14 + k * 26, sin(k * 2.0) * 4.0)
		var r := Rect2(c - Vector2(11, 11), Vector2(22, 22))
		draw_rect(r.grow(1.5), Color(0.15, 0.12, 0.1))
		draw_rect(r, Color(0.9, 0.86, 0.76))
		var pips: Array = [[Vector2(-5, -5), Vector2(5, 5)], [Vector2(-5, -5), Vector2(0, 0), Vector2(5, 5)]][k]
		for q in pips:
			draw_circle(c + q, 2.2, Color(0.15, 0.1, 0.08))
	# the price, as coin pips under the dice (none when a horseshoe makes it free)
	var x := p.x - 4.0 * dice_price
	for i in dice_price:
		draw_circle(Vector2(x + i * 9, p.y + 22), 3.0, Color(0.95, 0.75, 0.22) if dice_paid > i else Color(0.35, 0.28, 0.12))


func _draw_shop() -> void:
	for slot in racks:
		# a peg on the wall (weapons) or a little shelf (anything), lit when something hangs there
		var p: Vector2 = slot.pos
		var taken: bool = slot.item != null and is_instance_valid(slot.item)
		if slot.kind == "weapon":
			draw_rect(Rect2(p + Vector2(-26, -70), Vector2(52, 4)), Color(0.36, 0.23, 0.12))
			draw_rect(Rect2(p + Vector2(-3, -70), Vector2(6, 10)), Color(0.28, 0.18, 0.1))
			if not taken:
				draw_rect(Rect2(p + Vector2(-8, -52), Vector2(16, 100)), Color(1, 1, 1, 0.04))
		else:
			if not slot.get("mantel", false):
				# a wall shelf board with brackets (the mantel row stands on the mantel itself)
				draw_rect(Rect2(p + Vector2(-38, 28), Vector2(76, 8)), Color(0.36, 0.23, 0.12))
				draw_rect(Rect2(p + Vector2(-38, 28), Vector2(76, 2)), Color(0.5, 0.33, 0.18))
				draw_rect(Rect2(p + Vector2(-30, 36), Vector2(5, 14)), Color(0.28, 0.18, 0.1))
				draw_rect(Rect2(p + Vector2(25, 36), Vector2(5, 14)), Color(0.28, 0.18, 0.1))
			if not taken:
				draw_rect(Rect2(p + Vector2(-30, -24), Vector2(60, 50)), Color(1, 1, 1, 0.04))
	for sh in shelves:
		var r: Rect2 = sh.rect
		draw_rect(r, Color(0.36, 0.23, 0.12))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.5, 0.33, 0.18))
		draw_rect(Rect2(r.position + Vector2(6, r.size.y), Vector2(4, 14)), Color(0.28, 0.18, 0.1))  # brackets
		draw_rect(Rect2(r.end - Vector2(10, 0), Vector2(4, 14)), Color(0.28, 0.18, 0.1))
		# the stat shelf wears a green cloth, the ring shelves a gold one
		match sh.get("kind", "gear"):
			"stat":
				draw_rect(Rect2(r.position + Vector2(10, -3), Vector2(r.size.x - 20, 5)), Color(0.35, 0.55, 0.25))
			"ring":
				draw_rect(Rect2(r.position + Vector2(10, -3), Vector2(r.size.x - 20, 5)), Color(0.75, 0.6, 0.2))
		# a gem on the shelf's corner shows how rare the stock is (none for common)
		var rarity: int = sh.get("rarity", 0)
		if rarity > 0:
			var gc: Color = ItemDefs.RARITY_COLORS[rarity]
			var gp := Vector2(r.end.x - 12, r.position.y + 5)
			draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -6), gp + Vector2(5, 0), gp + Vector2(0, 6), gp + Vector2(-5, 0)]), gc)
			if rarity == 3:
				draw_arc(gp, 9.0 + sin(Time.get_ticks_msec() * 0.006) * 2.0, 0.0, TAU, 12, Color(gc.r, gc.g, gc.b, 0.6), 1.5)
		# the price as coins on the shelf's front edge: big pip = 5, small = 1; lit once paid
		var price: int = sh.price
		var paid: int = sh.paid
		var x := r.position.x + 14.0
		var y := r.end.y + 9.0
		var counted := 0
		for i in int(price / 5.0):
			var lit := paid >= counted + 5
			draw_circle(Vector2(x, y), 5.0, Color(0.95, 0.75, 0.22) if lit else Color(0.35, 0.28, 0.12))
			counted += 5
			x += 13.0
		for i in price % 5:
			var lit := paid >= counted + 1
			draw_circle(Vector2(x, y), 3.0, Color(0.95, 0.75, 0.22) if lit else Color(0.35, 0.28, 0.12))
			counted += 1
			x += 9.0
	if not dice.is_empty():
		_draw_dice()
	if not chute.is_empty():
		# an iron hopper set in the wall: a funnel mouth with a grate across it
		var p: Vector2 = chute.pos
		var r: float = chute.radius
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.7), p + Vector2(r, -r * 0.7),
			p + Vector2(r * 0.45, r * 0.7), p + Vector2(-r * 0.45, r * 0.7)]), Color(0.22, 0.2, 0.2))
		draw_rect(Rect2(p + Vector2(-r * 0.75, -r * 0.45), Vector2(r * 1.5, r * 0.9)), Color(0.05, 0.04, 0.04))
		for k in 5:
			var x := p.x - r * 0.6 + k * r * 0.3
			draw_line(Vector2(x, p.y - r * 0.45), Vector2(x, p.y + r * 0.45), Color(0.4, 0.37, 0.35), 2.0)
		draw_rect(Rect2(p + Vector2(-r, -r * 0.7), Vector2(r * 2, 4)), Color(0.45, 0.42, 0.4))
	if not door.is_empty():
		# an arched door with a lantern over it: the way home, if you're carrying something
		var p: Vector2 = door.pos
		var rad: float = door.radius
		draw_rect(Rect2(p + Vector2(-rad, -rad * 0.4), Vector2(rad * 2, rad * 1.6)), Color(0.3, 0.19, 0.1))
		draw_circle(p + Vector2(0, -rad * 0.4), rad, Color(0.3, 0.19, 0.1))
		draw_rect(Rect2(p + Vector2(-rad + 6, -rad * 0.4), Vector2(rad * 2 - 12, rad * 1.6)), Color(0.42, 0.27, 0.14))
		draw_circle(p + Vector2(0, -rad * 0.4), rad - 6, Color(0.42, 0.27, 0.14))
		for k in 3:
			draw_rect(Rect2(p + Vector2(-rad + 6, -rad * 0.2 + k * 22), Vector2(rad * 2 - 12, 3)), Color(0.2, 0.14, 0.08))  # planks
		draw_circle(p + Vector2(rad * 0.45, rad * 0.4), 4.0, Color(0.85, 0.65, 0.25))  # handle
		var glow := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(Rect2(p + Vector2(-5, -rad - 30), Vector2(10, 14)), Color(1.0, 0.8, 0.35, glow))  # the lantern
		draw_circle(p + Vector2(0, -rad - 23), 18.0, Color(1.0, 0.8, 0.35, 0.12 * glow))
	if enemy_fire.size != Vector2.ZERO:
		for i in 18:
			var x := enemy_fire.position.x + randf() * enemy_fire.size.x
			var y := enemy_fire.position.y + randf() * enemy_fire.size.y
			var fh := randf_range(8.0, 26.0)
			draw_rect(Rect2(x, y - fh, 5, fh), Color(1.0, randf_range(0.35, 0.8), 0.1, 0.8))
	if not gong.is_empty():
		var p: Vector2 = gong.pos
		var rad: float = gong.radius
		var sway := sin(Time.get_ticks_msec() * 0.02) * _gong_swing * 8.0
		var c := p + Vector2(sway, 0)
		draw_line(Vector2(p.x - 30, p.y - rad - 40), Vector2(p.x + 30, p.y - rad - 40), Color(0.3, 0.2, 0.1), 6.0)
		draw_line(Vector2(p.x - 20, p.y - rad - 40), c + Vector2(-12, -rad + 4), Color(0.5, 0.45, 0.35), 2.0)
		draw_line(Vector2(p.x + 20, p.y - rad - 40), c + Vector2(12, -rad + 4), Color(0.5, 0.45, 0.35), 2.0)
		draw_circle(c, rad, Color(0.6, 0.42, 0.18))
		draw_circle(c, rad * 0.75, Color(0.7, 0.5, 0.22))
		draw_circle(c, rad * 0.25, Color(0.5, 0.35, 0.15))
		if _gong_swing > 0.0:
			draw_arc(c, rad * (1.0 + (1.0 - _gong_swing) * 0.8), 0.0, TAU, 32, Color(1, 0.85, 0.4, _gong_swing * 0.6), 2.0)


# --- attack telegraph designs --------------------------------------------------

func _draw_zone() -> void:
	if poly.size() < 3:
		return
	match Looks.pick("telegraph"):
		"Blade Path":
			_draw_blade_path()
		"Looming Shadow":
			_draw_looming_shadow()
		"Scratch Marks":
			_draw_scratches()
		"Lock-on Brackets":
			_draw_brackets()
		_:
			_draw_red_zone()


## The lanes of the incoming blow, as arrows the way the blade will travel, each coloured
## by what's in its way right now: blue, your gear stops it; amber, it gets partly
## through; red, it's open. Chevrons march down each arrow faster as the blow comes in.
## A thrust's lanes are target marks closing in on the points it will strike.
func _draw_lanes() -> void:
	if poly.size() < 3 or lanes.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	var march := fmod(t * (0.8 + progress * 5.0), 1.0)
	var alpha := 0.55 + 0.45 * progress
	if (lanes[0] as Array).size() == 1:
		# a thrust: one ring closing in on its points, ticks pointing inward
		var c := _centre()
		var r := 0.0
		for v in poly:
			r = maxf(r, v.distance_to(c))
		r = r * (1.6 - 0.8 * progress) + 6.0
		var ring_col := Color(1.0, 0.85, 0.75, alpha)
		draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, alpha * 0.7), 5.0)
		draw_arc(c, r, 0.0, TAU, 32, ring_col, 2.0)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * (r + 14.0), c + d * (r + 2.0), Color(0, 0, 0, alpha * 0.7), 5.0)
			draw_line(c + d * (r + 14.0), c + d * (r + 2.0), ring_col, 2.0)
	for i in lanes.size():
		var lane: Array = lanes[i]
		var left: float = cover[i] if i < cover.size() else 1.0
		var col := lane_color(left)
		# what you've covered steps back; what's still open is what you look at
		var lane_alpha := alpha * (0.35 if left < 0.15 else 1.0)
		col.a = lane_alpha
		var back := Color(0, 0, 0, lane_alpha * 0.7)
		if lane.size() == 1:
			draw_circle(lane[0], 6.0, back)
			draw_circle(lane[0], 4.0, col)
			continue
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[lane.size() - 1]
		var d := (b - a).normalized()
		var side := d.orthogonal()
		var open := left >= 0.15
		draw_line(a, b, back, 6.0 if open else 4.0)
		draw_line(a, b, col, 2.0 if open else 1.0)
		var head := PackedVector2Array([b + d * 6.0, b - d * 16.0 + side * 10.0, b - d * 16.0 - side * 10.0])
		draw_colored_polygon(head, back)
		draw_colored_polygon(PackedVector2Array([b + d * 3.0, b - d * 13.0 + side * 7.0, b - d * 13.0 - side * 7.0]), col)
		if not open:
			continue  # a covered lane is just a faint line: no marching chevrons
		var length := a.distance_to(b) - 18.0
		var step := 120.0
		var x := march * step
		while x < length:
			var p := a + d * x
			var chev := PackedVector2Array([p - d * 9.0 + side * 8.0, p, p - d * 9.0 - side * 8.0])
			draw_polyline(chev, back, 6.0)
			draw_polyline(chev, col, 3.0)
			x += step


## Element marks over a foe's head: a small dot per element, its ring running down as the
## mark fades. Two different ones never sit together for long: they react.
func _draw_marks() -> void:
	for m in marks:
		var pips: Array = m.pips
		var x0: float = m.pos.x - (pips.size() - 1) * 9.0
		for i in pips.size():
			var p := Vector2(x0 + i * 18.0, m.pos.y)
			var col: Color = pips[i].color
			draw_circle(p, 7.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 5.0, col)
			draw_arc(p, 9.0, -PI * 0.5, -PI * 0.5 + TAU * float(pips[i].left), 16, Color(col.r, col.g, col.b, 0.8), 1.5)


## A Stormcaller's storm on a foe: a whirling column of its element (embers for a
## firestorm, flakes for a blizzard, drops for acid rain), narrow at the foot and wide at
## the top, fading as it blows itself out.
func _draw_storms() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for st in storms:
		var base: Vector2 = st.pos
		var col: Color = st.color
		var fade := clampf(float(st.t) / 0.6, 0.0, 1.0)
		for ring_i in 5:
			var h := ring_i / 4.0
			var y := base.y - h * 170.0
			var r := 10.0 + h * h * 55.0
			var sway := sin(t * 3.0 + h * 4.0) * 18.0 * h
			var c := Vector2(base.x + sway, y)
			var a0 := t * 9.0 + h * 2.0
			draw_arc(c, r, a0, a0 + PI * 1.2, 16, Color(0, 0, 0, 0.3 * fade), 5.0)
			draw_arc(c, r, a0, a0 + PI * 1.2, 16, Color(col.r, col.g, col.b, 0.7 * fade), 2.5)
		for k in 10:
			var h := fmod(t * 0.6 + k * 0.137, 1.0)
			var ang := t * 8.0 + k * 1.7
			var r := 10.0 + h * h * 55.0
			var p := Vector2(base.x + cos(ang) * r + sin(t * 3.0 + h * 4.0) * 18.0 * h, base.y - h * 170.0 + sin(ang) * r * 0.25)
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(col.r, col.g, col.b, 0.8 * (1.0 - h) * fade).lightened(0.4))


## Just after a blow: each lane flashes the colour of how it ended, so a hit that got
## through shows exactly which arrow nothing was on.
func _draw_lane_result() -> void:
	if _result_t <= 0.0:
		return
	var k := _result_t / RESULT_TIME
	for i in _result_lanes.size():
		var lane: Array = _result_lanes[i]
		var left: float = _result_left[i] if i < _result_left.size() else 1.0
		var col := lane_color(left)
		col.a = k
		var w := 3.0 + 6.0 * left
		if lane.size() == 1:
			draw_circle(lane[0], 6.0 + 10.0 * left, Color(col.r, col.g, col.b, k * 0.8))
			continue
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[lane.size() - 1]
		draw_line(a, b, Color(0, 0, 0, k * 0.6), w + 4.0)
		draw_line(a, b, col, w)


func _centre() -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out


func _scaled(p: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := _centre()
	var out := PackedVector2Array()
	for v in p:
		out.append(c + (v - c) * k)
	return out


## Lines through the zone along the blade's travel, clipped to the zone.
func _lanes(spacing: float) -> Array:
	var across := dir.orthogonal()
	var c := _centre()
	var lo := INF
	var hi := -INF
	for v in poly:
		var a := (v - c).dot(across)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	var out: Array = []
	var off := lo + spacing * 0.5
	while off < hi:
		var base := c + across * off
		var seg := PackedVector2Array([base - dir * 2000.0, base + dir * 2000.0])
		for piece in Geometry2D.intersect_polyline_with_polygon(seg, poly):
			out.append(piece)
		off += spacing
	return out


## Red Zone: the original filled area with a growing inner fill as the timing cue.
func _draw_red_zone() -> void:
	var base := tint.darkened(0.2)
	draw_colored_polygon(poly, Color(base.r, base.g, base.b, 0.06 + 0.2 * progress))
	if progress > 0.02:
		draw_colored_polygon(_scaled(poly, progress), Color(tint.r, tint.g, tint.b, 0.12 + 0.2 * progress))
	draw_polyline(_closed(poly), Color(tint.r, tint.g, tint.b, 0.5 + 0.5 * progress), 1.0 + 2.5 * weight)


## Blade Path: streaks run the way the blade will travel, with chevrons marching along
## them faster and faster. A thrust shows rings closing in on the point instead.
func _draw_blade_path() -> void:
	var col := Color(1.0, 0.85, 0.7, 0.15 + 0.5 * progress).lerp(tint, 0.3)
	draw_polyline(_closed(poly), Color(tint.r, tint.g, tint.b, 0.25 + 0.4 * progress), 1.0)
	if dir == Vector2.ZERO:
		var c := _centre()
		var r := 0.0
		for v in poly:
			r = maxf(r, v.distance_to(c))
		r *= 2.5
		for i in 3:
			var k := fmod(progress * 3.0 + i / 3.0, 1.0)
			draw_arc(c, r * (1.0 - k), 0.0, TAU, 24, Color(1, 0.4, 0.3, k), 2.0)
		draw_circle(c, 3.0 + 6.0 * progress, Color(1, 0.3, 0.2, progress))
		return
	if not lanes.is_empty():
		if progress > 0.85:
			draw_colored_polygon(poly, Color(tint.r, tint.g, tint.b, (progress - 0.85) * 2.0))
		return  # the lane arrows are the blade's path
	var t := Time.get_ticks_msec() * 0.001
	var march := fmod(t * (1.0 + progress * 6.0), 1.0)
	var side := dir.orthogonal() * 8.0
	for seg in _lanes(30.0):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[seg.size() - 1]
		if (b - a).dot(dir) < 0.0:
			var tmp := a
			a = b
			b = tmp
		draw_line(a, b, Color(col.r, col.g, col.b, col.a * 0.35), 1.0)
		var length := a.distance_to(b)
		var step := 56.0
		var x := march * step
		while x < length:
			var p := a + dir * x
			var chev := PackedVector2Array([p - dir * 10.0 + side, p, p - dir * 10.0 - side])
			draw_polyline(chev, Color(0, 0, 0, col.a * 0.8), 6.0)  # dark backing so it reads on any colour
			draw_polyline(chev, col, 3.0)
			x += step
	if progress > 0.85:
		draw_colored_polygon(poly, Color(tint.r, tint.g, tint.b, (progress - 0.85) * 2.0))


## Looming Shadow: the zone darkens like something heavy is about to come down on it,
## soft-edged, deepening with the wind-up, flickering red right before the strike.
func _draw_looming_shadow() -> void:
	for i in 5:
		var k := 1.0 - i * 0.04
		draw_colored_polygon(_scaled(poly, k), Color(0, 0, 0, 0.08 + 0.1 * progress))
	var dash := 12.0
	var cl := _closed(poly)
	for i in cl.size() - 1:
		var a: Vector2 = cl[i]
		var b: Vector2 = cl[i + 1]
		var n := int(a.distance_to(b) / dash)
		for j in range(0, n, 2):
			draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(0, 0, 0, 0.6), 2.0)
	if progress > 0.8 and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		draw_colored_polygon(poly, Color(tint.r * 0.7, tint.g * 0.3, tint.b * 0.3, 0.25))


## Scratch Marks: claw-like strokes are gouged across the zone along the blade's travel,
## one more every beat of the wind-up, turning red when it lands.
func _draw_scratches() -> void:
	var lanes: Array = []
	if dir == Vector2.ZERO:
		var c := _centre()
		for i in 6:
			var ang := i * TAU / 6.0 + 0.3
			lanes.append(PackedVector2Array([c + Vector2.from_angle(ang) * 50.0, c + Vector2.from_angle(ang) * 8.0]))
	else:
		lanes = _lanes(20.0)
	if lanes.is_empty():
		return
	var shown := int((0.15 + progress) * lanes.size() * 1.2)
	var col := Color(0.95, 0.9, 0.8, 0.85).lerp(tint, smoothstep(0.75, 1.0, progress))
	for i in mini(shown, lanes.size()):
		var seg: PackedVector2Array = lanes[(i * 7) % lanes.size()]
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[seg.size() - 1]
		var pts := PackedVector2Array()
		var n := 8
		for j in n + 1:
			var p := a.lerp(b, float(j) / n)
			var h := float((i * 31 + j * 17) % 7) - 3.0
			pts.append(p + (b - a).orthogonal().normalized() * h)
		draw_polyline(pts, Color(0, 0, 0, 0.7), 6.0 if i % 2 == 0 else 4.0)  # gouge shadow
		draw_polyline(pts, col, 3.0 if i % 2 == 0 else 2.0)


## Lock-on Brackets: no fill at all. Corner brackets start wide and close onto the zone;
## when they meet, it lands. A small arrow in the middle shows the blade's direction.
func _draw_brackets() -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		r = r.expand(v)
	r = r.grow((1.0 - progress) * 120.0)
	r = r.intersection(Rect2(10, 10, 1260, 700))  # full-width attacks: keep the brackets on screen
	var arm := minf(30.0, minf(r.size.x, r.size.y) * 0.3)
	var col := Color(1, 0.9, 0.85, 0.4 + 0.6 * progress).lerp(tint, smoothstep(0.7, 1.0, progress))
	var w := 3.0 + progress * 3.0
	var corners := [[r.position, Vector2(1, 0), Vector2(0, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)], [r.end, Vector2(-1, 0), Vector2(0, -1)]]
	for corner in corners:
		var p: Vector2 = corner[0]
		draw_line(p, p + corner[1] * arm, Color(0, 0, 0, 0.7), w + 3.0)
		draw_line(p, p + corner[2] * arm, Color(0, 0, 0, 0.7), w + 3.0)
		draw_line(p, p + corner[1] * arm, col, w)
		draw_line(p, p + corner[2] * arm, col, w)
	if dir != Vector2.ZERO:
		var c := r.get_center()
		var tip := c + dir * 34.0
		var head := PackedVector2Array([tip - dir * 14.0 + dir.orthogonal() * 10.0, tip, tip - dir * 14.0 - dir.orthogonal() * 10.0])
		draw_line(c - dir * 34.0, tip, Color(0, 0, 0, 0.7), 7.0)
		draw_polyline(head, Color(0, 0, 0, 0.7), 7.0)
		draw_line(c - dir * 34.0, tip, col, 3.0)
		draw_polyline(head, col, 3.0)
