extends SceneTree
## The recording pipeline, end to end at the desk: every foe is a HeadnHands character, the
## cue list comes from EnemyDefs, the rig puts your right hand on the foe's weapon hand (as
## the player sees it: the recorder's mirror is the game's view), a take bakes to a clip,
## and the game's Enemy plays that clip with its head still on the cursor. Headless.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/recording_test.gd

var main: Node
var f := 0
var fails: Array = []


func _initialize() -> void:
	SaveData.PATH = "user://hoardsman_test_save.txt"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


## A performer standing still, then raising the right hand up and out to the right.
func _take(seconds := 1.0) -> HHTake:
	var t := HHTake.new()
	t.eye_height = 1.65
	t.recipe = HHCleanupRecipe.new()
	t.recipe.trim_stop_reach = false
	t.recipe.smoothing = 0.0
	var n := int(seconds * 60.0)
	for i in n:
		var u := float(i) / float(n - 1)
		var fr := HHFrame.new()
		fr.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
		fr.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
		fr.right = Transform3D(Basis(), Vector3(0.22, 1.07, -0.22).lerp(Vector3(0.5, 1.95, -0.3), u))
		fr.left_confidence = 2
		fr.right_confidence = 2
		t.append(i / 60.0, fr)
	return t


## Phase 3: a take fitted to the game's timing, the beat it's performed to, and the game
## bending, chaining and blending clips.
## The far end of the foe's weapon, in its body's space.
static func _foe_tip(model: Enemy, haft: float) -> Vector3:
	return model.right_hand.position + model.right_hand.quaternion * Vector3(0, haft, 0)


## Where a point in front of the foe shows on the player's screen (0..1 each way), from the
## game's camera (relative to the foe: further back for a long weapon).
static func _on_screen(p: Vector3, cam := Enemy.GAME_CAM) -> Vector2:
	var ty := tan(deg_to_rad(Enemy.GAME_FOV * 0.5))
	var dz := cam.z - p.z
	return Vector2(0.5 + p.x / (ty * 16.0 / 9.0 * dz) * 0.5, 0.5 - (p.y - cam.y) / (ty * dz) * 0.5)


## A made-up clip: the hands from `a` to `b` (x of the weapon hand) over `length`, held,
## or with `keys` [time, x] for the weapon hand.
static func _line_clip(length: float, keys: Array, loop := false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for part in ["RightHand", "LeftHand", "Head"]:
		var tr := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tr, NodePath("Body/" + part))
		for k in keys:
			var x: float = k[1] if part == "RightHand" else 0.0
			a.position_track_insert_key(tr, k[0], Vector3(x, 1.4 if part != "Head" else 1.68, 0.3 if part != "Head" else 0.0))
	return a


## How the game plays clips into each other: a blow's follow-through plays out into the
## idle, the hands never jump at a change of clip, and a hit that doesn't stagger plays the
## flinch over whatever it's doing, from its recoil, and settles back.
func _test_playback(e: Enemy, base: String) -> void:
	var idle := _line_clip(1.0, [[0.0, 0.1], [1.0, 0.1]], true)
	var blow := _line_clip(2.0, [[0.0, 0.0], [2.0, 0.4]])  # (the hand moving on all through)
	blow.set_meta("strike", 0.5)
	Enemy._clip_cache[base + "idle_%s.res" % e.data.get("idle", "steady")] = idle
	Enemy._clip_cache[base + "act_overhead_r.res"] = blow
	e._flinch_t = -1.0
	e.clip_name = ""
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS.overhead_r.duplicate(true)
	e.current.id = "overhead_r"
	e.progress = 1.0
	e._update_clip(0.5)
	e.state = "recover"
	for i in 6:
		e._update_clip(0.05)
	e.state = "idle"  # (the game's recovery is over: the follow-through isn't)
	e._queued = ""
	var played_on := 0.0
	var last_x := e.right_hand.position.x
	var worst := 0.0
	for i in 60:
		e._update_clip(1.0 / 30.0)
		worst = maxf(worst, absf(e.right_hand.position.x - last_x))
		last_x = e.right_hand.position.x
		if e.clip_name == "act_overhead_r":
			played_on = e.clip_time
	_check(played_on > 2.0 - Enemy.CLIP_SETTLE - 0.1, "back in the idle, a blow's follow-through should play out (it stopped at %.2f of 2.0)" % played_on)
	_check(e.clip_name.begins_with("idle_"), "...and then settle into the idle (%s)" % e.clip_name)
	_check(worst < 0.05, "the hand shouldn't jump on the way (%.3f m in a frame; settling straight to the idle would be 0.22)" % worst)
	# a hit that doesn't stagger: the flinch's recoil (after its still start) over the idle
	var fl := _line_clip(1.5, [[0.0, 0.0], [0.4, 0.0], [0.6, 0.3], [1.5, 0.0]])
	Enemy._clip_cache[base + "act_flinch.res"] = fl
	fl.remove_meta("onset") if fl.has_meta("onset") else null
	for i in 20:
		e._update_clip(1.0 / 30.0)
	var rest_x := e.right_hand.position.x
	e.hp = e.max_hp
	e.take_hit(0.1, "torso", false)
	var peak := 0.0
	var peak_at := 0.0
	for i in 60:
		e._update_clip(1.0 / 30.0)
		if e.right_hand.position.x - rest_x > peak:
			peak = e.right_hand.position.x - rest_x
			peak_at = (i + 1) / 30.0
	_check(peak > 0.2 and peak_at < 0.35, "a hit should make it flinch straight away (%.2f m, %.2f s after the hit)" % [peak, peak_at])
	_check(absf(e.right_hand.position.x - rest_x) < 0.01, "...and it should settle back (%.3f m off)" % absf(e.right_hand.position.x - rest_x))
	Enemy._clip_cache.erase(base + "act_flinch.res")


func _test_timing(e: Enemy) -> void:
	# a slow performer: the wind-up starts at 1.0 s and the blow lands at 1.8 s; the game
	# wants it to land 0.5 s into the clip
	var take := _take(2.5)
	take.marks = {"windup": 1.0, "strike": 1.8}
	take.recipe.fit_marks = {"windup": 0.0, "strike": 0.5}
	var rig := HHCharacters.instantiate("knight")
	root.add_child(rig)
	var anim: Animation = HHBaker.bake(take, rig).animation
	_check(absf(float(anim.get_meta("strike", -1.0)) - 0.5) < 0.04, "the blow should land on the game's strike (%.2f)" % float(anim.get_meta("strike", -1.0)))
	_check(absf(float(anim.get_meta("windup", -1.0))) < 0.04, "the clip should start as the wind-up does (%.2f)" % float(anim.get_meta("windup", -1.0)))
	_check(absf(anim.length - (0.5 + 0.7)) < 0.08, "after the strike the follow-through plays at its own pace (length %.2f)" % anim.length)
	var plain: Animation = HHBaker.bake(_take(2.5), rig).animation
	var rh := Enemy._clip_tracks(anim, "RightHand").x
	var at_strike := anim.position_track_interpolate(rh, 0.5)
	var raw := plain.position_track_interpolate(Enemy._clip_tracks(plain, "RightHand").x, 1.8)
	_check(at_strike.distance_to(raw) < 0.03, "the pose at the game's strike should be the pose at your strike (%s vs %s)" % [at_strike, raw])
	rig.queue_free()
	# the beat: settle, wind-up, strike, follow; the trigger marks the blow
	var g := StudioGuide.new(0.8)
	_check(g.phase(0.5) == "settle" and g.phase(1.4) == "windup" and g.phase(2.0) == "follow", "the beat should run settle, wind-up, follow")
	_check(g.tick(1.05, 0.0) == ["windup"], "the wind-up tone should sound once, as it starts")
	g.tick(1.7, 0.9)
	_check(is_equal_approx(g.strike_mark, 1.7), "a trigger pull should mark the blow (%.2f)" % g.strike_mark)
	_check(g.marks() == {"windup": 1.0, "strike": 1.7} and g.fit() == {"windup": 0.0, "strike": 0.8}, "the take should be fitted from the trigger's mark to the game's wind-up")
	var c := StudioGuide.new(0.8, 0.6, 0.7)
	_check(c.phase(2.2) == "gap" and c.phase(2.8) == "windup2", "a combo's beat should pause, then wind up again")
	_check(is_equal_approx(float(c.fit().strike2), 2.1), "a combo's second blow should be pinned after the pause and second wind-up (%s)" % [c.fit()])
	# the cue list: combos carry both wind-ups; feints need no clip
	var knight := HHCues.all("knight")
	var combo: Array = knight.filter(func(cue: Dictionary) -> bool: return str(cue.clip).begins_with("act_combo_"))
	_check(not combo.is_empty() and combo.all(func(cue: Dictionary) -> bool: return float(cue.get("windup2", 0.0)) > 0.0 and float(cue.get("gap", 0.0)) > 0.0), "a combo cue should know both wind-ups and the pause")
	_check(not HHCues.all("duelist").any(func(cue: Dictionary) -> bool: return cue.clip == "act_feint"), "feints shouldn't need a clip of their own")
	# the game bends a hand-aimed blow towards the hand
	e.clip_name = ""
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS.thrust.duplicate(true)
	e.current.id = "thrust"
	e.current.track = true
	var moved: Array = []
	for p in e.current.zone:
		moved.append((p as Vector2) + Vector2(0.25, 0.0))
	e.current.zone = moved
	e.progress = 1.0
	e._update_clip(0.2)  # (past the crossfade from the last clip)
	var bent := e.right_hand.position
	var straight := anim.position_track_interpolate(rh, Enemy.strike_time(anim))
	_check(bent.x - straight.x > 0.15, "a blow aimed at the hand should be bent towards it (%s vs %s)" % [bent, straight])
	# a combo plays one clip across both blows, the second landing on strike2
	anim.set_meta("strike2", 1.0)
	var base := "%s/%s/" % [Enemy.CLIP_DIR, Enemy.model_path(e.data).get_file().get_basename()]
	Enemy._clip_cache[base + "act_combo_overhead_l.res"] = anim
	e.clip_name = ""
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS.overhead_l.duplicate(true)
	e.current.id = "overhead_l"
	e.current.next = "thrust"
	e.progress = 1.0
	e._update_clip(0.0)
	_check(e.clip_name == "act_combo_overhead_l" and is_equal_approx(e.clip_time, Enemy.strike_time(anim)), "a combo's first blow should land on the clip's first strike")
	e.state = "idle"
	e._queued = "thrust"
	e._update_clip(0.1)
	_check(e.clip_name == "act_combo_overhead_l", "the combo clip should carry on through the pause")
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS.thrust.duplicate(true)
	e.current.id = "thrust"
	e._queued = ""
	e.progress = 1.0
	e._update_clip(0.0)
	_check(e.clip_name == "act_combo_overhead_l" and is_equal_approx(e.clip_time, 1.0), "the second blow should land on strike2 (%s at %.2f)" % [e.clip_name, e.clip_time])
	# changing clip crossfades: straight after, the hand is between the two poses
	var other: Animation = plain
	Enemy._clip_cache[base + "act_stagger.res"] = other
	var before := e.right_hand.position
	e.state = "stagger"
	e._update_clip(0.01)
	var target := other.position_track_interpolate(Enemy._clip_tracks(other, "RightHand").x, e.clip_time)
	_check(e.right_hand.position.distance_to(target) > 0.001 or before.distance_to(target) < 0.001, "a change of clip should blend, not jump")
	_test_playback(e, base)
	e.active = false


func _process(_d: float) -> bool:
	f += 1
	if f != 10:
		return false
	# every foe in the cue list is a character
	var ids := HHCharacters.ids()
	var seen := {}
	for pair in HoardsmanCues.foes():
		var slug := HoardsmanCues.slug(pair[1])
		_check(ids.has(slug), "%s should be a recording character" % slug)
		_check(not seen.has(slug), "%s and %s share a model: one would overwrite the other's character and clips" % [pair[0], seen.get(slug, "")])
		seen[slug] = pair[0]
	# the cue list is the game's
	_check(HHCues.current_provider() is HoardsmanCues, "the recorder should read cues from HoardsmanCues")
	var knight := HHCues.all("knight")
	_check(knight.any(func(c: Dictionary) -> bool: return c.clip == "act_stagger"), "every foe should have one stagger to perform")
	var lunge: Array = HHCues.all("duelist").filter(func(c: Dictionary) -> bool: return c.clip == "act_lunge")
	_check(lunge.size() == 1 and is_equal_approx(float(lunge[0].windup), 0.8) and lunge[0].attack == "lunge", "a cue should know its attack and wind-up (%s)" % [lunge])
	# the rig: your right hand is the foe's weapon hand, on the player's right
	var rig := HHCharacters.instantiate("knight")
	root.add_child(rig)
	var take := _take()
	rig.begin(take.eye_height)
	for i in 30:
		rig.drive(take.sample(take.duration()), 1.0 / 60.0)
	var model: Enemy = rig.model
	_check(model.right_hand.position.y > 1.6 and model.right_hand.position.x > 0.25, "raising your right hand should raise the foe's weapon hand, on the player's right (%s)" % model.right_hand.position)
	_check(model.left_hand.position.y < 1.4, "the other hand should stay down (%s)" % model.left_hand.position)
	_check(model.head.quaternion.angle_to(Quaternion.IDENTITY) < 0.05, "looking straight ahead, the foe should look straight at the player, not away (%.2f rad off)" % model.head.quaternion.angle_to(Quaternion.IDENTITY))
	_check(model.torso.rotation.length() < 0.001, "the foe's body should always square up to the player")

	# reaching at the player is squashed and stops short of the camera
	var reach := HHFrame.new()
	reach.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
	reach.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
	reach.right = Transform3D(Basis(), Vector3(0.22, 1.4, -0.9))
	for i in 60:
		rig.drive(reach, 1.0 / 60.0)
	_check(model.right_hand.position.z < rig.reach_limit + 0.01, "a full reach at the player should stop short of the camera (z %.2f)" % model.right_hand.position.z)
	# the frame in front of you agrees with the player's screen: put the TIP of the weapon on
	# your controller where the frame says a point of the screen is (held straight or tilted),
	# and the foe's weapon tip lands on that point of the player's screen
	var depth: float = rig.tip_frame_depth()
	var grip := Basis.from_euler(rig.grip_offset_deg * PI / 180.0)
	var haft: float = rig._haft
	var holds := [Basis(), Basis.from_euler(Vector3(0.7, 0.3, -0.4)), Basis.from_euler(Vector3(-0.5, -0.4, 0.2))]
	# (standing off the floor mark too: nobody stands exactly on it)
	for stand in [Vector3(0, 1.65, 0), Vector3(0.3, 1.7, 0.4), Vector3(-0.25, 1.6, -0.2)]:
		for s in [Vector2(0.5, 0.5), Vector2(0.1, 0.12), Vector2(0.9, 0.85), Vector2(0.25, 0.3), Vector2(0.75, 0.65)]:
			for q in holds:
				rig.begin(1.65)
				var first := HHFrame.new()
				first.head = Transform3D(Basis(), stand)
				first.left = Transform3D(Basis(), stand + Vector3(-0.22, -0.58, -0.22))
				first.right = Transform3D(Basis(), stand + Vector3(0.22, -0.58, -0.22))
				rig.drive(first, 1.0 / 60.0)  # (where you stand when the take starts)
				var at: Vector3 = rig.performer_tip_for(rig.screen_point(s, depth))
				var aim := HHFrame.new()
				aim.head = Transform3D(Basis(), stand)
				aim.left = Transform3D(Basis(), stand + Vector3(-0.22, -0.58, -0.22))
				aim.right = Transform3D(q, at - q * (grip * Vector3(0, haft, 0)))
				for i in 120:
					rig.drive(aim, 1.0 / 60.0)
				var tp := _foe_tip(model, haft)
				var on_screen := _on_screen(tp, rig.game_cam())
				_check(on_screen.distance_to(s) < 0.03, "a weapon tip on the frame at %s (standing at %s, held %s) should put the foe's weapon tip at that point of the player's screen (got %s; tip %s, hand %s)" % [s, stand, q.get_euler(), on_screen, tp, model.right_hand.position])
				_check(tp.z <= rig.game_cam().z - 0.2 + 0.001, "the foe's weapon tip should stop short of the camera (z %.2f)" % tp.z)
	# the frame stands further out than arm's reach, and smaller than the old hand frame
	rig.begin(1.65)
	var still := HHFrame.new()
	still.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
	still.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
	still.right = Transform3D(Basis(), Vector3(0.22, 1.07, -0.22))
	rig.drive(still, 1.0 / 60.0)
	var mid_you: Vector3 = rig.performer_tip_for(rig.screen_point(Vector2(0.5, 0.5), depth))
	_check(absf(-mid_you.z - 0.9) < 0.12, "the frame should stand about 0.9 m in front of you (%.2f)" % -mid_you.z)
	var tall: float = (rig.performer_tip_for(rig.screen_point(Vector2(0.5, 0.0), depth)) - rig.performer_tip_for(rig.screen_point(Vector2(0.5, 1.0), depth))).length()
	_check(tall > 0.3 and tall < 0.5, "the frame should be a little under half a metre tall (%.2f m)" % tall)
	# ...and holds just past it: the tip pushed through the frame stays at the same height on screen
	for push in [-0.06, -0.03]:
		rig.begin(1.65)
		var mid: Vector3 = rig.performer_tip_for(rig.screen_point(Vector2(0.5, 0.25), depth))
		var near := HHFrame.new()
		near.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
		near.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
		near.right = Transform3D(Basis(), mid + Vector3(0, 0, push) - grip * Vector3(0, haft, 0))
		for i in 120:
			rig.drive(near, 1.0 / 60.0)
		var y_on := _on_screen(_foe_tip(model, haft), rig.game_cam()).y
		_check(absf(y_on - 0.25) < 0.03, "the tip %.2f m further out shouldn't change its height on screen (%.2f, wanted 0.25)" % [-push, y_on])
	# ...but pulled back off the frame (a raised blade, a follow-through) the hand goes where
	# yours does, not flung outward: the tip keeps the frame point's height and side-to-side
	for spot in [Vector2(0.15, 0.1), Vector2(0.85, 0.2), Vector2(0.5, 0.9)]:
		rig.begin(1.65)
		var on_pane: Vector3 = rig.screen_point(spot, depth)
		var back := HHFrame.new()
		back.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
		back.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
		var up := Basis(Vector3.RIGHT, PI / 2.0)  # (the blade raised, pointing straight up)
		back.right = Transform3D(up, rig.performer_tip_for(on_pane) + Vector3(0, 0, 0.35) - up * (grip * Vector3(0, haft, 0)))
		for i in 120:
			rig.drive(back, 1.0 / 60.0)
		var tp2 := _foe_tip(model, haft)
		var drift := Vector2(tp2.x - on_pane.x, tp2.y - on_pane.y).length()
		_check(drift < 0.02, "a raised tip 0.35 m back off the frame at %s should stay where your tip is, not be flung out (%.3f m off; tip z %.2f, frame %.2f)" % [spot, drift, tp2.z, depth])
	rig.begin(1.65)
	# holding the off hand's grip snaps it onto the weapon
	var grab := HHFrame.new()
	grab.head = reach.head
	grab.right = Transform3D(Basis(), Vector3(0.22, 1.1, -0.3))
	grab.left = Transform3D(Basis(), Vector3(-0.1, 1.0, -0.3))
	grab.left_grip = 1.0
	for i in 60:
		rig.drive(grab, 1.0 / 60.0)
	var axis := model.right_hand.basis.y.normalized()
	var off := model.left_hand.position - model.right_hand.position
	_check((off - axis * off.dot(axis)).length() < 0.02, "with its grip held, the off hand should sit on the weapon's line (%.3f off it)" % (off - axis * off.dot(axis)).length())
	grab.left_grip = 0.0
	for i in 60:
		rig.drive(grab, 1.0 / 60.0)
	off = model.left_hand.position - model.right_hand.position
	_check((off - axis * off.dot(axis)).length() > 0.05, "let go, the off hand should come away")
	# a take bakes to a clip on the foe's performers
	var baked: Dictionary = HHBaker.bake(take, rig)
	var anim: Animation = baked.animation
	_check(anim != null and anim.length > 0.5, "the take should bake to a clip")
	_check(Enemy._clip_tracks(anim, "RightHand").x >= 0 and Enemy._clip_tracks(anim, "Head").y >= 0, "the clip should drive Body/RightHand and Body/Head")
	rig.queue_free()
	# a fast chop carries the tip through the frame in a frame or two: the hand eases after
	# the screen correction, never jumping much further than your hand moved
	rig.begin(1.65)
	var chop := HHFrame.new()
	chop.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
	chop.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
	var raised := Basis(Vector3.RIGHT, PI * 0.6)  # (blade up and back)
	var swung := Basis(Vector3.RIGHT, -0.2)  # (blade down and out at the player)
	var worst := 0.0  # the foe's hand's biggest step in a frame
	var fastest := 0.0  # ...and yours
	var prev_hand := Vector3.INF
	var prev_ctrl := Vector3.INF
	for i in 60:
		var u := clampf((i - 30) / 4.0, 0.0, 1.0)  # (the chop: four frames at 30 fps)
		chop.right = Transform3D(raised.slerp(swung, u), Vector3(0.25, 1.95, -0.3).lerp(Vector3(0.15, 1.2, -0.55), u))
		rig.drive(chop, 1.0 / 30.0)
		var hp3: Vector3 = model.right_hand.position
		if prev_hand != Vector3.INF:
			worst = maxf(worst, hp3.distance_to(prev_hand))
			fastest = maxf(fastest, chop.right.origin.distance_to(prev_ctrl))
		prev_hand = hp3
		prev_ctrl = chop.right.origin
	_check(worst < fastest * 1.4, "a fast chop through the frame shouldn't make the foe's hand jump (%.2f m in a frame, yours at most %.2f)" % [worst, fastest])
	# a long weapon: the Halberdier stands back, and his frame stands out where his tip
	# swings, framing the screen as every foe's does; a tip at it lands where it shows, and a
	# tip swung well past it doesn't haul his hand across the screen
	var hal := HHCharacters.instantiate("halberdier")
	root.add_child(hal)
	hal.begin(1.65)  # (a rig builds its foe on its first take)
	var hm: Enemy = hal.model
	_check(hm.stand_back > 0.4, "the Halberdier should stand back for his halberd (%.2f m)" % hm.stand_back)
	_check(absf((hal.game_cam().z - hal.tip_frame_depth()) - (rig.game_cam().z - depth)) < 0.01, "his frame should frame the screen as the Knight's does")
	var hgrip := Basis.from_euler(hal.grip_offset_deg * PI / 180.0)
	var hhaft: float = hal._haft
	# (held as you'd swing it: raised, and raised and tipped forward; never level at the
	# screen with its tip on the frame, which puts your hand inside your own chest)
	for hold in [Basis(Vector3.RIGHT, PI / 2.0), Basis(Vector3.RIGHT, PI / 4.0)]:
		for s in [Vector2(0.5, 0.5), Vector2(0.15, 0.2), Vector2(0.85, 0.8)]:
			for push in [0.0, -0.5]:
				hal.begin(1.65)
				var hf := HHFrame.new()
				hf.head = Transform3D(Basis(), Vector3(0, 1.65, 0))
				hf.left = Transform3D(Basis(), Vector3(-0.22, 1.07, -0.22))
				hf.right = Transform3D(Basis(), Vector3(0.22, 1.07, -0.22))
				hal.drive(hf, 1.0 / 60.0)
				var pane: Vector3 = hal.screen_point(s, hal.tip_frame_depth())
				hf.right = Transform3D(hold, hal.performer_tip_for(pane) + Vector3(0, 0, push) - hold * (hgrip * Vector3(0, hhaft, 0)))
				for i in 120:
					hal.drive(hf, 1.0 / 60.0)
				var htp := hm.right_hand.position + hm.right_hand.quaternion * Vector3(0, hhaft, 0)
				if push == 0.0:
					var on := _on_screen(htp, hal.game_cam())
					_check(on.distance_to(s) < 0.03, "the Halberdier's tip on his frame at %s (held %s) should land there on the player's screen (got %s)" % [s, hold.get_euler(), on])
				else:
					var pulled := Vector2(htp.x - pane.x, htp.y - pane.y).length()
					_check(pulled < 0.05, "the Halberdier's tip 0.5 m past his frame at %s (held %s) shouldn't haul his hand across (%.2f m)" % [s, hold.get_euler(), pulled])
	hal.queue_free()
	# the Sexton's bell hangs free: straight down whichever way the pole is held, and
	# swinging behind a sudden move
	var sx := Enemy.new()
	sx.setup(EnemyDefs.scale_def(HoardsmanCues.def_of("Sexton").duplicate(true), 0), null)
	sx.active = false
	sx.set_process(false)
	root.add_child(sx)
	_check(not sx._swingers.is_empty(), "the Sexton's bell should hang free")
	if not sx._swingers.is_empty():
		var bell: Node3D = sx._swingers[0].node
		for tilt in [0.0, PI / 2.0, -PI / 3.0]:
			sx.right_hand.rotation = Vector3(0, 0, tilt)
			for i in 240:
				sx.swing_parts(1.0 / 60.0)
			_check(bell.global_basis.y.normalized().dot(Vector3.UP) > 0.98, "the bell should hang straight down with the pole tilted %.1f rad (%s)" % [tilt, bell.global_basis.y.normalized()])
		sx.right_hand.position.x += 0.4  # (a sudden sweep sideways)
		for i in 3:
			sx.swing_parts(1.0 / 60.0)
		_check(absf(bell.global_basis.y.normalized().x) > 0.1, "the bell should swing behind a sudden move (%s)" % bell.global_basis.y.normalized())
	sx.queue_free()
	# the game plays it: an idle Knight with this as its idle clip follows it
	var e: Enemy = main.enemy
	var idle_path := "%s/%s/idle_%s.res" % [Enemy.CLIP_DIR, Enemy.model_path(e.data).get_file().get_basename(), e.data.get("idle", "steady")]
	Enemy._clip_cache[idle_path] = anim
	e.clip_name = ""  # (it already looked for an idle clip before there was one)
	e.active = true
	e.state = "idle"
	e._timer = 99.0
	e.look_target = Vector2(0.9, 0.45)
	for i in 40:
		e._process(1.0 / 60.0)
	_check(e.clip_name.begins_with("idle_") and e.clip_time > 0.0, "an idle foe with an idle clip should play it (%s at %.2f, clip %s, state %s)" % [e.clip_name, e.clip_time, e._clip, e.state])
	var want := anim.position_track_interpolate(Enemy._clip_tracks(anim, "RightHand").x, e.clip_time)
	_check(e.right_hand.position.distance_to(want) < 0.01, "the weapon hand should follow the clip (%s vs %s)" % [e.right_hand.position, want])
	_check(e.head.rotation.y > 0.2, "the head should still turn to the cursor over the clip (yaw %.2f)" % e.head.rotation.y)
	# an attack clip is timed to the wind-up: its strike lands when the game's does
	anim.set_meta("strike", 0.6)
	e.state = "windup"
	e.current = EnemyDefs.ATTACKS.thrust.duplicate(true)
	e.current.id = "thrust"
	e.progress = 0.5
	Enemy._clip_cache[idle_path.get_base_dir().path_join("act_thrust.res")] = anim
	e._update_clip(0.0)
	_check(e.clip_name == "act_thrust" and is_equal_approx(e.clip_time, 0.3), "half way through the wind-up should be half way to the strike mark (%.2f)" % e.clip_time)
	_test_timing(e)
	Enemy.reload_clips()
	print("recording test: %d failures" % fails.size())
	for x in fails:
		print("  FAIL ", x)
	quit(1 if fails.size() > 0 else 0)
	return false
