extends SceneTree
## Stress test: a pile of volatile crates, red-hot strongboxes and wood, left to run.
## Every chain reaction must end: explosions stop, fires burn out, the body count stays
## capped. Run: Godot_console.exe --headless --fixed-fps 60 --path . -s res://tests/chaos_test.gd

var main: Node
var frame := 0
var fails := PackedStringArray()
var peak := 0
var frames_over := 0  # frames spent above the cap (a one-frame spike from a blast is fine)
var booms_at_20s := 0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		main.enemy.active = false
		for i in 8:
			main._spawn(ItemDefs.make("crate", "wood", ["volatile"]), Vector2(120 + i * 140, 600))
		for i in 4:
			main._spawn(ItemDefs.make("crate", "wood"), Vector2(190 + i * 280, 450))
		main._spawn(ItemDefs.make("strongbox", "iron", ["superheated"]), Vector2(300, 300))
		main._spawn(ItemDefs.make("strongbox", "iron", ["superheated"]), Vector2(900, 300))
		main._spawn(ItemDefs.make("tower_shield", "wood", ["superheated"]), Vector2(640, 300))
	if frame > 10:
		var live := main.get_tree().get_nodes_in_group("items").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
		peak = maxi(peak, live)
		if live > main.BODY_CAP:
			frames_over += 1
	if frame == 1200:
		booms_at_20s = main.explosions
	if frame == 1800:
		var burning := 0
		var fused := 0
		for n in main.get_tree().get_nodes_in_group("items"):
			var it := n as Item
			if it.is_burning():
				burning += 1
			if it._fuse >= 0.0:
				fused += 1
		print("chaos: %d explosions in all, %d after 20s, peak %d bodies, %d burning and %d fused at 30s" % [main.explosions, main.explosions - booms_at_20s, peak, burning, fused])
		if main.explosions - booms_at_20s > 0:
			fails.append("explosions were still going after 20s")
		if burning > 0:
			fails.append("%d things still burning after 30s" % burning)
		print("chaos: %d frames over the body cap" % frames_over)
		if frames_over > 20:
			fails.append("body count stayed over the cap for %d frames" % frames_over)
		print("chaos test: %d failures" % fails.size())
		for f in fails:
			print("  FAIL ", f)
		quit(1 if fails.size() > 0 else 0)
	return false
