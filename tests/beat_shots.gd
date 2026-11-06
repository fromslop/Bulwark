extends SceneTree
## The slate through an attack take (the Knight's overhead-into-thrust combo), saved at
## each beat to res://shots/beat_<phase>.png, plus the room in the settle beat (the rest
## ghosts). Takes go to user://, never the project. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --xr-mode off --path . -s res://tests/beat_shots.gd
var studio
var f := 0
var shot := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://headnhands_workspace.cfg"))
	HHTakeStore.takes_dir = "user://beat_shot_takes"
	HHCharacters.animations_dir = "user://beat_shot_anims"
	studio = load("res://recording/studio/studio.tscn").instantiate()
	root.add_child(studio)


func _process(_d: float) -> bool:
	f += 1
	if f == 4:
		studio.select_character_id("knight")
	if f == 8:
		studio.pick_cue(studio.cues.find_custom(func(c: Dictionary) -> bool: return c.clip == "act_combo_overhead_l"))
	if f == 20:
		studio.slate.viewport.get_texture().get_image().save_png("res://shots/beat_plan.png")
		studio.toggle_recording()
	if studio.is_recording() and studio.guide:
		var ph: String = studio.guide.phase(studio.recording_time())
		var t: float = studio.recording_time()
		var key := ph
		if ph == "windup" and studio.guide.progress(t) < 0.6:
			key = ""
		if key != "" and not shot.has(key):
			shot[key] = true
			studio.slate.viewport.get_texture().get_image().save_png("res://shots/beat_%s.png" % key)
			if key == "settle":
				studio.head.position = Vector3(0, 1.65, 0)
				root.get_texture().get_image().save_png("res://shots/beat_room.png")
	if f > 60 and studio.is_idle() and shot.size() > 2:
		return true
	return f > 2400
