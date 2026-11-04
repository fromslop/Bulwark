extends SceneTree
## How many full-strength slashes until an item stops protecting you (more than half the
## hit gets through). Tests a wooden round shield, then a copper shortsword. Run headless.
var main: Node
var f := 0
var specs := [["round_shield", "wood"], ["shortsword", "copper"]]
var it: Item
func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight
func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.active = false
		main.enemy.max_hp = 1e9
		main.enemy.hp = 1e9
		for n in main.items_root.get_children():
			n.queue_free()
	if f >= 12 and (f - 12) % 10 == 0:
		if specs.is_empty():
			return true
		var spec: Array = specs.pop_front()
		it = main._spawn(ItemDefs.make(spec[0], spec[1]), Vector2(640, 0.27 * 720))
		it.freeze = true
		it.set_meta("spec", spec)
	if f >= 12 and (f - 12) % 10 == 3 and is_instance_valid(it):
		it.teleport(Vector2(640, 0.27 * 720))
		if spec_name() == "shortsword":
			it.rotation = PI / 2  # held flat across the slash
			PhysicsServer2D.body_set_state(it.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, it.global_transform)
	if f >= 12 and (f - 12) % 10 == 6 and is_instance_valid(it):
		var n := 0
		var took := 0.0
		while took < 14.0 and n < 80:
			main.hand.injury = 0.0
			main.hand.position = Vector2(-500, -500)
			main._resolve_attack(EnemyDefs.ATTACKS["slash_high_r"].duplicate())
			took = main.hand.injury
			n += 1
		print("  %s %s protects for %d slashes" % [it.get_meta("spec")[1], spec_name(), n])
		it.queue_free()
	return false
func spec_name() -> String:
	return it.get_meta("spec")[0]
