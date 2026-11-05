extends SceneTree
## Writes a HeadnHands character for every foe in the cue list (HoardsmanCues.foes()): recording/characters/<slug>/<slug>.tscn,
## each the shared enemy rig (recording/enemy_rig.gd) set to that foe. The slug is the
## foe's model name, the same one the cue list and the baked clips use. Re-run it after
## adding an enemy.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/make_recording_characters.gd

const DIR := "res://recording/characters"


func _initialize() -> void:
	var n := 0
	for pair in HoardsmanCues.foes():
		var id: String = pair[0]
		var slug := HoardsmanCues.slug(pair[1])
		var dir := DIR.path_join(slug)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var f := FileAccess.open(dir.path_join(slug + ".tscn"), FileAccess.WRITE)
		f.store_string("\n".join([
			'[gd_scene load_steps=2 format=3]',
			'',
			'[ext_resource type="Script" path="res://recording/enemy_rig.gd" id="1_rig"]',
			'',
			'[node name="%s" type="Node3D"]' % slug.to_pascal_case(),
			'script = ExtResource("1_rig")',
			'enemy_id = "%s"' % id,
			'faces_player = true',
			'']))
		f.close()
		n += 1
	print("recording characters: %d written to %s" % [n, ProjectSettings.globalize_path(DIR)])
	quit(0)

