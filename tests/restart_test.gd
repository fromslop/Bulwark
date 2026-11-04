extends SceneTree
## Restarts the run from busy states (a burning, charged pile mid-fight; the shop; the dark
## catacombs with Alt held) and fails if anything errors while the old run unloads.
## Needs a window. Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/restart_test.gd
var f := 0
var step := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main  # so reload_current_scene works like the R key
	main.call_deferred("_start_run")


func _main() -> Node:
	return current_scene


func _process(_d: float) -> bool:
	f += 1
	if f % 60 != 30:
		return false
	var m := _main()
	if m == null:
		return false
	match step:
		0:
			m._spawn(ItemDefs.make("crate", "wood", ["volatile"]), Vector2(500, 600))
			m._spawn(ItemDefs.make("strongbox", "iron", ["superheated", "magnetic"]), Vector2(520, 500))
			m._spawn(ItemDefs.make("longsword", "steel", ["electrified"]), Vector2(700, 600))
			m._spawn(ItemDefs.make("potion_steel", "glass"), Vector2(600, 300))
			m._spawn_coins(30, Vector2(640, 500), 200.0)
			m.hand.force_inspect = true
		1:
			reload_current_scene()
		2:
			m._start_run()
			m.enemy.take_hit(1e9, "torso", false)
		3:
			m.hand.force_inspect = true
		4:
			reload_current_scene()
		5:
			m._start_run()
			m._set_backdrop("Catacombs")
			m._add_features()
			m.hand.force_inspect = true
			m.hand.injury = m.hand.max_hp  # defeat: the run restarts itself
		9:
			print("restart test done")
			return true
	step += 1
	return false
