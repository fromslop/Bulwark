# Rebakes every take into its character's animation library.
#
#   Godot --headless --xr-mode off --path . --script res://addons/headnhands/tools/bake_all.gd
#   Godot ... --script res://addons/headnhands/tools/bake_all.gd -- --character puppet
#   Godot ... --script res://addons/headnhands/tools/bake_all.gd -- --take res://takes/take_X.res
#
# (The same thing is available as buttons in the editor's Takes dock.)
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only_character := _arg(args, "--character")
	var only_take := _arg(args, "--take")
	var paths := PackedStringArray([only_take]) if only_take else HHTakeStore.list()
	var ok := 0
	var failed := 0
	for path in paths:
		var take := HHTakeStore.load_take(path)
		if take == null:
			print("SKIP  %s (not a take)" % path)
			continue
		if take.character_id.is_empty():
			print("SKIP  %s (no character chosen)" % path)
			continue
		if only_character and take.character_id != only_character:
			continue
		var r := HHBaker.bake_to_library(take, path, take.character_id)
		if r.ok:
			ok += 1
			print("BAKED %s -> %s/%s  (%s)" % [path.get_file(), take.character_id, r.clip, HHTakeStore.describe_report(r.report)])
		else:
			failed += 1
			print("FAIL  %s: %s" % [path, str(r.report.get("notes", []))])
	print("%d baked, %d failed" % [ok, failed])
	quit(1 if failed > 0 else 0)


static func _arg(args: PackedStringArray, name: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""
