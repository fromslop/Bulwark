extends SceneTree
## A superheated Stormcaller's firestorm and a frosty Wisp Cannon's wisps in flight.
## Saves res://shots/storm_*.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/storm_shot.gd

var main: Node
var f := 0
var cannon: Item


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	if f > 10 and f < 70:
		cannon.teleport(Vector2(1000, 560))
		cannon.angular_velocity = 30.0
	match f:
		10:
			var e: Enemy = main.enemy
			e.active = false
			e.max_hp = 5000.0
			e.hp = 5000.0
			var caller: Item = main._spawn(ItemDefs.make("longsword", "steel", ["stormcaller", "superheated"]), Vector2(400, 600))
			caller.heat = 1.0
			main._call_storm(caller, e, 20.0, Vector2(400, 500))
			cannon = main._spawn(ItemDefs.make("longsword", "steel", ["wispfire", "frosty"]), Vector2(1000, 560))
			cannon.gravity_scale = 0.0
		40:
			root.get_texture().get_image().save_png("res://shots/storm_fire.png")
		70:
			root.get_texture().get_image().save_png("res://shots/storm_wisps.png")
			return true
	return false
