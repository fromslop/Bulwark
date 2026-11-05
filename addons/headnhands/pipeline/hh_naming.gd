# Naming convention for takes and clips, and the "apply" step that renames
# freshly recorded takes (timestamped) to proper names.
#
# Convention:   <type>_<name>   e.g. idle_scan, act_weld, cs_intro_03
# The types (and which ones loop) come from the project's HHNamingRules.
#
# Files:  takes/<character>/<clip>.res        the raw take (source of truth)
#         animations/<character>/<clip>.res   the baked clip (+ <character>_library.tres)
#         takes/<character>/sources/...       raw punch-in recordings behind a comp
#         takes/_discarded/...                takes you threw away (recoverable)
class_name HHNaming
extends RefCounted

const DISCARD_DIR := "_discarded"


# "Weld Panel 2" + "act" -> "act_weld_panel_2"
static func make_clip_name(type: String, name: String) -> String:
	var n := name.strip_edges().to_lower()
	var clean := ""
	for c in n:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			clean += c
		elif not clean.ends_with("_"):
			clean += "_"
	clean = clean.strip_edges().trim_prefix("_").trim_suffix("_")
	if clean.is_empty():
		return ""
	# Don't double up if the name already starts with the type.
	if type.is_empty() or clean.begins_with(type + "_"):
		return clean
	return "%s_%s" % [type, clean]


# A take still has its automatic name if its file is take_<timestamp>... and
# it has no clip name. Raw punch-in sources (no character) are never listed.
static func is_unnamed(take: HHTake, path: String) -> bool:
	return not take.character_id.is_empty() and take.clip_name.strip_edges().is_empty() \
		and path.get_file().begins_with("take_")


static func unnamed_takes() -> PackedStringArray:
	var out := PackedStringArray()
	for p in HHTakeStore.list():
		if p.contains("/" + DISCARD_DIR + "/"):
			continue
		var t := HHTakeStore.load_take(p)
		if t and is_unnamed(t, p):
			out.append(p)
	return out


# Applies a list of decisions:
#   {"path": "res://takes/take_X.res", "action": "keep" | "discard",
#    "type": "idle", "name": "scan", "loop": true}
# Returns one printable line per entry.
static func apply(entries: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for e in entries:
		var path: String = e.get("path", "")
		var take := HHTakeStore.load_take(path)
		if take == null:
			lines.append("SKIP  %s (not found)" % path)
			continue
		var character := take.character_id
		if character.is_empty():
			lines.append("SKIP  %s (raw punch-in recording: it's renamed along with its comp)" % path.get_file())
			continue
		var old_clip := HHBaker.clip_name_for(take, path)

		if e.get("action", "keep") == "discard":
			var dest := _unique_path(HHTakeStore.takes_dir.path_join(DISCARD_DIR).path_join(path.get_file()))
			_move(path, dest)
			HHBaker.remove_from_library(character, old_clip)
			_retarget_references(path, dest)
			lines.append("DISCARDED %s -> %s" % [path.get_file(), dest])
			# A discarded punch-in comp takes its raw punch recording with it.
			if take.overdub_of.size() >= 2 and path.contains("_punch_") and FileAccess.file_exists(take.overdub_of[1]):
				var src := take.overdub_of[1]
				var src_dest := _unique_path(HHTakeStore.takes_dir.path_join(DISCARD_DIR).path_join(src.get_file()))
				_move(src, src_dest)
				_retarget_references(src, src_dest)
				lines.append("DISCARDED %s -> %s" % [src.get_file(), src_dest])
			continue

		var clip := make_clip_name(e.get("type", ""), e.get("name", ""))
		if clip.is_empty():
			lines.append("SKIP  %s (no name given)" % path.get_file())
			continue
		var char_dir := HHTakeStore.takes_dir.path_join(character)
		var new_path := _unique_path(char_dir.path_join(clip + ".res"), path)
		clip = new_path.get_file().get_basename()   # may have gained _2, _3...

		take.clip_name = clip
		if take.recipe == null:
			take.recipe = HHCleanupRecipe.new()
		take.recipe.loop = bool(e.get("loop", HHNamingRules.current().loops(clip)))
		# Keep the punch-in raw recording next to its comp, renamed to match.
		if take.overdub_of.size() >= 2 and path.contains("_punch_"):
			var src := take.overdub_of[1]
			if FileAccess.file_exists(src):
				var src_dest := _unique_path(char_dir.path_join("sources").path_join(clip + "_punch_source.res"))
				_move(src, src_dest)
				take.overdub_of[1] = src_dest
		HHTakeStore.save(take, new_path)
		if new_path != path:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_retarget_references(path, new_path)
		HHBaker.remove_from_library(character, old_clip)
		var r := HHBaker.bake_to_library(take, new_path, character)
		if r.ok:
			lines.append("NAMED %s -> %s/%s%s" % [path.get_file(), character, clip, "  (loops)" if take.recipe.loop else ""])
		else:
			lines.append("FAIL  baking %s: %s" % [clip, str(r.report.get("notes", []))])
	return lines


# Picks `path`, or path_2, path_3... if taken (ignoring `allow`, the file
# being renamed, so renaming a take to its own name is fine).
static func _unique_path(path: String, allow := "") -> String:
	var base := path.get_basename()
	var candidate := path
	var n := 2
	while FileAccess.file_exists(candidate) and candidate != allow:
		candidate = "%s_%d.res" % [base, n]
		n += 1
	return candidate


static func _move(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to.get_base_dir()))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


# Other takes remember which takes they were recorded against (play-along,
# punch-in); keep those links pointing at the renamed files.
static func _retarget_references(old_path: String, new_path: String) -> void:
	for p in HHTakeStore.list():
		var t := HHTakeStore.load_take(p)
		if t == null or not t.overdub_of.has(old_path):
			continue
		var refs := t.overdub_of
		refs[refs.find(old_path)] = new_path
		t.overdub_of = refs
		HHTakeStore.save(t, p)
