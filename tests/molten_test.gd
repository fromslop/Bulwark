extends SceneTree
## The Molten Core: a hoard too heavy for the shop floor cracks it, then breaks it, and the
## fall lands you in the Molten Core against the Smelter. Not before the limit; never into a
## boss's fight; and each fall shores the floor up, well past what you fell with. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/molten_test.gd

var main: Node
var f := 0
var fails: Array = []
var _lift := {}
var _fell_with := 0.0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _pile(mass: float) -> void:
	while main.pile_mass() < mass:
		main._spawn(ItemDefs.make("tower_shield", "iron"), Vector2(randf_range(100, 1180), 400))


func _process(_d: float) -> bool:
	f += 1
	match f:
		10:
			main.enemy.active = false
			main.round_num = 1
			main._open_shop()
			_pile(main.MOLTEN_MASS * 0.85)
		50:
			_check(main.state == main.State.SHOP and not main._falling, "below the limit the floor should only crack")
			_check(main.overlay.floor_crack > 0.0, "past %d%% of the limit the floor should crack (%.2f)" % [int(main.CRACK_AT * 100), main.overlay.floor_crack])
			main._spawn(ItemDefs.make("buckler", "wood"), Vector2(400, 600))
			_pile(main.MOLTEN_MASS * 1.05)
		90:
			_check(main._falling, "at the limit the floor should give way (mass %.0f)" % main.pile_mass())
			_fell_with = main.pile_mass()
			_check(main._molten_limit >= _fell_with + main.MOLTEN_STEP, "a fall should raise the limit well past the hoard (%.0f vs %.0f)" % [main._molten_limit, _fell_with])
		150:
			_lift = {}
			for n in main.items_root.get_children():
				if n is Item and n.owned and n.def.get("id", "") in ["buckler", "tower_shield"]:
					_lift[n.def.id] = n.global_position.y
		200:
			_check(main.camera.position.y < -5.0, "the camera should be falling through the earth (%.1f)" % main.camera.position.y)
			# the air's lift per mass: a light buckler is pushed up harder than a heavy tower shield
			var lift := {}
			for n in main.items_root.get_children():
				if n is Item and n.owned and n.def.get("id", "") in ["buckler", "tower_shield"]:
					lift[n.def.id] = n.cells.size() / n.mass
			_check(lift.get("buckler", 0.0) > lift.get("tower_shield", 0.0) * 1.5, "a light buckler should rise faster than a heavy tower shield as you fall (%s)" % [lift])
			_check(_lift.get("buckler", 0.0) > 0.0, "the buckler should be in the fall")
		400:
			_check(not main._falling and main.state == main.State.COMBAT, "the fall should end in a fight")
			_check(main.setting() == "Molten Core", "you should land in the Molten Core (got %s)" % main.setting())
			_check(main.enemy and main.enemy.data.name == "The Smelter", "the Smelter should be waiting")
			_check(absf(main.camera.position.y - 1.45) < 0.01, "the camera should be back where it was")
			_check(main.save.knows("places", "Molten Core"), "the Molten Core should be on the map")
			# beat it: a relic for the shelf at home
			main.enemy.take_hit(1e8, "torso", false)
		420:
			_check(main.save.found.guardians.has("The Smelter"), "beating the Smelter should put a relic on the shelf at home")
			# never into a boss's fight: the shop before the boss only creaks
			main._open_shop()  # (the shop after the Smelter: the lift, and the prize weighed in)
			main.round_num = EnemyDefs.BOSS_STAGE - 1
			main.secret_stage = ""
			main._gong_struck = false
			var limit: float = main._molten_limit
			main._molten_limit = main.MOLTEN_MASS  # (so only the boss rule can stop it)
			main._weigh_t = 0.0
			main._weigh_floor(0.1)
			_check(not main._falling, "the floor shouldn't give way into a boss's fight")
			main._molten_limit = limit
			main.round_num = 1
			main._weigh_t = 0.0
			main._weigh_floor(0.1)
			_check(not main._falling, "after a fall the same hoard shouldn't break the floor again")
			_check(main.overlay.floor_crack == 0.0, "nor even crack it (%.2f)" % main.overlay.floor_crack)
			# and a second fall shores it up by twice as much
			main._falls = 1
			_pile(limit * 1.02)
			main._weigh_t = 0.0
			main._weigh_floor(0.1)
			_check(main._falling and main._falls == 2, "a big enough hoard should break it again")
			_check(main._molten_limit >= main.pile_mass() + main.MOLTEN_STEP * 2.0, "and the second fall should raise it twice as far")
			print("molten test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false
