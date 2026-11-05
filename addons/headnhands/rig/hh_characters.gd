@tool
# Finds characters. A character is any folder <characters_dir>/<id>/ that
# contains <id>.tscn whose root has an HHRig script. Add a character by adding
# a folder; nothing else needs registering. The folder is set in Project
# Settings > headnhands/paths/characters_dir (res://characters by default).
class_name HHCharacters
extends RefCounted

## Where characters live. Tests (or a project at runtime) can point it elsewhere.
static var characters_dir := HHSettings.get_value("headnhands/paths/characters_dir")
## Where baked clips go. Tests point this somewhere else so they never
## touch your real animation libraries.
static var animations_dir := HHSettings.get_value("headnhands/paths/animations_dir")
## Maps an id to the folder holding its scene and clips. Identity by default;
## a project can map variants onto one model (e.g. "tinker2" -> "tinker").
static var model_of: Callable = func(id: String) -> String: return id


static func model(id: String) -> String:
	return model_of.call(id) if model_of.is_valid() else id


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(characters_dir):
		return out
	for dir in DirAccess.get_directories_at(characters_dir):
		if ResourceLoader.exists(scene_path(dir)):
			out.append(dir)
	return out


static func scene_path(id: String) -> String:
	var m := model(id)
	return "%s/%s/%s.tscn" % [characters_dir, m, m]


static func instantiate(id: String) -> HHRig:
	var scene := load(scene_path(id)) as PackedScene
	if scene == null:
		push_error("No character scene at %s" % scene_path(id))
		return null
	var node := scene.instantiate()
	if not node is HHRig:
		push_error("%s's root has no HHRig script" % scene_path(id))
		node.free()
		return null
	return node


# Where a character's baked clips live.
static func animation_dir(id: String) -> String:
	return "%s/%s" % [animations_dir, model(id)]


# The AnimationLibrary that collects all of a character's clips.
static func library_path(id: String) -> String:
	return "%s/%s_library.tres" % [animation_dir(id), model(id)]


static func display_name(id: String) -> String:
	var rig := instantiate(id)
	if rig == null:
		return id
	var n := rig.profile.display_name if rig.profile else id
	rig.free()
	return n
