extends SceneTree
## The shop gong's face showing the next fight: hand far (faint) and hand near (clear), for
## an ordinary next stage, a boss, and a secret place. Saves res://shots/gong_*.png.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/gong_shot.gd

var main: Node
var f := 0
var cases := [[0, ""], [3, ""], [1, "Giant's Table"]]  # [round, secret]
var i := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	if f < 10:
		return false
	var step := (f - 10) % 120
	if step == 0:
		if i >= cases.size():
			return true
		main.round_num = cases[i][0]
		main.secret_stage = cases[i][1]
		main.enemy.active = false
		main._open_shop()
		main.hand.pinned = Vector2(700, 600)
	if step == 60:
		root.get_texture().get_image().save_png("res://shots/gong_%d_far.png" % i)
		main.hand.pinned = main.GONG.pos + Vector2(-60, 40)
	if step == 119:
		root.get_texture().get_image().save_png("res://shots/gong_%d_near.png" % i)
		main.secret_stage = ""
		i += 1
	return false
