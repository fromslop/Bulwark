extends SceneTree
## Cold and heat pass along a pile only so far: a row of iron bars with a frosty one at
## one end and a superheated one at the other. What touches the source is a step away, the
## next two, and so on; past ELEMENT_HOPS steps nothing comes through. Headless, or windowed
## to save res://shots/elements.png.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/element_test.gd

const N := 14
const SLAB := ["coin25", "iron"]  # flat bars, laid end to end along the floor
var main: Node
var f := 0
var fails: Array = []
var row: Array = []
var w := 0.0  # a bar's width (less a hair, so neighbours press together)


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _width(it: Item) -> float:
	var lo := 1e9
	var hi := -1e9
	for c in it.cells:
		lo = minf(lo, it.cell_pos(c).x)
		hi = maxf(hi, it.cell_pos(c).x)
	return hi - lo + Item.CELL


## An end bar can slide off the row as it settles: push it back against its neighbour.
func _snug(end: int, next: int) -> void:
	var a: Item = row[end]
	var b: Item = row[next]
	a.global_position = Vector2(b.global_position.x + signf(a.global_position.x - b.global_position.x) * w, b.global_position.y)
	a.rotation = b.rotation
	a.linear_velocity = Vector2.ZERO
	a.angular_velocity = 0.0


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
			var probe: Item = main._spawn(ItemDefs.make(SLAB[0], SLAB[1]), Vector2(-500, 0))
			w = _width(probe) - 1.0  # (a hair of overlap: they settle pressed together)
			probe.queue_free()
			for i in N:
				var it: Item = main._spawn(ItemDefs.make(SLAB[0], SLAB[1]), Vector2(640 - (N - 1) * w * 0.5 + i * w, 690))
				row.append(it)
		90:
			_snug(0, 1)
			row[0].add_mod("frosty")
		600:
			var hops := []
			for it in row:
				hops.append(it.cold_hops if it.cold > 0.0 else -1)
			print("cold hops along the row: ", hops)
			var reached := 0
			for i in N:
				if row[i].cold > 0.0:
					reached = i
				_check(row[i].cold <= 0.0 or row[i].cold_hops <= Item.ELEMENT_HOPS, "nothing should carry cold past %d steps (%s)" % [Item.ELEMENT_HOPS, hops])
			_check(reached >= 4, "cold should reach a good way along the row (%s)" % [hops])
			_check(reached <= Item.ELEMENT_HOPS + 1, "the far end of the row shouldn't be cold (%s)" % [hops])
			_check(row[1].cold > 0.5 and row[1].cold_hops == 1, "what touches the frosty one should be frozen, a step away")
			_check(Item.hop_fade(row[reached].cold_hops) < Item.hop_fade(row[1].cold_hops), "frost should be drawn fainter further along")
			row[0].def.modifiers.erase("frosty")
			row[0].cold = 0.0
			for it in row:
				it.cold = 0.0
				it.cold_hops = Item.NO_HOPS
			_snug(N - 1, N - 2)
			row[N - 1].add_mod("superheated")
		1100:
			var hops := []
			var reached := N - 1
			for i in N:
				var it: Item = row[i]
				hops.append(it.heat_hops if it.heat > 0.0 else -1)
				if it.heat > 0.0:
					reached = mini(reached, i)
				_check(it.heat <= 0.0 or it.heat_hops <= Item.ELEMENT_HOPS, "nothing should carry heat past %d steps" % Item.ELEMENT_HOPS)
			print("heat hops along the row: ", hops)
			_check(N - 1 - reached >= 4, "heat should reach a good way along the row (%s)" % [hops])
			_check(N - 1 - reached <= Item.ELEMENT_HOPS + 1, "the far end shouldn't heat up (%s)" % [hops])
			if DisplayServer.get_name() != "headless":
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
				root.get_texture().get_image().save_png("res://shots/elements_heat.png")
			print("element test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	if f == 590 and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
		root.get_texture().get_image().save_png("res://shots/elements_cold.png")
	return false
