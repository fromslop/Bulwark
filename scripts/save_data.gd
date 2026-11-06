class_name SaveData
extends RefCounted
## What survives between runs: the gear kept at home (and where it hangs), everything the
## codex has seen, and how deep a run has ever gone. One text file in user://.

static var PATH := "user://hoardsman_save.txt"  # tests point this elsewhere
static var wiping := false  # the save was just erased: nothing writes it back until a fresh load
const OLD_NAME := "Bulwark"  # what the game was called: its save and settings lived under that


## The game was called Bulwark, and its save and settings lived in a folder by that name.
## The first time it starts as Hoardsman they're brought across (copied: the old ones stay).
static func carry_over() -> void:
	var here := OS.get_user_data_dir()
	var old := here.get_base_dir().path_join(OLD_NAME)
	for pair in [["bulwark_save.txt", "hoardsman_save.txt"], ["settings.cfg", "settings.cfg"], ["looks.cfg", "looks.cfg"], ["style.cfg", "style.cfg"]]:
		if wiping and pair[1] == "hoardsman_save.txt":
			continue  # (just reset: don't bring the old one back)
		var src: String = old.path_join(pair[0])
		var dst: String = here.path_join(pair[1])
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.make_dir_recursive_absolute(here)
			DirAccess.copy_absolute(src, dst)

var home: Array = []  # packed items: see pack()
var storage: Array = []  # packed items put away in the storage cupboard at home (Storage)
var found := {"items": [], "modifiers": [], "foes": [], "places": [], "reactions": [], "secrets": [], "guardians": []}  # guardians: secret places' foes beaten (the relic shelf at home)
var prestige_best := 0
## Lifetime tallies, shown around the home (the tally on the wall, the trophy shelf...).
var stats := {"runs": 0, "deaths": 0, "bosses": 0, "kills": 0, "best_hit": 0, "smelt": 0.0, "melted_cups": 0}
var trophies: Array = []  # every boss felled whose cup you still have: [name, prestige]: on the rack at home


static func load_file() -> SaveData:
	wiping = false
	var s := SaveData.new()
	if not FileAccess.file_exists(PATH) and FileAccess.file_exists(PATH + ".tmp"):
		# (the last write didn't get as far as its rename: its temp file is the save)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH))
	if not FileAccess.file_exists(PATH):
		return s
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return s
	var data = str_to_var(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		# unreadable: put it aside rather than let the next save write over it
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".damaged"))
	if data is Dictionary:
		s.home = data.get("home", [])
		s.storage = data.get("storage", [])
		s.prestige_best = int(data.get("prestige_best", 0))
		var fd: Dictionary = data.get("found", {})
		for k in s.found:
			s.found[k] = fd.get(k, [])
		var st: Dictionary = data.get("stats", {})
		for k in s.stats:
			s.stats[k] = float(st.get(k, 0.0)) if k == "smelt" else int(st.get(k, 0))
		s.trophies = data.get("trophies", [])
		while s.trophies.size() + int(s.stats.melted_cups) < int(s.stats.bosses):
			s.trophies.append(["", 0])  # (bosses felled before the shelf was kept: plain cups)
	return s


## Erase the save for good (the pause menu's Reset save). Until the next load_file(), nothing
## writes it back (the scene being left behind would otherwise save its home on the way out).
static func wipe() -> void:
	wiping = true
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func write() -> void:
	if wiping:
		return
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(var_to_str({"home": home, "storage": storage, "found": found, "prestige_best": prestige_best, "stats": stats, "trophies": trophies}))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))  # (whole or not at all)


func discover(category: String, id: String) -> void:
	if id == "" or not found.has(category):
		return
	if not found[category].has(id):
		found[category].append(id)


func tally(stat: String, by: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + by


func knows(category: String, id: String) -> bool:
	return found.get(category, []).has(id)


## Everything needed to make this item again, and what it has been through.
static func pack(it: Item) -> Dictionary:
	var d := it.def
	var e := {"kind": d.kind, "pos": it.global_position, "rot": it.rotation, "health": it.health_ratio(),
		"material": d.get("material", "wood"), "modifiers": d.modifiers.duplicate(), "shape": d.get("shape", ""),
		"size": d.get("size", 1.0), "boss_kills": int(d.get("boss_kills", 0)), "kills": int(d.get("kills", 0))}
	if d.kind == "upgrade":
		e.upgrade = d.upgrade
	else:
		e.id = d.get("id", "")
	if d.has("custom_name"):
		e.custom_name = d.custom_name
	if d.has("parts"):
		e.parts = d.parts.duplicate(true)
		e.fused_cells = it.cells.duplicate(true)
		e.fused_origin = it.origin
		e.fused_name = d.get("name", "")
		e.fused_kind = d.kind
	if d.has("value"):
		e.value = d.value
	return e


## Back into an item def. Empty if the save names something that no longer exists.
static func unpack(e: Dictionary) -> Dictionary:
	var d: Dictionary
	if e.get("kind", "") == "upgrade":
		if not ItemDefs.UPGRADES.has(e.get("upgrade", "")):
			return {}
		d = ItemDefs.make_upgrade(e.upgrade)
	else:
		if not ItemDefs.DEFS.has(e.get("id", "")):
			return {}
		var mods: Array = ItemDefs.current_mods(e.get("modifiers", []))  # (renamed modifiers mapped first)
		d = ItemDefs.make(e.id, e.get("material", "wood"), mods.duplicate())
		for m in mods:
			if not d.modifiers.has(m):
				d.modifiers.append(m)  # a fixed-modifier piece keeps what it gained on top (an altar, a glue pot...)
		if e.get("shape", "") != "":
			d.shape = e.shape
		d.size = float(e.get("size", 1.0))
		if d.has("swing_damage"):
			d.swing_damage = float(ItemDefs.DEFS[e.id].swing_damage)  # (its size counts through its pixels)
			if d.get("ascended", false):
				d.swing_damage *= ItemDefs.ASCEND_DAMAGE
	if e.has("custom_name"):
		d.custom_name = e.custom_name
	if e.has("fused_cells"):
		d.parts = e.parts
		d.fused = true
		d.fused_cells = e.fused_cells
		d.fused_origin = e.get("fused_origin", Vector2.ZERO)
		d.name = e.get("fused_name", d.get("name", ""))
		d.kind = e.get("fused_kind", d.kind)
	d.boss_kills = int(e.get("boss_kills", 0))
	d.kills = int(e.get("kills", 0))
	return d


static func apply_health(it: Item, ratio: float) -> void:
	for c in it.cells:
		it.cells[c].hp = it.cells[c].max * clampf(ratio, 0.1, 1.0)
	it.queue_redraw()
