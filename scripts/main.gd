class_name Main
extends Node
## Bulwark mechanics prototype.
## A 3D enemy stands in front of the camera; a 2D physics play field sits on top of it.
## Enemy attacks cover screen zones, and whatever items sit in a zone when it lands
## soak the hit cell by cell. Fast-moving items parry. Weapons hit specific body parts.
## There is no HUD: money is coins in the pile, health is the state of the hand, the
## enemy wears its wounds, and the shop is shelves you pay by putting coins on them.
##
## The game starts at home: a homestead where your kept gear hangs on racks, a codex on
## the table, and a gong. Ring it (holding something to bring along) and the run begins:
## five stages, the fifth a boss. Beat the boss and the shop grows a door home: walk
## through it holding one thing and that thing is yours to keep. Or ring the gong and
## prestige: everything deeper, rarer and harder.

enum State { HOME, COMBAT, VICTORY, SHOP, DEFEAT }

const SCREEN := Vector2(1280, 720)
const SAMPLE_STEP := 14.0
const DEBRIS_CAP := 160
const BODY_CAP := 240   # absolute backstop: past this, the smallest fragments are cleared (never coins)
const COIN_BODIES := 30  # past this many loose coins in the pile, five small ones fuse into one big one
const COIN_MERGES := 12  # fusions per second, so a hoard condenses over a few seconds rather than at once
const SHAKE_CAP := 30.0
const PUNCH_DAMAGE := 3.0
const SHIELD_STAGGER := 2.0  # stagger from blows a shield took the brunt of
# A plain weapon hits soft. The big numbers come from what you've done to it (each element
# or infusion multiplies it), the rings you build around it, and the openings your blocks
# make. Weapon hits barely fill the stagger meter: blocking is what breaks an enemy.
const WEAPON_DAMAGE := 0.8
const INFUSIONS := ["electrified", "superheated", "frosty", "poisoned", "corrosive"]
const INFUSED_BONUS := 1.35
const WEAPON_STAGGER := 0.2
const PUNCH_STAGGER := 0.5
const LANE_IMPACT := 1.4  # cell damage where a blade meets an item, times the attack's impact
const CLEAN_BLOCK := 0.15  # leak below this throws the enemy off balance
const OFF_BALANCE_TIME := 1.4
const HAND_CAUGHT := 0.25  # extra damage share when the blade reaches the hand itself
# A blow that's mostly stopped is checked: what slips past the open lanes has lost most of
# its force. What gets through is scaled by 1 - CHECK x (share stopped), so catching two
# lanes of three leaves the third a glancing hit, not a full one.
const CHECK := 0.75
const BLOCK_SHOCK := 6.0  # a charged piece's shock when it's struck...
const BLOCK_SHOCK_SHARE := 0.6  # ...plus this much of the damage it stopped
const SHIELD_SWING_PARRY := 0.2  # a shield is too heavy to parry by swinging: brace it instead
const PREVIEW_EVERY := 4  # frames between live lane-coverage previews
const AVENGE_TIME := 3.0  # Avenging: how long a parry's vengeance waits for the next hit
const WISP_SPEED := 0.25  # Wisp Cannon: how fast it has to move to fire (its parry-glint scale)
const WISP_EVERY := 0.45
const WISP_DAMAGE := 4.0
const WISP_FLIGHT := 900.0
const JAVELIN_SPEED := 650.0  # Javelin: let go faster than this (px/s) and it's thrown
const JAVELIN_FLIGHT := 1.2  # how long a thrown one can still hit
const BATON_TIME := 4.0
const REST_PER_SEC := 0.5
const REST_MAX := 4.0
const LIGHTNING_ROD_BOLT := 10.0
const RECKLESS_WEAR := 3.0
const CRITICAL_HURT := 0.75  # the hand below a quarter: the music closes in
const BLOOD_PRICE := 4.0  # Blood Price: what each hit cuts from your own hand
const BLOODLET := 10.0  # Ring of Bloodletting: the cut
const SOOTHE := 2.0  # soothing: healing a second, held in a fight
const SECOND_WIND := 35.0
const SHIRT_EVERY := 2.0  # Hair Shirt: a point of chafing this often
const SHIRT_BONUS := 1.4
var _second_wind_used := false
var _shirt_t := 0.0
var hoard_shirt := false  # a Hair Shirt in the pile
const COUNTER_CAP := 80.0
const RALLY_TIME := 3.0
const STORM_TIME := 3.0  # how long a Stormcaller's elemental storm rages on a foe
const STORM_TICK := 0.25
const STORM_DAMAGE := 4.0  # per tick
# Element reactions: anything elemental that reaches a foe marks it for MARK_TIME; a
# different element landing on a marked foe sets the pair off (once every REACT_COOLDOWN).
const MARK_TIME := 5.0
const CHANDELIER_DAMAGE := 35.0
# The fight bonus: a fight's coin reward goes up the faster it's won and the less of your
# hand it cost. Par time grows with the foes' total health.
const PAR_BASE := 20.0  # seconds, plus PAR_PER_HP for every point of foe health
const PAR_PER_HP := 0.08
const SPEED_BONUS := 0.5  # won in half the par time: +50% (nothing past 1.5x par)
const HEALTH_BONUS := 0.6  # 5% of the hand or less lost: +60% (nothing past 50%)
const DAMAGE_SOUND_TAKEN := 30.0  # a hit to the hand this big gets the pain sting at full volume
const DAMAGE_SOUND_DEALT := 60.0  # and a hit on a foe this big, the reward sting
const REACT_COOLDOWN := 1.5
const VULNERABLE := 1.5  # weapon hits on a foe left vulnerable by a reaction
const REACTIONS := {
	"fire+frost": {"name": "THERMAL SHOCK", "desc": "a big burst of damage; both elements are spent"},
	"fire+storm": {"name": "OVERLOAD", "desc": "an explosion that staggers the foe outright"},
	"frost+storm": {"name": "SUPERCONDUCT", "desc": "its armour cracks and it's vulnerable (x1.5) for 5s"},
	"fire+venom": {"name": "TOXIC BLAZE", "desc": "it's set alight and poisoned for 12s"},
	"frost+venom": {"name": "BRITTLE", "desc": "it's slowed and vulnerable (x1.5) for 5s"},
	"storm+venom": {"name": "NEUROTOXIN", "desc": "its swing seizes up, and it's slowed for 4s"},
	"fire+rot": {"name": "SLAG", "desc": "its armour melts away, and the molten metal burns (through armour)"},
	"frost+rot": {"name": "FROSTBITE", "desc": "damage, and it's slowed for 4s"},
	"rot+storm": {"name": "GALVANIC", "desc": "a jolt through its rotten plate: the more armour, the worse"},
	"rot+venom": {"name": "BLIGHT", "desc": "poisoned for 15s and its armour eaten through"},
}
const STORM_NAMES := {"fire": "FIRESTORM", "frost": "BLIZZARD", "venom": "ACID RAIN", "rot": "RUST STORM", "storm": "THUNDERHEAD"}
const ELEMENT_COLORS := {"fire": Color(1.0, 0.55, 0.15), "frost": Color(0.7, 0.9, 1.0), "venom": Color(0.55, 0.95, 0.3),
	"rot": Color(0.65, 0.5, 0.25), "storm": Color(0.6, 0.85, 1.0), "": Color(1.0, 0.65, 0.25)}
const MAGNET_CATCH := 26.0  # px from the nearest cell: a magnetic item draws the blade to it from this far off
const STARTING_COINS := 10
const SHELF_Y := 270.0  # top of the shop shelves
const SHELF_W := 140.0
const SHOP_GEAR := 4  # gear shelves; then a stat shelf and two ring shelves
const GONG := {"pos": Vector2(1190, 330), "radius": 42.0}
const DICE := {"pos": Vector2(1190, 225), "radius": 26.0}  # punch to reroll the shop
const CHUTE := {"pos": Vector2(640, 52), "radius": 38.0}  # shop: feed it scraps, it pays for metal
# What a cell of scrap is worth down the chute, in coins (anything not listed is just gone).
const SCRAP_VALUE := {"copper": 0.1, "iron": 0.15, "steel": 0.25, "gold": 1.0, "gem": 1.0}
const DOOR := {"pos": Vector2(1190, 120), "radius": 40.0}  # after a boss: go home with what you hold
const WATER_Y := 625.0  # Cistern: the floodwater's surface
const HEARTH := Rect2(220, 80, 450, 240)  # Forge: hold metal here to heat it
# Home: the gong hangs by the door, weapons go on the rack, everything else on the shelves
const HOME_COLLECTIONS := [["codex", "leather"], ["rune_tablet", "stone"], ["bestiary", "bone"], ["wall_map", "cloth"], ["journal", "leather"]]
const HOME_GONG := {"pos": Vector2(1215, 260), "radius": 42.0}
const RACK_SLOTS := [Vector2(70, 150), Vector2(160, 150), Vector2(250, 150), Vector2(340, 150)]
const SHELF_SLOTS := [Vector2(995, 150), Vector2(1070, 150), Vector2(1145, 150), Vector2(860, MANTEL_Y - 28.0), Vector2(945, MANTEL_Y - 28.0), Vector2(1030, MANTEL_Y - 28.0)]
const MANTEL_Y := 302.0  # the top of the 3D mantel over the hearth, on screen: the lower shelf row sits on it
const SMELT_PURSE := 10.0  # scrap value melted in the home hearth for one Coin Purse
const SNAP_REACH := 55.0

var state := State.HOME
var round_num := 0
var prestige := 0  # bosses beaten this run
var rng := RandomNumberGenerator.new()

var camera: Camera3D
var world3d: Node3D
var env: Environment
var torch: OmniLight3D
var styles: StyleManager
var backdrop: Backdrop
var looks: Looks
var liquids: Liquids
var enemy: Enemy  # the first still standing (there can be two)
var enemies: Array[Enemy] = []
var overlay: ZoneOverlay
var items_root: Node2D
var hand: Hand
var ui: CanvasLayer
var codex: Codex
var save: SaveData
var debug_label: Label  # F1: developer readout, hidden by default
var shelves: Array = []  # {rect, price, paid, item, body, kind}
var racks: Array = []    # home: {pos, kind, item}
var _state_timer := 0.0
var _gong_struck := false
var explosions := 0  # running count, for tests and tuning
var rerolls := 0       # this shop visit
var secret_next := false  # the hidden lever was pulled: the next fight is in the Hidden Vault
var secret_stage := ""  # a secret place unlocked this run (secrets.gd): the next ordinary fight is there
var _stars_caught := 0  # this fight's falling stars (the way into the Clockwork Orrery)
var _next_plan: Dictionary = {}  # the next fight, rolled when the shop opens (see _plan_fight)
var scrying: Scrying  # the shop gong's face, showing it
var _fight_start := 0.0  # when this fight began (clock)
var _fight_taken := 0.0  # what got through to the hand this fight
var _fight_base := 0  # the foes' coin rewards, for the bonus
var _fight_par := 30.0
var _fight_reactions: Array = []  # different reactions set off this fight (the way into the Ink Margin)
var _chute_gold := 0  # gold fed down the chute this shop visit (the way into the Gilded Gullet)
var _tooth_given := false
var _last_foe_def: Dictionary = {}  # the last ordinary foe fought: the Errata is a misprint of it
var _quake := 0.0  # Giant's Table: time to the next footstep
var _rain := 0.0  # Gilded Gullet: time to the next fall of coin
var _glint := 0.0
var free_rerolls := 0  # from horseshoes
var _debris_check := 0.0
var _shake := 0.0
var _bone_timer := 0.0  # Ossuary: bones drop now and then
# What the pile is worth right now (hoard utilities): refreshed every second
var hoard_wear := 1.0     # Trophy Pegs: gear wear from blows
var hoard_stagger := 1.0  # War Banner: stagger from blocks
var hoard_ward := 0.0     # Sentinel Stones: how much of the gap a piece you aren't holding closes
const WARD_PER := 0.12
const WARD_MAX := 6
var hoard_damage := 1.0   # Packrat Idol: weapon damage
var popups: Popups  # damage numbers
var _scrap_bank := 0.0
var _wisps: Array = []  # Wisp Cannon fire in flight: {pos, vel, target, dmg}
var props: Props  # the stage's usable things: element sources, chandeliers, altars, secrets
var _prop_tick := 0.0
var clock := 0.0  # game time in seconds: stops while paused
var _last_held: Item  # what the hand held last frame (rare modifiers that care about swapping)
var _prev_weapon: Item  # the weapon held before the current one: Mimic copies it
var _counter_bank := 0.0  # Riposte Guard: damage shields banked for the next weapon hit
var _rally_until := 0.0
var _storms: Array = []  # Stormcaller storms raging on a foe: {enemy, kind, t, tick}
var _last_blocked := 0.0  # Ring of Echoes: how hard the last blow you blocked was  # scrap value fed to the chute, not yet paid out as a whole coin


func _ready() -> void:
	rng.randomize()
	add_to_group("game")
	Settings.apply()
	add_child(Sfx.new())
	add_child(Music.new())
	save = SaveData.load_file()
	_build_3d()
	_build_2d()
	styles = StyleManager.new()
	add_child(styles)
	styles.setup(self)
	add_child(PauseMenu.new())
	looks = Looks.new()
	add_child(looks)
	looks.changed.connect(_on_look_changed)
	codex = Codex.new()
	add_child(codex)
	codex.setup(self)
	_go_home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and state == State.HOME:
		_save_home()


func _exit_tree() -> void:
	if state == State.HOME and is_instance_valid(hand):
		_save_home()


# --- setup -------------------------------------------------------------------

func _build_3d() -> void:
	world3d = Node3D.new()
	add_child(world3d)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.2)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.035)
	env.fog_density = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	world3d.add_child(we)
	torch = OmniLight3D.new()
	torch.position = Vector3(0.9, 2.2, 1.0)
	torch.light_color = Color(1.0, 0.7, 0.4)
	torch.light_energy = 2.5
	torch.omni_range = 5.0
	world3d.add_child(torch)
	# framed waist-up: the head and hands are the show
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0, 1.45, 1.5)
	world3d.add_child(camera)


func _build_2d() -> void:
	overlay = ZoneOverlay.new()
	add_child(overlay)
	props = Props.new()
	props.game = self
	add_child(props)  # under the items: a piece held in a torch sits in front of its flame
	items_root = Node2D.new()
	add_child(items_root)
	_add_walls()
	liquids = Liquids.new()
	liquids.z_index = 5
	add_child(liquids)
	liquids.setup(self)
	hand = Hand.new()
	hand.z_index = 50
	hand.process_mode = Node.PROCESS_MODE_ALWAYS  # it moves while the game is frozen for inspecting
	add_child(hand)
	hand.activated.connect(_on_item_activated)
	hand.buy_attempt.connect(_on_buy_attempt)
	hand.punched.connect(_on_punched)
	hand.knock = _knock_holding
	hand.on_hurt = _hand_hurt
	popups = Popups.new()
	add_child(popups)
	hand.hurt_taken.connect(func(a: float) -> void:
		popups.number(hand.position + Vector2(0, -34), a, Color(1.0, 0.25, 0.2), true)
		_damage_sound(a, true)
		if state == State.COMBAT:
			_fight_taken += a)
	hand.ring_used.connect(_on_ring_used)
	hand.released.connect(_on_released)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	debug_label = Label.new()
	debug_label.position = Vector2(12, 8)
	debug_label.visible = false
	ui.add_child(debug_label)
	add_child(Tooltip.new())


func _add_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var t := 200.0
	for r in [Rect2(-t, SCREEN.y, SCREEN.x + 2 * t, t), Rect2(-t, -t, t, SCREEN.y + 2 * t),
			Rect2(SCREEN.x, -t, t, SCREEN.y + 2 * t), Rect2(-t, -t, SCREEN.x + 2 * t, t)]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.get_center()
		body.add_child(cs)
	add_child(body)


func _spawn(d: Dictionary, pos: Vector2) -> Item:
	var it := Item.create(d)
	it.position = pos
	items_root.add_child(it)
	it._ensure_glue()
	_discover(d)
	return it


## The codex remembers everything you've laid eyes on.
func _discover(d: Dictionary) -> void:
	if d.has("id") and d.get("kind", "") != "coin":
		save.discover("items", d.id if d.kind != "upgrade" else d.upgrade)
	for m in d.get("modifiers", []):
		save.discover("modifiers", m)


func _spawn_starting_kit() -> void:
	var spots := [Vector2(380, 560), Vector2(640, 520), Vector2(900, 600)]
	var kit := ItemDefs.roll_kit(rng)
	for i in kit.size():
		if kit[i].has("coins"):
			_spawn_coins(kit[i].coins, spots[i], 80.0)
		else:
			_spawn(kit[i], spots[i])
	_spawn_coins(STARTING_COINS, Vector2(760, 640), 120.0)


## Coins are real gold objects: gold bars are worth 25, fat coins 5, small ones 1.
func _spawn_coins(value: int, at: Vector2, spray: float) -> void:
	var bars := int(value / 25.0)
	var fives := int((value % 25) / 5.0)
	for i in bars + fives + value % 5:
		var id := "coin25" if i < bars else "coin5" if i < bars + fives else "coin"
		var c := _spawn(ItemDefs.make(id, "gold"), at + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
		c.linear_velocity = Vector2(randf_range(-1.0, 1.0) * spray, -randf_range(0.3, 1.0) * spray * 2.0)
		c.angular_velocity = randf_range(-8, 8)


func coin_value(it: Item) -> int:
	return int(it.def.get("value", 0)) if it.def.kind == "coin" else 0


# --- home --------------------------------------------------------------------

## Home: the gear you've kept, on its racks; the codex and the mirror on the wall; the
## gong by the door. Nothing here can hurt you. `carry` is something brought back from a run.
func _go_home(carry: Item = null) -> void:
	state = State.HOME
	_end_scrying()
	_next_plan = {}
	Music.set_mode(Music.Mode.AMBIENT)
	round_num = 0
	prestige = 0
	ItemDefs.run_prestige = 0
	secret_next = false
	_clear_enemies()
	_clear_shop()
	for it in items_root.get_children():
		if it is Item and it != carry:
			it.queue_free()
	_set_backdrop("Homestead")
	overlay.gong = HOME_GONG
	overlay.door = {}
	overlay.dice = {}
	overlay.chute = {}
	_gong_struck = false
	racks.clear()
	for p in RACK_SLOTS:
		racks.append({"pos": p, "kind": "weapon", "item": null})
	for p in SHELF_SLOTS:
		racks.append({"pos": p, "kind": "any", "item": null, "mantel": p.y > 200.0})
	overlay.racks = racks
	hand.reset_run()  # a fresh hand (this lets go of what it carried: it drops here, yours)
	# the collections hang in a row along the top wall (hung up high: the floor fills up)
	for k in HOME_COLLECTIONS.size():
		var c: Array = HOME_COLLECTIONS[k]
		_spawn(ItemDefs.make(c[0], c[1]), Vector2(470 + k * 80, 100)).freeze = true
	_spawn(ItemDefs.make("mirror", "copper"), Vector2(450, 250)).freeze = true
	props.setup("Homestead", 0)
	for e in save.home:
		var d := SaveData.unpack(e)
		if d.is_empty():
			continue
		var it := _spawn(d, e.get("pos", Vector2(640, 600)))
		it.rotation = float(e.get("rot", 0.0))
		SaveData.apply_health(it, float(e.get("health", 1.0)))
		var slot := int(e.get("slot", -1))
		if slot >= 0 and slot < racks.size() and racks[slot].item == null:
			call_deferred("_slot_item", it, slot)
	if carry:
		carry.set_meta("kept", true)
		_save_home()


## Write the home down: every item in it, where it sits, and how worn it is.
func _save_home(leaving: Item = null) -> void:
	var out: Array = []
	for n in items_root.get_children():
		var it := n as Item
		if it == null or it == leaving or it.is_queued_for_deletion() or not it.owned:
			continue
		if it.def.kind in ["menu", "debris"]:
			continue
		var e := SaveData.pack(it)
		e.slot = -1
		for i in racks.size():
			if racks[i].item == it:
				e.slot = i
		out.append(e)
	save.home = out
	save.write()


## Hang something on a rack slot.
func _slot_item(it: Item, i: int) -> void:
	if not is_instance_valid(it) or it.is_queued_for_deletion():
		return
	var slot: Dictionary = racks[i]
	slot.item = it
	it.set_meta("slotted", true)
	it.freeze = true
	it.rotation = 0.0
	it.teleport(slot.pos)


## Let go of something at home near a free slot and it hangs itself there.
func _on_released(it: Item) -> void:
	if it and is_instance_valid(it):
		it.remove_meta("thrown")
		if state == State.COMBAT and _has(it, "javelin") and it.linear_velocity.length() > JAVELIN_SPEED:
			it.swing_time = JAVELIN_FLIGHT  # it's in flight: it can still hit
			it.swing_hit = false
			it.set_meta("thrown", true)
	if state != State.HOME or it == null or not is_instance_valid(it) or it.def.kind == "menu":
		return
	var best := -1
	var best_d := SNAP_REACH
	for i in racks.size():
		var slot: Dictionary = racks[i]
		if slot.item != null and is_instance_valid(slot.item) and slot.item != it:
			continue
		if slot.kind == "weapon" and it.def.kind != "weapon":
			continue
		var d: float = slot.pos.distance_to(it.global_position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_slot_item(it, best)
		overlay.ring(racks[best].pos, 30.0, Color(1, 0.9, 0.6), 0.25)
		Sfx.play("clack", -8.0, 1.2)


## Ring the gong at home: the run begins. Whatever's in your hand comes with you.
func _start_run() -> void:
	save.tally("runs")
	var carry := hand.held
	_save_home(carry)
	for it in items_root.get_children():
		if it is Item and it != carry:
			it.queue_free()
	for slot in racks:
		slot.item = null
	racks.clear()
	overlay.racks = racks
	if carry:
		carry.set_meta("kept", true)
		carry.set_meta("slotted", false)
	round_num = 0
	prestige = 0
	ItemDefs.run_prestige = 0
	_spawn_starting_kit()
	_start_fight()


## Through the door after a boss, holding one thing: home, and it's yours for good.
func _return_home() -> void:
	var carry := hand.held
	if carry == null or not carry.owned:
		return
	save.prestige_best = maxi(save.prestige_best, prestige + 1)
	overlay.ring(DOOR.pos, 80.0, Color(1, 0.9, 0.6), 0.6)
	Sfx.play("gong", -4.0, 1.4)
	_go_home(carry)


# --- flow --------------------------------------------------------------------

## Each fight happens somewhere: settings cycle with the round (F9 flips through them).
func _set_backdrop(name: String) -> void:
	if backdrop:
		backdrop.queue_free()
	var late: bool = Backdrop.TIERS.late.has(name)
	backdrop = Backdrop.create(name, late and rng.randf() < 0.5)
	world3d.add_child(backdrop)
	styles.set_base_env(Backdrop.ENV[name])
	styles.set_world_look(Backdrop.LOOK[name])
	styles.set_dark(name == "Catacombs")  # the catacombs are pitch dark: bring the light
	save.discover("places", name)


func setting() -> String:
	return backdrop.setting if backdrop else ""


## Middle and late settings put things in the scene you can take for free. Fixtures that
## are never picked up stay behind when the fight ends. Everything goes in the top half of
## the screen: the bottom fills up with the pile on a long run.
func _add_features() -> void:
	match setting():
		"Catacombs":
			_fixture(ItemDefs.make("lantern", "iron"), Vector2(110, 230), true)
			_fixture(ItemDefs.make("skull", "bone"), Vector2(1150, 150), false)
			_fixture(ItemDefs.make("skull", "bone"), Vector2(1190, 150), false)
		"Crypt Chapel":
			_fixture(ItemDefs.make("reliquary", "steel"), Vector2(1100, 200), true)
		"Hidden Vault":
			_fixture(ItemDefs.make("reliquary", "steel"), Vector2(1100, 200), true)
			var rings := ItemDefs.ring_ids()
			_fixture(ItemDefs.make_upgrade(rings[rng.randi() % rings.size()]), Vector2(160, 180), true)
			_spawn_coins(15, Vector2(640, 300), 200.0)
		"Forge":
			_fixture(ItemDefs.make("smith_hammer", "iron"), Vector2(1130, 210), true)
			if rng.randf() < 0.6:
				var pick: Array = [["longsword", "iron"], ["mace", "iron"], ["spear", "steel"], ["shortsword", "steel"]][rng.randi() % 4]
				_fixture(ItemDefs.make(pick[0], pick[1]), Vector2(1020, 200), true)  # on the rack
		"Ossuary":
			for i in 3:
				_fixture(ItemDefs.make("skull", "bone"), Vector2(1100 + i * 40, 150), false)
			_fixture(ItemDefs.make("reliquary", "steel"), Vector2(180, 200), true)
		"Star Chamber":
			_fixture(ItemDefs.make("potion_levitation", "glass"), Vector2(1150, 200), true)
		"Gilded Gullet":
			_secret_prize(["magnetic"])
			_fixture(ItemDefs.make("coin25", "gold"), Vector2(180, 200), true)
		"Giant's Table":
			_secret_prize(["large"])
		"Clockwork Orrery":
			_secret_prize(["electrified"])
		"Ink Margin":
			_secret_prize(["poisoned"])


func _fixture(d: Dictionary, at: Vector2, hanging: bool) -> Item:
	var it := _spawn(d, at)
	it.set_meta("fixture", true)
	if hanging:
		it.freeze = true  # hangs on its hook until you take it
	return it


func _clear_untaken_fixtures() -> void:
	for n in get_tree().get_nodes_in_group("items"):
		if n.has_meta("fixture") and not n.has_meta("taken"):
			n.queue_free()


## Cistern floodwater: things float and slow down, fire goes out (red-hot metal gets
## quenched, which tempers it), and charge spreads through the water, hand included.
## Forge hearth: things held in it heat up. Star Chamber: nothing weighs much. Ossuary:
## bones drop from the ceiling now and then.
func _setting_physics(delta: float) -> void:
	match setting():
		"Cistern":
			var wet: Array[Item] = []
			var volts := 0.0
			for n in get_tree().get_nodes_in_group("items"):
				var it := n as Item
				if it == null or it.freeze or it.is_queued_for_deletion() or it.global_position.y < WATER_Y:
					continue
				wet.append(it)
				it.apply_central_force(Vector2(0, -it.mass * 980.0 * 0.6))
				it.linear_velocity *= 0.96
				it.angular_velocity *= 0.96
				if it.heat > 0.3:
					it.cold = maxf(it.cold, 0.3)  # quench
				it.heat *= 0.9
				volts = maxf(volts, it.charge)
			if volts > 0.5:
				for it in wet:
					it.charge = maxf(it.charge, volts * 0.8)
				if hand.position.y > WATER_Y and not hand.has_ring("ring_grounding"):
					hand.injury = minf(hand.max_hp, hand.injury + volts * 8.0 * delta)
					hand.hazard_time = 0.2
		"Forge":
			for n in get_tree().get_nodes_in_group("items"):
				var it := n as Item
				if it and not it.freeze and HEARTH.has_point(it.global_position):
					it.heat = minf(1.0, it.heat + 0.35 * delta)
		"Star Chamber":
			for n in get_tree().get_nodes_in_group("items"):
				var it := n as Item
				if it and not it.freeze and not it.is_queued_for_deletion():
					it.apply_central_force(Vector2(0, -it.mass * 980.0 * 0.85))
					it.linear_velocity *= 0.995
		"Gilded Gullet":
			# gold rains down the throat now and then: yours if you can keep it from the golem
			_rain -= delta
			if _rain <= 0.0:
				_rain = rng.randf_range(4.0, 7.0)
				_spawn_coins(rng.randi_range(2, 5), Vector2(rng.randf_range(200, 1080), -20), 40.0)
		"Giant's Table":
			# the giant walks past: the whole table jumps
			_quake -= delta
			if _quake <= 0.0:
				_quake = rng.randf_range(6.0, 9.0)
				_shake += 14.0
				Sfx.play("boom", -4.0, 0.4)
				for n in get_tree().get_nodes_in_group("items"):
					var it := n as Item
					if it and not it.freeze and not it.held:
						it.apply_central_impulse(Vector2(rng.randf_range(-120, 120), -rng.randf_range(250, 450)) * it.mass)
			# the cat can't help itself: a gold coin flying past makes it drop its swing
			for e in living():
				if e.data.get("distractible", false) and e.state == "windup":
					for n in get_tree().get_nodes_in_group("items"):
						var c := n as Item
						if c and c.def.kind == "coin" and c.linear_velocity.length() > 450.0:
							e.stagger()
							popups.word(camera.unproject_position(e.head.global_position) + Vector2(0, -40), "!", Color(1.0, 0.85, 0.3))
							break
		"Clockwork Orrery":
			# light gravity, and the planets sweep through on their arms, batting things aside
			for n in get_tree().get_nodes_in_group("items"):
				var it := n as Item
				if it == null or it.freeze or it.is_queued_for_deletion():
					continue
				it.apply_central_force(Vector2(0, -it.mass * 980.0 * 0.5))
				for pl in planets():
					var d: Vector2 = it.global_position - pl.pos
					if d.length() < pl.r + 20.0:
						it.apply_central_impulse((d.normalized() + pl.vel.normalized() * 0.5) * it.mass * 30.0)
		"Ink Margin":
			# the floor is wet ink: what lies in it drags
			for n in get_tree().get_nodes_in_group("items"):
				var it := n as Item
				if it and not it.freeze and it.global_position.y > 600.0:
					it.linear_velocity *= 0.9
					it.angular_velocity *= 0.9
		"Ossuary":
			_bone_timer -= delta
			if _bone_timer <= 0.0:
				_bone_timer = rng.randf_range(6.0, 11.0)
				var b := _spawn(ItemDefs.make("skull", "bone"), Vector2(rng.randf_range(100, 1180), -20))
				b.angular_velocity = rng.randf_range(-6, 6)


func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	enemy = null


## What a fight will be: where, against whom. Rolled when the shop opens (so its gong can
## show it) and used when the fight starts; rolled fresh if something changed in between
## (a secret opened in the shop). The Hidden Vault and the secret places come first; a
## secret never takes a boss's place.
func _plan_fight(r: int, p: int) -> Dictionary:
	var vault := secret_next
	var hidden: String = secret_stage if (not vault and secret_stage != "" and r % EnemyDefs.STAGES != EnemyDefs.BOSS_STAGE) else ""
	var place: String = "Hidden Vault" if vault else (hidden if hidden != "" else Backdrop.for_round(r, rng, p))
	var defs: Array
	if vault:
		defs = [EnemyDefs.WARDEN.duplicate(true)]
	elif hidden != "":
		defs = [_guardian(hidden, p)]
	else:
		defs = EnemyDefs.encounter(r, p, rng)
	return {"round": r, "prestige": p, "place": place, "defs": defs, "vault": vault, "hidden": hidden}


func _end_scrying() -> void:
	if scrying and is_instance_valid(scrying):
		scrying.queue_free()
	scrying = null


func _start_fight() -> void:
	var plan := _next_plan
	_next_plan = {}
	var stale: bool = plan.is_empty() or plan.round != round_num or plan.prestige != prestige or plan.vault != secret_next \
		or (secret_stage != "" and plan.hidden != secret_stage and not is_boss_round())
	if stale:
		plan = _plan_fight(round_num, prestige)
	var vault: bool = plan.vault
	var hidden: String = plan.hidden
	if vault:
		secret_next = false
	if hidden != "":
		secret_stage = ""
	_stars_caught = 0
	_fight_start = clock
	_fight_taken = 0.0
	hand.pain = 0.0
	_second_wind_used = false
	_fight_reactions.clear()
	_quake = 5.0
	_rain = 3.0
	_set_backdrop(plan.place)
	_add_features()
	props.setup(setting(), rng.randi())
	_clear_enemies()
	var defs: Array = plan.defs
	if hidden == "" and not vault:
		_last_foe_def = defs[0].duplicate(true)
	for i in defs.size():
		var e := Enemy.new()
		e.setup(defs[i], camera)
		if defs.size() > 1:
			e.position.x = -0.6 + 1.2 * i  # side by side
			e.scale = Vector3.ONE * 0.9
		world3d.add_child(e)
		e.strike.connect(_resolve_attack.bind(e))
		e.died.connect(_on_enemy_died)
		e.armor_fell.connect(_on_armor_fell)
		e.broke.connect(_on_enemy_broke.bind(e))
		e.ignited.connect(func() -> void:
			Sfx.play("boom", -8.0, 1.6)
			overlay.sparks(camera.unproject_position(e.torso.global_position), 60000.0, Color(1, 0.5, 0.1)))
		if e.data.get("dark", false):
			styles.set_dark(true)  # it snuffs the lights
		save.discover("foes", e.data.name)
		enemies.append(e)
	if defs.size() > 1:
		enemies[1]._timer += 1.5  # they don't swing in unison
	_fight_base = 0
	var total_hp := 0.0
	for d in defs:
		_fight_base += int(d.get("reward", 0))
		total_hp += float(d.get("hp", 100.0))
	_fight_par = PAR_BASE + total_hp * PAR_PER_HP
	enemy = enemies[0]
	for it in items_root.get_children():
		if it is Item:
			it.remove_meta("hit_boss")
	_refresh_hoard()
	state = State.COMBAT
	Music.set_mode(Music.Mode.BOSS if is_boss_round() else Music.Mode.FIGHT)


## Everyone still fighting.
func living() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and e.state != "dead":
			out.append(e)
	return out


## Every hit location of every living enemy, weak spots first, each tagged with whose it is.
func _all_regions() -> Array:
	var out: Array = []
	for e in living():
		for r in e.regions():
			r.who = e
			out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id == "weak" and b.id != "weak")
	return out


func is_boss_round() -> bool:
	return round_num % EnemyDefs.STAGES == EnemyDefs.BOSS_STAGE


## One of them went down. The purse spills out of the body onto your pile; a boss adds a
## notch to every weapon that touched it. When the last is down, the fight is won.
func _on_enemy_died() -> void:
	for e in enemies:
		if is_instance_valid(e) and e.state == "dead" and not e.has_meta("paid"):
			e.set_meta("paid", true)
			save.tally("kills")
			if e.data.get("boss", false):
				save.tally("bosses")
			var at := camera.unproject_position(e.torso.global_position)
			_spawn_coins(e.data.reward * (2 if hand.has_ring("ring_magpie") else 1), at, 260.0)
			# every weapon that drew its blood gets a notch
			var mark := "hit_%d" % e.get_instance_id()
			for n in get_tree().get_nodes_in_group("items"):
				var w := n as Item
				if w and w.has_meta(mark):
					w.remove_meta(mark)
					if w.owned and w.def.kind == "weapon":
						w.def = w.def.duplicate(true)
						w.def.kills = int(w.def.get("kills", 0)) + 1
						w.queue_redraw()
			if e.data.get("boss", false):
				for n in get_tree().get_nodes_in_group("items"):
					var it := n as Item
					if it and it.owned and it.has_meta("hit_boss") and it.def.kind == "weapon":
						it.def = it.def.duplicate(true)
						it.def.boss_kills = int(it.def.get("boss_kills", 0)) + 1
						it.queue_redraw()
						overlay.ring(it.global_position, 40.0, Color(0.95, 0.6, 1.0), 0.6)
	var alive := living()
	if not alive.is_empty():
		enemy = alive[0]
		return
	state = State.VICTORY
	_pay_fight_bonus()
	Music.set_mode(Music.Mode.CALM)  # drums out; the base plays on through the shop
	_state_timer = 2.2
	overlay.clear_zone()
	_clear_untaken_fixtures()  # whatever you didn't take stays here
	props.clear()
	styles.set_dark(false)
	_pay_utilities()
	_crumble_dust()


## The shop's scrap chute: scraps and broken-off chunks that touch it go down it, held or
## thrown. Metal and gold pay back a little (SCRAP_VALUE per cell), the rest is just gone.
## It's the way to clear a long run's pile of bits.
func _feed_chute() -> void:
	var paid := false
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it == null or not it.owned or it.is_queued_for_deletion() or it.freeze:
			continue
		var gold: bool = it.def.kind == "coin"  # gold down the chute: it pays nothing, but it remembers
		if it.def.kind != "debris" and not it.def.get("piece", false) and not gold:
			continue
		if it.to_global(it.center_of_mass).distance_to(CHUTE.pos) > CHUTE.radius:
			continue
		if gold:
			if it.held:
				hand.release()
			_chute_ate_gold(coin_value(it))
			it.queue_free()
			continue
		for c in it.cells:
			_scrap_bank += float(SCRAP_VALUE.get(it.cells[c].mat, 0.0)) * (1.0 - 0.5 * float(it.cells[c].get("rust", 0.0)))
		overlay.sparks(CHUTE.pos, 3000.0, Color(0.6, 0.55, 0.5))
		Sfx.play("clack", -12.0, 1.6)
		if it.held:
			hand.release()
		it.queue_free()
		paid = true
	if paid and _scrap_bank >= 1.0:
		var coins := int(_scrap_bank)
		_scrap_bank -= coins
		_spawn_coins(coins, CHUTE.pos + Vector2(0, 50), 60.0)
		Sfx.play("ting", -6.0, 1.2)


## After a fight, bits that are spent crumble away: scraps burnt to a crisp or rusted
## through turn to dust. Whole gear and sound scrap stay (the chute and the crucible are
## for those).
func _crumble_dust() -> void:
	for n in get_tree().get_nodes_in_group("debris"):
		var it := n as Item
		if it == null or it.is_queued_for_deletion() or it.held or it.cells.is_empty():
			continue
		var rust := 0.0
		for c in it.cells:
			rust += float(it.cells[c].get("rust", 0.0))
		if it.charred or rust / it.cells.size() >= 0.5:
			overlay.sparks(it.global_position, 1500.0, Color(0.35, 0.3, 0.28) if it.charred else Color(0.6, 0.35, 0.15))
			it.queue_free()


## Utility items in your pile pay out after each fight, if they're still in one piece.
func _pay_utilities() -> void:
	var held_coins := coin_total()
	var things := _owned_count(func(it: Item) -> bool: return _whole(it) and it.def.kind not in ["coin", "menu"])
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it == null or not it.owned or it.is_queued_for_deletion() or it.health_ratio() < 0.3:
			continue
		match it.def.get("utility", ""):
			"purse":
				_spawn_coins(3, it.global_position + Vector2(0, -20), 80.0)
				overlay.ring(it.global_position, 40.0, Color(1, 0.85, 0.3))
			"ledger":
				var interest := mini(5, int(held_coins / 5.0))
				if interest > 0:
					_spawn_coins(interest, it.global_position + Vector2(0, -20), 80.0)
					overlay.ring(it.global_position, 40.0, Color(1, 0.85, 0.3))
			"scales":
				var tithe := mini(6, int(things / 4.0))
				if tithe > 0:
					_spawn_coins(tithe, it.global_position + Vector2(0, -20), 80.0)
					overlay.ring(it.global_position, 40.0, Color(1, 0.85, 0.3))
			"mortar":
				hand.heal(15.0)
				overlay.ring(it.global_position, 40.0, Color(0.5, 1.0, 0.6))
				overlay.streak(it.global_position, hand.position, 2.0, Color(0.5, 1.0, 0.6), 0.3)
			"crucible":
				# metal scrap resting on it melts down: a coin for every three cells
				var melted := 0
				for b in it.get_colliding_bodies():
					var o := b as Item
					if o and o.owned and o.is_loose_metal() and o.def.kind != "coin":
						melted += maxi(1, int(o.cells.size() / 3.0))
						o.queue_free()
				if melted > 0:
					_spawn_coins(melted, it.global_position + Vector2(0, -30), 120.0)
					overlay.sparks(it.global_position, 20000.0, Color(1, 0.6, 0.2))
					overlay.ring(it.global_position, 50.0, Color(1, 0.7, 0.3))


func _owned_count(pred: Callable) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("items"):
		var it := node as Item
		if it and it.owned and not it.is_queued_for_deletion() and pred.call(it):
			n += 1
	return n


func _has_utility(u: String) -> bool:
	return _owned_count(func(it: Item) -> bool: return it.def.get("utility", "") == u and it.health_ratio() >= 0.3) > 0


## What the pile is worth: hoard utilities count what you own and turn it into stats.
func _refresh_hoard() -> void:
	var weapons := _owned_count(func(it: Item) -> bool: return _whole(it) and it.def.kind == "weapon")
	var shields := _owned_count(func(it: Item) -> bool: return _whole(it) and it.def.kind == "shield")
	var pauldrons := _owned_count(func(it: Item) -> bool: return _whole(it) and it.def.get("id", "") == "pauldron" and it.health_ratio() >= 0.3)
	var gear := _owned_count(func(it: Item) -> bool: return _whole(it) and it.def.kind in ["weapon", "shield", "utility"])
	hand.hoard_hp = 4.0 * mini(10, weapons) if _has_utility("rack") else 0.0
	hoard_wear = 1.0 - 0.08 * mini(5, pauldrons) if _has_utility("pegs") else 1.0
	hoard_stagger = 1.0 + 0.15 * mini(3, shields) if _has_utility("banner") else 1.0
	hoard_damage = 1.0 + 0.02 * mini(10, gear) if _has_utility("idol") else 1.0
	hoard_shirt = _has_utility("hairshirt")
	var stones := _owned_count(func(it: Item) -> bool: return it.def.get("utility", "") == "sentinel" and it.health_ratio() >= 0.3)
	hoard_ward = 1.0 - pow(1.0 - WARD_PER, mini(WARD_MAX, stones))


## A whole thing, not a broken-off chunk or scrap of one (those don't count for the hoard).
func _whole(it: Item) -> bool:
	return it.def.kind != "debris" and not it.def.get("piece", false)


## The stagger meter filled: the enemy slumps, open to punishment.
func _on_enemy_broke(who: Enemy = null) -> void:
	var e: Enemy = who if who else enemy
	var at := camera.unproject_position(e.torso.global_position)
	overlay.starburst(at, 220.0, Color(1, 0.85, 0.4))
	overlay.ring(at, 260.0, Color(1, 0.85, 0.4), 0.6)
	Sfx.play("gong", -6.0, 1.6)
	_hitstop(0.12)
	_shake += 10.0


## Freeze the action for a moment so a big moment lands.
func _hitstop(secs: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(secs, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## A pauldron broke off: it lands in your play field as a chunk of iron you can use.
func _on_armor_fell(at: Vector2) -> void:
	var p := _spawn(ItemDefs.make("pauldron", "iron"), at)
	p.linear_velocity = Vector2(randf_range(-200, 200), -300)
	p.angular_velocity = randf_range(-6, 6)
	overlay.sparks(at, 30000.0)


func _defeat() -> void:
	save.tally("deaths")
	save.write()
	state = State.DEFEAT
	Music.set_mode(Music.Mode.AMBIENT, Music.DEATH_AMBIENCE)  # the cinder ambience over a death; home's night after
	hand.die()
	for e in enemies:
		if is_instance_valid(e):
			e.active = false
	overlay.clear_zone()
	_state_timer = 3.5


func _open_shop() -> void:
	state = State.SHOP
	_chute_gold = 0
	_tooth_given = false
	for e in enemies:
		if is_instance_valid(e):
			e.visible = false
	hand.heal(40.0)
	_gong_struck = false
	overlay.gong = GONG
	overlay.dice = DICE
	overlay.chute = CHUTE
	overlay.door = DOOR if is_boss_round() else {}
	# the next fight is decided now, so the gong's face can show it
	var next_round := round_num + 1
	_next_plan = _plan_fight(next_round, prestige + (1 if next_round % EnemyDefs.STAGES == 0 else 0))
	_end_scrying()
	scrying = Scrying.new()
	overlay.add_child(scrying)
	scrying.setup(self, _next_plan)
	rerolls = 0
	free_rerolls = 0
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it and it.owned and it.def.get("utility", "") == "horseshoe" and it.health_ratio() >= 0.3:
			free_rerolls += 1
	_stock_shelves(true)


func reroll_cost() -> int:
	return 0 if free_rerolls > 0 else 2 + rerolls


## Seven shelves: four of gear (the first stocking of a visit always puts a consumable on
## the first one), one of stat draughts and hand upgrades, and two of rings. Potions are
## rare and never more than one at a time.
func _stock_shelves(first: bool) -> void:
	var defs: Array = []
	var potions := 0
	for i in SHOP_GEAR:
		var d: Dictionary
		if first and i == 0:
			d = ItemDefs.roll_offer(round_num, rng, ["consumable", "potion"])
		else:
			d = ItemDefs.roll_offer(round_num, rng, [], ["potion"] if potions > 0 else [])
		if d.kind == "potion":
			potions += 1
		defs.append([d, "gear"])
	defs.append([ItemDefs.make_upgrade(ItemDefs.roll_stat(rng, hand.ring_slots < Hand.MAX_RING_SLOTS)), "stat"])
	var rings := ItemDefs.ring_ids().filter(func(k: String) -> bool: return not hand.has_ring(k))
	rings.shuffle()
	for i in 2:
		defs.append([ItemDefs.make_upgrade(rings[i]), "ring"])
	for i in defs.size():
		_add_shelf(defs[i][0], 85.0 + i * 152.0, defs[i][1])
	overlay.shelves = shelves
	overlay.dice_price = reroll_cost()


## Punch the dice: everything unbought goes, fresh stock comes out.
func _reroll() -> void:
	var cost := reroll_cost()
	if not _pay(cost, DICE.pos):
		overlay.ring(DICE.pos, 30.0, Color(1, 0.3, 0.2), 0.3)
		Sfx.play("deny")
		return
	if free_rerolls > 0:
		free_rerolls -= 1
	else:
		rerolls += 1
	_clear_shop()
	_stock_shelves(false)
	overlay.ring(DICE.pos, 50.0, Color(1, 1, 0.9))
	Sfx.play("clack", 0.0, 1.4)


func _clear_shop() -> void:
	for it in items_root.get_children():
		if it is Item and not it.owned:
			it.queue_free()
	for sh in shelves:
		sh.body.queue_free()
	shelves.clear()
	overlay.shelves = shelves


## Take coins out of the pile (biggest first, change back). False if you can't afford it.
func _pay(amount: int, change_at: Vector2) -> bool:
	if amount <= 0:
		return true
	if coin_total() < amount:
		return false
	var coins: Array[Item] = []
	for n in get_tree().get_nodes_in_group("coins"):
		var c := n as Item
		if c and c.owned and not c.is_queued_for_deletion():
			coins.append(c)
	coins.sort_custom(func(a: Item, b: Item) -> bool: return coin_value(a) > coin_value(b))
	var spent := 0
	var last_at := change_at
	for c in coins:
		if spent >= amount:
			break
		spent += coin_value(c)
		last_at = c.global_position
		overlay.sparks(c.global_position, 5000.0, Color(1, 0.85, 0.3))
		if c.held:
			hand.release()
		c.queue_free()
	if spent > amount:
		_spawn_coins(spent - amount, last_at + Vector2(0, -20), 60.0)  # change
	return true


## A shelf: a real ledge with the item resting on it and the price shown as coin pips.
## Drop coins on it (or on the item) to pay.
func _add_shelf(d: Dictionary, x: float, kind: String = "gear") -> void:
	var rect := Rect2(x - SHELF_W * 0.5, SHELF_Y, SHELF_W, 10)
	var body := StaticBody2D.new()
	body.collision_layer = 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.position = rect.get_center()
	body.add_child(cs)
	add_child(body)
	var it := Item.create(d)
	it.owned = false
	it.freeze = true
	it.position = Vector2(x, SHELF_Y - it.origin.y - 1.0)
	items_root.add_child(it)
	_discover(d)  # seen on a shelf counts as found
	shelves.append({"rect": rect, "price": ceili(d.cost * (1.3 if hand.has_ring("ring_magpie") else 1.0)), "paid": 0, "item": it, "body": body, "rarity": int(d.get("rarity", 0)), "kind": kind})


## Shelf pips light up for as much of the price as your pile of coins covers.
func _update_shelves() -> void:
	var total := coin_total()
	for sh in shelves:
		sh.paid = total
	overlay.dice_price = reroll_cost()
	overlay.dice_paid = total


func coin_total() -> int:
	if not is_inside_tree():
		return 0  # mid-restart: the inspect card can ask one last time after the scene is gone
	var total := 0
	for n in get_tree().get_nodes_in_group("coins"):
		var c := n as Item
		if c and c.owned and not c.is_queued_for_deletion():
			total += coin_value(c)
	return total


## Picking up shop stock buys it: the coins leave your pile (change comes back) and the
## item is in your hand.
func _on_buy_attempt(it: Item, at: Vector2) -> void:
	var sh: Dictionary = {}
	for s2 in shelves:
		if s2.item == it:
			sh = s2
	if sh.is_empty() or state != State.SHOP:
		return
	if not _pay(sh.price, Vector2(640, 650)):
		overlay.ring(it.global_position, 40.0, Color(1, 0.3, 0.2), 0.3)
		Sfx.play("deny")
		return
	it.owned = true
	it.freeze = false
	overlay.ring(it.global_position, 60.0, Color(1, 0.85, 0.3))
	Sfx.play("buy")
	sh.body.queue_free()
	shelves.erase(sh)
	overlay.shelves = shelves
	hand.grab(it, at)


func _strike_gong() -> void:
	if _gong_struck:
		return
	_gong_struck = true
	overlay.ring_gong()
	Sfx.play("gong", 0.0)
	_shake += 6.0
	if state == State.HOME:
		get_tree().create_timer(0.8).timeout.connect(_start_run)
	else:
		get_tree().create_timer(0.8).timeout.connect(_close_shop)


## On to the next stage. Past the boss, the run prestiges: everything deeper.
func _close_shop() -> void:
	# unbought stock, and anything that burned or broke off it, goes back on the shelf
	_clear_shop()
	_end_scrying()
	overlay.gong = {}
	overlay.dice = {}
	overlay.chute = {}
	overlay.door = {}
	round_num += 1
	if round_num % EnemyDefs.STAGES == 0:
		prestige += 1
		ItemDefs.run_prestige = prestige
		save.prestige_best = maxi(save.prestige_best, prestige)
		save.write()
	_start_fight()


## Hold a gauntlet, salve, charm, wristband or ring and press Space to put it on.
func _wear(it: Item) -> void:
	var uid: String = it.def.upgrade
	match uid:
		"strength":
			hand.strength *= 1.25
		"toughness":
			hand.base_max_hp += 25.0
		"steady":
			hand.steadiness *= 0.6
		"quick":
			hand.swing_power *= 1.2
		"slots":
			hand.ring_slots = mini(Hand.MAX_RING_SLOTS, hand.ring_slots + 1)
		"vigor":
			hand.base_max_hp += 15.0
		"tonic":
			hand.strength *= 1.12
		"haste":
			hand.haste *= 0.9
		"thick_skin":
			hand.resilience *= 0.9
		_:
			var off := hand.wear_ring(uid)
			if off != "":
				# every finger was taken: the oldest ring comes off and drops into the pile
				_spawn(ItemDefs.make_upgrade(off), hand.position + Vector2(0, 20))
	hand.upgrades[uid] = hand.upgrades.get(uid, 0) + 1
	Sfx.play("buy", -2.0, 0.8)
	overlay.ring(hand.position, 40.0, Color(1, 0.9, 0.5))
	hand.release()
	it.queue_free()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F1:
		debug_label.visible = not debug_label.visible
	elif k.keycode == KEY_ENTER and state == State.HOME and hand.held and hand.held.def.kind != "menu":
		codex.rename(hand.held)
	elif k.keycode == KEY_F9 and backdrop:
		var i := Backdrop.SETTINGS.find(backdrop.setting)
		_set_backdrop(Backdrop.SETTINGS[(i + 1) % Backdrop.SETTINGS.size()])


# --- combat --------------------------------------------------------------------

func _zone_px(atk: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in atk.zone:
		out.append(p * SCREEN)
	return out


## The attack lands. The zone is cut into lines along the blade's direction of travel;
## along each line the blade is stopped by the first things it meets, each taking a share
## (more if it's moving fast: parry). What's left at the end of a line reaches the hand.
## Magnetic gear draws the blade to it from a little way off. What the weapon is made of
## (its trait) rubs off on whatever blocked it: rust, heat, charge.
func _resolve_attack(atk: Dictionary, who: Enemy = null) -> void:
	if state != State.COMBAT:
		return
	var enemy: Enemy = who if who else self.enemy  # the one swinging
	var poly := _zone_px(atk)
	if atk.get("unmoor", false):
		# the pull of the heavens let go of: everything you own falls upward for a moment
		for n in get_tree().get_nodes_in_group("items"):
			var it := n as Item
			if it and it.owned and not it.freeze:
				it.reverse_time = 2.0
	if enemy_greedy(who):
		_swallow_coins(poly, who if who else enemy)
	var dir: Vector2 = (atk.dir as Vector2).normalized()
	var lanes := Lanes.build(poly, dir)
	if lanes.is_empty():
		return
	var space := get_viewport().world_2d.direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var magnets: Array[Item] = []
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it and it.owned and it.has_mod("magnetic") and not it.is_queued_for_deletion():
			magnets.append(it)
	Sfx.play("strike", -2.0, 0.8)
	var leak := 0.0
	var spiked := 0.0
	var touched := {}  # Item -> {n (lanes), at, parry, speed}
	# the hand only gets caught by whatever is left of the blade when it reaches the hand
	var hand_lane := _hand_lane(lanes) if Geometry2D.is_point_in_polygon(hand.position, poly) else -1
	var hand_energy := 0.0
	var lane_left: Array = []  # what's left of each lane at its end
	for li in lanes.size():
		var lane: Array = lanes[li]
		var energy := 1.0
		var hit_in_lane := {}
		var hand_reached := false
		for p in lane:
			if li == hand_lane and not hand_reached and p.dot(dir) > hand.position.dot(dir) + SAMPLE_STEP * 0.5:
				hand_energy = energy
				hand_reached = true
			q.position = p
			var hits: Array = []  # [item, point on it]
			for h in space.intersect_point(q, 6):
				if h.collider is Item:
					hits.append([h.collider, p])
			for mg in magnets:
				if hit_in_lane.has(mg):
					continue
				var near: Vector2 = mg.catch_at(p, MAGNET_CATCH)
				if near.is_finite():
					hits.append([mg, near])
			for pair in hits:
				var it: Item = pair[0]
				var at_p: Vector2 = pair[1]
				if hit_in_lane.has(it) or not it.owned:
					continue
				var b: float = it.block_at(at_p)
				if b <= 0.0:
					continue
				hit_in_lane[it] = true
				var spd: float = it.point_velocity(at_p).length()
				var legend: String = it.def.get("legend", "")
				var asc: bool = it.def.get("ascended", false)
				if legend == "vigil" and it.brace_time <= 0.0 and (asc or it.cooldown <= 0.0):
					it.cooldown = 0.0
					it.brace()  # the Bastion braces itself
				var parry := Item.parry_for_speed(spd)
				if it.def.kind == "shield" and it.swing_time <= 0.0:
					parry *= SHIELD_SWING_PARRY  # (dragged, a shield is too heavy to parry: a glued one swung on a weapon isn't)
				if it.brace_time > 0.0 or (legend == "unyielding" and asc):
					parry = 1.0
				if it != hand.held:
					b += (1.0 - b) * hoard_ward  # Sentinel Stones: the pile stands guard on its own
				var chew := energy * b  # what this piece takes, cleave or not
				if legend == "unyielding":
					b = 1.0  # the Aegis: nothing gets past
				b *= 1.0 - float(atk.get("cleave", 0.0)) * (0.0 if legend == "unyielding" else 1.0)  # a cleaving blow goes on through...
				b += (1.0 - b) * parry  # ...unless it's parried
				var absorbed := energy * b
				it.wear_at(at_p, atk.impact * LANE_IMPACT * maxf(absorbed, chew) * (1.0 - 0.5 * parry) * hoard_wear)
				energy -= absorbed
				if it.def.modifiers.has("spiked"):
					spiked += absorbed * atk.damage / lanes.size() * 0.25
				var t: Dictionary = touched.get(it, {"n": 0, "at": Vector2.ZERO, "parry": 0.0, "speed": 0.0, "stopped": 0.0})
				t.n += 1
				t.stopped += absorbed * atk.damage / lanes.size()  # its share of the blow, in hand damage
				t.at += at_p
				t.parry += parry
				t.speed = maxf(t.speed, spd)
				touched[it] = t
		if li == hand_lane and not hand_reached:
			hand_energy = energy
		leak += energy
		lane_left.append(energy)
	leak /= lanes.size()
	# the part that slipped past is checked by however much of the blow was stopped
	var check := 1.0 - CHECK * (1.0 - leak)
	leak *= check  # (the hand caught in the swing isn't checked: the blade got to it first)
	overlay.lane_result(lanes, lane_left)  # how each lane ended, before the check: which were open
	var best_parry := 0.0
	var parried_stop := 0.0  # damage stopped by gear moving fast enough to parry, weighted by how fast
	var stopped_total := 0.0
	var top_stop := 0.0
	var top_at := Vector2.ZERO
	var top_parry := 0.0
	var gummed := false
	for it in touched:
		if not is_instance_valid(it):
			continue
		var t: Dictionary = touched[it]
		var cover := float(t.n) / lanes.size()
		var at: Vector2 = t.at / t.n
		var parry: float = t.parry / t.n
		stopped_total += t.stopped
		if t.stopped > top_stop:
			top_stop = t.stopped
			top_at = at
			top_parry = parry
		if it.has_mod("volatile"):
			it.light_fuse(0.05)
		if it._glue > 0 and it.glued_at(at):
			gummed = true
		it.apply_impulse(dir * atk.push * cover * (1.0 - 0.7 * parry), at - it.global_position)
		if parry > 0.05:
			overlay.sparks(at, it.mass * t.speed * parry)
			_shake += it.mass * parry * 0.002
		best_parry = maxf(best_parry, parry)
		parried_stop += t.stopped * parry
		if parry > 0.5 and _has(it, "avenging"):
			it.set_meta("avenge_until", clock + AVENGE_TIME)
			overlay.ring(at, 40.0, Color(1.0, 0.82, 0.3), 0.4)
		if parry > 0.5 and _has(it, "stormcaller"):
			_call_storm(it, enemy, t.stopped, at)
		if _has(it, "counter"):
			_counter_bank = minf(COUNTER_CAP, _counter_bank + t.stopped)
		if parry > 0.5 and _has(it, "rally"):
			_rally()
		# the enemy's blade touches whatever it hit: charged gear shocks it, hot gear scalds it.
		# The shock runs up the blade into whoever holds it, and like an electrified weapon's
		# it goes through armour (the more plate, the worse), and harder the more it stopped:
		# an electrified shield is a weapon of its own
		var shock: float = it.charge * (BLOCK_SHOCK + t.stopped * BLOCK_SHOCK_SHARE) * (1.0 + float(enemy.data.get("armor", 0.0)) * 1.5)
		var elem: float = shock + it.heat * 5.0
		if elem > 1.0 and not enemy.data.get("shockproof", false):
			enemy.take_hit(elem, "torso", false)
			_apply_element(enemy, "storm" if it.charge > it.heat else "fire", at)
			if it.charge > it.heat:
				Sfx.play("zap", -4.0)
			overlay.sparks(at, elem * 4000.0, Color(0.6, 0.85, 1.0) if it.charge > it.heat else Color(1, 0.5, 0.2))
		# and what the weapon is made of rubs off on what it hit
		match atk.get("trait", ""):
			"corrosive":
				it.catch_rust(1.0)
				overlay.sparks(at, 6000.0, Color(0.5, 0.9, 0.3))
			"burning":
				it.heat = maxf(it.heat, 0.8)
				overlay.sparks(at, 6000.0, Color(1, 0.5, 0.15))
			"freezing":
				it.heat = 0.0
				it.cold = 1.0  # frozen brittle
				overlay.sparks(at, 6000.0, Color(0.75, 0.9, 1.0))
			"charged":
				it.charge = maxf(it.charge, 1.0)
				overlay.sparks(at, 6000.0, Color(0.6, 0.85, 1.0))
	# one number for the whole blow, where most of it was stopped (gold if that was a parry)
	if stopped_total > 0.0:
		popups.number(top_at + Vector2(0, -10), stopped_total, Color(0.95, 0.85, 0.5) if top_parry > 0.5 else Color(0.72, 0.72, 0.74))
	if gummed:
		enemy.gum_up(1.5)
	var dmg: float = atk.damage * leak
	dmg += atk.damage * HAND_CAUGHT * hand_energy  # the hand itself caught in the swing
	hand.hurt(dmg)
	if spiked > 0.0:
		enemy.take_hit(spiked, "torso", false)
	_grade_block(atk, poly, touched, leak, best_parry, parried_stop, dmg, enemy)


## Every blow that lands gets a grade, and each grade looks, sounds and feels different:
## parry (gold burst, chime, long freeze), clean block (blue shockwave, clang, short freeze),
## partial (orange crack, a red streak through to the hand) and miss (a full red slash to the
## hand and a red pulse round the screen). Sparks scale with the damage stopped. Damage you
## prevent also fills the enemy's stagger meter.
## A parry is anything of yours that met the blade moving fast (or a braced shield), however
## much else got through: what it stopped counts again toward the stagger meter. A parry
## that also stops nearly everything (a perfect parry) staggers the enemy outright.
func _grade_block(atk: Dictionary, poly: PackedVector2Array, touched: Dictionary, leak: float, best_parry: float, parried_stop: float, taken: float, enemy: Enemy) -> void:
	var prevented: float = atk.damage * (1.0 - leak) * hoard_stagger
	var centre := _centroid(poly)
	var impact := centre
	var metal := false
	var weight := 0.0
	var main_blocker: Item = null
	for it in touched:
		if is_instance_valid(it):
			metal = metal or it.conductive
			if touched[it].n > weight:
				weight = touched[it].n
				impact = touched[it].at / touched[it].n
				main_blocker = it
	if main_blocker and main_blocker.has_part("shield"):
		prevented *= SHIELD_STAGGER  # a blow turned on a shield (or a shield glued to a weapon) rattles the one who threw it
	if main_blocker and main_blocker.def.get("legend", "") == "reflect":
		# the Mirror Shield sends it back
		enemy.take_hit(prevented * (1.5 if main_blocker.def.get("ascended", false) else 0.5), "torso", false)
		overlay.ring(impact, 70.0, Color(0.8, 0.9, 1.0), 0.35)
	var parried := best_parry > 0.5
	if (parried or leak < CLEAN_BLOCK) and hand.has_ring("ring_momentum"):
		hand.momentum_time = 2.0
		hand.momentum_mult = 4.0 if parried else 2.5
	if (parried or leak < CLEAN_BLOCK) and hand.has_ring("ring_grudge"):
		hand.grudges = mini(5, hand.grudges + (2 if parried else 1))
	_block_rings(atk, parried, leak < CLEAN_BLOCK, prevented, impact, enemy)
	if main_blocker and _has(main_blocker, "hallowed") and (parried or leak < CLEAN_BLOCK):
		_heal_hand(8.0 if parried else 3.0, impact)
	enemy.on_blocked(parried or leak < CLEAN_BLOCK)
	if parried:
		if leak < CLEAN_BLOCK:
			enemy.stagger()
		enemy.throw_off_balance(OFF_BALANCE_TIME)
		enemy.add_stagger(prevented + parried_stop * hoard_stagger * (SHIELD_STAGGER if main_blocker and main_blocker.def.kind == "shield" else 1.0))
		hand.celebrate()
		overlay.starburst(impact, 140.0, Color(1.0, 0.85, 0.3))
		overlay.ring(impact, 170.0, Color(1, 0.95, 0.6), 0.5)
		overlay.sparks(impact, 120000.0 + prevented * 4000.0, Color(1.0, 0.9, 0.4))
		Sfx.play("parry", 0.0)
		_hitstop(0.11)
		_shake += 4.0
	elif leak < CLEAN_BLOCK:
		enemy.throw_off_balance(OFF_BALANCE_TIME)
		enemy.add_stagger(prevented)
		overlay.ring(impact, 60.0 + prevented * 4.0, Color(0.7, 0.85, 1.0), 0.4)
		overlay.sparks(impact, prevented * 4000.0, Color(0.8, 0.9, 1.0))
		Sfx.play("clang" if metal else "thud", 0.0, 0.75)
		_hitstop(0.05)
		_shake += 2.0 + prevented * 0.1
	elif not touched.is_empty() and leak < 0.6:
		enemy.add_stagger(prevented)
		overlay.ring(impact, 50.0, Color(1.0, 0.55, 0.2), 0.3)
		overlay.sparks(impact, prevented * 3000.0, Color(1.0, 0.6, 0.3))
		Sfx.play("clang" if metal else "thud", -6.0, 0.9)
	overlay.flash(poly, leak)
	if taken >= 2.5:
		# the part that got through, flying to the hand: as thick as the damage
		overlay.streak(impact if not touched.is_empty() else centre, hand.position, 2.0 + taken * 0.6, Color(1.0, 0.15, 0.1), 0.35)
		overlay.pulse(taken / 20.0)  # (its sound is the pain sting, from the hand's hurt)
		_shake += taken * 0.3


	if hand.injury >= hand.max_hp:
		_defeat()


## Which line of the attack the hand sits on (the one with the sample nearest to it).
func _hand_lane(lanes: Array) -> int:
	var best := -1
	var best_d := INF
	for li in lanes.size():
		for p in lanes[li]:
			var d: float = p.distance_squared_to(hand.position)
			if d < best_d:
				best_d = d
				best = li
	return best


## What each lane would let through if the blow landed now (no parries counted, but a
## braced shield is): the colours on the telegraph's arrows.
func _preview_cover(lanes: Array, cleave: float) -> Array:
	var space := get_viewport().world_2d.direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var out: Array = []
	for lane in lanes:
		var energy := 1.0
		var seen := {}
		for p in lane:
			q.position = p
			for h in space.intersect_point(q, 6):
				var it := h.collider as Item
				if it == null or seen.has(it) or not it.owned:
					continue
				var b := it.block_at(p)
				if b <= 0.0:
					continue
				seen[it] = true
				var unyielding: bool = it.def.get("legend", "") == "unyielding"
				if unyielding:
					b = 1.0
				else:
					b *= 1.0 - cleave
				if it.brace_time > 0.0:
					b = 1.0
				energy *= 1.0 - b
			if energy < 0.01:
				break
		out.append(energy)
	return out


func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()


func _physics_process(_delta: float) -> void:
	if state == State.COMBAT:
		_setting_physics(_delta)
	if state in [State.COMBAT, State.HOME]:
		_prop_tick += _delta
		if _prop_tick >= 0.05:
			props.feed(items_root.get_children(), _prop_tick)
			_prop_tick = 0.0
	if hand.well_time > 0.0:
		for it in items_root.get_children():
			if it is Item and it.owned and not it.freeze and not it.held:
				var to: Vector2 = hand.position - it.global_position
				if to.length() > 30.0:
					it.apply_central_force(to.normalized() * it.mass * 2600.0)
	if state == State.SHOP or state == State.HOME:
		if state == State.SHOP:
			_update_shelves()
			_feed_chute()
		else:
			for slot in racks:
				if slot.item != null and (not is_instance_valid(slot.item) or slot.item.is_queued_for_deletion() or slot.item.held):
					slot.item = null
		for it in items_root.get_children():
			if it is Item and it.swing_time > 0.0 and _over_gong(it):
				_strike_gong()
			elif state == State.SHOP and it is Item and it.def.get("id", "") == "gilded_tooth" and _over_gong(it):
				_tooth_to_gong(it)
			elif state == State.HOME and it is Item and it.swing_time > 0.0 and not it.swing_hit and it.def.kind == "weapon":
				for pr in props.props:
					if pr.kind == "dummy" and props._touches(it, pr):
						it.swing_hit = true
						pr.t = 0.0
						on_dummy_hit(it, pr.pos)
		return
	if state != State.COMBAT or living().is_empty():
		return
	var regs := _all_regions()
	var lp := _lever_screen()
	for it in items_root.get_children():
		if it is Item and it.swing_time > 0.0 and not it.swing_hit:
			if lp.is_finite():
				for c in it.cells:
					if it.to_global(it.cell_pos(c)).distance_to(lp) < 20.0:
						_try_lever(lp, 1.0)
						break
			_check_weapon_hit(it, regs)


## A swinging weapon hits the first body part (weak spot first) any of its cells passes over.
func _check_weapon_hit(it: Item, regs: Array) -> bool:
	for r in regs:
		var contact: Array[Vector2i] = []
		for c in it.cells:
			if it.to_global(it.cell_pos(c)).distance_to(r.center) <= r.radius:
				contact.append(c)
		if contact.is_empty():
			continue
		it.swing_hit = true
		it.hit_flash = 0.15
		var enemy: Enemy = r.get("who", self.enemy)
		if enemy.data.get("boss", false):
			it.set_meta("hit_boss", true)
		var thrown: bool = it.has_meta("thrown") and not it.held
		var wd: Dictionary = it.swing_part if not it.swing_part.is_empty() else it.def  # (glued: the part swung)
		var speed_f := clampf(absf(it.angular_velocity) / float(wd.get("swing_speed", 10.0)), 0.35, 1.15)
		if thrown:
			speed_f = clampf(it.linear_velocity.length() / 1400.0, 0.5, 1.15)
		var sharp: float = Materials.get_mat(wd.get("material", it.def.material)).sharp
		var dmg: float = float(wd.get("swing_damage", 4.0)) * WEAPON_DAMAGE * sharp * it.edge_condition() * speed_f * r.mult
		# electrified: shocks through armour, so armoured parts take the most
		if it.charge > 0.1:
			dmg *= 1.0 + it.charge * (0.2 + float(r.armor) * enemy.data.armor * 1.5)
		for m in INFUSIONS:
			if it.has_mod(m):
				dmg *= INFUSED_BONUS
		if it.storm_time > 0.0 and not it.has_mod("electrified"):
			dmg *= INFUSED_BONUS
		if hand.has_ring("ring_executioner") and (enemy.state == "broken" or enemy.off_balance > 0.0):
			dmg *= 3.0
		var guard_broken: bool = _has(it, "guardbreaker") and enemy.state == "windup"
		dmg *= _rare_mult(it, enemy, r)
		dmg *= it.heft()  # glued-on weight: a rock on a club is a mace
		if thrown:
			dmg *= 4.0
			it.remove_meta("thrown")
			overlay.starburst(r.center, 120.0, Color(1.0, 0.82, 0.3))
		if _counter_bank > 0.0:
			dmg += _counter_bank  # Riposte Guard: everything the shield took, back at them
			overlay.ring(r.center, 70.0, Color(0.8, 0.9, 1.0), 0.4)
			_counter_bank = 0.0
		dmg *= _ring_damage_mult() * hoard_damage * enemy.weapon_mult(it) * (SHIRT_BONUS if hoard_shirt else 1.0)
		if float(enemy.get_meta("vulnerable_until", 0.0)) > clock:
			dmg *= VULNERABLE

		it.set_meta("hit_%d" % enemy.get_instance_id(), true)  # for its kill count
		var legend: String = it.def.get("legend", "")
		var asc: bool = it.def.get("ascended", false)
		if legend == "flare" and enemy.burning_time > 0.0:
			dmg *= 4.0 if asc else 2.0
			if not asc:
				enemy.burning_time = 0.0  # the fire goes up all at once
			overlay.starburst(r.center, 200.0, Color(1.0, 0.5, 0.15))
		elif legend == "rot" and enemy.poison_time > 0.0:
			dmg *= 1.6 if asc else 1.25
		enemy.take_hit(dmg, r.id, true, WEAPON_STAGGER * (5.0 if guard_broken else 1.0))
		save.stats.best_hit = maxi(int(save.stats.best_hit), roundi(dmg))
		_legend_hit(it, legend, asc, enemy, dmg, r)
		_rare_after_hit(it, enemy, r, contact)
		for el in _elements(it):
			_apply_element(enemy, el, r.center)
		if hand.has_ring("ring_vampire"):
			hand.heal(dmg * 0.1)
		if _has(it, "sanguine"):
			hand.heal(dmg * 0.15)
			overlay.streak(r.center, hand.position, 1.5, Color(0.8, 0.1, 0.2), 0.25)
		if it.heat > 0.3:
			enemy.heat_up(it.heat * 0.34)  # about three red-hot hits sets it alight
		if it.cold > 0.3 and enemy.data.get("cold_stagger", false):
			enemy.stagger()  # the Zealot can't stand it
		if it.has_mod("corrosive"):
			enemy.corrode(0.12)
		if it.has_mod("poisoned"):
			enemy.poison(4.0)
		Sfx.play("hit", -4.0, 1.3 if r.id == "weak" else 1.0)
		_damage_sound(dmg, false)
		if it.charge > 0.5 and enemy.state == "windup":
			enemy.stagger()  # a solid shock locks up the swing
		# armour bites back: soft metals bend, wood cracks
		for c in contact:
			it.damage_cell(c, r.armor * enemy.data.armor * 1.0, true)
		it.angular_velocity *= -0.3
		var hit_col := Color(1, 0.8, 0.2) if r.id == "weak" else (Color(1, 0.4, 0.3) if r.id == "exposed" else Color(1, 1, 0.85))
		overlay.ring(r.center, r.radius + dmg * 1.2, hit_col)
		if r.id == "weak":
			overlay.starburst(r.center, 160.0, Color(1, 0.8, 0.2))
			_hitstop(0.1)
		overlay.sparks(r.center, dmg * 3000.0)
		return true
	return false


## A rare modifier on the item, or borrowed by a Mimic from the last weapon held.
func _has(it: Item, m: String) -> bool:
	return it.has_mod(m) or (it.has_meta("mimic") and (it.get_meta("mimic") as Array).has(m))


## The rare conditional modifiers: what meeting each one's condition is worth on this hit.
func _rare_mult(it: Item, enemy: Enemy, r: Dictionary) -> float:
	var m := 1.0
	if _has(it, "headhunter") and r.id == "head":
		m *= 3.0
	if _has(it, "desperate") and hand.hurt_fraction() > 2.0 / 3.0:
		m *= 2.0
	if _has(it, "lone") and _weapon_count() == 1:
		m *= 2.0
	if _has(it, "pristine") and it.edge_condition() >= 0.9:
		m *= 2.0
	if _has(it, "guardbreaker") and enemy.state == "windup":
		m *= 2.0
	if _has(it, "merciless") and enemy.hp < enemy.max_hp / 3.0:
		m *= 3.0
	if _has(it, "avenging") and float(it.get_meta("avenge_until", 0.0)) > clock:
		m *= 3.0
		it.set_meta("avenge_until", 0.0)
	if _has(it, "rested"):
		var rest := float(it.get_meta("rest", 0.0))
		if rest > 0.5:
			m *= minf(REST_MAX, 1.0 + REST_PER_SEC * rest)
		it.set_meta("rest", 0.0)
	if _has(it, "kindred"):
		var kin := 0
		for node in get_tree().get_nodes_in_group("items"):
			var o := node as Item
			if o and o != it and o.owned and _whole(o) and o.def.get("material", "") == it.def.material:
				kin += 1
		m *= minf(3.0, 1.0 + 0.2 * kin)
	if _has(it, "reckless"):
		m *= 2.5
	if _has(it, "bloodprice"):
		m *= 2.5
		if hand.wound(BLOOD_PRICE) > 0.0:
			overlay.ring(hand.position, 34.0, Color(0.7, 0.0, 0.05), 0.25)
	if _has(it, "bloodthirsty"):
		m *= 1.0 + 2.0 * hand.hurt_fraction()
	if enemy.has_meta("baton_by") and float(enemy.get_meta("baton_until", 0.0)) > clock:
		if enemy.get_meta("baton_by") != it:
			m *= 2.5  # a hand-off: another weapon marked it
			enemy.remove_meta("baton_by")
	if _has(it, "baton"):
		enemy.set_meta("baton_by", it)
		enemy.set_meta("baton_until", clock + BATON_TIME)
	if _rally_until > clock:
		m *= 1.5
		_rally_until = 0.0
	if m > 1.0:
		overlay.ring(r.center, r.radius + 30.0, Color(1.0, 0.82, 0.3), 0.4)  # the condition paid out
	return m


## Rare effects that follow a landed hit.
func _rare_after_hit(it: Item, enemy: Enemy, r: Dictionary, contact: Array) -> void:
	if _has(it, "lightning_rod") and not enemy.data.get("shockproof", false):
		var bolts := 0
		for node in get_tree().get_nodes_in_group("items"):
			var o := node as Item
			if o and o != it and o.owned and o.charge > 0.3:
				bolts += 1
				overlay.streak(o.global_position, r.center, 2.5, Color(0.6, 0.85, 1.0), 0.3)
				if not o.has_mod("electrified"):
					o.charge = 0.0  # drawn out of it
		if bolts > 0:
			enemy.take_hit(LIGHTNING_ROD_BOLT * bolts * (1.0 + float(enemy.data.get("armor", 0.0)) * 1.5), "torso", false)
			Sfx.play("zap", 0.0, 0.8)
	if _has(it, "kindling") and it.heat > 0.4:
		for node in get_tree().get_nodes_in_group("items"):
			var o := node as Item
			if o and o != it and o.owned and o.def.kind == "weapon":
				o.heat = maxf(o.heat, 0.9)
				overlay.sparks(o.global_position, 5000.0, Color(1.0, 0.5, 0.15))
	if _has(it, "reckless"):
		for c in contact:
			it.damage_cell(c, RECKLESS_WEAR, true)


## Every element a piece carries right now (a weapon that's hot and charged carries both).
func _elements(it: Item) -> Array:
	var out: Array = []
	if it.heat > 0.4 or it.is_burning():
		out.append("fire")
	if it.cold > 0.3 or it.has_mod("frosty"):
		out.append("frost")
	if it.has_mod("poisoned"):
		out.append("venom")
	if it.has_mod("corrosive"):
		out.append("rot")
	if it.charge > 0.3:
		out.append("storm")
	return out


## An element reaches a foe. If it's marked with a different one, the two react; otherwise
## it's marked with this one for a while.
func _apply_element(e: Enemy, el: String, at: Vector2) -> void:
	if el == "" or not is_instance_valid(e) or e.state == "dead":
		return
	var marks: Dictionary = e.get_meta("marks", {})
	if float(e.get_meta("react_ready", 0.0)) <= clock:
		for other in marks.keys():
			if other == el or float(marks[other]) <= clock:
				continue
			var pair := [other, el]
			pair.sort()
			var key := "%s+%s" % pair
			if REACTIONS.has(key):
				marks.erase(other)
				e.set_meta("marks", marks)
				e.set_meta("react_ready", clock + REACT_COOLDOWN)
				_react(e, key, [other, el])
				save.discover("reactions", key)
				# the way into the Ink Margin: three different reactions in one fight
				if not _fight_reactions.has(key):
					_fight_reactions.append(key)
					if _fight_reactions.size() == 3:
						props.appear("ink_blot", camera.unproject_position(e.head.global_position) + Vector2(0, -150), 26.0)
						popups.word(camera.unproject_position(e.head.global_position) + Vector2(0, -190), "...a stain?", Color(0.6, 0.6, 0.7))
				return
	marks[el] = clock + MARK_TIME
	e.set_meta("marks", marks)


func _react(e: Enemy, key: String, els: Array) -> void:
	var top := camera.unproject_position(e.head.global_position)
	var armour := 1.0 + float(e.data.get("armor", 0.0)) * 1.5
	var hp0 := e.hp
	match key:
		"fire+frost":
			e.take_hit(30.0, "torso", false)
			e.burning_time = 0.0
		"fire+storm":
			e.take_hit(20.0, "torso", false)
			e.stagger()
		"frost+storm":
			e.corrode(0.4)
			e.set_meta("vulnerable_until", clock + 5.0)
		"fire+venom":
			e.heat_up(1.0)
			e.poison(12.0)
		"frost+venom":
			e.slow_time = maxf(e.slow_time, 3.0)
			e.set_meta("vulnerable_until", clock + 5.0)
		"storm+venom":
			if e.state == "windup":
				e.stagger()
			e.slow_time = maxf(e.slow_time, 4.0)
		"fire+rot":
			e.corrode(0.6)
			e.take_hit(12.0 * armour, "torso", false)
		"frost+rot":
			e.take_hit(16.0, "torso", false)
			e.slow_time = maxf(e.slow_time, 4.0)
		"rot+storm":
			e.take_hit(18.0 * armour, "torso", false)
		"rot+venom":
			e.poison(15.0)
			e.corrode(0.3)
	var col: Color = (ELEMENT_COLORS[els[0]] as Color).lerp(ELEMENT_COLORS[els[1]], 0.5)
	if hp0 - e.hp >= 1.0:
		popups.number(top + Vector2(0, 10), hp0 - e.hp, col)  # what the reaction itself did
	popups.word(top + Vector2(0, -40), REACTIONS[key].name, col)
	overlay.ring(top + Vector2(0, 60), 80.0, col, 0.35)
	Sfx.play("boom", -10.0, 1.5)


## What's marked on each foe, for the little element pips over its head.
func _mark_display() -> Array:
	var out: Array = []
	for e in living():
		var marks: Dictionary = e.get_meta("marks", {})
		var pips: Array = []
		for el in marks:
			var left := float(marks[el]) - clock
			if left > 0.0:
				pips.append({"color": ELEMENT_COLORS[el], "left": left / MARK_TIME})
		if not pips.is_empty():
			out.append({"pos": camera.unproject_position(e.head.global_position) + Vector2(0, -60), "pips": pips})
	return out


## What a piece carries into an elemental rare effect.
func _element(it: Item) -> String:
	if it.heat > 0.4 or it.is_burning():
		return "fire"
	if it.cold > 0.3 or it.has_mod("frosty"):
		return "frost"
	if it.has_mod("poisoned"):
		return "venom"
	if it.has_mod("corrosive"):
		return "rot"
	if it.charge > 0.3:
		return "storm"
	return ""


## Stormcaller: a parry calls lightning down, and whatever the piece carries rides it.
## Hot, it's a firestorm; frosty, a blizzard; venomous, acid rain; corrosive, a rust storm
## (each a whirling column that rages on the foe for a few seconds); electrified, the
## lightning doubles and strikes every foe.
func _call_storm(it: Item, enemy: Enemy, stopped: float, at: Vector2) -> void:
	var el := _element(it)
	var armour := 1.0 + float(enemy.data.get("armor", 0.0)) * 1.5
	var bolt := stopped * 2.0 * armour
	var foes: Array = [enemy]
	if el == "storm":
		bolt *= 2.0
		foes = living()
	for e in foes:
		if e.data.get("shockproof", false) and el in ["", "storm"]:
			continue
		e.take_hit(bolt, "torso", false)
		if el != "":
			_apply_element(e, el, at)
		var top := camera.unproject_position(e.torso.global_position)
		overlay.streak(Vector2(top.x + randf_range(-40, 40), 0), top, 6.0, (ELEMENT_COLORS[el] as Color).lightened(0.3), 0.3)
		overlay.streak(at, top, 3.0, ELEMENT_COLORS[el], 0.3)
		if el != "":
			popups.word(top + Vector2(0, -90), STORM_NAMES[el], ELEMENT_COLORS[el])
		if el != "" and el != "storm":
			_storms.append({"enemy": e, "kind": el, "t": STORM_TIME, "tick": 0.0})
	Sfx.play("zap", 0.0, 0.7)


## Elemental storms rage on a foe for a while: damage every tick, and their element kept up.
func _tick_storms(delta: float) -> void:
	var keep: Array = []
	var shown: Array = []
	for st in _storms:
		var e: Enemy = st.enemy
		if not is_instance_valid(e) or e.state == "dead" or state != State.COMBAT:
			continue
		st.t -= delta
		st.tick -= delta
		if st.tick <= 0.0:
			st.tick = STORM_TICK
			e.take_hit(STORM_DAMAGE, "torso", false)
			match st.kind:
				"fire":
					e.heat_up(0.4)
				"frost":
					e.slow_time = maxf(e.slow_time, 0.6)
				"venom":
					e.poison(4.0)
				"rot":
					e.corrode(0.04)
		var pos := camera.unproject_position(e.torso.global_position)
		shown.append({"pos": pos + Vector2(0, 60), "kind": st.kind, "t": st.t, "color": ELEMENT_COLORS[st.kind]})
		if st.t > 0.0:
			keep.append(st)
	_storms = keep
	overlay.storms = shown
	overlay.marks = _mark_display()


## Notice when the hand takes something new: what it put down starts resting, what it took
## remembers how long it rested, and a Mimic takes on the last weapon's rare modifiers.
func _track_held() -> void:
	var h: Item = hand.held if hand.held and is_instance_valid(hand.held) else null
	if h == _last_held:
		return
	if _last_held and is_instance_valid(_last_held):
		_last_held.set_meta("released_at", clock)
		if _last_held.def.kind == "weapon":
			_prev_weapon = _last_held
	if h:
		h.set_meta("rest", maxf(0.0, clock - float(h.get_meta("released_at", -100.0))))
		if h.has_mod("mimic"):
			var copied: Array = []
			if _prev_weapon and is_instance_valid(_prev_weapon) and _prev_weapon != h:
				var theirs: Array = _prev_weapon.def.modifiers + (_prev_weapon.get_meta("mimic", []) as Array)
				for m in theirs:
					if m != "mimic" and ItemDefs.MODIFIERS.get(m, {}).get("rare", false) and not copied.has(m):
						copied.append(m)
			h.set_meta("mimic", copied)
			if not copied.is_empty():
				overlay.ring(h.global_position, 50.0, Color(1.0, 0.82, 0.3), 0.4)
	_last_held = h


## Rally: every weapon you own is ready, and the next hit lands harder.
func _rally() -> void:
	_rally_until = clock + RALLY_TIME
	for node in get_tree().get_nodes_in_group("items"):
		var o := node as Item
		if o and o.owned and o.def.kind == "weapon":
			o.cooldown = 0.0
			o.queue_redraw()
	overlay.ring(hand.position, 90.0, Color(1.0, 0.82, 0.3), 0.5)
	Sfx.play("ting", 0.0, 1.2)


func _weapon_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("items"):
		var w := node as Item
		if w and w.owned and w.def.kind == "weapon" and not w.is_queued_for_deletion():
			n += 1
	return n


## Wisp Cannon: an owned weapon moving fast enough spits a ball of wisp-fire at the nearest
## foe every WISP_EVERY seconds. The balls home in, scorch, and burst.
func _tick_wisps(delta: float) -> void:
	if state != State.COMBAT or living().is_empty():
		_wisps.clear()
		overlay.wisps = []
		return
	for node in get_tree().get_nodes_in_group("items"):
		var it := node as Item
		if it == null or not it.owned or not _has(it, "wispfire") or it.speed_parry() < WISP_SPEED:
			continue
		if float(it.get_meta("wisp_next", 0.0)) > clock:
			continue
		it.set_meta("wisp_next", clock + WISP_EVERY)
		var from := it.to_global(it.center_of_mass)
		var best: Enemy = null
		var best_d := INF
		for e in living():
			var d := from.distance_to(camera.unproject_position(e.torso.global_position))
			if d < best_d:
				best_d = d
				best = e
		var sharp: float = Materials.get_mat(it.def.material).sharp
		var size := 1.0
		if it.has_mod("large"):
			size = 1.4
		elif it.has_mod("huge"):
			size = 1.8
		var heavy := it.has_mod("heavy")
		if heavy:
			it.set_meta("wisp_next", clock + WISP_EVERY * 1.8)  # cannonballs: slower, harder
		var el := _element(it)
		if el == "":
			el = "fire"
		_wisps.append({"pos": from, "vel": it.linear_velocity.limit_length(400.0), "target": best, "kind": el,
			"size": size * (1.3 if heavy else 1.0), "dmg": WISP_DAMAGE * sharp * hoard_damage * size * (2.2 if heavy else 1.0)})
		Sfx.play("soft", -8.0, 2.2)
	var keep: Array = []
	for w in _wisps:
		var e: Enemy = w.target
		if not is_instance_valid(e) or e.state == "dead":
			continue
		var goal := camera.unproject_position(e.torso.global_position)
		var to: Vector2 = goal - w.pos
		if to.length() < 26.0:
			e.take_hit(w.dmg, "torso", false)
			_apply_element(e, w.kind, goal)
			match w.kind:
				"fire":
					e.heat_up(0.12)
				"frost":
					e.slow_time = maxf(e.slow_time, 1.5)
				"storm":
					if e.state == "windup" and randf() < 0.3:
						e.stagger()  # a jolt locks up the swing
				"venom":
					e.poison(3.0)
				"rot":
					e.corrode(0.05)
			overlay.sparks(goal, 9000.0 * w.size, ELEMENT_COLORS[w.kind])
			popups.number(goal + Vector2(0, -20), w.dmg, ELEMENT_COLORS[w.kind])
			continue
		w.vel = (w.vel as Vector2).lerp(to.normalized() * WISP_FLIGHT, minf(1.0, delta * 6.0))
		w.pos += w.vel * delta
		if randf() < 0.5:
			overlay.sparks(w.pos, 400.0, ELEMENT_COLORS[w.kind])
		keep.append(w)
	_wisps = keep
	overlay.wisps = _wisps.map(func(w: Dictionary) -> Dictionary: return {"pos": w.pos, "color": ELEMENT_COLORS[w.kind], "size": w.size})


## What a legendary does on top of its hit (see each one's "legend" in item_defs.gd).
func _legend_hit(it: Item, legend: String, asc: bool, enemy: Enemy, dmg: float, r: Dictionary) -> void:
	match legend:
		"chain":
			for e in living():
				if e != enemy:
					e.take_hit(dmg * (1.0 if asc else 0.5), "torso", false)
					overlay.streak(r.center, camera.unproject_position(e.torso.global_position), 3.0, Color(0.6, 0.85, 1.0))
				if asc or e.state == "windup":
					e.stagger()
			overlay.sparks(r.center, 30000.0, Color(0.6, 0.85, 1.0))
		"flare":
			if asc:
				enemy.heat_up(1.0)  # every hit sets it alight
		"rot":
			enemy.poison_time = minf(enemy.poison_time + 4.0, 60.0 if asc else 24.0)
		"sunder":
			enemy.corrode(1.0 if asc else 0.34)
			if asc:
				enemy.add_stagger(dmg)
			overlay.sparks(r.center, 20000.0, Color(0.8, 0.8, 0.85))
		"echo":
			for k in (3 if asc else 1):
				get_tree().create_timer(0.22 * (k + 1)).timeout.connect(_echo_hit.bind(enemy, dmg * 0.6, r.id, r.center))


## The Paragon's after-strike: the same blow again, a beat later.
func _echo_hit(e: Enemy, dmg: float, region: String, at: Vector2) -> void:
	if not is_instance_valid(e) or e.state == "dead" or state != State.COMBAT:
		return
	e.take_hit(dmg, region, false)
	overlay.ring(at, 36.0, Color(0.85, 0.75, 1.0), 0.3)
	Sfx.play("hit", -6.0, 1.6)


## Every blow to the hand passes through here first (Hand.on_hurt). Returns what's left of it.
func _hand_hurt(amount: float) -> float:
	var foe: Enemy = living()[0] if state == State.COMBAT and not living().is_empty() else null
	if hand.has_ring("ring_glass"):
		amount *= 2.0
	if hand.self_harm:
		# a price paid on purpose: the pain-answering rings still answer it (Thorns, the Martyr),
		# but no coins are spent on it and it can't burn the Phoenix (it never kills)
		if foe and hand.has_ring("ring_thorns"):
			foe.take_hit(amount * 2.0, "torso", false)
			overlay.ring(hand.position, 40.0, Color(0.35, 0.6, 0.2), 0.3)
		if foe and hand.has_ring("ring_martyr"):
			foe.add_stagger(amount * 3.0)
		return amount
	if hand.has_ring("ring_midas") and state != State.HOME:
		var spend := mini(coin_total(), ceili(amount / 3.0))
		if spend > 0 and _pay(spend, hand.position + Vector2(0, -30)):
			amount = maxf(0.0, amount - spend * 3.0)
			overlay.sparks(hand.position, 6000.0, Color(1.0, 0.85, 0.3))
	if amount <= 0.0:
		return 0.0
	hand.frenzy = 0
	hand.frenzy_time = 0.0
	if foe and hand.has_ring("ring_thorns"):
		foe.take_hit(amount * 2.0, "torso", false)
		overlay.ring(hand.position, 40.0, Color(0.35, 0.6, 0.2), 0.3)
	if foe and hand.has_ring("ring_martyr"):
		foe.add_stagger(amount * 3.0)
	if hand.has_ring("ring_phoenix") and hand.injury + amount >= hand.max_hp:
		hand.remove_ring("ring_phoenix")
		hand.injury = hand.max_hp * 0.5
		overlay.starburst(hand.position, 220.0, Color(1.0, 0.55, 0.1))
		overlay.sparks(hand.position, 80000.0, Color(1.0, 0.6, 0.2))
		Sfx.play("gong", 0.0, 1.3)
		return 0.0
	return amount


## Healing that comes from somewhere: a green ring where it came from, a streak to the hand.
func _heal_hand(amount: float, from: Vector2) -> void:
	if hand.injury <= 0.0:
		return
	hand.heal(amount)
	overlay.streak(from, hand.position, 1.5, Color(0.5, 1.0, 0.6), 0.25)
	overlay.ring(hand.position, 30.0, Color(0.5, 1.0, 0.6), 0.25)


## In a fight, every frame: what heals the hand on its own, and what bleeds it.
func _tick_blood(delta: float) -> void:
	if hand.held and hand.held.has_mod("soothing"):
		hand.heal(SOOTHE * delta)
	if hoard_shirt:
		_shirt_t += delta
		if _shirt_t >= SHIRT_EVERY:
			_shirt_t = 0.0
			hand.wound(1.0)
	var low := hand.hurt_fraction()
	if hand.has_ring("ring_second_wind") and not _second_wind_used and low > 0.75:
		_second_wind_used = true
		_heal_hand(SECOND_WIND, hand.position + Vector2(0, -40))
		overlay.starburst(hand.position, 120.0, Color(0.5, 1.0, 0.6))
		Sfx.play("ting", 0.0, 0.8)
	if low > 0.7:
		# a Field Dressing binds itself, from wherever it lies in the pile
		for n in get_tree().get_nodes_in_group("items"):
			var it := n as Item
			if it and it.owned and not it.is_queued_for_deletion() and low > 1.0 - float(it.def.get("auto_heal", 0.0)):
				_heal_hand(float(it.def.heal), it.global_position)
				overlay.starburst(it.global_position, 80.0, Color(0.95, 0.95, 0.85))
				Sfx.play("ting", -4.0, 1.2)
				if it == hand.held:
					hand.release()
				it.queue_free()
				break


## Rings that answer a good block.
func _block_rings(atk: Dictionary, parried: bool, clean: bool, prevented: float, impact: Vector2, enemy: Enemy) -> void:
	if parried or clean:
		_last_blocked = float(atk.damage) * float(enemy.data.get("power", 1.0))
	if (parried or clean) and hand.has_ring("ring_pacifist"):
		enemy.take_hit(prevented * (3.0 if parried else 1.5), "torso", false)
		overlay.streak(impact, camera.unproject_position(enemy.torso.global_position), 3.0, Color(1, 1, 1))
	if (parried or clean) and hand.has_ring("ring_winter"):
		enemy.slow_time = maxf(enemy.slow_time, 2.0)
		overlay.sparks(impact, 8000.0, Color(0.65, 0.95, 1.0))
	if hand.has_ring("ring_resolve") and (parried or clean):
		_heal_hand(6.0 if parried else 2.0, impact)
	if parried and hand.has_ring("ring_inferno"):
		enemy.heat_up(1.0)
	if parried and hand.has_ring("ring_static"):
		for it in items_root.get_children():
			if it is Item and it.owned and it.def.kind == "weapon":
				it.storm_time = maxf(it.storm_time, 4.0)


## The Alchemist's Ring: the thing goes up a metal. Legendaries refuse.
const ALCHEMY := {"wood": "copper", "bone": "copper", "stone": "iron", "leather": "copper", "cloth": "copper",
	"copper": "iron", "iron": "steel", "steel": "gold"}


func _alchemize(it: Item) -> bool:
	var from: String = it.def.get("material", "")
	if not ALCHEMY.has(from) or it.def.has("fixed_mods") or it.def.kind in ["coin", "menu", "upgrade"]:
		return false
	var to: String = ALCHEMY[from]
	for c in it.cells.keys():
		if it.cells.has(c) and it.cells[c].mat == from and not it.cells[c].get("handle", false):
			it.transmute_cell(c, to)
	it.adopt_material(to)
	if to == "gold":
		_gild(it)
	return true


## Conditional rings that change weapon damage.
func _ring_damage_mult() -> float:
	var m := 1.0
	if hand.has_ring("ring_untouched") and hand.hurt_fraction() < 0.1:
		m *= 1.8
	if hand.has_ring("ring_miser"):
		m *= 1.0 + minf(1.0, coin_total() * 0.03)
	if hand.momentum_time > 0.0:
		m *= hand.momentum_mult
		hand.momentum_time = 0.0
	if hand.grudges > 0:
		m *= 1.0 + 0.6 * hand.grudges
		hand.grudges = 0
	if hand.wrath_time > 0.0:
		m *= 2.5
	if hand.has_ring("ring_glass"):
		m *= 2.0
	if hand.gamble_mult > 1.0:
		m *= hand.gamble_mult
		hand.gamble_mult = 1.0
	if hand.blood_mult > 1.0:
		m *= hand.blood_mult
		hand.blood_mult = 1.0
	if hand.has_ring("ring_scars"):
		m *= 1.0 + minf(1.5, hand.pain * 0.015)
	if hand.has_ring("ring_frenzy"):
		m *= 1.0 + 0.25 * mini(hand.frenzy, 8)
		hand.frenzy += 1
		hand.frenzy_time = 2.5
	return m


## A prop did something to a piece (poisoned it, charged it...): a small ring in its colour.
func prop_feedback(at: Vector2, col: Color) -> void:
	overlay.ring(at, 40.0, col, 0.35)
	Sfx.play("ting", -10.0, 1.6)


## The chandelier's chain is punched: it comes down on whoever's under it.
func on_chandelier(at: Vector2) -> void:
	var foe: Enemy = null
	var best := INF
	for e in living():
		var d := at.distance_to(camera.unproject_position(e.head.global_position))
		if d < best:
			best = d
			foe = e
	Sfx.play("clang", 0.0, 0.6)
	_shake += 10.0
	if foe == null:
		return
	var head := camera.unproject_position(foe.head.global_position)
	overlay.streak(at, head, 10.0, Color(0.95, 0.85, 0.6), 0.25)
	overlay.sparks(head, 30000.0, Color(1.0, 0.7, 0.3))
	foe.take_hit(CHANDELIER_DAMAGE, "head", false)
	foe.stagger()
	foe.heat_up(0.6)
	_apply_element(foe, "fire", head)
	popups.number(head + Vector2(0, -20), CHANDELIER_DAMAGE, Color(1.0, 0.8, 0.4))


## A loose brick gives way: whatever was stashed behind it tumbles out.
func on_brick(at: Vector2) -> void:
	overlay.ring(at, 70.0, Color(1.0, 0.85, 0.3), 0.5)
	overlay.sparks(at, 15000.0, Color(0.8, 0.7, 0.5))
	Sfx.play("ting", 0.0, 1.0)
	_spawn_coins(rng.randi_range(10, 20), at + Vector2(0, 20), 30.0)
	if rng.randf() < 0.35:
		var rings := ItemDefs.ring_ids()
		_spawn(ItemDefs.make_upgrade(rings[rng.randi() % rings.size()]), at + Vector2(0, 30))
	save.discover("secrets", "brick")


## The blood altar takes its price and gives the weapon a rare modifier.
func on_altar(it: Item, at: Vector2) -> void:
	var rares := ItemDefs.MODIFIERS.keys().filter(func(k: String) -> bool:
		return ItemDefs.MODIFIERS[k].get("rare", false) and "weapon" in ItemDefs.MODIFIERS[k].get("kinds", ["weapon"]) and not it.has_mod(k))
	if rares.is_empty():
		return
	var m: String = rares[rng.randi() % rares.size()]
	it.add_mod(m)
	save.discover("modifiers", m)
	hand.injury = minf(hand.max_hp - 1.0, hand.injury + hand.max_hp / 3.0)  # it never kills you
	hand.hurt_taken.emit(hand.max_hp / 3.0)
	overlay.ring(at, 90.0, Color(0.8, 0.1, 0.1), 0.6)
	overlay.ring(it.global_position, 60.0, Color(1.0, 0.82, 0.3), 0.6)
	popups.word(it.global_position + Vector2(0, -50), str(ItemDefs.MODIFIERS[m].get("name", m)).to_upper(), Color(1.0, 0.82, 0.3))
	Sfx.play("gong", -6.0, 0.7)


## The guardian of a secret place. The Errata is a misprint of the last ordinary foe: its
## body and moves, in ink, a little faster.
func _guardian(place: String, p: int = -1) -> Dictionary:
	if p < 0:
		p = prestige
	var id: String = Secrets.STAGES[place].foe
	var d := EnemyDefs.scaled(id, p)
	if id == "Errata":
		var src: Dictionary = _last_foe_def if not _last_foe_def.is_empty() else EnemyDefs.scaled("Footman", prestige)
		d.attacks = (src.attacks as Array).duplicate()
		d.model = str(src.name).to_lower().replace(" ", "_")
		d.speed = float(src.get("speed", 1.0)) * 1.15
		d.hp = maxf(float(d.hp), float(src.hp) * 1.4)
		d.rest = (src.get("rest", [1.0, 1.6]) as Array).duplicate()
		d.bio = "A misprint of the %s, in wet ink: its moves, a little faster." % str(src.name)
	return d


func enemy_greedy(who: Enemy) -> bool:
	var e: Enemy = who if who else enemy
	return is_instance_valid(e) and e.data.get("greedy", false)


## The Coin Golem's blows swallow any coin in their path, and it grows back on them.
func _swallow_coins(poly: PackedVector2Array, e: Enemy) -> void:
	var eaten := 0
	for n in get_tree().get_nodes_in_group("items"):
		var c := n as Item
		if c == null or c.def.kind != "coin" or c.is_queued_for_deletion() or c.held:
			continue
		if Geometry2D.is_point_in_polygon(c.global_position, poly):
			eaten += coin_value(c)
			overlay.streak(c.global_position, camera.unproject_position(e.head.global_position), 2.0, Color(1.0, 0.85, 0.3), 0.25)
			c.queue_free()
	if eaten > 0:
		e.hp = minf(e.max_hp, e.hp + eaten * 4.0)
		popups.word(camera.unproject_position(e.head.global_position) + Vector2(0, -40), "GULP +%d" % (eaten * 4), Color(1.0, 0.85, 0.3))
		Sfx.play("ting", -2.0, 0.6)


## The Clockwork Orrery's planets: where each is now. Two on long arms, opposite ways round.
func planets() -> Array:
	if setting() != "Clockwork Orrery":
		return []
	var out: Array = []
	for k in 2:
		var period: float = [9.0, 6.0][k]
		var sgn: float = [1.0, -1.0][k]
		var a := sgn * TAU * clock / period + k * 2.0
		var radius: Vector2 = [Vector2(600, 190), Vector2(430, 120)][k]
		var pos := Vector2(640, 380) + Vector2(cos(a) * radius.x, sin(a) * radius.y)
		var vel := Vector2(-sin(a) * radius.x, cos(a) * radius.y) * sgn
		out.append({"pos": pos, "vel": vel, "r": [42.0, 30.0][k], "color": [Color(0.85, 0.55, 0.3), Color(0.5, 0.75, 0.95)][k]})
	return out


## The Gilded Gullet's chain, step one: the chute eats gold and, at 40, coughs up a tooth.
func _chute_ate_gold(value: int) -> void:
	_chute_gold += value
	if _chute_gold >= 40 and not _tooth_given:
		_tooth_given = true
		_spawn(ItemDefs.make("gilded_tooth", "gold"), CHUTE.pos + Vector2(0, 60))
		popups.word(CHUTE.pos + Vector2(0, 40), "*hic*", Color(1.0, 0.85, 0.3))
		Sfx.play("clang", -2.0, 1.4)


## Step two: the tooth touches the gong, and the gong swallows you.
func _tooth_to_gong(tooth: Item) -> void:
	if tooth.held:
		hand.release()
	tooth.queue_free()
	_unlock_secret("Gilded Gullet")
	_strike_gong()


## The Giant's Table's chain, last step: something shrunk twice goes through the brick's hole.
func on_through_hole(it: Item, at: Vector2) -> void:
	if it.held:
		hand.release()
	overlay.ring(at, 50.0, Color(0.95, 0.85, 0.6), 0.5)
	it.queue_free()
	popups.word(at + Vector2(0, -40), "...and so do you", Color(0.95, 0.85, 0.6))
	_unlock_secret("Giant's Table")


## The Clockwork Orrery's chain, last step: the star that waited is reached.
func on_still_star(at: Vector2) -> void:
	overlay.starburst(at, 140.0, Color(1.0, 0.95, 0.7))
	_unlock_secret("Clockwork Orrery")


## The Ink Margin's chain, last step: the stain is punched through.
func on_ink_blot(at: Vector2) -> void:
	overlay.sparks(at, 20000.0, Color(0.05, 0.05, 0.08))
	_unlock_secret("Ink Margin")


## The fight bonus as fractions of the reward: {speed, health}. Speed: won in half the par
## time or less pays SPEED_BONUS, falling to nothing at 1.5x par. Health: losing 5% of the
## hand or less pays HEALTH_BONUS, falling to nothing at 50%.
static func fight_bonus(secs: float, par: float, taken: float, max_hp: float) -> Dictionary:
	var speed := SPEED_BONUS * clampf((1.5 * par - secs) / par, 0.0, 1.0)
	var lost := taken / maxf(1.0, max_hp)
	var health := HEALTH_BONUS * clampf((0.5 - lost) / 0.45, 0.0, 1.0)
	return {"speed": speed, "health": health}


## A fight won: pay the bonus for speed and for keeping the hand whole, as extra coin
## spilling from where the foe stood, each part named so you know what earned it.
func _pay_fight_bonus() -> void:
	if _fight_base <= 0:
		return
	var secs := clock - _fight_start
	var b := fight_bonus(secs, _fight_par, _fight_taken, hand.max_hp)
	var speed_coins := roundi(_fight_base * float(b.speed))
	var health_coins := roundi(_fight_base * float(b.health))
	var at := Vector2(640, 260)
	if speed_coins > 0:
		popups.word(at + Vector2(-110, 0), "SWIFT +%d" % speed_coins, Color(0.6, 0.85, 1.0))
	if health_coins > 0:
		var lost := _fight_taken / maxf(1.0, hand.max_hp)
		var label := "FLAWLESS" if _fight_taken < 1.0 else ("UNSCATHED" if lost <= 0.05 else "GUARDED")
		popups.word(at + Vector2(110, 0), "%s +%d" % [label, health_coins], Color(1.0, 0.82, 0.3))
	if speed_coins + health_coins > 0:
		_spawn_coins(speed_coins + health_coins, at + Vector2(0, 40), 220.0)
		Sfx.play("buy", 0.0, 1.0)


## Audio for how much a blow did. Taken: a dissonant, driven sting (louder and a touch lower
## the harder you were hit). Dealt: a punchy, bright, consonant one (louder the harder you
## hit). A scratch is barely there; a big hit is unmistakable.
func _damage_sound(amount: float, taken: bool) -> void:
	if amount < 1.0:
		return
	var k := clampf(amount / (DAMAGE_SOUND_TAKEN if taken else DAMAGE_SOUND_DEALT), 0.0, 1.0)
	if taken:
		Sfx.play("pain", lerpf(-22.0, 3.0, k), lerpf(1.08, 0.82, k))
	else:
		Sfx.play("reward", lerpf(-22.0, 2.0, k), lerpf(1.0, 1.12, k))


## Glue joined two things into one (item.gd fuse()).
func on_fused(it: Item) -> void:
	overlay.ring(it.to_global(it.center_of_mass), 60.0, Color(0.85, 0.9, 0.3), 0.4)
	save.discover("secrets", "fusion")


func release_if_holding(it: Item) -> void:
	if hand.held == it:
		hand.release()


## The home hearth melts junk down: a thing left in the fire burns away and its scrap value
## builds up (saved) until a Coin Purse pops out to take on a run.
func on_smelt(it: Item, at: Vector2) -> void:
	var value := 0.0
	for c in it.cells:
		value += maxf(0.05, float(SCRAP_VALUE.get(it.cells[c].mat, 0.0)))
	if it.held:
		hand.release()
	it.queue_free()
	overlay.sparks(at, 8000.0, Color(1.0, 0.55, 0.15))
	Sfx.play("soft", -4.0, 0.6)
	save.stats.smelt = float(save.stats.get("smelt", 0.0)) + value
	while float(save.stats.smelt) >= SMELT_PURSE:
		save.stats.smelt = float(save.stats.smelt) - SMELT_PURSE
		var purse := _spawn(ItemDefs.make("coin_purse", "leather"), at + Vector2(-140, -80))
		purse.linear_velocity = Vector2(-220, -320)
		popups.word(at + Vector2(-60, -120), "COIN PURSE", Color(1.0, 0.82, 0.3))
		Sfx.play("ting", 0.0, 1.2)
	save.write()


## The training dummy at home takes a hit: what that weapon (or a punch) would do, rings,
## infusions and all, and the best is remembered.
func on_dummy_hit(it: Item, at: Vector2) -> void:
	var dmg: float = PUNCH_DAMAGE * hand.strength
	if it:
		var wd: Dictionary = it.swing_part if not it.swing_part.is_empty() else it.def
		var speed_f := clampf(absf(it.angular_velocity) / float(wd.get("swing_speed", 10.0)), 0.35, 1.15)
		dmg = float(wd.get("swing_damage", 4.0)) * WEAPON_DAMAGE * Materials.get_mat(wd.get("material", it.def.material)).sharp * it.edge_condition() * speed_f
		for m in INFUSIONS:
			if it.has_mod(m):
				dmg *= INFUSED_BONUS
		dmg *= _ring_damage_mult() * hoard_damage
	var best := dmg > float(save.stats.best_hit)
	if best:
		save.stats.best_hit = roundi(dmg)
	popups.number(at + Vector2(0, -50), dmg, Color(1.0, 0.82, 0.3) if best else Color(0.95, 0.95, 0.9), true)
	if best:
		popups.word(at + Vector2(0, -85), "BEST", Color(1.0, 0.82, 0.3))
	Sfx.play("thud", -2.0, 1.1)


## A secret place's condition is met: the next ordinary fight will be there.
func _unlock_secret(place: String) -> void:
	if secret_stage != "" or secret_next or not Secrets.STAGES.has(place):
		return
	secret_stage = place
	popups.word(Vector2(640, 220), "SOMETHING STIRS...", Color(1.0, 0.82, 0.3))
	overlay.ring(Vector2(640, 360), 400.0, Color(1.0, 0.82, 0.3), 1.0)
	Sfx.play("gong", -2.0, 0.45)
	_shake += 6.0


## Each secret place's guardian guards something: an infused weapon with a rare modifier
## hanging on the wall, and gold.
func _secret_prize(mods: Array) -> void:
	var pick: String = ["longsword", "greatsword", "mace", "spear"][rng.randi() % 4]
	var rares := ItemDefs.MODIFIERS.keys().filter(func(k: String) -> bool:
		return ItemDefs.MODIFIERS[k].get("rare", false) and "weapon" in ItemDefs.MODIFIERS[k].get("kinds", ["weapon"]))
	var all: Array = mods.duplicate()
	all.append(rares[rng.randi() % rares.size()])
	_fixture(ItemDefs.make(pick, "steel", all), Vector2(1100, 200), true)
	_spawn_coins(20, Vector2(640, 300), 200.0)


## A falling star, caught: a scatter of gold, and sometimes a ring.
func on_star_caught(at: Vector2) -> void:
	_stars_caught += 1
	if _stars_caught == 2 and setting() == "Star Chamber":
		props.appear("still_star", Vector2(1010, 70), 22.0)  # the third one waits
		popups.word(Vector2(1010, 110), "one stays...", Color(1.0, 0.95, 0.7))
	overlay.starburst(at, 120.0, Color(1.0, 0.95, 0.7))
	Sfx.play("ting", 0.0, 2.0)
	_spawn_coins(rng.randi_range(12, 20), at, 40.0)
	if rng.randf() < 0.4:
		var rings := ItemDefs.ring_ids()
		_spawn(ItemDefs.make_upgrade(rings[rng.randi() % rings.size()]), at)
	save.discover("secrets", "star")


## Where the hidden lever is on screen, if this setting has one still up.
func _lever_screen() -> Vector2:
	if backdrop == null or backdrop.lever == null or backdrop.lever_pulled or state != State.COMBAT:
		return Vector2.INF
	return camera.unproject_position(backdrop.lever.global_position)


func _try_lever(at: Vector2, reach: float) -> bool:
	var lp := _lever_screen()
	if not lp.is_finite() or at.distance_to(lp) > reach:
		return false
	backdrop.pull_lever()
	secret_next = true
	save.discover("secrets", "vault")
	overlay.ring(lp, 120.0, Color(1.0, 0.85, 0.3), 0.8)
	overlay.sparks(lp, 40000.0, Color(1.0, 0.85, 0.3))
	Sfx.play("gong", -4.0, 0.5)
	Sfx.play("clack", 0.0, 0.6)
	_shake += 12.0
	return true


func _gong() -> Dictionary:
	return HOME_GONG if state == State.HOME else GONG


func _over_gong(it: Item) -> bool:
	var g := _gong()
	for c in it.cells:
		if it.to_global(it.cell_pos(c)).distance_to(g.pos) <= g.radius:
			return true
	return false


func _on_punched(at: Vector2) -> void:
	Sfx.play("swing", -12.0, 1.6)
	if state in [State.SHOP, State.HOME] and at.distance_to(_gong().pos) <= _gong().radius + 8.0:
		_strike_gong()
		return
	if state == State.SHOP and at.distance_to(DICE.pos) <= DICE.radius + 10.0:
		_reroll()
		return
	if state == State.SHOP and not overlay.door.is_empty() and at.distance_to(DOOR.pos) <= DOOR.radius + 10.0:
		if hand.held:
			_return_home()
		else:
			overlay.ring(DOOR.pos, 30.0, Color(1, 0.3, 0.2), 0.3)  # bring something home
			Sfx.play("deny")
		return
	if _try_lever(at, 24.0):
		return
	if state == State.COMBAT and props.punch(at):
		return
	if state != State.COMBAT or living().is_empty():
		return
	for r in _all_regions():
		if at.distance_to(r.center) <= r.radius + 6.0:
			var e: Enemy = r.who
			var dmg: float = PUNCH_DAMAGE * hand.strength * r.mult * e.punch_mult()
			e.take_hit(dmg, r.id, true, PUNCH_STAGGER)
			Sfx.play("punch", 0.0)
			overlay.ring(r.center, r.radius, Color(1, 1, 0.85), 0.25)
			return


## Space with something in hand: smash a potion, put on an upgrade, dab a kit on
## something, bind a bandage, open a menu, or peel a stuck thing loose.
## Space while holding something: at the door after a boss it takes you home with it.
func _knock_holding(at: Vector2) -> bool:
	if state == State.SHOP and not overlay.door.is_empty() and at.distance_to(DOOR.pos) <= DOOR.radius + 10.0:
		_return_home()
		return true
	return false


func _on_item_activated(it: Item) -> void:
	if it.def.kind == "shield" or (it == hand.held and hand.grip_kind() == "shield"):  # (a glued thing held by its shield braces)
		if it.brace():
			Sfx.play("clang", -8.0, 1.5)
			overlay.ring(it.global_position, 50.0, Color(1.0, 0.85, 0.35), 0.25)
	elif it.def.kind == "potion":
		hand.release()
		it.shatter()  # smash it in your hand: it spills right there
	elif it.def.kind == "upgrade":
		_wear(it)
	elif it.def.kind == "menu":
		_open_menu(it)
	elif it.def.has("applies"):
		_apply_from(it)
	elif it.def.kind == "consumable" and it.def.has("heal"):
		hand.heal(it.def.heal)
		hand.release()
		it.queue_free()



## The furniture at home is the menu: the codex opens the index, the mirror tries on
## another gauntlet.
func _open_menu(it: Item) -> void:
	match it.def.get("menu", ""):
		"codex":
			if codex.is_open():
				codex.toggle()
			else:
				codex.open_tab(int(it.def.get("tab", 0)))
		"mirror":
			looks.set_choice("hand", Looks.choice.hand + 1)
			overlay.ring(hand.position, 30.0, Color(1, 1, 0.9), 0.3)


## A volatile item went off: shove and shred everything nearby, set things alight,
## hurt the hand, and hurt the enemy if it went off over one of its body parts.
func on_explosion(at: Vector2, radius: float, power: float, source: Item) -> void:
	explosions += 1
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it == null or it == source or it.is_queued_for_deletion():
			continue
		var d := it.global_position.distance_to(at)
		if d > radius + it.origin.length():
			continue
		var f := clampf(1.0 - d / radius, 0.2, 1.0)
		it.apply_central_impulse((it.global_position - at).normalized() * it.mass * 700.0 * f * power)
		it.heat = maxf(it.heat, 0.8 * f)
		for c in it.cells.keys():
			var cd := it.to_global(it.cell_pos(c)).distance_to(at)
			if cd < radius:
				it.damage_cell(c, 4.0 * power * (1.0 - cd / radius), false)
	var hd := hand.position.distance_to(at)
	if hd < radius:
		hand.hurt(30.0 * power * (1.0 - hd / radius))
	if state == State.COMBAT:
		for r in _all_regions():
			var ed: float = r.center.distance_to(at)
			if ed < radius:
				var dmg: float = 30.0 * power * (1.0 - ed / radius) * r.mult
				r.who.take_hit(dmg, r.id)
				overlay.ring(r.center, radius, Color(1, 0.6, 0.2), 0.5)
				break
	overlay.sparks(at, 400000.0 * power)
	_shake += 25.0 * power


## A crate was smashed open: its contents tumble out where it broke.
func on_crate_broken(crate: Item) -> void:
	var at := crate.to_global(crate.center_of_mass)
	overlay.sparks(at, 20000.0, Color(1, 0.85, 0.5))
	Sfx.play("crack", 0.0, 0.7)
	for find in ItemDefs.roll_loot(int(crate.def.loot), rng):
		if find.has("coins"):
			_spawn_coins(find.coins, at, 120.0)
		else:
			var it := _spawn(find, at + Vector2(randf_range(-15, 15), -10))
			it.owned = crate.owned
			it.freeze = false
			it.linear_velocity = Vector2(randf_range(-150, 150), randf_range(-350, -150))
			it.angular_velocity = randf_range(-4, 4)


## A potion broke: its liquid sprays out as pixels that soak into whatever they land on.
func on_potion_shatter(p: Item) -> void:
	var at := p.to_global(p.center_of_mass)
	if p.def.liquid == "homeward":
		_homeward(at, p)
		return
	on_potion_shatter_at(at, p.def.liquid, p.def.liquid_color, p.linear_velocity)


## Homeward Brew: no spill to aim. Whatever whole thing is nearest where it broke (it passes
## through gear, so hold it right over what you want) goes home.
func _homeward(at: Vector2, brew: Item) -> void:
	overlay.sparks(at, 8000.0, Color(0.5, 0.9, 0.7))
	Sfx.play("crack", 0.0, 1.8)
	var best: Item = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it == null or it == brew or not it.owned or it.is_queued_for_deletion() or it.def.kind in ["coin", "debris", "menu"]:
			continue
		var c := it.nearest_cell(at)
		if not it.cells.has(c):
			continue
		var d := it.to_global(it.cell_pos(c)).distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = it
	if best:
		_send_home(best)


func on_potion_shatter_at(at: Vector2, liquid: String, color: Color, vel: Vector2 = Vector2.ZERO) -> void:
	liquids.spill(at, liquid, color, 60, vel)
	overlay.sparks(at, 8000.0, Color(0.85, 0.95, 1.0))
	Sfx.play("crack", 0.0, 1.8)
	Sfx.play("soft", -4.0, 1.4)


const TRANSMUTE_SPREAD := 12  # cells one drop converts, soaking outward from where it lands
const MEND_PER_DROP := 0.12  # share of a whole piece's toughness each drop of mending puts back


func it_color(mat: String) -> Color:
	return (Materials.get_mat(mat).color as Color).lightened(0.4)


const TRANSMUTE := {"to_prestigium": "prestigium", "to_steel": "steel", "to_iron": "iron", "to_copper": "copper", "to_gold": "gold",
	"to_stone": "stone", "to_wood": "wood"}


## One liquid pixel landed on an item. Transmutation changes the cell it hit; coatings
## build up and take hold once enough has soaked in.
func soak(it: Item, at: Vector2, liquid: String) -> void:
	var c := it.cell_at_global(at)
	if not it.cells.has(c):
		c = it.nearest_cell(at)
	if TRANSMUTE.has(liquid):
		var mat: String = TRANSMUTE[liquid]
		var turned := it.transmute_spread(c, mat, TRANSMUTE_SPREAD)
		if turned > 0:
			overlay.sparks(at, 1500.0 * turned, it_color(mat))
			it.adopt_material(mat)
		if liquid == "to_gold":
			_gild(it)
		return
	if liquid == "glue":
		it.glue_patch(at, 0)  # pitch glues the pixel it lands on
		return
	if liquid == "mending":
		# the draught works on the whole piece, not the spot it landed on: a handful of drops
		# brings a battered blade back to new
		if it.repair(MEND_PER_DROP) > 0.0:
			overlay.sparks(at, 1200.0, Color(0.5, 1.0, 0.6))
		return
	it.soak[liquid] = it.soak.get(liquid, 0) + 1
	if it.soak[liquid] < maxi(3, int(it.cells.size() * 0.15)):
		return
	match liquid:
		"poison":
			it.add_mod("poisoned")
		"oil":
			it.add_mod("oiled")
		"glue":
			pass  # (handled per drop above)
		"levitation":
			it.add_mod("weightless")
		"grow":
			it.rescale(1.5)
			overlay.ring(it.global_position, 60.0, Color(0.9, 0.55, 0.2), 0.4)
		"shrink":
			it.rescale(0.65)
			overlay.ring(it.global_position, 40.0, Color(1.0, 0.75, 0.9), 0.4)
		"lead":
			it.add_mod("heavy")
		"homeward":
			_send_home(it)
		"frost":
			it.cold = 1.0
		"fire":
			it.heat = 1.0
		"lightning":
			it.charge = 1.0


## Homeward Brew: the item is whisked off to your shelf at home, to keep.
func _send_home(it: Item) -> void:
	if it.def.kind in ["coin", "debris", "menu"] or it.is_queued_for_deletion():
		return
	var e := SaveData.pack(it)
	e.slot = -1
	e.pos = Vector2(640, 600)
	save.home.append(e)
	save.write()
	overlay.sparks(it.global_position, 40000.0, Color(0.5, 0.9, 0.7))
	overlay.ring(it.global_position, 90.0, Color(0.5, 0.9, 0.7), 0.6)
	Sfx.play("gong", -8.0, 2.0)
	if hand.held == it:
		hand.release()
	it.queue_free()


## Scraps turned wholly to gold are as good as coins.
func _gild(it: Item) -> void:
	if it.def.kind != "debris" or it.is_queued_for_deletion():
		return
	for c in it.cells:
		if it.cells[c].mat != "gold":
			return
	_spawn_coins(it.cells.size(), it.global_position, 40.0)
	overlay.sparks(it.global_position, 6000.0, Color(1, 0.85, 0.3))
	it.queue_free()


func on_tempered(it: Item) -> void:
	overlay.sparks(it.global_position, 20000.0, Color(0.9, 0.95, 1.0))
	overlay.ring(it.global_position, 50.0, Color(0.7, 0.85, 1.0))
	Sfx.play("soft", 0.0, 2.0)


## Glue pot and friends: dab the modifier onto the item the pot is touching (or under the hand).
func _apply_from(pot: Item) -> void:
	var target: Item = null
	for b in pot.get_colliding_bodies():
		if b is Item and b.def.kind != "debris":
			target = b
			break
	if target == null:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = hand.position
		q.collision_mask = 1
		q.exclude = [pot.get_rid()]
		for h in get_viewport().world_2d.direct_space_state.intersect_point(q, 4):
			if h.collider is Item:
				target = h.collider
				break
	if target == null:
		overlay.ring(hand.position, 20.0, Color(0.7, 0.7, 0.7), 0.25)  # nothing to dab it on
		return
	if pot.def.applies == "sticky":
		# glue goes on as a patch where the pot touches (or under the hand)
		var at := hand.position
		var best := INF
		for c in pot.cells:
			var p := pot.to_global(pot.cell_pos(c))
			var near := target.to_global(target.cell_pos(target.nearest_cell(p)))
			if p.distance_to(near) < best:
				best = p.distance_to(near)
				at = near
		target.glue_patch(at, 1)
	else:
		target.add_mod(pot.def.applies)
	save.discover("modifiers", pot.def.applies)
	Sfx.play("soft", 0.0, 0.6)
	overlay.ring(target.global_position, 50.0, Color(0.85, 0.9, 0.3))
	var uses: int = pot.get_meta("uses", pot.def.get("uses", 1)) - 1
	pot.set_meta("uses", uses)
	if uses <= 0:
		hand.release()
		pot.queue_free()


func _on_ring_used(ring: String, at: Vector2, finger: int) -> void:
	var target: Item = hand.held if hand.held else hand.item_under(at)
	match ring:
		"ring_levitation":
			if target:
				target.weightless_for(6.0)
			else:
				hand.ring_cds[finger] = 0.0  # nothing to use it on: no charge spent
		"ring_mending":
			if target:
				target.repair(0.5)
			else:
				hand.ring_cds[finger] = 0.0  # nothing to use it on: no charge spent
		"ring_recall":
			for it in items_root.get_children():
				if it is Item and it.owned and it.def.kind != "debris":
					it.apply_central_impulse((at - it.global_position).normalized() * it.mass * 900.0)
		"ring_tempo":
			for e in living():
				e.slow_time = 3.0
		"ring_echoes":
			if _last_blocked > 0.0 and state == State.COMBAT and not living().is_empty():
				var foe: Enemy = living()[0]
				foe.take_hit(_last_blocked * 2.5, "torso", true)
				overlay.streak(at, camera.unproject_position(foe.torso.global_position), 5.0, Color(0.7, 0.5, 1.0))
				overlay.ring(camera.unproject_position(foe.torso.global_position), 90.0, Color(0.7, 0.5, 1.0), 0.4)
				Sfx.play("parry", -4.0, 0.7)
				_last_blocked = 0.0
			else:
				hand.ring_cds[finger] = 0.0  # nothing blocked yet: no charge spent
		"ring_juggler":
			for it in items_root.get_children():
				if it is Item and it.owned and not it.freeze and not it.held and it.def.kind != "debris":
					it.apply_central_impulse(Vector2(randf_range(-250, 250), -randf_range(700, 1100)) * it.mass)
					it.angular_velocity = randf_range(-6, 6)
			Sfx.play("swing", -2.0, 0.6)
		"ring_well":
			hand.well_time = 3.0
			overlay.ring(at, 120.0, Color(0.3, 0.15, 0.5), 0.5)
		"ring_reversal":
			for it in items_root.get_children():
				if it is Item and it.owned and not it.freeze:
					it.reverse_time = 3.0
			overlay.ring(at, 120.0, Color(0.4, 1.0, 0.85), 0.5)
		"ring_alchemy":
			if target and _alchemize(target):
				overlay.sparks(target.global_position, 30000.0, Color(1.0, 0.85, 0.3))
				Sfx.play("ting", -2.0, 0.9)
			else:
				hand.ring_cds[finger] = 0.0  # nothing it can work on: no charge spent
		"ring_gambler":
			if randf() < 0.5:
				hand.gamble_mult = 6.0
				overlay.starburst(at, 90.0, Color(1.0, 0.85, 0.3))
				Sfx.play("ting", 0.0, 1.4)
			else:
				hand.hurt(12.0)
				overlay.ring(at, 60.0, Color(1.0, 0.2, 0.2), 0.3)
				Sfx.play("crack", -2.0, 0.8)
		"ring_bloodletting":
			if hand.wound(BLOODLET) > 0.0:
				hand.blood_mult = 3.0
				overlay.ring(at, 60.0, Color(0.7, 0.0, 0.05), 0.3)
				overlay.sparks(at, 6000.0, Color(0.7, 0.0, 0.05))
				Sfx.play("crack", -4.0, 0.7)
			else:
				hand.ring_cds[finger] = 0.0  # nothing left to bleed: no charge spent
		"ring_wrath":
			hand.wrath_time = 4.0
			overlay.ring(at, 80.0, Color(1.0, 0.2, 0.1), 0.4)
		"ring_storm":
			if hand.held and hand.held.def.kind == "weapon":
				hand.held.storm_time = 6.0
				overlay.sparks(hand.held.global_position, 20000.0, Color(0.6, 0.85, 1.0))
			else:
				hand.ring_cds[finger] = 0.0  # nothing to charge: no charge spent


# --- per frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.VICTORY:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_open_shop()
	elif state == State.DEFEAT:
		_state_timer -= delta
		if _state_timer <= 0.0:
			get_tree().reload_current_scene()  # the run is lost: back home
			return  # this scene is out of the tree now
	overlay.weak = {}
	overlay.exposed = []
	overlay.enemy_fire = Rect2()
	overlay.water_y = WATER_Y if state == State.COMBAT and setting() == "Cistern" else -1.0
	overlay.hearth = HEARTH if state == State.COMBAT and setting() == "Forge" else Rect2()
	overlay.zones = []
	for e in living():
		if e.burning_time > 0.0:
			var a := camera.unproject_position(e.torso.global_position + Vector3(-0.3, -0.25, 0))
			var b := camera.unproject_position(e.head.global_position + Vector3(0.3, 0.2, 0))
			overlay.enemy_fire = Rect2(a, Vector2.ZERO).expand(b)
	if state == State.COMBAT:
		var shown := false
		for e in living():
			e.look_target = hand.position / SCREEN
			if e.state == "windup" and not e.current.is_empty():
				var zone := _zone_px(e.current)
				var d: Vector2 = (e.current.dir as Vector2).normalized()
				var w := clampf(e.current.damage / 30.0, 0.4, 1.6)
				var lanes := Lanes.build(zone, d)
				var cov: Array = e.get_meta("lane_cover", [])
				if cov.size() != lanes.size() or Engine.get_process_frames() % PREVIEW_EVERY == 0:
					cov = _preview_cover(lanes, float(e.current.get("cleave", 0.0)))
					e.set_meta("lane_cover", cov)
				if not shown:
					overlay.show_zone(zone, e.progress, d, w, e.current.get("trait", ""))
					overlay.lanes = lanes
					overlay.cover = cov
					shown = true
				else:
					overlay.zones.append({"poly": zone, "progress": e.progress, "dir": d, "weight": w, "trait": e.current.get("trait", ""),
						"lanes": lanes, "cover": cov})
			for r in e.regions():
				if r.id == "weak":
					overlay.weak = r
				elif r.id == "exposed":
					overlay.exposed.append(r)
		if not shown:
			overlay.clear_zone()
	_shake = clampf(_shake - delta * 20.0, 0.0, SHAKE_CAP)
	clock += delta
	_track_held()
	_tick_wisps(delta)
	_tick_storms(delta)
	var lp := _lever_screen()
	if lp.is_finite():
		_glint -= delta
		if _glint <= 0.0:
			_glint = rng.randf_range(3.0, 6.0)
			overlay.sparks(lp + Vector2(0, -6), 3000.0, Color(1, 0.95, 0.7))
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.004 * Settings.shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.004 * Settings.shake
	_debris_check -= delta
	if _debris_check <= 0.0 or get_tree().get_nodes_in_group("items").size() > BODY_CAP:
		_debris_check = 1.0
		_merge_coins()
		_cap_debris()
		_refresh_hoard()
	if state == State.COMBAT:
		_tick_blood(delta)
	Music.critical = state == State.COMBAT and hand.hurt_fraction() > CRITICAL_HURT
	if state != State.DEFEAT and state != State.HOME and hand.injury >= hand.max_hp:
		_defeat()  # in a fight, in the shop or in between: a ruined hand ends the run
	if debug_label.visible:
		_update_debug()


## A big hoard fuses: five coins into a fat coin, five fat coins into a gold bar. Same value,
## a fraction of the bodies (hundreds of loose coins were most of a long run's frame time).
## Only coins down in the pile, never one in hand or up on a shelf being paid with.
func _merge_coins() -> void:
	var loose := {"coin": [], "coin5": []}
	var count := 0
	for n in get_tree().get_nodes_in_group("coins"):
		var c := n as Item
		if c == null or c.is_queued_for_deletion() or not c.owned:
			continue
		count += 1
		var id: String = c.def.get("id", "")
		if loose.has(id) and not c.held and not c.freeze and c.global_position.y > SCREEN.y * 0.5 and not c.def.get("piece", false):
			loose[id].append(c)
	var merges := 0
	for id in ["coin", "coin5"]:
		var group: Array = loose[id]
		group.sort_custom(func(a: Item, b: Item) -> bool: return a.global_position.x < b.global_position.x)  # neighbours fuse
		while group.size() >= 5 and count > COIN_BODIES and merges < COIN_MERGES:
			var five := group.slice(0, 5)
			group = group.slice(5)
			var top: Vector2 = five[0].global_position
			for c in five:
				if c.global_position.y < top.y:
					top = c.global_position
				c.queue_free()
			var big := _spawn(ItemDefs.make("coin5" if id == "coin" else "coin25", "gold"), top + Vector2(0, -10))
			overlay.sparks(big.global_position, 4000.0, Color(1, 0.85, 0.3))
			count -= 4
			merges += 1
	if merges > 0:
		Sfx.play("ting", -10.0, 0.8)


## Splinters and scraps stay on screen, but past a cap the oldest ones go.
func _cap_debris() -> void:
	var debris := get_tree().get_nodes_in_group("debris")
	if debris.size() > DEBRIS_CAP:
		debris.sort_custom(func(a: Item, b: Item) -> bool: return a.age > b.age)
		for i in debris.size() - DEBRIS_CAP:
			debris[i].queue_free()
	var bodies := get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	if bodies.size() > BODY_CAP:
		bodies = bodies.filter(func(n: Item) -> bool: return n.def.kind != "coin")  # that's money: coins fuse instead
		# smallest first, then oldest; never the thing in your hand
		bodies.sort_custom(func(a: Item, b: Item) -> bool:
			return a.cells.size() < b.cells.size() if a.cells.size() != b.cells.size() else a.age > b.age)
		var extra := bodies.size() - BODY_CAP
		for n in bodies:
			if extra <= 0:
				break
			if n != hand.held:
				n.queue_free()
				extra -= 1


func _on_look_changed(part: String) -> void:
	if part == "enemy" and enemy:
		enemy.rebuild_look()


## Developer readout (F1). Players never see this.
func _update_debug() -> void:
	var lines := PackedStringArray()
	var coins := 0
	for n in get_tree().get_nodes_in_group("coins"):
		if n is Item and n.owned:
			coins += coin_value(n)
	lines.append("round %d   prestige %d   coins %d   state %s" % [round_num + 1, prestige, coins, State.keys()[state]])
	for e in living():
		lines.append("%s hp %d/%d [%s] off_balance %.1f queued %s" % [e.data.name, ceili(e.hp), e.max_hp, e.state, e.off_balance, e._queued])
	lines.append("hand %d/%d grip %d%% rings %s/%d punch %.1f  hoard wear %.2f stagger %.2f dmg %.2f" % [hand.injury, hand.max_hp, hand.grip() * 100.0, hand.rings, hand.ring_slots, hand.punch_cooldown, hoard_wear, hoard_stagger, hoard_damage])
	var hov := hand.held if hand.held else hand.item_under(hand.position)
	if hov:
		lines.append(hov.describe() + ("   cd %.1f" % hov.cooldown if hov.def.has("cooldown") else ""))
	debug_label.text = "\n".join(lines)
