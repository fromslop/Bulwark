extends SceneTree
## The Hidden Vault's hoard: heaped up for the fight, still there when the Warden is down and
## the shop appears (hung again under the shelves, clear of the stock), and gone when the next
## fight starts. Headless, or windowed to save res://shots/vault_shop.png.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/vault_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_vault_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(SaveData.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hoard() -> Array:
	return main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool:
		return n is Item and n.has_meta("fixture") and not n.has_meta("taken") and not n.is_queued_for_deletion())


func _run() -> void:
	await _frames(5)
	main.round_num = 1
	main.secret_next = true
	main._start_fight()
	await _frames(3)
	_check(main.setting() == "Hidden Vault", "the fight should be in the vault (%s)" % main.setting())
	var heaped := _hoard().size()
	_check(heaped >= 12, "the vault should be heaped with things to take (%d)" % heaped)
	var taken: Item = _hoard()[0]
	main.hand.grab(taken, taken.global_position)  # one taken: it's yours, whatever happens
	main.hand.release()
	for e in main.living():
		e.take_hit(1e9, "torso", false)
	for i in 400:
		await physics_frame
		if main.state == main.State.SHOP:
			break
	_check(main.state == main.State.SHOP, "the shop should open after the Warden")
	await _frames(2)
	var left := _hoard()
	_check(left.size() == heaped - 1, "everything not taken should still be there in the shop (%d of %d)" % [left.size(), heaped - 1])
	_check(left.all(func(it: Item) -> bool: return it.global_position.y >= 300.0 and it.freeze), "and hung under the shelves, clear of the stock")
	_check(is_instance_valid(taken) and not taken.is_queued_for_deletion(), "what you took should be yours")
	if DisplayServer.get_name() != "headless":
		main.hand.pinned = Vector2(1250, 700)
		await _frames(20)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		root.get_texture().get_image().save_png("res://shots/vault_shop.png")
	main.round_num += 1
	main._start_fight()
	await _frames(3)
	var stayed: Array = left.filter(func(it: Item) -> bool: return is_instance_valid(it) and not it.is_queued_for_deletion())
	_check(stayed.is_empty(), "what's left of the vault's hoard should be gone when the next fight starts (%d)" % stayed.size())

	print("vault test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
