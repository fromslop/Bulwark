extends SceneTree
## Lane arrows during a wind-up (coloured by what covers them) and the flash after a blow.
## Saves res://shots/lanes_*.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/lanes_shot.gd

var main: Node
var f := 0
var shield: Item


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _windup(id: String) -> void:
	var e: Enemy = main.enemy
	e.active = false
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS[id].duplicate()
	e.progress = 0.6


func _process(_d: float) -> bool:
	f += 1
	match f:
		10:
			main.enemy.active = false
			for n in main.get_tree().get_nodes_in_group("items"):
				n.queue_free()
		12:
			shield = main._spawn(ItemDefs.make("kite_shield", "iron"), Vector2(700, 300))
			shield.freeze = true
			shield.rotation = PI * 0.5
			shield.teleport(Vector2(700, 316))
			_windup("hew")
		40:
			root.get_texture().get_image().save_png("res://shots/lanes_hew.png")
			main.hand.position = Vector2(-500, -500)
			main._resolve_attack(EnemyDefs.ATTACKS.hew.duplicate())
			main.enemy.state = "idle"
			main.enemy.current = {}
		46:
			root.get_texture().get_image().save_png("res://shots/lanes_result.png")
		60:
			_windup("maul_low_l")
		80:
			root.get_texture().get_image().save_png("res://shots/lanes_maul.png")
			_windup("thrust")
		100:
			root.get_texture().get_image().save_png("res://shots/lanes_thrust.png")
			return true
	return false
