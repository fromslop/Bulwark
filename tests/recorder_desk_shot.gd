extends SceneTree
## The HeadnHands recorder at the desk (no headset) with a Hoardsman foe on the stage, driven
## by a scripted performer raising the weapon hand: res://shots/recorder_<foe>.png.
## Run: Godot_v4.7.2-stable_win64.exe --xr-mode off --path . -s res://tests/recorder_desk_shot.gd
var rec: HHRecorder
var f := 0
var cam: Camera3D
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	rec = load("res://addons/headnhands/recorder/hh_recorder.tscn").instantiate()
	root.add_child(rec)
func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		rec._select_character(rec.character_ids.find("knight"))
		cam = Camera3D.new()  # (no headset: look at the stage from where the performer stands)
		cam.position = Vector3(0, 1.6, 0.2)
		root.add_child(cam)
		cam.make_current()
	if f > 5 and f < 90:
		var fr := HHFrame.new()
		var u := clampf((f - 5) / 60.0, 0.0, 1.0)
		fr.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
		fr.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
		fr.right = Transform3D(Basis(Vector3.RIGHT, -0.6 * u), Vector3(0.22, 1.07, -0.22).lerp(Vector3(0.45, 1.9, -0.3), u))
		rec.character.drive(rec.character.view_frame(fr, rec.mirror_view), 1.0 / 60.0)
	if f == 90:
		root.get_texture().get_image().save_png("res://shots/recorder_knight.png")
		return true
	return false
