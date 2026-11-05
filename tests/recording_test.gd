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
	_check(knight.any(func(c: Dictionary) -> bool: return c.clip == "act_guard" and c.kind == "guard"), "the Knight's cues should include its guard")
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
	# a take bakes to a clip on the foe's performers
	var baked: Dictionary = HHBaker.bake(take, rig)
	var anim: Animation = baked.animation
	_check(anim != null and anim.length > 0.5, "the take should bake to a clip")
	_check(Enemy._clip_tracks(anim, "RightHand").x >= 0 and Enemy._clip_tracks(anim, "Head").y >= 0, "the clip should drive Body/RightHand and Body/Head")
	rig.queue_free()
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
	Enemy.reload_clips()
	print("recording test: %d failures" % fails.size())
	for x in fails:
		print("  FAIL ", x)
	quit(1 if fails.size() > 0 else 0)
	return false
