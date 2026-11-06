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
##   blood altar      hold anything on it: it takes a share of your hand's health and
##                    gives it a rare modifier (once)
## and the secrets, which only show when the hand is close:
##   loose brick      punch it three times for what's hidden behind it
##   falling star     now and then one streaks across the Star Chamber's sky; punch it
## Hold Alt over one to read what it does (the secrets, once found).

const CELL := 7.5  # the items' own pixel size
## A keepsake for each secret place's guardian beaten: [what it is].
const RELICS := {"The Astronomer": ["a pocket orrery"], "Errata": ["a page with a blot on it"], "The Smelter": ["its crucible, on the mantel, still molten"]}
const BUNTING_MAX := 30  # flags on the home's bunting (a flag per five foes felled)
const NEAR := 110.0  # how close the hand has to be for a prop to show it's live
const INFO := {
	"core_trophy": ["The Smelter's Crucible", "Carried up from the Molten Core, where the floor gave way. It hasn't cooled, and it never will."],
	"torch": ["Wall Torch", "Hold a piece in the flame and it heats up: fire for element reactions, and a red-hot blade scorches what it hits."],
	"frost_drain": ["Frozen Drain", "Rimed over. Hold a piece against it and it chills: frost for element reactions."],
	"quench": ["Quench Barrel", "Ice-cold water. Dip a piece and it chills (red-hot metal is tempered): frost for element reactions."],
	"fungus": ["Fungus Bloom", "Hold a piece in it and it comes away poisoned: venom for element reactions."],
	"rust_grate": ["Rust Grate", "Weeping rust. Hold a piece in it and it turns corrosive: rot for element reactions. Careful what it touches after."],
	"storm_glass": ["Storm Glass", "A jar of trapped lightning. Hold a piece to it and it stays charged for a while: storm for element reactions."],
	"chandelier": ["Chandelier", "Punch the chain and it drops on whoever's below: a heavy blow that staggers, and the candles catch."],
	"altar": ["Blood Altar", "Hold anything on it: it takes a third of your hand's health and gives the piece a rare modifier. Once."],
	"brick": ["Loose Brick", "There was something behind it."],
	"star": ["Falling Star", "Punch one as it passes."],
	"still_star": ["A Star That Waits", "It hangs still, too high to punch. Something that weighs nothing might reach it."],
	"dummy": ["Training Dummy", "Swing at it to see what a hit does: rings, infusions and all. It remembers your best."],
	"tally": ["Tally", ""],  # these three are filled in from the save: see describe()
	"trophy_shelf": ["Trophy Shelf", ""],
	"pennant": ["Pennant", ""],
	"relics": ["Relic Shelf", ""],
	"bunting": ["Bunting", ""],
	"cat": ["The Cat", "Asleep on the sill. Rest your empty hand on it a while."],
	"hearth": ["Hearth", ""],  # filled in from the save: see describe()
	"gong": ["Gong", "Strike it to go on. Look closely at its face first."],
	"placard": ["Hoardsman", ""],  # the build's version: see describe()
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


## What each setting has, and where: [kind, screen spot, reach, chance it's there]. The
## Wall Map in the codex reads this too, to say what's in each place.
const LAYOUT := {
	"Dungeon Cell": [["torch", Vector2(210, 165), 30.0, 1.0], ["brick", Vector2(1040, 130), 18.0, 0.6]],
	"Corridor": [["torch", Vector2(1070, 160), 30.0, 1.0], ["chandelier", Vector2(640, 48), 26.0, 0.33], ["brick", Vector2(250, 300), 18.0, 0.6]],
	"Cistern": [["rust_grate", Vector2(1060, 160), 30.0, 1.0]],
	"Catacombs": [["fungus", Vector2(980, 150), 32.0, 1.0]],
	"Crypt Chapel": [["chandelier", Vector2(640, 48), 26.0, 0.33], ["altar", Vector2(210, 300), 34.0, 0.33]],
	"Forge": [["quench", Vector2(190, 250), 34.0, 1.0]],
	"Ossuary": [["fungus", Vector2(950, 150), 32.0, 1.0], ["brick", Vector2(330, 120), 18.0, 0.5]],
	"Star Chamber": [["storm_glass", Vector2(240, 160), 30.0, 1.0]],
	"Hidden Vault": [["chandelier", Vector2(640, 48), 26.0, 0.33]],
	"Homestead": [["dummy", Vector2(420, 470), 80.0, 1.0],  # stands on the floor
		["trophy_shelf", Vector2(790, 196), 60.0, 1.0],  # the trophy rack: a board the bosses' cups stand on (main.gd TROPHY_SLOTS)
		["tally", Vector2(520, 180), 50.0, 1.0],  # a chalk mark for every run, on the plaster by the window
		["pennant", Vector2(590, 360), 34.0, 1.0],  # hung on the plaster: a star for every prestige reached
		["bunting", Vector2(640, 40), 40.0, 1.0],  # strung along the top beam: a flag for every five foes felled
		["cat", Vector2(300, 408), 26.0, 1.0],  # on the window sill
		["placard", Vector2(790, 266), 30.0, 1.0],  # under the trophy board: which build this is
		["hearth", Vector2(1110, 560), 100.0, 1.0],  # the fireplace: melts junk down
		["storage", Vector2(108, 470), 88.0, 1.0]],  # the cupboard in the corner: let go of a thing over it to put it away, Space opens it
	"Clockwork Orrery": [["storm_glass", Vector2(240, 160), 30.0, 1.0]],
	"Ink Margin": [["fungus", Vector2(960, 150), 32.0, 1.0]],
}


## The kinds of thing a setting can have (secrets that aren't always there left out).
static func layout(setting: String) -> Array:
	var out: Array = []
	for p in LAYOUT.get(setting, []):
		if (float(p[3]) >= 1.0 or (float(p[3]) >= 0.3 and p[0] != "brick")) and not out.has(p[0]):  # (a loose brick is a secret: unnamed)
			out.append(p[0])
	if setting == "Star Chamber":
		out.append("star")
	return out


## The props for a setting. Clears whatever was there.
func setup(setting: String, rng_seed: int) -> void:
	_free3d()
	props.clear()
	_star = {}
	_rng.seed = rng_seed
	for p in LAYOUT.get(setting, []):
		if float(p[3]) >= 1.0 or _rng.randf() < float(p[3]):
			_add(p[0], p[1], p[2])
	if setting == "Star Chamber":
		_star_timer = _rng.randf_range(6.0, 12.0)
	if setting == "Homestead" and game:
		var have: Array = game.save.found.get("guardians", [])
		if not have.filter(func(g: String) -> bool: return g != "The Smelter").is_empty():
			_add("relics", Vector2(726, 350), 70.0)  # a shelf of keepsakes from the secret places' guardians
		if have.has("The Smelter"):
			_add("core_trophy", Vector2(1010, 292), 40.0)  # the Molten Core's prize: up on the mantel, glowing
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
		return ["Hearth", "Throw a boss's cup in the fire and it melts down into coins. Junk melts too (scraps, pauldrons, skulls, rocks), a coin for every so much of it; throw wood on and it roars up. Coins left at home come along on your next run."]
	if kind == "storage" and game:
		return ["Storage Cupboard", "Let go of something over the cupboard to put it away; press Space on it (hand empty) to open it and take things back out. What's stored stays home when you set out.\nStored: %d of %d" %
			[game.save.storage.size(), Storage.CAPACITY]]
	if kind == "placard":
		return ["Hoardsman", "Build %s" % version()]
	if game:
		var st: Dictionary = game.save.stats
		match kind:
			"tally":
				return ["Tally", "A chalk mark for every run you've set out on: %d. The charcoal ones didn't come back: %d.\nFoes felled, all told: %d." % [st.runs, st.deaths, st.kills]]
			"trophy_shelf":
				var cups: int = game.save.trophies.size()
				var melted := int(st.get("melted_cups", 0))
				if int(st.bosses) <= 0:
					return ["Trophy Rack", "Empty. Fell a boss and its cup goes up here."]
				return ["Trophy Rack", "A cup for every boss you've felled, the deeper the run the bigger the cup: %d standing%s. Throw one in the hearth and it melts down into coins for your next run." %
					[cups, (", %d melted down" % melted) if melted > 0 else ""]]
			"relics":
				var have: Array = game.save.found.get("guardians", [])
				var lines: Array = []
				for g in have:
					lines.append("%s: %s" % [RELICS.get(g, ["a keepsake"])[0], g])
				return ["Relic Shelf", "Something from every secret place's guardian you've beaten (%d of %d).\n%s" % [have.size(), Secrets.STAGES.size(), "\n".join(PackedStringArray(lines))]]
			"bunting":
				return ["Bunting", "A flag for every five foes you've felled: %d felled, %d flags." % [st.kills, mini(int(st.kills / 5), BUNTING_MAX)] if st.kills >= 5 else "A bare string. Fell five foes and the first flag goes up."]
			"pennant":
				return ["Pennant", "A star for every prestige reached: your deepest run went to prestige %d." % game.save.prestige_best if game.save.prestige_best > 0 else "Plain. Push a run past its first boss and it gets its first star."]
	return INFO.get(kind, ["?", ""])


## This build's version (project.godot: application/config/version), e.g. "v0.3.0".
static func version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## The prop under the hand, for the inspect card: "prop:<kind>", or "".
func info_at(p: Vector2) -> String:
	if game and game.state == game.State.SHOP and not game.overlay.gong.is_empty() and p.distance_to(game.overlay.gong.pos) <= float(game.overlay.gong.radius) + 8.0:
		return "prop:gong"
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
## something brought to them: the star that waits.
func feed(items: Array, delta: float) -> void:
	for pr in props:
		if pr.kind == "brick" and pr.used:
			continue
		if pr.kind == "hearth":
			for n in items:
				var it := n as Item
				if it == null or not it.owned or it.held or it.freeze or it.is_queued_for_deletion():
					continue
				var junk: bool = it.def.kind in ["junk", "debris"] or it.def.get("piece", false)
				var cup: bool = it.def.kind == "trophy"
				if not junk and not cup and not _wooden(it):
					continue
				if it.global_position.distance_to(pr.pos) > pr.r:
					it.remove_meta("in_fire")
					continue
				# your own wooden gear (and a boss's cup) goes on the fire only when it's thrown
				# in (not when it just rolls up against the hearth)
				if not junk and not it.has_meta("in_fire") and game.clock - float(it.get_meta("let_go_at", -99.0)) > 3.0:
					continue
				it.set_meta("in_fire", float(it.get_meta("in_fire", 0.0)) + delta)
				it.heat = minf(1.0, it.heat + delta)
				if float(it.get_meta("in_fire")) > (0.8 if junk else 1.5):
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
					if it.def.kind in ["menu", "upgrade"] or not it.held:
						continue
					it.set_meta("on_altar", float(it.get_meta("on_altar", 0.0)) + delta)
					if float(it.get_meta("on_altar")) > 1.5:
						it.set_meta("on_altar", 0.0)
						pr.used = game.on_altar(it, pr.pos)  # (nothing left to give it: the altar waits)


func _touches(it: Item, pr: Dictionary) -> bool:
	var xf := it.global_transform
	var r2: float = pr.r * pr.r
	for c in it.cells:
		if (xf * it.cell_pos(c)).distance_squared_to(pr.pos) <= r2:
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
			var burlap := Color(0.56, 0.45, 0.3)
			var rope := Color(0.55, 0.12, 0.1)
			_piece(root, _box3(120, 10, 60, k), Vector3(0, -5, 0), Color(0.3, 0.2, 0.11), k)
			var body := Node3D.new()
			root.add_child(body)
			pr.flame = body  # what sways
			_piece(body, _cyl3(7, 7, 210, k, 8), Vector3(0, -105, 0), wood, k)
			_piece(body, _box3(90, 120, 50, k), Vector3(0, -260, 0), burlap, k)  # a burlap sack of straw
			_piece(body, _box3(150, 18, 22, k), Vector3(0, -300, 0), burlap.darkened(0.1), k)
			_piece(body, _cyl3(22, 22, 4, k, 12), Vector3(0, -262, 26), Color(0.62, 0.13, 0.12), k, 0.0, Vector3(PI / 2, 0, 0))  # a painted target
			_piece(body, _cyl3(10, 10, 5, k, 10), Vector3(0, -262, 27), Color(0.9, 0.82, 0.62), k, 0.0, Vector3(PI / 2, 0, 0))
			_piece(body, _ball3(30, k, 10), Vector3(0, -350, 0), straw.lightened(0.05), k)
			for i in 3:
				_piece(body, _box3(94, 5, 54, k), Vector3(0, -225 - i * 30, 0), rope, k)  # red rope lashings
		"trophy_shelf":
			# a wall shelf on two brackets: the bosses' cups stand on it (real things: main.gd
			# puts them there)
			_piece(root, _box3(230, 8, 34, k), Vector3(0, 22, 14), wood, k)
			for sx in [-1, 1]:
				_piece(root, _box3(8, 26, 30, k), Vector3(sx * 96, 36, 10), wood.darkened(0.2), k)
		"tally":
			# chalk marks scratched on the plaster, in fives: one per run. The runs that ended
			# in a death are in charcoal.
			var runs := mini(int(game.save.stats.runs) if game else 0, 60)
			var died := mini(int(game.save.stats.deaths) if game else 0, runs)
			for i in runs:
				var grp := int(i / 5)
				var gx := -60.0 + (grp % 5) * 28.0
				var gy := -30.0 + int(grp / 5) * 26.0
				var col := Color(0.12, 0.1, 0.09) if i < died else Color(0.92, 0.9, 0.82)
				if i % 5 == 4:
					_piece(root, _box3(26, 2.5, 1, k), Vector3(gx + 6, gy, 2), col, k, 0.1, Vector3(0, 0, 0.5))  # the strike through
				else:
					_piece(root, _box3(2.5, 18, 1, k), Vector3(gx + (i % 5) * 5, gy, 1), col, k, 0.1, Vector3(0, 0, 0.06 * ((i * 7) % 3 - 1)))
		"core_trophy":
			# the Smelter's crucible: squat black iron on three stubby feet, brimming with slag that
			# never cools, a glowing drip down its lip, lighting the plaster above it
			var slag := Color(0.85, 0.2, 0.04)  # (deep: a brighter glow washes out to the plaster's cream in the home's grade)
			for fx in [-14, 0, 14]:
				_piece(root, _box3(6, 8, 6, k), Vector3(fx, 4, 14 + absf(fx) * 0.3), iron.darkened(0.4), k)
			_piece(root, _cyl3(30, 20, 38, k, 14), Vector3(0, -19, 14), Color(0.09, 0.08, 0.08), k)
			_piece(root, _cyl3(33, 33, 5, k, 14), Vector3(0, -38, 14), Color(0.16, 0.13, 0.12), k)  # the rim
			for hx in [-1, 1]:
				_piece(root, _box3(10, 5, 6, k), Vector3(hx * 36, -30, 14), Color(0.12, 0.1, 0.09), k)  # lugs
			pr.flame = _piece(root, _cyl3(28, 28, 3, k, 14), Vector3(0, -41, 14), slag, k, 1.4)  # the molten top
			# heaped up over the rim, so it shows from the front: a glowing mound with dark crusts
			_piece(root, _ball3(24, k, 10), Vector3(0, -44, 18), slag, k, 1.2).scale = Vector3(1.0, 0.45, 0.8)
			for i in 5:
				var a := i * 1.3
				_piece(root, _ball3(4.0 + (i % 2) * 2.0, k, 6), Vector3(cos(a) * 15, -50, 22 + sin(a) * 8), Color(0.2, 0.08, 0.04), k, 0.4)  # crusts
			for cx in [-12, 4, 15]:  # cracks in the iron, glowing through
				_piece(root, _box3(2.5, 14, 1, k), Vector3(cx, -18, 40), slag, k, 1.0, Vector3(0, 0, 0.3 if cx < 0 else -0.25))
			_piece(root, _box3(5, 22, 3, k), Vector3(22, -26, 34), slag, k, 1.2, Vector3(0, 0, 0.12))  # the drip
			_piece(root, _ball3(4, k, 6), Vector3(24, -15, 34), slag, k, 1.2)
			_light3(root, Color(1.0, 0.4, 0.15), 0.5, 0.9).position = Vector3(0, -60, 30) * k
		"relics":
			# a little wall shelf, and on it whatever's been brought back from the secret places
			_piece(root, _box3(170, 7, 30, k), Vector3(0, 20, 12), wood.darkened(0.1), k)
			for sx in [-1, 1]:
				_piece(root, _box3(6, 20, 24, k), Vector3(sx * 70, 32, 10), wood.darkened(0.3), k)
			var have: Array = game.save.found.get("guardians", []) if game else []
			var order := ["The Astronomer", "Errata"]  # (the Smelter's is on the mantel: core_trophy)
			for i in order.size():
				if not have.has(order[i]):
					continue
				var x := -22.0 + i * 44.0
				match order[i]:
					"The Astronomer":  # a brass orrery: a sun, a ring, a little world
						_piece(root, _cyl3(3, 5, 8, k, 6), Vector3(x, 14, 14), Color(0.7, 0.55, 0.25), k)
						_piece(root, _ball3(5, k, 8), Vector3(x, 4, 14), Color(1.0, 0.8, 0.35), k, 1.5)
						_piece(root, _cyl3(11, 11, 1.2, k, 14), Vector3(x, 4, 14), Color(0.75, 0.6, 0.3), k, 0.0, Vector3(0.4, 0, 0.2))
						_piece(root, _ball3(2.4, k, 6), Vector3(x + 11, 1, 16), Color(0.4, 0.55, 0.9), k)
					"Errata":  # a page with a blot on it, propped against the wall
						_piece(root, _box3(20, 26, 1, k), Vector3(x, 5, 6), Color(0.92, 0.88, 0.78), k, 0.0, Vector3(-0.2, 0, 0.05))
						_piece(root, _ball3(5, k, 7), Vector3(x + 2, 4, 8), Color(0.03, 0.03, 0.05), k)
		"bunting":
			# a string along the beam; a little triangle flag on it for every five foes felled
			var n := mini(int(int(game.save.stats.kills) / 5) if game else 0, BUNTING_MAX)
			var span := 1000.0
			for i in 21:  # the string, sagging between nails
				var x0 := -span * 0.5 + i * span / 21.0
				var sag := 10.0 * sin(PI * fmod(float(i) / 21.0 * 3.0, 1.0))
				_piece(root, _box3(span / 21.0 + 2, 1.5, 1.5, k), Vector3(x0 + span / 42.0, sag, 2), Color(0.75, 0.68, 0.5), k)
			var cols := [Color(0.6, 0.15, 0.12), Color(0.85, 0.7, 0.3), Color(0.2, 0.35, 0.6), Color(0.3, 0.5, 0.25), Color(0.85, 0.8, 0.7)]
			for i in n:
				var x := -span * 0.5 + (i + 0.5) * span / BUNTING_MAX
				var sag := 10.0 * sin(PI * fmod((i + 0.5) / BUNTING_MAX * 3.0, 1.0))
				for row in 4:
					_piece(root, _box3(18.0 * (1.0 - row / 4.0), 5, 1, k), Vector3(x, sag + 4 + row * 5, 3), cols[i % cols.size()], k)
		"pennant":
			# a long cloth pennant from the beam, a gold star for every prestige reached
			var cloth := Color(0.5, 0.12, 0.1)
			_piece(root, _cyl3(2, 2, 70, k, 6), Vector3(0, -38, 4), wood, k, 0.0, Vector3(0, 0, PI / 2))  # the rod
			for row in 10:
				var w := 60.0 * (1.0 - row / 10.0)
				_piece(root, _box3(w, 9, 2, k), Vector3(0, -30 + row * 9, 4), cloth.darkened(0.06 * (row % 2)), k)
			for i in mini(int(game.save.prestige_best) if game else 0, 6):
				_piece(root, _box3(7, 7, 2, k), Vector3(0, -24 + i * 12, 6), Color(1.0, 0.8, 0.3), k, 1.2, Vector3(0, 0, PI / 4))
		"placard":
			_piece(root, _box3(152, 64, 6, k), Vector3.ZERO, wood, k)
			_piece(root, _box3(144, 56, 2, k), Vector3(0, 0, 3.5), wood.lightened(0.12), k)
			for sx in [-1, 1]:
				_piece(root, _cyl3(2, 2, 3, k, 6), Vector3(sx * 68, -25, 5), iron, k, 0.0, Vector3(PI / 2, 0, 0))
			var ink := Color(0.16, 0.1, 0.05)
			_letters(root, "HOARDSMAN", 18, Vector3(0, -11, 5), ink, k)
			_letters(root, version(), 18, Vector3(0, 13, 5), ink, k)
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


## Mostly wood (or anything else that burns): it'll feed the hearth.
static func _wooden(it: Item) -> bool:
	var n := 0
	for c in it.cells:
		if Materials.get_mat(it.cells[c].mat).get("burns", false):
			n += 1
	return n * 2 >= it.cells.size() and n > 0


## Words burnt into a prop, `size` screen pixels tall, centred on `px`.
func _letters(parent: Node3D, text: String, size: int, px: Vector3, col: Color, k: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size * 4
	l.pixel_size = k / 4.0
	l.outline_size = 0
	l.modulate = col
	l.shaded = true
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	l.position = Vector3(px.x, -px.y, px.z) * k
	l.set_meta("prop", true)
	parent.add_child(l)


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


