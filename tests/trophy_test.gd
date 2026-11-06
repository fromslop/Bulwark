extends SceneTree
## The trophy rack at home: a real cup for every boss felled stands on it (newest first, a
## deeper run's bigger), thrown in the hearth it melts into coins and is gone for good, cups
## never leave home, and every coin lying about at home comes along on the next run. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/trophy_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_trophy_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(SaveData.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _cups() -> Array:
	return main.items_root.get_children().filter(func(n: Node) -> bool: return n is Item and n.def.kind == "trophy" and not n.is_queued_for_deletion())


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	await _frames(3)
	var s: SaveData = main.save
	s.stats.bosses = 7
	s.trophies = [["Castellan", 0], ["Castellan", 0], ["Castellan", 1], ["The Sexton", 1], ["Castellan", 2], ["The Sexton", 2], ["The Sexton", 3]]
	main._go_home()
	await _frames(3)

	# a cup each, the newest five on the rack, standing on its board
	var cups := _cups()
	_check(cups.size() == 7, "there should be a cup for each of the 7 bosses (got %d)" % cups.size())
	var on_rack: Array = []
	for slot in main.racks:
		if slot.kind == "trophy" and slot.item != null:
			on_rack.append(slot.item)
	_check(on_rack.size() == main.TROPHY_SLOTS.size(), "the rack should be full (%d of %d)" % [on_rack.size(), main.TROPHY_SLOTS.size()])
	var newest: Item = on_rack[0] if not on_rack.is_empty() else null
	_check(newest != null and newest.def.trophy == ["The Sexton", 3], "the newest cup should stand first (%s)" % [newest.def.get("trophy", []) if newest else "none"])
	if newest:
		var bottom := -INF
		for c in newest.cells:
			bottom = maxf(bottom, newest.to_global(newest.cell_pos(c)).y + Item.CELL * 0.5)
		_check(absf(bottom - main.TROPHY_SHELF_Y) < 2.0, "a cup should stand on the board (bottom %.1f, board %.1f)" % [bottom, main.TROPHY_SHELF_Y])
	_check(on_rack.all(func(c: Item) -> bool: return c.collision_layer == Item.SHOP_LAYER), "cups on the rack should stand apart: nothing swung at home catches on them")
	var plain: Item = cups.filter(func(c: Item) -> bool: return c.def.trophy[1] == 0)[0]
	_check(newest.cells.size() > plain.cells.size(), "a deeper run's cup should be bigger")
	_check(int(newest.def.melt_value) > int(plain.def.melt_value), "and worth more melted down")

	# a cup that rolls up to the hearth stays; one thrown in melts into coins
	var hearth: Dictionary = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "hearth")[0]
	for slot in main.racks:
		if slot.item == newest:
			slot.item = null
	newest.freeze = false
	newest.teleport(hearth.pos)
	newest.set_meta("let_go_at", -99.0)
	for i in 40:
		main.props.feed([newest], 0.05)
	_check(is_instance_valid(newest) and not newest.is_queued_for_deletion(), "a cup that only rolled up to the hearth should be left alone")
	var coins_before: int = main.coin_total()
	var worth := int(newest.def.melt_value)
	newest.set_meta("let_go_at", main.clock)
	for i in 40:
		main.props.feed([newest], 0.05)
	await _frames(2)
	_check(not is_instance_valid(newest) or newest.is_queued_for_deletion(), "a cup thrown in the hearth should melt down")
	_check(main.coin_total() == coins_before + worth, "it should melt into %d coins (%d -> %d)" % [worth, coins_before, main.coin_total()])
	_check(not s.trophies.has(["The Sexton", 3]) and s.trophies.size() == 6, "a melted cup is gone from the trophy list (%s)" % [s.trophies])
	var loaded := SaveData.load_file()
	_check(loaded.trophies.size() == 6, "and stays gone in the save, not refilled as a plain cup (%d)" % loaded.trophies.size())

	# junk in the fire melts into coins too (no Coin Purse any more)
	s.stats.smelt = 0.95
	coins_before = main.coin_total()
	var junk: Item = main._spawn(ItemDefs.make("pauldron", "iron"), hearth.pos)
	for i in 30:
		main.props.feed([junk], 0.05)
	await _frames(2)
	_check(main.coin_total() > coins_before, "melted junk should make coins (%d -> %d)" % [coins_before, main.coin_total()])
	_check(main.items_root.get_children().filter(func(n: Node) -> bool: return n is Item and n.def.get("id", "") == "coin_purse").is_empty(), "no Coin Purse should pop out")

	# off to a run holding a cup: the cup stays home; the coins at home come along
	var home_coins: int = main.coin_total()
	var cup: Item = _cups()[0]
	main.hand.grab(cup, cup.global_position)
	main._start_run()
	await _frames(3)
	_check(main.hand.held == null and _cups().is_empty(), "a cup shouldn't leave home")
	_check(s.trophies.size() == 6, "taking a cup to the gong shouldn't cost you it (%d)" % s.trophies.size())
	_check(main.coin_total() >= home_coins + main.STARTING_COINS, "the %d coins at home should come along on the run (have %d)" % [home_coins, main.coin_total()])
	var saved_coins: Array = SaveData.load_file().home.filter(func(e: Dictionary) -> bool: return e.get("kind", "") == "coin")
	_check(saved_coins.is_empty(), "coins taken on the run shouldn't stay in the home save (%d left)" % saved_coins.size())

	print("trophy test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
