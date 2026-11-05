extends SceneTree
## The home fire as it is and stoked to a full blaze: res://shots/hearth_calm.png and
## res://shots/hearth_blaze.png. Needs a window.
var main: Node
var f := 0
func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		main.hand.pinned = Vector2(500, 300)
	if f == 50:
		root.get_texture().get_image().save_png("res://shots/hearth_calm.png")
		main.backdrop.stoke(1.0)
	if f == 56:
		root.get_texture().get_image().save_png("res://shots/hearth_blaze.png")
		return true
	return false
