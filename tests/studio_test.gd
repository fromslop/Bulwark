extends SceneTree
## The recording studio at the desk: its windows are up and pointable, the cue board lists
## the whole character (recorded clips too) and picking a row picks the cue, the cast board
## switches character, the attack's field stands where the game's camera puts it, and the
## foe's weapon rides on your controllers. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --xr-mode off --path . -s res://tests/studio_test.gd

var studio
var f := 0
var fails: Array = []


func _initialize() -> void:
	studio = load("res://recording/studio/studio.tscn").instantiate()
	root.add_child(studio)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


func _buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			studio.select_character_id("knight")
		10:
			var ws: HHWorkspace = studio.workspace
			_check(ws.panels.size() == 5, "the studio should put up five windows (%d)" % ws.panels.size())
			# a ray at a window's middle hits its middle pixel
			var p: HHPanel = studio.cue_board
			var h := p.hit(p.global_position + p.global_basis.z * 1.0, -p.global_basis.z)
			_check(not h.is_empty() and (h.px as Vector2).distance_to(Vector2(p.viewport.size) * 0.5) < 2.0, "pointing at a window's middle should hit its middle (%s)" % [h])
			_check(p.hit(p.global_position + p.global_basis.z, p.global_basis.z).is_empty(), "pointing away from a window shouldn't hit it")
			# the cue board: the whole list, recorded or not
			_check(studio.cues.size() == HHCues.all("knight").size(), "the studio should keep every cue, not just the missing ones")
			var rows := _buttons(studio.cue_board.body)
			_check(rows.size() == studio.cues.size(), "the cue board should have a row per cue (%d rows, %d cues)" % [rows.size(), studio.cues.size()])
			var thrust: int = studio.cues.find_custom(func(c: Dictionary) -> bool: return c.clip == "act_thrust")
			rows[thrust].pressed.emit()
		12:
			_check(studio.current_cue().get("clip", "") == "act_thrust", "pressing a row should pick that cue")
			# the field: the thrust's patch of screen, put back in the foe's space
			_check(studio.field.visible, "an attack cue should show its field on the stage")
			var mid := StudioField.zone_point(Vector2(0.5, 0.5))
			_check(mid.distance_to(Vector3(0, StudioField.CAM.y, StudioField.DEPTH)) < 0.001, "the middle of the screen should land straight ahead of the camera (%s)" % mid)
			var corner := StudioField.zone_point(Vector2(1, 0))
			_check(corner.x > 0.5 and corner.y > StudioField.CAM.y, "the top right of the screen should land up and to the foe's right (%s)" % corner)
			_check(studio.view._zone.size() >= 3, "the player's view should draw the thrust's field")
			var model: Enemy = studio.stage_model()
			var want: Transform3D = model.global_transform * Transform3D(Basis(), StudioField.CAM)
			_check(studio.view.cam.global_transform.origin.distance_to(want.origin) < 0.001, "the player's view camera should sit where the game's does")
			# an idle cue has no field
			studio.pick_cue(0)
		14:
			_check(not studio.field.visible, "an idle cue shouldn't show a field")
			_check(studio.right_hand.get_node_or_null("WeaponGhost") != null and studio.right_hand.get_node("WeaponGhost").get_child_count() > 0, "the foe's weapon should ride on your right controller")
			# the cast board switches character
			var cast_rows := _buttons(studio.cast.body)
			_check(cast_rows.size() == studio.character_ids.size(), "the cast board should list every character (%d)" % cast_rows.size())
			var duel: int = -1
			for i in cast_rows.size():
				var labels := (cast_rows[i] as Node).find_children("*", "Label", true, false)
				if labels.any(func(l: Label) -> bool: return l.text == "Duelist"):
					duel = i
			_check(duel >= 0, "the Duelist should be on the cast board")
			if duel >= 0:
				cast_rows[duel].pressed.emit()
		16:
			_check(studio.character_id() == "duelist", "picking the Duelist on the cast board should step into it (%s)" % studio.character_id())
			_check(studio.cue_board._name.text == "Duelist", "the cue board should follow the character")
			print("studio test: %d failures" % fails.size())
			for x in fails:
				print("  FAIL ", x)
			quit(1 if fails.size() > 0 else 0)
	return false
