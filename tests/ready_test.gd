extends SceneTree
## A weapon held by its handle stands up in a ready position; held by the blade, or anything
## else held anywhere, it dangles as before. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/ready_test.gd

var main: Node
var f := 0
var fails: Array = []
var sword: Item


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _handle(it: Item) -> Vector2:
	for c in it.cells:
		if it.cells[c].get("handle", false):
			return it.to_global(it.cell_pos(c))
	return Vector2.INF


func _blade(it: Item) -> Vector2:
	var far := Vector2.INF
	var h := _handle(it)
	for c in it.cells:
		var p := it.to_global(it.cell_pos(c))
		if not far.is_finite() or p.distance_to(h) > far.distance_to(h):
			far = p
	return far


func _grab(it: Item, at: Vector2) -> void:
	main.hand.release()
	main.hand.pinned = at
	main.hand.position = at
	main.hand.grab(it, at)


func _process(_d: float) -> bool:
	f += 1
	match f:
		10:
			sword = main._spawn(ItemDefs.make("longsword", "iron"), Vector2(640, 300))
			sword.rotation = PI / 2.0  # lying on its side
			_grab(sword, _handle(sword))
			_check(is_finite(main.hand.ready_offset()), "a sword held by the handle should have a ready angle")
		130:
			var off: float = main.hand.ready_offset()
			_check(absf(off) < 0.2, "held by the handle, a sword should stand up (%.2f rad off)" % off)
			var tip_up: bool = _blade(sword).y < _handle(sword).y - 30.0
			_check(tip_up, "the blade should point up from the grip")
			# held by the blade, it hangs
			_grab(sword, _blade(sword))
			_check(not is_finite(main.hand.ready_offset()), "held by the blade, a sword shouldn't stand up")
		250:
			_check(_blade(sword).y < _handle(sword).y, "held by the blade, the sword should hang handle-down")
			# a shield doesn't stand up
			var shield: Item = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(400, 300))
			_grab(shield, shield.global_position + Vector2(10, 0))
			_check(not is_finite(main.hand.ready_offset()), "a shield shouldn't get a ready angle")
			# Q/E: a turned sword keeps its new angle
			_grab(sword, _handle(sword))
			main.hand.ready_tilt = 0.6
		370:
			var off: float = main.hand.ready_offset()
			_check(absf(off) < 0.2, "a sword should settle at the angle Q/E left it (%.2f rad off)" % off)
			print("ready test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false
