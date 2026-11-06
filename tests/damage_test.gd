extends SceneTree
## Weapon damage comes from the weapon's pixels: how many it has left, each weighted by its
## material (wood least, prestigium most) and how whole it still is. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/damage_test.gd

var fails: Array = []
var made: Array = []


func _initialize() -> void:
	# a starter hits as it always has: swing_damage x its material's sharp x WEAPON_DAMAGE
	var club := _make("club", "wood")
	_check(is_equal_approx(club.hit_damage(), 12.0 * 0.6 * ItemDefs.WEAPON_DAMAGE), "a fresh wooden club should hit for %.2f, not %.2f" % [12.0 * 0.6 * ItemDefs.WEAPON_DAMAGE, club.hit_damage()])
	var greatsword := _make("greatsword", "iron")
	_check(is_equal_approx(greatsword.hit_damage(), 30.0 * ItemDefs.WEAPON_DAMAGE), "a fresh iron greatsword should hit for its listed damage (%.2f)" % greatsword.hit_damage())

	# bigger hits harder: the same weapon, more pixels
	var dagger := _make("dagger", "iron")
	_check(greatsword.hit_damage() > dagger.hit_damage() * 2.0, "a greatsword (%.1f) should hit far harder than a dagger (%.1f)" % [greatsword.hit_damage(), dagger.hit_damage()])
	var big := _make("falchion", "iron", ["large"])
	var plain := _make("falchion", "iron")
	_check(big.hit_damage() > plain.hit_damage() * 1.8, "a large falchion (%.1f) should hit about 2.25x a plain one (%.1f)" % [big.hit_damage(), plain.hit_damage()])

	# denser material hits harder, pixel for pixel: wood < copper < iron < steel < prestigium
	var last := 0.0
	for mat in ["wood", "copper", "iron", "steel", "prestigium"]:
		var it := _make("dagger", mat)
		_check(it.hit_damage() > last, "a %s dagger (%.2f) should outhit the material below it (%.2f)" % [mat, it.hit_damage(), last])
		last = it.hit_damage()

	# chipped pixels count for less, and broken-off ones not at all
	var sword := _make("longsword", "steel")
	var fresh := sword.hit_damage()
	for c in sword.cells:
		sword.cells[c].hp = sword.cells[c].max * 0.5
	_check(is_equal_approx(sword.hit_damage(), fresh * 0.5), "a longsword chipped to half its condition should hit for half (%.2f of %.2f)" % [sword.hit_damage(), fresh])
	var broken := _make("longsword", "steel")
	var keys: Array = broken.cells.keys()
	for i in keys.size() / 2:
		broken.cells.erase(keys[i])
	_check(broken.hit_damage() < fresh * 0.75, "a longsword that's lost half its pixels should hit much softer (%.2f of %.2f)" % [broken.hit_damage(), fresh])

	# Giant's Brew: more pixels, more damage, and a weight the hand can barely lift
	var brewed := _make("greatsword", "prestigium")
	var before := brewed.hit_damage()
	var mass_before := brewed.mass
	brewed.rescale(1.5)
	_check(brewed.hit_damage() > before * 1.8, "Giant's Brew should raise a prestigium greatsword's damage about 2.25x (%.1f -> %.1f)" % [before, brewed.hit_damage()])
	_check(brewed.mass > mass_before * 1.8, "and its weight with it (%.0f -> %.0f)" % [mass_before, brewed.mass])
	var lift := Hand.MAX_FORCE / float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_check(brewed.mass > lift * 0.9, "a brewed prestigium greatsword (mass %.0f) should be at the edge of what the hand can lift (%.0f)" % [brewed.mass, lift])
	var shrunk := _make("greatsword", "iron")
	shrunk.rescale(0.65)
	_check(shrunk.hit_damage() < greatsword.hit_damage() * 0.6, "Pixie Dust should cut a greatsword's damage (%.1f)" % shrunk.hit_damage())

	# the ledger's figure is a fresh one's
	_check(is_equal_approx(ItemDefs.fresh_damage("greatsword", "iron"), greatsword.hit_damage()), "the ledger's greatsword damage (%.2f) should match a fresh one (%.2f)" % [ItemDefs.fresh_damage("greatsword", "iron"), greatsword.hit_damage()])

	for it in made:
		it.free()
	if fails.is_empty():
		print("DAMAGE TEST PASSED")
	else:
		for m in fails:
			print("FAIL: ", m)
		print("DAMAGE TEST FAILED")
	quit(0 if fails.is_empty() else 1)


func _make(id: String, mat: String, mods: Array = []) -> Item:
	var it := Item.create(ItemDefs.make(id, mat, mods))  # (a wooden dagger isn't sold, but its pixels weigh what wood weighs)
	made.append(it)
	return it


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
