# Bakes a take into a character animation:
#   raw take -> HHCleanup -> character rig (step by step) -> Animation tracks
#
# The result is an ordinary Godot Animation of the character's joint nodes, so
# AnimationPlayer / AnimationTree use it like any other clip. Takes are the
# source of truth: bake again whenever a character or its profile changes.
class_name HHBaker
extends RefCounted

## Cleanup works at this rate before the rig samples it at the clip's fps.
const CLEAN_RATE := 90.0
## The rig is driven this many times per clip frame (at about the headset's rate): its
## springs then move as they did live, while you performed, not stiffer. (At a clip's 30 fps
## a spring's stability clamp all but snaps fast springs, a 12 Hz grip or a 3 Hz hand.)
const SUBSTEPS := 3


# Returns {"animation": Animation, "report": Dictionary}.
static func bake(take: HHTake, rig: HHRig, recipe: HHCleanupRecipe = null) -> Dictionary:
	if recipe == null:
		recipe = take.recipe if take.recipe else HHCleanupRecipe.new()
	var cleaned := HHCleanup.run(take, recipe, CLEAN_RATE)
	var clean: HHTake = cleaned.take
	var report: Dictionary = cleaned.report

	var fps := float(recipe.fps)
	var dt := 1.0 / fps
	var retime := rig.profile.retime if rig.profile else 1.0
	# A looping clip's last frame flows into its first, so its length is one
	# frame longer than its last sample.
	var period := clean.duration() + (1.0 / CLEAN_RATE if recipe.loop else 0.0)
	# Fitted marks: clip time -> take time, piecewise straight between pinned marks.
	var anchors := [] if recipe.loop else fit_anchors(clean, recipe)
	if not anchors.is_empty():
		var last: Vector2 = anchors.back()
		period = last.x + maxf(clean.duration() - last.y, 0.0)
	var count := maxi(2, int(round(period * fps)) + (0 if recipe.loop else 1))

	rig.begin(take.eye_height)
	if recipe.loop:
		# Warm-up lap: springs end the lap in the state they start the next
		# one, so the baked loop has no pop at the seam.
		for i in count:
			for j in SUBSTEPS:
				rig.drive(clean.sample(minf(fposmod((i + float(j + 1 - SUBSTEPS) / SUBSTEPS) * dt, period), clean.duration())), dt / SUBSTEPS)

	var nodes := rig.baked_nodes()
	var props := rig.baked_properties()
	var pos := []
	var rot := []
	var scl := []
	var vals := []
	for n in nodes:
		pos.append([])
		rot.append([])
		scl.append([])
	for p in props:
		vals.append([])

	for i in count:
		for j in SUBSTEPS:  # (the last lands on this frame's time)
			var ct := (i + float(j + 1 - SUBSTEPS) / SUBSTEPS) * dt
			var tt := minf(fposmod(ct, period), clean.duration()) if recipe.loop else clampf(warp(anchors, ct), 0.0, clean.duration())
			rig.drive(clean.sample(tt), dt / SUBSTEPS)
		for k in nodes.size():
			var node := nodes[k]
			pos[k].append(node.position)
			# q and -q are the same rotation; keep neighbouring keys on the
			# same side so playback never spins the long way round.
			var q := node.quaternion
			if not rot[k].is_empty() and (rot[k].back() as Quaternion).dot(q) < 0.0:
				q = -q
			rot[k].append(q)
			scl[k].append(node.scale)
		for k in props.size():
			vals[k].append(props[k][0].get(props[k][1]))

	var anim := Animation.new()
	anim.length = (count - (0 if recipe.loop else 1)) * dt * retime
	anim.loop_mode = Animation.LOOP_LINEAR if recipe.loop else Animation.LOOP_NONE
	anim.step = dt * retime

	var tracks := 0
	for k in nodes.size():
		var path := node_path(rig, nodes[k])
		tracks += _add_track(anim, Animation.TYPE_POSITION_3D, path, pos[k], dt * retime)
		tracks += _add_track(anim, Animation.TYPE_ROTATION_3D, path, rot[k], dt * retime)
		tracks += _add_track(anim, Animation.TYPE_SCALE_3D, path, scl[k], dt * retime)
	for k in props.size():
		var path := "%s:%s" % [node_path(rig, props[k][0]), props[k][1]]
		tracks += _add_track(anim, Animation.TYPE_VALUE, path, vals[k], dt * retime)

	for k in clean.marks:
		anim.set_meta(k, unwarp(anchors, float(clean.marks[k])) * retime)  # where each mark landed
	report["marks"] = clean.marks.keys()
	report["frames"] = count
	report["fps"] = fps
	report["length"] = anim.length
	report["tracks"] = tracks
	report["loop"] = recipe.loop
	return {"animation": anim, "report": report}


# The pinned marks the recipe asks for that the take has: [Vector2(clip time, take
# time)], in order. Empty: no fitting (the clip plays at the take's own pace).
static func fit_anchors(clean: HHTake, recipe: HHCleanupRecipe) -> Array:
	var out := []
	for k in recipe.fit_marks:
		if clean.marks.has(k):
			out.append(Vector2(float(recipe.fit_marks[k]), float(clean.marks[k])))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	if out.size() == 1 and out[0].x > 0.0:
		out.push_front(Vector2(0.0, maxf(out[0].y - out[0].x, 0.0)))  # (one mark: just shift)
	return out


# Clip time -> take time.
static func warp(anchors: Array, c: float) -> float:
	if anchors.is_empty():
		return c
	var first: Vector2 = anchors[0]
	if c <= first.x:
		return first.y - (first.x - c)
	for i in range(1, anchors.size()):
		var a: Vector2 = anchors[i - 1]
		var b: Vector2 = anchors[i]
		if c <= b.x:
			return lerpf(a.y, b.y, (c - a.x) / maxf(b.x - a.x, 0.0001))
	var last: Vector2 = anchors.back()
	return last.y + (c - last.x)


# Take time -> clip time (where a moment of the take lands in the clip).
static func unwarp(anchors: Array, t: float) -> float:
	if anchors.is_empty():
		return t
	var first: Vector2 = anchors[0]
	if t <= first.y:
		return first.x - (first.y - t)
	for i in range(1, anchors.size()):
		var a: Vector2 = anchors[i - 1]
		var b: Vector2 = anchors[i]
		if t <= b.y:
			return lerpf(a.x, b.x, (t - a.y) / maxf(b.y - a.y, 0.0001))
	var last: Vector2 = anchors.back()
	return last.x + (t - last.y)


# Bakes a take for a character and saves the clip into that character's library.
# Returns {"ok": bool, "clip": String, "path": String, "report": Dictionary}.
static func bake_to_library(take: HHTake, take_path: String, character_id: String) -> Dictionary:
	var rig := HHCharacters.instantiate(character_id)
	if rig == null:
		return {"ok": false, "clip": "", "path": "", "report": {"notes": ["unknown character '%s'" % character_id]}}
	var result := bake(take, rig, null)
	rig.free()

	var clip := clip_name_for(take, take_path)
	var dir := HHCharacters.animation_dir(character_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var anim_path := "%s/%s.res" % [dir, clip]
	var anim: Animation = result.animation
	anim.resource_name = clip
	var err := ResourceSaver.save(anim, anim_path)
	if err != OK:
		return {"ok": false, "clip": clip, "path": anim_path, "report": result.report}

	# Point the character's AnimationLibrary at the saved clip (a reference, so
	# the library file stays small and readable).
	var lib_path := HHCharacters.library_path(character_id)
	var lib: AnimationLibrary = null
	if ResourceLoader.exists(lib_path):
		lib = ResourceLoader.load(lib_path, "", ResourceLoader.CACHE_MODE_REPLACE) as AnimationLibrary
	if lib == null:
		lib = AnimationLibrary.new()
	if lib.has_animation(clip):
		lib.remove_animation(clip)
	lib.add_animation(clip, ResourceLoader.load(anim_path, "", ResourceLoader.CACHE_MODE_REPLACE))
	ResourceSaver.save(lib, lib_path)
	return {"ok": true, "clip": clip, "path": anim_path, "report": result.report}


# Removes a clip from a character's library and deletes its baked file (it can
# always be rebaked from the take).
static func remove_from_library(character_id: String, clip: String) -> void:
	if character_id.is_empty() or clip.is_empty():
		return
	var lib_path := HHCharacters.library_path(character_id)
	if ResourceLoader.exists(lib_path):
		var lib := ResourceLoader.load(lib_path, "", ResourceLoader.CACHE_MODE_REPLACE) as AnimationLibrary
		if lib and lib.has_animation(clip):
			lib.remove_animation(clip)
			ResourceSaver.save(lib, lib_path)
	var anim_path := "%s/%s.res" % [HHCharacters.animation_dir(character_id), clip]
	if FileAccess.file_exists(anim_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(anim_path))


static func clip_name_for(take: HHTake, take_path: String) -> String:
	var n := take.clip_name.strip_edges() if take.clip_name else ""
	if n.is_empty():
		n = take_path.get_file().get_basename()
	return n.validate_filename().replace(" ", "_")


# Path from the rig root to a node, e.g. "Core/ArmL/Wrist".
static func node_path(rig: Node, node: Node) -> String:
	var parts := PackedStringArray()
	var n := node
	while n != null and n != rig:
		parts.insert(0, n.name)
		n = n.get_parent()
	return "/".join(parts)


# Adds one track; a channel that never changes gets a single key.
static func _add_track(anim: Animation, type: int, path: String, values: Array, dt: float) -> int:
	if values.is_empty():
		return 0
	var constant := true
	for v in values:
		if not _approx(v, values[0]):
			constant = false
			break
	var idx := anim.add_track(type)
	anim.track_set_path(idx, NodePath(path))
	if type == Animation.TYPE_ROTATION_3D:
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	var keys := 1 if constant else values.size()
	for i in keys:
		var t := i * dt
		match type:
			Animation.TYPE_POSITION_3D:
				anim.position_track_insert_key(idx, t, values[i])
			Animation.TYPE_ROTATION_3D:
				anim.rotation_track_insert_key(idx, t, values[i])
			Animation.TYPE_SCALE_3D:
				anim.scale_track_insert_key(idx, t, values[i])
			_:
				anim.track_insert_key(idx, t, values[i])
	return 1


static func _approx(a: Variant, b: Variant) -> bool:
	if a is Vector3:
		return (a as Vector3).distance_squared_to(b) < 1e-10
	if a is Quaternion:
		return absf((a as Quaternion).dot(b)) > 0.9999999
	if a is float:
		return absf(a - b) < 1e-6
	return a == b
