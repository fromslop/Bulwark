extends SceneTree
## Every foe, for real: each one fights for a stretch at prestige 0 and 2 with a little gear on
## the floor and the hand wandering about, so every attack, feint, combo, chase and pan gets
## run through the real resolution path. Checks each foe actually strikes, feints where it
## should, and nothing errors. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/gauntlet_test.gd

const FIGHT := 25.0  # seconds per foe
var main: Node
var fails: Array = []
var queue: Array = []
var foe: Enemy
var t := 0.0
var strikes := 0
var feints := 0
var prestige := 0
var report: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for p in [0, 2]:
		for id in EnemyDefs.ENEMIES:
			queue.append([id, p])
	queue.append(["WARDEN", 1])
	main.call_deferred("_start_run")


func _next() -> void:
	if foe and is_instance_valid(foe):
		report.append("%-14s p%d  %2d strikes  %d feints" % [foe.data.name, prestige, strikes, feints])
		if strikes < 3:
			fails.append("%s (prestige %d) only struck %d times in %ds" % [foe.data.name, prestige, strikes, FIGHT])
		if foe.data.has("feint") and feints == 0 and strikes >= 16:  # (a feint is a 20-35% chance on attacks it picks itself)
			fails.append("%s never feinted in %d attacks" % [foe.data.name, strikes])
	if queue.is_empty():
		for line in report:
			print(line)
		print("gauntlet test: %d failures" % fails.size())
		for x in fails:
			print("  FAIL ", x)
		quit(1 if fails.size() > 0 else 0)
		return
	var q: Array = queue.pop_front()
	prestige = int(q[1])
	main._clear_enemies()
	for n in main.items_root.get_children():
		if n is Item:
			n.queue_free()
	main.hand.reset_run()
	main.hand.base_max_hp = 100000.0  # (the hand mustn't die: we're watching the foe)
	var d: Dictionary = EnemyDefs.scale_def(EnemyDefs.WARDEN.duplicate(true), prestige) if q[0] == "WARDEN" else EnemyDefs.scaled(q[0], prestige)
	d.hp = 1e6  # nor the foe: it has to keep attacking
	foe = Enemy.new()
	foe.setup(d, main.camera)
	main.world3d.add_child(foe)
	foe.strike.connect(func(atk: Dictionary) -> void:
		strikes += 1
		main._resolve_attack(atk, foe))
	foe.died.connect(main._on_enemy_died)
	foe.armor_fell.connect(main._on_armor_fell)
	foe.broke.connect(main._on_enemy_broke.bind(foe))
	main.enemies.append(foe)
	main.enemy = foe
	main.state = main.State.COMBAT
	for i in 4:
		main._spawn(ItemDefs.make(["round_shield", "kite_shield", "longsword", "crate"][i], "iron" if i < 3 else "wood"), Vector2(250 + i * 250, 500))
	t = 0.0
	strikes = 0
	feints = 0


func _process(delta: float) -> bool:
	if main.state == main.State.HOME or main.enemy == null:
		return false
	if foe == null or t >= FIGHT:
		_next()
		return false
	t += delta
	main.hand.pinned = Vector2(640 + 420 * sin(t * 0.7), 360 + 220 * sin(t * 1.3))
	main.hand.injury = 0.0
	if foe.current.has("feinted_from") and not foe.has_meta("seen_feint_%d" % foe.get_instance_id()):
		feints += 1
		foe.set_meta("seen_feint_%d" % foe.get_instance_id(), true)
	elif not foe.current.has("feinted_from"):
		foe.remove_meta("seen_feint_%d" % foe.get_instance_id())
	if int(t * 60.0) % 150 == 0:
		main.hand._activate()  # a punch now and then
	return false
