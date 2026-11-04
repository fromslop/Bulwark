extends SceneTree
## Breaking your own crates open: a heavy steel swing bursts wood, metal holds out against
## swings, and rust, prestigium or a blast gets through anything. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/smash_test.gd
## (tests/smash_probe.gd swings real weapons at real crates and prints how many it takes.)

var main: Node
var f := 0
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _hits(weapon: Array, crate: Array, n: int) -> bool:
	var w: Item = main._spawn(ItemDefs.make(weapon[0], weapon[1], weapon.slice(2)), Vector2(300, 300))
	var c: Item = main._spawn(ItemDefs.make(crate[0], crate[1]), Vector2(700, 300))
	for i in n:
		c.smash(c.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), w)
	var opened: bool = c.def.get("opened", false)
	w.queue_free()
	c.queue_free()
	return opened


func _process(_d: float) -> bool:
	f += 1
	if f != 10:
		return false
	_check(_hits(["warhammer", "steel"], ["crate", "wood"], 3), "three steel warhammer swings should burst a wooden crate")
	_check(not _hits(["shortsword", "iron"], ["crate", "wood"], 2), "two shortsword swings shouldn't be enough for a wooden crate")
	_check(not _hits(["club", "wood"], ["crate", "wood"], 4), "a wooden club shouldn't make short work of a crate")
	_check(not _hits(["warhammer", "steel"], ["strongbox", "iron"], 4), "a strongbox should hold out against a few steel swings")
	_check(not _hits(["greatsword", "steel"], ["reliquary", "steel"], 10), "a steel reliquary should shrug off steel swings")
	_check(_hits(["greatsword", "prestigium"], ["reliquary", "steel"], 7), "a prestigium greatsword should break a reliquary open")
	_check(_hits(["shortsword", "iron", "corrosive"], ["reliquary", "steel"], 3), "a corrosive blade should eat a reliquary's lock in three hits")
	var rel: Item = main._spawn(ItemDefs.make("reliquary", "steel"), Vector2(900, 300))
	main.on_explosion(rel.global_position + Vector2(25, 0), 110.0, 1.0, null)
	_check(rel.def.get("opened", false), "a blast right by a reliquary should blow its lock")
	var far: Item = main._spawn(ItemDefs.make("reliquary", "steel"), Vector2(200, 300))
	main.on_explosion(far.global_position + Vector2(105, 0), 110.0, 1.0, null)
	_check(not far.def.get("opened", false), "a blast at the edge of its reach shouldn't open a reliquary")
	print("smash test: %d failures" % fails.size())
	for x in fails:
		print("  FAIL ", x)
	quit(1 if fails.size() > 0 else 0)
	return false
