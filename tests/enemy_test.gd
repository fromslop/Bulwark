extends SceneTree
## The roster: every enemy builds and fights, attacks have poses, tracking zones follow the
## hand, weapon traits rub off on gear, characters react (riposte, bash, enrage, guard), the
## run's stages and prestige pick the right foes, and two can fight at once.
## Run: Godot_console.exe --headless --fixed-fps 60 --path . -s res://tests/enemy_test.gd

var main: Node
var frame := 0
var fails := PackedStringArray()


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


## Swap the fight's enemy for a given character, in the Character look.
func _become(id: String, prestige: int = 0) -> Enemy:
	Looks.choice.enemy = 0  # Character
	main._clear_enemies()
	var e := Enemy.new()
	e.setup(EnemyDefs.scaled(id, prestige), main.camera)
	main.world3d.add_child(e)
	e.strike.connect(main._resolve_attack.bind(e))
	e.died.connect(main._on_enemy_died)
	e.armor_fell.connect(main._on_armor_fell)
	e.broke.connect(main._on_enemy_broke.bind(e))
	e.active = false
	main.enemies.append(e)
	main.enemy = e
	main.state = main.State.COMBAT
	return e


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		10:
			_test_defs()
			_test_models()
		12:
			_test_tracking()
			_test_reactions()
		14:
			_test_traits()
		40:
			_test_duo()
		60:
			_test_run_structure()
			print("enemy test: %d failures" % fails.size())
			for f in fails:
				print("  FAIL ", f)
			quit(1 if fails.size() > 0 else 0)
	return false


func _test_defs() -> void:
	for id in EnemyDefs.ENEMIES:
		var d: Dictionary = EnemyDefs.ENEMIES[id]
		for a in d.attacks:
			_check(EnemyDefs.ATTACKS.has(a), "%s uses an attack that doesn't exist: %s" % [id, a])
			if EnemyDefs.ATTACKS.has(a):
				_check(Enemy.POSES.has(EnemyDefs.ATTACKS[a].pose), "attack %s has no pose %s" % [a, EnemyDefs.ATTACKS[a].pose])
		_check(d.has("bio") and d.has("weapon") and d.has("idle"), "%s should have a bio, a weapon and an idle" % id)
		if d.has("riposte"):
			_check(EnemyDefs.ATTACKS.has(d.riposte), "%s ripostes with an attack that doesn't exist" % id)
	for a in EnemyDefs.ATTACKS:
		var atk: Dictionary = EnemyDefs.ATTACKS[a]
		if atk.has("next"):
			_check(EnemyDefs.ATTACKS.has(atk.next), "%s chains into an attack that doesn't exist" % a)
		_check(atk.zone.size() >= 3, "%s needs a polygon zone" % a)


func _test_models() -> void:
	var ids: Array = EnemyDefs.ENEMIES.keys()
	for id in ids:
		var e := _become(id)
		_check(e._pauldrons.size() == 2, "%s should wear two pauldrons (got %d)" % [id, e._pauldrons.size()])
		_check(e.regions().size() >= 4, "%s should have hit regions" % id)
		var parts := 0
		for n in [e.torso, e.head, e.right_hand, e.left_hand]:
			parts += n.get_child_count()
		_check(parts >= 8, "%s's model looks too bare (%d parts)" % [id, parts])
		_check(e.model_loaded, "%s should wear its modelled body from %s" % [id, Enemy.model_path(e.data)])
		_check(e._mats.size() >= 4 and e._base_colors.size() == e._mats.size(), "%s's modelled body should have wound-tinted materials" % id)
		for pd in e._pauldrons:
			_check(pd.get_parent() == e.torso and pd.position.length() > 0.1, "%s's pauldrons should sit on the shoulders of the torso" % id)
		# the armour comes off the modelled body like it did the primitives: past the first break
		var breaks: Array = e.data.get("armor_breaks", Enemy.ARMOR_BREAKS)
		e.hp = e.max_hp * (1.0 - float(breaks[0]) - 0.02)
		e._update_wounds()
		_check(not e._pauldrons[0].visible and e._pauldrons[1].visible and e._exposed.size() == 1, "%s should lose one pauldron past its first break" % id)
		if id == "Footman":
			# force barely scratches plate early; corrosion eats it through
			var fresh := Enemy.new()
			fresh.setup(EnemyDefs.scaled("Knight", 0), main.camera)
			main.world3d.add_child(fresh)
			fresh.hp = fresh.max_hp * 0.55
			fresh._update_wounds()
			_check(fresh._pauldrons[0].visible, "45% of a foe's health beaten off shouldn't strip its plate yet")
			fresh.hp = fresh.max_hp
			for k in 3:
				fresh.corrode(0.12)
			_check(not fresh._pauldrons[0].visible, "three corrosive hits should rust a pauldron off a foe at full health")
			fresh.queue_free()
		_check(e.regions()[0].id == "exposed", "%s's lost pauldron should leave an exposed region" % id)
		e.rebuild_look()
		_check(e.model_loaded and not e._pauldrons[0].visible and e._exposed.size() == 1, "%s should keep its wounds across a rebuild" % id)
	var warden := Enemy.new()
	warden.setup(EnemyDefs.WARDEN.duplicate(true), main.camera)
	main.world3d.add_child(warden)
	_check(warden.model_loaded and warden._pauldrons.size() == 2, "the Vault Warden should have a modelled body")
	warden.queue_free()
	var c := _become("Castellan")
	_check(c.shield_arm != null, "the Castellan should carry a shield")
	var torso: Dictionary = c.regions().back()
	_check(torso.id == "torso" and torso.mult < 1.0 and torso.armor > 1.0, "the Castellan's guard should cover its torso")
	c.throw_off_balance(1.0)
	_check(not c.guard_up(), "a reeling Castellan should drop its guard")


func _test_tracking() -> void:
	var w := _become("Wraith")
	w.look_target = Vector2(0.2, 0.8)
	w._begin_attack("grasp")
	var c := Vector2.ZERO
	for p in w.current.zone:
		c += p
	c /= w.current.zone.size()
	_check(c.distance_to(Vector2(0.2, 0.8)) < 0.02, "a tracking attack should centre on the hand (%s)" % c)
	w.look_target = Vector2(0.0, 0.0)
	w._begin_attack("grasp")
	var lo := Vector2(1, 1)
	for p in w.current.zone:
		lo = lo.min(p)
	_check(lo.x >= 0.0 and lo.y >= 0.0, "a tracking zone should stay on screen")
	w.state = "idle"
	w.current = {}
	var pm := w.punch_mult()
	_check(pm == 0.0, "punches should pass through a Wraith")
	var plain := Item.create(ItemDefs.make("shortsword", "iron"))
	var zap := Item.create(ItemDefs.make("shortsword", "iron", ["electrified"]))
	_check(w.weapon_mult(plain) < 0.6 and w.weapon_mult(zap) > 1.4, "steel should barely touch a Wraith; lightning should hurt it")
	plain.free()
	zap.free()


func _test_reactions() -> void:
	var d := _become("Duelist")
	d.on_blocked(true)
	_check(d._queued == "riposte", "a Duelist should answer a clean block with a riposte")
	d._queued = ""
	d.on_blocked(false)
	_check(d._queued == "", "a sloppy block shouldn't draw a riposte")
	var c := _become("Castellan")
	for i in 3:
		c.on_blocked(true)
	_check(c._queued == "shield_bash", "three clean blocks should make the Castellan bash")
	c._queued = ""
	c._begin_attack("shield_bash")
	c._strike()
	_check(c._queued == "overhead_r", "the bash should chain into an overhead")
	var b := _become("Brute")
	var s0 := b.cur_speed()
	b.hp = b.max_hp * 0.2
	_check(b.cur_speed() > s0 * 1.2 and b.is_enraged(), "a bleeding Brute should speed up")
	var f := _become("Footman")
	f.throw_off_balance(1.0)
	_check(f.off_balance > 1.5, "a parried Footman should reel for longer than most")
	var z := _become("Zealot")
	z.heat_up(5.0)
	_check(z.burning_time == 0.0, "the Zealot shouldn't catch fire")
	var r := _become("Rusted")
	r.corrode(0.3)
	_check(r.corrosion > 0.5, "the Rusted's rotten plate should corrode twice as fast")
	var st := _become("Duelist")
	st.gum_up(2.0)
	st._begin_attack("lunge")
	_check(st._windup_total > EnemyDefs.ATTACKS.lunge.windup / st.cur_speed() * 1.3, "a gummed blade should wind up slower")


## Corrosive, burning and charged attacks rub off on whatever blocks them; magnetic gear
## catches a blade that passes just beside it.
func _test_traits() -> void:
	var r := _become("Rusted")
	for n in main.items_root.get_children():
		n.queue_free()
	var shield: Item = main._spawn(ItemDefs.make("round_shield", "iron"), Vector2(640, 0.81 * 720))
	shield.freeze = true
	shield.teleport(Vector2(640, 0.81 * 720))
	var wood: Item = main._spawn(ItemDefs.make("round_shield", "wood"), Vector2(640, 0.5 * 720))
	wood.freeze = true
	wood.teleport(Vector2(640, 0.5 * 720))
	await physics_frame
	await physics_frame
	main.hand.position = Vector2(-500, -500)
	main._resolve_attack(EnemyDefs.ATTACKS["drag_low"].duplicate(true), r)
	_check(shield.rusting > 0.9, "an iron shield that blocks the Rusted should start rusting (%.2f)" % shield.rusting)
	var z := _become("Zealot")
	main._resolve_attack(EnemyDefs.ATTACKS["brand"].duplicate(true), z)
	_check(wood.heat > 0.5, "a wooden shield that blocks the Zealot's brand should come away hot (%.2f)" % wood.heat)
	var l := _become("Lamplighter")
	main._resolve_attack(EnemyDefs.ATTACKS["brand"].duplicate(true), l)  # any attack: the shield is charged already? no: use spark
	var atk: Dictionary = EnemyDefs.ATTACKS["spark"].duplicate(true)
	atk.zone = [Vector2(0.47, 0.44), Vector2(0.53, 0.44), Vector2(0.53, 0.56), Vector2(0.47, 0.56)]
	main._resolve_attack(atk, l)
	_check(wood.charge > 0.9, "gear that blocks the Lamplighter should be charged (%.2f)" % wood.charge)
	# magnetic catch: a thin attack lane passing 15px beside a magnetic buckler still meets it
	var k := _become("Knight")
	var mag: Item = main._spawn(ItemDefs.make("buckler", "iron", ["magnetic"]), Vector2(300, 300))
	mag.freeze = true
	mag.teleport(Vector2(300, 300))
	await physics_frame
	var half_w: float = mag.origin.x
	var x0 := (300.0 + half_w + 12.0) / 1280.0
	var thin: Dictionary = EnemyDefs.ATTACKS["thrust"].duplicate(true)
	thin.zone = [Vector2(x0, 0.4), Vector2(x0 + 0.01, 0.4), Vector2(x0 + 0.01, 0.43), Vector2(x0, 0.43)]
	main.hand.injury = 0.0
	main.hand.position = Vector2(-500, -500)
	var hp0 := mag.health_ratio()
	main._resolve_attack(thin, k)
	_check(main.hand.injury < thin.damage * 0.5 and mag.health_ratio() < hp0, "a magnetic buckler should catch a blade passing just beside it (took %.1f)" % main.hand.injury)
	for it in [shield, wood, mag]:
		it.queue_free()


func _test_duo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var duos := 0
	for i in 60:
		if EnemyDefs.encounter(2, 1, rng).size() == 2:
			duos += 1
	_check(duos > 5 and duos < 55, "past the first boss, middle stages should sometimes be two enemies (%d of 60)" % duos)
	for i in 30:
		_check(EnemyDefs.encounter(2, 0, rng).size() == 1, "the first run through should never be a duo")
		_check(EnemyDefs.encounter(4, 3, rng).size() == 1, "a boss stage is never a duo")
	# a real duo fight: two rigs, both hittable, the fight only ends when both are down
	main.round_num = 2
	main.prestige = 1
	main._clear_enemies()
	main.enemies.clear()
	var defs := [EnemyDefs.scaled("Footman", 1), EnemyDefs.scaled("Footman", 1)]
	for i in 2:
		var e := Enemy.new()
		e.setup(defs[i], main.camera)
		e.position.x = -0.6 + 1.2 * i
		main.world3d.add_child(e)
		e.died.connect(main._on_enemy_died)
		e.active = false
		main.enemies.append(e)
	main.enemy = main.enemies[0]
	main.state = main.State.COMBAT
	var regs: Array = main._all_regions()
	_check(regs.size() >= 8, "two enemies should offer two sets of hit regions (%d)" % regs.size())
	var second: Enemy = main.enemies[1]
	var hp0: float = second.hp
	for r in regs:
		if r.who == second and r.id == "head":
			main._on_punched(r.center)
	_check(second.hp < hp0, "a punch at the second enemy's head should hurt the second enemy")
	main.enemies[0].take_hit(1e6, "torso", false)
	_check(main.state == main.State.COMBAT and main.enemy == second, "with one down, the fight goes on against the other")
	second.take_hit(1e6, "torso", false)
	_check(main.state == main.State.VICTORY, "with both down, the fight is won")
	main.state = main.State.COMBAT  # don't let the shop open under the next test
	main.round_num = 0
	main.prestige = 0


func _test_run_structure() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	_check(EnemyDefs.for_round(0, 0, rng).name == "Footman", "the first stage is always the Footman")
	_check(EnemyDefs.for_round(1, 0, rng).name == "Woodcutter", "the second stage is the Woodcutter")
	_check(is_equal_approx(EnemyDefs.for_round(1, 0, rng).hp, EnemyDefs.ENEMIES.Woodcutter.hp * 0.6), "the first run's second fight goes down quicker")
	_check(is_equal_approx(EnemyDefs.for_round(0, 0, rng).hp, EnemyDefs.ENEMIES.Footman.hp), "the first fight is unchanged")
	_check(EnemyDefs.for_round(4, 0, rng).get("boss", false), "the fifth stage is a boss")
	_check(EnemyDefs.for_round(4, 0, rng).name == "Castellan", "the first boss is the Castellan")
	var seen := {}
	for i in 200:
		seen[EnemyDefs.for_round(3, 0, rng).name] = true
		seen[EnemyDefs.for_round(2, 0, rng).name] = true
	_check(not seen.has("Headsman") and not seen.has("Lamplighter"), "rare enemies shouldn't show before their prestige")
	_check(seen.has("Wraith") and seen.has("Pyre Zealot") and seen.has("The Rusted") and seen.has("Duelist") and seen.has("Brute"), "the middle stages should draw from the whole tier (%s)" % [seen.keys()])
	var deep := {}
	for i in 200:
		deep[EnemyDefs.for_round(3, 3, rng).name] = true
		deep[EnemyDefs.for_round(4, 3, rng).name] = true
	_check(deep.has("Headsman") and deep.has("Lamplighter"), "deep runs should meet the rare enemies (%s)" % [deep.keys()])
	_check(deep.has("Hollow King"), "deep runs should meet the second boss")
	var p0 := EnemyDefs.scaled("Knight", 0)
	var p2 := EnemyDefs.scaled("Knight", 2)
	_check(p2.hp > p0.hp * 1.5 and p2.power > p0.power, "prestige should scale enemies up")
	# settings: rare places need a prestige
	var places := {}
	for i in 200:
		places[Backdrop.for_round(4, rng, 0)] = true
	_check(not places.has("Ossuary") and not places.has("Star Chamber"), "rare places shouldn't show before their prestige")
	for i in 200:
		places[Backdrop.for_round(4, rng, 3)] = true
	_check(places.has("Ossuary") and places.has("Star Chamber"), "deep runs should find the rare places (%s)" % [places.keys()])
	# gated gear
	ItemDefs.run_prestige = 0
	var early := {}
	for i in 300:
		early[ItemDefs.roll_offer(8, rng).id] = true
	_check(not early.has("sunderer") and not early.has("mirror_shield") and not early.has("aegis"), "prestige gear shouldn't be sold on the first run through")
	ItemDefs.run_prestige = 3
	var late := {}
	for i in 600:
		late[ItemDefs.roll_offer(8, rng).id] = true
	_check(late.has("sunderer") or late.has("mirror_shield"), "deep runs should sell prestige legendaries (%s)" % [late.keys()])
	ItemDefs.run_prestige = 0
