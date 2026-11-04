class_name Props
extends Node2D
## The things in each stage you can use mid-fight, modelled into the set itself (see
## _build3d: each sits on the back wall, or the floor, where its screen spot falls). Their
## interaction is all in screen space: where they are, how near the hand is. All of them sit
## in the top half of the screen, clear of the pile (the home's dummy stands on the floor).
##   element sources  hold a piece in one and it takes on the element: a wall torch (fire),
##                    a frozen drain or quench barrel (frost), a fungus bloom (venom), a rust
##                    grate (rot), a storm glass (storm). The way into element reactions.
##   chandelier       punch its chain and it comes down on the foe
##   blood altar      hold a weapon on it: it takes a share of your hand's health and
##                    gives the weapon a rare modifier (once)
## and the secrets, which only show when the hand is close:
##   loose brick      punch it three times for what's hidden behind it
##   falling star     now and then one streaks across the Star Chamber's sky; punch it
## Hold Alt over one to read what it does (the secrets, once found).

const CELL := 7.5  # the items' own pixel size
const NEAR := 110.0  # how close the hand has to be for a prop to show it's live
const SECRET_NEAR := 70.0  # and for a secret to show at all
const INFO := {
	"torch": ["Wall Torch", "Hold a piece in the flame and it heats up: fire for element reactions, and a red-hot blade scorches what it hits."],
	"frost_drain": ["Frozen Drain", "Rimed over. Hold a piece against it and it chills: frost for element reactions."],
	"quench": ["Quench Barrel", "Ice-cold water. Dip a piece and it chills (red-hot metal is tempered): frost for element reactions."],
	"fungus": ["Fungus Bloom", "Hold a piece in it and it comes away poisoned: venom for element reactions."],
	"rust_grate": ["Rust Grate", "Weeping rust. Hold a piece in it and it turns corrosive: rot for element reactions. Careful what it touches after."],
	"storm_glass": ["Storm Glass", "A jar of trapped lightning. Hold a piece to it and it stays charged for a while: storm for element reactions."],
	"chandelier": ["Chandelier", "Punch the chain and it drops on whoever's below: a heavy blow that staggers, and the candles catch."],
	"altar": ["Blood Altar", "Hold a weapon on it: it takes a third of your hand's health and gives the weapon a rare modifier. Once."],
	"brick": ["Loose Brick", "There was something behind it."],
	"star": ["Falling Star", "Punch one as it passes."],
	"still_star": ["A Star That Waits", "It hangs still, too high to punch. Something that weighs nothing might reach it."],
	"dummy": ["Training Dummy", "Swing at it to see what a hit does: rings, infusions and all. It remembers your best."],
	"trophies": ["Trophy Board", ""],  # filled in from the save: see describe()
	"cat": ["The Cat", "Asleep on the sill. Rest your empty hand on it a while."],
	"hearth": ["Hearth", ""],  # filled in from the save: see describe()
	"ink_blot": ["Ink Blot", "The reactions left a stain on the air. It looks thin enough to punch through."],
}

var props: Array = []  # {kind, pos, r, used, hits, t}
var game: Node
var _rng := RandomNumberGenerator.new()
var _star_timer := 8.0
var _star: Dictionary = {}  # {pos, vel}
var _star_trail: Array = []


func _ready() -> void:
	z_index = 5


## The props for a setting. Clears whatever was there.
func setup(setting: String, rng_seed: int) -> void:
	_free3d()
	props.clear()
	_star = {}
	_rng.seed = rng_seed
	match setting:
		"Dungeon Cell":
			_add("torch", Vector2(210, 165), 30.0)
			if _rng.randf() < 0.6:
				_add("brick", Vector2(1040, 130), 18.0)
		"Corridor":
			_add("torch", Vector2(1070, 160), 30.0)
			_add("chandelier", Vector2(640, 48), 26.0)
			if _rng.randf() < 0.6:
				_add("brick", Vector2(250, 300), 18.0)
		"Cistern":
			_add("frost_drain", Vector2(230, 150), 32.0)
			_add("rust_grate", Vector2(1060, 160), 30.0)
		"Catacombs":
			_add("fungus", Vector2(980, 290), 32.0)
		"Crypt Chapel":
			_add("chandelier", Vector2(640, 48), 26.0)
			_add("altar", Vector2(210, 300), 34.0)
		"Forge":
			_add("quench", Vector2(190, 250), 34.0)
		"Ossuary":
			_add("fungus", Vector2(950, 300), 32.0)
			if _rng.randf() < 0.5:
				_add("brick", Vector2(330, 120), 18.0)
		"Star Chamber":
			_add("storm_glass", Vector2(240, 160), 30.0)
			_star_timer = _rng.randf_range(6.0, 12.0)
		"Hidden Vault":
			_add("chandelier", Vector2(640, 48), 26.0)
		"Homestead":
			_add("dummy", Vector2(420, 470), 80.0)  # stands on the floor
			_add("trophies", Vector2(790, 200), 34.0)  # on the wall between the beam and the mantel
			_add("cat", Vector2(300, 408), 26.0)  # on the window sill
			_add("hearth", Vector2(1060, 640), 95.0)  # the fireplace: melts junk down
		"Gilded Gullet":
			_add("chandelier", Vector2(640, 48), 26.0)
		"Giant's Table":
			_add("torch", Vector2(1080, 140), 30.0)  # the giant candle's drip
		"Clockwork Orrery":
			_add("storm_glass", Vector2(240, 160), 30.0)
		"Ink Margin":
			_add("fungus", Vector2(960, 290), 32.0)
	queue_redraw()


func clear() -> void:
	_free3d()
	props.clear()
	_star = {}
	queue_redraw()


func _add(kind: String, pos: Vector2, r: float) -> void:
	var pr := {"kind": kind, "pos": pos, "r": r, "used": false, "hits": 0, "t": 0.0}
	props.append(pr)
	_build3d(pr)


## [title, text] for a prop's inspect card. The trophy board reads the save.
func describe(key: String) -> Array:
	var kind := key.trim_prefix("prop:")
	if kind == "hearth" and game:
		return ["Hearth", "Throw junk in the fire (scraps, pauldrons, skulls, rocks) and it melts down. Melt enough and a Coin Purse pops out to take on a run.\nMelted so far: %d of %d" %
			[floori(float(game.save.stats.get("smelt", 0.0))), int(game.SMELT_PURSE)]]
	if kind == "trophies" and game:
		var st: Dictionary = game.save.stats
		return ["Trophy Board", "Runs %d   ·   Deaths %d   ·   Foes felled %d   ·   Bosses %d\nDeepest run: prestige %d   ·   Best hit: %d" %
			[st.runs, st.deaths, st.kills, st.bosses, game.save.prestige_best, st.best_hit]]
	return INFO.get(kind, ["?", ""])


## The prop under the hand, for the inspect card: "prop:<kind>", or "".
func info_at(p: Vector2) -> String:
	for pr in props:
		if pr.kind == "brick" and pr.hits == 0:
			continue  # a secret isn't named until it's been found
		if p.distance_to(pr.pos) <= pr.r + 12.0:
			return "prop:" + str(pr.kind)
	if not _star.is_empty() and p.distance_to(_star.pos) < 30.0:
		return "prop:star"
	return ""


## A punch. True if it hit a prop.
func punch(at: Vector2) -> bool:
	if not _star.is_empty() and at.distance_to(_star.pos) < 34.0:
		game.on_star_caught(_star.pos)
		_star = {}
		return true
	for pr in props:
		if pr.used or at.distance_to(pr.pos) > pr.r + 10.0:
			continue
		match pr.kind:
			"chandelier":
				pr.used = true
				pr.t = 0.0
				game.on_chandelier(pr.pos)
				return true
			"ink_blot":
				pr.used = true
				game.on_ink_blot(pr.pos)
				return true
			"cat":
				pr.t = 0.0
				pr.hits += 1  # startled: it jumps
				Sfx.play("deny", -8.0, 2.2)
				return true
			"dummy":
				pr.t = 0.0
				game.on_dummy_hit(null, pr.pos)
				return true
			"brick":
				pr.hits += 1
				Sfx.play("clack", -4.0, 1.2 + pr.hits * 0.1)
				if pr.hits >= 3:
					pr.used = true
					game.on_brick(pr.pos)
				queue_redraw()
				return true
	return false


func _process(delta: float) -> void:
	if props.is_empty() and _star.is_empty() and _star_timer <= 0.0 and _planet_nodes.is_empty() and not (game and game.has_method("planets") and not game.planets().is_empty()):
		return
	for pr in props:
		pr.t += delta
		if pr.kind == "cat" and game and game.hand.held == null and game.hand.position.distance_to(pr.pos) < pr.r + 10.0:
			pr.used = false
			pr["pet"] = float(pr.get("pet", 0.0)) + delta  # petted: it purrs, now and then a heart
			if fmod(float(pr.pet), 0.8) < delta:
				game.overlay.sparks(pr.pos + Vector2(0, -20), 1200.0, Color(1.0, 0.5, 0.6))
	if game and game.setting() == "Star Chamber" and game.state == game.State.COMBAT:
		if _star.is_empty():
			_star_timer -= delta
			if _star_timer <= 0.0:
				_star_timer = _rng.randf_range(10.0, 18.0)
				var left := _rng.randf() < 0.5
				_star = {"pos": Vector2(-20.0 if left else 1300.0, _rng.randf_range(40.0, 140.0)),
					"vel": Vector2(420.0 if left else -420.0, _rng.randf_range(20.0, 60.0))}
		else:
			_star.pos += _star.vel * delta
			_star_trail.push_front(_star.pos)
			if _star_trail.size() > 14:
				_star_trail.pop_back()
			if _star.pos.x < -40.0 or _star.pos.x > 1320.0:
				_star = {}
	if _star.is_empty() and not _star_trail.is_empty():
		_star_trail.pop_back()
	_animate3d(delta)
	queue_redraw()


## Add a prop mid-fight (the chain pieces appear when their step is done).
func appear(kind: String, pos: Vector2, r: float) -> void:
	for pr in props:
		if pr.kind == kind:
			return
	_add(kind, pos, r)
	queue_redraw()


## Element sources: whatever owned piece is held in one takes on its element. Called from
## the physics step with the time since the last call. Also the chain pieces that want
## something brought to them: an opened brick's hole, the star that waits.
func feed(items: Array, delta: float) -> void:
	for pr in props:
		if pr.kind == "brick" and pr.used:
			for n in items:
				var it := n as Item
				if it and it.owned and float(it.def.get("size", 1.0)) <= 0.45 and _touches(it, pr):
					game.on_through_hole(it, pr.pos)  # small enough to fit
					break
			continue
		if pr.kind == "hearth":
			for n in items:
				var it := n as Item
				if it == null or not it.owned or it.held or it.freeze or it.is_queued_for_deletion():
					continue
				if not (it.def.kind in ["junk", "debris"] or it.def.get("piece", false)):
					continue
				if it.global_position.distance_to(pr.pos) > pr.r:
					it.remove_meta("in_fire")
					continue
				it.set_meta("in_fire", float(it.get_meta("in_fire", 0.0)) + delta)
				it.heat = minf(1.0, it.heat + delta)
				if float(it.get_meta("in_fire")) > 0.8:
					game.on_smelt(it, pr.pos)
			continue
		if pr.kind == "still_star":
			for n in items:
				var it := n as Item
				if it and it.owned and (it.has_mod("weightless") or it.levitate_time > 0.0) and _touches(it, pr):
					pr.kind = "spent_star"
					var sn = pr.get("node")
					if sn != null and is_instance_valid(sn):
						(sn as Node).queue_free()
					game.on_still_star(pr.pos)
					break
			continue
		var kind: String = pr.kind
		if not kind in ["torch", "frost_drain", "quench", "fungus", "rust_grate", "storm_glass", "altar"] or pr.used:
			continue
		for n in items:
			var it := n as Item
			if it == null or not it.owned or it.def.kind == "debris" or it.global_position.distance_to(pr.pos) > pr.r + 90.0:
				continue
			if not _touches(it, pr):
				continue
			match kind:
				"torch":
					it.heat = minf(1.0, it.heat + 0.6 * delta)
				"frost_drain", "quench":
					if kind == "quench" and it.heat > 0.6 and Materials.get_mat(it.def.get("material", "")).get("conducts", false):
						it.add_mod("tempered")
					it.heat = 0.0
					it.cold = minf(1.0, it.cold + 0.8 * delta)
				"fungus":
					it.set_meta("soak_venom", float(it.get_meta("soak_venom", 0.0)) + delta)
					if float(it.get_meta("soak_venom")) > 1.2 and not it.has_mod("poisoned"):
						it.add_mod("poisoned")
						game.prop_feedback(it.global_position, Color(0.55, 0.95, 0.3))
				"rust_grate":
					it.set_meta("soak_rot", float(it.get_meta("soak_rot", 0.0)) + delta)
					if float(it.get_meta("soak_rot")) > 1.5 and not it.has_mod("corrosive"):
						it.add_mod("corrosive")
						game.prop_feedback(it.global_position, Color(0.65, 0.5, 0.25))
				"storm_glass":
					if it.storm_time < 0.5:
						game.prop_feedback(it.global_position, Color(0.6, 0.85, 1.0))
					it.storm_time = maxf(it.storm_time, 8.0)
				"altar":
					if it.def.kind != "weapon" or not it.held:
						continue
					it.set_meta("on_altar", float(it.get_meta("on_altar", 0.0)) + delta)
					if float(it.get_meta("on_altar")) > 1.5:
						pr.used = true
						game.on_altar(it, pr.pos)


func _touches(it: Item, pr: Dictionary) -> bool:
	for c in it.cells:
		if it.to_global(it.cell_pos(c)).distance_to(pr.pos) <= pr.r:
			return true
	return false


# --- drawing ------------------------------------------------------------------------
# The props themselves are in the set (3D). The play field only draws a faint ring round a
# live prop when the hand comes near, and a found brick's outline.

func _draw() -> void:
	var hand_p: Vector2 = game.hand.position if game and game.hand else Vector2.INF
	var t := Time.get_ticks_msec() * 0.001
	for pr in props:
		if pr.used or pr.kind in ["brick", "spent_star"]:
			continue
		if hand_p.distance_to(pr.pos) < NEAR:
			if pr.kind == "hearth":
				draw_arc(pr.pos, pr.r, PI, TAU, 24, Color(1.0, 0.6, 0.2, 0.35 + 0.15 * sin(t * 4.0)), 2.0)
			else:
				draw_arc(pr.pos, pr.r + 6.0 + sin(t * 4.0) * 2.0, 0.0, TAU, 28, Color(1, 1, 1, 0.22), 1.5)


# --- the props in the set -----------------------------------------------------------------
# Each prop is modelled in 3D and placed into the backdrop where its screen spot meets the
# back wall (the dummy, where it meets the floor), sized to the same footprint on screen. So
# they're part of the room: lit and graded like everything else, freed with the backdrop.
# The only 2D left is a faint ring round a live prop when the hand is near.

const WALL_Z := -1.5  # the plane the wall props sit on (just in front of the back wall)

var _star_node: Node3D
var _planet_nodes: Array = []


func _cam() -> Camera3D:
	return game.camera if game and game.get("camera") else null


func _set3d() -> Node3D:
	return game.backdrop if game and game.get("backdrop") != null and is_instance_valid(game.backdrop) else null


## Where a screen point meets the plane z = `z` in the world.
func _wall_point(screen: Vector2, z: float = WALL_Z) -> Vector3:
	var cam := _cam()
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var t := (z - o.z) / d.z if absf(d.z) > 0.0001 else 1.0
	return o + d * t


## Where a screen point meets the first surface of the set behind it (back wall, side wall,
## pillar, mantel...), pulled `lift` metres toward the camera so the prop sits on it.
## Ray against the bounding boxes of the set's meshes; the back plane if nothing's hit.
func _surface_point(screen: Vector2, lift: float = 0.05) -> Vector3:
	var cam := _cam()
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var best := INF
	var world := _set3d()
	if world:
		for mi in world.find_children("*", "MeshInstance3D", true, false):
			if (mi as Node).has_meta("prop"):
				continue
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			var t := _ray_box(o, d, box)
			if t > 0.4 and t < best:
				best = t
	if best == INF:
		return _wall_point(screen)
	return o + d * maxf(0.4, best - lift)


static func _ray_box(o: Vector3, d: Vector3, box: AABB) -> float:
	var t0 := -INF
	var t1 := INF
	for i in 3:
		if absf(d[i]) < 0.000001:
			if o[i] < box.position[i] or o[i] > box.end[i]:
				return INF
			continue
		var a := (box.position[i] - o[i]) / d[i]
		var b := (box.end[i] - o[i]) / d[i]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return t0 if t0 <= t1 and t1 > 0.0 else INF


## Where a screen point meets the floor (y = 0).
func _floor_point(screen: Vector2) -> Vector3:
	var cam := _cam()
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var t := -o.y / d.y if absf(d.y) > 0.0001 else 1.0
	return o + d * t


## World units per screen pixel at a point (so props keep their size on screen).
func _m_per_px(at: Vector3) -> float:
	var cam := _cam()
	var a := cam.unproject_position(at)
	var b := cam.unproject_position(at + Vector3(1, 0, 0))
	return 1.0 / maxf(1.0, absf(b.x - a.x))


func _mat3(col: Color, glow: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


## A piece of a prop, in pixels: offset (x right, y down, z toward you) and size, as on screen.
func _piece(parent: Node3D, mesh: Mesh, px: Vector3, col: Color, k: float, glow: float = 0.0, rot: Vector3 = Vector3.ZERO, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat3(col, glow, alpha)
	mi.position = Vector3(px.x, -px.y, px.z) * k
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("prop", true)  # (not part of the set's surfaces when placing the next one)
	parent.add_child(mi)
	return mi


func _box3(w: float, h: float, d: float, k: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d) * k
	return b


func _cyl3(r_top: float, r_bot: float, h: float, k: float, sides: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top * k
	c.bottom_radius = r_bot * k
	c.height = h * k
	c.radial_segments = sides
	c.rings = 1
	return c


func _ball3(r: float, k: float, seg: int = 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r * k
	s.height = r * 2.0 * k
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return s


func _light3(parent: Node3D, col: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	parent.add_child(l)
	return l


## Build a prop's model into the set.
func _build3d(pr: Dictionary) -> void:
	var world := _set3d()
	if world == null or _cam() == null:
		return
	var root := Node3D.new()
	root.set_meta("prop", true)
	var at: Vector3
	if pr.kind == "dummy":
		at = _surface_point(Vector2(pr.pos.x, 716.0), 0.35)  # stands at the foot of the wall
	elif pr.kind == "ink_blot":
		at = _wall_point(pr.pos, -0.9)  # hangs in the air
	else:
		at = _surface_point(pr.pos, 0.12)
	world.add_child(root)
	root.global_position = at
	var k := _m_per_px(at)
	pr.node = root
	pr.k = k
	var iron := Color(0.33, 0.32, 0.31)
	var wood := Color(0.42, 0.27, 0.15)
	match pr.kind:
		"torch":
			_piece(root, _box3(18, 6, 12, k), Vector3(0, 14, -4), iron, k)
			_piece(root, _cyl3(3, 4, 44, k), Vector3(0, 30, 0), wood, k, 0.0, Vector3(0, 0, 0.12))
			pr.flame = _piece(root, _ball3(10, k), Vector3(0, -2, 2), Color(1.0, 0.55, 0.15), k, 4.0)
			_piece(root, _ball3(5.5, k), Vector3(0, 0, 6), Color(1.0, 0.92, 0.55), k, 6.0)
			pr.light = _light3(root, Color(1.0, 0.6, 0.25), 1.6, 1.6)
		"frost_drain", "rust_grate":
			var c := Color(0.62, 0.74, 0.85) if pr.kind == "frost_drain" else Color(0.5, 0.3, 0.14)
			_piece(root, _box3(56, 40, 8, k), Vector3.ZERO, c, k)
			for b in 4:
				_piece(root, _box3(5, 34, 10, k), Vector3(-18 + b * 12, 0, 2), c.darkened(0.45), k)
			for b in 2:
				_piece(root, _box3(50, 4, 10, k), Vector3(0, -8 + b * 16, 2), c.darkened(0.45), k)
			if pr.kind == "frost_drain":
				for i in 5:  # icicles
					_piece(root, _cyl3(4, 0.2, 18 + (i % 2) * 10, k, 6), Vector3(-20 + i * 10, 28 + (i % 2) * 5, 3), Color(0.82, 0.95, 1.0), k, 0.6)
				_light3(root, Color(0.6, 0.85, 1.0), 0.5, 1.0)
			else:
				pr.drip = _piece(root, _ball3(3.5, k, 6), Vector3(6, 26, 4), Color(0.6, 0.38, 0.14), k)
		"quench":
			_piece(root, _cyl3(26, 24, 46, k, 14), Vector3(0, 6, 0), wood, k)
			for b in 2:
				_piece(root, _cyl3(27, 27, 4, k, 14), Vector3(0, -6 + b * 22, 0), iron, k)
			_piece(root, _cyl3(23, 23, 2, k, 14), Vector3(0, -17, 0), Color(0.3, 0.55, 0.75), k, 0.4)
		"fungus":
			for i in 5:
				var x := -24.0 + i * 12.0
				var h := 14.0 + (i % 3) * 8.0
				_piece(root, _cyl3(3, 4, h, k, 6), Vector3(x, 12 - h * 0.5, 0), Color(0.85, 0.85, 0.72), k)
				var cap := _piece(root, _ball3(9 + (i % 2) * 4, k), Vector3(x, 10 - h, 2), Color(0.45, 0.85, 0.3), k, 0.8)
				cap.scale = Vector3(1, 0.55, 1)
		"storm_glass":
			_piece(root, _cyl3(16, 18, 8, k, 12), Vector3(0, 26, 0), iron, k)
			_piece(root, _cyl3(14, 14, 44, k, 12), Vector3(0, 0, 0), Color(0.75, 0.85, 0.95), k, 0.2, Vector3.ZERO, 0.35)
			_piece(root, _cyl3(12, 15, 6, k, 12), Vector3(0, -25, 0), iron, k)
			pr.flame = _piece(root, _ball3(6, k), Vector3(0, 0, 0), Color(0.65, 0.88, 1.0), k, 6.0)
			pr.light = _light3(root, Color(0.6, 0.85, 1.0), 1.2, 1.4)
		"chandelier":
			_piece(root, _box3(3, pr.pos.y + 20.0, 3, k), Vector3(0, -(pr.pos.y + 20.0) * 0.5, -2), iron.darkened(0.3), k)  # the chain, up to the ceiling
			_piece(root, _cyl3(36, 36, 5, k, 16), Vector3(0, 0, 0), Color(0.5, 0.42, 0.26), k)
			for i in 6:
				var a := i * TAU / 6.0
				var cp := Vector3(cos(a) * 30.0, -8.0, sin(a) * 30.0)
				_piece(root, _cyl3(3, 3, 12, k, 6), cp, Color(0.95, 0.92, 0.8), k)
				_piece(root, _ball3(3.5, k, 6), cp + Vector3(0, -10, 0), Color(1.0, 0.7, 0.3), k, 5.0)
			_light3(root, Color(1.0, 0.7, 0.35), 1.2, 2.0)
		"altar":
			_piece(root, _box3(70, 42, 40, k), Vector3(0, 8, 0), Color(0.42, 0.4, 0.38), k)
			_piece(root, _box3(84, 8, 48, k), Vector3(0, -16, 0), Color(0.5, 0.48, 0.45), k)
			pr.flame = _piece(root, _cyl3(16, 12, 8, k, 12), Vector3(0, -24, 0), Color(0.6, 0.05, 0.05), k, 1.2)
		"brick":
			# a brick that sits a little proud of the wall, a shade off: easy to miss
			pr.flame = _piece(root, _box3(36, 18, 12, k), Vector3(0, 0, 4), Color(0.48, 0.34, 0.26), k)
		"still_star":
			pr.flame = _piece(root, _ball3(9, k), Vector3.ZERO, Color(1.0, 0.96, 0.8), k, 8.0)
			pr.light = _light3(root, Color(1.0, 0.95, 0.75), 1.5, 2.0)
		"ink_blot":
			for b in 7:
				var blob := _piece(root, _ball3(13.0 - b * 0.8, k), Vector3(sin(b * 2.1) * 14.0, cos(b * 1.7) * 10.0, 0), Color(0.02, 0.02, 0.03), k)
				blob.scale = Vector3(1, 1, 0.4)
		"dummy":
			var straw := Color(0.85, 0.72, 0.35)
			_piece(root, _box3(120, 10, 60, k), Vector3(0, -5, 0), Color(0.3, 0.2, 0.11), k)
			var body := Node3D.new()
			root.add_child(body)
			pr.flame = body  # what sways
			_piece(body, _cyl3(7, 7, 210, k, 8), Vector3(0, -105, 0), wood, k)
			_piece(body, _box3(90, 120, 50, k), Vector3(0, -260, 0), straw, k)
			_piece(body, _box3(150, 18, 22, k), Vector3(0, -300, 0), straw.darkened(0.08), k)
			_piece(body, _ball3(30, k, 10), Vector3(0, -350, 0), straw.lightened(0.05), k)
			for i in 3:
				_piece(body, _box3(94, 5, 54, k), Vector3(0, -225 - i * 30, 0), Color(0.55, 0.4, 0.2), k)
		"trophies":
			_piece(root, _box3(84, 44, 8, k), Vector3.ZERO, wood, k)
			_piece(root, _box3(76, 4, 14, k), Vector3(0, 6, 6), wood.darkened(0.2), k)
			if game:
				for i in mini(int(game.save.prestige_best), 5):
					_piece(root, _cyl3(5, 3, 12, k, 8), Vector3(-28 + i * 14, -2, 8), Color(0.95, 0.75, 0.25), k, 0.8)
				for i in mini(int(game.save.stats.bosses), 6):
					_piece(root, _ball3(4.5, k, 6), Vector3(-28 + i * 11, 14, 8), Color(0.9, 0.88, 0.8), k)
		"cat":
			var fur := Color(0.2, 0.2, 0.22)
			var cat := Node3D.new()
			root.add_child(cat)
			pr.flame = cat  # what hops
			var torso := _piece(cat, _ball3(18, k, 10), Vector3(0, 8, 0), fur, k)
			torso.scale = Vector3(1.4, 0.9, 0.9)
			_piece(cat, _ball3(12, k, 10), Vector3(-18, -10, 6), fur, k)
			for sx in [-1, 1]:
				_piece(cat, _box3(6, 9, 4, k), Vector3(-18 + sx * 7, -22, 6), fur, k, 0.0, Vector3(0, 0, -sx * 0.35))
			pr.eyes = []
			for sx in [-1, 1]:
				pr.eyes.append(_piece(cat, _ball3(2.2, k, 6), Vector3(-18 + sx * 5, -11, 17), Color(0.75, 1.0, 0.35), k, 4.0))
			_piece(cat, _cyl3(3, 3, 30, k, 6), Vector3(22, 14, 0), fur, k, 0.0, Vector3(0, 0, 1.2))
		"hearth":
			pass  # the fireplace is already in the room
	_build_star_and_planets()


func _build_star_and_planets() -> void:
	pass


## Keep the 3D props moving: flames, the chandelier's fall, the dummy's sway, the cat, the
## falling star and the Orrery's planets.
func _animate3d(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for pr in props:
		# (the set can be freed under them, taking their models with it: check before typing)
		var nv = pr.get("node")
		if nv == null or not is_instance_valid(nv):
			continue
		var node: Node3D = nv
		var pv = pr.get("flame")
		var part: Node3D = pv if pv != null and is_instance_valid(pv) else null
		match pr.kind:
			"torch", "storm_glass":
				if part:
					part.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 13.0 + pr.pos.x) + 0.08 * sin(t * 7.3))
				var lv = pr.get("light")
				var l: OmniLight3D = lv if lv != null and is_instance_valid(lv) else null
				if l:
					l.light_energy = (1.6 if pr.kind == "torch" else 1.2) * (0.85 + 0.15 * sin(t * 11.0))
			"still_star":
				if part:
					part.scale = Vector3.ONE * (1.0 + 0.25 * sin(t * 3.0))
			"rust_grate":
				var dv = pr.get("drip")
				var drip: Node3D = dv if dv != null and is_instance_valid(dv) else null
				if drip:
					var f := fmod(t * 0.8, 1.0)
					drip.position.y = -(26.0 + f * 30.0) * float(pr.k)
					drip.visible = f < 0.85
			"chandelier":
				if pr.used:
					node.position.y -= delta * 9.0 * minf(1.0, pr.t * 4.0)  # it comes down
					node.visible = pr.t < 0.35
			"altar":
				if part:
					(part.material_override as StandardMaterial3D).emission_energy_multiplier = 0.1 if pr.used else 1.0 + 0.3 * sin(t * 3.0)
			"brick":
				if part:
					part.visible = not pr.used
					part.rotation.z = sin(pr.t * 40.0) * 0.08 * exp(-pr.t * 6.0) if pr.hits > 0 else 0.0
			"ink_blot":
				node.visible = not pr.used
			"dummy":
				if part:
					part.rotation.z = sin(pr.t * 9.0) * 0.12 * exp(-pr.t * 2.5)
			"cat":
				if part:
					part.position.y = (sin(pr.t / 0.5 * PI) * 30.0 * float(pr.k)) if (pr.hits > 0 and pr.t < 0.5) else 0.0
					var awake: bool = pr.t < 1.5 or float(pr.get("pet", 0.0)) > 0.0
					for e in pr.get("eyes", []):
						if is_instance_valid(e):
							(e as Node3D).visible = awake
	# the falling star
	if not _star.is_empty():
		if _star_node == null or not is_instance_valid(_star_node):
			var world := _set3d()
			if world:
				_star_node = Node3D.new()
				world.add_child(_star_node)
				var at := _wall_point(_star.pos, -1.7)
				var k := _m_per_px(at)
				_piece(_star_node, _ball3(8, k), Vector3.ZERO, Color(1.0, 0.97, 0.85), k, 9.0)
				for i in 5:
					_piece(_star_node, _ball3(5.0 - i * 0.8, k, 6), Vector3(-_star.vel.x * 0.02 * (i + 1), -_star.vel.y * 0.02 * (i + 1), 0), Color(1.0, 0.9, 0.6), k, 5.0 - i)
				_light3(_star_node, Color(1.0, 0.95, 0.75), 1.4, 2.0)
		if _star_node and is_instance_valid(_star_node):
			_star_node.global_position = _wall_point(_star.pos, -1.7)
	elif _star_node and is_instance_valid(_star_node):
		_star_node.queue_free()
		_star_node = null
	# the Orrery's planets, on the plane in front of the great rings
	var pls: Array = game.planets() if game and game.has_method("planets") else []
	if pls.is_empty():
		for n in _planet_nodes:
			if is_instance_valid(n):
				n.queue_free()
		_planet_nodes.clear()
	else:
		var world := _set3d()
		while _planet_nodes.size() < pls.size() and world:
			var pl: Dictionary = pls[_planet_nodes.size()]
			var holder := Node3D.new()
			world.add_child(holder)
			var at := _wall_point(pl.pos, -1.0)
			var k := _m_per_px(at)
			_piece(holder, _ball3(pl.r, k, 12), Vector3.ZERO, pl.color, k, 0.4)
			var ring := TorusMesh.new()
			ring.inner_radius = pl.r * 1.3 * k
			ring.outer_radius = pl.r * 1.55 * k
			_piece(holder, ring, Vector3.ZERO, Color(0.9, 0.8, 0.55), k, 0.3, Vector3(1.2, 0, 0.3))
			_planet_nodes.append(holder)
		for i in mini(pls.size(), _planet_nodes.size()):
			if is_instance_valid(_planet_nodes[i]):
				_planet_nodes[i].global_position = _wall_point(pls[i].pos, -1.0)
				_planet_nodes[i].rotation.y = t * (0.8 + i * 0.5)


func _free3d() -> void:
	for pr in props:
		var nv = pr.get("node")
		if nv != null and is_instance_valid(nv):
			(nv as Node).queue_free()
	if _star_node and is_instance_valid(_star_node):
		_star_node.queue_free()
	_star_node = null
	for n in _planet_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_planet_nodes.clear()


func _sprite(center: Vector2, rows: Array, palette: Dictionary) -> void:
	var w: float = (rows[0] as String).length() * CELL
	var h: float = rows.size() * CELL
	var origin := center - Vector2(w, h) * 0.5
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				draw_rect(Rect2(origin + Vector2(x, y) * CELL - Vector2(1, 1), Vector2(CELL + 2, CELL + 2)), Color(0, 0, 0, 0.55))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				draw_rect(Rect2(origin + Vector2(x, y) * CELL, Vector2(CELL, CELL)), palette[row[x]])


func _flame(at: Vector2, t: float, outer: Color, inner: Color, k: float = 1.0) -> void:
	var f := 1.0 + 0.15 * sin(t * 13.0) + 0.1 * sin(t * 7.3)
	draw_circle(at + Vector2(0, -2) * k, 7.0 * f * k, Color(outer.r, outer.g, outer.b, 0.85))
	draw_circle(at + Vector2(0, -6) * k, 4.5 * f * k, outer.lightened(0.2))
	draw_circle(at + Vector2(0, -3) * k, 3.0 * k, inner)
