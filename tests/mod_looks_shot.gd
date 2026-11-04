extends SceneTree
## Every modifier's look: one iron dagger per modifier, laid out in a grid with its name
## under it. Saves res://shots/mod_looks.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/mod_looks_shot.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.hand.pinned = Vector2(1260, 700)
		for n in main.items_root.get_children():
			if n is Item:
				n.queue_free()
		var mods: Array = ItemDefs.MODIFIERS.keys().filter(func(m: String) -> bool: return not m in ["small", "large", "huge", "sticky"])
		var cols := 10
		var layer := CanvasLayer.new()
		layer.layer = 20
		main.add_child(layer)
		for i in mods.size():
			var at := Vector2(70 + (i % cols) * 126, 60 + (i / cols) * 140)
			var it: Item = main._spawn(ItemDefs.make("dagger", "iron", [mods[i]]), at)
			it.freeze = true
			it.rotation = 0.0
			it.teleport(at)
			var l := Label.new()
			l.text = str(ItemDefs.MODIFIERS[mods[i]].get("name", mods[i]))
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_constant_override("outline_size", 4)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			l.position = at + Vector2(-50, 42)
			l.size = Vector2(100, 16)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			layer.add_child(l)
	if f == 70:
		root.get_texture().get_image().save_png("res://shots/mod_looks.png")
		return true
	return false
