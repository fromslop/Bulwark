extends SceneTree
## After the Smelter: the next shop has a lift instead of the door. It arrives (car down, ding,
## doors open); in holding something, the doors close and it goes home. Or strike the gong and
## the run prestiges. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/lift_test.gd

var main: Node
var f := 0
var fails: Array = []
var phase := 0
var t0 := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _beat_smelter() -> void:
	main.enemy.active = false
	main.round_num = 1
	main.secret_stage = "Molten Core"
	main._clear_enemies()
	main._start_fight()
	main.enemy.active = false
	main.enemy.take_hit(1e9, "torso", false)


func _process(_d: float) -> bool:
	f += 1
	match phase:
		0:
			if f == 10:
				_beat_smelter()
				phase = 1
		1:
			if main.state == main.State.SHOP:
				_check(main.overlay.lift and not main.overlay.door.is_empty(), "after the Smelter the shop should have a lift")
				_check(main.overlay.lift_car < 0.5, "the lift should still be coming down when the shop opens")
				t0 = f
				phase = 2
		2:
			if f - t0 == 240:
				_check(main.overlay.lift_car >= 1.0 and main.overlay.lift_open >= 1.0, "the lift should arrive and open its doors (%.2f, %.2f)" % [main.overlay.lift_car, main.overlay.lift_open])
				# continue instead: the gong, and the run prestiges
				var p0: int = main.prestige
				main._close_shop()
				_check(main.prestige == p0 + 1, "going on after the Smelter should prestige the run (%d -> %d)" % [p0, main.prestige])
				_check(main.round_num % EnemyDefs.STAGES == 0, "and start the next lap from its first stage (round %d)" % main.round_num)
				_check(not main.overlay.lift and not main._core_cleared, "the lift shouldn't follow you into the next fight")
				phase = 3
				t0 = f
		3:
			if f - t0 == 10:
				# beat it again; this time ride the lift home
				_beat_smelter()
				phase = 4
		4:
			if main.state == main.State.SHOP:
				t0 = f
				phase = 5
		5:
			if f - t0 == 240:
				var it: Item = main._spawn(ItemDefs.make("longsword", "iron"), main.DOOR.pos)
				main.hand.position = main.DOOR.pos
				main.hand.grab(it, main.DOOR.pos)
				main._return_home()
				_check(main.state == main.State.SHOP and main._lift_busy, "stepping in: the doors close before it leaves")
				t0 = f
				phase = 6
		6:
			if f - t0 == 200:
				_check(main.state == main.State.HOME, "the lift should take you home")
				print("lift test: %d failures" % fails.size())
				for x in fails:
					print("  FAIL ", x)
				quit(1 if fails.size() > 0 else 0)
	if f > 3000:
		fails.append("timed out in phase %d" % phase)
		print("lift test: %d failures" % fails.size())
		for x in fails:
			print("  FAIL ", x)
		quit(1)
	return false
