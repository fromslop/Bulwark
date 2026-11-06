class_name Item
extends RigidBody2D
## A physical object made of a grid of cells, each with its own material and health.
## Damage lands on cells; failing cells splinter, dent or tear, and any part that loses
## its connection to the rest falls away as its own body.

const CELL := ItemDefs.CELL
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
# Velocity parry: above PARRY_MIN px/s a cell starts blocking extra, at PARRY_FULL it stops everything.
const PARRY_MIN := 450.0
const PARRY_FULL := 2400.0
# Impacts: a new contact closing faster than this (px/s) damages the cell it lands on
const IMPACT_MIN_DV := 700.0
const IMPACT_DV_PER_DAMAGE := 300.0
const SOUND_MIN_DV := 220.0  # gentler knocks than this are silent
# Broken-off pieces keep only these. Elemental and magical modifiers live in the whole item,
# so a volatile crate explodes once, a superheated item's splinters don't each become a new
# fire source, and every chain reaction runs out.
const SHIELD_WEIGHT := 0.6  # shields are built to be carried: lighter than the same metal as a lump
const UNGLUABLE := ["coin", "menu", "upgrade", "potion"]
const FUSE_CAP := 900  # cells: past this a glued lump is too big to be one thing
const FUSE_SLIDE := 6  # cells: how far a glued-on piece may slide to sit clear of the other
const PART_WHOLE := 0.7  # a part torn off with this much of itself left falls away as itself
const WEAR_RING := 0.45  # share of a blow's wear on the cells round where it struck
const WEAPON_GUARD := 0.75  # a blade is a poor wall: weapons block this much as well as their material
const BRACE_TIME := 0.45  # Space with a shield: braced this long, every block a parry
const CRATE_OPEN_AT := 0.7  # a crate bursts once it's lost this much of its condition
const LOCK_RUST := 0.05  # per rust tick (4 a second) at full rust: a corroding crate's lock goes in ~5 s
## Smashing your own crate open with a swing (see smash()): a swing lands its swing damage
## times SMASH, times how much harder the weapon is than the crate (hp ratio less a half, up
## to x3; prestigium counts triple, uncapped). A steel warhammer bursts a wooden crate in about three
## swings, an iron shortsword in six or so, a club barely; a strongbox wants steel and
## patience; a steel reliquary all but ignores anything short of prestigium, rust or a blast.
const SMASH := 1.2
const SMASH_REACH := 2.5  # cells: how wide a smash spreads round where it lands
const SMASH_RUST := 0.35  # a corrosive weapon's hit on a metal crate eats this much of its lock
const BLAST_LOCK := 1.5  # an explosion right next to a crate blows its lock (any metal) this far
const WHETSTONE_WEAR := 0.1  # of the condition a whetstone puts back, what it loses itself
const ANVIL_WEAR := 0.05
const WEIGHTLESS_DENSITY := 0.04  # what's left of an item's weight when it goes weightless
const CONTACT_EVERY := 4
const NEAR_WINDOW := 2.5 * CELL  # px: nearest_cell's window (2 cells each way, from inside one)
# Prestigium runs in a gradient across a piece, teal at its top-left to blue at its bottom-right
const PRESTIGIUM_FROM := Color(0.25, 0.9, 0.82)
const PRESTIGIUM_TO := Color(0.18, 0.38, 1.0)  # physics steps between contact exchanges (heat, cold, charge)
const INHERITED_MODS := ["heavy", "weightless", "reinforced", "bouncy", "spiked", "small", "large", "huge"]
# Fire eats wood: every quarter second a burning thing loses BURN_SHARE of its burnable cells'
# worth of BURN_DAMAGE, harder the longer it's been alight, until there's no wood left. Metal
# that's only oiled has nothing to eat: it burns BURN_LIMIT seconds, then it's out for good.
const BURN_LIMIT := 8.0
const ELEMENT_HOPS := 8  # cold and heat pass on through this many things from where they started
# Charge runs out sooner: one electrified thing charges what it touches, and what that
# touches, this many things deep and no further (so one live source doesn't light up the
# whole hoard, and the Lightning Rod has only so much to draw on)
const CHARGE_HOPS := 4
const NO_HOPS := 99
# Shop stock and its shelves (and the cups on the trophy rack at home) sit on a physics layer
# of their own: the hoard passes through them (nothing you own knocks them about, piles up on
# them or swings into them), and only the hand's reach looks there (Hand.REACH_MASK)
const SHOP_LAYER := 4
const BURN_SHARE := 0.15
const BURN_DAMAGE := 1.0
# and it leaps: flame reaches this far (px) from a burning cell to the next thing, further up
const FIRE_REACH := 14.0
const FIRE_REACH_UP := 30.0
const EMBER_REACH := 45.0  # embers: now and then fire jumps a gap this wide (px) to something nearby
const EMBER_CHANCE := 0.12  # per quarter second, per thing in range
const MAGNET_RANGE := 260.0
const MAGNET_ACCEL := 2200.0


var def: Dictionary
var cells := {}   # Vector2i -> {mat, hp, max, shade}
# Collision is one rectangle per horizontal run of cells (far fewer shapes than one per
# cell); a row's rectangles are rebuilt when one of its cells goes.
var _shapes: Array[CollisionShape2D] = []  # merged rectangles covering the cells
var _shapes_dirty := false
# Drawing is split: the cells are drawn once and only redrawn when they change; moving
# effects (sparks, flames, glints, drips...) go on a separate light layer.
var _fx: Fx
var _tint := Vector2i(-1, -1)  # heat/cold, quantised: the cells only redraw when it steps
var _edges: Array = []   # [cell, dir] for every outside edge
var _tops: Array = []    # cells with nothing above
var _drips: Array = []   # decoration picks, by hash
var _bubbles: Array = []
var _sparkles: Array = []
var _sheeny: Array = []  # copper, iron and steel: the sheen that slides across them as they turn
var _twinkly: Array = []  # gold and gems: a glint now and then
var origin := Vector2.ZERO
var owned := true
var held := false:
	set(v):
		held = v
		_wake_tick()
var swing_time := 0.0:
	set(v):
		swing_time = v
		_wake_tick()
var swing_hit := false
var cooldown := 0.0:  # seconds until this weapon can swing again
	set(v):
		cooldown = v
		_wake_tick()
var _ready_flash := 0.0
var _animated := false  # has a modifier with a moving look
var _mod_looks: Array = []  # this item's modifiers that have a look in MOD_LOOKS
var _tip := Vector2i.ZERO  # the cell farthest from the grip (or the middle): a blade's point
## A small look for each modifier that has nothing else to show it: [motif, colour]. Static
## motifs draw with the item (tint: its edges washed in a colour; stripes; inset: an inner
## outline; crosshair: a mark at its point); the rest move, on the effects layer (pulse: a
## heartbeat along the edges; breathe: a slow glow; mote: specks rising; drip: drops falling;
## orbit: a wisp circling it; spark: a crackle at its point; sweep: a sheen running across;
## glint: stars twinkling; flicker: sparks at the edges; shift: an edge cycling through
## colours; halo: a ring above it).
const MOD_LOOKS := {
	"tempered": ["tint", Color(0.4, 0.5, 0.95)],  # the blue of quenched steel
	"soothing": ["mote", Color(0.75, 1.0, 0.85)],
	"wispfire": ["orbit", Color(0.6, 0.9, 1.0)],
	"headhunter": ["crosshair", Color(0.95, 0.15, 0.1)],
	"desperate": ["flicker", Color(0.8, 0.1, 0.15)],
	"lone": ["glint", Color(1.0, 1.0, 1.0)],
	"pristine": ["sweep", Color(1.0, 1.0, 1.0)],
	"guardbreaker": ["flicker", Color(1.0, 0.6, 0.2)],
	"merciless": ["tint", Color(0.5, 0.0, 0.08)],
	"avenging": ["pulse", Color(1.0, 0.8, 0.35)],
	"stormcaller": ["mote", Color(0.55, 0.62, 0.8)],  # little storm clouds
	"rested": ["breathe", Color(0.5, 0.6, 1.0)],
	"baton": ["stripes", Color(0.95, 0.3, 0.3)],
	"javelin": ["sweep", Color(1.0, 0.95, 0.6)],
	"mimic": ["shift", Color(1.0, 1.0, 1.0)],
	"lightning_rod": ["spark", Color(0.7, 0.9, 1.0)],
	"kindred": ["inset", Color(1.0, 1.0, 1.0)],  # (in its own metal's colour)
	"reckless": ["drip", Color(1.0, 0.55, 0.2)],  # chips coming off it
	"sanguine": ["mote", Color(0.85, 0.1, 0.15)],
	"bloodprice": ["pulse", Color(0.6, 0.0, 0.06)],
	"bloodthirsty": ["drip", Color(0.7, 0.0, 0.08)],
	"kindling": ["mote", Color(1.0, 0.55, 0.15)],  # embers
	"counter": ["inset", Color(0.8, 0.9, 1.0)],
	"hallowed": ["halo", Color(1.0, 0.95, 0.7)],
	"rally": ["glint", Color(1.0, 0.8, 0.3)],
}
const STATIC_LOOKS := ["tint", "stripes", "inset", "crosshair"]
var _born := 0.0  # when it was made (Time.get_ticks_msec, seconds)
var age: float:  # seconds since (the debris cap clears the oldest first)
	get:
		return Time.get_ticks_msec() * 0.001 - _born
var base_angular_damp := 0.8
var base_gravity := 1.0:
	set(v):
		base_gravity = v
		_wake_tick()
var base_linear_damp := 0.0
var levitate_time := 0.0:
	set(v):
		levitate_time = v
		_wake_tick()
var brace_time := 0.0:  # a shield set against the blow: blocks count as parries
	set(v):
		brace_time = v
		_wake_tick()
var storm_time := 0.0:  # Ring of the Storm: electrified for a while
	set(v):
		storm_time = v
		_wake_tick()
var reverse_time := 0.0:  # Ring of Reversal: falls up for a while
	set(v):
		reverse_time = v
		_wake_tick()
var _legendary := false  # legendary gear wears an aura
var _prestigium := false  # has prestigium cells (they mend themselves)
var _lock_rust := 0.0  # a metal crate's lock rusting through: at 1 it opens
var _wear_cell := Vector2i(-9999, -9999)  # the cell a whetstone or anvil is wearing down now
var _blade: Array = []  # non-handle cells top to bottom, where a weapon's engravings go
var max_total := 1.0
# elements: charge flows instantly through metal; heat creeps through contact and sets burnables alight
var charge := 0.0:
	set(v):
		charge = v
		_wake_tick()
var heat := 0.0:
	set(v):
		heat = v
		_wake_tick()
var conductive := false
var flammable := false
var cold := 0.0:
	set(v):
		cold = v
		_wake_tick()
# how many things away the cold (or heat) came from: a frosty or red-hot thing is 0, what
# touches it 1, and so on. It's just as cold in play, only drawn fainter the further it got,
# and it stops passing on after ELEMENT_HOPS. Fire catching from fire isn't held back.
var cold_hops := NO_HOPS
var heat_hops := NO_HOPS
var charge_hops := NO_HOPS  # how many things away the charge came from (0: its own)
var burn_time := 0.0
var soak := {}  # liquid -> how much has soaked in (coatings take hold past a threshold)
var _shattered := false
var charred := false
var _tick := 0.0
var _joints := {}  # Item -> [PinJoint2D, PinJoint2D] (sticky)
var _impacts: Array = []  # [global point, closing speed, other] gathered in _integrate_forces
var _fuse := -1.0  # volatile: counting down to an explosion
var _frozen_friction := false
var _vel_now := Vector2.ZERO  # velocity at the last two physics steps (for impacts)
var _spin_now := 0.0  # and spin, so a swung blade's head counts at its own speed
var _spin_prev := 0.0
var _vel_prev := Vector2.ZERO
var _contact_ids := {}
var _smashes: Array = []  # [global point, crate] this swing struck (handled outside physics)
var _smashed := {}  # instance id -> true: crates this swing has already struck
var _last_good := Transform2D.IDENTITY
var _density_mult := 1.0
var _pending_debris: Array = []
var swing_mass := 1.0  # what a swing has to move: glued-on parts count half (see _recompute_mass)
var swing_part: Dictionary = {}  # the weapon part this swing is made with (glued things: the one held)
var _glue := 0  # cells with wet glue on them (cells[c].glue): only these grab
var _rebuild_queued := false
# Rust is a state like heat: a corrosive thing starts it, it eats a metal cell now and then,
# and it creeps into other metal it touches (weaker each hop), fading unless it's fed.
var rusting := 0.0:
	set(v):
		rusting = v
		_wake_tick()
var _trail: Array = []  # global transforms over the last few frames of a swing (the motion blur)
var hit_flash := 0.0:  # the blade just landed: it flashes
	set(v):
		hit_flash = v
		_wake_tick()
# def.modifiers as a set, and the ones the physics step asks about every step as flags
# (has_mod() was a string search, made a dozen times a step by every body in the pile)
var _mods := {}
var _m_electrified := false
var _m_superheated := false
var _m_frosty := false
var _m_oiled := false
var _m_magnetic := false
var _m_volatile := false
var _m_source := false  # acts on its own every step (an element, rust, mending, a whetstone)
var _runed := false  # three bosses down: its inlaid runes glow
var _stagger := 0  # which of every CONTACT_EVERY steps is this body's
# the body's settings as last written (each write goes to the physics server)
var _gs_set := 1.0
var _ld_set := 0.0
var _ad_set := 0.0
# The room's hand on it (the Cistern's water, the Star Chamber's lift, wet ink): a gravity
# factor and extra damping the server applies, set by the game as it goes in and comes out
# (set_env) instead of a push every step, so a flooded pile can sleep like a dry one.
var env_gravity := 1.0
var env_linear_damp := 0.0
var env_angular_damp := 0.0
var _touching: Array = []  # the bodies it was against at its last physics step (see touching())
var _contact_seen := {}  # (the other contact map: the two swap every step, nothing allocated)
var _fx_shown := false
var _fx_anim_was := false  # drew moving effects last frame: one more redraw clears them
var _sheen_xform := Transform2D()  # where the sheen was last drawn
var _mass_dirty := false  # a cell changed material: mass and the rest follow at the next rebuild
# Dormant: asleep with nothing going on, so it doesn't tick at all (see _physics_process).
# The sleep signal, and the setters above on everything the tick watches, start it again.
var _ticking := true
var _paint: Paint  # the mesh being painted in _draw
var _mesh: ArrayMesh  # the item's still look, one draw command (see Paint)


static func create(d: Dictionary) -> Item:
	d.modifiers = ItemDefs.current_mods(d.get("modifiers", []))
	if d.has("fused_cells"):
		# a glued-together thing from the save: its cells as they were, not its mask's
		var fc: Dictionary = d.fused_cells
		var org: Vector2 = d.get("fused_origin", Vector2.ZERO)
		d.erase("fused_cells")
		d.erase("fused_origin")
		var fused := Item.new()
		fused._init_from(d, fc, org)
		return fused
	var mask := ItemDefs.scale_mask(ItemDefs.shape_mask(d.shape), d.get("size", 1.0))
	var it := Item.new()
	it._init_from(d, _mask_cells(d, mask), Vector2(mask[0].length(), mask.size()) * CELL * 0.5)
	return it


## A thing's cells from its pixel mask, in its material, as tough as its modifiers make it
## (`cond`: how worn, 0..1), shaded.
static func _mask_cells(d: Dictionary, mask: PackedStringArray, cond: float = 1.0) -> Dictionary:
	var main_mat: String = d.get("material", "wood")
	var hp_mult := 1.0
	for m in d.modifiers:
		if m != "tempered":
			hp_mult *= ItemDefs.MODIFIERS[m].get("hp", 1.0)
	var temper: float = ItemDefs.MODIFIERS["tempered"].get("hp", 1.0) if d.modifiers.has("tempered") else 1.0
	var cs := {}
	for y in mask.size():
		var row: String = mask[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var mat: String = main_mat if ch == "M" else ItemDefs.MASK_MATS.get(ch, main_mat)
			if ch == "h":
				mat = ItemDefs.grip_mat(main_mat)
			if ch == "i" and d.kind == "shield" and Materials.get_mat(main_mat).get("conducts", false):
				mat = main_mat  # a metal shield's boss and bands are its own metal, not a weak spot
			var full: float = Materials.hp_of(mat) * hp_mult
			if Materials.get_mat(mat).get("conducts", false):
				full *= temper  # (quenching toughens the metal, not the grip)
			cs[Vector2i(x, y)] = {"mat": mat, "hp": full * cond, "max": full, "shade": 1.0}
			if ch == "h":
				cs[Vector2i(x, y)].handle = true
	_shade(cs)
	return cs


static func _shade(cs: Dictionary) -> void:
	for c in cs:
		var s := 1.0
		if not cs.has(c + Vector2i.UP) or not cs.has(c + Vector2i.LEFT):
			s = 1.15
		if not cs.has(c + Vector2i.DOWN) or not cs.has(c + Vector2i.RIGHT):
			s = 0.75
		var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
		cs[c].shade = s * (0.94 + float(h % 13) / 100.0)


func _init_from(d: Dictionary, cs: Dictionary, org: Vector2) -> void:
	if not d.has("lineage"):
		d.lineage = new_lineage()  # (a piece broken off keeps its parent's: see lineages())
	def = d
	cells = cs
	origin = org
	def_changed()
	collision_layer = 1
	collision_mask = 3
	if d.get("phases", false):
		collision_layer = 0  # nothing bumps into it, and it only stops at walls and shelves
		collision_mask = 2
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	# contacts come through _integrate_forces (what it's against, and how hard a new one
	# lands); no contact monitor, whose bookkeeping and signals cost every awake body a step
	max_contacts_reported = 24 if cs.size() > 12 else 6  # a flat item resting on the floor uses several
	_stagger = get_instance_id() % CONTACT_EVERY
	_born = Time.get_ticks_msec() * 0.001
	sleeping_state_changed.connect(_on_sleep_changed)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.85 if d.modifiers.has("bouncy") else 0.1
	physics_material_override = pm
	_legendary = int(d.get("rarity", 0)) >= 3 and d.kind in ["weapon", "shield"] and not d.get("piece", false)
	_density_mult = SHIELD_WEIGHT if d.kind == "shield" else 1.0
	_density_mult *= float(d.get("weight", 1.0))  # a buckler is built light
	for m in d.modifiers:
		_density_mult *= ItemDefs.MODIFIERS[m].get("density", 1.0)
	if d.modifiers.has("weightless"):
		_go_weightless()
	_rebuild_shapes()
	for c in cells:
		if cells[c].get("glue", false):
			_glue += 1
	_fx = Fx.new()
	_fx.item = self
	_fx.visible = false
	add_child(_fx)
	add_to_group("items")
	if d.kind == "coin":
		add_to_group("coins")
	for m in d.modifiers:
		if m in ["sticky", "corrosive", "regenerating", "magnetic", "volatile"]:
			_animated = true
	_refresh_mod_looks()
	if d.kind == "debris":
		add_to_group("debris")
	max_total = 0.0
	for c in cells:
		max_total += cells[c].max
	if d.modifiers.has("electrified"):
		charge = 1.0
	if d.modifiers.has("superheated"):
		heat = 1.0
	if d.modifiers.has("frosty"):
		cold = 1.0
	_recompute_mass()


## (Re)build the collision rectangles for one row of cells.
## Collision: the cells covered by as few rectangles as possible. Each row's runs of cells
## are found, then a run that repeats exactly in the next row grows downward into one tall
## rectangle (a blade or a shield face becomes a handful of shapes instead of one per row).
## A long run's pile is hundreds of bodies, and the solver's cost goes with the shape count.
func _rebuild_shapes() -> void:
	for cs in _shapes:
		cs.disabled = true  # gone this step, freed at the end of the frame
		cs.queue_free()
	_shapes.clear()
	_shapes_dirty = false
	var rows := {}  # y -> xs in that row
	for c in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	var ys := rows.keys()
	ys.sort()
	var open := {}  # Vector2i(start, end) of a run -> Vector2i(first row, last row)
	for y in ys:
		var xs: Array = rows[y]
		xs.sort()
		var i := 0
		while i < xs.size():
			var start: int = xs[i]
			var end: int = start
			while i + 1 < xs.size() and xs[i + 1] == end + 1:
				i += 1
				end = xs[i]
			var run := Vector2i(start, end)
			if open.has(run) and open[run].y == y - 1:
				open[run].y = y
			else:
				if open.has(run):
					_add_rect(run, open[run])
				open[run] = Vector2i(y, y)
			i += 1
		for run in open.keys():
			if open[run].y < y:
				_add_rect(run, open[run])
				open.erase(run)
	for run in open:
		_add_rect(run, open[run])


func _add_rect(run: Vector2i, span: Vector2i) -> void:
	var rs := RectangleShape2D.new()
	rs.size = Vector2((run.y - run.x + 1) * CELL, (span.y - span.x + 1) * CELL)
	var cs := CollisionShape2D.new()
	cs.shape = rs
	cs.position = (cell_pos(Vector2i(run.x, span.x)) + cell_pos(Vector2i(run.y, span.y))) * 0.5
	add_child(cs)
	_shapes.append(cs)


func _physics_process(delta: float) -> void:
	# Most of a long run's pile is asleep: resting bodies the server isn't moving. They keep
	# their timers, and skip everything that only matters to a body in motion; one with
	# nothing left to count down stops ticking altogether (see _wake_tick).
	var awake := not sleeping
	if awake and not _is_sane():
		return
	if swing_time > 0.0:
		swing_time -= delta
		_trail.push_front(global_transform)
		if _trail.size() > 7:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
		if cooldown == 0.0:
			_ready_flash = 0.2
			queue_redraw()  # colour comes back
	if _ready_flash > 0.0:
		_ready_flash = maxf(0.0, _ready_flash - delta)
	if levitate_time > 0.0:
		levitate_time -= delta
		if levitate_time <= 0.0:
			_end_weightless_spell()
	if brace_time > 0.0:
		brace_time = maxf(0.0, brace_time - delta)
	if storm_time > 0.0:
		storm_time = maxf(0.0, storm_time - delta)
	if reverse_time > 0.0:
		reverse_time = maxf(0.0, reverse_time - delta)
	# only touch the body's settings when they change: each write goes to the physics
	# server, and a long run has a few hundred bodies doing this 120 times a second
	var floating := levitate_time > 0.0 or base_gravity == 0.0
	var gs := -1.0 if reverse_time > 0.0 else (0.0 if floating else env_gravity)
	var ld := (1.2 if levitate_time > 0.0 else base_linear_damp) + env_linear_damp
	var ad := (0.3 if swing_time > 0.0 else 5.0 if held else base_angular_damp) + env_angular_damp
	if gs != _gs_set:
		_gs_set = gs
		gravity_scale = gs
	if ld != _ld_set:
		_ld_set = ld
		linear_damp = ld
	if ad != _ad_set:
		_ad_set = ad
		angular_damp = ad
	if not awake and _at_rest():
		if _twinkly.is_empty():
			_ticking = false
			set_physics_process(false)  # dormant
		elif (Engine.get_process_frames() + _stagger) % 4 == 0:
			_fx.queue_redraw()  # (the glint off gold, now and then: that much still moves)
		return
	if not _impacts.is_empty() or not _smashes.is_empty():
		_process_impacts()
	# Elements: a thing that's cold, dark and quiet (plain gear, coins, scraps: most of the
	# pile) has nothing to pass on and nothing counting down, so it skips the exchange
	var quiet := charge <= 0.0 and heat <= 0.0 and cold <= 0.0 and rusting <= 0.0 and _glue == 0 \
		and storm_time <= 0.0 and not _m_source and not _prestigium
	if not quiet:
		_update_elements(delta)
	if _m_magnetic and (Engine.get_physics_frames() + _stagger) % CONTACT_EVERY == 0:
		_magnetize()  # (every few steps, a few times as hard: the same pull, a fraction of the scanning)
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			explode()
			return
	var tint := Vector2i.ZERO if quiet else Vector2i(int(heat * 8.0 * hop_fade(heat_hops)), int(cold * 8.0 * hop_fade(cold_hops)))
	if tint != _tint:
		_tint = tint
		queue_redraw()
	_update_fx(awake)


## Nothing counting down, nothing to pass on, nothing moving in its look: asleep like this
## it needn't tick.
func _at_rest() -> bool:
	return swing_time <= 0.0 and cooldown <= 0.0 and _ready_flash <= 0.0 and levitate_time <= 0.0 \
		and brace_time <= 0.0 and storm_time <= 0.0 and reverse_time <= 0.0 and hit_flash <= 0.0 \
		and _fuse < 0.0 and _trail.is_empty() and _impacts.is_empty() and _smashes.is_empty() \
		and charge <= 0.0 and heat <= 0.0 and cold <= 0.0 and rusting <= 0.0 and _glue == 0 \
		and not _m_source and not _prestigium and not _m_magnetic \
		and not _animated and not _legendary and not _runed and not _fx_anim_was


## Something changed that the tick watches: a dormant body ticks again.
func _wake_tick() -> void:
	if not _ticking:
		_ticking = true
		set_physics_process(true)


func _on_sleep_changed() -> void:
	if not sleeping:
		_wake_tick()


## The effects layer. Moving effects (fire, charge, a swing's trail, a modifier's look)
## redraw every frame; the sheen on metal only when the thing has moved; gold glints now
## and then. The rest of the time the layer sleeps with the body, and that's most of the pile.
func _update_fx(awake: bool) -> void:
	var anim := _animated or _legendary or _runed or charge > 0.1 or rusting > 0.0 or _fuse >= 0.0 \
		or _ready_flash > 0.0 or hit_flash > 0.0 or brace_time > 0.0 or not _trail.is_empty() \
		or (heat > 0.6 and not charred and (flammable or _m_oiled)) or (awake and speed_parry() > 0.05)
	var on := anim or not _sheeny.is_empty() or not _twinkly.is_empty()
	if on != _fx_shown:
		_fx_shown = on
		_fx.visible = on
	if not on:
		return
	var redraw := anim or _fx_anim_was
	_fx_anim_was = anim
	if not redraw and not _sheeny.is_empty() and (awake or freeze):
		# (moved a pixel or turned a hair since the sheen was drawn; a settling jiggle isn't a move)
		var xf := global_transform
		if xf.origin.distance_squared_to(_sheen_xform.origin) > 1.0 or absf(xf.x.x - _sheen_xform.x.x) + absf(xf.x.y - _sheen_xform.x.y) > 0.01:
			_sheen_xform = xf
			redraw = true
	if not redraw and not _twinkly.is_empty() and (Engine.get_process_frames() + _stagger) % 4 == 0:
		redraw = true
	if redraw:
		_fx.queue_redraw()


## The room's hand on it (see env_gravity). The step writes it to the body when it changes.
func set_env(g: float, ld: float, ad: float) -> void:
	env_gravity = g
	env_linear_damp = ld
	env_angular_damp = ad
	_wake_tick()


## The things it's resting against or pressed into, as of its last physics step (a sleeping
## body's are the ones it went to sleep on).
func touching() -> Array[Item]:
	var out: Array[Item] = []
	for b in _touching:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			out.append(b)
	return out


## Impacts are judged by how fast two things met when they first touch (not by how much
## this body's own velocity changed: a shield lying on the floor barely moves when a mace
## lands on it, but it should still crack). Lighter impactors count for less.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var count := state.get_contact_count()
	if count == 0:
		if not _contact_ids.is_empty():
			_contact_ids.clear()
			_touching.clear()
	else:
		_integrate_contacts(state, count)
	_vel_prev = _vel_now
	_vel_now = state.linear_velocity
	_spin_prev = _spin_now
	_spin_now = state.angular_velocity


func _integrate_contacts(state: PhysicsDirectBodyState2D, count: int) -> void:
	var seen := _contact_seen
	seen.clear()
	_touching.clear()
	for i in count:
		var id := state.get_contact_collider_id(i)
		if seen.has(id):
			continue
		seen[id] = true
		var other := state.get_contact_collider_object(i)
		if other is Item:
			_touching.append(other)
		if _contact_ids.has(id):
			continue  # already touching: resting, not a new knock
		if swing_time > 0.0 and other is Item and other.def.has("loot") and other.owned and not _smashed.has(id):
			_smashed[id] = true
			_smashes.append([state.get_contact_local_position(i), other])
		var n := state.get_contact_local_normal(i)
		var at := state.get_contact_local_position(i)  # (global)
		# the speed of the bits that met, not just of the bodies' centres: a swung hammer's
		# head moves far faster than its middle
		var mine := _point_vel(_vel_now, _spin_now, at - state.transform * center_of_mass)
		var ov := Vector2.ZERO
		var om := INF
		if other is Item:
			om = other.mass
			# depending on step order the other body's pre-hit velocity is in one of these
			var r: Vector2 = at - other.global_transform * other.center_of_mass
			var a := _point_vel(other._vel_now, other._spin_now, r)
			var b := _point_vel(other._vel_prev, other._spin_prev, r)
			ov = a if absf((mine - a).dot(n)) > absf((mine - b).dot(n)) else b
		elif other is RigidBody2D:
			om = other.mass
			ov = other.linear_velocity
		var share := 1.0 if om == INF else 2.0 * om / (mass + om)
		var dv := absf((mine - ov).dot(n)) * share
		if dv > SOUND_MIN_DV:
			_impacts.append([state.get_contact_local_position(i), dv, other])
	_contact_seen = _contact_ids
	_contact_ids = seen


static func _point_vel(v: Vector2, spin: float, r: Vector2) -> Vector2:
	return v + Vector2(-spin * r.y, spin * r.x)


## Hard knocks hurt: the cell at the contact takes damage, more if the other thing is harder.
func _process_impacts() -> void:
	for sm in _smashes:
		if is_instance_valid(sm[1]) and not sm[1].is_queued_for_deletion():
			sm[1].smash(sm[0], self)
	_smashes.clear()
	if _impacts.is_empty():
		return
	var list := _impacts
	_impacts = []
	for hit in list:
		var dv: float = hit[1]
		var hardness := 1.0
		var other = hit[2]
		if other is Item and is_instance_valid(other):
			var oc: Vector2i = other.nearest_cell(hit[0])
			if other.cells.has(oc):
				hardness = clampf(Materials.get_mat(other.cells[oc].mat).hp / 6.0, 0.4, 2.0)
		var cell := nearest_cell(hit[0])
		if cells.has(cell):
			var loud := clampf((dv - SOUND_MIN_DV) / 1500.0, 0.0, 1.0)
			Sfx.play(Sfx.impact_for(cells[cell].mat), lerpf(-22.0, -2.0, loud), clampf(2.0 / sqrt(maxf(mass, 1.0) / 10.0), 0.6, 1.8))
		if dv <= IMPACT_MIN_DV:
			continue
		var o_item: Item = other if other is Item and is_instance_valid(other) else null
		if o_item and ((_glue > 0 and _glue_touches(o_item)) or (o_item._glue > 0 and o_item._glue_touches(self))):
			continue  # pressed together on wet glue: that's a join, not a knock
		damage_cell(cell, (dv - IMPACT_MIN_DV) / IMPACT_DV_PER_DAMAGE * hardness, true)
		if _m_volatile and dv > IMPACT_MIN_DV * 2.0:
			light_fuse(0.05)


func nearest_cell(p: Vector2, metal_only: bool = false) -> Vector2i:
	var l := to_local(p)
	var best := Vector2i(-99999, -99999)
	var best_d := INF
	# The cells round the point first: a contact, a grab or a drop is on the thing or right
	# next to it. Any cell outside the window is at least NEAR_WINDOW away, so if the best
	# in it is nearer than that it's the answer, without a walk over every cell.
	var c0 := Vector2i(floori((l.x + origin.x) / CELL), floori((l.y + origin.y) / CELL))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := c0 + Vector2i(dx, dy)
			if not cells.has(c) or (metal_only and not Materials.get_mat(cells[c].mat).get("conducts", false)):
				continue
			var d := cell_pos(c).distance_squared_to(l)
			if d < best_d:
				best_d = d
				best = c
	if best_d <= NEAR_WINDOW * NEAR_WINDOW:
		return best
	for c in cells:
		if metal_only and not Materials.get_mat(cells[c].mat).get("conducts", false):
			continue
		var d := cell_pos(c).distance_squared_to(l)
		if d < best_d:
			best_d = d
			best = c
	return best


## Coins, scraps and pauldrons: the loose metal a magnet gathers. Whole gear is left alone,
## so a magnetic shield is still a shield and your sword doesn't come stuck to it.
func is_loose_metal() -> bool:
	return conductive and def.kind in ["coin", "debris", "junk"]


## A magnet tidies the loose metal around it into a pile and stays put itself.
func _magnetize() -> void:
	if not is_in_group("items"):
		return  # (a codex preview: not part of the game)
	for n in get_tree().get_nodes_in_group("items"):
		var o := n as Item
		if o == null or o == self or o.held or o.freeze or not o.is_loose_metal():
			continue
		var d := o.global_position - global_position
		var dist := d.length()
		if dist > MAGNET_RANGE or dist < 1.0:
			continue
		var f := d / dist * (1.0 - dist / MAGNET_RANGE) * MAGNET_ACCEL * o.mass * CONTACT_EVERY
		o.apply_central_force(-f)


func light_fuse(t: float = 0.4) -> void:
	if _fuse < 0.0 or t < _fuse:
		_fuse = t
		_wake_tick()


func explode() -> void:
	if is_queued_for_deletion():
		return
	var power := sqrt(float(cells.size()) / 40.0)
	Sfx.play("boom", 0.0, 1.2 / maxf(power, 0.5))
	get_tree().call_group("game", "on_explosion", to_global(center_of_mass), 110.0 + 50.0 * power, power, self)
	# a few chunks fly; the rest is gone in the blast
	var keys := cells.keys()
	keys.shuffle()
	for i in mini(10, keys.size()):
		var c: Vector2i = keys[i]
		_spawn_piece({c: cells[c]}, Vector2.from_angle(randf() * TAU) * randf_range(300.0, 700.0))
	queue_free()


## How strongly cold or heat that came `hops` things away is drawn: full at the source,
## down to a hint at the end of the chain.
static func hop_fade(hops: int) -> float:
	return clampf(1.0 - 0.09 * hops, 0.28, 1.0)


func is_burning() -> bool:
	return (flammable or _m_oiled) and heat > 0.6 and not charred


## Could fire take hold of it? (Anything with wood, cloth or leather left in it, or oil on it.)
func can_catch() -> bool:
	return (flammable or _m_oiled) and not charred and not is_burning() and cold < 0.3 \
		and not is_queued_for_deletion()


func ignite(amount: float = 1.0) -> void:
	heat = minf(1.0, maxf(heat, 0.45) + amount)


## Flame leaps from its burning cells to whatever's close: beside them a little, above them
## further (fire climbs). Not at home: the hoard on your shelves is safe from a stray spark.
func _spread_fire(burnable: Array) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and game.state == game.State.HOME:
		return
	var r := origin.length() + EMBER_REACH
	var near: Array[Item] = []
	for n in get_tree().get_nodes_in_group("items"):
		var o := n as Item
		if o and o != self and o.can_catch() and o.global_position.distance_to(global_position) < r + o.origin.length():
			near.append(o)
	if near.is_empty():
		return
	var reach := [Vector2(FIRE_REACH, 0), Vector2(-FIRE_REACH, 0), Vector2(0, FIRE_REACH), Vector2(0, -FIRE_REACH_UP)]
	for o in near:
		if randf() < EMBER_CHANCE:
			o.ignite(0.35)  # an ember lands on it
	for i in mini(10, burnable.size()):
		var p := to_global(cell_pos(burnable[randi() % burnable.size()]))
		for o in near:
			if o.is_burning():
				continue
			for off in reach:
				if o.cells.has(o.cell_at_global(p + off)):
					o.ignite(0.35)
					break


func has_mod(m: String) -> bool:
	return _mods.has(m)


## def changed under it (a modifier added, a kill notched): the step's flags follow.
func def_changed() -> void:
	_mods.clear()
	for m in def.modifiers:
		_mods[m] = true
	_m_electrified = _mods.has("electrified")
	_m_superheated = _mods.has("superheated")
	_m_frosty = _mods.has("frosty")
	_m_oiled = _mods.has("oiled")
	_m_magnetic = _mods.has("magnetic")
	_m_volatile = _mods.has("volatile")
	var whet := false
	if def.has("parts") and def.kind == "weapon":
		for pd in def.parts:
			if pd.get("utility", "") == "whetstone":
				whet = true
	_m_source = _m_electrified or _m_superheated or _m_frosty or _mods.has("corrosive") \
		or _mods.has("regenerating") or whet or def.get("utility", "") in ["whetstone", "anvil"]
	_runed = int(def.get("boss_kills", 0)) >= 3
	_wake_tick()


func _refresh_mod_looks() -> void:
	_mod_looks = def.modifiers.filter(func(m: String) -> bool: return MOD_LOOKS.has(m))
	for m in _mod_looks:
		if not MOD_LOOKS[m][0] in STATIC_LOOKS:
			_animated = true
	if def.get("kind", "") in ["potion", "curio"]:
		_animated = true  # potions bubble; curios catch the light (_draw_kind_fx)
	queue_redraw()


## Little lives of their own: a potion's liquid bubbles, a coin or a curio catches a glint
## now and then.
func _draw_kind_fx(cv: CanvasItem, t: float) -> void:
	match str(def.get("kind", "")):
		"potion":
			var up := Vector2.UP.rotated(-global_rotation)
			var liquid: Color = (def.get("liquid_color", Color(0.6, 0.8, 1.0)) as Color).lightened(0.4)
			for c in _sparkles + _bubbles:
				if not cells.has(c) or cells[c].mat != "glass":
					continue
				var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
				var rise := fmod(t * 0.6 + h * 0.29, 1.0)
				cv.draw_circle(cell_pos(c) + up * rise * 10.0, 1.2 * (1.0 - rise) + 0.4, Color(liquid, 0.8 * (1.0 - rise)))
		"curio":
			var ph := fmod(t * 0.5 + get_instance_id() * 0.13, 3.0)
			if ph < 0.25 and not cells.is_empty():
				var c: Vector2i = cells.keys()[get_instance_id() % cells.size()]
				var sz := sin(ph / 0.25 * PI) * 4.0
				var p := cell_pos(c)
				cv.draw_line(p - Vector2(sz, 0), p + Vector2(sz, 0), Color(1, 1, 0.9), 1.0)
				cv.draw_line(p - Vector2(0, sz), p + Vector2(0, sz), Color(1, 1, 0.9), 1.0)


## Give this item (and only this item, not pieces sharing its def) a new modifier.
func add_mod(m: String) -> void:
	if has_mod(m):
		return
	def = def.duplicate(true)
	def.modifiers.append(m)
	def_changed()
	if m in ["sticky", "corrosive", "regenerating", "magnetic", "volatile"]:
		_animated = true
	_refresh_mod_looks()
	if m == "electrified":
		charge = 1.0
	elif m == "superheated":
		heat = 1.0
	elif m == "tempered":
		for c in cells:
			if Materials.get_mat(cells[c].mat).get("conducts", false):
				cells[c].max *= 1.3
				cells[c].hp = cells[c].max
		max_total = 0.0
		for c in cells:
			max_total += cells[c].max
	elif m == "reinforced":
		# a resin block applied after the fact: the whole piece gets the toughness it would
		# have been made with, and the resin fills every crack (it comes out as good as new)
		var k: float = ItemDefs.MODIFIERS.reinforced.hp
		for c in cells:
			cells[c].max *= k
			cells[c].hp = cells[c].max
		max_total *= k
	elif m == "heavy":
		_density_mult *= 1.8
		for c in cells:
			cells[c].max *= 1.2
			cells[c].hp *= 1.2
		max_total *= 1.2
		_recompute_mass()
	elif m == "weightless":
		if levitate_time > 0.0:
			_end_weightless_spell()  # it's for good now
			levitate_time = 0.0
		_density_mult *= WEIGHTLESS_DENSITY
		_recompute_mass()
		_go_weightless()
	queue_redraw()


## Take a modifier off it again (a spell worn off, a test's row reset).
func remove_mod(m: String) -> void:
	if not has_mod(m):
		return
	def = def.duplicate(true)
	def.modifiers.erase(m)
	def_changed()
	_refresh_mod_looks()
	queue_redraw()


## Weightless: no gravity and almost no mass, so it flicks round with no effort and adds
## next to nothing to what it's glued to. A little air drag so it drifts to a stop instead
## of sailing off.
func _go_weightless() -> void:
	base_gravity = 0.0
	base_linear_damp = 1.2
	base_angular_damp = 1.5
	_wake_tick()


## The Ring of Levitation: weightless for a while (mass and all), then back to normal.
func weightless_for(seconds: float) -> void:
	if has_mod("weightless"):
		return
	if levitate_time <= 0.0:
		_density_mult *= WEIGHTLESS_DENSITY
		_recompute_mass()
	levitate_time = maxf(levitate_time, seconds)
	queue_redraw()


func _end_weightless_spell() -> void:
	_density_mult /= WEIGHTLESS_DENSITY
	_recompute_mass()
	queue_redraw()


## Regrow the item at another size (a growth or shrinking potion): the mask is rescaled and
## rebuilt, keeping the material of every cell as best it can and the same condition.
func rescale(factor: float) -> void:
	if def.has("parts"):
		return  # a glued-together thing is built from its pieces, not a mask: it can't be resized
	var old_size: float = def.get("size", 1.0)
	var new_size: float = clampf(old_size * factor, 0.4, 2.5)
	var f := new_size / old_size
	if cells.is_empty() or is_equal_approx(f, 1.0):
		return
	def = def.duplicate(true)
	def.size = new_size  # (a weapon's damage follows its pixels: see hit_damage)
	if def.kind == "coin" and ItemDefs.DEFS.has(def.get("id", "")):
		# more gold or less: a coin's worth goes with its area (never below one)
		def.value = maxi(1, roundi(float(ItemDefs.DEFS[def.id].value) * new_size * new_size))
	# what's there is what grows (or shrinks): each cell of it, damage, rust and all, scaled
	# like the mask is, so a broken blade's stub grows into a bigger stub, not a whole sword
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var size_old := hi - lo + Vector2i.ONE
	var size_new := Vector2i(maxi(1, roundi(size_old.x * f)), maxi(1, roundi(size_old.y * f)))
	var scaled := {}
	for y in size_new.y:
		for x in size_new.x:
			var src := lo + Vector2i(mini(int(x / f), size_old.x - 1), mini(int(y / f), size_old.y - 1))
			if cells.has(src):
				scaled[Vector2i(x, y)] = (cells[src] as Dictionary).duplicate()
	if scaled.is_empty():
		return
	_shade(scaled)
	# the same middle stays where it was in the body
	var mid := (Vector2(lo + hi) + Vector2.ONE) * 0.5 * CELL - origin
	var was := 0.0
	for c in cells:
		was += cells[c].max
	var now := 0.0
	for c in scaled:
		now += scaled[c].max
	max_total *= now / maxf(was, 0.001)  # (what it's lost stays lost: a stub is still a stub)
	cells = scaled
	origin = Vector2(size_new) * CELL * 0.5 - mid
	_rebuild_shapes()
	_recompute_mass()
	queue_redraw()


## Set apart from the hoard (SHOP_LAYER): shop stock on its shelf, a cup on the trophy rack.
## Nothing you own bumps into it, but the hand still reaches it. Off: an ordinary thing again.
func set_apart(on: bool) -> void:
	if on:
		collision_layer = SHOP_LAYER
		collision_mask = 0  # (it's frozen on its shelf: it needn't feel anything)
	elif def.get("phases", false):
		collision_layer = 0
		collision_mask = 2
	else:
		collision_layer = 1
		collision_mask = 3


## Every thing made gets a lineage of its own, and every piece broken off it (and every part
## of a glued thing) keeps it: whatever came from one thing can be found again together.
static func new_lineage() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]


## This thing's lineages: its own, and every glued-on part's.
func lineages() -> Array:
	var out: Array = [str(def.get("lineage", ""))]
	for pd in def.get("parts", []):
		if (pd as Dictionary).has("lineage") and not out.has(str(pd.lineage)):
			out.append(str(pd.lineage))
	return out.filter(func(l: String) -> bool: return l != "")


## Whole: every pixel its mask would give it (not a piece, nothing broken off).
func is_whole() -> bool:
	if def.get("piece", false):
		return false
	if def.has("parts") or not def.has("shape"):
		return true  # (glued things keep their own cells anyway)
	var n := 0
	for row in ItemDefs.scale_mask(ItemDefs.shape_mask(def.shape), float(def.get("size", 1.0))):
		for ch in row:
			if ch != ".":
				n += 1
	return cells.size() >= n


## The nearest bit of this item to a point, if it's within reach (magnetic catch). INF if not.
func catch_at(p: Vector2, reach: float) -> Vector2:
	var c := nearest_cell(p)
	if not cells.has(c):
		return Vector2.INF
	var g := to_global(cell_pos(c))
	return g if g.distance_to(p) <= reach else Vector2.INF


## Rust takes hold (from a corrosive thing, a rotten blade, or rusting metal it touches).
func catch_rust(level: float) -> void:
	if conductive and level > rusting:
		rusting = minf(1.0, level)


## Turn one cell into another material, keeping how damaged it was.
func transmute_cell(c: Vector2i, mat: String) -> void:
	if not cells.has(c) or cells[c].mat == mat:
		return
	var cell: Dictionary = cells[c]
	var frac := clampf(cell.hp / cell.max, 0.25, 1.0)
	var mx := Materials.hp_of(mat)
	max_total += mx - float(cell.max)
	cell.mat = mat
	cell.max = mx
	cell.hp = mx * frac
	_mass_dirty = true
	_queue_rebuild()  # mass, conductivity and flammability follow the new material


## Corrosion: the cell rusts (and shows it) as it's eaten away.
func rust_cell(c: Vector2i, amount: float) -> void:
	if not cells.has(c) or cells[c].mat == "prestigium":
		return  # prestigium never rusts
	cells[c].rust = minf(1.0, cells[c].get("rust", 0.0) + 0.25)
	damage_cell(c, amount, true)


## A transmuting drop soaks outward from where it landed: the cell it hit and up to
## `count` connected cells nearest to it (wrapped handles keep their grip). Returns how
## many changed.
func transmute_spread(start: Vector2i, mat: String, count: int) -> int:
	if not cells.has(start):
		return 0
	var turned := 0
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty() and turned < count:
		var c: Vector2i = queue.pop_front()
		if cells[c].mat != mat and not cells[c].get("handle", false):
			transmute_cell(c, mat)
			turned += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return turned


## Once most of an item is a new material it *is* that material: name and weapon stats follow.
func adopt_material(mat: String) -> void:
	if def.get("material", "") == mat or (def.has("fixed_mods") and not (mat == "prestigium" and def.has("legend"))):
		return  # legendaries keep their metal, except to ascend
	var counts := {}
	var total := 0
	for c in cells:
		if cells[c].get("handle", false):
			continue
		counts[cells[c].mat] = counts.get(cells[c].mat, 0) + 1
		total += 1
	if total == 0 or counts.get(mat, 0) * 2 < total:
		return
	def = def.duplicate(true)
	def.material = mat
	if mat in ItemDefs.METAL_GRIPS:
		for c in cells:
			if cells[c].get("handle", false):
				transmute_cell(c, mat)  # turned to fine metal: the grip goes with it
	if def.has("title"):
		def.name = "%s %s" % [mat.capitalize(), def.title]
	if mat == "prestigium" and def.has("legend"):
		ItemDefs.ascend(def)
		queue_redraw()


## A potion's glass gave way: its liquid sprays out over whatever's nearby.
func shatter() -> void:
	if _shattered or def.kind != "potion":
		return
	_shattered = true
	get_tree().call_group("game", "on_potion_shatter", self)
	queue_free()


func _update_elements(delta: float) -> void:
	if _m_electrified or storm_time > 0.0:
		charge = 1.0
	else:
		charge = maxf(0.0, charge - delta * 1.5)
	if _m_superheated:
		heat = 1.0
	elif is_burning() and cold <= 0.0:
		heat = maxf(heat, 0.75)  # fire feeds itself until frost gets at it
	else:
		heat = maxf(0.0, heat - delta * 0.08)
	if _m_frosty:
		cold = 1.0
	else:
		cold = maxf(0.0, cold - delta * 0.1)
	# frost douses a fire outright: the flames die the moment it takes, the warmth lingers
	if cold > 0.15 and is_burning() and not _m_superheated:
		heat = minf(heat, 0.55)
	# heat and cold eat each other: frost puts fires out, fire thaws ice
	if heat > 0.0 and cold > 0.0:
		var m := minf(heat, cold) * delta * 2.0
		if not _m_superheated:
			heat = maxf(0.0, heat - m)
		if not _m_frosty:
			cold = maxf(0.0, cold - m)
	# where the cold or heat came from: its own (a frosty or burning thing, or set on it
	# outright by a drain, a potion, a forge) is the start of a chain
	if _m_frosty or (cold > 0.0 and cold_hops == NO_HOPS):
		cold_hops = 0
	elif cold <= 0.0:
		cold_hops = NO_HOPS
	if _m_superheated or is_burning() or (heat > 0.0 and heat_hops == NO_HOPS):
		heat_hops = 0
	elif heat <= 0.0:
		heat_hops = NO_HOPS
	# (charge set on it outright, by a storm, a gauntlet or a potion, is a source too)
	if _m_electrified or storm_time > 0.0 or (charge > 0.1 and charge_hops == NO_HOPS):
		charge_hops = 0
	elif charge <= 0.1:
		charge_hops = NO_HOPS
	if conductive and heat > 0.6 and cold > 0.25 and not has_mod("tempered"):
		add_mod("tempered")  # quenched while red-hot: the metal comes out tougher
		heat = 0.2
		get_tree().call_group("game", "on_tempered", self)
	var frozen := cold > 0.5
	if frozen != _frozen_friction:
		_frozen_friction = frozen
		physics_material_override.friction = 0.03 if frozen else 0.7
	# Contact exchange. An inert thing (no charge, heat or cold, nothing that acts on touch)
	# has nothing to give and its neighbours push into it themselves, so it skips the
	# loop: most of a long run's pile is inert coins and scraps.
	# It runs at a quarter of the physics rate, staggered across items, with the rates
	# scaled to match.
	var inert := charge <= 0.1 and heat <= 0.0 and cold <= 0.0 and _glue == 0
	var exchange := (Engine.get_physics_frames() + _stagger) % CONTACT_EVERY == 0
	var dt := delta * CONTACT_EVERY
	var touching: Array[Item] = []
	for b in ([] if inert or not exchange else _touching):
		if not is_instance_valid(b):
			continue
		var o := b as Item
		if o == null:
			continue
		touching.append(o)
		# push to the neighbour and pull from it, so contact works even when only one
		# side reports it (frozen shop stock, for example)
		if charge > 0.1 and o.conductive and o.charge < charge * 0.9 and charge_hops < CHARGE_HOPS:
			o.charge = charge * 0.9
			o.charge_hops = mini(o.charge_hops, charge_hops + 1)
		elif o.charge > 0.1 and conductive and charge < o.charge * 0.9 and o.charge_hops < CHARGE_HOPS:
			charge = o.charge * 0.9
			charge_hops = mini(charge_hops, o.charge_hops + 1)
		if is_burning() and o.can_catch():
			o.ignite(dt * 4.0)
		elif o.is_burning() and can_catch():
			ignite(dt * 4.0)
		if heat > o.heat and heat_hops < ELEMENT_HOPS:
			o.heat = minf(1.0, o.heat + (heat - o.heat) * dt * (2.0 if o.conductive else 0.8))
			o.heat_hops = mini(o.heat_hops, heat_hops + 1)
		elif o.heat > heat and o.heat_hops < ELEMENT_HOPS:
			heat = minf(1.0, heat + (o.heat - heat) * dt * (2.0 if conductive else 0.8))
			heat_hops = mini(heat_hops, o.heat_hops + 1)
		if cold > o.cold and cold_hops < ELEMENT_HOPS:
			o.cold = minf(1.0, o.cold + (cold - o.cold) * dt * (1.5 if o.conductive else 0.6))
			o.cold_hops = mini(o.cold_hops, cold_hops + 1)
		elif o.cold > cold and o.cold_hops < ELEMENT_HOPS:
			cold = minf(1.0, cold + (o.cold - cold) * dt * (1.5 if conductive else 0.6))
			cold_hops = mini(cold_hops, o.cold_hops + 1)
		# glue only grabs with its glued patch: press that patch against the other thing, one of
		# the two in your hand, and the one in your hand takes the other in
		if _glue > 0 and (held or o.held) and _glue_touches(o):
			if held:
				fuse(o)
			else:
				o.fuse(self)
	if _m_volatile and (heat > 0.7 or charge > 0.5):
		light_fuse()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if _prestigium:
		for c in cells:  # prestigium knits itself back together
			var cell: Dictionary = cells[c]
			if cell.mat == "prestigium" and cell.hp < cell.max:
				cell.hp = minf(cell.max, cell.hp + cell.max * 0.01)
	if touching.is_empty() and (rusting > 0.0 or has_mod("corrosive") or def.get("utility", "") in ["whetstone", "anvil"]):
		for b in _touching:  # these act on touch whether or not the exchange ran this step
			if is_instance_valid(b) and b is Item:
				touching.append(b)
	if has_mod("corrosive"):
		rusting = 1.0
		for o in touching:
			o.catch_rust(0.9)
	if rusting > 0.0:
		# rust eats a metal cell now and then, creeps into metal it touches, and fades
		var metal: Array = []
		for c in cells:
			if Materials.get_mat(cells[c].mat).get("conducts", false):
				metal.append(c)
		if metal.is_empty():
			rusting = 0.0
		else:
			# only something corrosive spreads it (above); rust caught from one stays where it is
			rust_cell(metal[randi() % metal.size()], maxf(0.5, max_total * 0.001) * rusting)
			if def.has("loot"):
				_lock_rust += rusting * LOCK_RUST  # the lock goes first
				_check_crate()
			if not has_mod("corrosive"):
				rusting = maxf(0.0, rusting - 0.012)
	if is_burning():
		burn_time += 0.25
		var burnable: Array = []
		for c in cells:
			if Materials.get_mat(cells[c].mat).get("burns", false):
				burnable.append(c)
		if burnable.is_empty():
			if burn_time >= BURN_LIMIT:
				charred = true  # (oiled metal: the oil's burnt off)
				queue_redraw()
		else:
			# the fire eats through it: a share of its wood every tick, faster as it takes hold
			var dmg := BURN_DAMAGE * (1.0 + minf(burn_time, 6.0) * 0.25)
			for i in maxi(1, ceili(burnable.size() * BURN_SHARE)):
				damage_cell(burnable[randi() % burnable.size()], dmg, false)
			_spread_fire(burnable)
	if has_mod("regenerating"):
		repair(0.0075)
	if def.has("parts") and def.kind == "weapon":
		for pd in def.parts:
			if pd.get("utility", "") == "whetstone":
				var restored := repair(0.006)
				if restored > 0.0:
					# it wears the stone, not the blade
					for c in cells:
						if def.parts[int(cells[c].get("part", 0))] == pd:
							damage_cell(c, restored * WHETSTONE_WEAR * 2.0, false)
							break
				break
	match def.get("utility", ""):
		"whetstone":
			for o in touching:
				if o.def.kind == "weapon":
					_wear_from(o.repair(0.02) * WHETSTONE_WEAR)
		"anvil":
			for o in touching:
				if o.conductive and o.def.kind != "coin":
					_wear_from(o.repair(0.02) * ANVIL_WEAR)


## Dab glue on: the cells within `radius` of the cell nearest `at` get a wet patch. Only
## glued cells grab (see the contact loop), so glue goes where you put it.
func glue_patch(at: Vector2, radius: int = 1) -> void:
	var c0 := nearest_cell(at)
	if not cells.has(c0):
		return
	for c in cells:
		if absi(c.x - c0.x) + absi(c.y - c0.y) <= radius and not cells[c].get("glue", false):
			cells[c].glue = true
			_glue += 1
	_wake_tick()
	if not has_mod("sticky"):
		add_mod("sticky")  # (shows on the inspect card; the patch is what grabs)
	queue_redraw()


func glued_at(p: Vector2) -> bool:
	var c := cell_at_global(p)
	return cells.has(c) and cells[c].get("glue", false)


## Is the glued patch pressed against `o`? (a glued cell, or the cell next to it, overlaps o)
func _glue_touches(o: Item) -> bool:
	for c in cells:
		if not cells[c].get("glue", false):
			continue
		var p := to_global(cell_pos(c))
		if o.has_cell_at(p):
			return true
		for d in DIRS:
			if o.has_cell_at(p + to_global(Vector2(d) * CELL) - global_position):
				return true
	return false


## A thing made sticky (a rolled modifier, an old save) gets one small patch on an edge.
func _ensure_glue() -> void:
	if not has_mod("sticky") or _glue > 0 or cells.is_empty():
		return
	var edge: Array = cells.keys().filter(func(c: Vector2i) -> bool: return _is_edge(c))
	var pick: Vector2i = edge[absi(hash(def.get("id", ""))) % edge.size()] if not edge.is_empty() else cells.keys()[0]
	glue_patch(to_global(cell_pos(pick)), 1)


## Glue: take `o` into this item. Its cells join this one's grid where they lie (snapped to
## the nearest free cell), each remembering which piece it came from, so a buckler glued to
## a sword still blocks like a buckler and weighs what a buckler weighs. One rigid body, so
## nothing jitters at a joint; breakage, blocking and splitting all work as for any item.
## Modifiers are pooled (the glue is used up). If damage later tears a part off mostly whole,
## it falls away as itself again.
func fuse(o: Item) -> bool:
	if o == self or not is_instance_valid(o) or o.is_queued_for_deletion() or is_queued_for_deletion():
		return false
	if o.freeze or not o.owned or not owned or o.def.kind in UNGLUABLE or def.kind in UNGLUABLE or o.def.get("phases", false):
		return false
	if cells.size() + o.cells.size() > FUSE_CAP:
		return false
	def = def.duplicate(true)
	if not def.has("parts"):
		var own := _part_summary(def, _density_mult, cells.size())
		def.parts = [own]
		for c in cells:
			cells[c].part = 0
	var offset: int = def.parts.size()
	var theirs: Array = o.def.parts if o.def.has("parts") else [_part_summary(o.def, o._density_mult, o.cells.size())]
	for pd in theirs:
		def.parts.append((pd as Dictionary).duplicate(true))
	# the other thing comes across whole: its grid turned to the nearest quarter turn and moved
	# as one block, so its shape, every pixel and its condition arrive exactly as they were
	# (copied pixel by pixel at a slant, pixels rounded onto each other and were lost or
	# pushed aside: glue warped and chipped both pieces). Overlapping, the block slides to the
	# nearest spot where it doesn't; the glue seam then bridges any gap.
	var quarter := posmod(roundi((o.global_rotation - global_rotation) / (PI / 2.0)), 4)
	var anchor: Vector2i = o.nearest_cell(o.to_global(o.center_of_mass))
	var lp := to_local(o.to_global(o.cell_pos(anchor)))
	var base := Vector2i(floori((lp.x + origin.x) / CELL), floori((lp.y + origin.y) / CELL))
	var spots := {}
	for c in o.cells:
		spots[c] = base + _quarter_turn(c - anchor, quarter)
	var shift := _free_shift(spots.values())
	if shift.x == 9999:
		return false  # nowhere near to put it
	for c in o.cells:
		var cell: Dictionary = (o.cells[c] as Dictionary).duplicate()
		cell.part = offset + int(cell.get("part", 0))
		cell.erase("handle")  # only the main piece's grip is a grip
		cells[spots[c] + shift] = cell
	_bridge(offset)
	var title := str(o.def.get("title", o.def.get("name", "thing")))
	def.name = "%s + %s" % [str(def.get("name", def.get("title", ""))), title]
	def.fused = true
	for m in o.def.modifiers:
		if m != "sticky" and not has_mod(m) and ItemDefs.MODIFIERS.has(m) and ItemDefs._compatible(m, def.modifiers):
			add_mod(m)
	def.modifiers.erase("sticky")  # the glue is spent
	def_changed()
	for c in cells:
		cells[c].erase("glue")
	_glue = 0
	heat = maxf(heat, o.heat)
	charge = maxf(charge, o.charge)
	cold = maxf(cold, o.cold)
	cold_hops = mini(cold_hops, o.cold_hops)
	heat_hops = mini(heat_hops, o.heat_hops)
	charge_hops = mini(charge_hops, o.charge_hops)
	Item._shade(cells)
	max_total = 0.0
	for c in cells:
		max_total += cells[c].max
	if o.held:
		get_tree().call_group("game", "release_if_holding", o)
	o.queue_free()
	_shapes_dirty = true
	_rebuild_shapes()
	_recompute_mass()
	queue_redraw()
	Sfx.play("soft", -2.0, 0.7)
	get_tree().call_group("game", "on_fused", self)
	return true


## A cell offset turned by `q` quarter turns (clockwise on screen, as rotation goes).
static func _quarter_turn(v: Vector2i, q: int) -> Vector2i:
	match q:
		1:
			return Vector2i(-v.y, v.x)
		2:
			return Vector2i(-v.x, -v.y)
		3:
			return Vector2i(v.y, -v.x)
	return v


## The smallest move (in cells) that puts every one of `spots` on an empty cell, or
## (9999, 9999) if there isn't one close by.
func _free_shift(spots: Array) -> Vector2i:
	var moves: Array[Vector2i] = []
	for dy in range(-FUSE_SLIDE, FUSE_SLIDE + 1):
		for dx in range(-FUSE_SLIDE, FUSE_SLIDE + 1):
			moves.append(Vector2i(dx, dy))
	moves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	for d in moves:
		var clear := true
		for sp in spots:
			if cells.has(sp + d):
				clear = false
				break
		if clear:
			return d
	return Vector2i(9999, 9999)


## Glued pieces that only touch at a corner, or not quite at all, are joined by a seam of
## glue cells along the shortest gap, so the whole is one connected thing (otherwise the
## first knock would split them straight back apart).
func _bridge(glue_part: int) -> void:
	for guard in 8:
		var comps := _components()
		if comps.size() <= 1:
			return
		comps.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		var main_comp: Array = comps[0]
		var other: Array = comps[1]
		var best_a := Vector2i.ZERO
		var best_b := Vector2i.ZERO
		var best_d := 1 << 30
		for a in main_comp:
			for b in other:
				var d: int = absi(a.x - b.x) + absi(a.y - b.y)
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		# a staircase of glue from one to the other (4-connected)
		var cur: Vector2i = best_a
		while cur != best_b:
			if cur.x != best_b.x:
				cur.x += signi(best_b.x - cur.x)
			else:
				cur.y += signi(best_b.y - cur.y)
			if not cells.has(cur):
				var hp := Materials.hp_of("glue")
				cells[cur] = {"mat": "glue", "hp": hp, "max": hp, "shade": 1.0, "part": glue_part}
		# a fat seam: a cell either side of the join too
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = best_a + d
			if not cells.has(n):
				var hp2 := Materials.hp_of("glue")
				cells[n] = {"mat": "glue", "hp": hp2, "max": hp2, "shade": 1.0, "part": glue_part}


static func _part_summary(d: Dictionary, dens: float, n: int) -> Dictionary:
	var pd := d.duplicate(true)
	pd.erase("parts")
	pd.erase("fused")
	pd.dens = dens
	pd.n = n
	return pd


## Safety net: if the solver ever hands us non-finite numbers, snap back to the last good
## state instead of letting NaNs spread through contacts and joints.
func _is_sane() -> bool:
	var xf := global_transform
	if xf.is_finite() and _vel_now.is_finite() and is_finite(_spin_now):
		_last_good = xf
		return true
	for k in _joints.keys():
		for j in _joints[k]:
			if is_instance_valid(j):
				j.queue_free()
	_joints.clear()
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, _last_good)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	return false


## Move a body that's already in the physics world (plain position writes get overwritten).
func teleport(p: Vector2) -> void:
	_wake_tick()
	global_position = p
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func cell_pos(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL - origin


func cell_at_global(p: Vector2) -> Vector2i:
	var l := to_local(p) + origin
	return Vector2i(floori(l.x / CELL), floori(l.y / CELL))


## True if the cell at this local grab point is a wrapped handle.
func is_handle_at_local(local: Vector2) -> bool:
	var c := cell_at_global(to_global(local))
	return cells.has(c) and cells[c].get("handle", false)


func has_cell_at(p: Vector2) -> bool:
	return cells.has(cell_at_global(p))


func point_velocity(p: Vector2) -> Vector2:
	var r := p - to_global(center_of_mass)
	return linear_velocity + Vector2(-angular_velocity * r.y, angular_velocity * r.x)


## 0..1 parry strength for a given speed in px/s.
static func parry_for_speed(speed: float) -> float:
	return clampf((speed - PARRY_MIN) / (PARRY_FULL - PARRY_MIN), 0.0, 1.0)


## Rough "how parry-ready is this whole item right now", used for the glint.
func speed_parry() -> float:
	var radius := origin.length()
	return parry_for_speed(linear_velocity.length() + absf(angular_velocity) * radius * 0.7)


func block_at(p: Vector2) -> float:
	var c := cell_at_global(p)
	if not cells.has(c):
		return 0.0
	var cell: Dictionary = cells[c]
	var hpf := clampf(cell.hp / cell.max, 0.0, 1.0)
	var pd := _part_of(cell)  # a glued-on part blocks as what it is: a buckler on a sword is a shield
	var b: float = Materials.get_mat(cell.mat).block * (0.85 + 0.15 * hpf) * float(pd.get("guard", 1.0))
	if pd.kind == "weapon":
		b *= WEAPON_GUARD
	return minf(b, 0.99)


## What a cell is part of: the item itself, or (once things are glued together) the piece it
## came from: {kind, guard, id, ...}.
func _part_of(cell: Dictionary) -> Dictionary:
	if cell.has("part") and def.has("parts") and int(cell.part) < def.parts.size():
		return def.parts[int(cell.part)]
	return def


## The piece of this item at a local point (the grip): a glued sword-and-buckler held by the
## buckler is a buckler to Space, held by the sword it's a sword. Every part still blocks.
func part_at_local(local: Vector2) -> Dictionary:
	var c := cell_at_global(to_global(local))
	if not cells.has(c):
		c = nearest_cell(to_global(local))
	return _part_of(cells[c]) if cells.has(c) else def


func has_part(kind: String) -> bool:
	if not def.has("parts"):
		return def.kind == kind
	for pd in def.parts:
		if pd.kind == kind:
			return true
	return false


## Glued-on weight that isn't weapon or shield makes a weapon hit harder: a rock on a club
## is a mace. Up to x1.6.
func heft() -> float:
	if not def.has("parts") or def.kind != "weapon":
		return 1.0
	var blade := 0.0
	var extra := 0.0
	for c in cells:
		var pd := _part_of(cells[c])
		var m: float = Materials.get_mat(cells[c].mat).density * float(pd.get("dens", _density_mult))
		if pd.kind == "weapon":
			blade += m
		elif pd.kind != "shield":
			extra += m
	return clampf(1.0 + 0.5 * extra / maxf(blade, 1.0), 1.0, 1.6)


## An enemy blow chewing into it where a lane met it: the cell it struck and the ring of
## cells round it (a lane is a broad stroke, not a pinprick), each by its material's wear.
func wear_at(p: Vector2, amount: float) -> void:
	var c := cell_at_global(p)
	if not cells.has(c):
		return
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if cells.has(n):
				var w: float = Materials.get_mat(cells[n].mat).get("wear", 1.0)
				damage_cell(n, amount * w * (1.0 if n == c else WEAR_RING), n == c)


func damage_cell(c: Vector2i, amount: float, spread: bool) -> void:
	if not cells.has(c) or amount <= 0.0:
		return
	var cell: Dictionary = cells[c]
	var m := Materials.get_mat(cell.mat)
	if cold > 0.5:
		amount *= 1.5  # frozen things are brittle
	cell.hp -= amount
	if spread:
		var s: Vector2 = m.spread
		damage_cell(c + Vector2i.LEFT, amount * s.x, false)
		damage_cell(c + Vector2i.RIGHT, amount * s.x, false)
		damage_cell(c + Vector2i.UP, amount * s.y, false)
		damage_cell(c + Vector2i.DOWN, amount * s.y, false)
	if cell.hp <= 0.0 and cells.has(c):
		_fail_cell(c, m)
	_queue_rebuild()


func _fail_cell(c: Vector2i, m: Dictionary) -> void:
	var cell: Dictionary = cells[c]
	var overflow: float = -cell.hp
	Sfx.play("crack", -10.0, 1.4 if m.behavior == "dent" else 1.0)
	if def.kind == "potion" and cell.mat == "glass":
		call_deferred("shatter")
	cells.erase(c)
	_shapes_dirty = true
	if m.behavior != "tear" and not (m.get("burns", false) and is_burning()):
		# the failed cell comes off as a splinter / scrap of its own (one that burnt away is ash)
		cell.hp = cell.max * 0.6
		var fling := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.2)).normalized() * randf_range(80.0, 240.0)
		_pending_debris.append({"cells": {c: cell}, "vel": fling})
	if m.behavior == "splinter" and overflow > 0.0:
		# cracks run along the grain
		damage_cell(c + Vector2i.UP, overflow * 0.8 + 0.3, false)
		damage_cell(c + Vector2i.DOWN, overflow * 0.8 + 0.3, false)


## Legendary gear shimmers: a rim of colour running round its edge and stars glinting off
## it. Ascended (prestigium) legendaries burn paler and brighter, with a halo.
func _draw_aura(cv: CanvasItem, t: float, half: Vector2) -> void:
	var asc: bool = def.get("ascended", false)
	# the rim: a line just outside every outer edge, its colour running round the item,
	# with a fainter glow further out
	for i in _edges.size():
		var e: Array = _edges[i]
		var d := Vector2(e[1])
		var tan := Vector2(-d.y, d.x) * (CELL * 0.5 + 1.0)
		var hue := fmod(t * 0.3 + float(i) / _edges.size(), 1.0)
		var col := Color.from_hsv(hue, 0.25 if asc else 0.65, 1.0, 0.9 if asc else 0.75)
		var p := cell_pos(e[0]) + d * (CELL * 0.5 + 1.5)
		cv.draw_line(p - tan, p + tan, col, 2.0)
		var p2 := p + d * 3.0
		cv.draw_line(p2 - tan, p2 + tan, Color(col.r, col.g, col.b, 0.25), 3.0)
	for k in (5 if asc else 2):
		var e2: Array = _edges[int(t * 5.0 + k * 13) % _edges.size()]
		var tw := fmod(t * 1.7 + k * 0.37, 1.0)
		var p := cell_pos(e2[0]) + Vector2(e2[1]) * (4.0 + tw * 8.0)
		var s := 3.0 + 2.0 * (1.0 - tw)
		var a := 1.0 - tw
		cv.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color(1, 1, 1, a), 1.0)
		cv.draw_line(p - Vector2(0, s), p + Vector2(0, s), Color(1, 1, 1, a), 1.0)
	if asc:
		cv.draw_arc(center_of_mass, origin.length() * 0.6 + 6.0 + sin(t * 3.0) * 2.0, 0.0, TAU, 40, Color(0.4, 0.85, 1.0, 0.35), 2.0)


## Where a weapon's boss runes go: four per boss slain, spread down the blade.
func _inlay_cells() -> Array:
	var bosses := int(def.get("boss_kills", 0))
	var out: Array = []
	if _blade.is_empty():
		return out
	for i in mini(bosses * 4, _blade.size()):
		var c: Vector2i = _blade[(i * 5 + 2) % _blade.size()]
		if cells.has(c):
			out.append(c)
	return out


## A weapon wears what it has done: a tally notch cut in the edge for every foe slain, gold
## runes inlaid for every boss (they glow from the third), and a gilded edge from the fifth.
func _draw_engravings() -> void:
	var kills := int(def.get("kills", 0))
	var bosses := int(def.get("boss_kills", 0))
	if (kills == 0 and bosses == 0) or _edges.is_empty():
		return
	var notched := 0
	var i := 0
	while notched < mini(kills, 24) and i < _edges.size() * 2:
		var e: Array = _edges[(i * 7) % _edges.size()]
		i += 1
		if cells[e[0]].get("handle", false):
			continue
		var p := cell_pos(e[0])
		var d := Vector2(e[1])
		_paint.line(p + d * 0.5, p + d * (CELL * 0.5), Color(0.08, 0.06, 0.05, 0.9), 1.5)
		notched += 1
	for c in _inlay_cells():
		var p := cell_pos(c)
		_paint.line(p - Vector2(2, 0), p + Vector2(2, 0), Color(0.95, 0.75, 0.3), 1.0)
		_paint.line(p - Vector2(0, 2), p + Vector2(0, 2), Color(0.95, 0.75, 0.3), 1.0)
	if bosses >= 5:
		for e in _edges:
			if not cells[e[0]].get("handle", false):
				_paint.outline(Rect2(cell_pos(e[0]) - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), Color(1.0, 0.8, 0.35, 0.5), 1.0)


## Space with a shield: set it against the next blow. For a moment every block it makes
## is a parry. Shields take time to reset (their cooldown).
func brace() -> bool:
	if not has_part("shield") or cooldown > 0.0:
		return false  # (a glued thing braces when it has a shield in it and is held by that)
	brace_time = BRACE_TIME
	cooldown = def.get("cooldown", 1.4)
	queue_redraw()
	return true


## Mend every cell by `fraction` of its toughness. Returns how much condition came back.
func repair(fraction: float) -> float:
	var restored := 0.0
	for c in cells:
		var cell: Dictionary = cells[c]
		var hp: float = cell.hp
		cell.hp = minf(cell.max, cell.hp + cell.max * fraction)
		restored += cell.hp - hp
		if cell.get("rust", 0.0) > 0.0:
			cell.rust = maxf(0.0, cell.rust - fraction * 2.0)
	rusting = maxf(0.0, rusting - fraction * 4.0)  # mending scours the rust off too
	queue_redraw()
	return restored


## A whetstone or anvil wears as it works: a share of what it put back comes off it, a
## cell at a time (stone chips, iron dents). Harder ones have more to lose.
func _wear_from(amount: float) -> void:
	if amount <= 0.0 or cells.is_empty():
		return
	# one edge cell at a time, so it visibly chips away rather than crumbling all at once
	if not cells.has(_wear_cell):
		_wear_cell = _edges[randi() % _edges.size()][0] if not _edges.is_empty() else cells.keys()[0]
	damage_cell(_wear_cell, amount, false)


func start_swing(dir: float, power: float, haste: float = 1.0, part: Dictionary = {}) -> bool:
	if swing_time > 0.0 or cooldown > 0.0:
		return false
	swing_part = part if not part.is_empty() else def  # a glued thing swings with the weapon you hold it by
	cooldown = float(swing_part.get("cooldown", def.get("cooldown", 1.0))) * haste
	queue_redraw()  # drained of colour while it recovers
	swing_time = 0.35
	swing_hit = false
	_smashed.clear()
	angular_velocity = dir * float(swing_part.get("swing_speed", def.get("swing_speed", 10.0))) * power / maxf(1.0, sqrt(swing_mass / 15.0))
	return true


## What a full-strength swing of this weapon lands for, before swing speed, rings, infusions
## and the rest: its pixels, each weighted by its material and by how whole it still is,
## times its kind's punch per pixel (ItemDefs.damage_per_pixel). `wd`: the weapon (a glued
## thing's: the weapon part swung, whose pixels are the only ones that count).
func hit_damage(wd: Dictionary = {}) -> float:
	if wd.is_empty():
		wd = swing_part if not swing_part.is_empty() else def
	var part := _part_index(wd)
	var px := 0.0
	for c in cells:
		var cell: Dictionary = cells[c]
		if part >= 0 and int(cell.get("part", 0)) != part:
			continue
		px += float(Materials.get_mat(cell.mat).sharp) * clampf(cell.hp / cell.max, 0.0, 1.0)
	return ItemDefs.damage_per_pixel(wd) * px * ItemDefs.WEAPON_DAMAGE


## Which of a glued thing's parts `wd` is (-1: not glued, or not one of them: every pixel).
func _part_index(wd: Dictionary) -> int:
	if not def.has("parts"):
		return -1
	for i in def.parts.size():
		if is_same(def.parts[i], wd):
			return i
	for i in def.parts.size():
		if def.parts[i].get("id", "") == wd.get("id", "") and def.parts[i].kind == wd.get("kind", ""):
			return i
	return -1


## Average condition of the main-material cells (a dented blade hits softer).
func edge_condition() -> float:
	var total := 0.0
	var n := 0
	for c in cells:
		if cells[c].mat == def.material:
			total += clampf(cells[c].hp / cells[c].max, 0.0, 1.0)
			n += 1
	return total / n if n > 0 else 0.3


func health_ratio() -> float:
	var total := 0.0
	for c in cells:
		total += maxf(cells[c].hp, 0.0)
	return total / maxf(max_total, 0.001)


## What this item is called: the name its owner gave it, or what it is.
func display_name() -> String:
	return str(def.get("custom_name", def.name))


func describe() -> String:
	var s: String = display_name()
	if not def.modifiers.is_empty():
		s += " [" + ", ".join(PackedStringArray(def.modifiers)) + "]"
	return "%s   %d%% intact   mass %.0f" % [s, health_ratio() * 100.0, mass]


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		call_deferred("_rebuild")


func _rebuild() -> void:
	_rebuild_queued = false
	if _shattered:
		return
	for p in _pending_debris:
		_spawn_piece(p.cells, p.vel)
	_pending_debris.clear()
	if cells.is_empty():
		queue_free()
		return
	# a cell lost: what's come loose falls away, and the collision and the mass follow. A
	# cell only worn (most damage) wants nothing but a redraw.
	var lost := _shapes_dirty
	if lost:
		var comps := _components()
		if comps.size() > 1:
			comps.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
			for i in range(1, comps.size()):
				var sub := {}
				for c in comps[i]:
					sub[c] = cells[c]
					cells.erase(c)
				_spawn_piece(sub, Vector2.ZERO)
		_rebuild_shapes()
	if lost or _mass_dirty:
		_mass_dirty = false
		_recompute_mass()
	queue_redraw()
	_check_crate()


## Struck by a swing of your own (a hammer brought down on your crate): it lands like a weapon
## hit, cut down by how much harder this is than the weapon, spread round where it lands.
## A corrosive weapon eats a metal crate's lock as well.
func smash(at: Vector2, by: Item) -> void:
	var c := nearest_cell(at)
	if not cells.has(c) or def.get("opened", false):
		return
	var wd: Dictionary = by.swing_part if not by.swing_part.is_empty() else by.def
	var wmat: String = wd.get("material", by.def.material)
	var ratio: float = Materials.get_mat(wmat).hp / Materials.get_mat(cells[c].mat).hp
	var bite := clampf(ratio - 0.5, 0.0, 3.0)
	if wmat == "prestigium":
		bite = ratio * 3.0 - 0.5  # the keenest there is: no cap, and a reliquary gives way
	var amount := by.hit_damage(wd) / ItemDefs.WEAPON_DAMAGE * SMASH * bite * by.heft()
	var weights := {}
	var total := 0.0
	for o in cells:
		var d := Vector2(o - c).length()
		if d <= SMASH_REACH:
			weights[o] = 1.0 - d / (SMASH_REACH + 1.0)
			total += weights[o]
	for o in weights:
		damage_cell(o, amount * weights[o] / total, false)
	if by.has_mod("corrosive") and conductive:
		_lock_rust += SMASH_RUST
	Sfx.play("crack", -4.0, 0.8)
	_check_crate()


## Caught in a blast: a crate's lock is blown open the closer it was (any metal).
func blast_lock(amount: float) -> void:
	if def.has("loot"):
		_lock_rust += amount
		_check_crate()


## A crate spills its loot once it's taken enough of a beating, or once rust has eaten its
## lock through.
func _check_crate() -> void:
	if not def.has("loot") or def.get("opened", false) or def.kind == "debris" or not owned:
		return  # shop stock stays shut until it's bought
	if health_ratio() < CRATE_OPEN_AT or _lock_rust >= 1.0:
		def.opened = true  # shared by every piece of this crate
		get_tree().call_group("game", "on_crate_broken", self)


func _components() -> Array:
	var seen := {}
	var comps: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var comp: Array = []
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			comp.append(cur)
			for d in DIRS:
				var n: Vector2i = cur + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		comps.append(comp)
	return comps


func _spawn_piece(sub: Dictionary, extra_vel: Vector2) -> void:
	if get_parent() == null:
		return
	var d := def.duplicate(true)
	if def.has("parts"):
		# a glued-on part torn away: if it's all one piece and mostly whole, it's itself again
		var part := -1
		for c in sub:
			var p: int = int(sub[c].get("part", 0))
			part = p if part == -1 or part == p else -2
		if part >= 0 and part < def.parts.size():
			var pd: Dictionary = def.parts[part]
			d = pd.duplicate(true)
			d.erase("dens")
			d.erase("n")
			for c in sub:
				sub[c].erase("part")
			if sub.size() >= int(pd.get("n", 1)) * PART_WHOLE:
				var whole := Item.new()
				whole._init_from(d, sub, origin)
				whole.owned = owned
				whole.transform = transform
				whole.linear_velocity = linear_velocity + extra_vel
				whole.angular_velocity = angular_velocity
				get_parent().add_child(whole)
				return
	d.erase("loot")  # only the crate itself spills its contents
	d.piece = true  # a broken-off chunk: not a whole thing any more (hoard utilities skip it)
	if d.kind == "potion":
		d.kind = "debris"  # a broken flask's pieces are just glass
		d.name = "Glass shard"
	d.modifiers = d.modifiers.filter(func(m: String) -> bool: return INHERITED_MODS.has(m))
	if sub.size() <= 3:
		d.kind = "debris"
		var mat: String = sub.values()[0].mat
		d.name = "%s %s" % [mat.capitalize(), "splinter" if mat == "wood" else "scrap"]
	var piece := Item.new()
	piece._init_from(d, sub, origin)
	piece.owned = owned
	piece.heat = heat if is_burning() else heat * 0.7  # leftover heat and cold fade on their own (but a fire carries on in what breaks off)
	piece.cold = cold * 0.7
	piece.heat_hops = heat_hops
	piece.cold_hops = cold_hops
	piece.charge_hops = charge_hops
	piece.charred = charred
	piece.burn_time = burn_time
	piece.transform = transform
	piece.linear_velocity = linear_velocity + extra_vel
	piece.angular_velocity = angular_velocity + randf_range(-3.0, 3.0)
	get_parent().add_child(piece)


func _recompute_mass() -> void:
	var total := 0.0
	var swing := 0.0
	var com := Vector2.ZERO
	conductive = false
	flammable = false
	_prestigium = false
	for c in cells:
		var md := Materials.get_mat(cells[c].mat)
		conductive = conductive or md.get("conducts", false)
		_prestigium = _prestigium or cells[c].mat == "prestigium"
		flammable = flammable or md.get("burns", false)
		var pd := _part_of(cells[c])
		var m: float = Materials.get_mat(cells[c].mat).density * float(pd.get("dens", _density_mult))
		total += m
		swing += m if (not cells[c].has("part") or pd.kind == "weapon") else m * 0.5
		com += cell_pos(c) * m
	mass = maxf(total, 0.05)
	swing_mass = maxf(swing, 0.05)
	_blade = cells.keys().filter(func(c: Vector2i) -> bool: return not cells[c].get("handle", false))
	_blade.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com / maxf(total, 0.0001)
	_edges.clear()
	_tops.clear()
	_drips.clear()
	_bubbles.clear()
	_sparkles.clear()
	_sheeny.clear()
	_twinkly.clear()
	for c in cells:
		for d in DIRS:
			if not cells.has(c + d):
				_edges.append([c, d])
		if not cells.has(c + Vector2i.UP):
			_tops.append(c)
		var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
		if h % 5 == 0 and not cells.has(c + Vector2i.DOWN):
			_drips.append(c)
		if h % 7 == 0:
			_bubbles.append(c)
		if h % 11 == 0:
			_sparkles.append(c)
		var mat: String = cells[c].mat
		if mat == "gold" or mat == "gem":
			_twinkly.append(c)
		elif mat == "copper" or mat == "iron" or mat == "steel":
			_sheeny.append(c)
	# the point: the cell farthest from the grip (or from the middle, if it has none)
	var from := center_of_mass
	var grips := cells.keys().filter(func(c: Vector2i) -> bool: return cells[c].get("handle", false))
	if not grips.is_empty():
		from = Vector2.ZERO
		for g in grips:
			from += cell_pos(g)
		from /= grips.size()
	var far := -1.0
	for c in cells:
		var dd := cell_pos(c).distance_squared_to(from)
		if dd > far:
			far = dd
			_tip = c


## The still part of its look (the cells, their grain, wear, rust and marks) is painted into
## one mesh and drawn with one command. It was a few commands a cell, and with a long run's
## pile on screen the renderer spent most of the frame walking through them.
func _draw() -> void:
	_paint = Paint.new()
	_paint_cells()
	_mesh = _paint.mesh()  # (kept: the draw command points at it)
	_paint = null
	if _mesh:
		draw_mesh(_mesh, null)


func _paint_cells() -> void:
	var half := Vector2(CELL, CELL) * 0.5
	var t := Time.get_ticks_msec() * 0.001
	var mods: Array = def.modifiers
	var dull := cooldown > 0.0 and def.has("cooldown")  # recovering from a swing: drained of colour
	var poisoned := has_mod("poisoned")
	for c in cells:
		var cell: Dictionary = cells[c]
		var m := Materials.get_mat(cell.mat)
		var hpf := clampf(cell.hp / cell.max, 0.0, 1.0)
		var base: Color = def.gem if cell.mat == "gem" and def.has("gem") else m.color
		if cell.mat == "prestigium":
			var span := maxf(1.0, (origin.x + origin.y) * 2.0 / CELL)
			base = PRESTIGIUM_FROM.lerp(PRESTIGIUM_TO, clampf(float(c.x + c.y) / span, 0.0, 1.0))
		if cell.mat == "glass" and def.has("liquid_color"):
			base = (def.liquid_color as Color).lerp(Color(1, 1, 1), 0.2)
		if poisoned and not cells.has(c + Vector2i.UP):
			base = base.lerp(Color(0.4, 0.9, 0.3), 0.5)  # venom glistening on the top edge
		if _m_oiled:
			base = base.darkened(0.25)
		var col: Color = base * float(cell.shade)
		col = col.darkened((1.0 - hpf) * 0.45)
		if cell.get("rust", 0.0) > 0.0:
			col = col.lerp(Color(0.55, 0.28, 0.12), cell.rust * 0.65)
		if dull:
			var g := col.get_luminance() * 0.8
			col = col.lerp(Color(g, g, g), 0.6)
		if charred and m.get("burns", false):
			col = col.darkened(0.6)
		if cold > 0.05:
			col = col.lerp(Color(0.75, 0.9, 1.0), cold * 0.5 * hop_fade(cold_hops))
		if heat > 0.05:
			col = col.lerp(Color(1.0, 0.35, 0.1), heat * (0.6 if m.get("conducts", false) else 0.25) * hop_fade(heat_hops))
		col.a = 1.0
		var r := Rect2(cell_pos(c) - half, Vector2(CELL, CELL))
		if m.behavior == "dent" and hpf < 0.6:
			r = r.grow(-1.0)
		_paint.rect(r, col)
		_texture_cell(c, cell.mat, r, col, t)  # each material's own grain, sheen or weave
		if cell.get("handle", false):
			# leather wrapping: dark diagonal bands
			_paint.line(r.position + Vector2(0, CELL * 0.75), r.position + Vector2(CELL, CELL * 0.25), Color(0.25, 0.15, 0.08), 2.0)
		if m.behavior == "splinter" and hpf < 0.5:
			_paint.line(r.position + Vector2(CELL * 0.5, 0), r.position + Vector2(CELL * 0.4, CELL), col.darkened(0.5), 1.0)
		elif m.behavior == "tear" and hpf < 0.5:
			_paint.rect(r.grow(-2.0), col.darkened(0.6))
		var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
		var edge := _is_edge(c)
		if mods.has("reinforced"):
			_paint.rect(r, Color(1.0, 0.65, 0.15, 0.18))  # a glaze of amber resin over all of it
			if edge:
				_paint.outline(r, Color(0.85, 0.5, 0.1, 0.7), 1.0)
		if cell.get("glue", false):
			_paint.rect(r, Color(0.95, 0.75, 0.2, 0.8))  # wet glue: a glossy amber patch, outlined: this side grabs
			_paint.outline(r, Color(1.0, 0.9, 0.45, 0.95), 1.0)
			_paint.rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.97, 0.8, 0.95))
		if edge:
			if mods.has("heavy"):
				_paint.outline(r, Color(0.05, 0.05, 0.05, 0.6), 1.5)
			if (mods.has("weightless") or levitate_time > 0.0) and h % 3 == 0:
				_paint.outline(r, Color(0.85, 0.95, 1.0, 0.45), 1.0)  # a faint shimmer at the edges
			if mods.has("bouncy"):
				_paint.outline(r, Color(1.0, 0.5, 0.8, 0.5), 1.0)
		if mods.has("spiked"):
			for d in DIRS:
				if not cells.has(c + d) and h % 2 == 0:
					var out := Vector2(d)
					var side := Vector2(-out.y, out.x) * 2.0
					var b := cell_pos(c) + out * CELL * 0.5
					_paint.poly(PackedVector2Array([b - side, b + side, b + out * 5.0]), Color(0.7, 0.7, 0.72))
		if not _mod_looks.is_empty() and not cell.get("handle", false):
			_draw_static_looks(c, r, edge, m)
	if _mod_looks.has("headhunter") and cells.has(_tip):
		var tp := cell_pos(_tip)
		var hc: Color = MOD_LOOKS.headhunter[1]
		_paint.ring(tp, 3.5, 12, hc, 1.0)
		_paint.line(tp + Vector2(-5, 0), tp + Vector2(5, 0), hc, 1.0)
		_paint.line(tp + Vector2(0, -5), tp + Vector2(0, 5), hc, 1.0)
	if def.kind == "weapon":
		_draw_engravings()
	if (base_gravity == 0.0 and not has_meta("fall_gravity")) or levitate_time > 0.0:  # (not while falling to the Core: that's not magic)
		_paint.ring(center_of_mass, origin.length() * 0.5 + 4.0, 16, Color(0.55, 0.8, 1.0, 0.35), 1.0)
	if mods.has("volatile"):
		# a rune at the heart of it (the effects layer makes it pulse)
		var cc := center_of_mass
		_paint.line(cc + Vector2(-4, -4), cc + Vector2(4, 4), Color(0.6, 0.1, 0.05), 2.0)
		_paint.line(cc + Vector2(-4, 4), cc + Vector2(4, -4), Color(0.6, 0.1, 0.05), 2.0)


## The still part of a modifier's look, on one cell (see MOD_LOOKS).
func _draw_static_looks(c: Vector2i, r: Rect2, edge: bool, m: Dictionary) -> void:
	for mod in _mod_looks:
		var look: Array = MOD_LOOKS[mod]
		var col: Color = look[1]
		match look[0]:
			"tint":
				if edge:
					_paint.rect(r, Color(col, 0.4))
			"stripes":
				if (c.x + c.y) % 4 == 0:
					_paint.rect(r, Color(col, 0.45))
			"inset":
				if edge:
					var ic: Color = (m.color as Color).lightened(0.5) if mod == "kindred" else col
					_paint.outline(r.grow(-1.5), Color(ic, 0.7), 1.0)


## Material Texture: each material gets its own surface pattern so you can tell them
## apart at a glance: wood grain, a sheen that slides across metal as it turns, leather
## stitching, stone speckle, a weave on cloth, sparkle on gold and gems.
func _texture_cell(c: Vector2i, mat: String, r: Rect2, col: Color, t: float) -> void:
	var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
	match mat:
		"wood":
			_paint.line(r.position + Vector2(2 + (c.y % 2), 0), r.position + Vector2(2 + (c.y % 2), CELL), col.darkened(0.25), 1.0)
			if h % 23 == 0:
				_paint.circle(r.get_center(), 1.5, col.darkened(0.45))  # knot
		"copper", "iron", "steel":
			_paint.line(r.position + Vector2(0, CELL * 0.5), r.position + Vector2(CELL, CELL * 0.5), col.lightened(0.1), 1.0)
		"leather":
			if _is_edge(c) and (c.x + c.y) % 2 == 0:
				_paint.rect(Rect2(r.get_center() - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 0.75, 0.55))
		"stone":
			if h % 3 == 0:
				_paint.rect(Rect2(r.position + Vector2(h % 5, (h / 5) % 5), Vector2(1.5, 1.5)), col.lightened(0.3))
			if h % 4 == 0:
				_paint.rect(Rect2(r.position + Vector2((h / 7) % 5, h % 4), Vector2(1.5, 1.5)), col.darkened(0.35))
		"cloth":
			if (c.x + c.y) % 2 == 0:
				_paint.rect(r.grow(-1.5), col.darkened(0.12))
		"gold", "gem":
			pass  # sparkle is on the effects layer


## Everything that moves, drawn on the light effects layer. It samples a few cells from
## the cached lists rather than walking every cell.
func _draw_fx(cv: CanvasItem) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var half := Vector2(CELL, CELL) * 0.5
	# a swing leaves a smear of the blade behind it: ghosts of where it just was, fading
	if not _trail.is_empty():
		var blade_col: Color = Materials.get_mat(def.get("material", "wood")).color
		var inv := global_transform.affine_inverse()
		for i in _trail.size():
			var past: Transform2D = _trail[i]
			var a := 0.45 * (1.0 - float(i + 1) / float(_trail.size() + 1))
			var col := Color(blade_col.r, blade_col.g, blade_col.b, a).lightened(0.3)
			for c in cells:
				if cells[c].get("handle", false):
					continue
				var p: Vector2 = inv * (past * cell_pos(c))
				cv.draw_rect(Rect2(p - half, Vector2(CELL, CELL)), col)
	if _legendary and not _edges.is_empty():
		_draw_aura(cv, t, half)
	if _runed:
		# three bosses down: the inlaid runes glow
		var g := 0.45 + 0.3 * sin(t * 3.0)
		for c in _inlay_cells():
			cv.draw_rect(Rect2(cell_pos(c) - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.8, 0.4, g))
	if brace_time > 0.0 and not _edges.is_empty():
		# braced: the rim of the shield lit gold
		var a := brace_time / BRACE_TIME
		for e in _edges:
			cv.draw_rect(Rect2(cell_pos(e[0]) - half, Vector2(CELL, CELL)), Color(1.0, 0.85, 0.35, 0.55 * a), false, 1.5)
	if hit_flash > 0.0:
		for c in cells:
			if not cells[c].get("handle", false):
				cv.draw_rect(Rect2(cell_pos(c) - half, Vector2(CELL, CELL)), Color(1, 1, 0.9, hit_flash * 4.0))
	if rusting > 0.0 and not _edges.is_empty():
		for i in 1 + int(rusting * 3.0):
			var e: Array = _edges[(int(t * 3.0) + i * 7) % _edges.size()]
			cv.draw_rect(Rect2(cell_pos(e[0]) - Vector2(1, 1) + Vector2(e[1]) * 3.0, Vector2(2, 2)), Color(0.8, 0.4, 0.1, 0.7 * rusting))
	if _fuse >= 0.0 and int(_fuse * 20.0) % 2 == 0:
		for c in cells:
			cv.draw_rect(Rect2(cell_pos(c) - half, Vector2(CELL, CELL)), Color(1, 1, 1, 0.9))
	if is_burning() and not _tops.is_empty():
		for i in mini(8, _tops.size()):
			var c: Vector2i = _tops[randi() % _tops.size()]
			if not cells.has(c) or not Materials.get_mat(cells[c].mat).get("burns", false) and not _m_oiled:
				continue
			var fh := randf_range(3.0, 10.0)
			cv.draw_rect(Rect2(cell_pos(c) - half + Vector2(randf_range(0, CELL - 3), -fh), Vector2(3, fh)),
				Color(1.0, randf_range(0.4, 0.8), 0.1, 0.85))
	if charge > 0.1 and not _edges.is_empty():
		for i in 2 + int(charge * 4.0):
			var a := cell_pos(_edges[randi() % _edges.size()][0])
			var b := a + Vector2(randf_range(-9, 9), randf_range(-9, 9))
			cv.draw_line(a, b, Color(0.6, 0.85, 1.0, charge), 1.0)
			cv.draw_line(b, b + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(0.8, 0.95, 1.0, charge * 0.7), 1.0)
	# fast-moving items glint along their edges: they're parrying. A weapon also glints for a
	# moment when it's ready to swing again.
	var shine := maxf(speed_parry(), _ready_flash * 5.0)
	if shine > 0.05:
		for e in _edges:
			var d: Vector2i = e[1]
			var p := cell_pos(e[0])
			var o := Vector2(d) * CELL * 0.5
			var tt := Vector2(-d.y, d.x) * CELL * 0.5
			cv.draw_line(p + o - tt, p + o + tt, Color(1, 1, 0.85, minf(1.0, shine)), 2.0)
	var mods: Array = def.modifiers
	if _glue > 0:
		for c in _drips:
			if not cells.has(c) or not cells[c].get("glue", false):
				continue
			var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
			var drip := fmod(t * 0.7 + h * 0.13, 1.0) * 8.0
			cv.draw_rect(Rect2(cell_pos(c) + Vector2(-1, CELL * 0.5), Vector2(2, drip)), Color(0.85, 0.9, 0.3, 0.7))
	if mods.has("corrosive"):
		for c in _bubbles:
			var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
			var rise := fmod(t * 0.5 + h * 0.37, 1.0)
			cv.draw_circle(cell_pos(c) + Vector2(sin(t * 3.0 + h), -rise * 14.0), 1.5 * (1.0 - rise), Color(0.5, 1.0, 0.3, 0.8))
	if mods.has("regenerating"):
		for c in _sparkles:
			var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
			if fmod(t + h * 0.21, 2.0) < 0.15:
				cv.draw_rect(Rect2(cell_pos(c) - Vector2(1, 1), Vector2(2, 2)), Color(0.6, 1.0, 0.6))
	if mods.has("magnetic"):
		var pulse := fmod(t, 1.0)
		cv.draw_arc(center_of_mass, origin.length() * (0.6 + pulse * 0.8), 0.0, TAU, 24, Color(1.0, 0.3, 0.3, 0.3 * (1.0 - pulse)), 1.0)
	if mods.has("volatile"):
		var a := 0.5 + 0.5 * sin(t * 6.0)
		var cc := center_of_mass
		cv.draw_line(cc + Vector2(-4, -4), cc + Vector2(4, 4), Color(1, 0.2, 0.1, a), 2.0)
		cv.draw_line(cc + Vector2(-4, 4), cc + Vector2(4, -4), Color(1, 0.2, 0.1, a), 2.0)
	if not _mod_looks.is_empty():
		_draw_mod_looks(cv, t, half)
	_draw_kind_fx(cv, t)
	for c in _twinkly:  # gold and gems catch the light now and then
		if cells.has(c) and fmod(t * 1.5 + absi((c.x * 73856093) ^ (c.y * 19349663)) * 0.37, 3.0) < 0.12:
			cv.draw_rect(Rect2(cell_pos(c) - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 0.9))
	if not _sheeny.is_empty():
		# a band of light across the metal, by where each cell is on screen (which is linear
		# in the cell's place on the thing: a few multiplies a cell, no transform each)
		var xf := global_transform
		var kx := xf.x.x + xf.x.y
		var ky := xf.y.x + xf.y.y
		var k0 := xf.origin.x + xf.origin.y + xf.get_rotation() * 200.0
		for c in _sheeny:
			if not cells.has(c):
				continue
			var l := cell_pos(c)
			var band := fmod(kx * l.x + ky * l.y + k0, 90.0)
			if band < 10.0:
				cv.draw_rect(Rect2(l - half, Vector2(CELL, CELL)), Color(1, 1, 1, 0.35 * (1.0 - absf(band - 5.0) / 5.0)))


## The moving part of each modifier's look (see MOD_LOOKS), on the effects layer. Motes rise
## and drops fall the way the world's up and down are, however the thing is turned.
func _draw_mod_looks(cv: CanvasItem, t: float, half: Vector2) -> void:
	var up := Vector2.UP.rotated(-global_rotation)
	var across := Vector2(-up.y, up.x)
	for k in _mod_looks.size():
		var look: Array = MOD_LOOKS[_mod_looks[k]]
		var col: Color = look[1]
		var seed := k * 0.29
		match look[0]:
			"pulse":  # a heartbeat: two quick throbs along the edges, then rest
				var beat := fmod(t * 1.1 + seed, 1.0)
				var a := maxf(0.0, 1.0 - beat * 6.0) + 0.6 * maxf(0.0, 1.0 - absf(beat - 0.25) * 7.0)
				if a > 0.02:
					for e in _edges:
						cv.draw_rect(Rect2(cell_pos(e[0]) - half, Vector2(CELL, CELL)), Color(col, 0.4 * a))
			"breathe":
				var a := 0.1 + 0.1 * sin(t * 1.3 + seed * 10.0)
				for e in _edges:
					cv.draw_rect(Rect2(cell_pos(e[0]) - half, Vector2(CELL, CELL)), Color(col, a))
			"mote":
				for c in _bubbles:
					var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
					var rise := fmod(t * 0.45 + h * 0.37 + seed, 1.0)
					var p := cell_pos(c) + up * rise * 16.0 + across * sin(t * 2.0 + h) * 2.0
					cv.draw_circle(p, 1.5 * (1.0 - rise) + 0.3, Color(col, 0.8 * (1.0 - rise)))
			"drip":
				for c in _drips:
					var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
					var fall := fmod(t * 0.6 + h * 0.21 + seed, 1.0)
					cv.draw_rect(Rect2(cell_pos(c) - up * (CELL * 0.5 + fall * 10.0) - Vector2(1, 1), Vector2(2, 2)), Color(col, 0.85 * (1.0 - fall)))
			"orbit":
				var r := origin.length() * 0.55 + 6.0
				for i in 3:
					var ang := t * 2.5 + seed * 7.0 - i * 0.3
					cv.draw_circle(center_of_mass + Vector2(cos(ang), sin(ang)) * r, 2.4 - i * 0.7, Color(col, 0.9 - i * 0.3))
			"spark":
				if fmod(t * 1.7 + seed, 1.0) < 0.3 and cells.has(_tip):
					var tp := cell_pos(_tip)
					for i in 3:
						var b := tp + Vector2(randf_range(-7, 7), randf_range(-7, 7))
						cv.draw_line(tp, b, Color(col, 0.9), 1.0)
			"sweep":  # a sheen running across it now and then
				var sw := fmod(t * 0.5 + seed, 2.0)
				if sw < 1.2:
					var span := maxf(1.0, 2.0 * (origin.x + origin.y))
					for c in cells:
						var v := cell_pos(c) + origin
						if absf((v.x + v.y) / span - (sw - 0.1)) < 0.06:
							cv.draw_rect(Rect2(cell_pos(c) - half, Vector2(CELL, CELL)), Color(col, 0.45))
			"glint":
				for c in _sparkles:
					var h: int = absi((c.x * 73856093) ^ (c.y * 19349663))
					var ph := fmod(t * 0.8 + h * 0.37 + seed, 2.5)
					if ph < 0.3:
						var sz := sin(ph / 0.3 * PI) * 3.5
						var p := cell_pos(c)
						cv.draw_line(p - Vector2(sz, 0), p + Vector2(sz, 0), col, 1.0)
						cv.draw_line(p - Vector2(0, sz), p + Vector2(0, sz), col, 1.0)
			"flicker":
				if not _edges.is_empty():
					for i in 2:
						if randf() < 0.35:
							var e: Array = _edges[randi() % _edges.size()]
							cv.draw_rect(Rect2(cell_pos(e[0]) + Vector2(e[1]) * 3.5 - Vector2(1, 1), Vector2(2, 2)), Color(col, 0.9))
			"shift":  # an edge running through every colour: it could be anything
				for i in _edges.size():
					var e: Array = _edges[i]
					var d: Vector2i = e[1]
					var p := cell_pos(e[0])
					var o := Vector2(d) * CELL * 0.5
					var tt := Vector2(-d.y, d.x) * CELL * 0.5
					cv.draw_line(p + o - tt, p + o + tt, Color.from_hsv(fmod(t * 0.2 + i * 0.015, 1.0), 0.6, 1.0, 0.6), 1.0)
			"halo":
				var top := center_of_mass + up * (origin.length() * 0.6 + 8.0)
				var pts := PackedVector2Array()
				for i in 17:
					var a := TAU * i / 16.0
					pts.append(top + across * cos(a) * 9.0 + up * sin(a) * 3.0)
				cv.draw_polyline(pts, Color(col, 0.55 + 0.2 * sin(t * 2.0)), 1.5)


## A triangle list with a colour a vertex: the item's still look, built in _draw and drawn
## as one mesh. rect, line, outline, circle, ring and poly stand in for the CanvasItem draws.
class Paint:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()

	func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
		verts.append(a)
		verts.append(b)
		verts.append(c)
		cols.append(col)
		cols.append(col)
		cols.append(col)

	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
		tri(a, b, c, col)
		tri(a, c, d, col)

	func rect(r: Rect2, col: Color) -> void:
		var e := r.end
		quad(r.position, Vector2(e.x, r.position.y), e, Vector2(r.position.x, e.y), col)

	func line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
		var d := b - a
		var l := d.length()
		if l < 0.001:
			return
		var n := Vector2(-d.y, d.x) * (maxf(width, 1.0) * 0.5 / l)
		quad(a + n, b + n, b - n, a - n, col)

	## A stroke of `width` centred on the rectangle's edges (draw_rect unfilled).
	func outline(r: Rect2, col: Color, width: float) -> void:
		var h := width * 0.5
		rect(Rect2(r.position.x - h, r.position.y - h, r.size.x + width, width), col)
		rect(Rect2(r.position.x - h, r.end.y - h, r.size.x + width, width), col)
		rect(Rect2(r.position.x - h, r.position.y + h, width, r.size.y - width), col)
		rect(Rect2(r.end.x - h, r.position.y + h, width, r.size.y - width), col)

	func circle(c: Vector2, radius: float, col: Color, segs: int = 8) -> void:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			tri(c, c + Vector2(cos(a0), sin(a0)) * radius, c + Vector2(cos(a1), sin(a1)) * radius, col)

	func ring(c: Vector2, radius: float, segs: int, col: Color, width: float) -> void:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			line(c + Vector2(cos(a0), sin(a0)) * radius, c + Vector2(cos(a1), sin(a1)) * radius, col, width)

	## A convex polygon, as a fan from its first point.
	func poly(pts: PackedVector2Array, col: Color) -> void:
		for i in range(1, pts.size() - 1):
			tri(pts[0], pts[i], pts[i + 1], col)

	func mesh() -> ArrayMesh:
		if verts.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## The effects layer: a child canvas that draws the item's moving effects on top of it.
class Fx:
	extends Node2D

	var item: Item

	func _draw() -> void:
		if item and is_instance_valid(item):
			item._draw_fx(self)


func _is_edge(c: Vector2i) -> bool:
	for d in DIRS:
		if not cells.has(c + d):
			return true
	return false
