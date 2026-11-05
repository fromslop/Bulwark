@tool
# The default cue provider: a plain text file, one cue per line.
#
#   # comments start with #
#   character | clip          | what to perform
#   puppet    | idle_breathe  | standing, breathing, glancing around
#   puppet    | act_wave      | big friendly wave with the left hand
#
# The file is set in Project Settings > headnhands/cues/sheet
# (res://cue_sheet.txt by default). No file = no cues.
class_name HHCueSheet
extends HHCueProvider

var path := ""


func _init(p_path := "") -> void:
	path = p_path if p_path else HHSettings.get_value("headnhands/cues/sheet")


func cues(character := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		var parts := l.split("|")
		if parts.size() < 2:
			continue
		var who := parts[0].strip_edges()
		var clip := parts[1].strip_edges()
		if clip.is_empty() or (not character.is_empty() and who != character):
			continue
		var what := parts[2].strip_edges() if parts.size() > 2 else ""
		out.append({"character": who, "clip": clip, "kind": "cue", "what": what})
	return out
