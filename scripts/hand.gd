class_name Hand
extends Node2D
## The mouse cursor is the player's hand, and the hand is the player's body:
## unblocked hits hurt it, and a hurt hand grips weaker and shakes.
## Everything about the player is shown on the hand itself: dents, cracks and bandages
## for health; wraps, bands and charms for upgrades; the rings and their gems.
## It's a character, too: an open gauntlet that points at what it can pick up, grips what
## it holds, balls into a fist to punch, leans into the way it's moving, recoils when
## hurt, and gives a thumbs-up after a parry.
## LMB grabs, Space swings / uses / punches, Q and E rotate. Rings: one per finger (two
## slots to start, up to five); RMB fires every ready ring, 1-5 fires one finger's ring.

signal activated(item: Item)
signal buy_attempt(item: Item, at: Vector2)
signal punched(at: Vector2)
signal ring_used(ring: String, at: Vector2, finger: int)
signal released(item: Item)
signal hurt_taken(amount: float)  # what actually reached the hand, after rings

const STIFFNESS := 280.0
const DAMPING := 32.0
const MAX_FORCE := 210000.0
const ROTATE_SPEED := 5.0
const DROP_THRESHOLD := 16.0
const PUNCH_COOLDOWN := 1.0
const MAX_RING_SLOTS := 5  # one per finger
const GRAB_REACH := 18.0  # a near miss still grabs: thin blades and hafts are hard to hit exactly
const PX := 3.0  # the hand is drawn in chunky 3px pixels: it is the health readout, so it is big

var held: Item = null
var grab_local := Vector2.ZERO
var injury := 0.0
var base_max_hp := 100.0  # from upgrades
var hoard_hp := 0.0       # from the Weapon Rack: what's in the pile
var max_hp: float:
	get:
		return base_max_hp + hoard_hp
var strength := 1.0
var steadiness := 1.0
var swing_power := 1.0
var haste := 1.0        # multiplies weapon recovery time (Quicksilver Drop)
var resilience := 1.0   # multiplies damage that gets through (Troll Marrow)
var rings: Array[String] = []  # by finger: index finger first, thumb last
var ring_cds: Array[float] = []
var ring_slots := 2
var upgrades := {}  # upgrade id -> how many times bought
var punch_time := 0.0
var punch_cooldown := 0.0
var hazard_time := 0.0
var dead := false
var momentum_time := 0.0  # Ring of Momentum: a primed big hit after a good block
var momentum_mult := 2.5  # how big (more after a parry)
var grudges := 0  # Ring of Grudges: banked good blocks, spent on the next hit
var wrath_time := 0.0  # Ring of Wrath: every hit hits much harder while this runs
var frenzy := 0  # Ring of Frenzy: hits in the current streak
var frenzy_time := 0.0  # how long the streak has to land its next hit
var gamble_mult := 1.0  # Gambler's Ring: what the next hit is multiplied by
var well_time := 0.0  # Ring of the Well: the pile is dragged to the hand while this runs
var on_hurt: Callable  # set by the game: rings that change a blow to the hand (amount -> amount)
var knock: Callable  # set by the game: Space while holding something; returns true if it went through the door
var pinned := Vector2.INF  # dev/capture hook: hold the hand here instead of at the mouse
var force_inspect := false  # dev/capture hook: inspect without Alt
var force_gesture := ""  # dev/capture hook: show one gesture
var gesture := "open"  # open, point, grip, fist, thumbs, limp
var _celebrate := 0.0
var _recoil := Vector2.ZERO
var _lean := 0.0
var _flinch := 0.0
var _t := 0.0
var _last_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _drips: Array = []  # global-space blood drops {pos, vel, life}
var _drip_timer := 0.0
var _hover: Item = null


## A fresh hand for a fresh run: upgrades, rings and wounds all go.
func reset_run() -> void:
	injury = 0.0
	base_max_hp = 100.0
	hoard_hp = 0.0
	strength = 1.0
	steadiness = 1.0
	swing_power = 1.0
	haste = 1.0
	resilience = 1.0
	rings.clear()
	ring_cds.clear()
	ring_slots = 2
	upgrades.clear()
	momentum_time = 0.0
	grudges = 0
	wrath_time = 0.0
	frenzy = 0
	gamble_mult = 1.0
	well_time = 0.0
	dead = false
	release()


## Alt held: the hand becomes a magnifying glass and items show their info.
func inspecting() -> bool:
	return not dead and (force_inspect or Input.is_key_pressed(KEY_ALT))


func grip() -> float:
	if has_ring("ring_desperation") and hurt_fraction() > 0.7:
		return 2.0 * strength  # nothing left to lose: everything you've got
	return lerpf(1.0, 0.75, clampf(injury / max_hp, 0.0, 1.0)) * strength


func hurt_fraction() -> float:
	return clampf(injury / max_hp, 0.0, 1.0)


func target() -> Vector2:
	var tremor := Vector2(sin(_t * 23.0), cos(_t * 17.0)) * hurt_fraction() * 3.0 * steadiness
	tremor += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _flinch * 30.0
	var base := pinned if pinned.is_finite() else get_global_mouse_position()
	return base + tremor + _recoil


func _unhandled_input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	if dead:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_try_grab()
			else:
				release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			for i in rings.size():
				_use_ring(i)
	elif e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_SPACE:
			_activate()
		elif k.pressed and not k.echo and k.keycode >= KEY_1 and k.keycode <= KEY_5:
			_use_ring(k.keycode - KEY_1)


func item_under(p: Vector2) -> Item:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1
	for h in get_world_2d().direct_space_state.intersect_point(q, 8):
		if h.collider is Item:
			return h.collider
	return null


## The item exactly under p, or failing that the nearest one within GRAB_REACH.
func item_near(p: Vector2) -> Item:
	var exact := item_under(p)
	if exact:
		return exact
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GRAB_REACH
	q.shape = circle
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1
	var best: Item = null
	var best_d := INF
	for h in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var it := h.collider as Item
		if it == null:
			continue
		var c := it.nearest_cell(p)
		if not it.cells.has(c):
			continue
		var d := it.to_global(it.cell_pos(c)).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = it
	return best


func _try_grab() -> void:
	var p := get_global_mouse_position()
	var it := item_near(p)
	if it == null:
		return
	if not it.owned:
		buy_attempt.emit(it, p)  # shop stock: picking it up buys it, if you have the coins
		return
	grab(it, p)


func grab(it: Item, p: Vector2) -> void:
	held = it
	if it.has_meta("fixture"):
		it.set_meta("taken", true)  # it's yours now: it comes with you
		it.freeze = false
	if it.has_meta("slotted"):
		it.set_meta("slotted", false)  # off its rack
		it.freeze = false
	var c := it.cell_at_global(p)
	if not it.cells.has(c):
		c = it.nearest_cell(p)  # a near miss: take hold of the closest bit
	grab_local = it.cell_pos(c) if it.cells.has(c) else it.to_local(p)
	it.held = true


func release() -> void:
	if held and is_instance_valid(held):
		held.held = false
		var was := held
		held = null
		released.emit(was)
		return
	held = null


## A blow that gets through. Troll Marrow softens it; a big one knocks the thing out of
## your hand and the hand itself back.
func hurt(amount: float) -> void:
	if amount <= 0.0:
		return
	amount *= resilience
	if on_hurt.is_valid():
		amount = on_hurt.call(amount)
		if amount <= 0.0:
			return
	injury = minf(max_hp, injury + amount)
	hurt_taken.emit(amount)
	_flinch = clampf(amount / 25.0, 0.1, 0.5)
	_recoil = Vector2(randf_range(-1.0, 1.0), 1.0).normalized() * clampf(amount * 1.2, 4.0, 30.0)
	if amount > DROP_THRESHOLD * strength:
		release()


func heal(amount: float) -> void:
	injury = maxf(0.0, injury - amount)


## A parry: the hand gives a thumbs-up.
func celebrate() -> void:
	_celebrate = 0.7


## What Space does with the thing in hand depends on the part you hold it by: a glued
## sword-and-buckler swings when held by the sword, braces when held by the buckler.
func grip_kind() -> String:
	if held == null or not is_instance_valid(held):
		return ""
	return str(held.part_at_local(grab_local).get("kind", held.def.kind))


func _activate() -> void:
	if held == null:
		if punch_cooldown > 0.0:
			return
		punch_cooldown = PUNCH_COOLDOWN
		punch_time = 0.15
		punched.emit(position)
	elif knock.is_valid() and knock.call(position):
		return
	elif grip_kind() == "weapon" and has_ring("ring_pacifist"):
		return  # the Pacifist's oath: no swinging
	elif grip_kind() == "weapon":
		var dir := signf(_mouse_vel.x) if absf(_mouse_vel.x) > 30.0 else 1.0
		if held.start_swing(dir, grip() * swing_power, haste, held.part_at_local(grab_local)):
			Sfx.play("swing", -4.0, 1.3 / sqrt(maxf(held.mass, 1.0) / 30.0))
	else:
		activated.emit(held)


func _use_ring(finger: int) -> void:
	if finger >= rings.size() or ring_cds[finger] > 0.0:
		return
	var cd: float = ItemDefs.UPGRADES[rings[finger]].cooldown
	if cd <= 0.0:
		return  # passive ring
	ring_cds[finger] = cd
	ring_used.emit(rings[finger], position, finger)


func has_ring(id: String) -> bool:
	return rings.has(id)


## Take a ring off for good (the Phoenix Ring burns away).
func remove_ring(id: String) -> void:
	var i := rings.find(id)
	if i >= 0:
		rings.remove_at(i)
		ring_cds.remove_at(i)


## Put a ring on the next free finger. With every slot full, the oldest ring comes off;
## its id is returned so it can drop into the pile.
func wear_ring(id: String) -> String:
	var off := ""
	if rings.size() >= ring_slots:
		off = rings.pop_front()
		ring_cds.pop_front()
	rings.append(id)
	ring_cds.append(0.0)
	return off


func die() -> void:
	dead = true
	release()


func _process(delta: float) -> void:
	if get_tree().paused:
		position = target()  # frozen for inspecting: the glass still moves
		queue_redraw()
		return
	if dead:
		position += Vector2(0, 60.0 * delta)  # the hand sags and falls away
	else:
		position = target()
	punch_time = maxf(0.0, punch_time - delta)
	punch_cooldown = maxf(0.0, punch_cooldown - delta)
	for i in ring_cds.size():
		ring_cds[i] = maxf(0.0, ring_cds[i] - delta)
	hazard_time = maxf(0.0, hazard_time - delta)
	momentum_time = maxf(0.0, momentum_time - delta)
	wrath_time = maxf(0.0, wrath_time - delta)
	well_time = maxf(0.0, well_time - delta)
	frenzy_time = maxf(0.0, frenzy_time - delta)
	if frenzy_time <= 0.0:
		frenzy = 0
	_flinch = maxf(0.0, _flinch - delta)
	_celebrate = maxf(0.0, _celebrate - delta)
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-delta * 10.0))
	# leans into the way it's moving, and rights itself when it stops
	_lean = lerpf(_lean, clampf(_mouse_vel.x / 2500.0, -0.3, 0.3), 1.0 - exp(-delta * 8.0))
	if force_gesture != "":
		gesture = force_gesture
	elif dead:
		gesture = "limp"
	elif punch_time > 0.0:
		gesture = "fist"
	elif held:
		gesture = "grip"
	elif _celebrate > 0.0:
		gesture = "thumbs"
	else:
		_hover = item_near(position) if not inspecting() else null
		gesture = "point" if _hover and _hover.def.kind != "debris" else "open"
	_update_drips(delta)
	queue_redraw()


func _update_drips(delta: float) -> void:
	var f := hurt_fraction()
	if f > 0.5 and not dead:
		_drip_timer -= delta * (f - 0.5) * 8.0
		if _drip_timer <= 0.0:
			_drip_timer = 1.0
			_drips.append({"pos": global_position + Vector2(randf_range(-10, 10), 14), "vel": Vector2.ZERO, "life": 1.5})
	for d in _drips:
		d.vel += Vector2(0, 700.0 * delta)
		d.pos += d.vel * delta
		d.life -= delta
	_drips = _drips.filter(func(d: Dictionary) -> bool: return d.life > 0.0 and d.pos.y < 720.0)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	var m := get_global_mouse_position()
	_mouse_vel = _mouse_vel.lerp((m - _last_mouse) / delta, 0.3)
	_last_mouse = m
	if held and (not is_instance_valid(held) or held.is_queued_for_deletion()):
		held = null
	if dead:
		return
	_touch_hazards(delta)
	if held == null:
		return
	var p := held.to_global(grab_local)
	if not held.has_cell_at(p):
		# the bit we were holding broke off: keep hold of whatever is there now
		var other := item_under(p)
		release()
		if other and other.owned:
			grab(other, p)
		return
	var r := p - held.global_position
	var f := held.mass * (STIFFNESS * (target() - p) - DAMPING * held.point_velocity(p))
	held.apply_force(f.limit_length(MAX_FORCE * grip()), r)
	var spin := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	if spin != 0.0 and held.swing_time <= 0.0:
		held.angular_velocity = move_toward(held.angular_velocity, spin * ROTATE_SPEED * grip(), 30.0 * delta)


## Holding something charged, hot or frozen hurts, unless a ring protects it or you've got
## it by a weapon's wrapped handle. Hovering over it (or inspecting it) is safe. Shocks also make the hand spasm and drop things.
func _touch_hazards(delta: float) -> void:
	var touching: Item = held
	if touching == null:
		return
	if touching.is_handle_at_local(grab_local):
		return  # held by the wrapped handle: safe whatever the blade is doing
	var shock := 0.0 if has_ring("ring_grounding") else touching.charge
	var burn := 0.0 if has_ring("ring_fireward") else touching.heat
	var frost := 0.0 if has_ring("ring_fireward") else touching.cold
	if shock < 0.05 and burn < 0.2 and frost < 0.3:
		return
	hazard_time = 0.2
	injury = minf(max_hp, injury + (shock * 10.0 + burn * 7.0 + frost * 4.0) * delta)
	if shock > 0.5 and held and randf() < delta * 1.5:
		release()


# --- drawing -------------------------------------------------------------------
# The hand is a little avatar with a handful of gestures. Four designs (F6) share the
# gesture shapes and each shows health its own way. Upgrades and rings go on top of all.

func _px(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), col)


## The hand's pieces in hand-pixels, for the current gesture: [x, y, w, h, kind].
## Kinds: palm, finger, thumb, knuckle, cuff. Fingers are listed index first.
func _shape(g: String) -> Array:
	var f := hurt_fraction()
	var out: Array = []
	var fx := [-7.0, -3.4, 0.2, 3.8]
	var lens := [8.0, 9.5, 8.5, 6.5]
	match g:
		"fist":
			out = [[-8, -7, 16, 14, "palm"], [-7, -7, 3, 3, "knuckle"], [-3, -7, 3, 3, "knuckle"],
				[1, -7, 3, 3, "knuckle"], [5, -7, 3, 3, "knuckle"], [-10, -2, 3, 6, "thumb"], [-8, 7, 16, 4, "cuff"]]
		"thumbs":
			out = [[-8, -5, 16, 14, "palm"], [-7, -5, 3, 3, "knuckle"], [-3, -5, 3, 3, "knuckle"],
				[1, -5, 3, 3, "knuckle"], [5, -5, 3, 3, "knuckle"], [-10, -4, 3, 5, "thumb"], [-10, -11, 3, 7, "thumb"], [-8, 9, 16, 4, "cuff"]]
		"grip":
			out = [[-7, -1, 14, 13, "palm"], [-7, 12, 14, 4, "cuff"], [0, 2, 7, 3, "thumb"]]
			for i in 4:
				out.append([fx[i], -4, 3, 3, "finger"])
				out.append([fx[i], -1, 3, 1, "knuckle"])
		"point":
			out = [[-7, -1, 14, 13, "palm"], [-7, 12, 14, 4, "cuff"], [7, 1, 3, 4, "thumb"], [9, -2, 3, 4, "thumb"]]
			out.append([fx[0], -1 - 11, 3, 11, "finger"])
			for i in range(1, 4):
				out.append([fx[i], -4, 3, 3, "finger"])
				out.append([fx[i], -1, 3, 1, "knuckle"])
		"limp":
			out = [[-7, -1, 14, 13, "palm"], [-7, 12, 14, 4, "cuff"], [7, 3, 4, 5, "thumb"]]
			for i in 4:
				out.append([fx[i], -1 - 4, 3, 4, "finger"])
		_:  # open
			out = [[-7, -1, 14, 13, "palm"], [-7, 12, 14, 4, "cuff"], [7, 2, 3, 4, "thumb"], [9, -1, 3, 4, "thumb"]]
			for i in 4:
				var h: float = lens[i] + sin(_t * 2.0 + i) * 0.4  # fingers idle
				if i == 3 and f > 0.75:
					# a broken little finger, bent out at the knuckle
					out.append([fx[i], -3, 3, 3, "finger"])
					out.append([fx[i] + 2, -6, 3, 3, "finger"])
				else:
					out.append([fx[i], -1 - h, 3, h, "finger"])
	return out


func _draw() -> void:
	for d in _drips:
		draw_rect(Rect2(to_local(d.pos) - Vector2(1.5, 2), Vector2(3, 4)), Color(0.55, 0.05, 0.05, minf(1.0, d.life)))
	var s := 1.3 if punch_time > 0.0 else 1.0
	var rot := 0.9 if dead else _lean
	draw_set_transform(Vector2.ZERO, rot, Vector2(s, s))
	if inspecting():
		_draw_magnifier()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var parts := _shape(gesture)
	match Looks.pick("hand"):
		"Pixel Hand":
			_draw_pixel_hand(parts)
		"Bone":
			_draw_bone(parts)
		"Shadow Puppet":
			_draw_puppet(parts)
		_:
			_draw_gauntlet(parts)
	_draw_upgrades()
	if gesture == "thumbs":
		# a couple of little stars for a job well done
		for k in 3:
			var a := _t * 4.0 + k * 2.1
			var p := Vector2(-11 + cos(a) * 5.0, -12 + sin(a) * 3.0 - k * 2.0) * PX
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 0.95, 0.6, 0.6 + 0.4 * sin(a * 3.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _skin() -> Color:
	var skin := Color(0.86, 0.68, 0.54).lerp(Color(0.72, 0.66, 0.64), hurt_fraction())  # paler as it weakens
	if _flinch > 0.0:
		skin = skin.lerp(Color(0.9, 0.2, 0.15), _flinch * 1.5)
	if hazard_time > 0.0 and randf() < 0.5:
		skin = Color(1, 1, 0.7)
	if dead:
		skin = Color(0.55, 0.55, 0.55)
	return skin


## The outline grows thicker with calloused skin (the Salve upgrade).
func _outline(parts: Array, col: Color, extra: float = 0.0) -> void:
	var tough: float = upgrades.get("toughness", 0) + extra
	for r in parts:
		draw_rect(Rect2(Vector2(r[0], r[1]) * PX - Vector2.ONE * (1.0 + tough), Vector2(r[2], r[3]) * PX + Vector2.ONE * (2.0 + tough * 2.0)), col)


## Gauntlet: the default. A chunky plate glove: bevelled steel plates, articulated
## fingers, riveted knuckles, a leather cuff. Hits dent it, then crack it, then plates
## come away and the bandaged hand shows through, with blood running from the seams.
func _draw_gauntlet(parts: Array) -> void:
	var f := hurt_fraction()
	var steel := Color(0.6, 0.63, 0.7)
	if dead:
		steel = Color(0.35, 0.35, 0.37)
	if _flinch > 0.0:
		steel = steel.lerp(Color(1, 0.75, 0.6), _flinch * 1.5)
	if hazard_time > 0.0 and randf() < 0.5:
		steel = Color(1, 1, 0.75)
	var leather := Color(0.4, 0.25, 0.14)
	var dark := Color(0.09, 0.09, 0.12)
	_outline(parts, dark)
	for r in parts:
		var x: float = r[0]
		var y: float = r[1]
		var w: float = r[2]
		var h: float = r[3]
		match r[4]:
			"cuff":
				_px(x, y, w, h, leather)
				_px(x, y, w, 1, leather.lightened(0.25))
				_px(x, y + h - 1, w, 1, leather.darkened(0.4))
				_px(x + 1, y + 1.5, w - 2, 1, Color(0.75, 0.6, 0.3))  # a brass band
			"knuckle":
				var col := steel.darkened(0.1).lerp(Color(1.0, 0.5, 0.2), punch_cooldown / PUNCH_COOLDOWN * 0.7)  # glows hot after a punch
				_px(x, y, w, h, col)
				_px(x + 1, y + 1, 1, 1, dark)  # rivet
			"finger", "thumb":
				var col := steel.darkened(0.12)
				_px(x, y, w, h, col)
				_px(x, y, 1, h, col.lightened(0.3))  # left bevel
				_px(x, y, w, 1, col.lightened(0.35))  # top bevel
				_px(x + w - 1, y, 1, h, col.darkened(0.3))
				var k := 2.5
				while k < h - 1.0:
					_px(x, y + k, w, 0.7, dark)  # articulated plates
					k += 3.0
			_:
				_px(x, y, w, h, steel)
				_px(x, y, w, 1, steel.lightened(0.35))
				_px(x, y, 1, h, steel.lightened(0.2))
				_px(x + w - 1, y, 1, h, steel.darkened(0.35))
				_px(x, y + h - 1, w, 1, steel.darkened(0.3))
				# the plate's crease and two rivets
				_px(x + 1, y + h * 0.55, w - 2, 0.7, steel.darkened(0.4))
				_px(x + 1.5, y + 1.5, 1, 1, dark)
				_px(x + w - 2.5, y + 1.5, 1, 1, dark)
	var py := -7.0 if gesture in ["fist", "thumbs"] else -1.0
	var dents := int(f * 8.0)
	for k in dents:
		_px(-6 + (k * 5) % 12, py + 3 + (k * 3) % 8, 2, 2, steel.darkened(0.5))
	if f > 0.45:
		# a plate has come away: bare, bandaged hand underneath
		_px(-3, py + 5, 7, 5, _skin())
		_px(-3, py + 7, 7, 2, Color(0.92, 0.9, 0.82))
		if f > 0.55:
			_px(0, py + 7, 2, 2, Color(0.7, 0.1, 0.1, 0.8))  # blood seeping through
	if f > 0.6:
		draw_line(Vector2(-6, py + 3) * PX, Vector2(-1, py + 9) * PX, dark, 2.0)
		draw_line(Vector2(5, py + 2) * PX, Vector2(2, py + 7) * PX, dark, 2.0)
	if f > 0.75:
		_px(-7, py + 11, 1, 3, Color(0.6, 0.05, 0.05))  # blood from the seams
		_px(6, py + 10, 1, 4, Color(0.6, 0.05, 0.05))


## Pixel Hand: skin that bruises, gets bandaged, bleeds through and pales.
func _draw_pixel_hand(parts: Array) -> void:
	var f := hurt_fraction()
	var skin := _skin()
	var shade := skin.darkened(0.25)
	_outline(parts, Color(0.25, 0.15, 0.1).darkened(0.2 * upgrades.get("toughness", 0)))
	for r in parts:
		var col := skin
		if r[4] == "knuckle":
			col = shade.lerp(Color(0.8, 0.25, 0.2), punch_cooldown / PUNCH_COOLDOWN * 0.8)  # sore knuckles
		elif r[4] == "cuff":
			col = Color(0.3, 0.25, 0.35)  # a sleeve
		_px(r[0], r[1], r[2], r[3], col)
	if f > 0.15:
		_px(-4, 4, 3, 2, Color(0.45, 0.25, 0.45, 0.8))
	if f > 0.25:
		_px(2, 7, 3, 3, Color(0.4, 0.22, 0.4, 0.85))
	if f > 0.35:
		_px(-8, 5, 16, 3, Color(0.92, 0.9, 0.82))
		if f > 0.5:
			_px(-1, 5, 3, 3, Color(0.7, 0.1, 0.1, 0.8))  # blood seeping through
	if f > 0.6:
		_px(-8, 9, 16, 2, Color(0.88, 0.86, 0.78))


## Bone: flesh over bone. As the hand is hurt the flesh wears away and the bones show,
## until it's little more than a skeleton holding on.
func _draw_bone(parts: Array) -> void:
	var f := hurt_fraction()
	var bone := Color(0.92, 0.88, 0.78) if not dead else Color(0.6, 0.6, 0.58)
	var raw := Color(0.55, 0.1, 0.1)
	# bones first
	for r in parts:
		if r[4] == "palm":
			for k in 4:
				_px(r[0] + 1 + k * 3.6, r[1] + 1, 1.5, r[3] - 3, bone)  # metacarpals
		elif r[4] == "finger" or r[4] == "thumb":
			var segs := 3
			var sh: float = r[3] / segs
			for k in segs:
				_px(r[0] + 0.75, r[1] + k * sh + 0.3, 1.5, sh - 0.6, bone)
				_px(r[0] + 0.5, r[1] + k * sh, 2, 0.6, bone.darkened(0.15))  # knuckle joints
		elif r[4] == "cuff":
			_px(r[0], r[1], r[2], r[3], Color(0.25, 0.2, 0.3))
		else:
			_px(r[0] + 0.5, r[1] + 0.5, r[2] - 1, r[3] - 1, bone)
	# flesh over the top, wearing away with damage (raw red at the edges)
	var flesh := _skin()
	flesh.a = clampf(1.0 - f * 1.1, 0.0, 1.0)
	var edge := raw
	edge.a = clampf(f * 1.5, 0.0, 0.8) * flesh.a + (0.0 if f < 0.1 else 0.2)
	for r in parts:
		if r[4] == "cuff":
			continue
		draw_rect(Rect2(Vector2(r[0], r[1]) * PX - Vector2.ONE, Vector2(r[2], r[3]) * PX + Vector2.ONE * 2.0), edge)
		_px(r[0], r[1], r[2], r[3], flesh)


## Shadow Puppet: a black silhouette with a warm rim of light. Damage opens glowing ember
## cracks across it, more and brighter the closer it is to breaking.
func _draw_puppet(parts: Array) -> void:
	var f := hurt_fraction()
	var rim := Color(1.0, 0.85, 0.6)
	if _flinch > 0.0:
		rim = Color(1, 0.3, 0.2)
	if dead:
		rim = Color(0.3, 0.3, 0.3)
	_outline(parts, rim)
	for r in parts:
		_px(r[0], r[1], r[2], r[3], Color(0.02, 0.02, 0.03))
	var cracks := int(f * 9.0)
	var t := Time.get_ticks_msec() * 0.001
	var ember := Color(1.0, 0.5, 0.15, 0.6 + 0.4 * sin(t * 7.0))
	if dead:
		ember = Color(0.3, 0.3, 0.3)
	var py := -7.0 if gesture in ["fist", "thumbs"] else -1.0
	for k in cracks:
		var a := Vector2(-6 + (k * 7) % 12, py + 1 + (k * 5) % 11)
		var b := a + Vector2(((k * 13) % 7) - 3, ((k * 11) % 5) - 1)
		var c := b + Vector2(((k * 17) % 5) - 2, 2)
		draw_polyline(PackedVector2Array([a * PX, b * PX, c * PX]), ember, 1.5)


## Inspect mode: a brass-rimmed magnifying glass, the lens centred on the cursor.
func _draw_magnifier() -> void:
	var r := 7.0 * PX
	var handle_dir := Vector2(1, 1).normalized()
	var a := handle_dir * (r + 2.0)
	var b := handle_dir * (r + 11.0 * PX)
	draw_line(a, b, Color(0.05, 0.03, 0.02), 4.0 * PX)
	draw_line(a, b, Color(0.42, 0.26, 0.14), 2.5 * PX)  # wooden handle
	draw_circle(Vector2.ZERO, r, Color(0.75, 0.88, 1.0, 0.15))  # glass
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.05, 0.03, 0.02), 2.6 * PX)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.85, 0.65, 0.3), 1.4 * PX)  # brass rim
	draw_arc(Vector2.ZERO, r * 0.6, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.6), 1.0 * PX)  # glint


func _draw_upgrades() -> void:
	var fist := gesture in ["fist", "thumbs"]
	if upgrades.get("strength", 0) > 0:
		_px(-8, -2 if not fist else -8, 16, 2, Color(0.45, 0.45, 0.5))  # iron knuckle wrap
	if upgrades.get("quick", 0) > 0:
		_px(-7, 12 if not fist else 7, 14, 1.5, Color(0.6, 0.4, 0.2))  # leather wristband
	if upgrades.get("steady", 0) > 0:
		_px(0, 16, 1, 3, Color(0.3, 0.3, 0.3))
		_px(-1, 19, 3, 3, Color(0.45, 0.45, 0.42))  # charm hanging off the wrist
	if upgrades.get("tonic", 0) > 0:
		_px(-9, -1 if not fist else -7, 2, 13, Color(0.35, 0.37, 0.42))  # an iron bar down the side
	if upgrades.get("thick_skin", 0) > 0:
		_px(-7, 10 if not fist else 4, 14, 1, Color(0.4, 0.6, 0.3))  # a green stain at the cuff
	# one ring per finger (index first, thumb last); each gem lights up as it recharges
	for i in rings.size():
		var u: Dictionary = ItemDefs.UPGRADES[rings[i]]
		var cd: float = u.cooldown
		var ready := 1.0 if cd <= 0.0 else 1.0 - ring_cds[i] / cd
		var at := _finger_spot(i)
		_px(at.x, at.y, 3, 1, Color(0.95, 0.75, 0.22))
		var gem: Color = u.gem
		_px(at.x + 1, at.y - 1, 1, 1, gem.darkened(0.8 * (1.0 - ready)))


func _finger_spot(i: int) -> Vector2:
	var fist := gesture in ["fist", "thumbs"]
	var curled := gesture in ["grip", "point"] and not (gesture == "point" and i == 0)
	if i == 4:
		return Vector2(-10, 1) if fist else Vector2(7.5, 4)  # thumb
	if fist:
		return Vector2(-7 + i * 4, -5)
	if curled:
		return Vector2(-7 + i * 3.6, -2)
	return Vector2(-7 + i * 3.6, -4)
