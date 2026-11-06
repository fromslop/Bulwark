extends SceneTree
## Headless checks of the core mechanics.
## Run: Godot_console.exe --headless --path . -s res://tests/smoke_test.gd

var main: Node
var frame := 0
var fails := PackedStringArray()
var shield: Item
var shield_hp_before := 0.0
var crate_count_before := 0
var parry_leak := {}
var zap_rock: Item
var zap_sword: Item
var hot_rock: Item
var crate2: Item
var glue_a: Item
var glue_b: Item
var magnet: Item
var pulled: Item
var pulled_start := 0.0
var unpulled: Item
var unpulled_start := 0.0
var fire_crate: Item
var ice: Item
var bomb: Item
var bomb_neighbor: Item
var bomb_neighbor_hp := 0.0
var dropped_on: Item
var dropped_on_hp := 0.0
var acid: Item
var rusting: Item
var rust2: Item
var paid_item: Item
var purse: Item
var ledger: Item
var coins_before_kill := 0
var real_max_hp := 0.0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save = SaveData.new()
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		20:
			# the opening kit is random; the tests bring their own
			main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(380, 560))
			main._spawn(ItemDefs.make("shortsword", "copper"), Vector2(640, 520))
			main._spawn(ItemDefs.make("crate", "wood"), Vector2(900, 620))
		30:
			main.enemy.active = false  # we'll trigger attacks ourselves
			main.enemy._begin_attack()
			_check(main.enemy.current.damage <= 16.0, "stage one attacks should hit at half strength (got %.1f)" % main.enemy.current.damage)
			main.enemy.state = "idle"
			main.enemy.current = {}
			real_max_hp = main.enemy.max_hp
			main.enemy.max_hp = 1e6  # stray blasts in the pile tests mustn't kill it early
			main.enemy.hp = 1e6
			_place_shield()
		34:
			_test_block()
		40:
			_check(shield.health_ratio() < shield_hp_before, "blocked attack should damage the shield")
			_check(main.hand.injury < 28.0 * 0.6, "shield should keep most damage off the hands (got %.1f)" % main.hand.injury)
			_test_split()
		50:
			var pieces := 0
			for it in main.items_root.get_children():
				if it is Item and it.def.id == "crate" and it.cells.size() > 3:
					pieces += 1
			_check(pieces >= 2, "cutting a crate in half should give two bodies (got %d)" % pieces)
			_test_materials()
			_test_parry()
		60:
			_test_weapon_hit()
			_test_punch()
			_setup_elements()
			_test_cooldowns()
			_test_near_grab()
			_test_real_block()
		200:
			_check_elements()  # awaits a few physics frames
		203:
			_clear_field()
		205:
			_setup_pile()
		212:
			_test_weapon_traits()
			_test_rings()
		250:
			# checked before the volatile crate further along the floor goes off and shoves everything
			_check(pulled.global_position.distance_to(magnet.global_position) < pulled_start - 30.0,
				"a magnet should pull a loose pauldron closer")
			_check(unpulled.global_position.x > unpulled_start - 20.0, "a magnet should leave whole gear (a sword) where it is (moved %.0f)" % (unpulled.global_position.x - unpulled_start))
		420:
			_check_pile()
			_test_wear_and_armor()
			_test_crates()
		425:
			_kill_enemy()
		430:
			_check_utilities()
		440:
			var coins := 0
			for n in main.get_tree().get_nodes_in_group("coins"):
				coins += main.coin_value(n)
			_check(coins >= main.enemy.data.reward, "a kill should spill coins into the play field (got %d)" % coins)
		600:
			_check(main.state == main.State.SHOP, "the shop should open after a kill")
			_test_shop_layout()
			_test_reroll()
		640:
			_pay_shelf()
		700:
			_check(paid_item != null and is_instance_valid(paid_item) and paid_item.owned, "enough coins on a shelf should buy its item")
			main._on_punched(main.GONG.pos)
		780:
			_check(main.state == main.State.COMBAT and main.round_num == 1, "punching the gong should start the next fight")
			main.state = main.State.SHOP
			main.hand.injury = main.hand.max_hp
		782:
			_check(main.state == main.State.DEFEAT, "a ruined hand should end the run in the shop too")
		790:
			main.enemy.active = false
			main.state = main.State.COMBAT
			main.hand.injury = 0.0
			_test_potions()
		920:
			print("smoke test: %d failures" % fails.size())
			for f in fails:
				print("  FAIL ", f)
			quit(1 if fails.size() > 0 else 0)
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


func _find(id: String) -> Item:
	for it in main.items_root.get_children():
		if it is Item and it.def.id == id:
			return it
	return null


func _place_shield() -> void:
	shield = _find("round_shield")
	shield.freeze = true
	shield.teleport(Vector2(640, 0.27 * 720))


func _test_block() -> void:
	main.hand.injury = 0.0
	shield_hp_before = shield.health_ratio()
	var atk: Dictionary = EnemyDefs.ATTACKS["slash_high_r"].duplicate()
	# thin zone that the shield fully covers
	atk.zone = [Vector2(0.47, 0.22), Vector2(0.53, 0.22), Vector2(0.53, 0.32), Vector2(0.47, 0.32)]
	main._resolve_attack(atk)


func _test_split() -> void:
	var crate := _find("crate")
	for c in crate.cells.keys():
		if c.x == 5:
			crate.damage_cell(c, 999.0, false)


func _test_materials() -> void:
	var copper := Item.create(ItemDefs.make("buckler", "copper"))
	var steel := Item.create(ItemDefs.make("buckler", "steel"))
	for it in [copper, steel]:
		for c in it.cells.keys():
			it.damage_cell(c, 3.0, false)
	_check(steel.health_ratio() > copper.health_ratio(), "steel should hold up better than copper")
	copper.free()
	steel.free()


func _test_parry() -> void:
	_check(Item.parry_for_speed(100.0) == 0.0, "slow items shouldn't parry")
	_check(Item.parry_for_speed(5000.0) == 1.0, "very fast items should parry fully")


func _test_weapon_hit() -> void:
	var sword := _find("shortsword")
	var regs: Array = main.enemy.regions()
	var torso: Dictionary = regs[regs.size() - 1]
	sword.freeze = true
	sword.teleport(torso.center)
	sword.swing_time = 0.3
	sword.swing_hit = false
	var before: float = main.enemy.hp
	var hit: bool = main._check_weapon_hit(sword, regs)
	_check(hit and main.enemy.hp < before, "a sword over the torso should hit")


func _test_punch() -> void:
	var regs: Array = main.enemy.regions()
	var before: float = main.enemy.hp
	main._on_punched(regs[0].center)
	_check(main.enemy.hp < before, "punching the head should hurt the enemy")


func _setup_elements() -> void:
	# electrified rock resting on an iron sword lying flat on the floor
	zap_sword = main._spawn(ItemDefs.make("longsword", "iron"), Vector2(300, 690))
	zap_sword.rotation = PI / 2
	# a flat charged strongbox (a round rock tends to roll off the blade; a wooden crate can
	# catch fire from the hot test across the floor, and a fire takes its charge with it)
	zap_rock = main._spawn(ItemDefs.make("strongbox", "iron", ["electrified"]), Vector2(300, 630))
	# red-hot rock dropped on a crate
	crate2 = main._spawn(ItemDefs.make("crate", "wood"), Vector2(800, 680))
	hot_rock = main._spawn(ItemDefs.make("strongbox", "iron", ["superheated"]), Vector2(800, 560))  # flat, dropped from clear above: lands on it
	# sticky buckler pressed (held) onto another crate
	glue_b = main._spawn(ItemDefs.make("crate", "wood"), Vector2(1100, 680))
	glue_a = main._spawn(ItemDefs.make("buckler", "wood", ["sticky"]), Vector2(1100, 620))
	glue_a.glue_patch(glue_a.global_position + Vector2(0, 60), 1)  # glue on its underside, the side that lands
	glue_a.held = true  # in your hand: pressing it on fuses it
	main.hand.injury = 0.0


func _check_elements() -> void:
	_check(zap_sword.charge > 0.5, "iron touching an electrified strongbox should be charged (got %.2f)" % zap_sword.charge)
	_check(is_instance_valid(crate2) and crate2.heat > 0.3, "a crate under a red-hot rock should heat up")
	_check(glue_a.has_part("crate"), "a buckler with glue on its underside, pressed on by hand, should fuse with the crate it lands on")
	glue_a.held = false
	var loose: Item = main._spawn(ItemDefs.make("buckler", "wood", ["sticky"]), Vector2(1100, 500))
	loose.glue_patch(loose.global_position + Vector2(0, 60), 1)
	loose.teleport(Vector2(1100, 560))
	await physics_frame
	await physics_frame
	await physics_frame
	_check(is_instance_valid(loose) and not loose.def.has("parts") and loose._glue > 0, "a glued thing just dropped into the pile (no hand on it) shouldn't grab anything")
	loose.queue_free()
	var blade := Vector2i(-1, -1)
	for c in zap_sword.cells:
		if not zap_sword.cells[c].get("handle", false) and zap_sword.cells[c].mat == "iron":
			blade = c
	var before: float = main.hand.injury
	main.hand.held = zap_sword
	main.hand.grab_local = zap_sword.cell_pos(blade)  # by the blade
	main.hand._touch_hazards(0.5)
	_check(main.hand.held == null and main.hand.stunned > 0.0, "a charged sword should jolt the hand: it drops it and is stunned")
	main.hand.held = null
	_check(main.hand.injury > before, "holding a charged sword should hurt")
	var zapped_at: Vector2 = main.hand.position
	main.hand.pinned = zapped_at + Vector2(200, 0)
	await process_frame
	_check(main.hand.position.distance_to(zapped_at) < 10.0, "a stunned hand should stay where it was zapped")
	main.hand.pinned = Vector2.INF
	main.hand.stunned = 0.0
	before = main.hand.injury
	main.hand.held = null
	main.hand.position = zap_sword.global_position
	main.hand._touch_hazards(0.5)
	_check(main.hand.injury == before, "hovering over a charged sword should be harmless")
	# the same charged sword held by its wrapped handle is safe
	before = main.hand.injury
	main.hand.held = zap_sword
	var handle := Vector2i(-1, -1)
	for c in zap_sword.cells:
		if zap_sword.cells[c].get("handle", false):
			handle = c
	main.hand.grab_local = zap_sword.cell_pos(handle)
	main.hand._touch_hazards(0.5)
	main.hand.held = null
	_check(main.hand.injury == before, "holding a charged sword by its wrapped handle should be safe")
	main.hand.wear_ring("ring_grounding")
	zap_sword.heat = 0.0  # (shock alone: any warmth it caught from the fire test isn't the ring's to stop)
	zap_sword.cold = 0.0
	before = main.hand.injury
	main.hand.held = zap_sword
	main.hand.grab_local = zap_sword.cell_pos(blade)
	main.hand._touch_hazards(0.5)
	main.hand.held = null
	_check(main.hand.injury == before, "Ring of Grounding should block shocks")


func _clear_field() -> void:
	for it in main.items_root.get_children():
		it.queue_free()


func _setup_pile() -> void:
	var normal := Item.create(ItemDefs.make("round_shield", "wood"))
	var large := Item.create(ItemDefs.make("round_shield", "wood", ["large"]))
	_check(large.cells.size() > normal.cells.size() * 2 and large.mass > normal.mass * 2, "a large shield should have more cells and mass")
	normal.free()
	large.free()
	magnet = main._spawn(ItemDefs.make("buckler", "wood", ["magnetic"]), Vector2(100, 690))
	pulled = main._spawn(ItemDefs.make("pauldron", "iron"), Vector2(240, 690))
	pulled_start = pulled.global_position.distance_to(magnet.global_position)
	unpulled = main._spawn(ItemDefs.make("shortsword", "iron"), Vector2(350, 704))  # flat on the floor, in range, touching nothing
	unpulled.rotation = PI / 2
	unpulled_start = unpulled.global_position.x
	fire_crate = main._spawn(ItemDefs.make("crate", "wood"), Vector2(520, 685))
	fire_crate.heat = 1.0
	fire_crate.def.opened = true  # it burns open now: keep its random loot out of this test
	ice = main._spawn(ItemDefs.make("rock", "stone", ["frosty"]), Vector2(520, 630))
	bomb = main._spawn(ItemDefs.make("crate", "wood", ["volatile"]), Vector2(700, 685))
	main._spawn(ItemDefs.make("rock", "stone", ["superheated"]), Vector2(700, 630))
	bomb_neighbor = main._spawn(ItemDefs.make("buckler", "wood"), Vector2(790, 690))
	bomb_neighbor_hp = bomb_neighbor.health_ratio()
	dropped_on = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(950, 670))
	dropped_on_hp = dropped_on.health_ratio()
	var mace: Item = main._spawn(ItemDefs.make("mace", "steel", ["heavy"]), Vector2(950, 100))
	mace.linear_velocity = Vector2(0, 2500)
	rusting = main._spawn(ItemDefs.make("strongbox", "iron"), Vector2(1180, 675))
	rust2 = main._spawn(ItemDefs.make("strongbox", "iron"), Vector2(1097, 675))  # beside it, never touching the acid
	acid = main._spawn(ItemDefs.make("rock", "stone", ["corrosive"]), Vector2(1180, 610))
	main.hand.position = Vector2(-500, -500)


func _check_pile() -> void:
	_check(not is_instance_valid(fire_crate) or not fire_crate.is_burning(), "frost should put a burning crate out")
	_check(not is_instance_valid(bomb), "a volatile crate under a red-hot rock should explode")
	_check(not is_instance_valid(bomb_neighbor) or bomb_neighbor.health_ratio() < bomb_neighbor_hp, "the blast should damage nearby items")
	_check(not is_instance_valid(dropped_on) or dropped_on.health_ratio() < dropped_on_hp, "a hurled steel mace should crack a wooden shield")
	_check(rusting.health_ratio() < 0.999, "a corrosive rock should eat into iron")
	_check(rusting.rusting > 0.5, "iron touching something corrosive should start rusting (%.2f)" % rusting.rusting)
	_check(rust2.rusting <= 0.0, "rust caught from something corrosive shouldn't spread on to the next piece (%.2f)" % rust2.rusting)


## Clicking just beside a thin sword should still pick it up.
func _test_near_grab() -> void:
	var sword: Item = main._spawn(ItemDefs.make("shortsword", "iron"), Vector2(1000, 300))
	sword.freeze = true
	await physics_frame
	await physics_frame
	var beside := sword.global_position + Vector2(14, 0)  # the blade is ~15px wide: this is off it
	_check(main.hand.item_under(beside) == null and main.hand.item_near(beside) == sword, "a click just beside a sword should still find it")
	main.hand.grab(sword, beside)
	_check(main.hand.held == sword and sword.cells.has(sword.cell_at_global(sword.to_global(main.hand.grab_local))), "grabbing from beside should take hold of the nearest bit")
	main.hand.release()
	sword.queue_free()


func _test_cooldowns() -> void:
	var sword := Item.create(ItemDefs.make("shortsword", "iron"))
	_check(sword.start_swing(1.0, 1.0), "first swing should go")
	sword.swing_time = 0.0
	_check(not sword.start_swing(1.0, 1.0), "a second swing inside the cooldown should be refused")
	sword.free()
	main.hand.held = null
	main.hand.punch_cooldown = 0.0
	main.hand._activate()
	var cd: float = main.hand.punch_cooldown
	_check(cd > 0.5, "punching should start a cooldown")
	_check(main.hand.PUNCH_COOLDOWN < Music.BAR / 2.0, "you should be able to punch on every snare (every other beat)")
	main.hand.punch_cooldown = 0.1
	main.hand._activate()  # a touch early: held, and lands as soon as the fist is ready
	_check(main.hand._punch_queued > 0.0, "a punch pressed just before the cooldown ends should be held, not lost")


## A single wooden round shield held in the real high-slash band should stop most of it
## and throw the enemy off balance.
func _test_real_block() -> void:
	if is_instance_valid(shield):
		shield.queue_free()  # the earlier test's shield is still parked in this band
	var s: Item = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(640, 0.27 * 720))
	s.freeze = true
	s.teleport(Vector2(640, 0.27 * 720))
	await physics_frame
	await physics_frame
	main.hand.injury = 0.0
	main.hand.position = Vector2(-500, -500)
	main.enemy.state = "idle"
	main.enemy.off_balance = 0.0
	main._resolve_attack(EnemyDefs.ATTACKS["slash_high_r"].duplicate())
	var took: float = main.hand.injury
	print("  one round shield vs high slash: hand took %.1f of 28" % took)
	_check(took < 28.0 * 0.15, "one well-placed shield should stop 85%%+ of a slash (took %.1f)" % took)
	_check(main.enemy.off_balance > 0.0, "a clean block should throw the enemy off balance")
	# the slash travels right to left: a hand behind (left of) the shield is protected,
	# a hand in front of it (right) is caught before the shield stops the blade.
	# Repair between hits so each one meets the same shield.
	var hit_with_hand_at := func(at: Vector2) -> float:
		s.repair(1.0)
		main.hand.injury = 0.0
		main.hand.position = at
		main._resolve_attack(EnemyDefs.ATTACKS["slash_high_r"].duplicate())
		return main.hand.injury
	var outside: float = hit_with_hand_at.call(Vector2(-500, -500))
	var behind: float = hit_with_hand_at.call(Vector2(560, 0.27 * 720))
	var in_front: float = hit_with_hand_at.call(Vector2(900, 0.27 * 720))
	print("  hand outside zone %.1f, behind shield %.1f, in front of it %.1f" % [outside, behind, in_front])
	_check(behind < outside + 1.0, "a hand behind a blocking shield shouldn't take the in-the-swing penalty (took %.1f vs %.1f)" % [behind, outside])
	_check(in_front > behind + 5.0, "a hand the blade reaches before the shield should get caught")
	s.queue_free()


func _test_wear_and_armor() -> void:
	main.hand.rings.clear()
	main.hand.ring_cds.clear()
	main.hand.ring_slots = 2
	main._wear(main._spawn(ItemDefs.make_upgrade("ring_levitation"), Vector2(600, 400)))
	main._wear(main._spawn(ItemDefs.make_upgrade("ring_grounding"), Vector2(600, 400)))
	_check(main.hand.has_ring("ring_levitation") and main.hand.has_ring("ring_grounding"), "two rings should fit to start")
	main._wear(main._spawn(ItemDefs.make_upgrade("ring_fireward"), Vector2(600, 400)))
	var dropped := false
	for it in main.items_root.get_children():
		if it is Item and it.def.get("upgrade", "") == "ring_levitation" and not it.is_queued_for_deletion():
			dropped = true
	_check(main.hand.rings == ["ring_grounding", "ring_fireward"] and dropped, "a third ring should push the oldest off into the pile")
	for i in 5:
		main._wear(main._spawn(ItemDefs.make_upgrade("slots"), Vector2(600, 400)))
	_check(main.hand.ring_slots == 5, "ring fittings should add slots up to five (got %d)" % main.hand.ring_slots)
	var g: Item = main._spawn(ItemDefs.make_upgrade("strength"), Vector2(600, 400))
	var before: float = main.hand.strength
	main._wear(g)
	_check(main.hand.strength > before, "a gauntlet should strengthen the grip")
	# earlier tests (and the pile explosion) chip the enemy at random: start from fresh
	main.enemy.off_balance = 0.0
	main.enemy.state = "idle"
	main.enemy.stagger_meter = 0.0
	main.enemy.weak_spot.visible = false
	main.enemy.data.stagger = 1e6  # don't let this hit break it (that doubles the damage)
	main.enemy.max_hp = real_max_hp
	main.enemy.hp = real_max_hp
	for pd in main.enemy._pauldrons:
		pd.visible = true
	var before_count := _count("pauldron")
	main.enemy.take_hit(main.enemy.max_hp * 0.4, "torso", false)
	await process_frame
	_check(_count("pauldron") == before_count + 1, "losing a third of its HP should knock a pauldron off")
	var ids: Array = main.enemy.regions().map(func(r: Dictionary) -> String: return r.id)
	_check(ids.has("exposed"), "a stripped pauldron should leave an exposed area")
	_check(not ids.has("weak"), "no weak point until the enemy is broken")
	main.enemy.data.stagger = 35.0
	main.enemy.hp = 1e6
	main.enemy.max_hp = 1e6
	main.enemy.add_stagger(100.0)
	_check(main.enemy.state == "broken" and main.enemy.weak_spot.visible, "a full stagger meter should break the enemy and open a weak point")
	main.enemy.take_hit(1.0, "weak")
	_check(not main.enemy.weak_spot.visible, "the weak point should close after one hit")


func _count(id: String) -> int:
	var n := 0
	for it in main.items_root.get_children():
		if it is Item and it.def.id == id and not it.is_queued_for_deletion():
			n += 1
	return n


func _kill_enemy() -> void:
	for n in main.get_tree().get_nodes_in_group("coins"):
		n.queue_free()
	# a purse and a ledger in the pile, plus 10 coins for interest
	purse = main._spawn(ItemDefs.make("coin_purse", "leather"), Vector2(100, 650))
	ledger = main._spawn(ItemDefs.make("ledger", "leather"), Vector2(200, 650))
	main._spawn_coins(10, Vector2(300, 650), 0.0)
	coins_before_kill = 10
	main.enemy.hp = 1.0
	main.enemy.take_hit(10.0, "torso", false)


func _pay_shelf() -> void:
	var sh: Dictionary = main.shelves[0]
	paid_item = sh.item
	var price: int = sh.price
	for n in main.get_tree().get_nodes_in_group("coins"):
		n.queue_free()
	await process_frame
	# too poor: picking it up does nothing
	main._spawn_coins(price - 1, Vector2(640, 600), 0.0)
	await process_frame
	main._on_buy_attempt(paid_item, paid_item.global_position)
	_check(not paid_item.owned, "picking up shop stock without enough coins shouldn't buy it")
	main._spawn_coins(1, Vector2(700, 600), 0.0)
	await process_frame
	main._on_buy_attempt(paid_item, paid_item.global_position)
	_check(paid_item.owned and main.hand.held == paid_item, "picking up shop stock with enough coins should buy it into your hand")
	_check(paid_item.collision_layer == 1 and paid_item.collision_mask == 3, "bought, it should collide with the hoard again")
	await process_frame
	_check(main.coin_total() == 0, "buying should take the coins out of the pile (left %d)" % main.coin_total())
	main.hand.release()


func _test_crates() -> void:
	for id in ["crate", "strongbox", "reliquary"]:
		var mat: String = ItemDefs.DEFS[id].materials[0]
		var crate: Item = main._spawn(ItemDefs.make(id, mat), Vector2(640, 300))
		var before := {}
		for n in main.items_root.get_children():
			before[n] = true
		for c in crate.cells.keys():
			crate.damage_cell(c, Materials.hp_of(mat) * 0.7, false)
		await process_frame
		await process_frame
		var found := 0
		for n in main.items_root.get_children():
			if not before.has(n) and n is Item and n.def.kind != "debris":
				found += 1
		_check(crate.def.get("opened", false) and found > 0, "a smashed %s should spill loot" % id)
		crate.queue_free()


func _hit_with(it: Item, region: String) -> float:
	var regs: Array = main.enemy.regions()
	var r: Dictionary = {}
	for x in regs:
		if x.id == region:
			r = x
	it.teleport(r.center)
	it.swing_time = 0.3
	it.swing_hit = false
	it.angular_velocity = 10.0
	var before: float = main.enemy.hp
	main._check_weapon_hit(it, [r])
	return before - main.enemy.hp


func _test_weapon_traits() -> void:
	main.enemy.state = "idle"
	main.enemy.data.stagger = 1e6
	main.enemy.hp = 1e6
	main.enemy.max_hp = 1e6
	main.enemy.off_balance = 0.0
	var plain: Item = main._spawn(ItemDefs.make("shortsword", "iron"), Vector2(640, 300))
	var zap: Item = main._spawn(ItemDefs.make("shortsword", "iron", ["electrified"]), Vector2(640, 300))
	for it in [plain, zap]:
		it.freeze = true
	await physics_frame
	var p_torso := _hit_with(plain, "torso")
	var z_torso := _hit_with(zap, "torso")
	_check(z_torso > p_torso * 1.3, "an electrified sword should shock through armour (%.1f vs %.1f)" % [z_torso, p_torso])
	var hot: Item = main._spawn(ItemDefs.make("shortsword", "iron", ["superheated"]), Vector2(640, 300))
	hot.freeze = true
	await physics_frame
	for k in 3:
		_hit_with(hot, "torso")
	_check(main.enemy.burning_time > 0.0, "three superheated hits should set the enemy alight")
	var hp_before: float = main.enemy.hp
	main.enemy.active = true
	for k in 70:
		await process_frame
	main.enemy.active = false
	_check(main.enemy.hp < hp_before, "a burning enemy should take damage over time")
	main.enemy.burning_time = 0.0
	main.enemy.state = "idle"
	main.enemy.current = {}
	var acid: Item = main._spawn(ItemDefs.make("shortsword", "iron", ["corrosive"]), Vector2(640, 300))
	acid.freeze = true
	await physics_frame
	for pd in main.enemy._pauldrons:
		pd.visible = true
	main.enemy.corrosion = 0.0
	for k in 3:
		_hit_with(acid, "head")
	var lost := 0
	for pd in main.enemy._pauldrons:
		if not pd.visible:
			lost += 1
	_check(lost >= 1, "corrosive hits should strip armour")
	for it in [plain, zap, hot, acid]:
		it.queue_free()


func _test_rings() -> void:
	main.hand.rings.clear()
	main.hand.ring_cds.clear()
	main.hand.ring_slots = 5
	main.hand.injury = main.hand.max_hp * 0.8
	var g0: float = main.hand.grip()
	main.hand.wear_ring("ring_desperation")
	_check(main.hand.grip() > g0 * 1.8, "Desperation should max the grip at low health")
	main.hand.injury = 0.0
	main.hand.wear_ring("ring_untouched")
	_check(main._ring_damage_mult() >= 1.39, "the Untouched should boost damage at full health")
	main.hand.wear_ring("ring_momentum")
	main.hand.momentum_time = 2.0
	_check(main._ring_damage_mult() >= 2.7 and main.hand.momentum_time == 0.0, "Momentum should double one hit then spend itself")
	main.hand.rings.clear()
	main.hand.ring_cds.clear()


func _check_utilities() -> void:
	# reward coins + purse 3 + ledger interest 2 (10 coins / 5)
	var total: int = main.coin_total()
	var reward: int = main.enemy.data.reward
	_check(total >= coins_before_kill + reward + 3 + 2, "purse and ledger should pay out after the fight (have %d)" % total)


func _test_shop_layout() -> void:
	_check(main.shelves.size() == 7, "the shop should have seven shelves (got %d)" % main.shelves.size())
	var kinds: Array = main.shelves.map(func(sh: Dictionary) -> String: return sh.kind)
	_check(kinds == ["gear", "gear", "gear", "gear", "stat", "ring", "ring"], "shelves should be four gear, a stat shelf and two ring shelves (%s)" % [kinds])
	var first: Item = main.shelves[0].item
	_check(first.def.kind in ["consumable", "potion"], "the first stocking should put a consumable on the first shelf (got %s)" % first.def.kind)
	var potions := 0
	for sh in main.shelves:
		if sh.item.def.kind == "potion":
			potions += 1
	_check(potions <= 1, "a shop should never hold more than one potion (got %d)" % potions)
	_check(not ItemDefs.UPGRADES[main.shelves[4].item.def.upgrade].get("ring", false), "the stat shelf should hold a hand upgrade or draught")
	for i in [5, 6]:
		_check(ItemDefs.UPGRADES[main.shelves[i].item.def.upgrade].get("ring", false), "ring shelves should hold rings")
	_check(main.shelves[5].item.def.upgrade != main.shelves[6].item.def.upgrade, "the two ring shelves should hold different rings")
	# the shop stands apart from the hoard: its shelves and stock are on their own layer, which
	# nothing you own collides with, but the hand can still reach (to inspect and to buy)
	var own: Item = main._spawn(ItemDefs.make("rock", "stone"), Vector2(-400, 0))
	for sh in main.shelves:
		_check(sh.body.collision_layer == Item.SHOP_LAYER and sh.item.collision_layer == Item.SHOP_LAYER, "shop shelves and stock should sit on the shop layer")
	_check(own.collision_mask & Item.SHOP_LAYER == 0, "the hoard shouldn't collide with the shop's shelves or stock")
	_check(main.hand.item_under(first.to_global(first.cell_pos(first.cells.keys()[0]))) == first, "the hand should still reach shop stock")
	_check(main.shelves[0].rect.position.y == main.SHELF_Y, "the shelves should hang at SHELF_Y")
	own.queue_free()
	# potions are rare in the gear pool
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := 0
	for i in 300:
		if ItemDefs.roll_offer(6, rng).kind == "potion":
			p += 1
	_check(p < 60, "potions should be a small share of late stock (%d of 300)" % p)


func _test_reroll() -> void:
	for n in main.get_tree().get_nodes_in_group("coins"):
		n.queue_free()
	await process_frame
	main._spawn_coins(10, Vector2(640, 600), 0.0)
	await process_frame
	var first: Item = main.shelves[0].item
	var cost: int = main.reroll_cost()
	main._on_punched(main.DICE.pos)
	await process_frame
	_check(not is_instance_valid(first) or first.is_queued_for_deletion(), "punching the dice should replace the stock")
	_check(main.coin_total() == 10 - cost, "a reroll should cost %d coins" % cost)
	_check(main.reroll_cost() > cost, "each reroll should cost more than the last")
	var keep: int = main.rerolls
	var costs := []
	for n in 6:
		main.rerolls = n
		costs.append(main.reroll_cost())
	main.rerolls = keep
	_check(costs == [3, 5, 7, 14, 28, 56], "rerolls should cost 3, 5, 7, then double each time (%s)" % [costs])
	main.free_rerolls = 1
	_check(main.reroll_cost() == 0, "a horseshoe should make a reroll free")
	main.free_rerolls = 0


func _test_potions() -> void:
	# Steelwater over a copper sword lying flat: most of it should come out steel
	var sword: Item = main._spawn(ItemDefs.make("longsword", "copper"), Vector2(640, 520))
	sword.rotation = PI / 2
	sword.freeze = true
	var shield: Item = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(1000, 520))
	shield.freeze = true
	var iron: Item = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(300, 520))
	iron.freeze = true
	await physics_frame
	await physics_frame
	main.on_potion_shatter_at(sword.global_position + Vector2(0, -40), "to_steel", Color(0.8, 0.8, 0.9))
	main.on_potion_shatter_at(shield.global_position + Vector2(0, -60), "poison", Color(0.4, 0.9, 0.3))
	for k in 90:
		await physics_frame
	var steel := 0
	for c in sword.cells:
		if sword.cells[c].mat == "steel":
			steel += 1
	var blade := 0
	for c in sword.cells:
		if not sword.cells[c].get("handle", false):
			blade += 1
	print("  Steelwater over a copper longsword: %d of %d blade cells turned" % [steel, blade])
	_check(steel >= blade * 0.6, "one Steelwater should turn most of a sword to steel (%d of %d)" % [steel, blade])
	_check(sword.def.material == "steel" and sword.def.name.begins_with("Steel"), "a sword that's mostly steel should become a steel sword (%s)" % sword.def.name)
	_check(shield.has_mod("poisoned"), "a shield soaked in Venom should become poisoned")
	# gilded scraps become coins
	var scrap: Item = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(500, 300))
	scrap.def.kind = "debris"
	for c in scrap.cells:
		scrap.cells[c].mat = "gold"
	var coins_before: int = main.coin_total()
	main._gild(scrap)
	await process_frame
	_check(main.coin_total() > coins_before and not is_instance_valid(scrap), "a gold scrap should turn into coins")
	# tempering: red-hot iron hit with frost
	iron.heat = 1.0
	iron.cold = 0.5
	await physics_frame
	await physics_frame
	_check(iron.has_mod("tempered"), "quenching red-hot iron should temper it")
	# a potion smashed in the hand breaks and spills
	var flask: Item = main._spawn(ItemDefs.make("potion_mending", "glass"), Vector2(800, 300))
	await physics_frame
	main._on_item_activated(flask)
	await process_frame
	_check(not is_instance_valid(flask), "smashing a potion should break it")
	for it in [sword, shield, iron]:
		it.queue_free()
