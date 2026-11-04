extends SceneTree
## Settings and their features: tiers, fixtures, floodwater, the hearth, darkness, the
## hidden lever. Run: Godot_console.exe --headless --fixed-fps 60 --path . -s res://tests/stage_test.gd

var main: Node
var frame := 0
var fails := PackedStringArray()
var hammer: Item
var wet_wood: Item
var wet_iron: Item
var hot_iron: Item
var rusty: Item


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


var ash: Item
var rot: Item
var sound: Item
var coins0 := 0
var chute_bits: Array = []
var strongbox: Item


## A three-cell scrap of one material, like the bits a broken item sheds.
func _scrap(mat: String, at: Vector2) -> Item:
	var d := ItemDefs.make("buckler", mat)
	d.kind = "debris"
	var cells := {}
	for x in 3:
		cells[Vector2i(x, 0)] = {"mat": mat, "hp": 5.0, "max": 5.0, "shade": 1.0}
	var it := Item.new()
	it._init_from(d, cells, Vector2(11, 4))
	it.position = at
	main.items_root.add_child(it)
	return it


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		10:
			main.enemy.active = false
			var order: Array = []
			for n in 5:
				order.append(Backdrop.for_round(n, main.rng, 0))
			_check(Backdrop.TIERS.early.has(order[0]) and Backdrop.TIERS.early.has(order[1]) and Backdrop.TIERS.middle.has(order[2])
				and Backdrop.TIERS.middle.has(order[3]) and Backdrop.TIERS.late.has(order[4]), "a run should go early, early, middle, middle, late (%s)" % [order])
			main._set_backdrop("Forge")
			main._add_features()
		12:
			for n in main.items_root.get_children():
				if n is Item and n.def.id == "smith_hammer":
					hammer = n
			_check(hammer != null and hammer.freeze, "the forge should hang a hammer on its rack")
			main.hand.grab(hammer, hammer.global_position)
			main.hand.release()
			main._clear_untaken_fixtures()
		14:
			var leftover := 0
			for n in main.items_root.get_children():
				if n.has_meta("fixture") and not n.has_meta("taken") and not n.is_queued_for_deletion():
					leftover += 1
			_check(is_instance_valid(hammer) and not hammer.is_queued_for_deletion(), "a fixture you took should stay yours")
			_check(leftover == 0, "fixtures nobody took should be cleared")
			hot_iron = main._spawn(ItemDefs.make("buckler", "iron", ["weightless"]), main.HEARTH.get_center())  # the hearth is up high: hover it there
			rusty = main._spawn(ItemDefs.make("reliquary", "steel", ["corrosive"]), Vector2(900, 300))
			rusty.freeze = true
		90:
			_check(hot_iron.heat > 0.3, "the forge hearth should heat what's in it (%.2f)" % hot_iron.heat)
			_check(rusty.health_ratio() < 0.995, "a corrosive steel reliquary should be eating itself (%.3f)" % rusty.health_ratio())
			var rusted := 0
			for c in rusty.cells:
				if rusty.cells[c].get("rust", 0.0) > 0.0:
					rusted += 1
			_check(rusted > 0, "its corroded cells should show rust")
			rusty.queue_free()
			main._set_backdrop("Cistern")
			wet_wood = main._spawn(ItemDefs.make("crate", "wood"), Vector2(400, 680))
			wet_wood.heat = 1.0
			wet_iron = main._spawn(ItemDefs.make("buckler", "iron"), Vector2(800, 680))
			wet_iron.heat = 1.0
		150:
			_check(not wet_wood.is_burning(), "floodwater should put a fire out")
			_check(wet_iron.has_mod("tempered"), "red-hot iron dropped in the floodwater should be quenched and tempered")
			main._set_backdrop("Catacombs")
			_check(main.styles.dark, "the catacombs should be dark")
			main._set_backdrop("Forge")
			main.backdrop.queue_free()
			main.backdrop = Backdrop.create("Forge", true)
			main.world3d.add_child(main.backdrop)
		152:
			var lp: Vector2 = main._lever_screen()
			_check(lp.is_finite() and main._try_lever(lp, 5.0), "punching the hidden lever should pull it")
			_check(main.secret_next, "pulling the lever should lead to the Hidden Vault")
			main._start_fight()
		154:
			_check(main.setting() == "Hidden Vault" and main.enemy.data.name == "Vault Warden", "the next fight should be the Hidden Vault and its Warden")
			_check(not main.styles.dark, "leaving the catacombs should bring the light back")
			# spent bits crumble after a fight; sound scrap stays
			ash = _scrap("wood", Vector2(300, 600))
			ash.charred = true
			rot = _scrap("iron", Vector2(360, 600))
			for c in rot.cells:
				rot.cells[c].rust = 1.0
			sound = _scrap("iron", Vector2(420, 600))
			main._crumble_dust()
			_check(ash.is_queued_for_deletion() and rot.is_queued_for_deletion(), "burnt and rusted-through scraps should crumble after a fight")
			_check(not sound.is_queued_for_deletion(), "sound scrap should stay")
			sound.queue_free()
			main._open_shop()
		156:
			# the shop's chute eats scraps and pays for metal
			coins0 = main.coin_total()
			for i in 12:
				var bit: Item = _scrap("steel", main.CHUTE.pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
				chute_bits.append(bit)
		160:
			var left := 0
			for b in chute_bits:
				if is_instance_valid(b) and not b.is_queued_for_deletion():
					left += 1
			_check(left == 0, "scraps that touch the chute should go down it (%d left)" % left)
		200:
			_check(main.coin_total() > coins0, "steel scrap down the chute should pay out coins (%d -> %d)" % [coins0, main.coin_total()])
			# rust eats a metal crate's lock: something corrosive against it opens it quickly
			strongbox = main._spawn(ItemDefs.make("strongbox", "iron"), Vector2(300, 660))
		230:
			main._spawn(ItemDefs.make("rock", "stone", ["corrosive"]), strongbox.global_position + Vector2(0, -40))
		230 + 60 * 9:
			_check(strongbox.def.get("opened", false), "a corrosive rock on an iron strongbox should rust its lock open within seconds")
			# mending and resin work on the whole piece, not the pixel they touch
			var blade: Item = main._spawn(ItemDefs.make("longsword", "copper"), Vector2(600, 500))
			blade.freeze = true
			for c in blade.cells:
				blade.damage_cell(c, blade.cells[c].max * 0.6, false)
			var before := blade.health_ratio()
			for i in 5:
				main.soak(blade, blade.global_position, "mending")
			_check(blade.health_ratio() > before + 0.4, "five drops of mending should mend most of a whole sword (%.2f -> %.2f)" % [before, blade.health_ratio()])
			var tough0 := blade.max_total
			for c in blade.cells:
				blade.damage_cell(c, blade.cells[c].max * 0.5, false)
			blade.add_mod("reinforced")
			_check(is_equal_approx(blade.max_total, tough0 * 2.0), "resin should double a whole piece's toughness")
			_check(blade.health_ratio() > 0.99, "resin should fill every crack (%.2f)" % blade.health_ratio())
			print("stage test: %d failures" % fails.size())
			for f in fails:
				print("  FAIL ", f)
			quit(1 if fails.size() > 0 else 0)
	return false
