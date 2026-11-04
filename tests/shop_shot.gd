extends SceneTree
## Renders the shop to res://shots/shop.png. Needs a real window.
var main: Node
var f := 0
func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.take_hit(1e6, "torso", false)
	if f == 220:
		main.hand.pinned = Vector2(640, 600)
		root.get_texture().get_image().save_png("res://shots/shop.png")
		return true
	return false
