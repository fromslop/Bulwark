extends SceneTree
## Home and the meta-run: the game opens at home with the codex, mirror and racks; gear
## hangs itself on racks; names and boss notches stick; the save round-trips; the gong
## starts a run carrying what you hold; a boss opens the door home; hoard utilities count
## the pile; the new potions grow, shrink, weigh and warp.
## Run: Godot_console.exe --headless --fixed-fps 60 --path . -s res://tests/home_test.gd

var main: Node
var frame := 0
var fails := PackedStringArray()
var sword: Item
var carried: Item


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(SaveData.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


func _find(id: String) -> Item:
	for it in main.items_root.get_children():
		if it is Item and it.def.get("id", "") == id and not it.is_queued_for_deletion():
			return it
	return null


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		5:
			_test_home_opens()
		10:
			_test_racks_and_names()
		20:
			_test_save_roundtrip()
		25:
			_test_gong_carries()
		60:
			_test_hoard()
			_test_potions()
		120:
			_test_boss_door()
		270:
			_test_return_home()
		280:
			print("home test: %d failures" % fails.size())
			for f in fails:
				print("  FAIL ", f)
			quit(1 if fails.size() > 0 else 0)
	return false


func _test_home_opens() -> void:
	_check(main.state == main.State.HOME, "the game should open at home")
	_check(main.setting() == "Homestead", "home is the Homestead (got %s)" % main.setting())
	_check(main.enemies.is_empty(), "nothing fights you at home")
	_check(_find("codex") != null and _find("mirror") != null, "the codex and the mirror should be on the floor")
	# a fresh load (game start, or the reload after a death) brings up home's night ambience
	_check(Music._inst != null and float(Music._inst._target.get("amb_night", 0.0)) == 1.0, "a fresh load at home should bring up the night ambience")
	_check(main.racks.size() == 10, "four rack pegs and six shelf spots (got %d)" % main.racks.size())
	_check(not main.overlay.gong.is_empty(), "the gong should hang at home")
	# the codex opens and closes
	main.codex.toggle()
	_check(main.codex.is_open(), "Space on the codex should open the index")
	var entries: Array = main.codex.entries()
	_check(entries.size() > 40, "the gear page should list the gear (%d)" % entries.size())
	main.codex.toggle()
	_check(not main.codex.is_open(), "the codex should close again")


func _test_racks_and_names() -> void:
	sword = main._spawn(ItemDefs.make("longsword", "steel", ["electrified"]), main.RACK_SLOTS[1] + Vector2(10, 10))
	main.hand.grab(sword, sword.global_position)
	main.hand.release()
	_check(main.racks[1].item == sword and sword.freeze, "a weapon let go near a rack peg should hang itself there")
	var crate: Item = main._spawn(ItemDefs.make("crate", "wood"), main.RACK_SLOTS[2] + Vector2(5, 10))
	main.hand.grab(crate, crate.global_position)
	main.hand.release()
	_check(main.racks[2].item != crate, "only weapons go on the weapon rack")
	crate.teleport(main.SHELF_SLOTS[0] + Vector2(5, 5))
	main.hand.grab(crate, crate.global_position)
	main.hand.release()
	_check(main.racks[4].item == crate, "anything can go on a shelf")
	main.codex._rename_target = sword
	main.codex.rename(sword)
	main.codex._on_renamed("Stormcaller")
	_check(sword.display_name() == "Stormcaller" and sword.def.name.begins_with("Steel"), "a kept piece can be named, and remembers what it is")
	sword.def.boss_kills = 3


func _test_save_roundtrip() -> void:
	main._save_home()
	var loaded := SaveData.load_file()
	_check(loaded.home.size() == 2, "the save should hold both kept items (got %d)" % loaded.home.size())
	var e: Dictionary = {}
	for x in loaded.home:
		if x.get("id", "") == "longsword":
			e = x
	_check(not e.is_empty() and e.get("custom_name", "") == "Stormcaller" and int(e.get("boss_kills", 0)) == 3 and e.get("slot", -1) == 1,
		"the save should remember the sword's name, its kills and its peg (%s)" % [e])
	var d := SaveData.unpack(e)
	_check(d.material == "steel" and d.modifiers.has("electrified") and d.custom_name == "Stormcaller", "unpacking should give the same sword back")
	# a fresh home from that save hangs it back on its peg
	main.save = loaded
	main._go_home()
	await process_frame
	await process_frame
	var back := _find("longsword")
	_check(back != null and main.racks[1].item == back and back.display_name() == "Stormcaller", "coming home should hang the sword back on its peg")
	sword = back


func _test_gong_carries() -> void:
	var pick := _find("longsword")
	main.hand.grab(pick, pick.global_position)
	main._start_run()
	_check(main.state == main.State.COMBAT and main.round_num == 0 and main.prestige == 0, "the gong should start a run at stage one")
	_check(is_instance_valid(pick) and not pick.is_queued_for_deletion() and pick.has_meta("kept"), "what you hold at the gong comes with you")
	_check(_find("codex") == null, "the furniture stays home")
	var loaded := SaveData.load_file()
	_check(loaded.home.size() == 1, "what you took along should leave the home save (got %d)" % loaded.home.size())
	carried = pick
	main.hand.release()
	main.enemy.active = false


func _test_hoard() -> void:
	for n in main.items_root.get_children():
		if n is Item and n != carried:
			n.queue_free()
	main._spawn(ItemDefs.make("weapon_rack", "wood"), Vector2(200, 650))
	for i in 3:
		main._spawn(ItemDefs.make("club", "wood"), Vector2(400 + i * 60, 650))
	main._spawn(ItemDefs.make("trophy_pegs", "iron"), Vector2(700, 650))
	main._spawn(ItemDefs.make("pauldron", "iron"), Vector2(800, 650))
	main._spawn(ItemDefs.make("pauldron", "iron"), Vector2(860, 650))
	main._spawn(ItemDefs.make("war_banner", "cloth"), Vector2(950, 650))
	main._spawn(ItemDefs.make("buckler", "wood"), Vector2(1050, 650))
	main._spawn(ItemDefs.make("packrat_idol", "gold"), Vector2(1150, 650))
	main._refresh_hoard()
	_check(main.hand.hoard_hp == 16.0, "a weapon rack should add 4 HP per weapon (%.0f)" % main.hand.hoard_hp)  # 3 clubs + the carried sword
	_check(is_equal_approx(main.hoard_wear, 0.84), "trophy pegs should cut gear wear 8%% per pauldron (%.2f)" % main.hoard_wear)
	_check(is_equal_approx(main.hoard_stagger, 1.15), "a war banner should add 15%% stagger per shield (%.2f)" % main.hoard_stagger)
	_check(main.hoard_damage > 1.15 and main.hoard_damage <= 1.2, "a packrat idol should pay 2%% damage per piece of gear, up to 20%% (%.2f)" % main.hoard_damage)
	var before: float = main.hoard_damage
	for i in 10:
		var chunk: Dictionary = ItemDefs.make("club", "wood")
		chunk.piece = true  # broken-off chunks keep their parent's kind but aren't gear any more
		main._spawn(chunk, Vector2(300 + i * 50, 600))
	main._refresh_hoard()
	_check(is_equal_approx(main.hoard_damage, before), "broken-off chunks shouldn't count for the packrat idol (%.2f)" % main.hoard_damage)
	_check(main.hand.max_hp == 116.0, "max HP should include the hoard bonus (%.0f)" % main.hand.max_hp)


func _test_potions() -> void:
	var shield: Item = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(640, 400))
	shield.freeze = true
	var cells0 := shield.cells.size()
	shield.rescale(1.5)
	_check(shield.cells.size() > cells0 * 2 and shield.def.size == 1.5, "Giant's Brew should grow an item (%d -> %d cells)" % [cells0, shield.cells.size()])
	shield.rescale(0.65 / 1.5)
	_check(shield.cells.size() < cells0, "Pixie Dust should shrink it back")
	var m0 := shield.mass
	shield.add_mod("heavy")
	_check(shield.mass > m0 * 1.5, "a Leaden Draught should weigh it down")
	shield.add_mod("weightless")
	_check(shield.mass < m0 * 0.2 and shield.base_gravity == 0.0, "Featherdraught should make it weightless")
	var home0: int = main.save.home.size()
	var keep: Item = main._spawn(ItemDefs.make("mace", "iron"), Vector2(640, 300))
	main._send_home(keep)
	_check(main.save.home.size() == home0 + 1 and main.save.home.back().id == "mace", "Homeward Brew should warp the item to the home save")
	_check(keep.is_queued_for_deletion(), "and take it out of the fight")
	# the brew itself: it passes through gear and sends home whatever is nearest where it breaks
	var near: Item = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(400, 200))
	var far: Item = main._spawn(ItemDefs.make("club", "wood"), Vector2(900, 200))
	near.freeze = true
	far.freeze = true
	var brew: Item = main._spawn(ItemDefs.make("potion_homeward", "glass"), Vector2(405, 205))
	_check(brew.collision_layer == 0 and brew.collision_mask == 2, "a Homeward Brew should pass through gear")
	brew.shatter()
	_check(near.is_queued_for_deletion() and not far.is_queued_for_deletion(), "a broken Homeward Brew should send home the nearest thing")
	far.queue_free()
	shield.queue_free()


func _test_boss_door() -> void:
	# jump to the boss stage and win it
	main.round_num = EnemyDefs.BOSS_STAGE
	main.state = main.State.COMBAT
	main._start_fight()
	_check(main.enemy.data.get("boss", false) and main.is_boss_round(), "stage five should be a boss")
	main.enemy.active = false
	for it in main.items_root.get_children():
		if it is Item and it.def.kind == "weapon":
			it.set_meta("hit_boss", true)
	main.enemy.take_hit(1e7, "torso", false)
	_check(carried.def.get("boss_kills", 0) == 4, "a weapon that touched the boss gets a notch (%d)" % carried.def.get("boss_kills", 0))


func _test_return_home() -> void:
	_check(main.state == main.State.SHOP, "the shop should open after the boss")
	_check(not main.overlay.door.is_empty(), "after a boss the shop should have a door home")
	main._on_punched(main.DOOR.pos)
	_check(main.state == main.State.SHOP, "punching the door empty-handed does nothing")
	main.hand.grab(carried, carried.global_position)
	main._on_punched(main.DOOR.pos)
	_check(main.state == main.State.HOME, "through the door holding something: home")
	_check(is_instance_valid(carried) and not carried.is_queued_for_deletion(), "and the thing you carried is here")
	_check(main.save.prestige_best >= 1, "beating a boss and going home should count as a prestige")
	var loaded := SaveData.load_file()
	var names: Array = loaded.home.map(func(e: Dictionary) -> String: return str(e.get("custom_name", e.get("id", ""))))
	_check(names.has("Stormcaller"), "the carried sword should be in the home save (%s)" % [names])
	# prestige: continuing past the boss instead
	main._start_run()
	main.enemy.active = false
	main.round_num = EnemyDefs.BOSS_STAGE
	main.state = main.State.SHOP
	main._close_shop()
	_check(main.prestige == 1 and ItemDefs.run_prestige == 1 and main.round_num == 5, "ringing the gong after the boss should prestige the run")
	_check(main.enemy.data.prestige == 1, "the next enemy should be scaled for prestige 1")
