extends SceneTree
## Renders the new work to res://shots/: home, the hand's gestures in every design, each
## enemy character, a duo fight, the codex, and the post-boss shop with its door.
## Needs a window. Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/review_shots.gd

var main: Node
var f := 0
var steps: Array = []
var i := 0
var ghosts: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		[func() -> void:
			main.hand.pinned = Vector2(640, 500)
			var sw: Item = main._spawn(ItemDefs.make("longsword", "steel", ["electrified"]), Vector2(110, 320))
			main._slot_item(sw, 1)
			var sh: Item = main._spawn(ItemDefs.make("kite_shield", "iron"), Vector2(950, 330))
			main._slot_item(sh, 4)
			, "home"],
		[func() -> void: main.hand.pinned = Vector2(540, 650), "home_point"],
		[func() -> void: _gestures("Gauntlet"), "hand_gauntlet"],
		[func() -> void: _gestures("Pixel Hand"), "hand_pixel"],
		[func() -> void: _gestures("Bone"), "hand_bone"],
		[func() -> void: _gestures("Shadow Puppet"), "hand_puppet"],
		[func() -> void:
			_end_gestures()
			main.codex.toggle(), "codex_gear"],
		[func() -> void: main.codex.tab = 2, "codex_foes"],
		[func() -> void:
			main.codex.toggle()
			main._start_run()
			main.hand.pinned = Vector2(640, 600)
			, "fight"],
	]
	for id in EnemyDefs.ENEMIES:
		steps.append([func() -> void: _become(id), "char_" + id.to_lower().replace(" ", "_")])
	steps.append([func() -> void: _duo(), "duo"])
	steps.append([func() -> void: _swing(), "swing"])
	steps.append([func() -> void: _boss_shop(), "shop_door"])


func _gestures(design: String) -> void:
	main.hand.pinned = Vector2(640, 360)
	Looks.choice.hand = Looks.OPTIONS.hand.find(design)
	_end_gestures()
	var ghost := Node2D.new()
	main.add_child(ghost)
	ghosts.append(ghost)
	var x := 240.0
	for g in ["open", "point", "grip", "fist", "thumbs", "limp"]:
		var h := Hand.new()
		h.pinned = Vector2(x, 360)
		h.force_gesture = g
		h.z_index = 60
		h.set_process_unhandled_input(false)
		ghost.add_child(h)
		if g == "grip":
			h.injury = 30.0
		if g == "fist":
			h.injury = 60.0
			h.upgrades["strength"] = 1
		if g == "thumbs":
			h.ring_slots = 3
			h.wear_ring("ring_momentum")
			h.wear_ring("ring_fireward")
		if g == "limp":
			h.injury = 85.0
		x += 160.0
	main.hand.pinned = Vector2(-500, -500)


func _end_gestures() -> void:
	for g in ghosts:
		g.queue_free()
	ghosts.clear()
	Looks.choice.hand = 0
	main.hand.pinned = Vector2(640, 500)


func _become(id: String) -> void:
	Looks.choice.enemy = 0
	main._clear_enemies()
	var e := Enemy.new()
	e.setup(EnemyDefs.scaled(id, 0), main.camera)
	main.world3d.add_child(e)
	e.active = false
	main.enemies.append(e)
	main.enemy = e
	main.state = main.State.COMBAT
	main.hand.pinned = Vector2(640, 620)


func _duo() -> void:
	main._clear_enemies()
	for k in 2:
		var e := Enemy.new()
		e.setup(EnemyDefs.scaled(["Footman", "Duelist"][k], 1), main.camera)
		e.position.x = -0.6 + 1.2 * k
		e.scale = Vector3.ONE * 0.9
		main.world3d.add_child(e)
		e.active = false
		main.enemies.append(e)
		if k == 0:
			e._begin_attack("slash_low")
		else:
			e._begin_attack("lunge")
		e._timer = 0.3
	main.enemy = main.enemies[0]


func _swing() -> void:
	main._clear_enemies()
	_become("Knight")
	var sw: Item = main._spawn(ItemDefs.make("falchion", "steel"), Vector2(640, 420))
	sw.freeze = false
	main.hand.pinned = Vector2(640, 440)
	main.hand.grab(sw, sw.global_position + Vector2(0, 40))
	sw.start_swing(1.0, 1.4)
	sw.angular_velocity = 18.0


func _boss_shop() -> void:
	main.hand.release()
	main.round_num = EnemyDefs.BOSS_STAGE
	main._open_shop()
	main.hand.pinned = Vector2(640, 600)


func _process(_d: float) -> bool:
	f += 1
	if f % 25 == 5 and i < steps.size():
		steps[i][0].call()
	if f % 25 == 24 and i < steps.size():
		root.get_texture().get_image().save_png("res://shots/%s.png" % steps[i][1])
		i += 1
		if i >= steps.size():
			return true
	return false
