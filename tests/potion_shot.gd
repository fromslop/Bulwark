extends SceneTree
## Renders a potion splash (Steelwater over a copper sword, Venom over a shield) to res://shots/.
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
	if f == 5:
		main.enemy.active = false
		var s: Item = main._spawn(ItemDefs.make("longsword", "copper"), Vector2(500, 560))
		s.rotation = PI / 2
		main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(860, 600))
		main._spawn(ItemDefs.make("potion_steel", "glass"), Vector2(500, 200))
		main._spawn(ItemDefs.make("potion_poison", "glass"), Vector2(860, 200))
		main.hand.pinned = Vector2(1100, 300)
	if f == 60:
		for it in main.items_root.get_children():
			if it is Item and it.def.kind == "potion":
				it.shatter()
	if f == 72:
		root.get_texture().get_image().save_png("res://shots/potion_splash.png")
	if f == 160:
		root.get_texture().get_image().save_png("res://shots/potion_after.png")
		return true
	return false
