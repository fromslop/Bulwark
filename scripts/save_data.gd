class_name SaveData
extends RefCounted
## What survives between runs: the gear kept at home (and where it hangs), everything the
## codex has seen, and how deep a run has ever gone. One text file in user://.

static var PATH := "user://bulwark_save.txt"  # tests point this elsewhere

var home: Array = []  # packed items: see pack()
var found := {"items": [], "modifiers": [], "foes": [], "places": [], "reactions": [], "secrets": []}
var prestige_best := 0
## Lifetime tallies, shown on the trophy board at home.
var stats := {"runs": 0, "deaths": 0, "bosses": 0, "kills": 0, "best_hit": 0, "smelt": 0.0}


static func load_file() -> SaveData:
	var s := SaveData.new()
	if not FileAccess.file_exists(PATH):
		return s
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return s
	var data = str_to_var(f.get_as_text())
	if data is Dictionary:
		s.home = data.get("home", [])
		s.prestige_best = int(data.get("prestige_best", 0))
		var fd: Dictionary = data.get("found", {})
		for k in s.found:
			s.found[k] = fd.get(k, [])
		var st: Dictionary = data.get("stats", {})
		for k in s.stats:
			s.stats[k] = float(st.get(k, 0.0)) if k == "smelt" else int(st.get(k, 0))
	return s


func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str({"home": home, "found": found, "prestige_best": prestige_best, "stats": stats}))


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
		var mods: Array = e.get("modifiers", [])
		d = ItemDefs.make(e.id, e.get("material", "wood"), mods.duplicate())
		if e.get("shape", "") != "":
			d.shape = e.shape
		d.size = float(e.get("size", 1.0))
		if d.has("swing_damage"):
			d.swing_damage = float(ItemDefs.DEFS[e.id].swing_damage) * d.size
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
