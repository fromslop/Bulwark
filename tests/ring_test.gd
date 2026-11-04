extends SceneTree
## The strange rings: each does what it says. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/ring_test.gd

var main: Node
var f := 0
var fails: Array = []
var floater: Item
var y0 := 0.0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _only(id: String) -> void:
	main.hand.rings.clear()
	main.hand.ring_cds.clear()
	main.hand.ring_slots = 5
	main.hand.wear_ring(id)
	main.hand.injury = 0.0


func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			main.enemy.active = false
			var e: Enemy = main.enemy
			# thorns: the hand's pain comes back double
			_only("ring_thorns")
			var hp0: float = e.hp
			main.hand.hurt(10.0)
			_check(e.hp <= hp0 - 19.0, "Ring of Thorns should hurt the enemy double what the hand took (%.1f)" % (hp0 - e.hp))
			# glass cannon: the hand takes double, hits do double
			_only("ring_glass")
			main.hand.hurt(10.0)
			_check(is_equal_approx(main.hand.injury, 20.0), "Glass Cannon should double the hand's damage (%.1f)" % main.hand.injury)
			_check(main._ring_damage_mult() >= 2.0, "Glass Cannon should double weapon damage")
			# phoenix: a killing blow is turned aside, once
			_only("ring_phoenix")
			main.hand.hurt(main.hand.max_hp * 2.0)
			_check(main.hand.injury < main.hand.max_hp and not main.hand.has_ring("ring_phoenix"), "the Phoenix Ring should save the hand once and burn away")
			# martyr: pain fills the stagger meter
			_only("ring_martyr")
			var s0: float = e.stagger_meter
			main.hand.hurt(5.0)
			_check(e.stagger_meter > s0 or e.state == "broken", "Ring of the Martyr should fill the enemy's stagger meter")
			# frenzy: a streak builds
			_only("ring_frenzy")
			var m1: float = main._ring_damage_mult()
			var m2: float = main._ring_damage_mult()
			var m3: float = main._ring_damage_mult()
			_check(m3 > m2 and m2 > m1, "Ring of Frenzy should build with each hit (%.2f %.2f %.2f)" % [m1, m2, m3])
			main.hand.hurt(1.0)
			_check(main.hand.frenzy == 0, "getting hurt should break the Frenzy streak")
			# gambler: either the next hit is x6 or the hand pays
			_only("ring_gambler")
			main._on_ring_used("ring_gambler", main.hand.position, 0)
			_check(main.hand.gamble_mult == 6.0 or main.hand.injury >= 12.0, "the Gambler's Ring should either load the next hit or cost the hand")
			# alchemy: copper goes to iron
			_only("ring_alchemy")
			var cu: Item = main._spawn(ItemDefs.make("buckler", "copper"), Vector2(300, 300))
			cu.freeze = true
			main.hand.pinned = cu.global_position
			main.hand.position = cu.global_position
			main._on_ring_used("ring_alchemy", cu.global_position, 0)
			_check(cu.def.material == "iron", "the Alchemist's Ring should turn copper to iron (%s)" % cu.def.material)
			main.hand.pinned = Vector2.INF
			# magpie: shop prices go up
			_only("ring_magpie")
			main._open_shop()
			var dear := 0
			for sh in main.shelves:
				if sh.price >= ceili(sh.item.def.cost * 1.3) and sh.item.def.cost > 0:
					dear += 1
			_check(dear > 0, "the Magpie's shop should be dearer")
			# reversal: things fall up
			_only("ring_reversal")
			floater = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(900, 500))
			y0 = floater.global_position.y
			main._on_ring_used("ring_reversal", main.hand.position, 0)
		60:
			_check(floater.global_position.y < y0 - 40.0, "Ring of Reversal should make the pile fall up (%.0f -> %.0f)" % [y0, floater.global_position.y])
			# the fight bonus: fast and unhurt pays most; slow and battered pays nothing extra
			var best: Dictionary = main.fight_bonus(5.0, 30.0, 0.0, 100.0)
			var none: Dictionary = main.fight_bonus(60.0, 30.0, 60.0, 100.0)
			var mid: Dictionary = main.fight_bonus(30.0, 30.0, 20.0, 100.0)
			_check(is_equal_approx(best.speed, main.SPEED_BONUS) and is_equal_approx(best.health, main.HEALTH_BONUS), "a quick, unhurt win should earn the full bonus (%s)" % [best])
			_check(none.speed == 0.0 and none.health == 0.0, "a slow, battered win should earn no bonus (%s)" % [none])
			_check(mid.speed > 0.0 and mid.speed < main.SPEED_BONUS and mid.health > 0.0 and mid.health < main.HEALTH_BONUS, "in between should earn some of each (%s)" % [mid])
			var coins0: int = main.coin_total()
			main._fight_base = 20
			main._fight_start = main.clock - 5.0
			main._fight_par = 30.0
			main._fight_taken = 0.0
			main._pay_fight_bonus()
			var paid: int = main.coin_total() - coins0
			print("fight bonus for a 5 s, unhurt win on a 20-coin fight: +%d" % paid)
			_check(paid >= 20, "a fast flawless win should pay about double the reward on top (%d)" % paid)
			main._close_shop()
		75:
			_blood()
			main.hand.rings.clear()
			main.hand.injury = main.hand.max_hp * 0.8  # critical: the music should close in
		150:
			_check(main.state == main.State.COMBAT, "the blood tests should run in a fight")
			_check(Music.critical and Music.critical_amount() > 0.6, "a critical hand in a fight should band-pass the music (%.2f)" % Music.critical_amount())
			main.hand.injury = 0.0  # healed: it should open back up
		300:
			_check(not Music.critical and Music.critical_amount() < 0.05, "healing should lift the band-pass (%.2f)" % Music.critical_amount())
			print("ring test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false


## Healing, and pain that pays: the blood rings, modifiers and items.
func _blood() -> void:
	var e: Enemy = main.enemy
	e.active = false
	var hp: float = main.hand.max_hp
	var r := {"id": "torso", "center": Vector2(640, 300), "radius": 20.0}
	# Bloodletting: a cut for a big hit, never the last point
	_only("ring_bloodletting")
	main.hand.injury = hp - 5.0
	main._on_ring_used("ring_bloodletting", main.hand.position, 0)
	_check(is_equal_approx(main.hand.injury, hp - 1.0), "a self-inflicted cut should stop at the last point (%.1f)" % main.hand.injury)
	_check(main._ring_damage_mult() >= 3.0 and main.hand.blood_mult == 1.0, "Bloodletting should make the next hit x3, once")
	main.hand.ring_cds[0] = 0.0
	main._on_ring_used("ring_bloodletting", main.hand.position, 0)
	_check(main.hand.blood_mult == 1.0 and main.hand.ring_cds[0] == 0.0, "with nothing left to bleed, Bloodletting shouldn't fire")
	# Scars: pain this fight, from anything, pays
	_only("ring_scars")
	main.hand.pain = 0.0
	main.hand.hurt(50.0)
	_check(is_equal_approx(main._ring_damage_mult(), 1.75), "Ring of Scars should pay 1.5%% per point lost (%.2f)" % main._ring_damage_mult())
	# Second Wind: once a fight
	_only("ring_second_wind")
	main._second_wind_used = false
	main.hand.injury = 80.0
	main._tick_blood(0.016)
	_check(is_equal_approx(main.hand.injury, 45.0), "Second Wind should heal 35 below a quarter (%.1f)" % main.hand.injury)
	main.hand.injury = 80.0
	main._tick_blood(0.016)
	_check(is_equal_approx(main.hand.injury, 80.0), "Second Wind should only fire once a fight")
	# Resolve: blocks heal
	_only("ring_resolve")
	main.hand.injury = 20.0
	main._block_rings({"damage": 10.0}, true, true, 10.0, Vector2(640, 400), e)
	_check(is_equal_approx(main.hand.injury, 14.0), "a parry with the Ring of Resolve should heal 6 (%.1f)" % main.hand.injury)
	# Field Dressing: binds itself from the pile
	main.hand.rings.clear()
	var dressing: Item = main._spawn(ItemDefs.make("field_dressing", "cloth"), Vector2(1000, 600))
	main.hand.injury = 60.0
	main._tick_blood(0.016)
	_check(is_equal_approx(main.hand.injury, 60.0) and not dressing.is_queued_for_deletion(), "a Field Dressing should wait for the hand to get low")
	main.hand.injury = 75.0
	main._tick_blood(0.016)
	_check(is_equal_approx(main.hand.injury, 30.0) and dressing.is_queued_for_deletion(), "below 30%% a Field Dressing should bind itself (%.1f)" % main.hand.injury)
	# Blood Price and Bloodthirsty
	var sword: Item = main._spawn(ItemDefs.make("shortsword", "iron", ["bloodprice"]), Vector2(300, 500))
	main.hand.injury = 0.0
	var m: float = main._rare_mult(sword, e, r)
	_check(m >= 2.5 and is_equal_approx(main.hand.injury, main.BLOOD_PRICE), "Blood Price should cut the hand and pay x2.5 (x%.2f, %.1f)" % [m, main.hand.injury])
	var thirsty: Item = main._spawn(ItemDefs.make("shortsword", "iron", ["bloodthirsty"]), Vector2(400, 500))
	main.hand.injury = hp * 0.5
	_check(is_equal_approx(main._rare_mult(thirsty, e, r), 2.0), "Bloodthirsty should do x2 at half health")
	# the Mortar heals after a fight; the Hair Shirt chafes in one, and pays
	main._spawn(ItemDefs.make("mortar", "stone"), Vector2(500, 600))
	main.hand.injury = 30.0
	main._pay_utilities()
	_check(is_equal_approx(main.hand.injury, 15.0), "the Apothecary's Mortar should heal 15 after a fight (%.1f)" % main.hand.injury)
	main._spawn(ItemDefs.make("hair_shirt", "cloth"), Vector2(600, 600))
	main._refresh_hoard()
	_check(main.hoard_shirt, "a Hair Shirt in the pile should count")
	main._shirt_t = 0.0
	main.hand.injury = 0.0
	main._tick_blood(main.SHIRT_EVERY + 0.01)
	_check(is_equal_approx(main.hand.injury, 1.0), "the Hair Shirt should chafe a point every %ds (%.1f)" % [main.SHIRT_EVERY, main.hand.injury])
	# soothing: held, it heals
	var balm: Item = main._spawn(ItemDefs.make("buckler", "wood", ["soothing"]), main.hand.position)
	main.hand.held = balm
	main.hand.injury = 10.0
	main._tick_blood(1.0)
	_check(main.hand.injury < 10.0 - 1.5, "holding something soothing should heal the hand (%.1f)" % main.hand.injury)
	main.hand.held = null
	for it in [sword, thirsty, balm]:
		it.queue_free()
