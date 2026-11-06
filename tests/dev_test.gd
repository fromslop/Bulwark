extends SceneTree
## The dev menu (F3, debug builds): straight into any fight (place, stage, prestige, one foe
## or two) from home or the shop, and the creative page spawns any item in any material with
## any modifiers. Headless, or windowed to save res://shots/dev_fight.png and dev_creative.png.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/dev_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_dev_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(SaveData.PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await _frames(3)
		root.get_texture().get_image().save_png("res://shots/dev_%s.png" % name)


func _run() -> void:
	await _frames(3)
	var dev: DevMenu = main.dev_menu
	_check(dev != null, "a debug build should have the dev menu")
	if dev == null:
		_finish()
		return
	# the menu opens and pauses the game, and shuts again
	dev.toggle()
	_check(dev.is_open() and paused, "F3 should open the dev menu and pause the game")
	await _shot("fight")
	dev.toggle()
	_check(not dev.is_open() and not paused, "closing it should let the game go on")

	# from home, straight into a fight of your choosing
	_check(main.state == main.State.HOME, "the test starts at home")
	main.dev_fight("Forge", 3, 1, ["Knight", "Footman"])
	await _frames(3)
	var names: Array = main.living().map(func(e: Enemy) -> String: return str(e.data.name))
	_check(main.state == main.State.COMBAT and main.setting() == "Forge", "the fight should be in the Forge (%s)" % main.setting())
	_check(names.size() == 2 and names.has("Knight") and names.has("Footman"), "against the Knight and a Footman (%s)" % [names])
	_check(main.round_num % EnemyDefs.STAGES == 2 and main.prestige == 1, "at stage 3, prestige 1 (round %d, prestige %d)" % [main.round_num, main.prestige])
	_check(main.coin_total() > 0, "a run started from home should come with its starting coin")
	# again, mid-run: the vault and its Warden
	main.dev_fight("Hidden Vault", 2, 0, ["Vault Warden"])
	await _frames(3)
	var hoard: Array = main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool: return n is Item and n.has_meta("fixture"))
	_check(main.setting() == "Hidden Vault" and main.living().size() == 1 and main.enemy.data.name == "Vault Warden", "the vault and its Warden (%s, %s)" % [main.setting(), main.enemy.data.name])
	_check(hoard.size() >= 12, "with its hoard (%d)" % hoard.size())
	# a boss stage
	main.dev_fight("Crypt Chapel", 5, 0, ["Sexton"])
	await _frames(3)
	_check(main.is_boss_round() and main.enemy.data.name == "The Sexton", "stage 5 is the boss's: the Sexton (%s)" % main.enemy.data.name)

	# creative: any item, any material, any modifiers
	var it: Item = main.dev_spawn(ItemDefs.make("longsword", "prestigium", ["electrified", "huge", "headhunter"]), ["electrified", "huge", "headhunter"])
	_check(it.def.material == "prestigium" and it.has_mod("electrified") and it.has_mod("huge") and it.has_mod("headhunter"), "a spawned piece should be what was asked for (%s %s)" % [it.def.material, it.def.modifiers])
	_check(float(it.def.size) > 1.9, "a huge one should be twice the size (%.2f)" % float(it.def.size))
	var legend: Item = main.dev_spawn(ItemDefs.make("stormbrand", "steel", ["poisoned"]), ["poisoned"])
	_check(legend.has_mod("electrified") and legend.has_mod("poisoned"), "a legendary should keep its own modifiers and take the extra ones (%s)" % [legend.def.modifiers])
	# ...and through the menu itself
	dev.toggle()
	dev._search.text = "mace"
	dev._refresh_items()
	_check(dev._items.item_count >= 1, "searching should find the mace")
	dev._items.select(0)
	dev._on_item_picked(0)
	(dev._mods["frosty"] as CheckBox).button_pressed = true
	dev._count.value = 3
	var before: int = main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool: return n is Item and n.def.get("id", "") == "mace").size()
	dev._spawn()
	await _frames(2)
	var maces: Array = main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool: return n is Item and n.def.get("id", "") == "mace")
	_check(maces.size() == before + 3 and maces.all(func(m: Item) -> bool: return m.has_mod("frosty")), "the menu should spawn three frosty maces (%d)" % (maces.size() - before))
	var tabs: TabContainer = dev._root.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 1
	await _shot("creative")
	dev.toggle()
	_finish()


func _finish() -> void:
	print("dev test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
