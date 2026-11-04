extends SceneTree
## Opens the pause menu's settings page and saves a screenshot to res://shots/settings.png.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/settings_shot.gd

var main: Node
var frame := 0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 20:
		var menu: PauseMenu = get_first_node_in_group("pause_menu")
		menu._pause()
		menu._open_settings()
	if frame == 40:
		root.get_texture().get_image().save_png("res://shots/settings.png")
		return true
	return false
