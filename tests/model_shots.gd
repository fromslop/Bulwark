extends SceneTree
## Renders every character's modelled body with the world grade off, so the models can be
## judged as modelled (shape, colour, pauldrons) rather than through a setting's palette:
## res://shots/model_<slug>.png, plus model_wounded_<slug>.png with both pauldrons gone.
## Needs a window. Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/model_shots.gd

var main: Node
var f := 0
var steps: Array = []
var i := 0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var defs: Array = []
	for id in EnemyDefs.ENEMIES:
		defs.append(EnemyDefs.scaled(id, 0))
	defs.append(EnemyDefs.WARDEN.duplicate(true))
	for d in defs:
		var slug: String = str(d.name).to_lower().replace(" ", "_")
		steps.append([func() -> void: _show(d, false), "model_" + slug])
		steps.append([func() -> void: _show(d, true), "model_wounded_" + slug])


func _show(d: Dictionary, wounded: bool) -> void:
	if main.state != main.State.COMBAT:
		main._start_run()
	main.styles._world_rect.visible = false
	main.styles.set_dark(false)
	main.hand.pinned = Vector2(-500, -500)
	for it in main.items_root.get_children():
		it.queue_free()
	Looks.choice.enemy = 0
	main._clear_enemies()
	var e := Enemy.new()
	e.setup(d, main.camera)
	main.world3d.add_child(e)
	e.active = false
	main.enemies.append(e)
	main.enemy = e
	main.state = main.State.COMBAT
	if wounded:
		e.hp = e.max_hp * 0.25
		e._update_wounds()


func _process(_d: float) -> bool:
	f += 1
	if f % 20 == 5 and i < steps.size():
		steps[i][0].call()
	if f % 20 == 19 and i < steps.size():
		root.get_texture().get_image().save_png("res://shots/%s.png" % steps[i][1])
		i += 1
		if i >= steps.size():
			return true
	return false
