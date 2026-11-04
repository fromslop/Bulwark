extends SceneTree
## Renders every setting, with its features and props, plus the Hidden Vault, to res://shots/setting_*.png.
## Needs a window.
var main: Node
var f := 0
var i := 0
var names: Array = Backdrop.SETTINGS + ["Ossuary", "Star Chamber", "Hidden Vault"]
func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight
func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		main.enemy.active = false
		main.hand.pinned = Vector2(1100, 600)
	if f >= 10 and (f - 10) % 20 == 0:
		if i > 0:
			var prev: String = names[i - 1]
			root.get_texture().get_image().save_png("res://shots/setting_%d_%s.png" % [i, prev.to_lower().replace(" ", "_")])
		if i >= names.size():
			return true
		for n in main.items_root.get_children():
			if n.has_meta("fixture"):
				n.queue_free()
		main._set_backdrop(names[i])
		main._add_features()
		main.props.setup(names[i], 3)
		for pr in main.props.props:
			if pr.kind == "brick":
				main.hand.pinned = pr.pos + Vector2(30, 20)  # close enough for the secret to show
		i += 1
	return false
