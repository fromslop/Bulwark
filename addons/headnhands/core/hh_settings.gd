@tool
# HeadnHands' per-project settings, under Project Settings > headnhands.
# (Turn on "Advanced Settings" to see them.) The plugin registers them with
# their defaults; a project that never touches them gets the defaults.
#
#   headnhands/paths/characters_dir   where characters live: <dir>/<id>/<id>.tscn
#   headnhands/paths/takes_dir        raw takes (the source of truth)
#   headnhands/paths/animations_dir   baked clips: <dir>/<id>/<clip>.res + <id>_library.tres
#   headnhands/naming/rules           an HHNamingRules .tres (empty = idle_/act_/cs_)
#   headnhands/cues/sheet             a plain-text cue sheet (see HHCueSheet)
#   headnhands/cues/provider          a script extending HHCueProvider (overrides the sheet)
class_name HHSettings
extends RefCounted

const DEFAULTS := {
	"headnhands/paths/characters_dir": "res://characters",
	"headnhands/paths/takes_dir": "res://takes",
	"headnhands/paths/animations_dir": "res://animations",
	"headnhands/naming/rules": "",
	"headnhands/cues/sheet": "res://cue_sheet.txt",
	"headnhands/cues/provider": "",
}

const HINTS := {
	"headnhands/paths/characters_dir": [PROPERTY_HINT_DIR, ""],
	"headnhands/paths/takes_dir": [PROPERTY_HINT_DIR, ""],
	"headnhands/paths/animations_dir": [PROPERTY_HINT_DIR, ""],
	"headnhands/naming/rules": [PROPERTY_HINT_FILE, "*.tres,*.res"],
	"headnhands/cues/sheet": [PROPERTY_HINT_FILE, "*.txt"],
	"headnhands/cues/provider": [PROPERTY_HINT_FILE, "*.gd"],
}


## A setting's value (its default if the project hasn't set it).
static func get_value(key: String) -> String:
	return str(ProjectSettings.get_setting(key, DEFAULTS.get(key, "")))


## Adds every setting to Project Settings with its default (editor plugin).
static func register() -> void:
	for key in DEFAULTS:
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, DEFAULTS[key])
		ProjectSettings.set_initial_value(key, DEFAULTS[key])
		ProjectSettings.set_as_basic(key, false)
		var hint: Array = HINTS.get(key, [PROPERTY_HINT_NONE, ""])
		ProjectSettings.add_property_info({"name": key, "type": TYPE_STRING, "hint": hint[0], "hint_string": hint[1]})
