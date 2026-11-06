@tool
# Finds, loads and saves takes under the takes folder (Project Settings >
# headnhands/paths/takes_dir, res://takes by default). Sub-folders are fine,
# e.g. takes/demo/ or takes/scene_03/.
class_name HHTakeStore
extends RefCounted

## Where takes are read and written. Tests point this somewhere else so
## they never touch your real takes.
static var takes_dir := HHSettings.get_value("headnhands/paths/takes_dir")


# Every take file, sorted by path (timestamps sort oldest -> newest).
static func list(dir := "") -> PackedStringArray:
	if dir.is_empty():
		dir = takes_dir
	var out := PackedStringArray()
	_collect(dir, out)
	# (in natural order, so take _2 comes before _10: baking every take in this order leaves
	# each clip from its latest take)
	var sorted := Array(out)
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return PackedStringArray(sorted)


static func _collect(dir: String, out: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".res") or f.ends_with(".tres"):
			var path := dir.path_join(f)
			# Only count files that really are takes.
			if ResourceLoader.exists(path) and _is_take(path):
				out.append(path)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


static func _is_take(path: String) -> bool:
	var r := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	return r is HHTake


# The most recently recorded take (by its recording time, not its file name,
# since named takes no longer sort by date). Skips demo takes, discarded
# takes and raw punch-in sources.
static func newest() -> String:
	var best := ""
	var best_created := ""
	for p in list():
		if p.contains("/demo/") or p.contains("/_discarded/") or p.contains("/sources/"):
			continue
		var t := load_take(p)
		if t and not t.character_id.is_empty() and t.created >= best_created:
			best_created = t.created
			best = p
	return best


static func load_take(path: String) -> HHTake:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as HHTake


static func save(take: HHTake, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(take, path)


# A new timestamped path, e.g. res://takes/take_2026-09-29T14-05-33.res
static func new_path(sub_dir := "") -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var dir := takes_dir if sub_dir.is_empty() else takes_dir.path_join(sub_dir)
	var path := dir.path_join("take_%s.res" % stamp)
	var n := 2
	while FileAccess.file_exists(path):
		path = dir.path_join("take_%s_%d.res" % [stamp, n])
		n += 1
	return path


## Keeps only one take of a clip: `newest` (a take file in the folder) stays, every other
## take of the same clip there (<clip>.res, <clip>_2.res...) goes to the system's recycle
## bin, and the one kept is renamed to <clip>.res, so the next take is <clip>_2 and the
## numbers say which is newest again. Returns where the kept take is now. (If the bin can't
## take a file, it's left where it is and the kept one keeps its name.)
static func keep_only(newest: String, clip: String) -> String:
	var dir := newest.get_base_dir()
	var cleared := true
	for f in DirAccess.get_files_at(dir):
		if f == newest.get_file() or not (f.ends_with(".res") or f.ends_with(".tres")):
			continue
		var base := f.get_basename()
		if base == clip or (base.begins_with(clip + "_") and base.trim_prefix(clip + "_").is_valid_int()):
			if OS.move_to_trash(ProjectSettings.globalize_path(dir.path_join(f))) != OK:
				cleared = false
	var keep := dir.path_join(clip + "." + newest.get_extension())
	if keep == newest or not cleared:
		return newest
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(newest), ProjectSettings.globalize_path(keep)) != OK:
		return newest
	if ResourceLoader.has_cached(newest):
		var r: Resource = ResourceLoader.load(newest, "", ResourceLoader.CACHE_MODE_REUSE)
		r.take_over_path(keep)  # (a cached copy of the replaced take mustn't stand in for this one)
	return keep


# One line describing a bake report, for printing.
static func describe_report(r: Dictionary) -> String:
	var bits := PackedStringArray()
	bits.append("%.2f s" % r.get("length", 0.0))
	bits.append("%d fps" % int(r.get("fps", 0)))
	if r.get("loop", false):
		bits.append("loop at %.2f s" % r.get("loop_point", -1.0))
	if int(r.get("gaps_repaired", 0)) > 0:
		bits.append("%d gaps repaired" % r.gaps_repaired)
	for g in r.get("gaps_left", []):
		bits.append("UNREPAIRED GAP " + str(g))
	for n in r.get("notes", []):
		bits.append(str(n))
	return ", ".join(bits)
