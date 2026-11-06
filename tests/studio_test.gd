extends SceneTree
## The recording studio at the desk: its windows are up and pointable, the cue board lists
## the whole character (recorded clips too) and picking a row picks the cue, the cast board
## switches character, the attack's field stands where the game's camera puts it, and the
## foe's weapon rides on your controllers. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --xr-mode off --path . -s res://tests/studio_test.gd

var studio
var f := 0
var fails: Array = []
var _rec_from := -1
var _checked_take := false
var _rec_ms := 0


func _initialize() -> void:
	# (choices made here go to a scratch file, not the real assignments)
	HoardsmanCues.ASSIGNMENTS = "user://studio_test_assignments.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HoardsmanCues.ASSIGNMENTS))
	HoardsmanCues.reload_assignments()
	studio = load("res://recording/studio/studio.tscn").instantiate()
	studio.bake_on_assign = false
	studio.one_take_per_clip = false  # (the test's takes don't go to your recycle bin)
	root.add_child(studio)


func _knight_row(clip: String) -> Dictionary:
	for c in HHCues.all("knight"):
		if c.clip == clip:
			return c
	return {}


func _texts(n: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b in n.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


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


## The Assign window: choosing who performs a clip changes its owner, and a clip marked not
## needed leaves the studio's lists.
func _test_assign() -> void:
	var a: StudioAssign = studio.assign_board
	_check(a._foe == "knight", "the Assign window should start on the foe on the stage (%s)" % a._foe)
	var c: Dictionary = studio.shared_cues[0]
	var clip: String = c.clip
	var auto_owner: String = c.owner
	# open its choices: Auto, Own take, each foe that has the clip, Not needed
	var row: Button
	for b in _buttons(a._list):
		if (b as Node).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == StudioSlate.clip_title(c)):
			row = b
	_check(row != null, "the Assign window should list the knight's %s" % clip)
	if row == null:
		return
	_check(_texts(row).has(StudioAssign.source_of(c)[1]) and _texts(row).has("AUTO"), "a shared clip should read as from its owner, automatically (%s)" % _texts(row))
	row.pressed.emit()
	var chips: Array = _buttons(a._list).filter(func(b: Button) -> bool: return b.text != "")
	_check(chips.size() == HoardsmanCues.sources("knight", clip).size() + 3, "its choices should be Auto, Own take, every foe with the clip, and Not needed (%d chips)" % chips.size())
	# own take
	(chips[1] as Button).pressed.emit()
	var r := _knight_row(clip)
	_check(r.assigned == "own" and r.owner == "knight" and not r.shared and not r.skipped, "choosing Own take should make the knight perform it (%s)" % r)
	_check(studio.cues.any(func(x: Dictionary) -> bool: return x.clip == clip), "an own take should join the knight's cue list")
	_check(a._open == "", "choosing should close the choices")
	# another foe's take
	var other: String = HoardsmanCues.sources("knight", clip)[0][0]
	a.choose(clip, other)
	r = _knight_row(clip)
	_check(r.owner == other and r.shared and not r.skipped, "choosing a foe should lend its take (%s)" % r)
	_check(studio.shared_cues.any(func(x: Dictionary) -> bool: return x.clip == clip and x.owner == other), "the cue board should list it as from %s" % other)
	# not needed
	a.choose(clip, "skip")
	r = _knight_row(clip)
	_check(r.skipped and r.owner == "" and not r.shared, "Not needed should skip it (%s)" % r)
	_check(not studio.cues.any(func(x: Dictionary) -> bool: return x.clip == clip) and not studio.shared_cues.any(func(x: Dictionary) -> bool: return x.clip == clip), "a clip that isn't needed should leave the studio's lists")
	a.refresh()
	_check(_texts(a._list).has("NOT NEEDED"), "the Assign window should show it as not needed")
	var saved := ConfigFile.new()
	saved.load(HoardsmanCues.ASSIGNMENTS)
	_check(saved.get_value("knight", clip, "") == "skip", "the choice should be saved")
	# back to automatic
	a.choose(clip, "")
	r = _knight_row(clip)
	_check(r.assigned == "" and r.owner == auto_owner, "Auto should hand it back (%s, wanted %s)" % [r.owner, auto_owner])
	saved = ConfigFile.new()
	saved.load(HoardsmanCues.ASSIGNMENTS)
	_check(not saved.has_section_key("knight", clip), "Auto should clear the saved choice")
	# another foe on the left lists that foe's clips
	a.show_foe("duelist")
	_check(a._name.text == "DUELIST", "picking a foe should list its clips (%s)" % a._name.text)
	a.show_foe("knight")


func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			studio.select_character_id("knight")
		10:
			var ws: HHWorkspace = studio.workspace
			_check(ws.panels.size() == 6, "the studio should put up six windows (%d)" % ws.panels.size())
			# a ray at a window's middle hits its middle pixel
			var p: HHPanel = studio.cue_board
			var h := p.hit(p.global_position + p.global_basis.z * 1.0, -p.global_basis.z)
			_check(not h.is_empty() and (h.px as Vector2).distance_to(Vector2(p.viewport.size) * 0.5) < 2.0, "pointing at a window's middle should hit its middle (%s)" % [h])
			_check(p.hit(p.global_position + p.global_basis.z, p.global_basis.z).is_empty(), "pointing away from a window shouldn't hit it")
			# the cue board: the whole list, recorded or not
			_check(studio.cues.size() + studio.shared_cues.size() == HHCues.all("knight").size() and not studio.shared_cues.is_empty(), "the studio should keep every cue (its own, and the ones it shares), not just the missing ones (%d own + %d shared vs %d)" % [studio.cues.size(), studio.shared_cues.size(), HHCues.all("knight").size()])
			var rows := _buttons(studio.cue_board.body)
			_check(rows.size() == studio.cues.size(), "the cue board should have a row per cue (%d rows, %d cues)" % [rows.size(), studio.cues.size()])
			var thrust: int = studio.cues.find_custom(func(c: Dictionary) -> bool: return c.clip == "act_thrust")
			rows[thrust].pressed.emit()
		12:
			_check(studio.current_cue().get("clip", "") == "act_thrust", "pressing a row should pick that cue")
			# the field: the thrust's patch of screen, put back in the foe's space
			_check(studio.field.visible, "an attack cue should show its field on the stage")
			var mid := StudioField.zone_point(Vector2(0.5, 0.5))
			_check(mid.distance_to(Vector3(0, StudioField.CAM.y, 0.5)) < 0.001, "the middle of the screen should land straight ahead of the camera (%s)" % mid)
			var corner := StudioField.zone_point(Vector2(1, 0))
			_check(corner.x > 0.5 and corner.y > StudioField.CAM.y, "the top right of the screen should land up and to the foe's right (%s)" % corner)
			_check(studio.view._zone.size() >= 3, "the player's view should draw the thrust's field")
			var model: Enemy = studio.stage_model()
			var want: Transform3D = model.global_transform * Transform3D(Basis(), model.cam_rel())
			_check(studio.view.cam.global_transform.origin.distance_to(want.origin) < 0.001, "the player's view camera should sit where the game's does")
			# an idle cue has no field
			studio.pick_cue(studio.cues.find_custom(func(c: Dictionary) -> bool: return c.kind != "attack"))
		14:
			_check(studio.field.visible and not studio.field._attack.visible, "an idle cue should show the player's screen but no attack field")
			_check(studio.right_hand.get_node_or_null("WeaponGhost") != null and studio.right_hand.get_node("WeaponGhost").get_child_count() > 0, "the foe's weapon should ride on your right controller")
			_check(studio.right_hand.get_node("WeaponGhost").get_node_or_null("TipMarker") != null, "the weapon on your right controller should mark its tip")
			_test_assign()
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
			# an attack take, start to finish: it runs to the beat and stops by itself
			HHTakeStore.takes_dir = "user://studio_test_takes"
			HHCharacters.animations_dir = "user://studio_test_anims"
			studio.pick_cue(studio.cues.find_custom(func(c: Dictionary) -> bool: return c.clip == "act_lunge"))
		18:
			_check(studio.plan != null and is_equal_approx(studio.plan.windup, 0.8), "the lunge should be planned to its 0.8 s wind-up")
			studio.toggle_recording()
			_rec_from = f
			_rec_ms = Time.get_ticks_msec()
	if _rec_from > 0 and f > _rec_from + 60 and studio.is_idle() and not _checked_take:
		_checked_take = true
		var t: HHTake = studio.last_take
		_check(t != null and t.marks.has("strike") and t.marks.has("windup"), "the take should carry its wind-up and strike marks")
		_check(t != null and t.recipe != null and is_equal_approx(float(t.recipe.fit_marks.get("strike", -1.0)), 0.8), "the take should be fitted to the game's wind-up")
		var clip_path := HHCharacters.animation_dir("duelist").path_join("act_lunge.res")
		var a: Animation = load(clip_path) if ResourceLoader.exists(clip_path) else null
		_check(a != null and absf(float(a.get_meta("strike", -1.0)) - 0.8) < 0.05, "the baked lunge should strike 0.8 s in (%s)" % [a.get_meta("strike", -1.0) if a else "no clip"])
		var took := (Time.get_ticks_msec() - _rec_ms) / 1000.0
		_check(took < 3.0 + 1.0 + 0.8 + 1.5 + 2.0, "the take should have stopped by itself after the follow-through (%.1f s)" % took)
		print("studio test: %d failures" % fails.size())
		for x in fails:
			print("  FAIL ", x)
		quit(1 if fails.size() > 0 else 0)
	if _rec_ms > 0 and Time.get_ticks_msec() - _rec_ms > 20000:  # (takes run on the wall clock)
		fails.append("the attack take never finished")
		print("studio test: %d failures" % fails.size())
		for x in fails:
			print("  FAIL ", x)
		quit(1)
	return false
