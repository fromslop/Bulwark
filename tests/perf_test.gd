extends SceneTree
## Benchmark: a late-game pile (metal gear, coins, a few big items) all carrying charge,
## like an electrified sword touching the pile. Prints frame, process and physics times.
## Needs a window (drawing doesn't happen headless).
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/perf_test.gd [-- --hoard]
## (--hoard adds a long run's coin pile: hundreds of loose coins)

var main: Node
var f := 0
var frame_ms: Array = []
var proc_ms: Array = []
var phys_ms: Array = []
var _last := 0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # measure real cost, not the refresh wait
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		main.enemy.active = false
		var gear := [["kite_shield", "iron"], ["round_shield", "steel"], ["longsword", "iron"], ["mace", "copper"],
			["buckler", "iron"], ["shortsword", "steel"], ["tower_shield", "iron"], ["spear", "copper"]]
		for i in 30:
			var g: Array = gear[i % gear.size()]
			main._spawn(ItemDefs.make(g[0], g[1]), Vector2(60 + (i * 41) % 1160, 300 + (i % 5) * 60))
		main._spawn_coins(40, Vector2(640, 400), 300.0)
		if "--hoard" in OS.get_cmdline_user_args():
			# a long run's coin hoard: hundreds of loose coins and fat coins under everything
			for i in 220:
				main._spawn(ItemDefs.make("coin", "gold"), Vector2(40 + (i * 37) % 1200, 380 + (i % 9) * 30))
			for i in 120:
				main._spawn(ItemDefs.make("coin5", "gold"), Vector2(60 + (i * 53) % 1160, 360 + (i % 7) * 40))
		main._spawn(ItemDefs.make("longsword", "steel", ["electrified"]), Vector2(640, 200))
	if f == 240:
		for n in main.get_tree().get_nodes_in_group("items"):
			n.charge = 1.0  # as if the sword had touched the whole pile
	if f > 240:
		for n in main.get_tree().get_nodes_in_group("items"):
			if n.conductive:
				n.charge = maxf(n.charge, 0.9)
		var now := Time.get_ticks_usec()
		if _last > 0:
			frame_ms.append((now - _last) / 1000.0)
		_last = now
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if f == 540:
		frame_ms.sort()
		var avg := func(a: Array) -> float:
			var t := 0.0
			for v in a:
				t += v
			return t / maxf(1.0, a.size())
		print("perf: %d bodies | frame avg %.1f ms, p95 %.1f ms | process %.1f ms | physics %.1f ms" % [
			main.get_tree().get_nodes_in_group("items").size(), avg.call(frame_ms), frame_ms[int(frame_ms.size() * 0.95)],
			avg.call(proc_ms), avg.call(phys_ms)])
		return true
	return false
