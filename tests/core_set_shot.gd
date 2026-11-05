extends SceneTree
## The Molten Core's set, empty, and with the Smelter in it. Saves res://shots/core_*.png. Window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/core_set_shot.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.active = false
		main.round_num = 1
		main.secret_stage = "Molten Core"
		main._clear_enemies()
		for n in main.items_root.get_children():
			if n is Item:
				n.queue_free()
		main._start_fight()
		main.hand.pinned = Vector2(1250, 700)
	if f == 20:
		main.enemy.active = false
		main.enemy.visible = false
	if f == 80:
		root.get_texture().get_image().save_png("res://shots/core_set.png")
		main.enemy.visible = true
	if f == 120:
		root.get_texture().get_image().save_png("res://shots/core_fight.png")
		return true
	return false
