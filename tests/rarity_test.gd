extends SceneTree
## Shop odds over a run: early stock is plain, late stock turns rare.
## Run: Godot_console.exe --headless --path . -s res://tests/rarity_test.gd
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fails := PackedStringArray()
	var early_steel := 0
	var early_iron := 0
	var early_rare := 0
	for i in 400:
		var d := ItemDefs.roll_offer(0, rng)
		if d.material == "steel":
			early_steel += 1
		if d.material == "iron":
			early_iron += 1
		if d.rarity >= 2:
			early_rare += 1
	var late_legend := 0
	var late_steel := 0
	for i in 1000:
		var d := ItemDefs.roll_offer(8, rng)
		if d.rarity == 3:
			late_legend += 1
		if d.material == "steel":
			late_steel += 1
	print("rarity: round 1 -> steel %d iron %d rare+ %d / 400 | round 9 -> legendary %d steel %d / 1000" % [early_steel, early_iron, early_rare, late_legend, late_steel])
	if early_steel + early_iron + early_rare > 0:
		fails.append("the first shop should be all common wood, leather and copper")
	if late_legend < 3 or late_legend > 40 or late_steel < 150:
		fails.append("late shops should turn up steel, and legendaries only rarely (%d / 1000)" % late_legend)
	# prestigium: none before the wall, some past it; a legendary in it is ascended
	var prest := [0, 0]
	for p in 2:
		ItemDefs.run_prestige = 3 + p
		for i in 600:
			if ItemDefs.roll_offer(8, rng).material == "prestigium":
				prest[p] += 1
	ItemDefs.run_prestige = 0
	print("prestigium: prestige 3 -> %d, prestige 4 -> %d / 600" % prest)
	if prest[0] > 0 or prest[1] == 0:
		fails.append("prestigium should only turn up past prestige 3")
	var plain := ItemDefs.make("stormbrand", "steel")
	var risen := ItemDefs.make("stormbrand", "prestigium")
	if not risen.get("ascended", false) or risen.name != "Prestigium Stormbrand" or risen.swing_damage < plain.swing_damage * 1.9:
		fails.append("a prestigium Stormbrand should be ascended (%s, %.0f vs %.0f)" % [risen.name, risen.swing_damage, plain.swing_damage])
	var storm := ItemDefs.make("stormbrand", "steel")
	if storm.name != "Stormbrand" or not storm.modifiers.has("electrified"):
		fails.append("Stormbrand should carry its fixed enchantments")
	# several modifiers: rare, rarer past two, and likelier as the run prestiges
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 3
	var multi := [0, 0]
	var three := [0, 0]
	for p in 2:
		ItemDefs.run_prestige = p * 3
		for i in 20000:
			var n := ItemDefs.roll_mods(mrng, 1.0).size()
			if n >= 2:
				multi[p] += 1
			if n >= 3:
				three[p] += 1
	ItemDefs.run_prestige = 0
	print("mods: 2+ %d -> %d, 3+ %d -> %d / 20000 (prestige 0 -> 3)" % [multi[0], multi[1], three[0], three[1]])
	if multi[0] > 2000 or multi[0] == 0:
		fails.append("a second modifier should be rare but possible (%d / 20000)" % multi[0])
	if three[0] > multi[0] / 5 or three[1] == 0:
		fails.append("three or more modifiers should be exceptional but possible")
	if multi[1] < multi[0] * 2:
		fails.append("prestige should make extra modifiers likelier (%d -> %d)" % [multi[0], multi[1]])
	print("rarity test: %d failures" % fails.size())
	for f in fails:
		print("  FAIL ", f)
	quit(1 if fails.size() > 0 else 0)
