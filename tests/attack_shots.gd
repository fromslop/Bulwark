extends SceneTree
## The stage 3-5 foes' attacks mid wind-up, as in a fight: moving fields, chases, follow-ups
## (the dashed "2"), and each field's properties (cleave, corrosive, burning, charged, crushing).
## Saves res://shots/attack_<foe>_<attack>.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/attack_shots.gd

var main: Node
var f := 0
var shots := [["Halberdier", "reap", 0.5], ["Halberdier", "pike", 0.4], ["Twinblade", "x_right", 0.6], ["Twinblade", "scissor_hi", 0.6],
	["Bonebreaker", "crush_l", 0.6], ["Brute", "maul_low_l", 0.6], ["Rusted", "drag_low", 0.5], ["Zealot", "flail_arc", 0.95],
	["Wraith", "grasp", 0.9], ["Lamplighter", "arc_lash", 0.6], ["Headsman", "cleave", 0.6],
	["Sexton", "toll", 0.6], ["Sexton", "dig", 0.6], ["Sexton", "peal", 0.95]]
var i := 0
var e: Enemy


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _become(id: String) -> Enemy:
	main._clear_enemies()
	var en := Enemy.new()
	en.setup(EnemyDefs.scaled(id, 0), main.camera)
	main.world3d.add_child(en)
	en.active = false
	main.enemies.append(en)
	main.enemy = en
	main.state = main.State.COMBAT
	return en


func _process(_d: float) -> bool:
	f += 1
	if f < 20:
		return false
	var step := (f - 20) % 30
	if i >= shots.size():
		return true
	var s: Array = shots[i]
	if step == 0:
		main.hand.pinned = Vector2(820, 300)
		e = _become(s[0])
		e.look_target = Vector2(820, 300) / Vector2(1280, 720)
		e._begin_attack(s[1])
		e._feint_at = -1.0
	elif step < 29 and e:
		e._timer = e._windup_total * (1.0 - float(s[2]))
		e.progress = float(s[2])
		e._shape_zone()
	elif step == 29:
		root.get_texture().get_image().save_png("res://shots/attack_%s_%s.png" % [str(s[0]).to_lower(), s[1]])
		i += 1
	return false
