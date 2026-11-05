extends SceneTree
## The four books at home, open: the ledger, the rune tablet (both faces: the runes, and the
## element circle), the bestiary (an attack mid-swing) and the map. Everything found (on the
## test save) except a few, to show both. Saves res://shots/codex_*.png. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/codex_shots.gd

var main: Node
var f := 0


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _know_all() -> void:
	var s: SaveData = main.save
	var skip := ["paragon", "mimic", "Errata", "Ink Margin", "frost+rot", "rot+venom"]
	for id in ItemDefs.DEFS:
		if not id in skip:
			s.discover("items", id)
	for id in ItemDefs.UPGRADES:
		s.discover("items", id)
	for m in ItemDefs.MODIFIERS:
		if not m in skip:
			s.discover("modifiers", m)
	for id in EnemyDefs.ENEMIES:
		if not EnemyDefs.ENEMIES[id].name in skip:
			s.discover("foes", EnemyDefs.ENEMIES[id].name)  # (foes are known by name)
	s.discover("foes", EnemyDefs.WARDEN.name)
	for nm in Codex._place_names():
		if not nm in skip:
			s.discover("places", nm)
	for k in Main.REACTIONS:
		if not k in skip:
			s.discover("reactions", k)


func _process(_d: float) -> bool:
	f += 1
	var c: Codex = main.codex
	match f:
		10:
			_know_all()
			main.hand.pinned = Vector2(1260, 700)
			c.selected = ["warhammer", "superheated", "The Sexton", "Molten Core"]
			c.open_tab(0)
		40:
			_shot("gear")
			c.open_tab(1)
		70:
			_shot("mods")
			c.tablet_face = 1
			c.selected[1] = "fire+frost"
		100:
			_shot("reactions")
			c.tablet_face = 0
			c.open_tab(2)
		120:
			c.attack_pick = 0
			c.play_attack("dig")  # (a field that walks across the screen)
		170:
			_shot("foes")
			c.open_tab(3)
		210:
			_shot("places")
			return true
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/codex_%s.png" % name)
