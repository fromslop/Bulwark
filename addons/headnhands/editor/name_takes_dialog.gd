# "Name your new takes": pops up in the editor after a run that recorded
# takes (and from the Takes panel's "Name takes..." button). One row per take
# still carrying its automatic timestamp name:
#
#   [Preview] character  length  [type v] [name.........] [x] loop  [Keep v]
#
# Save names writes the choices to a small JSON file and runs
# tools/apply_take_names.gd headless, which renames the takes to
# takes/<character>/<type>_<name>.res, bakes animations/<character>/<type>_<name>.res
# and updates the character's animation library. Discarded takes move to
# takes/_discarded/ (nothing is deleted).
@tool
extends ConfirmationDialog

signal applied(log_lines: PackedStringArray)

var rules: HHNamingRules

var grid: GridContainer
var rows := []   # [{path, type, name, loop, keep}]
var empty_label: Label


func _init() -> void:
	title = "Name your new takes"
	ok_button_text = "Save names"
	cancel_button_text = "Later"
	min_size = Vector2i(900, 420)
	var box := VBoxContainer.new()
	add_child(box)
	var intro := Label.new()
	intro.text = "Name each take. It becomes takes/<character>/<type>_<name> and the clip animations/<character>/<type>_<name>.\nPreview plays it in the take viewer. Leave a name blank to decide later."
	box.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(860, 300)
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	empty_label = Label.new()
	empty_label.text = "No unnamed takes."
	box.add_child(empty_label)
	confirmed.connect(_apply)


# Fills the list. Returns how many unnamed takes there are.
func populate() -> int:
	for c in grid.get_children():
		c.queue_free()
	rows.clear()
	rules = HHNamingRules.current()
	for header in ["", "Character", "Length   Time", "Type", "Name", "Loop", ""]:
		var h := Label.new()
		h.text = header
		grid.add_child(h)
	for path in find_unnamed():
		_add_row(path)
	empty_label.visible = rows.is_empty()
	return rows.size()


static func find_unnamed() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect(HHSettings.get_value("headnhands/paths/takes_dir"), paths)
	paths.sort()
	var out := PackedStringArray()
	for p in paths:
		if p.contains("/_discarded/") or p.contains("/sources/") or p.contains("/demo/"):
			continue
		if not p.get_file().begins_with("take_"):
			continue
		var t := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
		if t == null or t.get("sample_times") == null:
			continue
		if str(t.get("character_id")).is_empty() or not str(t.get("clip_name")).strip_edges().is_empty():
			continue
		out.append(p)
	return out


static func _collect(dir: String, out: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".res"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


func _add_row(path: String) -> void:
	var take := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var times: PackedFloat32Array = take.get("sample_times")
	var length := times[times.size() - 1] if times.size() > 0 else 0.0

	var preview := Button.new()
	preview.text = "Preview"
	preview.tooltip_text = path
	preview.pressed.connect(_preview.bind(path))
	grid.add_child(preview)

	var character := Label.new()
	character.text = str(take.get("character_id"))
	if path.contains("_punch_"):
		character.text += "  (punch-in)"
	grid.add_child(character)

	var len_label := Label.new()
	# "2026-09-29T14:18:24" -> "14:18"; helps tell takes apart.
	var created := str(take.get("created"))
	len_label.text = "%.1f s   %s" % [length, created.substr(11, 5) if created.length() >= 16 else ""]
	grid.add_child(len_label)

	var type := OptionButton.new()
	var types := rules.types()
	for l in rules.type_labels():
		type.add_item(l)
	type.select(maxi(0, types.find(rules.default_prefix)))
	grid.add_child(type)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "e.g. scan, weld_panel, intro_03"
	name_edit.custom_minimum_size.x = 260
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_edit)

	var loop := CheckBox.new()
	grid.add_child(loop)
	loop.button_pressed = rules.loop_prefixes.has(rules.default_prefix)
	type.item_selected.connect(func(i: int): loop.button_pressed = rules.loop_prefixes.has(types[i]))

	var keep := OptionButton.new()
	keep.add_item("Keep")
	keep.add_item("Discard")
	grid.add_child(keep)

	rows.append({"path": path, "type": type, "name": name_edit, "loop": loop, "keep": keep})


func _preview(path: String) -> void:
	OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), "--xr-mode", "off",
		"res://addons/headnhands/viewer/hh_viewer.tscn", "--", "--take", path]))


func _apply() -> void:
	var entries := []
	for r in rows:
		var discard: bool = (r.keep as OptionButton).selected == 1
		var name := (r.name as LineEdit).text.strip_edges()
		if not discard and name.is_empty():
			continue   # decide later
		entries.append({
			"path": r.path,
			"action": "discard" if discard else "keep",
			"type": rules.types()[(r.type as OptionButton).selected],
			"name": name,
			"loop": (r.loop as CheckBox).button_pressed,
		})
	if entries.is_empty():
		return
	var manifest := ProjectSettings.globalize_path("user://take_names.json")
	var f := FileAccess.open(manifest, FileAccess.WRITE)
	f.store_string(JSON.stringify(entries, "  "))
	f.close()
	var output := []
	OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--xr-mode", "off", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://addons/headnhands/tools/apply_take_names.gd", "--", "--manifest", manifest]), output, true)
	var lines := PackedStringArray()
	for chunk in output:
		for line in str(chunk).split("\n"):
			if line.begins_with("NAMED") or line.begins_with("DISCARDED") or line.begins_with("FAIL") or line.begins_with("SKIP"):
				lines.append(line)
	EditorInterface.get_resource_filesystem().scan()
	applied.emit(lines)
