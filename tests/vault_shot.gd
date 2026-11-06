extends SceneTree
## The Hidden Vault heaped with things to take, and a stage with its hidden keyhole (and the
## Mysterious Key held up to it), to res://shots/vault.png and res://shots/keyhole.png.
## Needs a window. Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/vault_shot.gd

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
	match f:
		10:
			main.enemy.active = false
			main.round_num = 1
			main._set_backdrop("Corridor", true)
		20:
			var kp: Vector2 = main._keyhole_screen()
			main.hand.pinned = kp + Vector2(60, 40)
			print("keyhole at ", kp)
		50:
			root.get_texture().get_image().save_png("res://shots/keyhole.png")
			main.round_num = 2
			main.secret_next = true
			main._start_fight()
			main.enemy.active = false
			main.hand.pinned = Vector2(1250, 700)
		120:
			root.get_texture().get_image().save_png("res://shots/vault.png")
			return true
	return false
