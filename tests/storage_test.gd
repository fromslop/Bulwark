extends SceneTree
## The storage cupboard at home: let go of a thing over it and it's put away (out of the
## world, into the save); Space on it opens it; TAKE OUT gives it back as it was; coins,
## cups and the furniture don't go in; what's stored stays home through a run. With a
## window it also saves res://shots/storage_*.png. Run headless:
## Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/storage_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_storage_test_save.txt"
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
		await physics_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://shots/storage_%s.png" % name)


func _cupboard() -> Vector2:
	return main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "storage")[0].pos


## Carry a thing to the cupboard and let go of it there.
func _drop_in(it: Item) -> void:
	main.hand.pinned = it.global_position
	await _frames(2)
	main.hand.grab(it, it.global_position)
	main.hand.pinned = _cupboard()
	main.hand.position = _cupboard()
	await _frames(2)
	main.hand.release()
	await _frames(2)


func _run() -> void:
	await _frames(3)
	_check(main.props.props.any(func(pr: Dictionary) -> bool: return pr.kind == "storage"), "home should have a storage cupboard")
	var sword: Item = main._spawn(ItemDefs.make("longsword", "steel", ["electrified"]), Vector2(640, 600))
	sword.def.custom_name = "Grudge"
	var shield: Item = main._spawn(ItemDefs.make("kite_shield", "iron", ["large"]), Vector2(760, 600))
	var potion: Item = main._spawn(ItemDefs.make("potion_growth", "glass"), Vector2(860, 600))
	await _frames(20)
	await _drop_in(sword)
	_check(not is_instance_valid(sword) or sword.is_queued_for_deletion(), "a sword let go of over the cupboard should be put away")
	_check(main.save.storage.size() == 1 and main.save.storage[0].get("custom_name", "") == "Grudge", "the cupboard should hold it, name and all (%s)" % [main.save.storage])
	await _drop_in(shield)
	await _drop_in(potion)
	_check(main.save.storage.size() == 3, "three things should be stored (%d)" % main.save.storage.size())
	main._spawn_coins(5, Vector2(500, 600), 0.0)
	await _frames(10)
	var coin: Item = main.get_tree().get_nodes_in_group("coins")[0]
	await _drop_in(coin)
	_check(main.save.storage.size() == 3 and is_instance_valid(coin) and not coin.is_queued_for_deletion(), "coins shouldn't go in the cupboard")
	_check(SaveData.load_file().storage.size() == 3, "the save should keep what's stored")

	# Space on it (hand empty) opens it
	main.hand.pinned = _cupboard()
	await _frames(2)
	main._on_punched(_cupboard())
	_check(main.storage.is_open(), "Space on the cupboard should open it")
	main.storage.picked = 0
	await _shot("open")
	var back: Item = main.storage.take_out(0)
	await _frames(3)
	_check(back != null and back.display_name() == "Grudge" and back.has_mod("electrified") and back.owned, "taking it out should give the same sword back")
	_check(main.save.storage.size() == 2, "and it should leave the cupboard (%d)" % main.save.storage.size())
	main.storage.toggle()
	_check(not main.storage.is_open(), "it should close")

	# a run leaves what's stored at home
	main._start_run()
	await _frames(3)
	var found: Array = main.items_root.get_children().filter(func(n: Node) -> bool: return n is Item and n.def.get("id", "") == "kite_shield" and n.def.get("material", "") == "iron" and n.has_mod("large"))  # (the kit can hold a plain wooden one)
	_check(found.is_empty(), "stored things stay home on a run")
	_check(main.save.storage.size() == 2, "and stay stored (%d)" % main.save.storage.size())
	main._go_home()
	await _frames(3)
	_check(main.save.storage.size() == 2, "and are still there back home (%d)" % main.save.storage.size())
	main.hand.pinned = _cupboard() + Vector2(0, -60)
	main.hand.force_inspect = true
	await _shot("home")
	main.hand.force_inspect = false

	print("storage test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
