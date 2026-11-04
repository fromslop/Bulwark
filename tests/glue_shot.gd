extends SceneTree
## Glue up close: a buckler fused to a sword (amber seam), a rock on a club, and a buckler
## with an unused wet patch. Saves res://shots/glue.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/glue_shot.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _hang(it: Item, at: Vector2) -> void:
	it.freeze = true
	it.teleport(at)


func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.hand.pinned = Vector2(1200, 650)
		var sword: Item = main._spawn(ItemDefs.make("longsword", "steel"), Vector2(400, 420))
		var b: Item = main._spawn(ItemDefs.make("buckler", "steel", ["electrified"]), Vector2(400, 380))
		sword.fuse(b)
		_hang(sword, Vector2(400, 420))
		var club: Item = main._spawn(ItemDefs.make("club", "wood"), Vector2(700, 430))
		var rock: Item = main._spawn(ItemDefs.make("rock", "stone"), Vector2(700, 370))
		club.fuse(rock)
		_hang(club, Vector2(700, 430))
		var wet: Item = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(960, 420))
		wet.glue_patch(wet.global_position + Vector2(30, 0), 1)
		_hang(wet, Vector2(960, 420))
	if f == 50:
		root.get_texture().get_image().save_png("res://shots/glue.png")
		return true
	return false
