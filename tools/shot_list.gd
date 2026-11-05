extends SceneTree
## Writes the performance shot list as a HeadnHands cue sheet (res://shot_list.txt): every
## clip each foe needs performed, one per line, `character | clip | what to perform`. It's
## the same list the recorder reads live from recording/hoardsman_cues.gd (Project Settings
## > headnhands/cues/provider); this copy is for reading at the desk. Built from EnemyDefs:
## re-run it after changing an enemy.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/shot_list.gd

const OUT := "res://shot_list.txt"


func _initialize() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(HoardsmanCues.sheet())
	f.close()
	print("shot list: %d cues -> %s" % [HoardsmanCues.build().size(), ProjectSettings.globalize_path(OUT)])
	quit(0)
