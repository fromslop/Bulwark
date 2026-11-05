class_name Backdrop
extends Node3D
## The place a fight happens in. Each setting is built from low-poly primitives: tight,
## dim spaces lit by their own fires and candles, no long sight lines. The enemy stands at
## the origin facing +z; the camera sits at z 1.5 framing it waist-up.

const SETTINGS := ["Dungeon Cell", "Corridor", "Cistern", "Catacombs", "Crypt Chapel", "Forge"]
# Early settings are bare; middle and late ones bring their own features.
const TIERS := {"early": ["Dungeon Cell", "Corridor"], "middle": ["Cistern", "Catacombs"], "late": ["Crypt Chapel", "Forge", "Ossuary", "Star Chamber"]}
# Places only a deep run finds: they need a prestige and then only turn up sometimes.
const RARE := {"Ossuary": {"prestige": 2, "chance": 0.3}, "Star Chamber": {"prestige": 3, "chance": 0.3}}
const BLURB := {
	"Dungeon Cell": "Where it starts. Bars, chains, one torch.",
	"Corridor": "A vaulted passage running off into the dark.",
	"Cistern": "Floodwater along the bottom: things float, fires go out, red-hot metal is quenched, and charge spreads through the water.",
	"Catacombs": "Pitch dark. Take the lantern off the wall and it lights wherever you put it.",
	"Crypt Chapel": "Stained glass and a reliquary to smash open mid-fight.",
	"Forge": "A hammer and sometimes a weapon on the rack, and a hearth that heats whatever you hold in it.",
	"Ossuary": "A hall of bone. Skulls on the ledge, and more of them dropping from the ceiling now and then.",
	"Star Chamber": "An observatory open to the night. Nothing weighs much here: everything you drop hangs in the air.",
	"Hidden Vault": "Behind the lever. A treasure room with its own warden.",
	"Gilded Gullet": Secrets.STAGES["Gilded Gullet"].blurb,
	"Giant's Table": Secrets.STAGES["Giant's Table"].blurb,
	"Clockwork Orrery": Secrets.STAGES["Clockwork Orrery"].blurb,
	"Ink Margin": Secrets.STAGES["Ink Margin"].blurb,
	"Molten Core": Secrets.STAGES["Molten Core"].blurb,
	"Homestead": "Home. Your racks, your codex, your gong.",
}


## Which setting a round is fought in: a five-stage run goes early, early, middle, middle,
## late. Past a prestige, the rare places can take a late slot. Never the place you were just
## in, nor (when there's other choice) the one before it: `recent` is the latest places, newest last.
static func for_round(n: int, rng: RandomNumberGenerator, prestige: int = 0, recent: Array = []) -> String:
	var stage := n % 5
	var pool: Array
	if stage < 2 and prestige == 0:
		pool = TIERS.early
	elif stage < 4:
		pool = TIERS.middle + (TIERS.late if prestige > 0 else [])
	else:
		pool = TIERS.late
	pool = pool.filter(func(nm: String) -> bool: return not RARE.has(nm) or int(RARE[nm].prestige) <= prestige)
	for k in [2, 1]:
		var fresh := pool.filter(func(nm: String) -> bool: return not recent.slice(-k).has(nm))
		if not fresh.filter(func(nm: String) -> bool: return not RARE.has(nm)).is_empty():
			pool = fresh
			break
	for nm in RARE:
		if pool.has(nm) and rng.randf() < float(RARE[nm].chance):
			return nm
	var plain := pool.filter(func(nm: String) -> bool: return not RARE.has(nm))
	return plain[rng.randi() % plain.size()]

# per setting: fog density, fog colour, ambient energy
const ENV := {
	"Homestead": {"fog": 0.1, "fog_color": Color(0.05, 0.03, 0.015), "ambient": 0.36},  # (dimmer: the fire and the lantern light it)
	"Ossuary": {"fog": 0.2, "fog_color": Color(0.03, 0.03, 0.025), "ambient": 0.32},
	"Star Chamber": {"fog": 0.05, "fog_color": Color(0.01, 0.01, 0.03), "ambient": 0.3},
	"Dungeon Cell": {"fog": 0.18, "fog_color": Color(0.02, 0.02, 0.025), "ambient": 0.35},
	"Corridor": {"fog": 0.22, "fog_color": Color(0.01, 0.01, 0.012), "ambient": 0.3},
	"Catacombs": {"fog": 0.25, "fog_color": Color(0.03, 0.025, 0.02), "ambient": 0.3},
	"Crypt Chapel": {"fog": 0.12, "fog_color": Color(0.03, 0.03, 0.05), "ambient": 0.35},
	"Cistern": {"fog": 0.3, "fog_color": Color(0.01, 0.03, 0.03), "ambient": 0.3},
	"Forge": {"fog": 0.15, "fog_color": Color(0.05, 0.02, 0.01), "ambient": 0.35},
	"Hidden Vault": {"fog": 0.12, "fog_color": Color(0.05, 0.035, 0.01), "ambient": 0.4},
	"Gilded Gullet": {"fog": 0.15, "fog_color": Color(0.15, 0.05, 0.02), "ambient": 0.5},
	"Giant's Table": {"fog": 0.06, "fog_color": Color(0.08, 0.05, 0.03), "ambient": 0.55},
	"Clockwork Orrery": {"fog": 0.05, "fog_color": Color(0.0, 0.0, 0.02), "ambient": 0.35},
	"Ink Margin": {"fog": 0.02, "fog_color": Color(0.9, 0.87, 0.8), "ambient": 0.9},
	"Molten Core": {"fog": 0.05, "fog_color": Color(0.3, 0.07, 0.01), "ambient": 0.35},
}

# per setting: the world grade's five colour stops (dark to bright) and its texture
const LOOK := {
	"Homestead": {"c": [Color(0.03, 0.025, 0.05), Color(0.17, 0.1, 0.1), Color(0.52, 0.29, 0.13), Color(0.93, 0.63, 0.3), Color(1.0, 0.93, 0.72)],
		"pixel": 2.0, "noise": 0.03, "gamma": 0.82, "contrast": 1.15},  # (cool shadows under warm firelight: depth)
	"Ossuary": {"c": [Color(0.03, 0.03, 0.02), Color(0.2, 0.18, 0.12), Color(0.5, 0.45, 0.32), Color(0.85, 0.8, 0.62), Color(1.0, 0.98, 0.9)],
		"pixel": 2.0, "noise": 0.08, "gamma": 0.85, "contrast": 1.1},
	"Star Chamber": {"c": [Color(0.0, 0.0, 0.04), Color(0.05, 0.05, 0.25), Color(0.2, 0.25, 0.6), Color(0.6, 0.7, 0.95), Color(0.95, 0.98, 1.0)],
		"pixel": 2.0, "noise": 0.04, "gamma": 0.85, "contrast": 1.15},
	"Dungeon Cell": {"c": [Color(0.01, 0.02, 0.05), Color(0.08, 0.14, 0.26), Color(0.22, 0.4, 0.45), Color(0.75, 0.75, 0.45), Color(1.0, 0.96, 0.75)],
		"pixel": 2.0, "noise": 0.05, "gamma": 0.8, "contrast": 1.05},
	"Corridor": {"c": [Color(0.0, 0.0, 0.0), Color(0.3, 0.02, 0.02), Color(0.75, 0.2, 0.05), Color(1.0, 0.62, 0.2), Color(1.0, 0.92, 0.75)],
		"pixel": 2.0, "noise": 0.03, "gamma": 0.95, "contrast": 1.25},
	"Catacombs": {"c": [Color(0.04, 0.025, 0.015), Color(0.22, 0.14, 0.07), Color(0.5, 0.36, 0.2), Color(0.82, 0.72, 0.52), Color(1.0, 0.96, 0.86)],
		"pixel": 2.0, "noise": 0.09, "gamma": 0.8, "contrast": 1.1},
	"Crypt Chapel": {"c": [Color(0.03, 0.01, 0.1), Color(0.24, 0.06, 0.4), Color(0.7, 0.15, 0.5), Color(0.98, 0.72, 0.3), Color(0.92, 0.88, 1.0)],
		"pixel": 2.0, "noise": 0.04, "gamma": 0.75, "contrast": 1.0},
	"Cistern": {"c": [Color(0.0, 0.03, 0.02), Color(0.02, 0.17, 0.15), Color(0.1, 0.42, 0.33), Color(0.5, 0.8, 0.62), Color(0.88, 1.0, 0.9)],
		"pixel": 3.0, "noise": 0.06, "gamma": 0.85, "contrast": 1.1},
	"Hidden Vault": {"c": [Color(0.04, 0.02, 0.0), Color(0.3, 0.16, 0.03), Color(0.75, 0.5, 0.1), Color(1.0, 0.85, 0.35), Color(1.0, 1.0, 0.85)],
		"pixel": 2.0, "noise": 0.04, "gamma": 0.85, "contrast": 1.15},
	"Forge": {"c": [Color(0.02, 0.0, 0.0), Color(0.4, 0.02, 0.02), Color(0.9, 0.3, 0.02), Color(1.0, 0.8, 0.15), Color(1.0, 1.0, 0.92)],
		"pixel": 2.0, "noise": 0.03, "gamma": 1.05, "contrast": 1.4},
	"Gilded Gullet": {"c": [Color(0.12, 0.0, 0.02), Color(0.5, 0.08, 0.05), Color(0.9, 0.5, 0.1), Color(1.0, 0.85, 0.35), Color(1.0, 1.0, 0.85)],
		"pixel": 2.0, "noise": 0.04, "gamma": 0.95, "contrast": 1.3},
	"Giant's Table": {"c": [Color(0.08, 0.04, 0.02), Color(0.35, 0.2, 0.1), Color(0.75, 0.5, 0.25), Color(1.0, 0.85, 0.55), Color(1.0, 0.98, 0.9)],
		"pixel": 2.0, "noise": 0.03, "gamma": 0.9, "contrast": 1.05},
	"Clockwork Orrery": {"c": [Color(0.0, 0.0, 0.05), Color(0.08, 0.06, 0.25), Color(0.5, 0.35, 0.2), Color(0.95, 0.75, 0.35), Color(1.0, 0.98, 0.85)],
		"pixel": 2.0, "noise": 0.04, "gamma": 0.85, "contrast": 1.2},
	"Molten Core": {"c": [Color(0.02, 0.0, 0.0), Color(0.25, 0.03, 0.02), Color(0.75, 0.2, 0.05), Color(1.0, 0.6, 0.15), Color(1.0, 0.95, 0.7)],
		"pixel": 2.0, "noise": 0.05, "gamma": 0.85, "contrast": 1.2},
	"Ink Margin": {"c": [Color(0.02, 0.02, 0.03), Color(0.15, 0.15, 0.17), Color(0.55, 0.53, 0.5), Color(0.88, 0.85, 0.77), Color(0.98, 0.96, 0.9)],
		"pixel": 1.0, "noise": 0.02, "gamma": 1.0, "contrast": 1.6, "keep": 0.0},
}

var setting := ""
var lever: Node3D = null  # late settings sometimes hide one: pull it to find the Hidden Vault
var lever_pulled := false
var _flicker: Array = []  # [light, base energy, speed, phase]
var _flames: Array = []  # [mesh, base scale, speed, phase]: tongues of fire that lick and sway
var _spinners: Array = []  # [node, radians per second]: rings of crust turning round the Molten Core's whirlpool
var _risers: Array = []  # [node, speed, bottom, top, drift]: embers and bubbles rising, then starting over
var _rng := RandomNumberGenerator.new()


static func create(name: String, with_lever: bool = false) -> Backdrop:
	var b := Backdrop.new()
	b.setting = name
	b._rng.seed = hash(name)
	match name:
		"Corridor":
			b._corridor()
		"Catacombs":
			b._catacombs()
		"Crypt Chapel":
			b._crypt()
		"Cistern":
			b._cistern()
		"Forge":
			b._forge()
		"Hidden Vault":
			b._vault()
		"Homestead":
			b._homestead()
		"Ossuary":
			b._ossuary()
		"Star Chamber":
			b._star_chamber()
		"Gilded Gullet":
			b._gullet()
		"Giant's Table":
			b._giant_table()
		"Clockwork Orrery":
			b._orrery()
		"Ink Margin":
			b._margin()
		"Molten Core":
			b._molten_core()
		_:
			b._cell()
	if with_lever:
		b._add_lever()
	return b


## The Molten Core: deep under the mantle, a lake of magma turning in a slow whirlpool. Rings
## of cooling crust wheel round its glowing eye at different speeds, slag bubbles and embers
## rise through the heat, falls of lava pour from the cavern's ribs, and the mantle's rock
## arches overhead, lit from below.
func _molten_core() -> void:
	var basalt := Color(0.07, 0.05, 0.05)
	var mantle := Color(0.18, 0.06, 0.04)
	var lava := Color(1.0, 0.38, 0.06)
	var hot := Color(1.0, 0.75, 0.25)
	var centre := Vector3(0, 0.0, -6.0)  # (well back: you look out across the lake to its eye)
	# the lake: a wide disc of magma, and its eye, white-hot, where it drains away
	_cyl(9.0, 9.0, 0.06, centre + Vector3(0, -0.04, 1.5), lava, 48, Vector3.ZERO, 2.2)
	_cyl(0.9, 0.9, 0.07, centre + Vector3(0, -0.02, 0), hot, 32, Vector3.ZERO, 4.0)
	_cyl(0.4, 0.4, 0.08, centre + Vector3(0, -0.01, 0), Color(1.0, 0.95, 0.7), 24, Vector3.ZERO, 6.0)
	# rings of crust wheeling round the eye: inner ones fast, outer ones slow
	for ring in 9:
		var spin := Node3D.new()
		spin.position = centre
		add_child(spin)
		_spinners.append([spin, (0.75 - ring * 0.07) * (1.0 if ring % 2 == 0 else 0.85)])
		var r := 1.2 + ring * 0.75
		var n := 12 + ring * 6
		for k in n:
			var a := TAU * k / n + _rng.randf() * 0.2
			var crust := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(_rng.randf_range(0.3, 0.6) + ring * 0.05, 0.05, _rng.randf_range(0.15, 0.3))
			bm.material = _mat(basalt.lightened(_rng.randf() * 0.1), 1.0, 0.0)
			crust.mesh = bm
			crust.position = Vector3(cos(a) * r, 0.02, sin(a) * r)
			crust.rotation = Vector3(0, -a + PI * 0.5 + _rng.randf_range(-0.3, 0.3), 0)  # (lying along the flow)
			spin.add_child(crust)
			if k % 3 == 0:  # a glowing seam where the crust has split
				var seam := MeshInstance3D.new()
				var sm := BoxMesh.new()
				sm.size = Vector3(bm.size.x * 0.8, 0.045, 0.02)
				sm.material = _mat(hot, 1.0, 3.5)
				seam.mesh = sm
				seam.position = crust.position + Vector3(0, 0.005, 0)
				seam.rotation = crust.rotation
				spin.add_child(seam)
	# the cavern: mantle rock rising round the lake and arching overhead in ribs
	for k in 40:  # the far wall of the cavern: jagged mantle rock, lit from below
		_box(Vector3(_rng.randf_range(1.0, 2.6), _rng.randf_range(1.2, 3.0), 0.8), Vector3(-9.0 + k * 0.45, _rng.randf_range(0.4, 6.5), -12.5 + _rng.randf_range(-0.6, 0.6)),
			mantle.lightened(_rng.randf() * 0.12), Vector3(0, 0, _rng.randf_range(-0.4, 0.4)))
	_box(Vector3(30, 14, 0.5), Vector3(0, 5, -13.5), mantle.darkened(0.4))
	for k in 14:  # glowing seams in the far wall: magma showing through cracks in the mantle
		var x := -8.0 + k * 1.2 + _rng.randf_range(-0.3, 0.3)
		var y := _rng.randf_range(0.5, 6.0)
		for j in 4:
			_box(Vector3(0.08, 0.6, 0.05), Vector3(x + j * 0.18, y + j * 0.45, -11.9), lava, Vector3(0, 0, 0.5 * (-1) ** j), 3.0)
	for side in [-1, 1]:
		for k in 8:  # the side walls, broken rock running back into the dark
			_box(Vector3(1.2, _rng.randf_range(3.0, 6.0), 1.6), Vector3(side * _rng.randf_range(3.2, 4.4), 1.8, 1.0 - k * 1.7), mantle.darkened(_rng.randf_range(0.2, 0.5)),
				Vector3(0, _rng.randf(), side * _rng.randf_range(-0.2, 0.1)))
	for k in 5:  # the ribs of the cavern, black against the glow, marching away over the lake
		var z := -10.0 + k * 2.0
		for side in [-1, 1]:
			_box(Vector3(0.6, 6.0, 0.6), Vector3(side * (4.2 - k * 0.3), 2.6, z), basalt, Vector3(0, 0, side * -0.3))
		_box(Vector3(8.0 - k * 0.6, 0.6, 0.6), Vector3(0, 5.2 - k * 0.3, z), basalt)
	for k in 18:  # stalactites of slag hanging from the vault
		var x := -2.6 + k * 0.3 + _rng.randf_range(-0.08, 0.08)
		var h := _rng.randf_range(0.3, 1.1)
		_cyl(0.0, _rng.randf_range(0.07, 0.16), h, Vector3(x * 1.6, 3.6 - h * 0.5, _rng.randf_range(-8.0, -1.0)), basalt.lightened(0.06), 6)
	# falls of lava pouring from the ribs into the lake
	for side in [-1, 1]:
		for k in 2:
			var x: float = side * (3.0 + k * 1.2)
			_box(Vector3(0.3 - k * 0.06, 6.0, 0.1), Vector3(x, 3.0, -8.0 + k * 1.5), lava.lightened(0.1 * k), Vector3.ZERO, 3.0)
			_cyl(0.5, 0.7, 0.06, Vector3(x, 0.02, -8.0 + k * 1.5), hot, 12, Vector3.ZERO, 3.5)  # where it hits the lake
	# slag bubbles welling up from the lake, embers lifting off it
	for k in 40:
		var ember := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3.ONE * _rng.randf_range(0.02, 0.05)
		em.material = _mat(hot if k % 3 else lava, 1.0, 4.0)
		ember.mesh = em
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.3, 6.0)
		ember.position = centre + Vector3(cos(a) * r, _rng.randf_range(0.0, 3.2), sin(a) * r * 0.6 + 2.5)
		add_child(ember)
		_risers.append([ember, _rng.randf_range(0.25, 0.7), 0.0, 3.4, _rng.randf() * TAU])
	# basalt pillars standing out of the lake at its edge, a few with molten cracks
	for k in 8:
		var a := PI + k * PI / 7.0
		var pos := centre + Vector3(cos(a) * 5.5, 0.0, sin(a) * 2.5 + 1.0)
		var h := _rng.randf_range(0.6, 1.8)
		_cyl(0.13, 0.22, h, pos + Vector3(0, h * 0.5, 0), Color(0.11, 0.07, 0.08), 5)
		if k % 2 == 0:
			_box(Vector3(0.03, h * 0.7, 0.02), pos + Vector3(0.05, h * 0.5, 0.19), lava, Vector3.ZERO, 3.0)
	_light(centre + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.15), 8.0, 12.0)  # the eye lights the cavern from below
	_light(Vector3(-2.5, 1.5, -3.0), Color(1.0, 0.42, 0.12), 3.0, 6.0)
	_light(Vector3(2.5, 1.5, -3.0), Color(1.0, 0.42, 0.12), 3.0, 6.0)
	_light(Vector3(0, 1.2, 0.2), Color(1.0, 0.45, 0.12), 1.6, 3.0)  # the lake's glow on the foe


## The way down to the Molten Core, for the fall: a shaft through the earth below the shop,
## soil and roots, then rock with veins of ore, then deep black stone, then the red glow of
## the fire coming up from under it all. `depth` metres.
static func create_shaft(depth: float) -> Backdrop:
	var b := Backdrop.new()
	b.setting = "shaft"
	b._rng.seed = 77
	var bands := [[0.0, Color(0.5, 0.33, 0.18)], [0.3, Color(0.55, 0.52, 0.48)], [0.6, Color(0.3, 0.28, 0.32)], [0.85, Color(0.55, 0.14, 0.05)]]
	var y := -0.3
	while y > -depth:
		var f := -y / depth
		var col: Color = bands[0][1]
		for band in bands:
			if f >= float(band[0]):
				col = band[1]
		var glow := 0.25 if f < 0.85 else 0.25 + (f - 0.85) * 12.0  # (lit a little by itself: the fall reads in the dark)
		b._box(Vector3(6.0, 1.6, 0.4), Vector3(0, y, -1.7), col.lightened(b._rng.randf() * 0.06), Vector3.ZERO, glow)
		for side in [-1, 1]:
			b._box(Vector3(0.6, 1.6, 5.0), Vector3(side * 2.2, y, 0.3), col.darkened(0.25))
		for k in 5:  # rocks, roots and veins in the walls
			var x := b._rng.randf_range(-2.2, 2.2)
			var detail: Color = Color(0.45, 0.3, 0.15) if f < 0.3 else (Color(0.75, 0.6, 0.25) if b._rng.randf() < 0.3 else col.lightened(0.12))
			b._box(Vector3(b._rng.randf_range(0.1, 0.5), b._rng.randf_range(0.05, 0.3), 0.3), Vector3(x, y + b._rng.randf_range(-0.7, 0.7), -1.45), detail,
				Vector3(0, 0, b._rng.randf_range(-0.6, 0.6)), 2.0 if f > 0.85 else 0.0)
		if int(-y) % 3 == 0:
			b._light(Vector3(0, y, -0.4), Color(1.0, 0.4, 0.1) if f > 0.7 else Color(0.9, 0.75, 0.55), 2.5 if f > 0.7 else 1.8, 5.0, false)
		y -= 1.6
	return b


## A small iron lever set into the wall somewhere off to the side, easy to miss.
func _add_lever() -> void:
	lever = Node3D.new()
	var spots := [Vector3(-1.45, 2.2, -1.2), Vector3(1.5, 2.0, -1.2), Vector3(-1.5, 1.85, -1.0)]  # high: the pile hides the bottom
	lever.position = spots[_rng.randi() % spots.size()]
	add_child(lever)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 0.16, 0.03)
	pm.material = _mat(Color(0.2, 0.18, 0.15))
	plate.mesh = pm
	lever.add_child(plate)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.025, 0.16, 0.025)
	am.material = _mat(Color(0.35, 0.3, 0.22))
	arm.mesh = am
	arm.position = Vector3(0, 0.07, 0.03)
	arm.rotation.z = 0.5
	arm.name = "Arm"
	lever.add_child(arm)


func pull_lever() -> void:
	if lever == null or lever_pulled:
		return
	lever_pulled = true
	var arm: Node3D = lever.get_node("Arm")
	create_tween().tween_property(arm, "rotation:z", -0.6, 0.25).set_trans(Tween.TRANS_BACK)


## The Hidden Vault: a low treasure room heaped with gold, chests and a single brazier.
func _vault() -> void:
	var stone := Color(0.3, 0.25, 0.18)
	var gold := Color(0.95, 0.75, 0.25)
	_block_wall(Vector3(0, 0, -1.8), 5.0, 3.0, stone)
	_box(Vector3(0.3, 3.0, 4.0), Vector3(-1.9, 1.5, 0.2), stone.darkened(0.35))
	_box(Vector3(0.3, 3.0, 4.0), Vector3(1.9, 1.5, 0.2), stone.darkened(0.35))
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 2.9, 0.2), stone.darkened(0.5))
	# heaps of coin: piles of gold discs
	for pile in [Vector3(-1.2, 0, -1.3), Vector3(1.1, 0, -1.4), Vector3(-0.2, 0, -1.6)]:
		for k in 40:
			var a := _rng.randf() * TAU
			var r := _rng.randf() * 0.45 * (1.0 - k / 50.0)
			var coin := _cyl(0.05, 0.05, 0.015, pile + Vector3(cos(a) * r, 0.02 + k * 0.022, sin(a) * r * 0.6), gold, 8, Vector3(_rng.randf() * 0.6, 0, _rng.randf() * 0.6))
			coin.scale = Vector3.ONE
	# chests
	for c in [Vector3(-1.5, 0.25, -0.9), Vector3(1.55, 0.25, -0.7)]:
		_box(Vector3(0.55, 0.35, 0.35), c, Color(0.4, 0.22, 0.1))
		_box(Vector3(0.57, 0.06, 0.37), c + Vector3(0, 0.1, 0), gold.darkened(0.2))
		_box(Vector3(0.1, 0.1, 0.02), c + Vector3(0, 0.05, 0.18), gold)
	# goblets and a crown on a shelf
	_box(Vector3(1.4, 0.06, 0.25), Vector3(0, 1.95, -1.6), Color(0.35, 0.22, 0.12))
	for i in 4:
		_cyl(0.035, 0.02, 0.12, Vector3(-0.5 + i * 0.33, 2.04, -1.6), gold, 8)
	_cyl(0.09, 0.08, 0.08, Vector3(0.1, 2.02, -1.6), gold, 6)
	# one brazier lighting it all
	_cyl(0.18, 0.1, 0.3, Vector3(0.9, 1.5, -1.4), Color(0.2, 0.15, 0.1), 8)
	_box(Vector3(0.2, 0.12, 0.2), Vector3(0.9, 1.7, -1.4), Color(1.0, 0.55, 0.15), Vector3.ZERO, 3.0)
	_light(Vector3(0.9, 1.9, -1.1), Color(1.0, 0.7, 0.3), 2.8, 5.0)
	_light(Vector3(-1.0, 1.0, -0.8), Color(1.0, 0.8, 0.4), 1.0, 3.0)


## The Gilded Gullet: down a golden throat. Ribs of stacked coin close in toward a glow at
## the back, gold teeth along the top, a gold bell of a uvula, coin heaped on the tongue.
func _gullet() -> void:
	var gold := Color(0.95, 0.72, 0.22)
	var flesh := Color(0.5, 0.1, 0.12)
	_box(Vector3(6.0, 0.1, 5.0), Vector3(0, -0.05, 0.3), flesh)  # the tongue
	_box(Vector3(4.0, 3.4, 0.1), Vector3(0, 1.7, -2.0), flesh.darkened(0.6))
	_cyl(0.5, 0.5, 0.05, Vector3(0, 1.5, -1.9), Color(1.0, 0.85, 0.4), 16, Vector3(PI * 0.5, 0, 0), 3.0)  # the glow down the throat
	for k in 6:
		var z := -1.7 + k * 0.45
		var w := 1.0 + k * 0.3
		for side in [-1, 1]:
			for c in 15:
				var g := gold.darkened(0.12 * (c % 3))
				_cyl(0.17, 0.17, 0.05, Vector3(side * w + 0.02 * sin(c * 2.0), 0.03 + c * 0.21, z), g, 12)
		_box(Vector3(w * 2.0 + 0.3, 0.14, 0.18), Vector3(0, 3.1 - k * 0.04, z), gold.darkened(0.25))  # a rib of the arch
	for i in 11:
		_box(Vector3(0.22, 0.35, 0.18), Vector3(-2.5 + i * 0.5, 2.95, 1.0), Color(1.0, 0.85, 0.35), Vector3(0, 0, 0.1 * sin(i)))  # gold teeth
	_cyl(0.03, 0.03, 0.7, Vector3(0, 2.75, -0.7), flesh)
	_ball(0.2, Vector3(0, 2.3, -0.7), gold, 10)  # the uvula, a bell of gold
	for k in 60:  # coin heaped on the tongue
		var a := _rng.randf() * TAU
		var r := _rng.randf() * 1.6
		_cyl(0.07, 0.07, 0.015, Vector3(cos(a) * r, 0.02 + _rng.randf() * 0.1, -1.0 + sin(a) * r * 0.4), gold.lightened(_rng.randf() * 0.2), 8,
			Vector3(_rng.randf() * 0.8, 0, _rng.randf() * 0.8))
	_light(Vector3(0, 1.6, -1.4), Color(1.0, 0.8, 0.4), 3.0, 6.0)
	_light(Vector3(0, 2.4, 0.4), Color(1.0, 0.55, 0.3), 1.2, 5.0)


## The Giant's Table: you're the size of a crumb. A mountain of cheese, a teacup like a
## tower on its saucer, a fork standing like a tree, a candle as tall as a church, and far
## off in the dark the rest of an enormous kitchen.
func _giant_table() -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var china := Color(0.93, 0.92, 0.88)
	var cheese := Color(1.0, 0.82, 0.35)
	var steel := Color(0.75, 0.77, 0.82)
	_box(Vector3(8.0, 0.2, 6.0), Vector3(0, -0.1, 0.0), wood)
	for i in 9:
		_box(Vector3(8.0, 0.01, 0.03), Vector3(0, 0.005, -2.5 + i * 0.6), wood.darkened(0.35))  # plank seams
	_box(Vector3(14.0, 9.0, 0.2), Vector3(0, 3.5, -5.0), Color(0.12, 0.08, 0.06))  # the kitchen, far off
	_box(Vector3(2.0, 2.6, 0.05), Vector3(2.5, 4.2, -4.85), Color(0.35, 0.45, 0.7), Vector3.ZERO, 0.8)  # a window bigger than the world
	# the teacup, left
	_cyl(1.1, 1.1, 0.06, Vector3(-1.5, 0.03, -1.3), china, 24)
	_cyl(0.8, 0.55, 1.3, Vector3(-1.5, 0.7, -1.3), china, 20)
	_cyl(0.76, 0.76, 0.02, Vector3(-1.5, 1.35, -1.3), Color(0.45, 0.25, 0.1), 20)
	_box(Vector3(0.12, 0.6, 0.12), Vector3(-2.38, 0.75, -1.3), china)
	_box(Vector3(0.35, 0.12, 0.12), Vector3(-2.25, 1.0, -1.3), china)
	_box(Vector3(0.35, 0.12, 0.12), Vector3(-2.25, 0.5, -1.3), china)
	# the cheese, right: a stepped wedge, holed
	for i in 5:
		_box(Vector3(1.4 - i * 0.25, 0.28, 0.9), Vector3(1.5 + i * 0.12, 0.14 + i * 0.28, -1.1), cheese)
	for k in 8:
		_ball(0.07 + _rng.randf() * 0.05, Vector3(1.0 + _rng.randf() * 1.0, 0.15 + _rng.randf() * 1.0, -0.64), cheese.darkened(0.3), 6)
	# a fork standing like a tree, a knife lying across
	_box(Vector3(0.1, 2.6, 0.05), Vector3(-0.35, 1.3, -1.8), steel)
	for t in 4:
		_box(Vector3(0.04, 0.6, 0.04), Vector3(-0.53 + t * 0.12, 2.9, -1.8), steel)
	_box(Vector3(0.45, 0.08, 0.05), Vector3(-0.35, 2.6, -1.8), steel)
	_box(Vector3(3.0, 0.04, 0.3), Vector3(0.4, 0.04, -0.4), steel, Vector3(0, 0.35, 0))
	# the candle, a tower with a flame at the top
	_cyl(0.28, 0.28, 2.6, Vector3(0.75, 1.3, -2.2), Color(0.95, 0.9, 0.78), 14)
	_cyl(0.0, 0.1, 0.32, Vector3(0.75, 2.78, -2.2), Color(1.0, 0.7, 0.3), 8, Vector3.ZERO, 4.0)
	_light(Vector3(0.75, 2.6, -1.6), Color(1.0, 0.75, 0.4), 2.6, 7.0)
	for k in 30:  # crumbs, each the size of a boulder
		_box(Vector3.ONE * (0.04 + _rng.randf() * 0.08), Vector3(_rng.randf_range(-2.2, 2.2), 0.04, _rng.randf_range(-1.5, 0.6)),
			Color(0.8, 0.6, 0.35).darkened(_rng.randf() * 0.3), Vector3(_rng.randf(), _rng.randf(), _rng.randf()))
	_light(Vector3(0, 3.0, 1.0), Color(1.0, 0.9, 0.75), 1.0, 8.0, false)


## The Clockwork Orrery: inside a brass orrery the size of a cathedral, out among the
## stars. A burning sun on its spindle, brass rings tilted round it, gears turning on the
## walls. The two planets that swing through the play field are drawn by the props (they
## move): these are the rest of the machine.
func _orrery() -> void:
	var brass := Color(0.85, 0.65, 0.3)
	_box(Vector3(12.0, 9.0, 0.2), Vector3(0, 3.0, -4.0), Color(0.01, 0.01, 0.04))
	for k in 120:  # stars
		_box(Vector3.ONE * (0.02 + _rng.randf() * 0.03), Vector3(_rng.randf_range(-5.5, 5.5), _rng.randf_range(-0.5, 6.5), -3.85),
			Color(1.0, 0.95, 0.85), Vector3.ZERO, 2.0 + _rng.randf() * 3.0)
	_cyl(2.6, 2.6, 0.1, Vector3(0, -0.05, -0.6), brass.darkened(0.4), 32)  # the platform
	_cyl(0.06, 0.06, 2.6, Vector3(0, 1.3, -1.8), brass)  # the spindle
	_ball(0.35, Vector3(0, 2.6, -1.8), Color(1.0, 0.75, 0.3), 12)
	_cyl(0.36, 0.36, 0.02, Vector3(0, 2.6, -1.8), Color(1.0, 0.85, 0.5), 16, Vector3.ZERO, 5.0)
	_light(Vector3(0, 2.6, -1.4), Color(1.0, 0.75, 0.35), 3.5, 8.0)
	for ring in 3:  # the great rings, each a hoop of brass segments, tilted
		var r := 1.0 + ring * 0.55
		var tilt := 0.3 + ring * 0.35
		for s in 36:
			var a := s * TAU / 36.0
			var p := Vector3(cos(a) * r, sin(a) * r * cos(tilt), sin(a) * r * sin(tilt))
			_box(Vector3(0.18, 0.05, 0.05), Vector3(0, 2.6, -1.8) + p, brass.darkened(0.1 * ring), Vector3(0, 0, a + PI * 0.5))
	for side in [-1, 1]:  # gears on the walls
		for g in 3:
			var c := Vector3(side * 2.6, 0.7 + g * 1.1, -1.2 - g * 0.4)
			_cyl(0.42 - g * 0.08, 0.42 - g * 0.08, 0.08, c, brass.darkened(0.2), 16, Vector3(PI * 0.5, 0, 0))
			for t in 12:
				var a := t * TAU / 12.0
				_box(Vector3(0.1, 0.1, 0.06), c + Vector3(cos(a), sin(a), 0) * (0.46 - g * 0.08), brass.darkened(0.3), Vector3(0, 0, a))
	_light(Vector3(0, 1.5, 1.0), Color(0.6, 0.65, 1.0), 0.8, 8.0, false)


## The Ink Margin: in the margins of the codex. Cream page underfoot and behind, lines of
## text running across it, giant letters loose in the air, an inkwell like a well, a quill
## like a mast, and blots where the mistakes went.
func _margin() -> void:
	var cream := Color(0.93, 0.89, 0.78)
	var ink := Color(0.04, 0.04, 0.06)
	_box(Vector3(8.0, 0.1, 6.0), Vector3(0, -0.05, 0.2), cream)
	_box(Vector3(6.0, 4.0, 0.1), Vector3(0, 2.0, -1.9), cream)
	for side in [-1, 1]:
		_box(Vector3(0.1, 4.0, 4.0), Vector3(side * 2.4, 2.0, 0.0), cream.darkened(0.08), Vector3(0, side * 0.35, 0))
	for row in 12:  # lines of text: words of random length
		var x := -2.6
		while x < 2.6:
			var w := 0.12 + _rng.randf() * 0.4
			_box(Vector3(w, 0.05, 0.02), Vector3(x + w * 0.5, 0.45 + row * 0.27, -1.84), ink)
			x += w + 0.08
	# giant letters loose in the air, built of strokes
	var letters := [
		[Vector3(-1.4, 2.4, -0.9), [[Vector3(0, 0, 0), Vector3(0.08, 0.7, 0.06)], [Vector3(0.22, 0.32, 0), Vector3(0.4, 0.08, 0.06)], [Vector3(0.42, 0, 0), Vector3(0.08, 0.7, 0.06)]]],  # H
		[Vector3(1.2, 2.2, -1.0), [[Vector3(0, 0, 0), Vector3(0.08, 0.7, 0.06)], [Vector3(0.2, 0.31, 0), Vector3(0.4, 0.08, 0.06)], [Vector3(0.2, -0.31, 0), Vector3(0.4, 0.08, 0.06)], [Vector3(0.2, 0, 0), Vector3(0.3, 0.08, 0.06)]]],  # E
		[Vector3(0.0, 2.9, -1.3), [[Vector3(0, 0.25, 0), Vector3(0.4, 0.08, 0.06)], [Vector3(0.2, 0.1, 0), Vector3(0.08, 0.3, 0.06)], [Vector3(0.0, -0.1, 0), Vector3(0.08, 0.15, 0.06)], [Vector3(0.0, -0.33, 0), Vector3(0.09, 0.09, 0.06)]]],  # ?
	]
	for l in letters:
		var base: Vector3 = l[0]
		for stroke in l[1]:
			_box(stroke[1], base + stroke[0], ink, Vector3(0, 0, _rng.randf_range(-0.2, 0.2)))
	_cyl(0.45, 0.55, 0.7, Vector3(-1.6, 0.35, -1.2), ink, 16)  # the inkwell
	_cyl(0.3, 0.3, 0.02, Vector3(-1.6, 0.71, -1.2), Color(0.1, 0.1, 0.18), 16, Vector3.ZERO, 0.5)
	_box(Vector3(0.05, 3.0, 0.05), Vector3(-1.3, 1.6, -1.1), Color(0.9, 0.88, 0.82), Vector3(0, 0, -0.35))  # the quill
	for f in 8:
		_box(Vector3(0.35 - f * 0.03, 0.06, 0.02), Vector3(-1.0 - f * 0.05, 2.0 + f * 0.17, -1.1), Color(0.95, 0.95, 0.9), Vector3(0, 0, -0.35 + 0.2))
	for k in 6:  # blots
		_cyl(0.15 + _rng.randf() * 0.3, 0.15 + _rng.randf() * 0.3, 0.01, Vector3(_rng.randf_range(-2.0, 2.0), 0.01, _rng.randf_range(-1.4, 0.4)), ink, 10)
	_light(Vector3(0, 2.5, 0.5), Color(1.0, 0.98, 0.92), 1.5, 8.0, false)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for f in _flicker:
		var l: OmniLight3D = f[0]
		l.light_energy = f[1] * (0.8 + 0.12 * sin(t * f[2] + f[3]) + 0.08 * sin(t * f[2] * 2.7 + f[3] * 3.0))
	for f in _flames:
		var m: Node3D = f[0]
		var base: Vector3 = f[1]
		var lick := 0.75 + 0.2 * sin(t * f[2] + f[3]) + 0.12 * sin(t * f[2] * 2.3 + f[3] * 1.7)
		m.scale = Vector3(base.x * (1.1 - 0.2 * lick), base.y * lick, base.z)
		m.rotation.z = 0.12 * sin(t * f[2] * 0.6 + f[3])
	var dt := get_process_delta_time()
	for sp in _spinners:
		(sp[0] as Node3D).rotation.y += float(sp[1]) * dt
	for r in _risers:
		var n: Node3D = r[0]
		n.position.y += float(r[1]) * dt
		n.position.x += sin(t * 1.3 + float(r[4])) * 0.1 * dt
		if n.position.y > float(r[3]):
			n.position.y = float(r[2])


## A tongue of fire: a cone that licks and sways (see _process).
func _flame(pos: Vector3, h: float, r: float, col: Color, glow: float) -> void:
	var m := _cyl(0.0, r, h, pos + Vector3(0, h * 0.5, 0), col, 6, Vector3.ZERO, glow)
	var root := Node3D.new()  # (the cone scales from its foot, not its middle)
	root.position = pos
	m.get_parent().remove_child(m)
	root.add_child(m)
	m.position = Vector3(0, h * 0.5, 0)
	add_child(root)
	_flames.append([root, Vector3.ONE, _rng.randf_range(5.0, 9.0), _rng.randf_range(0.0, TAU)])


# --- building blocks --------------------------------------------------------------

func _mat(col: Color, rough: float = 1.0, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, glow: float = 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(col, 1.0, glow)
	return _place(bm, pos, rot)


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, sides: int = 8, rot: Vector3 = Vector3.ZERO, glow: float = 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	cm.material = _mat(col, 1.0, glow)
	return _place(cm, pos, rot)


func _ball(r: float, pos: Vector3, col: Color, segs: int = 6) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(2, int(segs / 2.0))
	sm.material = _mat(col)
	return _place(sm, pos, Vector3.ZERO)


func _place(mesh: Mesh, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _light(pos: Vector3, col: Color, energy: float, rng: float, flicker: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	if flicker:
		_flicker.append([l, energy, _rng.randf_range(6.0, 11.0), _rng.randf() * TAU])
	return l


func _stone(base: Color) -> Color:
	var v := _rng.randf_range(-0.04, 0.04)
	return Color(base.r + v, base.g + v, base.b + v * 0.8)


## A wall of staggered blocks facing +z, centred at x, spanning width x height.
func _block_wall(center: Vector3, width: float, height: float, base: Color, bw: float = 0.5, bh: float = 0.28) -> void:
	_box(Vector3(width, height, 0.1), center + Vector3(0, height * 0.5, -0.06), base.darkened(0.5))  # mortar behind
	var rows := int(height / bh)
	for r in rows:
		var off := (bw * 0.5) if r % 2 == 1 else 0.0
		var x := -width * 0.5 - off
		while x < width * 0.5:
			var w := minf(bw, width * 0.5 - x)
			var lx := maxf(x, -width * 0.5)
			var ww := minf(x + w, width * 0.5) - lx
			if ww > 0.05:
				_box(Vector3(ww - 0.03, bh - 0.03, 0.16 + _rng.randf() * 0.04), center + Vector3(lx + ww * 0.5, r * bh + bh * 0.5, 0), _stone(base))
			x += bw


## A wall torch: bracket, stick, flame and a flickering light.
func _torch(pos: Vector3, facing_z: float = 1.0) -> void:
	_box(Vector3(0.06, 0.12, 0.08), pos + Vector3(0, -0.12, 0), Color(0.15, 0.13, 0.12))
	_cyl(0.025, 0.02, 0.3, pos, Color(0.3, 0.2, 0.1), 5, Vector3(0.3 * facing_z, 0, 0))
	_box(Vector3(0.07, 0.12, 0.07), pos + Vector3(0, 0.18, 0.05 * facing_z), Color(1.0, 0.55, 0.15), Vector3.ZERO, 3.0)
	_light(pos + Vector3(0, 0.25, 0.2 * facing_z), Color(1.0, 0.6, 0.3), 2.2, 4.0)


func _candle(pos: Vector3, h: float = 0.12) -> void:
	_cyl(0.02, 0.022, h, pos + Vector3(0, h * 0.5, 0), Color(0.85, 0.8, 0.65), 6)
	_box(Vector3(0.015, 0.03, 0.015), pos + Vector3(0, h + 0.02, 0), Color(1.0, 0.75, 0.3), Vector3.ZERO, 4.0)


# --- settings -----------------------------------------------------------------------

## A cramped dungeon cell: block walls, iron bars, hanging chains, one torch.
func _cell() -> void:
	var stone := Color(0.27, 0.25, 0.23)
	_block_wall(Vector3(0, 0, -1.5), 5.0, 3.4, stone)
	_box(Vector3(0.3, 3.4, 4.0), Vector3(-1.9, 1.7, 0.4), stone.darkened(0.3))
	_box(Vector3(0.3, 3.4, 4.0), Vector3(1.9, 1.7, 0.4), stone.darkened(0.3))
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 3.3, 0.4), stone.darkened(0.45))
	_box(Vector3(5.0, 0.1, 4.0), Vector3(0, -0.05, 0.4), Color(0.25, 0.2, 0.12))
	# iron bars on the left, a crossbar top and bottom
	for i in 6:
		_cyl(0.025, 0.025, 3.2, Vector3(-1.7 + i * 0.16, 1.6, -0.8), Color(0.2, 0.2, 0.22), 6)
	_box(Vector3(1.0, 0.06, 0.06), Vector3(-1.3, 2.6, -0.8), Color(0.18, 0.18, 0.2))
	# chains hanging from the ceiling
	for c in [Vector3(1.25, 0, -1.1), Vector3(1.45, 0, -1.2)]:
		for k in 12:
			_box(Vector3(0.04, 0.09, 0.02), Vector3(c.x, 3.1 - k * 0.1, c.z), Color(0.22, 0.21, 0.2), Vector3(0, k * PI / 2.0, 0))
	_box(Vector3(0.25, 0.06, 0.12), Vector3(1.0, 2.4, -1.32), Color(0.18, 0.16, 0.14))  # shelf
	_torch(Vector3(0.95, 2.1, -1.35))
	_light(Vector3(-0.6, 2.8, 0.6), Color(0.6, 0.65, 0.8), 0.6, 4.0, false)  # cold light from a grate above


## A narrow vaulted corridor running away into the dark, torches on every other rib.
func _corridor() -> void:
	var stone := Color(0.25, 0.24, 0.22)
	var depth := 14.0
	_box(Vector3(0.3, 3.0, depth), Vector3(-1.25, 1.5, -depth * 0.5 + 0.5), stone.darkened(0.25))
	_box(Vector3(0.3, 3.0, depth), Vector3(1.25, 1.5, -depth * 0.5 + 0.5), stone.darkened(0.25))
	_box(Vector3(2.8, 0.3, depth), Vector3(0, 2.9, -depth * 0.5 + 0.5), stone.darkened(0.4))
	_box(Vector3(2.8, 0.1, depth), Vector3(0, -0.05, -depth * 0.5 + 0.5), stone.darkened(0.2))
	var z := -0.8
	var k := 0
	while z > -depth:
		for side in [-1.0, 1.0]:
			_box(Vector3(0.28, 2.8, 0.3), Vector3(1.0 * side, 1.4, z), _stone(stone))
		_box(Vector3(2.3, 0.3, 0.32), Vector3(0, 2.6, z), _stone(stone))
		for side in [-1.0, 1.0]:
			_box(Vector3(0.3, 0.3, 0.32), Vector3(0.82 * side, 2.38, z), _stone(stone), Vector3(0, 0, 0.785 * side))
		if k % 2 == 0:
			_torch(Vector3(-0.98 if k % 4 == 0 else 0.98, 1.8, z + 0.25))
		z -= 1.6
		k += 1


## Catacombs: walls of niches stacked with skulls and bones, candles on the ledges.
func _catacombs() -> void:
	var stone := Color(0.3, 0.27, 0.22)
	var bone := Color(0.78, 0.72, 0.6)
	_box(Vector3(5.0, 3.0, 0.3), Vector3(0, 1.5, -1.6), stone.darkened(0.2))
	_box(Vector3(0.3, 3.0, 4.0), Vector3(-1.8, 1.5, 0.3), stone.darkened(0.35))
	_box(Vector3(0.3, 3.0, 4.0), Vector3(1.8, 1.5, 0.3), stone.darkened(0.35))
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 2.7, 0.3), stone.darkened(0.45))
	for row in 3:
		for col in 6:
			var c := Vector3(-1.5 + col * 0.6, 0.9 + row * 0.62, -1.42)
			_box(Vector3(0.48, 0.42, 0.12), c + Vector3(0, 0, -0.02), Color(0.04, 0.035, 0.03))  # the niche
			_box(Vector3(0.52, 0.05, 0.2), c + Vector3(0, -0.23, 0.04), _stone(stone))  # ledge
			if _rng.randf() < 0.75:
				var sk := c + Vector3(_rng.randf_range(-0.1, 0.1), -0.1, 0.06)
				_ball(0.08, sk, bone)
				_box(Vector3(0.025, 0.025, 0.01), sk + Vector3(-0.03, 0.01, 0.075), Color(0.05, 0.04, 0.03))
				_box(Vector3(0.025, 0.025, 0.01), sk + Vector3(0.03, 0.01, 0.075), Color(0.05, 0.04, 0.03))
			for b in _rng.randi_range(0, 2):
				_cyl(0.012, 0.012, 0.3, c + Vector3(_rng.randf_range(-0.12, 0.12), -0.18, 0.02), bone.darkened(0.15), 4, Vector3(0, _rng.randf() * PI, PI / 2))
			if _rng.randf() < 0.3:
				_candle(c + Vector3(0.18, -0.2, 0.1))
	_light(Vector3(-0.7, 1.5, -1.0), Color(1.0, 0.75, 0.4), 1.4, 2.5)
	_light(Vector3(0.9, 2.0, -1.0), Color(1.0, 0.75, 0.4), 1.2, 2.5)


## A crypt chapel: pillars, a tall stained-glass window throwing coloured light, candles.
func _crypt() -> void:
	var stone := Color(0.3, 0.3, 0.33)
	_box(Vector3(6.0, 4.0, 0.3), Vector3(0, 2.0, -2.6), stone.darkened(0.3))
	# two lancet windows flanking the head: lead frames and coloured panes, glowing
	var panes := [Color(0.8, 0.15, 0.15), Color(0.15, 0.25, 0.8), Color(0.9, 0.7, 0.2), Color(0.2, 0.6, 0.3)]
	for wx in [-0.95, 0.95]:
		for r in 5:
			for c in 2:
				var col: Color = panes[(r * 2 + c + int(wx > 0.0)) % panes.size()]
				_box(Vector3(0.2, 0.24, 0.04), Vector3(wx - 0.11 + c * 0.22, 1.25 + r * 0.27, -2.42), col, Vector3.ZERO, 1.6)
		_box(Vector3(0.5, 1.45, 0.03), Vector3(wx, 1.8, -2.45), Color(0.05, 0.05, 0.05))
		_cyl(0.0, 0.26, 0.3, Vector3(wx, 2.65, -2.44), Color(0.05, 0.05, 0.05), 3, Vector3(PI / 2, 0, 0))  # pointed arch top
	var shaft := SpotLight3D.new()
	shaft.position = Vector3(0, 3.0, -2.2)
	shaft.rotation = Vector3(-0.6, 0, 0)
	shaft.light_color = Color(0.7, 0.6, 1.0)
	shaft.light_energy = 4.0
	shaft.spot_range = 6.0
	shaft.spot_angle = 25.0
	add_child(shaft)
	for side in [-1.0, 1.0]:
		for z in [-0.6, -2.0]:
			_cyl(0.22, 0.24, 4.0, Vector3(1.4 * side, 2.0, z), _stone(stone), 8)
			_box(Vector3(0.6, 0.15, 0.6), Vector3(1.4 * side, 3.9, z), stone)
			_box(Vector3(0.6, 0.15, 0.6), Vector3(1.4 * side, 0.08, z), stone)
	_box(Vector3(1.2, 0.5, 0.5), Vector3(0.6, 0.25, -1.9), Color(0.35, 0.33, 0.3))  # sarcophagus
	_box(Vector3(1.3, 0.08, 0.6), Vector3(0.6, 0.54, -1.9), Color(0.4, 0.38, 0.35))
	for i in 5:
		_candle(Vector3(-1.0 + i * 0.12, 1.2 + (i % 2) * 0.08, -1.6), 0.15)
	_box(Vector3(0.7, 0.05, 0.2), Vector3(-0.76, 1.18, -1.6), Color(0.2, 0.16, 0.1))
	_light(Vector3(-0.8, 1.5, -1.3), Color(1.0, 0.75, 0.4), 1.5, 3.0)


## A cistern tunnel: wet arched walls, black water below, pipes, a lit grate far back.
func _cistern() -> void:
	var stone := Color(0.18, 0.22, 0.2)
	var depth := 8.0
	for side in [-1.0, 1.0]:
		_box(Vector3(0.3, 3.0, depth), Vector3(1.5 * side, 1.5, -depth * 0.5 + 0.5), stone)
		for k in 3:
			_cyl(0.07, 0.07, depth, Vector3(1.3 * side, 0.9 + k * 0.5, -depth * 0.5 + 0.5), Color(0.2, 0.18, 0.15), 6, Vector3(PI / 2, 0, 0))
	var z := -0.5
	while z > -depth:
		for i in 7:
			var a := PI * i / 6.0
			_box(Vector3(0.45, 0.25, 0.3), Vector3(cos(a) * 1.4, 2.0 + sin(a) * 0.9, z), _stone(stone), Vector3(0, 0, a + PI / 2))
		z -= 1.8
	var water := BoxMesh.new()
	water.size = Vector3(3.0, 0.05, depth)
	water.material = _mat(Color(0.02, 0.05, 0.06), 0.05, 0.0, 0.6)
	_place(water, Vector3(0, 0.3, -depth * 0.5 + 0.5), Vector3.ZERO)
	# the grate at the end, lit from behind
	for i in 7:
		_cyl(0.02, 0.02, 1.4, Vector3(-0.6 + i * 0.2, 1.3, -depth + 0.8), Color(0.12, 0.12, 0.12), 5)
	_light(Vector3(0, 1.4, -depth + 0.3), Color(0.5, 0.9, 0.7), 3.0, 4.0, false)
	_torch(Vector3(-1.32, 1.9, -1.5))


## Home: a timber-framed room, a hearth with a fire going, a window with the night behind it,
## a table with a candle, a bookshelf, a rug. Warm and low. Nothing here hits back.
func _homestead() -> void:
	var plaster := Color(0.6, 0.5, 0.38)
	var timber := Color(0.32, 0.2, 0.1)
	_box(Vector3(5.0, 3.2, 0.2), Vector3(0, 1.6, -1.7), plaster)
	for x in [-1.9, -0.95, 0.0, 0.95, 1.9]:
		_box(Vector3(0.14, 3.2, 0.06), Vector3(x, 1.6, -1.58), timber)  # posts
	_box(Vector3(5.0, 0.14, 0.06), Vector3(0, 2.3, -1.58), timber)  # a beam
	_box(Vector3(5.0, 0.14, 0.06), Vector3(0, 0.7, -1.58), timber)
	_box(Vector3(0.3, 3.2, 4.0), Vector3(-1.9, 1.6, 0.3), plaster.darkened(0.3))
	_box(Vector3(0.3, 3.2, 4.0), Vector3(1.9, 1.6, 0.3), plaster.darkened(0.3))
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 3.2, 0.3), timber.darkened(0.3))
	for i in 6:
		_box(Vector3(0.12, 0.12, 4.0), Vector3(-1.5 + i * 0.6, 3.05, 0.3), timber)  # rafters
	_box(Vector3(5.0, 0.1, 4.0), Vector3(0, -0.05, 0.3), Color(0.4, 0.26, 0.14))  # floorboards
	_box(Vector3(2.4, 0.02, 1.6), Vector3(0, 0.01, -0.3), Color(0.62, 0.45, 0.2))  # rug: a border...
	_box(Vector3(2.1, 0.022, 1.3), Vector3(0, 0.012, -0.3), Color(0.5, 0.15, 0.12))  # ...and its red field
	_box(Vector3(1.2, 0.024, 0.5), Vector3(0, 0.013, -0.3), Color(0.38, 0.1, 0.1))
	_box(Vector3(5.0, 0.6, 0.04), Vector3(0, 0.3, -1.57), Color(0.26, 0.16, 0.08))  # a wainscot of dark boards along the wall
	_box(Vector3(5.0, 0.04, 0.06), Vector3(0, 0.6, -1.56), timber)
	# an armchair, turned to the fire
	var seat := Color(0.42, 0.14, 0.1)
	_box(Vector3(0.5, 0.12, 0.45), Vector3(1.55, 0.35, -0.55), seat, Vector3(0, -0.6, 0))
	_box(Vector3(0.5, 0.55, 0.1), Vector3(1.7, 0.62, -0.38), seat.darkened(0.15), Vector3(-0.15, -0.6, 0))
	for arm in [-1, 1]:
		_box(Vector3(0.08, 0.16, 0.45), Vector3(1.55 + arm * 0.2, 0.47, -0.55 + arm * 0.12), seat.darkened(0.1), Vector3(0, -0.6, 0))
	_box(Vector3(0.5, 0.3, 0.45), Vector3(1.55, 0.15, -0.55), timber.darkened(0.2), Vector3(0, -0.6, 0))
	# a lantern hung from the rafters, warm pool of light under it
	_box(Vector3(0.01, 0.4, 0.01), Vector3(-0.35, 2.85, -0.7), Color(0.15, 0.13, 0.1))
	_box(Vector3(0.14, 0.18, 0.14), Vector3(-0.35, 2.56, -0.7), Color(0.18, 0.16, 0.14))
	_box(Vector3(0.1, 0.13, 0.1), Vector3(-0.35, 2.56, -0.7), Color(1.0, 0.75, 0.4), Vector3.ZERO, 3.0)
	_light(Vector3(-0.35, 2.45, -0.7), Color(1.0, 0.72, 0.4), 1.6, 3.5)
	# the hearth, right, with a fire in it
	_block_wall(Vector3(1.2, 0, -1.45), 1.3, 1.5, Color(0.35, 0.3, 0.26), 0.3, 0.15)
	_box(Vector3(1.3, 0.8, 0.5), Vector3(1.2, 0.4, -1.2), Color(0.3, 0.27, 0.24))  # a raised hearthstone
	_box(Vector3(0.9, 0.6, 0.3), Vector3(1.2, 1.1, -1.35), Color(0.03, 0.02, 0.02))
	_box(Vector3(0.86, 0.45, 0.02), Vector3(1.2, 1.05, -1.48), Color(0.35, 0.1, 0.03), Vector3.ZERO, 0.6)  # the soot-black back, lit from below
	# a fire: andirons, logs, a bed of embers and flames that lick and sway
	for ax in [0.92, 1.48]:
		_box(Vector3(0.03, 0.16, 0.25), Vector3(ax, 0.85, -1.13), Color(0.12, 0.11, 0.1))
	for lg in [[Vector3(1.2, 0.85, -1.13), Vector3(0, PI / 2 + 0.15, PI / 2)], [Vector3(1.15, 0.92, -1.15), Vector3(0, PI / 2 - 0.3, PI / 2)], [Vector3(1.28, 0.91, -1.09), Vector3(0, PI / 2 + 0.6, PI / 2)]]:
		_cyl(0.05, 0.055, 0.62, lg[0], Color(0.22, 0.13, 0.07), 7, lg[1])
	for i in 9:
		_box(Vector3(0.07, 0.04, 0.07), Vector3(0.95 + i * 0.065, 0.79, -1.10 + (i % 3) * 0.03), Color(1.0, 0.35 + (i % 3) * 0.12, 0.05), Vector3(0, i, 0), 3.0)
	for i in 7:
		var fx := 0.98 + i * 0.075
		var h := 0.22 + 0.18 * sin(i * 1.3 + 0.4) * sin(i * 0.7) + (0.12 if i in [2, 3, 4] else 0.0)
		_flame(Vector3(fx, 0.87, -1.12), h, 0.07, Color(1.0, 0.42, 0.08), 3.5)
		_flame(Vector3(fx + 0.02, 0.87, -1.08), h * 0.6, 0.04, Color(1.0, 0.82, 0.3), 5.0)
	_box(Vector3(1.4, 0.12, 0.4), Vector3(1.2, 1.55, -1.35), timber)  # mantel
	_candle(Vector3(0.8, 1.61, -1.35), 0.14)
	_light(Vector3(1.2, 1.2, -0.9), Color(1.0, 0.55, 0.22), 4.2, 6.0)  # the fire lights the room
	# a window, left, with the night sky, a moon and a few stars. The glass sits a little in
	# front of the wall (sharing the wall's plane, the two flickered: the window would turn
	# the colour of the plaster), and it's dark with no glow of its own, so the grade always
	# reads it as night.
	_box(Vector3(0.9, 1.0, 0.02), Vector3(-1.2, 1.7, -1.585), Color(0.01, 0.012, 0.03))
	_box(Vector3(0.05, 1.0, 0.03), Vector3(-1.2, 1.7, -1.56), timber)
	_box(Vector3(0.9, 0.05, 0.03), Vector3(-1.2, 1.7, -1.56), timber)
	_box(Vector3(0.96, 0.05, 0.03), Vector3(-1.2, 2.2, -1.56), timber)
	_box(Vector3(1.0, 0.08, 0.1), Vector3(-1.2, 1.17, -1.55), timber)  # sill
	_ball(0.09, Vector3(-1.4, 1.95, -1.57), Color(0.95, 0.95, 0.85))
	for st in [Vector3(-1.05, 2.05, -1.572), Vector3(-0.9, 1.85, -1.572), Vector3(-1.5, 1.5, -1.572), Vector3(-1.0, 1.42, -1.572), Vector3(-1.3, 2.1, -1.572)]:
		_box(Vector3(0.015, 0.015, 0.005), st, Color(0.9, 0.92, 1.0), Vector3.ZERO, 3.0)
	_light(Vector3(-1.2, 1.7, -1.2), Color(0.6, 0.7, 1.0), 0.8, 3.0, false)
	# a bookshelf in the corner and a table
	_box(Vector3(0.6, 1.6, 0.25), Vector3(-1.65, 0.8, -1.4), timber.darkened(0.2))
	for r in 3:
		for k in 5:
			_box(Vector3(0.08, 0.22, 0.18), Vector3(-1.86 + k * 0.1, 0.35 + r * 0.45, -1.38), [Color(0.5, 0.15, 0.1), Color(0.15, 0.3, 0.45), Color(0.6, 0.5, 0.25)][(k + r) % 3])
	_box(Vector3(1.0, 0.06, 0.5), Vector3(0.1, 0.72, -1.1), timber.lightened(0.15))
	for lx in [-0.35, 0.55]:
		_box(Vector3(0.06, 0.7, 0.06), Vector3(lx, 0.36, -1.1), timber)
	_candle(Vector3(0.3, 0.75, -1.05), 0.1)
	_light(Vector3(0.3, 1.0, -0.8), Color(1.0, 0.8, 0.5), 1.0, 2.5)
	# herbs drying from the rafters, pots on the mantel, a basket of firewood by the hearth
	for i in 5:
		var hx := -1.4 + i * 0.6
		_box(Vector3(0.01, 0.25, 0.01), Vector3(hx, 2.88, -0.6), Color(0.3, 0.25, 0.15))
		for k in 4:
			_box(Vector3(0.05, 0.16, 0.05), Vector3(hx + (k - 1.5) * 0.04, 2.68, -0.6), [Color(0.35, 0.5, 0.2), Color(0.5, 0.45, 0.2), Color(0.45, 0.25, 0.35)][i % 3], Vector3(0, 0, (k - 1.5) * 0.2))
	for k in 3:
		_cyl(0.06 + k * 0.01, 0.05, 0.12 + k * 0.03, Vector3(1.45 + k * 0.13, 1.67 + k * 0.015, -1.35), [Color(0.6, 0.35, 0.2), Color(0.3, 0.4, 0.5), Color(0.75, 0.7, 0.6)][k], 8)
	_cyl(0.25, 0.2, 0.3, Vector3(1.95, 0.15, -1.0), Color(0.5, 0.35, 0.18), 10)
	for k in 5:
		_cyl(0.04, 0.04, 0.45, Vector3(1.85 + k * 0.05, 0.38, -1.0 + (k % 2) * 0.05), Color(0.35, 0.22, 0.12), 6, Vector3(PI * 0.5, 0, 0.3 * k))
	_light(Vector3(1.2, 1.0, -0.7), Color(1.0, 0.45, 0.15), 1.6, 3.0)  # the embers' low glow (it flickers)


## An ossuary: a long hall faced entirely in bone. Stacked femurs, rows of skulls, a few
## candles in eye sockets.
func _ossuary() -> void:
	var bone := Color(0.72, 0.66, 0.52)
	var dark := Color(0.12, 0.1, 0.08)
	_box(Vector3(5.0, 3.2, 0.3), Vector3(0, 1.6, -1.7), dark)
	_box(Vector3(0.3, 3.2, 4.0), Vector3(-1.9, 1.6, 0.3), dark)
	_box(Vector3(0.3, 3.2, 4.0), Vector3(1.9, 1.6, 0.3), dark)
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 3.1, 0.3), dark.darkened(0.3))
	for row in 9:
		var y := 0.25 + row * 0.32
		if row % 3 == 2:
			for col in 12:
				var sk := Vector3(-1.75 + col * 0.32, y, -1.5)
				_ball(0.1, sk, bone.lightened(_rng.randf_range(-0.05, 0.1)))
				_box(Vector3(0.03, 0.03, 0.01), sk + Vector3(-0.035, 0.01, 0.095), Color(0.03, 0.02, 0.02))
				_box(Vector3(0.03, 0.03, 0.01), sk + Vector3(0.035, 0.01, 0.095), Color(0.03, 0.02, 0.02))
				if col % 4 == 1:
					_candle(sk + Vector3(0, 0.1, 0.02), 0.08)
		else:
			for col in 16:
				_cyl(0.035, 0.035, 0.5, Vector3(-1.85 + col * 0.24, y, -1.5), bone.darkened(_rng.randf_range(0.0, 0.2)), 5, Vector3(PI / 2, 0, 0))
				_ball(0.045, Vector3(-1.85 + col * 0.24, y, -1.25), bone)
	_light(Vector3(-0.8, 1.6, -1.0), Color(1.0, 0.8, 0.5), 1.4, 3.0)
	_light(Vector3(0.9, 1.0, -1.0), Color(1.0, 0.8, 0.5), 1.4, 3.0)


## The star chamber: an observatory open to the night sky. A ring of pillars, a brass
## orrery, stars, and a cold light from above.
func _star_chamber() -> void:
	var stone := Color(0.2, 0.22, 0.3)
	var brass := Color(0.7, 0.55, 0.25)
	_box(Vector3(6.0, 0.1, 6.0), Vector3(0, -0.05, 0), stone.darkened(0.2))
	for i in 8:
		var a := i * TAU / 8.0 + 0.2
		if absf(a - PI * 1.5) < 0.9:
			continue  # the gap the camera looks through
		_cyl(0.14, 0.16, 3.2, Vector3(cos(a) * 2.4, 1.6, sin(a) * 2.4 - 0.6), stone, 6)
		_box(Vector3(0.4, 0.12, 0.4), Vector3(cos(a) * 2.4, 3.2, sin(a) * 2.4 - 0.6), stone.lightened(0.1))
	# stars, far back, and a moon
	_rng.seed = 11
	for k in 60:
		var p := Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.5, 7.0), -9.0 + _rng.randf_range(-2.0, 0.0))
		_box(Vector3(0.05, 0.05, 0.05), p, Color(0.9, 0.95, 1.0), Vector3.ZERO, _rng.randf_range(2.0, 5.0))
	_ball(0.5, Vector3(2.5, 4.5, -8.0), Color(0.9, 0.9, 0.8))
	# the orrery: a brass stand and a few rings with little planets
	_cyl(0.1, 0.2, 0.9, Vector3(-1.3, 0.45, -1.3), brass.darkened(0.3), 8)
	for k in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.25 + k * 0.12
		ring.outer_radius = 0.27 + k * 0.12
		ring.material = _mat(brass)
		_place(ring, Vector3(-1.3, 1.1, -1.3), Vector3(0.4 * k, 0.3 * k, 0.2))
		_ball(0.04, Vector3(-1.3 + (0.27 + k * 0.12), 1.1, -1.3), [Color(0.8, 0.3, 0.2), Color(0.3, 0.5, 0.9), Color(0.9, 0.8, 0.5)][k])
	_ball(0.08, Vector3(-1.3, 1.1, -1.3), Color(1.0, 0.8, 0.3))
	_light(Vector3(0, 3.5, -0.5), Color(0.6, 0.7, 1.0), 1.6, 6.0, false)
	_light(Vector3(-1.3, 1.3, -1.0), Color(1.0, 0.85, 0.5), 0.8, 2.5)


## A forge: brick wall, glowing hearth, anvil, a rack of weapons, everything lit orange.
func _forge() -> void:
	var brick := Color(0.35, 0.18, 0.12)
	_block_wall(Vector3(0, 0, -1.7), 5.0, 3.4, brick, 0.32, 0.14)
	_box(Vector3(0.3, 3.4, 4.0), Vector3(-1.9, 1.7, 0.3), brick.darkened(0.4))
	_box(Vector3(0.3, 3.4, 4.0), Vector3(1.9, 1.7, 0.3), brick.darkened(0.4))
	_box(Vector3(5.0, 0.3, 4.0), Vector3(0, 3.3, 0.3), Color(0.1, 0.08, 0.07))
	# the hearth: a dark mouth full of coals, raised high on a brick plinth (the pile hides
	# the bottom of the screen)
	_box(Vector3(1.4, 0.75, 0.3), Vector3(-0.6, 1.95, -1.55), Color(0.03, 0.02, 0.02))
	for i in 9:
		_box(Vector3(0.14, 0.08, 0.12), Vector3(-1.1 + i * 0.12, 1.62 + (i % 3) * 0.03, -1.45), Color(1.0, 0.4 + (i % 2) * 0.2, 0.1), Vector3(0, i, 0), 4.0)
	_box(Vector3(1.6, 0.2, 0.4), Vector3(-0.6, 2.42, -1.5), brick.darkened(0.2))  # mantel
	_box(Vector3(1.6, 0.12, 0.4), Vector3(-0.6, 1.52, -1.5), brick.darkened(0.2))  # hearthstone
	_light(Vector3(-0.6, 1.9, -1.0), Color(1.0, 0.45, 0.15), 4.0, 5.0)
	# an anvil and a weapon rack
	_box(Vector3(0.5, 0.18, 0.2), Vector3(1.1, 0.95, -1.2), Color(0.15, 0.15, 0.17))
	_box(Vector3(0.18, 0.4, 0.16), Vector3(1.1, 0.7, -1.2), Color(0.13, 0.13, 0.15))
	_box(Vector3(0.9, 0.06, 0.08), Vector3(1.2, 2.4, -1.5), Color(0.3, 0.2, 0.1))
	for i in 4:
		_box(Vector3(0.04, 0.9, 0.02), Vector3(0.9 + i * 0.2, 1.95, -1.48), Color(0.55, 0.55, 0.6), Vector3(0, 0, 0.05 * (i - 1.5)))
	_light(Vector3(1.0, 2.6, -0.6), Color(1.0, 0.6, 0.3), 1.0, 3.0)
