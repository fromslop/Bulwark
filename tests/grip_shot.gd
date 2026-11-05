extends SceneTree
## Renders an iron, a steel and a prestigium sword side by side to res://shots/grips.png:
## wooden grip, steel grip, prestigium grip. Needs a real window.
var main: Node
var f := 0
func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.active = false
		for n in main.items_root.get_children():
			if n is Item:
				n.queue_free()
		var i := 0
		for m in ["iron", "steel", "prestigium"]:
			var it: Item = main._spawn(ItemDefs.make("longsword", m), Vector2(480 + i * 160, 420))
			it.freeze = true
			it.rotation = 0.0
			i += 1
	if f == 30:
		main.hand.pinned = Vector2(1200, 650)
		root.get_texture().get_image().save_png("res://shots/grips.png")
		return true
	return false
