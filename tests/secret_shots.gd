extends SceneTree
## Renders each secret place with its guardian to res://shots/secret_*.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/secret_shots.gd

var main: Node
var f := 0
var i := 0
var names: Array = Secrets.STAGES.keys()


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	if f < 10:
		return false
	if (f - 10) % 50 == 0:
		if i > 0:
			var prev: String = names[i - 1]
			root.get_texture().get_image().save_png("res://shots/secret_%s.png" % prev.to_lower().replace(" ", "_").replace("'", ""))
		if i >= names.size():
			return true
		main.round_num = 1
		main._last_foe_def = EnemyDefs.scaled("Brute", 0)
		main.secret_stage = names[i]
		main._start_fight()
		for e in main.living():
			e.active = false
		main.hand.pinned = Vector2(1150, 620)
		i += 1
	return false
