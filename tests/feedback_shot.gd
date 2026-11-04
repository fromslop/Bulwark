extends SceneTree
## Renders a broken enemy (weak point open) with a stripped shoulder, then a clean block,
## to res://shots/. Needs a real window.
var main: Node
var f := 0
var shield: Item
func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.take_hit(main.enemy.max_hp * 0.4, "torso", false)
		main.enemy.data.stagger = 1.0
		main.enemy.add_stagger(5.0)
		main.hand.pinned = Vector2(900, 500)
		shield = main._spawn(ItemDefs.make("round_shield", "iron"), Vector2(640, 0.27 * 720))
		shield.freeze = true
	if f == 40:
		root.get_texture().get_image().save_png("res://shots/broken.png")
		main.enemy.active = false
		shield.teleport(Vector2(640, 0.27 * 720))
	if f == 44:
		main._resolve_attack(EnemyDefs.ATTACKS["slash_high_r"].duplicate())
	if f == 47:
		root.get_texture().get_image().save_png("res://shots/clean_block.png")
		Engine.time_scale = 1.0
		return true
	return false
