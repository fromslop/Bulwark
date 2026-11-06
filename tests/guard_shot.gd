extends SceneTree
## A Knight on guard as he winds up an attack (he guards through every wind-up), to
## res://shots/guard.png. Needs a window.
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
		Looks.choice.enemy = 0
		main._clear_enemies()
		var e := Enemy.new()
		e.setup(EnemyDefs.scaled("Knight", 0), main.camera)
		main.world3d.add_child(e)
		e.active = false
		main.enemies.append(e)
		main.enemy = e
		main.hand.pinned = Vector2(900, 500)
	if f == 30:
		main.enemy.active = true
		main.enemy._begin_attack("overhead_l")  # (on guard through the wind-up)
		main.enemy.active = false
	if f == 60:
		root.get_texture().get_image().save_png("res://shots/guard.png")
		return true
	return false
