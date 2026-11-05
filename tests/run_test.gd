extends SceneTree
## Whole runs, end to end, as a player moves through them: from home strike the gong, win each
## fight (quickly: the foe is cut down after a few of its blows), shop (buy what can be afforded,
## reroll), strike the gong, through the boss, out the door home holding something, and round
## again, twice through (a death reloads the scene, which tests/restart_test.gd covers). Checks the flow never stalls or errors, and that
## the home save, the tallies and the trophy shelf come out right. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/run_test.gd

var main: Node
var fails: Array = []
var t := 0.0
var step_t := 0.0
var runs_done := 0
var phase := "home"
var last_state := -1
var fights := 0
var bought := 0
var stuck := 0.0
var died := false


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_run_test_save.txt"
	if FileAccess.file_exists(SaveData.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _finish() -> void:
	print("run test: %d runs, %d fights, %d bought" % [runs_done, fights, bought])
	print("run test: %d failures" % fails.size())
	for x in fails:
		print("  FAIL ", x)
	quit(1 if fails.size() > 0 else 0)


func _process(delta: float) -> bool:
	t += delta
	step_t += delta
	if t > 900.0:
		fails.append("timed out in state %s" % main.State.keys()[main.state])
		_finish()
		return true
	if main.state != last_state:
		last_state = main.state
		step_t = 0.0
		stuck = 0.0
	stuck += delta
	if stuck > 60.0:
		fails.append("stuck in %s for a minute (round %d)" % [main.State.keys()[main.state], main.round_num])
		_finish()
		return true
	main.hand.pinned = Vector2(640, 600)
	main._molten_limit = 1e12  # (this test buys a mountain of gear: the floor's fall has its own test, molten_test)
	match main.state:
		main.State.HOME:
			if step_t > 0.5 and step_t < 0.6:
				if runs_done >= 2:
					_check(main.save.stats.runs >= 2, "two runs should be tallied (%d)" % main.save.stats.runs)
					_check(main.save.trophies.size() >= 2, "two bosses felled should mean two cups (%d)" % main.save.trophies.size())
					var back := SaveData.load_file()
					_check(back.trophies.size() == main.save.trophies.size(), "the cups should be in the save")
					_finish()
					return true
				main._strike_gong()
		main.State.COMBAT:
			var foes: Array = main.living()
			if step_t > 3.0 and not foes.is_empty():
				for e in foes:
					e.take_hit(1e7, "torso", false)
				fights += 1
			main.hand.injury = 0.0
		main.State.SHOP:
			if step_t > 0.3 and step_t < 0.4:
				main._spawn_coins(30, Vector2(640, 500), 40.0)
			if step_t > 1.0 and step_t < 1.1:
				main._reroll()
				for sh in main.shelves.duplicate():
					if main.coin_total() >= sh.price:
						main._on_buy_attempt(sh.item, sh.item.global_position)
						main.hand.release()
						bought += 1
			if step_t > 1.6 and step_t < 1.7:
				if not main.overlay.door.is_empty():
					# past the boss: home through the door, holding the first thing to hand
					var it: Item = null
					for n in main.items_root.get_children():
						if n is Item and n.owned and n.def.kind == "weapon":
							it = n
							break
					_check(it != null, "there should be a weapon to carry home")
					if it:
						main.hand.position = it.global_position
						main.hand.grab(it, it.global_position)
						main._return_home()
						runs_done += 1
						_check(main.state == main.State.HOME, "the door should take you home")
				else:
					main._strike_gong()
	return false
