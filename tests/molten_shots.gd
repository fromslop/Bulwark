extends SceneTree
## The fall to the Molten Core: the cracking floor, partway down through the earth, deep down
## by the fire, and the landing against the Smelter. Saves res://shots/molten_*.png. Window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/molten_shots.gd

var main: Node
var f := 0
var fall_f := -1


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/molten_%s.png" % name)


func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		main.enemy.active = false
		main.round_num = 1
		main._open_shop()
		main.hand.pinned = Vector2(1250, 700)
		var mix := [["buckler", "wood"], ["shortsword", "iron"], ["round_shield", "wood"], ["club", "wood"], ["longsword", "steel"], ["crate", "wood"]]
		for i in 18:
			var m: Array = mix[i % mix.size()]
			main._spawn(ItemDefs.make(m[0], m[1]), Vector2(80 + i * 64, 450))
		while main.pile_mass() < main.MOLTEN_MASS * 0.9:
			main._spawn(ItemDefs.make("tower_shield", "iron"), Vector2(randf_range(100, 1180), 300))
	if f == 70:
		_shot("cracks")
		main._spawn(ItemDefs.make("tower_shield", "steel"), Vector2(640, 300))
		main._spawn(ItemDefs.make("tower_shield", "steel"), Vector2(700, 300))
	if fall_f < 0 and main._falling:
		fall_f = f
	if fall_f > 0:
		var k := f - fall_f
		if k == 120:
			_shot("fall_earth")
		if k == 210:
			_shot("fall_deep")
		if k == 330:
			main.enemy.active = false
			for n in main.items_root.get_children():
				if n is Item and n.owned:
					n.queue_free()
		if k == 360:
			_shot("core")
			return true
	return false
