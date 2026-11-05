@tool
# A project's clip naming convention: <type>_<name>, where the type prefix
# tells the game how to use the clip. The defaults:
#   idle_  loops (idle variations)
#   act_   one-shot actions
#   cs_    cutscene performances
#   (no prefix) anything else
#
# Make your own: right-click in the FileSystem > New Resource > HHNamingRules,
# then point Project Settings > headnhands/naming/rules at it.
class_name HHNamingRules
extends Resource

## Type prefixes offered when naming a take (without the trailing "_").
@export var prefixes := PackedStringArray(["idle", "act", "cs"])
## What each prefix is for, shown next to it in the naming window.
@export var descriptions := PackedStringArray(["loops", "action", "cutscene"])
## Clips with these prefixes are set to loop seamlessly when named.
@export var loop_prefixes := PackedStringArray(["idle"])
## The type picked by default in the naming window ("" = no prefix).
@export var default_prefix := "act"

static var _cached: HHNamingRules
static var _cached_from := "-"


## The project's rules (from Project Settings), or the defaults.
static func current() -> HHNamingRules:
	var path := HHSettings.get_value("headnhands/naming/rules")
	if path != _cached_from or _cached == null:
		_cached_from = path
		_cached = null
		if not path.is_empty() and ResourceLoader.exists(path):
			_cached = load(path) as HHNamingRules
		if _cached == null:
			_cached = HHNamingRules.new()
	return _cached


## Every type, in order, ending with "" (no prefix).
func types() -> PackedStringArray:
	var out := prefixes.duplicate()
	out.append("")
	return out


## Labels for types(), e.g. "idle_  (loops)".
func type_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for i in prefixes.size():
		var what := descriptions[i] if i < descriptions.size() else ""
		out.append("%s_  (%s)" % [prefixes[i], what] if what else prefixes[i] + "_")
	out.append("(no prefix)")
	return out


## Should a clip with this name loop?
func loops(clip: String) -> bool:
	for p in loop_prefixes:
		if clip.begins_with(p + "_"):
			return true
	return false
