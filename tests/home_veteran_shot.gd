extends SceneTree
## Home after a long career: runs tallied in chalk, a shelf of cups, stars on the pennant,
## bunting along the beam. Saves res://shots/home_veteran.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/home_veteran_shot.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		var s: SaveData = main.save
		s.stats.runs = 23
		s.stats.deaths = 17
		s.stats.kills = 112
		s.stats.bosses = 6
		s.prestige_best = 3
		s.found.guardians = ["The Astronomer", "Errata", "The Smelter"]
		s.trophies = [["Castellan", 0], ["Castellan", 0], ["Castellan", 1], ["The Sexton", 1], ["Castellan", 2], ["The Sexton", 3]]
		main._go_home()
		main.hand.pinned = Vector2(1250, 700)
	if f == 60:
		root.get_texture().get_image().save_png("res://shots/home_veteran.png")
		return true
	return false
