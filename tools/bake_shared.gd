extends SceneTree
## Bakes takes for every foe that uses them, as the cue list's sharing and your assignments
## (the studio's Assign window, recording/assignments.cfg) say. Each foe gets the take through
## its own rig, so a Footman's cut fits the Knight's reach and sword.
##
##   with take paths   bakes each take for the foes that share it (the studio runs this in
##                     the background after a take)
##   with no paths     applies everything: each foe's own takes for itself, every shared
##                     clip for the foes that use it, and a clip a foe doesn't need removed
##                     (it keeps its procedural motion). The studio runs this after you
##                     change an assignment.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --xr-mode off --path . --script res://tools/bake_shared.gd -- [take paths...]


func _initialize() -> void:
	var paths := Array(OS.get_cmdline_user_args())
	var everything := paths.is_empty()
	if everything:
		paths = _all_takes()
	var rows := HoardsmanCues.build()
	var owner_of := {}
	for c in rows:
		owner_of["%s/%s" % [c.character, c.clip]] = c.owner
	var n := 0
	for p in paths:
		var path := ProjectSettings.localize_path(str(p))
		var take := HHTakeStore.load_take(path)
		if take == null or take.clip_name == "" or take.character_id == "":
			continue
		if everything and owner_of.get("%s/%s" % [take.character_id, take.clip_name], "") == take.character_id:
			HHBaker.bake_to_library(take, path, take.character_id)  # its own, for itself
			n += 1
		for who in HoardsmanCues.sharers(take.character_id, take.clip_name):
			var r := HHBaker.bake_to_library(take, path, who)
			print("SHARED %s/%s -> %s %s" % [take.character_id, take.clip_name, who, "ok" if r.ok else "FAILED"])
			n += 1
	if everything:
		for c in rows:
			if c.skipped and HHCues.recorded(str(c.character), str(c.clip)):
				HHBaker.remove_from_library(str(c.character), str(c.clip))
				print("REMOVED %s/%s (not needed)" % [c.character, c.clip])
	print("bake_shared: %d clips" % n)
	quit(0)


## Every take under the takes folder, newest last per clip (so the latest take wins).
static func _all_takes() -> Array:
	var out := []
	var root := HHTakeStore.takes_dir
	if not DirAccess.dir_exists_absolute(root):
		return out
	for who in DirAccess.get_directories_at(root):
		var files := Array(DirAccess.get_files_at(root.path_join(who))).filter(func(f: String) -> bool: return f.ends_with(".res"))
		files.sort_custom(func(a: String, b: String) -> bool: return FileAccess.get_modified_time(root.path_join(who).path_join(a)) < FileAccess.get_modified_time(root.path_join(who).path_join(b)))
		for f in files:
			out.append(root.path_join(who).path_join(f))
	return out
