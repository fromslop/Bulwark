extends SceneTree
## Balance harness: the autopilot (tools/autoplay.gd's play) fights every enemy one at a
## time with the same plain kit, an iron kite shield and an iron longsword, and reports how
## long each took to kill and how much got through to the hand. Headless and fast.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tools/balance.gd -- [prestige] [hybrid]
## "hybrid": one iron buckler glued to an iron longsword, used for both blocking and swinging.

const TIMEOUT := 150.0

var main: Node
var f := 0
var queue: Array = []  # enemy ids still to fight
var prestige := 0
var shield: Item
var sword: Item
var foe: Enemy
var fight_t := 0.0
var taken := 0.0
var blows := 0
var braced := false
var swing_wait := 0.0
var results: Array = []
var was_winding := false
var hybrid := false


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_balance_save.txt"
	var args := OS.get_cmdline_user_args()
	prestige = int(args[0]) if not args.is_empty() else 0
	hybrid = args.size() > 1 and args[1] == "hybrid"
	for id in EnemyDefs.ENEMIES:
		if id != "Errata":  # a copy of whatever came before
			queue.append(id)
	queue.append("WARDEN")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _next_fight() -> void:
	main._clear_enemies()
	for n in main.get_tree().get_nodes_in_group("items"):
		n.queue_free()
	main.hand.reset_run()
	main.hand.upgrades["strength"] = 2
	main.hand.injury = 0.0
	if hybrid:
		sword = main._spawn(ItemDefs.make("longsword", "iron"), Vector2(640, 600))
		var b: Item = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(640, 560))
		sword.fuse(b)
		shield = sword  # the same thing does both jobs
	else:
		shield = main._spawn(ItemDefs.make("kite_shield", "iron"), Vector2(300, 600))
		sword = main._spawn(ItemDefs.make("longsword", "iron"), Vector2(1000, 600))
	var id: String = queue.pop_front()
	var d: Dictionary = EnemyDefs.WARDEN.duplicate(true) if id == "WARDEN" else EnemyDefs.scaled(id, prestige)
	if id == "WARDEN":
		d.prestige = prestige
	foe = Enemy.new()
	foe.setup(d, main.camera)
	main.world3d.add_child(foe)
	foe.strike.connect(main._resolve_attack.bind(foe))
	main.enemies.append(foe)
	main.enemy = foe
	main.state = main.State.COMBAT
	fight_t = 0.0
	taken = 0.0
	blows = 0


func _process(delta: float) -> bool:
	f += 1
	if f == 10:
		main.hand.hurt_taken.connect(func(a: float) -> void: taken += a)
		_next_fight()
	if f < 12:
		return false
	main.state = main.State.COMBAT  # never leave for the shop
	main.hand.injury = 0.0  # never die: we're measuring what gets through
	fight_t += delta
	var winding: bool = foe.state == "windup"
	if was_winding and not winding:
		blows += 1
	was_winding = winding
	if foe.state == "dead" or fight_t > TIMEOUT:
		results.append([foe.data.name, fight_t, taken, blows, foe.state == "dead"])
		if queue.is_empty():
			_report()
			return true
		_next_fight()
		return false
	_play(delta)
	return false


func _report() -> void:
	print("\n== prestige %d: %s ==" % [prestige, "iron buckler glued to an iron longsword" if hybrid else "iron kite shield + iron longsword"])
	print("%-16s %8s %8s %6s %8s" % ["foe", "time s", "taken", "blows", "per blow"])
	for r in results:
		print("%-16s %8.1f %8.1f %6d %8.1f%s" % [r[0], r[1], r[2], r[3], r[2] / maxf(1.0, r[3]), "" if r[4] else "  (timed out)"])


# --- the autopilot's play (as tools/autoplay.gd) --------------------------------------

func _play(delta: float) -> void:
	var hand: Hand = main.hand
	if not _ok(shield) or not _ok(sword):
		return
	if foe.state == "windup" and not foe.current.is_empty():
		swing_wait = 0.0
		if _hold(shield):
			var cover := _cover_point(foe)
			var centre := shield.to_global(shield.center_of_mass)
			hand.pinned = cover - (centre - shield.to_global(hand.grab_local))
			if _left(foe) < 0.3 and not braced and centre.distance_to(cover) < 60.0:
				if not hybrid:
					hand._activate()  # (the hybrid can't brace: Space swings it)
				braced = true
		return
	braced = false
	var open: bool = foe.off_balance > 0.0 or foe.state in ["stagger", "broken"]
	if not open:
		if _hold(shield):
			var centre := shield.to_global(shield.center_of_mass)
			hand.pinned = Vector2(640, 400) - (centre - shield.to_global(hand.grab_local))
		return
	if _hold(sword):
		var head: Dictionary = {}
		for r in foe.regions():
			if r.id == "head":
				head = r
		if head.is_empty():
			return
		var aim: Vector2 = head.center + Vector2(-90.0 + sin(fight_t * 3.0) * 20.0, 70.0)
		hand.pinned = aim
		swing_wait -= delta
		if hand.position.distance_to(aim) < 40.0 and sword.cooldown <= 0.0 and swing_wait <= 0.0:
			hand._activate()
			swing_wait = 0.5


func _ok(it) -> bool:
	return it != null and is_instance_valid(it) and not it.is_queued_for_deletion()


func _hold(it: Item) -> bool:
	var hand: Hand = main.hand
	if hand.held == it:
		return true
	if hand.held:
		hand.release()
	var at := it.to_global(it.center_of_mass)
	hand.pinned = at
	if hand.position.distance_to(at) < 30.0:
		hand.grab(it, at)
		return true
	return false


func _cover_point(e: Enemy) -> Vector2:
	var zone: PackedVector2Array = main._zone_px(e.current)
	var dir: Vector2 = (e.current.dir as Vector2).normalized()
	var lanes := Lanes.build(zone, dir)
	var sum := Vector2.ZERO
	for lane in lanes:
		sum += lane[lane.size() / 2]
	var c := sum / maxf(1.0, lanes.size())
	if absf(dir.x) > 0.7:
		c.x = clampf(main.hand.position.x, 380.0, 900.0)
	elif absf(dir.y) > 0.7:
		c.y = clampf(main.hand.position.y, 300.0, 560.0)
	return c


## Seconds until the wind-up lands: brace about then, as a player would (a brace lasts 0.45 s).
func _left(e: Enemy) -> float:
	return (1.0 - e.progress) * float(e.current.get("windup", 1.0)) / maxf(0.1, e.cur_speed())
