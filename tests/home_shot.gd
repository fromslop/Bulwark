extends SceneTree
## The home with its collections, mirror, dummy, trophy board, cat and chimes.
## Saves res://shots/home.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/home_shot.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		main.hand.pinned = Vector2(700, 420)
		main.save.prestige_best = 3
		main.save.stats.bosses = 4
	if f == 60:
		root.get_texture().get_image().save_png("res://shots/home.png")
		return true
	return false
