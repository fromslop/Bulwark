extends SceneTree
## Renders the same busy moment once per design of each part (telegraph, hand, items,
## enemy), changing one part at a time, plus the dark stage modifier and a shop tooltip.
## PNGs go to res://shots/. Needs a real window (shaders don't compile headless).
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/style_shots.gd

var main: Node
var frame := 0
var queue: Array = []  # [label, Callable to set it up]
var wait := 0
var saved_choice := {}


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")  # the game starts at home (after _ready); the tests want a fight


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		saved_choice = Looks.choice.duplicate()
		main.enemy.active = false
		var c: Item = main._spawn(ItemDefs.make("crate", "wood"), Vector2(980, 640))
		c.heat = 1.0
		main._spawn(ItemDefs.make("kite_shield", "iron", ["electrified"]), Vector2(300, 600))
		main._spawn(ItemDefs.make("buckler", "steel", ["frosty", "spiked"]), Vector2(520, 650))
		main._spawn(ItemDefs.make("tower_shield", "wood", ["reinforced", "sticky"]), Vector2(140, 560))
		main._spawn(ItemDefs.make("mace", "copper"), Vector2(820, 600))
		main.hand.injury = 55.0
		main.hand.wear_ring("ring_levitation")
		main.hand.wear_ring("ring_fireward")
		main.hand.upgrades = {"strength": 1, "quick": 1}
		for part in Looks.OPTIONS:
			for i in Looks.OPTIONS[part].size():
				queue.append(["%s_%d_%s" % [part, i + 1, Looks.OPTIONS[part][i].to_lower().replace(" ", "_")], _pick.bind(part, i)])
		queue.append(["dark_mode", _dark])
	if frame == 90:
		main.enemy.active = true
		main.enemy._begin_attack()
	if frame == 130:
		main.enemy.active = false
		main.enemy.progress = 0.6
		main.hand.pinned = Vector2(700, 470)
	if frame >= 132:
		main.overlay.show_zone(main._zone_px(main.enemy.current), 0.6, (main.enemy.current.dir as Vector2).normalized())
	if frame >= 135 and not queue.is_empty():
		wait += 1
		if wait == 1:
			queue[0][1].call()
		elif wait == 8:
			root.get_texture().get_image().save_png("res://shots/%s.png" % queue[0][0])
			queue.pop_front()
			wait = 0
			if queue.is_empty():
				for part in saved_choice:
					main.looks.set_choice(part, saved_choice[part], false)
				main.styles.set_dark(false)
				return true
	return false


func _pick(part: String, i: int) -> void:
	main.styles.set_dark(false)
	for p in Looks.OPTIONS:
		main.looks.set_choice(p, 0, false)
	main.looks.set_choice(part, i, false)


func _dark() -> void:
	for p in Looks.OPTIONS:
		main.looks.set_choice(p, 0, false)
	main.styles.set_dark(true)
