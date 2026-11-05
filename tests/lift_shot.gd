extends SceneTree
## The lift back up from the Molten Core, coming down and then open. Saves res://shots/lift_*.png. Window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/lift_shot.gd

var main: Node
var f := 0
var t0 := -1


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
		main._start_fight()
		main.enemy.active = false
		main.enemy.take_hit(1e9, "torso", false)
		main.hand.pinned = Vector2(900, 650)
	if t0 < 0 and main.state == main.State.SHOP:
		t0 = f
	if t0 > 0 and f - t0 == 70:
		root.get_texture().get_image().save_png("res://shots/lift_arriving.png")
	if t0 > 0 and f - t0 == 240:
		root.get_texture().get_image().save_png("res://shots/lift_open.png")
		return true
	return false
