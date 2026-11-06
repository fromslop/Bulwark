extends SceneTree
## Scaling benchmark: gear rained onto the floor a row at a time until there are N whole
## things (plus loose coins), measured once the pile has had time to settle. Prints the
## frame, process and physics times and how much of the pile is asleep, so a change to the
## per-body cost shows up as a number. Needs a window (drawing doesn't happen headless).
## The schedule runs on physics ticks and the clock, not frames: uncapped, a cheap frame
## is a millisecond, and a count of frames would drop the rows on top of each other.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/perf_scale.gd -- [options]
##   --n=120        whole gear items (default 120)
##   --coins=0      loose fat coins on top (they fuse past COIN_BODIES; default 0)
##   --debris=0     splinters and scraps in the pile (what a long run is mostly made of)
##   --huge         three giants first: a greatsword, a tower shield and a round shield at
##                  two and a half times their size (a thousand cells and more each)
##   --stir=1500    knock a body every N ms while measuring, as a player rummaging does:
##                  the whole touching pile wakes (measures the awake pile, over 6 s)
##   --charge       every fourth thing electrified: the whole pile carries charge
##   --seed=7       the room and the pile
##   --fps=0        cap the frame rate (0: none)
##   --no-item-tick items' _physics_process off (impacts, elements, effects)
##   --hide-items   items' 2D layer hidden (no item drawing at all)
##   --no-main      main's _process and _physics_process off
##   --no-enemy     the foe removed
##   --no-set       the 3D set hidden
##   --sleep=N      sleep thresholds raised to N px/s and N*2.5 deg/s (an experiment)
##   --dump         the fastest and highest bodies at the end

const ROW_EVERY := 48  # physics ticks between rows (0.4 s: the last row has fallen clear)
const HEADROOM := 170.0  # px: a row waits until the pile's top is below this
const WAIT_MAX := 480  # ticks a row waits for headroom at most (then it drops anyway)
const SETTLE := 720  # ticks after the last row before measuring (6 s)
const MEASURE := 3.0  # seconds measured
# a long run's hoard: a few big things and a lot of small ones
const GEAR := [["kite_shield", "iron"], ["coin5", "gold"], ["dagger", "steel"], ["pauldron", "iron"],
	["round_shield", "steel"], ["coin25", "gold"], ["rock", "stone"], ["buckler", "iron"],
	["longsword", "iron"], ["coin5", "gold"], ["skull", "bone"], ["shortsword", "steel"],
	["mace", "copper"], ["coin5", "gold"], ["pauldron", "iron"], ["dagger", "steel"],
	["axe", "iron"], ["coin25", "gold"], ["rock", "stone"], ["buckler", "iron"],
	["crate", "wood"], ["club", "wood"], ["coin5", "gold"], ["spear", "wood"]]

var main: Node
var f := 0
var frame_ms: Array = []
var proc_ms: Array = []
var phys_ms: Array = []
var _last := 0
var args: PackedStringArray
var _n := 120
var _coins := 0
var _spawned := 0
var _coins_spawned := 0
var _debris := 0
var _debris_spawned := 0
var _stir_at := 0  # ms
var _next_row := 0  # physics tick of the next row
var _waited := 0
var _measure_from := 0  # physics tick the measuring starts at (0: not yet)
var _measure_end := 0  # ms
var _measuring := false


func _opt(key: String, default: int) -> int:
	for a in args:
		if a.begins_with(key + "="):
			return int(a.substr(key.length() + 1))
	return default


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	_n = _opt("--n", 120)
	_coins = _opt("--coins", 0)
	_debris = _opt("--debris", 0)
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.rng.seed = _opt("--seed", 7)  # the same room and the same pile every run
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


## Is there room under the ceiling for another row? (Dropped into the pile, things overlap
## and the solver throws them about: not a pile, an explosion.)
func _headroom() -> bool:
	for n in main.get_tree().get_nodes_in_group("items"):
		if n.global_position.y < HEADROOM:
			return false
	return true


## The pile is here to be counted, not broken: nothing in it can lose a cell.
func _harden(it: Item) -> void:
	for c in it.cells:
		it.cells[c].hp = 1.0e9
		it.cells[c].max = 1.0e9


func _row() -> void:
	if _spawned < _n:
		for col in 12:
			if _spawned >= _n:
				break
			var g: Array = GEAR[_spawned % GEAR.size()]
			if "--huge" in args and _spawned < 3:
				g = [["greatsword", "steel"], ["tower_shield", "iron"], ["round_shield", "steel"]][_spawned]
			var d: Dictionary = ItemDefs.make(g[0], g[1])
			if "--huge" in args and _spawned < 3:
				d.size = 2.5
				d.modifiers.append("spiked")
			if "--charge" in args and _spawned % 4 == 0:
				d.modifiers.append("electrified")
			_harden(main._spawn(d, Vector2(70 + col * 100 + (_spawned * 37) % 30, 30 + (col % 3) * 15)))
			_spawned += 1
	elif _coins_spawned < _coins:
		for k in 24:
			if _coins_spawned >= _coins:
				break
			_harden(main._spawn(ItemDefs.make("coin5", "gold"), Vector2(30 + k * 52 + (_coins_spawned * 13) % 20, 20 + (k % 2) * 12)))
			_coins_spawned += 1
	elif _debris_spawned < _debris:
		for k in 24:
			if _debris_spawned >= _debris:
				break
			var d := {"kind": "debris", "shape": "coin", "material": "wood" if k % 3 else "iron", "name": "Scrap", "piece": true, "modifiers": []}
			_harden(main._spawn(d, Vector2(30 + k * 52 + (_debris_spawned * 17) % 24, 20 + (k % 2) * 12)))
			_debris_spawned += 1


func _setup() -> void:
	# (Settings.apply() in main's _ready turns the player's vsync back on)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # measure real cost, not the refresh wait
	Engine.max_fps = _opt("--fps", 0)
	main.enemy.active = false
	var sl := _opt("--sleep", 0)
	if sl > 0:
		var space := main.get_viewport().world_2d.space
		PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_LINEAR_VELOCITY_SLEEP_THRESHOLD, sl)
		PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_ANGULAR_VELOCITY_SLEEP_THRESHOLD, deg_to_rad(sl * 2.5))
	if "--no-enemy" in args:
		for e in main.living():
			e.queue_free()
	if "--no-main" in args:
		main.set_process(false)
		main.set_physics_process(false)
	if "--no-set" in args:
		main.world3d.visible = false
	_next_row = Engine.get_physics_frames()


func _start_measuring() -> void:
	for n in main.get_tree().get_nodes_in_group("items"):
		if "--no-item-tick" in args:
			n.set_physics_process(false)
		if "--charge" in args:
			n.charge = 1.0
	if "--hide-items" in args:
		main.items_root.visible = false
	_measuring = true
	_measure_end = Time.get_ticks_msec() + int(MEASURE * (2.0 if _opt("--stir", 0) > 0 else 1.0) * 1000.0)
	_stir_at = Time.get_ticks_msec()


func _dump(bodies: Array) -> void:
	var rows: Array = []
	for n in bodies:
		rows.append([n.linear_velocity.length(), n])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in mini(8, rows.size()):
		var it: Item = rows[i][1]
		print("  fast: %s at %s vel %s spin %.1f sleeping %s freeze %s" % [it.def.get("id", "?"), it.global_position.round(), it.linear_velocity.round(), it.angular_velocity, it.sleeping, it.freeze])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1].global_position.y < b[1].global_position.y)
	for i in mini(4, rows.size()):
		var it: Item = rows[i][1]
		print("  high: %s at %s vel %s sleeping %s" % [it.def.get("id", "?"), it.global_position.round(), it.linear_velocity.round(), it.sleeping])


func _report() -> void:
	frame_ms.sort()
	var avg := func(a: Array) -> float:
		var t := 0.0
		for v in a:
			t += v
		return t / maxf(1.0, a.size())
	var bodies := main.get_tree().get_nodes_in_group("items")
	var asleep := 0
	var top_speed := 0.0
	var speed_sum := 0.0
	for n in bodies:
		if n.sleeping:
			asleep += 1
		else:
			var sp: float = n.linear_velocity.length() + absf(n.angular_velocity) * 20.0
			top_speed = maxf(top_speed, sp)
			speed_sum += sp
	if "--dump" in args:
		_dump(bodies)
	print("perf-scale %s [%s]: %d bodies (%d asleep; awake avg %.1f, top %.1f px/s), %d pairs | frame avg %.1f ms, p95 %.1f ms | process %.1f ms | physics %.1f ms" % [
		" ".join(args), main.setting(), bodies.size(), asleep, speed_sum / maxf(1.0, bodies.size() - asleep), top_speed,
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		avg.call(frame_ms), frame_ms[int(frame_ms.size() * 0.95)], avg.call(proc_ms), avg.call(phys_ms)])


func _process(_d: float) -> bool:
	f += 1
	if f < 5:
		return false
	if f == 5:
		_setup()
	var tick := Engine.get_physics_frames()
	if _measure_from == 0:
		if tick >= _next_row:
			_next_row = tick + ROW_EVERY
			if _headroom() or _waited >= WAIT_MAX:
				_waited = 0
				_row()
			else:
				_waited += ROW_EVERY
			if _spawned >= _n and _coins_spawned >= _coins and _debris_spawned >= _debris:
				_measure_from = tick + SETTLE
		return false
	if not _measuring:
		if tick >= _measure_from:
			_start_measuring()
		return false
	if "--charge" in args:
		for n in main.get_tree().get_nodes_in_group("items"):
			if n.conductive:
				n.charge = maxf(n.charge, 0.9)
	if _opt("--stir", 0) > 0 and Time.get_ticks_msec() >= _stir_at:
		_stir_at = Time.get_ticks_msec() + _opt("--stir", 0)
		var all := main.get_tree().get_nodes_in_group("items")
		var it: Item = all[(f * 7919) % all.size()]
		it.apply_central_impulse(Vector2(randf_range(-0.6, 0.6), -1.0) * it.mass * 420.0)
	var now := Time.get_ticks_usec()
	if _last > 0:
		frame_ms.append((now - _last) / 1000.0)
	_last = now
	proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if Time.get_ticks_msec() >= _measure_end:
		_report()
		return true
	return false
