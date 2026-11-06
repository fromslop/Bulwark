extends SceneTree
## A foe playing its recorded clips in the game, frozen at a few moments of each:
## res://shots/clip_<foe>_<clip>_<n>.png. Shows how the hands and weapon read with real
## performances on them. Needs a window.
## Run: Godot_v4.7.2-stable_win64.exe --path . -s res://tests/clip_shots.gd -- [foe id] [clip...]
var main: Node
var f := 0
var foe := "Brute"
var clips: Array = []
var queue: Array = []  # [clip, fraction]
var e: Enemy


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		foe = args[0]
	clips = args.slice(1) if args.size() > 1 else ["idle_heavy", "act_slam", "act_ground_pound", "act_sweep"]
	for c in clips:
		for k in [0.0, 0.5, 0.75, 1.0]:
			queue.append([c, k])
	SaveData.PATH = "user://hoardsman_test_save.txt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(_d: float) -> bool:
	f += 1
	if f == 10:
		Looks.choice.enemy = 0
		main._clear_enemies()
		e = Enemy.new()
		e.setup(EnemyDefs.scaled(foe, 0), main.camera)
		main.world3d.add_child(e)
		e.active = false
		main.enemies.append(e)
		main.enemy = e
		main.hand.pinned = Vector2(1180, 640)
	if f > 20 and f % 4 == 0:
		if queue.is_empty():
			return true
		var job: Array = queue.pop_front()
		var a := e.clip(job[0])
		if a == null:
			return false
		var t: float = a.length * float(job[1])
		for part in [["RightHand", e.right_hand], ["LeftHand", e.left_hand], ["Head", e.head]]:
			var tr := Enemy._clip_tracks(a, part[0])
			if tr.x >= 0:
				part[1].position = a.position_track_interpolate(tr.x, t)
			if tr.y >= 0:
				part[1].quaternion = a.rotation_track_interpolate(tr.y, t)
		e.follow_head_with_torso()
	if f > 20 and f % 4 == 2 and f > 22:
		pass
	if f > 20 and f % 4 == 3:
		var done := clips.size() * 4 - queue.size()
		if done > 0:
			var idx := done - 1
			root.get_texture().get_image().save_png("res://shots/clip_%s_%s_%d.png" % [foe.to_lower(), clips[idx / 4], idx % 4])
	return false
