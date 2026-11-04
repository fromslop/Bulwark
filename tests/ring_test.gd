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
			print("ring test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false
