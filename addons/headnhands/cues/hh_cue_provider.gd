@tool
# Where the recorder's cue list comes from: every clip a project wants
# performed, like an ADR or spotting sheet. The default provider reads a plain
# text cue sheet (HHCueSheet). A project with its own source of truth (story
# files, a spreadsheet export, a database) extends this class, overrides
# cues(), and points Project Settings > headnhands/cues/provider at its script.
#
# Each cue is a Dictionary:
#   {"character": "tinker", "clip": "act_wave", "kind": "story", "what": "waves at the camera"}
# "kind" and "what" are shown in the recorder's HUD; anything else is ignored.
class_name HHCueProvider
extends RefCounted


## Every cue for `character` ("" = every character).
func cues(_character := "") -> Array[Dictionary]:
	return []
