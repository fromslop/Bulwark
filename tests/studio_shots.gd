extends SceneTree
## The recording studio at the desk: each window as drawn (res://shots/studio_<panel>.png)
## and the room from the performer's mark (studio_room.png, studio_room_wide.png), with the
## Knight on stage and its thrust picked. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --xr-mode off --path . -s res://tests/studio_shots.gd -- [foe] [clip]

var studio
var f := 0
var cam: Camera3D
var foe := "knight"
var clip := "act_thrust"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		foe = args[0]
	if args.size() > 1:
		clip = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://headnhands_workspace.cfg"))  # default layout
	studio = load("res://recording/studio/studio.tscn").instantiate()
	root.add_child(studio)


func _process(_d: float) -> bool:
	f += 1
	if f == 4:
		studio.select_character_id(foe)
	if f == 8:
		var i: int = studio.cues.find_custom(func(c: Dictionary) -> bool: return c.clip == clip)
		studio.pick_cue(i)
		# the Assign window with a shared clip's choices open
		if not studio.shared_cues.is_empty():
			studio.assign_board._open = studio.shared_cues[0].clip
			studio.assign_board.refresh()
	if f == 40:
		for p in studio.workspace.panels:
			p.viewport.get_texture().get_image().save_png("res://shots/studio_%s.png" % str(p.name).to_snake_case())
		cam = studio.head
		cam.position = Vector3(0, 1.65, 0.0)
		cam.fov = 75.0
	if f == 48:
		root.get_texture().get_image().save_png("res://shots/studio_room.png")
		cam.position = Vector3(0, 1.9, 1.6)
		cam.fov = 85.0
	if f == 56:
		root.get_texture().get_image().save_png("res://shots/studio_room_wide.png")
		return true
	return false
