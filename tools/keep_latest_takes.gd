extends SceneTree
## Keeps the newest take of every clip, for every foe, and sends the older ones to the
## recycle bin (HHTakeStore.keep_only: the kept take is renamed to the clip's own name). The
## studio does the same as each new take is saved. Prints what it did.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --xr-mode off --path . -s res://tools/keep_latest_takes.gd


func _initialize() -> void:
	var root := HHTakeStore.takes_dir
	var kept := 0
	var before := 0
	for who in DirAccess.get_directories_at(root):
		var dir := root.path_join(who)
		var newest := {}  # clip -> [modified time, file]
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".res"):
				continue
			before += 1
			var base := f.get_basename()
			var tail := base.get_slice("_", base.get_slice_count("_") - 1)
			var clip := base.trim_suffix("_" + tail) if tail.is_valid_int() and base.contains("_") else base
			var t := FileAccess.get_modified_time(dir.path_join(f))
			if not newest.has(clip) or t > int(newest[clip][0]):
				newest[clip] = [t, f]
		for clip in newest:
			var now := HHTakeStore.keep_only(dir.path_join(str(newest[clip][1])), clip)
			kept += 1
			print("%s/%s: kept %s%s" % [who, clip, now.get_file(), "" if now.get_file() == str(newest[clip][1]) else " (was %s)" % newest[clip][1]])
	print("kept %d takes, sent %d to the recycle bin" % [kept, before - kept])
	quit()
