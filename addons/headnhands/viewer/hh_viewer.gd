# The take viewer: plays a take on its character on your monitor, looping,
# so you can check it without the headset. The naming window's Preview
# button opens it; run it yourself with:
#
#   Godot --path <project> --xr-mode off res://addons/headnhands/viewer/hh_viewer.tscn -- --take res://takes/x.res
#
# With no --take it plays the newest take.
#   Space  restart      M  mirror on/off      Up/Down  slower/faster
class_name HHViewer
extends Node3D

var take_path := ""
var character: HHRig
var playback: HHPlayback
var speed := 1.0
var hud: Label


func _ready() -> void:
	_build_stage()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--take")
	take_path = args[i + 1] if i >= 0 and i + 1 < args.size() else HHTakeStore.newest()
	load_take(take_path)


func load_take(path: String) -> void:
	if character:
		character.queue_free()
		character = null
	playback = null
	var take: HHTake = HHTakeStore.load_take(path) if not path.is_empty() else null
	if take == null:
		hud.text = "No take to show (%s)" % (path if path else "the takes folder is empty")
		return
	if take.character_id.is_empty():
		hud.text = "%s has no character (raw punch-in recording?)" % path.get_file()
		return
	character = HHCharacters.instantiate(take.character_id)
	if character == null:
		hud.text = "Unknown character '%s'" % take.character_id
		return
	$Stage.add_child(character)
	character.position.y = character.mount_height
	playback = HHPlayback.new(character, HHCleanup.run(take).take, true)
	_update_hud()


func _process(delta: float) -> void:
	if playback:
		playback.step(delta * speed)
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or playback == null:
		return
	match event.keycode:
		KEY_SPACE:
			playback.restart()
		KEY_M:
			playback.mirrored = not playback.mirrored
			$Stage.rotation.y = PI if playback.mirrored else 0.0
			playback.restart()
		KEY_UP:
			speed = minf(speed * 2.0, 4.0)
		KEY_DOWN:
			speed = maxf(speed * 0.5, 0.125)


func _update_hud() -> void:
	hud.text = "%s  on %s\n%.1f / %.1f s   speed %sx   %s\nSpace restart   M mirror   Up/Down speed" % [
		take_path.get_file(), character.profile.display_name if character.profile else take_path,
		playback.time, playback.take.duration(), str(speed), "mirror" if playback.mirrored else "behind"]


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var stage := Node3D.new()
	stage.name = "Stage"
	stage.rotation.y = PI   # mirror: the character faces the camera
	add_child(stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 2.4)
	add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	layer.add_child(hud)
