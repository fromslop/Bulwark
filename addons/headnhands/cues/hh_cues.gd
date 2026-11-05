@tool
# The cue list: every clip the project asks for (from its HHCueProvider),
# and which of those are still missing. The recorder steps through the
# missing ones, and a take recorded on a cue is saved and baked under the
# cue's clip name.
#
# Each cue: {"character", "clip", "kind", "what", "recorded"}.
class_name HHCues
extends RefCounted

## The provider in use. Set it from code to override Project Settings
## (tests do this).
static var provider: HHCueProvider


static func current_provider() -> HHCueProvider:
	if provider:
		return provider
	var script_path := HHSettings.get_value("headnhands/cues/provider")
	if not script_path.is_empty() and ResourceLoader.exists(script_path):
		var script := load(script_path) as Script
		var p = script.new() if script else null
		if p is HHCueProvider:
			return p
		push_error("%s doesn't extend HHCueProvider; using the cue sheet" % script_path)
	return HHCueSheet.new()


## Every cue (for one character, or all), each marked recorded or not.
static func all(character := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for c in current_provider().cues(character):
		var who := str(c.get("character", ""))
		var clip := str(c.get("clip", ""))
		if clip.is_empty() or (not character.is_empty() and who != character) or seen.has(who + "/" + clip):
			continue
		seen[who + "/" + clip] = true
		var row := c.duplicate()
		row.character = who
		row.clip = clip
		row.kind = str(c.get("kind", "cue"))
		row.what = str(c.get("what", ""))
		row.recorded = recorded(who, clip)
		out.append(row)
	return out


## The cues for a character that have no baked clip yet.
static func missing(character: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in all(character):
		if not c.recorded:
			out.append(c)
	return out


static func recorded(character: String, clip: String) -> bool:
	return ResourceLoader.exists(HHCharacters.animation_dir(character).path_join(clip + ".res"))
