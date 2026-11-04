extends SceneTree
## Renders the inspect view (as if Alt were held) to res://shots/: an item card with the
## stats strip and ring slots, then a worn ring's card, then a weapon for sale.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/inspect_shot.gd

var main: Node
var f := 0
var weapon: Item


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
		main._spawn(ItemDefs.make("kite_shield", "iron", ["electrified", "large"]), Vector2(640, 560))
		weapon = main._spawn(ItemDefs.make("longsword", "steel", ["electrified", "regenerating", "magnetic"]), Vector2(950, 300))
		weapon.freeze = true
		weapon.owned = false
		main.hand.ring_slots = 4
		main.hand.wear_ring("ring_momentum")
		main.hand.wear_ring("ring_fireward")
		main.hand.wear_ring("ring_tempo")
		main.hand.ring_cds[2] = 7.0
		main.hand.injury = 35.0
		main.hand.force_inspect = true
	if f == 90:
		main.hand.pinned = Vector2(640, 560)
	if f == 100:
		root.get_texture().get_image().save_png("res://shots/inspect_item.png")
		main.hand.pinned = Vector2(37, 173)  # over the first ring slot
	if f == 110:
		root.get_texture().get_image().save_png("res://shots/inspect_ring.png")
		main.hand.pinned = weapon.global_position
	if f == 120:
		root.get_texture().get_image().save_png("res://shots/inspect_shop.png")
		return true
	return false
