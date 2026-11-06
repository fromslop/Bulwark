extends SceneTree
## The Bestiary's portrait plays a foe's recorded clips (res://animations), as a fight does:
## its idle between swings, and a picked attack wound up and swung from its own clip, the
## blow landing where the game's does. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/bestiary_test.gd

var main: Node
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_bestiary_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(SaveData.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(3)
	var c: Codex = main.codex
	main.save.discover("foes", "Knight")
	c.selected = ["", "", "Knight", ""]
	c.open_tab(2)
	await _frames(3)
	var foe: Enemy = c._foe
	_check(foe != null and is_instance_valid(foe), "the Bestiary should show the Knight")
	if foe == null:
		_finish()
		return
	_check(foe.clip("act_overhead_l") != null, "the Knight should have recorded clips to show")
	c.play_attack("overhead_l")
	c.attack_pick = -1  # (played once: no replay, so it can settle into its idle after)
	await _frames(10)
	_check(foe.state == "windup" and foe.clip_name.begins_with("act_"), "winding up, the portrait should play the recorded attack (%s, %s)" % [foe.state, foe.clip_name])
	var t0 := foe.clip_time
	await _frames(10)
	_check(foe.clip_time > t0, "and the clip should move on as the wind-up goes (%.2f -> %.2f)" % [t0, foe.clip_time])
	var wind: float = c._replay.windup
	await _frames(int(wind * 60.0))
	_check(foe.state == "recover" and foe.clip_name.begins_with("act_"), "as the blow lands it should play the recorded follow-through (%s, %s)" % [foe.state, foe.clip_name])
	await _frames(150)
	_check(foe.clip_name.begins_with("idle_"), "between swings it should play its recorded idle (%s)" % foe.clip_name)
	_finish()


func _finish() -> void:
	print("bestiary test: %d failures" % fails.size())
	for m in fails:
		print("  FAIL ", m)
	DirAccess.remove_absolute(SaveData.PATH)
	quit(1 if fails.size() > 0 else 0)
