# Plays a take through a character rig in real time (the recorder's replay and
# play-along characters). Same maths as baking, just live.
class_name HHPlayback
extends RefCounted

var rig: HHRig
var take: HHTake
var time := 0.0
var looping := true
var mirrored := false


func _init(p_rig: HHRig, p_take: HHTake, p_mirrored := false) -> void:
	rig = p_rig
	take = p_take
	mirrored = p_mirrored
	restart()


func restart() -> void:
	time = 0.0
	rig.begin(take.eye_height)


# Advances by dt seconds and poses the rig. Returns the frame it used.
func step(dt: float) -> HHFrame:
	time += dt
	if time > take.duration():
		if looping:
			time = fmod(time, maxf(take.duration(), 0.001))
		else:
			time = take.duration()
	var f := take.sample(time)
	rig.drive(rig.view_frame(f, mirrored), dt)
	return f


func finished() -> bool:
	return not looping and time >= take.duration()
