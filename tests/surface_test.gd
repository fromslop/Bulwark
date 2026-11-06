extends SceneTree
## The home's surfaces: something let go of above the shelves, the trophy board, the mantel,
## the table or the hearthstone lands and rests on it; something held passes through them,
## so dragging never snags; the hand lifts anything at home; and all of that ends when a run starts. With a window it also saves
## res://shots/surfaces.png. Run headless:
## Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/surface_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_surface_test_save.txt"
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


func _bottom(it: Item) -> float:
	var b := -INF
	for c in it.cells:
		b = maxf(b, it.to_global(it.cell_pos(c)).y + Item.CELL * 0.5)
	return b


func _run() -> void:
	await _frames(3)
	main.hand.pinned = Vector2(640, 40)  # (out of the way)
	var placed := {}
	for name in main.HOME_LEDGES:
		var sp: Array = main.HOME_LEDGES[name]
		var x: float = (float(sp[0]) + float(sp[1])) * 0.5
		if name == "shelves":
			x = 1070.0 + 30.0  # (between two of the shelf's hang spots: it rests, it doesn't hang)
		var rock: Item = main._spawn(ItemDefs.make("lantern", "iron"), Vector2(x, float(sp[2]) - 60.0))  # (not junk: the hearth would melt a rock)
		placed[name] = rock
	await _frames(150)
	for name in placed:
		var rock: Item = placed[name]
		var top: float = main.HOME_LEDGES[name][2]
		_check(is_instance_valid(rock) and absf(_bottom(rock) - top) < 6.0, "a rock let go of over the %s should rest on it (bottom %.0f, surface %.0f)" % [name, _bottom(rock) if is_instance_valid(rock) else -1.0, top])
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("res://shots/surfaces.png")

	# held, it goes straight through: drag the table's rock down to the floor
	var rock: Item = placed["table"]
	main.hand.pinned = rock.global_position
	await _frames(2)
	main.hand.grab(rock, rock.global_position)
	main.hand.pinned = Vector2(rock.global_position.x, 690)
	await _frames(90)
	_check(rock.global_position.y > float(main.HOME_LEDGES["table"][2]) + 20.0, "something held should pass down through the table (at y %.0f)" % rock.global_position.y)
	main.hand.release()
	await _frames(60)
	_check(rock.global_position.y > float(main.HOME_LEDGES["table"][2]) + 20.0, "and, let go of under it, stay down there (at y %.0f)" % rock.global_position.y)

	# at home the hand lifts anything, however heavy
	var heavy: Item = main._spawn(ItemDefs.make("greatsword", "steel", ["huge"]), Vector2(330, 560))  # (clear of the table and the lanterns resting about)
	await _frames(30)
	var lift_limit: float = Hand.MAX_FORCE / float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_check(heavy.mass > lift_limit * 2.0, "the test sword should be far past what a hand can lift (%.0f vs %.0f)" % [heavy.mass, lift_limit])
	main.hand.pinned = heavy.to_global(heavy.center_of_mass)
	await _frames(2)
	main.hand.grab(heavy, heavy.to_global(heavy.center_of_mass))
	main.hand.pinned = Vector2(330, 320)
	await _frames(120)
	_check(heavy.to_global(heavy.center_of_mass).y < 370.0, "at home the hand should lift even a sword of mass %.0f (held at y %.0f)" % [heavy.mass, heavy.to_global(heavy.center_of_mass).y])
	main.hand.release()

	main._start_run()
	await _frames(3)
	_check(main._ledges == null, "the home's surfaces should go once a run starts")
	_check(not main.hand.unlimited, "out on a run, weight should count again")

	print("surface test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
