extends SceneTree
## How many swings each weapon takes to burst each crate of yours. Windowless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/smash_probe.gd

var main: Node


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _handle(it: Item) -> Vector2:
	for c in it.cells:
		if it.cells[c].get("handle", false):
			return it.to_global(it.cell_pos(c))
	return it.global_position


func _reach(it: Item) -> float:
	var h := _handle(it)
	var far := 0.0
	for c in it.cells:
		far = maxf(far, it.to_global(it.cell_pos(c)).distance_to(h))
	return far


func swings_to_open(weapon: Array, crate: Array, cap: int) -> Array:
	for n in main.items_root.get_children():
		if n is Item:
			n.queue_free()
	await _frames(2)
	var w: Item = main._spawn(ItemDefs.make(weapon[0], weapon[1], weapon.slice(2)), Vector2(500, 400))
	var spot := Vector2(760, 640)
	var c: Item = main._spawn(ItemDefs.make(crate[0], crate[1]), spot)
	# the crate floats in the blade's arc, 55 degrees round from upright
	c.base_gravity = 0.0
	spot = Vector2(760, 420)
	var grip := spot - Vector2(sin(0.95), -cos(0.95)) * (_reach(w) * 0.75 + c.origin.length() * 0.5)
	main.hand.pinned = grip
	main.hand.position = grip
	w.global_position = grip + (w.global_position - _handle(w))
	main.hand.grab(w, _handle(w))
	for i in cap:
		await _frames(40)  # stands back up
		if not is_instance_valid(c) or c.def.get("opened", false):
			return [i, 0.0]
		c.global_position = spot
		c.rotation = 0.0
		c.linear_velocity = Vector2.ZERO
		c.angular_velocity = 0.0
		w.cooldown = 0.0
		main.hand._activate()
		await _frames(30)
		if not is_instance_valid(c) or c.def.get("opened", false):
			return [i + 1, 0.0]
	return [cap, c.health_ratio() if is_instance_valid(c) else 0.0]


func _run() -> void:
	await _frames(10)
	var cap := 10
	for weapon in [["warhammer", "steel"], ["greatsword", "steel"], ["mace", "iron"], ["shortsword", "iron"], ["club", "wood"], ["greatsword", "prestigium"], ["shortsword", "iron", "corrosive"]]:
		var line := "%-18s" % ("%s %s" % [weapon[1], weapon[0]])
		for crate in [["crate", "wood"], ["strongbox", "iron"], ["reliquary", "steel"]]:
			var r: Array = await swings_to_open(weapon, crate, cap)
			line += "  %s: %s" % [crate[0], ("%d swings" % r[0]) if r[0] < cap else ("shut (%.0f%%)" % (r[1] * 100.0))]
		print(line)
	quit(0)
