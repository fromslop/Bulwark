extends SceneTree
## Fire is a hazard: light one crate in a heap of wooden things and it spreads
## through the heap and eats them all. An iron blade beside it comes through; a frosty buckler
## doesn't catch; and nothing burns at home. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/fire_test.gd

const WOOD := [["crate", "wood"], ["buckler", "wood"], ["club", "wood"], ["round_shield", "wood"], ["crate", "wood"], ["club", "wood"]]
var main: Node
var f := 0
var fails: Array = []
var row: Array = []
var wood0 := 0
var iron: Item
var frosty: Item


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


## Wood cells left in everything owned (what's burnt away is gone; what broke off still counts).
func _wood() -> int:
	var n := 0
	for it in main.items_root.get_children():
		if it is Item and not it.is_queued_for_deletion():
			for c in it.cells:
				if Materials.get_mat(it.cells[c].mat).get("burns", false):
					n += 1
	return n


func _process(_d: float) -> bool:
	f += 1
	match f:
		10:
			main.enemy.active = false
			main.round_num = 1
			main._open_shop()
			for n in main.items_root.get_children():
				if n is Item:
					n.queue_free()
		12:
			for i in WOOD.size():
				row.append(main._spawn(ItemDefs.make(WOOD[i][0], WOOD[i][1]), Vector2(300 + i * 70, 640 - i * 60)))  # (a heap, as a hoard lies)
			iron = main._spawn(ItemDefs.make("longsword", "iron"), Vector2(760, 600))
			frosty = main._spawn(ItemDefs.make("buckler", "wood"), Vector2(1220, 640))
			frosty.add_mod("frosty")
		60:
			wood0 = _wood()
			row[0].ignite()
			_check(row[0].is_burning(), "a lit crate should be burning")
		360:
			var lit := 0
			for it in row:
				if not is_instance_valid(it) or it.is_burning() or it.charred:
					lit += 1
			_check(lit >= 4, "in five seconds fire should have run down most of the row (%d of %d caught)" % [lit, row.size()])
		1500:
			var left := _wood()
			_check(left < wood0 * 0.15, "fire should eat the wood: %d of %d wood cells left" % [left, wood0])
			_check(is_instance_valid(iron) and iron.cells.size() > 10, "an iron blade should come through a fire")
			_check(is_instance_valid(frosty) and not frosty.is_burning(), "a frosty buckler shouldn't catch")
			# at home, a burning thing doesn't set the shelves alight
			main.state = main.State.HOME
			var a: Item = main._spawn(ItemDefs.make("crate", "wood"), Vector2(400, 300))
			var b: Item = main._spawn(ItemDefs.make("crate", "wood"), Vector2(470, 300))
			a.freeze = true
			b.freeze = true
			a.ignite()
			row = [b]
		1560:
			_check(not row[0].is_burning(), "at home fire shouldn't leap from one thing to the next")
			print("fire test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false
