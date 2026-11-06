extends SceneTree
## Blocking: lanes, the check on what slips past, parries, shield wear by material, block
## shocks and the rare conditional modifiers. Headless; prints the numbers it tunes against.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/block_test.gd

var main: Node
var f := 0
var fails: Array = []
var started := false


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _process(_d: float) -> bool:
	f += 1
	if f == 5 and not started:
		started = true
		_run()
	return false


func _clear() -> void:
	for n in main.get_tree().get_nodes_in_group("items"):
		n.queue_free()
	await physics_frame
	await physics_frame


func _place(id: String, mat: String, at: Vector2, mods: Array = []) -> Item:
	var it: Item = main._spawn(ItemDefs.make(id, mat, mods), at)
	it.freeze = true
	it.teleport(at)
	return it


## Land an attack with the hand well out of the way; what the hand took, as a share of the blow.
func _land(atk_id: String) -> float:
	main.hand.injury = 0.0
	main.hand.position = Vector2(-500, -500)
	main.enemy.state = "idle"
	main.enemy.off_balance = 0.0
	var atk: Dictionary = EnemyDefs.ATTACKS[atk_id].duplicate()
	main._resolve_attack(atk)
	return main.hand.injury / float(atk.damage)


func _run() -> void:
	main.enemy.active = false
	main.hand.resilience = 1.0
	# --- lanes ----------------------------------------------------------------------
	var counts := {}
	for id in ["hew", "slash_high_r", "overhead_l", "maul_low_l", "ground_pound", "thrust", "cut_tl"]:
		var atk: Dictionary = EnemyDefs.ATTACKS[id]
		counts[id] = Lanes.build(main._zone_px(atk), (atk.dir as Vector2).normalized()).size()
	print("lanes: ", counts)
	_check(counts.hew == 3, "the Woodcutter's hew should be three lanes (%d)" % counts.hew)
	_check(counts.thrust >= 3 and counts.thrust <= 5, "a thrust should be a few points (%d)" % counts.thrust)
	_check(counts.maul_low_l <= Lanes.MAX, "no blow should have more than %d lanes" % Lanes.MAX)
	# --- the check: two lanes of three caught --------------------------------------
	await _clear()
	var hew_y: Array = []
	for lane in Lanes.build(main._zone_px(EnemyDefs.ATTACKS.hew), Vector2(-1, 0)):
		hew_y.append((lane[0] as Vector2).y)
	hew_y.sort()
	var top := _place("kite_shield", "iron", Vector2(640, hew_y[0]))
	top.rotation = PI * 0.5  # on its side: a long bar across the top two lanes only
	top.teleport(Vector2(640, (hew_y[0] + hew_y[1]) * 0.5))
	await physics_frame
	await physics_frame
	var two_of_three := _land("hew")
	print("hew, two lanes of three caught: hand took %.0f%%" % (two_of_three * 100.0))
	_check(two_of_three < 0.25 and two_of_three > 0.08, "catching two lanes of three should leave a glancing hit, not a third of it (%.2f)" % two_of_three)
	# --- shield wear by material --------------------------------------------------------
	var lasted := {}
	for mat in ["wood", "copper", "iron", "steel"]:
		await _clear()
		var s := _place("round_shield", mat, Vector2(640, hew_y[1]))
		await physics_frame
		await physics_frame
		var n := 0
		while n < 300:
			n += 1
			if not is_instance_valid(s) or _land("hew") > 0.12:
				break
			await physics_frame  # let the broken shape settle, and sweep the splinters away
			for d in main.get_tree().get_nodes_in_group("items"):
				if d != s and d.def.kind == "debris":
					d.queue_free()
		lasted[mat] = n
		print("  %s: %d hews, %s, %d cells left, %.0f%% condition" % [mat, n, "intact" if is_instance_valid(s) else "gone", s.cells.size() if is_instance_valid(s) else 0, s.health_ratio() * 100.0 if is_instance_valid(s) else 0.0])
	print("hews a round shield holds (under 12%% getting through): ", lasted)
	_check(lasted.wood < lasted.copper and lasted.copper * 1.6 <= lasted.iron and lasted.iron * 2 <= lasted.steel,
		"each metal should outlast the one below it by far (%s)" % [lasted])
	# --- parry: a fast weapon through one lane parries, even with the rest open ------
	await _clear()
	var sword := _place("longsword", "steel", Vector2(640, hew_y[1]))
	sword.freeze = false
	sword.gravity_scale = 0.0
	sword.rotation = PI * 0.5
	sword.teleport(Vector2(640, hew_y[1]))
	await physics_frame
	sword.linear_velocity = Vector2(0, -2600)
	main.enemy.stagger_meter = 0.0
	var leak := _land("hew")
	print("a steel sword swung through the middle lane: hand took %.0f%%, enemy off balance %.2f" % [leak * 100.0, main.enemy.off_balance])
	_check(main.enemy.off_balance > 0.0, "a fast weapon catching one lane should still parry (throw the enemy off balance)")
	# a shield dragged fast is not a parry: brace it instead
	await _clear()
	var sh := _place("round_shield", "steel", Vector2(640, hew_y[1]))
	sh.freeze = false
	sh.gravity_scale = 0.0
	await physics_frame
	sh.linear_velocity = Vector2(0, -2600)
	_land("hew")
	_check(main.enemy.off_balance <= 0.0 or main.enemy.state != "stagger", "dragging a shield through a blow shouldn't parry")
	# --- an electrified shield shocks whoever strikes it ------------------------------
	var shock := {}
	for mods in [[], ["electrified"]]:
		await _clear()
		_place("round_shield", "iron", Vector2(640, hew_y[1]), mods)
		await physics_frame
		await physics_frame
		var hp0: float = main.enemy.hp
		_land("hew")
		shock[str(mods)] = hp0 - main.enemy.hp
	print("enemy hurt by blocking it: ", shock)
	_check(shock["[\"electrified\"]"] > shock["[]"] + 8.0, "an electrified shield should shock the attacker hard (%s)" % [shock])
	# --- rare modifiers --------------------------------------------------------------
	_check(ItemDefs.MODIFIERS.keys().filter(func(k: String) -> bool: return ItemDefs.MODIFIERS[k].get("rare", false)).size() >= 8, "there should be a set of rare modifiers")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rares := 0
	var on_shields := 0
	for i in 4000:
		for m in ItemDefs.roll_mods(rng, 0.5, 1, "longsword"):
			if ItemDefs.MODIFIERS[m].get("rare", false):
				rares += 1
		for m in ItemDefs.roll_mods(rng, 0.5, 1, "kite_shield"):
			if ItemDefs.MODIFIERS[m].get("rare", false):
				on_shields += 1
				_check("shield" in ItemDefs.MODIFIERS[m].get("kinds", ["weapon"]), "a shield rolled a weapon's rare modifier (%s)" % m)
	print("rare modifiers on 4000 longswords: %d" % rares)
	_check(rares > 80 and rares < 400, "rare modifiers should be rare but findable (%d / 4000)" % rares)
	_check(on_shields > 40, "shields should roll their own rare modifiers too (%d)" % on_shields)
	await _clear()
	var e: Enemy = main.enemy
	var head := {}
	for r in e.regions():
		if r.id == "head":
			head = r
	var plain := _place("longsword", "steel", Vector2(200, 200))
	var hunter := _place("longsword", "steel", Vector2(300, 200), ["headhunter"])
	_check(main._rare_mult(plain, e, head) == 1.0 and main._rare_mult(hunter, e, head) == 3.0, "Headhunter should triple head hits")
	e.hp = e.max_hp * 0.2
	var merciless := _place("longsword", "steel", Vector2(400, 200), ["merciless"])
	_check(main._rare_mult(merciless, e, head) == 3.0, "Merciless should triple hits on a foe below a third")
	e.hp = e.max_hp
	# Wisp Cannon: swung fast, it fires; the fire lands
	await _clear()
	var cannon := _place("longsword", "steel", Vector2(640, 500), ["wispfire"])
	cannon.freeze = false
	cannon.gravity_scale = 0.0
	await physics_frame
	var hp1: float = e.hp
	for i in 90:
		cannon.teleport(Vector2(640, 500))
		cannon.angular_velocity = 30.0
		await physics_frame
		await process_frame
	print("wisp cannon: enemy lost %.1f in 1.5 s of swinging" % (hp1 - e.hp))
	_check(hp1 - e.hp > 10.0, "a Wisp Cannon swung hard should burn the enemy (%.1f)" % (hp1 - e.hp))
	await _new_mods(e, head)
	await _reactions_and_props(e)
	await _secrets()
	await _fusion()
	await _grip_and_smelt()
	print("block test: %d failures" % fails.size())
	for x in fails:
		print("  FAIL ", x)
	quit(1 if fails.size() > 0 else 0)


## The juggling, build and shield modifiers, and the element combos.
func _new_mods(e: Enemy, head: Dictionary) -> void:
	await _clear()
	e.max_hp = 5000.0  # a foe that outlives the storms
	e.hp = e.max_hp
	e.off_balance = 0.0
	# Rested: four seconds out of hand is x3, spent on the hit
	var rested := _place("longsword", "steel", Vector2(200, 200), ["rested"])
	rested.set_meta("rest", 4.0)
	_check(is_equal_approx(main._rare_mult(rested, e, head), 3.0), "Rested: 4 s out of hand should be x3")
	_check(main._rare_mult(rested, e, head) == 1.0, "Rested: the bonus is spent on the first hit")
	# Baton: a hit marks the foe; another weapon cashes it in
	var baton := _place("longsword", "steel", Vector2(300, 200), ["baton"])
	var other := _place("longsword", "steel", Vector2(400, 200))
	main._rare_mult(baton, e, head)
	_check(is_equal_approx(main._rare_mult(other, e, head), 2.5), "Baton: the next weapon's hit should be x2.5")
	_check(main._rare_mult(other, e, head) == 1.0, "Baton: the mark is used up")
	# Kindred: three more steel pieces is x1.6 (and it isn't stacking with anything else here)
	await _clear()
	var kin := _place("longsword", "steel", Vector2(200, 200), ["kindred"])
	for i in 3:
		_place("buckler", "steel", Vector2(300 + i * 80, 200))
	_check(is_equal_approx(main._rare_mult(kin, e, head), 1.6), "Kindred: three other steel pieces should be x1.6 (%.2f)" % main._rare_mult(kin, e, head))
	# Mimic: picked up after a Headhunter, it's a Headhunter
	await _clear()
	var hunter := _place("longsword", "steel", Vector2(200, 200), ["headhunter"])
	var mimic := _place("longsword", "iron", Vector2(300, 200), ["mimic"])
	main.hand.held = hunter
	main._track_held()
	main.hand.held = mimic
	main._track_held()
	main.hand.held = null
	main._track_held()
	_check(main._has(mimic, "headhunter") and is_equal_approx(main._rare_mult(mimic, e, head), 3.0), "Mimic should take on the last weapon's Headhunter")
	# Lightning Rod: three charged pieces, three bolts
	await _clear()
	var rod := _place("longsword", "copper", Vector2(200, 200), ["lightning_rod"])
	for i in 3:
		var c := _place("buckler", "copper", Vector2(300 + i * 80, 200))
		c.charge = 1.0
	var hp0: float = e.hp
	main._rare_after_hit(rod, e, head, [])
	print("lightning rod with three charged pieces: %.1f" % (hp0 - e.hp))
	_check(hp0 - e.hp >= 30.0, "Lightning Rod should draw a bolt from each charged piece (%.1f)" % (hp0 - e.hp))
	# Stormcaller, superheated: a firestorm that keeps the foe burning
	await _clear()
	e.hp = e.max_hp
	e.burning_time = 0.0
	var caller := _place("longsword", "steel", Vector2(640, 400), ["stormcaller", "superheated"])
	caller.heat = 1.0
	hp0 = e.hp
	main._call_storm(caller, e, 20.0, Vector2(640, 400))
	_check(main._storms.size() == 1 and main._storms[0].kind == "fire", "a superheated Stormcaller should whip up a firestorm")
	for i in 60:
		await process_frame
	print("firestorm: %.1f damage in 1 s, burning %s" % [hp0 - e.hp, e.burning_time > 0.0])
	_check(e.burning_time > 0.0 or e.data.get("fireproof", false), "a firestorm should set the foe alight")
	_check(hp0 - e.hp > 40.0, "a firestorm should do real damage (%.1f)" % (hp0 - e.hp))
	# frosty: a blizzard slows
	var frost := _place("longsword", "steel", Vector2(640, 400), ["stormcaller", "frosty"])
	main._storms.clear()
	main._call_storm(frost, e, 20.0, Vector2(640, 400))
	await process_frame
	_check(main._storms.size() == 1 and main._storms[0].kind == "frost" and e.slow_time > 0.0, "a frosty Stormcaller should call a blizzard that slows")
	main._storms.clear()
	# Riposte Guard: what the shield stops is banked for the next weapon hit
	await _clear()
	main._counter_bank = 0.0
	var hew_y: float = (Lanes.build(main._zone_px(EnemyDefs.ATTACKS.hew), Vector2(-1, 0))[1][0] as Vector2).y
	_place("round_shield", "iron", Vector2(640, hew_y), ["counter"])
	await physics_frame
	await physics_frame
	_land("hew")
	print("riposte guard banked %.1f" % main._counter_bank)
	_check(main._counter_bank > 10.0, "Riposte Guard should bank what it stopped (%.1f)" % main._counter_bank)
	main._counter_bank = 0.0
	# Javelin: let go of it fast and it's in flight, able to hit
	await _clear()
	var jav := _place("longsword", "steel", Vector2(640, 400), ["javelin"])
	jav.freeze = false
	main.hand.held = jav
	jav.held = true
	jav.linear_velocity = Vector2(1500, -300)
	main.hand.release()
	_check(jav.swing_time > 0.5 and jav.has_meta("thrown"), "a Javelin let go fast should be thrown")


## Element reactions, and the stage props that feed them.
func _reactions_and_props(e: Enemy) -> void:
	await _clear()
	e.max_hp = 5000.0
	e.hp = e.max_hp
	e.off_balance = 0.0
	e.set_meta("marks", {})
	e.set_meta("react_ready", 0.0)
	var top := Vector2(640, 200)
	# fire marks; frost on top of it reacts
	main._apply_element(e, "fire", top)
	_check((e.get_meta("marks") as Dictionary).has("fire"), "fire should mark the foe")
	var hp0: float = e.hp
	main._apply_element(e, "frost", top)
	print("thermal shock: %.1f" % (hp0 - e.hp))
	_check(hp0 - e.hp >= 30.0, "fire then frost should set off a Thermal Shock (%.1f)" % (hp0 - e.hp))
	_check(not (e.get_meta("marks") as Dictionary).has("fire"), "a reaction spends the mark")
	# straight away again: on cooldown, so it just marks
	main._apply_element(e, "storm", top)
	_check((e.get_meta("marks") as Dictionary).has("storm"), "inside the cooldown a new element just marks")
	# superconduct leaves it vulnerable
	e.set_meta("marks", {"frost": main.clock + 5.0})
	e.set_meta("react_ready", 0.0)
	main._apply_element(e, "storm", top)
	_check(float(e.get_meta("vulnerable_until", 0.0)) > main.clock, "frost and storm should leave the foe vulnerable")
	# every pair has a reaction
	for a in ["fire", "frost", "storm", "venom", "rot"]:
		for b in ["fire", "frost", "storm", "venom", "rot"]:
			if a < b:
				_check(main.REACTIONS.has("%s+%s" % [a, b]), "no reaction for %s+%s" % [a, b])
	# props: a torch heats, a fungus poisons, the chandelier drops, the brick gives, the altar blesses
	main.props.setup("Corridor", 1)
	var torch: Dictionary = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "torch")[0]
	var blade := _place("longsword", "iron", torch.pos)
	for i in 30:
		main.props.feed([blade], 0.05)
	_check(blade.heat > 0.6, "a piece held in a torch should heat up (%.2f)" % blade.heat)
	hp0 = e.hp
	var chand: Dictionary = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "chandelier")[0]
	_check(main.props.punch(chand.pos) and hp0 - e.hp >= 30.0, "punching the chandelier's chain should drop it on the foe")
	main.props.setup("Catacombs", 1)
	var bloom: Dictionary = main.props.props[0]
	var dagger := _place("dagger", "steel", bloom.pos)
	for i in 30:
		main.props.feed([dagger], 0.05)
	_check(dagger.has_mod("poisoned"), "a piece held in the fungus should come away poisoned")
	main.props.props.clear()
	main.props._add("brick", Vector2(400, 150), 18.0)
	var coins0: int = main.coin_total()
	for i in 3:
		main.props.punch(Vector2(400, 150))
	await physics_frame
	await physics_frame
	_check(main.coin_total() > coins0, "three punches on a loose brick should spill its stash")
	main.props.setup("Crypt Chapel", 1)
	var altar: Dictionary = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "altar")[0]
	var offering := _place("longsword", "steel", altar.pos)
	offering.held = true
	main.hand.injury = 0.0
	for i in 40:
		main.props.feed([offering], 0.05)
	offering.held = false
	var rare: Array = offering.def.modifiers.filter(func(m: String) -> bool: return ItemDefs.MODIFIERS[m].get("rare", false))
	_check(rare.size() == 1 and main.hand.injury > 20.0, "the blood altar should take health and give a rare modifier (%s, %.0f)" % [rare, main.hand.injury])
	main.props.clear()


## Secret places: a met condition routes the next ordinary fight there, with its guardian.
func _secrets() -> void:
	for place in Secrets.STAGES:
		var st: Dictionary = Secrets.STAGES[place]
		_check(EnemyDefs.ENEMIES.has(st.foe), "%s's guardian %s should exist" % [place, st.foe])
		_check(Backdrop.LOOK.has(place) and Backdrop.ENV.has(place), "%s needs a look and lighting" % place)
		main.secret_stage = ""
		main.secret_next = false
		main.round_num = 1  # not a boss round
		main._unlock_secret(place)
		_check(main.secret_stage == place, "meeting the condition should unlock %s" % place)
		main._start_fight()
		await physics_frame
		_check(main.setting() == place and main.enemy.data.name == st.foe, "the next fight should be in %s against the %s (got %s, %s)" % [place, st.foe, main.setting(), main.enemy.data.name])
		_check(main.save.knows("places", place), "visiting %s should write it in the journal" % place)
	# a secret never takes a boss's place
	main.secret_stage = ""
	main._unlock_secret("Ink Margin")
	main.round_num = EnemyDefs.BOSS_STAGE
	main._start_fight()
	await physics_frame
	_check(main.setting() != "Ink Margin" and main.secret_stage == "Ink Margin", "a boss fight should keep the secret waiting")
	main.secret_stage = ""
	main.round_num = 1
	main.secret_stage = ""
	main.round_num = 1
	await _chains()
	# the Astronomer's unmoor lets go of the weight of everything you own
	await _clear()
	var floaty := _place("buckler", "iron", Vector2(640, 600))
	floaty.freeze = false
	_land("unmoor")
	_check(floaty.reverse_time > 1.0, "the Astronomer's unmoor should make your gear fall upward")


## Each secret place's chain, step by step.
func _chains() -> void:
	# Clockwork Orrery: two stars, then the one that waits, reached by something weightless
	main.secret_stage = ""
	main.props.props.clear()
	main._set_backdrop("Star Chamber")
	main._stars_caught = 0
	main.on_star_caught(Vector2(600, 100))
	main.on_star_caught(Vector2(600, 100))
	var still: Array = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "still_star")
	_check(still.size() == 1, "after two stars, a third should hang still")
	if still.size() == 1:
		var feather := _place("dagger", "steel", still[0].pos, ["weightless"])
		main.props.feed([feather], 0.05)
	_check(main.secret_stage == "Clockwork Orrery", "something weightless reaching the still star should open the Orrery")
	# Ink Margin: three different reactions in a fight leave a blot; punch it
	main.secret_stage = ""
	main.props.props.clear()
	main._fight_reactions.clear()
	var e: Enemy = main.enemy
	for pair in [["fire", "frost"], ["storm", "venom"], ["rot", "fire"]]:
		e.set_meta("marks", {pair[0]: main.clock + 5.0})
		e.set_meta("react_ready", 0.0)
		main._apply_element(e, pair[1], Vector2(640, 200))
	var blot: Array = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "ink_blot")
	_check(blot.size() == 1, "three different reactions should leave an ink blot")
	if blot.size() == 1:
		main.props.punch(blot[0].pos)
	_check(main.secret_stage == "Ink Margin", "punching the blot should open the Ink Margin")
	# the Errata is a misprint of the last ordinary foe
	main._last_foe_def = EnemyDefs.scaled("Duelist", 0)
	var errata: Dictionary = main._guardian("Ink Margin")
	_check(errata.model == "duelist" and errata.attacks == EnemyDefs.ENEMIES.Duelist.attacks, "the Errata should wear the last foe's body and moves")
	main.secret_stage = ""
	main.props.clear()


## Glue: a buckler glued to a sword is one thing that blocks like a buckler where the
## buckler is, swings near as fast as the sword, and comes apart cleanly.
func _fusion() -> void:
	await _clear()
	var sword := _place("longsword", "steel", Vector2(500, 300))
	var buckler := _place("buckler", "steel", Vector2(500, 260))
	sword.freeze = false
	buckler.freeze = false
	sword.gravity_scale = 0.0
	buckler.gravity_scale = 0.0
	await physics_frame
	var sword_mass: float = sword.mass
	var buckler_mass: float = buckler.mass
	var sword_cells: int = sword.cells.size()
	var buckler_cells: int = buckler.cells.size()
	var buckler_at: Vector2 = buckler.to_global(buckler.center_of_mass)
	var hp_before := 0.0
	for it in [sword, buckler]:
		for c in it.cells:
			hp_before += float(it.cells[c].hp)
	buckler.rotation = 0.6  # met at a slant: it used to warp and lose pixels
	_check(sword.fuse(buckler), "a sword and a buckler should fuse")
	await physics_frame
	_check(not is_instance_valid(buckler) or buckler.is_queued_for_deletion(), "the buckler should be taken in")
	var kept := 0
	var hp_after := 0.0
	for c in sword.cells:
		if sword.cells[c].mat != "glue":
			kept += 1
			hp_after += float(sword.cells[c].hp)
	_check(kept == sword_cells + buckler_cells, "gluing shouldn't lose a single pixel of either piece (%d of %d + %d)" % [kept, sword_cells, buckler_cells])
	_check(is_equal_approx(hp_after, hp_before), "gluing shouldn't wear either piece (%.1f -> %.1f hp)" % [hp_before, hp_after])
	_check(sword.def.kind == "weapon" and sword.has_part("shield"), "a sword with a buckler is still a weapon, with a shield on it")
	var on_buckler := 0.0
	for c in sword.cells:
		if int(sword.cells[c].get("part", 0)) == 1 and sword.cells[c].mat == "steel":
			on_buckler = sword.block_at(sword.to_global(sword.cell_pos(c)))  # a cell of the buckler itself
			break
	var on_blade := 0.0
	for c in sword.cells:
		if not sword.cells[c].has("part") or int(sword.cells[c].part) == 0:
			on_blade = sword.block_at(sword.to_global(sword.cell_pos(c)))
			break
	print("fused sword+buckler: blocks %.2f on the buckler, %.2f on the blade; mass %.0f (sword %.0f + buckler %.0f), swing mass %.0f" % [on_buckler, on_blade, sword.mass, sword_mass, buckler_mass, sword.swing_mass])
	_check(on_buckler > on_blade + 0.15, "the buckler's cells should block as a shield, the blade's as a weapon")
	_check(sword.swing_mass < sword_mass * 1.45, "glued on, a buckler should cost a swing less than half again (swing mass %.0f vs %.0f)" % [sword.swing_mass, sword_mass])
	# it saves and comes back fused
	var packed := SaveData.pack(sword)
	var back := Item.create(SaveData.unpack(packed))
	_check(back.cells.size() == sword.cells.size() and back.has_part("shield"), "a fused thing should come back from the save fused")
	back.free()
	# tear the buckler away whole: it falls off as a buckler again
	var torn := {}
	for c in sword.cells.keys():
		if int(sword.cells[c].get("part", 0)) == 1:
			torn[c] = sword.cells[c]
			sword.cells.erase(c)
	sword._spawn_piece(torn, Vector2.ZERO)
	await physics_frame
	var bucklers: Array = main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool:
		return n is Item and n.def.get("id", "") == "buckler" and not n.def.get("piece", false))
	_check(bucklers.size() == 1, "a buckler torn off whole should fall away as a buckler")
	# a rock glued to a club is a mace
	await _clear()
	var club := _place("club", "wood", Vector2(500, 300))
	var rock := _place("rock", "stone", Vector2(500, 250))
	club.freeze = false
	rock.freeze = false  # (frozen things, like shop stock, don't take glue)
	club.fuse(rock)
	print("club + rock heft: x%.2f" % club.heft())
	_check(club.heft() > 1.2, "a rock glued to a club should hit harder (x%.2f)" % club.heft())
	# glue only grabs with its patch: press a buckler's dry side to a held sword's tip and
	# nothing happens; press its glued side there and they fuse
	for glued_side in [false, true]:
		await _clear()
		var blade := _place("longsword", "iron", Vector2(640, 420))
		var bk := _place("buckler", "iron", Vector2(640, 200))
		blade.freeze = false
		bk.freeze = false
		blade.gravity_scale = 0.0
		bk.gravity_scale = 0.0
		await physics_frame
		var tip_c: Vector2i = blade.nearest_cell(blade.global_position + Vector2(0, -400))
		var tip := blade.to_global(blade.cell_pos(tip_c))
		var bottom_c: Vector2i = bk.nearest_cell(bk.global_position + Vector2(0, 400))
		var top_c: Vector2i = bk.nearest_cell(bk.global_position + Vector2(0, -400))
		bk.glue_patch(bk.to_global(bk.cell_pos(bottom_c if glued_side else top_c)), 1)
		if glued_side:
			_check(bk._glue > 0 and bk._glue <= 6, "a glue patch should be a few pixels (%d)" % bk._glue)
		# set the buckler's bottom on the sword's tip, pressing down a little
		var bottom := bk.to_global(bk.cell_pos(bottom_c))
		bk.teleport(bk.global_position + (tip - bottom) + Vector2(0, -2))
		blade.held = true
		for k in 20:
			if not is_instance_valid(bk) or bk.is_queued_for_deletion():
				break  # taken in
			bk.linear_velocity = Vector2(0, 60)
			blade.linear_velocity = Vector2.ZERO
			await physics_frame
		await physics_frame
		var took: bool = not is_instance_valid(bk) or bk.is_queued_for_deletion()
		if glued_side:
			_check(took, "pressing the glued patch to a held sword should fuse them")
			_check(not blade.has_mod("sticky") and blade._glue == 0, "the glue is spent once it's fused")
			_check(blade._components().size() == 1, "a fused thing should be one connected piece (glue seams bridge any gap)")
		else:
			_check(not took, "glue on the far side shouldn't grab")
		blade.held = false
	# a rolled sticky item comes with a small patch, not glue all over
	var rolled: Item = main._spawn(ItemDefs.make("round_shield", "wood", ["sticky"]), Vector2(300, 200))
	_check(rolled._glue > 0 and rolled._glue < rolled.cells.size() / 4, "a sticky item should have a small glued patch (%d of %d)" % [rolled._glue, rolled.cells.size()])


## A glued thing does what the part you hold does; the home hearth melts junk into a purse.
func _grip_and_smelt() -> void:
	await _clear()
	var sword := _place("longsword", "steel", Vector2(500, 300))
	var buckler := _place("buckler", "steel", Vector2(500, 260))
	sword.freeze = false
	buckler.freeze = false
	sword.gravity_scale = 0.0
	sword.fuse(buckler)
	await physics_frame
	var blade_c := Vector2i(9999, 9999)
	var shield_c := Vector2i(9999, 9999)
	for c in sword.cells:
		var part := int(sword.cells[c].get("part", 0))
		if part == 0 and sword.cells[c].mat == "steel" and blade_c.x == 9999:
			blade_c = c
		elif part == 1 and sword.cells[c].mat == "steel" and shield_c.x == 9999:
			shield_c = c
	var hand: Hand = main.hand
	hand.held = sword
	sword.held = true
	# held by the buckler: Space braces
	hand.grab_local = sword.cell_pos(shield_c)
	_check(hand.grip_kind() == "shield", "held by its buckler, a glued sword-and-buckler is a shield")
	sword.cooldown = 0.0
	hand._activate()
	_check(sword.brace_time > 0.0 and sword.swing_time <= 0.0, "Space on the buckler part should brace, not swing")
	# held by the blade: Space swings, with the longsword's numbers
	hand.grab_local = sword.cell_pos(blade_c)
	sword.cooldown = 0.0
	sword.brace_time = 0.0
	_check(hand.grip_kind() == "weapon", "held by its blade, it's a sword")
	hand._activate()
	_check(sword.swing_time > 0.0 and str(sword.swing_part.get("title", "")) == "Longsword", "Space on the sword part should swing it as a longsword")
	hand.held = null
	sword.held = false
	# the hearth: junk left in the fire melts down, and enough of it makes a coin
	await _clear()
	main.props.setup("Homestead", 0)
	var hearth: Dictionary = main.props.props.filter(func(pr: Dictionary) -> bool: return pr.kind == "hearth")[0]
	main.save.stats.smelt = 0.95
	var coins_before: int = main.coin_total()
	var junk: Item = main._spawn(ItemDefs.make("pauldron", "iron"), hearth.pos)
	for i in 30:
		main.props.feed([junk], 0.05)
	await physics_frame
	_check(not is_instance_valid(junk) or junk.is_queued_for_deletion(), "a pauldron left in the hearth should melt down")
	_check(main.coin_total() > coins_before, "melting enough junk should make a coin (%d -> %d)" % [coins_before, main.coin_total()])
	# wood thrown on the fire burns away and stokes it; wood that just rolls up to it is left be
	var resting: Item = main._spawn(ItemDefs.make("club", "wood"), hearth.pos)
	var thrown: Item = main._spawn(ItemDefs.make("club", "wood"), hearth.pos + Vector2(10, 0))
	thrown.set_meta("let_go_at", main.clock)
	main.backdrop.blaze = 0.0
	for i in 40:
		main.props.feed([resting, thrown], 0.05)
	await physics_frame
	_check(not is_instance_valid(thrown) or thrown.is_queued_for_deletion(), "a wooden club thrown in the hearth should burn away")
	_check(main.backdrop.blaze > 0.1, "wood on the fire should make it roar up (blaze %.2f)" % main.backdrop.blaze)
	_check(is_instance_valid(resting) and not resting.is_queued_for_deletion(), "a wooden club that only rolled up to the hearth should be left alone")
	resting.queue_free()
	main.props.clear()
