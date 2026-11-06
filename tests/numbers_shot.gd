extends SceneTree
## Every stat as a number: the inspect view over an enemy, over a ring on cooldown, and the
## hand's stat strip after a few charms (haste and skin showing); then the same weapon fresh,
## grown with a Giant's Brew, and chipped, side by side in the shop. Saves res://shots/numbers_*.png.
## Needs a window. Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/numbers_shot.gd

var main: Node
var f := 0
var swords: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"  # never the player's real home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			main.enemy.active = false
			main.hand.ring_slots = 3
			main.hand.wear_ring("ring_momentum")
			main.hand.wear_ring("ring_tempo")
			main.hand.ring_cds[1] = 4.3
			main.hand.strength *= 1.25
			main.hand.swing_power *= 1.2
			main.hand.steadiness *= 0.6
			main.hand.haste *= 0.9
			main.hand.resilience *= 0.81
			main.hand.injury = 22.0
			main.enemy.hp *= 0.7
			main.hand.force_inspect = true
		60:
			for it in main.get_tree().get_nodes_in_group("items"):
				if not it in swords and it is Item:
					(it as Item).freeze = true
					(it as Item).global_position = Vector2(1240, 700)  # out from under the glass
			main.hand.pinned = main.camera.unproject_position(main.enemy.torso.global_position)
		80:
			_shot("enemy")
			for i in 3:
				var it: Item = main._spawn(ItemDefs.make("greatsword", "steel"), Vector2(250 + i * 330, 420))
				it.freeze = true
				it.owned = false
				swords.append(it)
			swords[1].rescale(1.5)  # a Giant's Brew
			var keys: Array = swords[2].cells.keys()
			for k in keys.size() / 3:
				swords[2].damage_cell(keys[k * 3], 1e6, false)  # a third of it chipped away
			for c in swords[2].cells:
				swords[2].cells[c].hp *= 0.6
			main.hand.pinned = Vector2(37, 227)  # over the second ring slot
		95:
			_shot("ring")
			main.hand.pinned = swords[0].global_position
		110:
			_shot("fresh")
			main.hand.pinned = swords[1].global_position
		125:
			_shot("brewed")
			main.hand.pinned = swords[2].global_position
		140:
			_shot("chipped")
			return true
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/numbers_%s.png" % name)
