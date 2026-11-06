@tool
## Hoardsman's cue list for the HeadnHands recorder, built straight from EnemyDefs so it's
## always in step with the game: every clip each foe needs performed, with what to do and,
## for attacks, which attack it is and its wind-up time at the foe's own speed (the
## recording suite shows the attack's field and times the take from these).
## Project Settings > headnhands/cues/provider points here; tools/shot_list.gd writes the
## same list out as a plain cue sheet (shot_list.txt) for reading at the desk.
##
## Each cue: {character, clip, what, kind, enemy, attack, windup, loops, title, where}
##   kind     "idle", "attack", "guard" or "reaction" (no deaths: a foe goes over like a
##            cardboard cutout, the game's own fall)
##   enemy    the EnemyDefs id ("WARDEN" for the Vault Warden)
##   attack   the EnemyDefs.ATTACKS id an act_ clip performs ("" if none)
##   windup   seconds from the start of the wind-up to the strike (0 if none)
##   windup2, gap   a combo's second wind-up, and the pause before it
class_name HoardsmanCues
extends HHCueProvider

## A combo's pause between its blows, as the game times it (enemy.gd: the follow-through
## after a strike, 0.55 s at the foe's speed, then the follow-up's short wait).
const COMBO_GAP := 0.55
const COMBO_PAUSE := 0.15

## What each wind-up pose is, in performer's words (an attack's own "act" note comes first).
const POSE_TEXT := {
	"high_right": "weapon raised by the right shoulder, cut across to the left at head height",
	"high_left": "weapon raised by the left shoulder, cut across to the right at head height",
	"low": "weapon drawn back low on the right, swept across low to the left",
	"low_left": "weapon drawn back low on the left, swept across low to the right",
	"overhead_l": "raised high on the left, brought straight down",
	"overhead_r": "raised high on the right, brought straight down",
	"thrust": "drawn back, then thrust straight out at the player",
	"sweep": "a wide sweep from high right down across to the left",
	"slam": "both hands raised overhead, slammed down",
	"lunge": "weapon drawn back level, then the whole arm shoots forward",
	"spit": "the head rears back, then jerks forward (a spit); hands stay low",
	"grasp": "both hands reach out of the screen toward the player's hand",
	"bash": "the off-hand shield swung across in a shove; the weapon hand stays",
	"off_high": "the LEFT hand's blade from high left, cutting across; the right stays ready",
	"off_low": "the LEFT hand's blade low from the left, cutting across",
	"reap": "both hands on a long pole, its head swung low and wide from left to right",
}
const IDLE_TEXT := {
	"steady": "standing ready, weight even, eyes on the player's hand",
	"heavy": "heavy breathing, weight shifting foot to foot, weapon low",
	"bounce": "light on the toes, bouncing, weapon point moving",
	"shamble": "slumped, swaying, something loose about it",
	"drift": "floating: slow drifting sway, hands hanging open",
	"guard": "shield up and forward, weapon held back behind it",
}


## Sharing. Foes of a kind perform alike, so one take serves them all: it's baked through
## each one's own rig (its size, reach and weapon), not copied. A cue is shared by every
## foe with the same sharing key, and performed by its OWNER: a foe with its own take of
## it keeps that; the rest take the first of their group with a take, or the first of them
## in the roster. Your ASSIGNMENTS (the studio's Assign window) come first: per foe and
## clip, its own take, another foe's, or not needed at all.
##   attacks, guards and combos   the same move with the same GRIP (how the weapon's swung)
##   idles                        the same idle style, BUILD and grip
##   reactions and deaths         the same BUILD (it's the body that reels and falls)
## A foe with no grip or build listed is one of a kind and shares nothing.
const GRIP := {"sword": "blade", "twin": "blade", "rapier": "blade", "rusted": "blade", "shield": "blade",
	"axe": "chopper", "mace": "chopper", "halberd": "pole", "staff": "pole", "bell": "pole",
	"maul": "maul", "flail": "flail"}
const BUILD := {"Footman": "soldier", "Knight": "soldier", "WARDEN": "soldier", "Castellan": "soldier",
	"Bonebreaker": "soldier", "Twinblade": "soldier", "Duelist": "soldier", "Halberdier": "soldier",
	"Rusted": "soldier", "Zealot": "soldier", "Woodcutter": "heavy", "Brute": "heavy", "Headsman": "heavy",
	"The Astronomer": "robed", "Lamplighter": "robed", "Sexton": "robed"}


func cues(character := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in build():
		if character == "" or c.character == character:
			out.append(c)
	return out


## What a cue is shared by ("" = nobody: this foe performs its own).
static func share_key(c: Dictionary) -> String:
	var d := def_of(str(c.enemy))
	var grip: String = GRIP.get(str(d.get("weapon", "")), "")
	var build_of: String = BUILD.get(str(c.enemy), "")
	match str(c.kind):
		"attack", "guard":
			return "%s|%s" % [c.clip, grip] if grip != "" else ""
		"idle":
			return "%s|%s|%s" % [c.clip, build_of, grip] if grip != "" and build_of != "" else ""
		_:
			return "%s|%s" % [c.clip, build_of] if build_of != "" else ""


## Marks who performs each cue. owner: the character whose take it uses (itself, another,
## or "" if it's not needed); shared: someone else performs it; skipped: not needed (the
## foe keeps its procedural motion); assigned: what you chose in the Assign window ("" for
## automatic, "own", a character id, or "skip").
static func _share(rows: Array[Dictionary]) -> void:
	var owners := {}  # sharing key -> its automatic owner
	for c in rows:
		var key := share_key(c)
		if key != "" and not owners.has(key) and _has_take(str(c.character), str(c.clip)):
			owners[key] = c.character
	for c in rows:
		var key := share_key(c)
		var pick := assignment(str(c.character), str(c.clip))
		c.assigned = pick
		c.skipped = pick == "skip"
		if pick == "skip":
			c.owner = ""
		elif pick == "own":
			c.owner = c.character
		elif pick != "":
			c.owner = pick
		elif key == "" or _has_take(str(c.character), str(c.clip)):
			c.owner = c.character  # one of a kind, or it has its own take: it keeps it
		else:
			if not owners.has(key):
				owners[key] = c.character
			c.owner = owners[key]
		c.shared = c.owner != c.character and not c.skipped


## Every other foe a take of this foe's clip should be baked for: the foes whose clip it
## owns (automatically, or because you assigned it).
static func sharers(character: String, clip: String) -> PackedStringArray:
	var out := PackedStringArray()
	for c in build():
		if c.clip == clip and c.owner == character and c.character != character:
			out.append(c.character)
	return out


## Who would perform a foe's clip if you left it to the studio: the foe itself if it has a
## take (or shares the clip with nobody), else the first foe with the same grip or build
## that has one, else the first such foe in the roster.
static func auto_owner(character: String, clip: String) -> String:
	var rows := build()
	var key := ""
	for c in rows:
		if c.character == character and c.clip == clip:
			key = share_key(c)
	if key == "" or _has_take(character, clip):
		return character
	var first := ""
	for c in rows:
		if share_key(c) == key:
			if _has_take(str(c.character), clip):
				return c.character
			if first == "":
				first = c.character
	return first if first != "" else character


## The foes that could lend a clip: every other foe with the same clip in its list,
## [character id, has a take of it].
static func sources(character: String, clip: String) -> Array:
	var out := []
	for c in build():
		if c.clip == clip and c.character != character:
			out.append([c.character, _has_take(str(c.character), clip)])
	return out


# --- your assignments (recording/assignments.cfg) -----------------------------------

static var ASSIGNMENTS := "res://recording/assignments.cfg"  # (tests point it elsewhere)
static var _assign: ConfigFile


## What you chose for a foe's clip: "" (automatic), "own", "skip", or a character id.
static func assignment(character: String, clip: String) -> String:
	if _assign == null:
		_assign = ConfigFile.new()
		_assign.load(ASSIGNMENTS)
	return str(_assign.get_value(character, clip, ""))


## Sets (or with "", clears) a choice and saves it.
static func assign(character: String, clip: String, pick: String) -> void:
	assignment(character, clip)  # (loads the file)
	if pick == "":
		if _assign.has_section_key(character, clip):
			_assign.erase_section_key(character, clip)
	else:
		_assign.set_value(character, clip, pick)
	_assign.save(ASSIGNMENTS)
	invalidate()


## Forget the loaded choices (tests point ASSIGNMENTS elsewhere by clearing them).
static func reload_assignments() -> void:
	_assign = null
	invalidate()


static func _has_take(character: String, clip: String) -> bool:
	var key := HHTakeStore.takes_dir.path_join(character)
	if not _takes.has(key):
		var names := PackedStringArray()
		if DirAccess.dir_exists_absolute(key):
			for f in DirAccess.get_files_at(key):
				names.append(f.get_basename())
		_takes[key] = names
	for n in _takes[key]:
		if n == clip or n.begins_with(clip + "_") and n.trim_prefix(clip + "_").is_valid_int():
			return true
	return false


## Every foe the recorder can perform, in roster order: [EnemyDefs id, its definition].
static func foes() -> Array:
	var out: Array = []
	for id in EnemyDefs.ENEMIES:
		if id != "Errata":  # a misprint of the last foe, in ink: it plays that foe's clips
			out.append([id, EnemyDefs.ENEMIES[id]])
	out.append(["WARDEN", EnemyDefs.WARDEN])
	return out


## A foe's definition by its EnemyDefs id ("WARDEN" too).
static func def_of(id: String) -> Dictionary:
	return EnemyDefs.WARDEN if id == "WARDEN" else EnemyDefs.ENEMIES[id]


## A foe's character id: its model's name ("Pyre Zealot" -> "pyre_zealot").
static func slug(d: Dictionary) -> String:
	return Enemy.model_path(d).get_file().get_basename()


## The whole list is worked out once a frame: the studio's windows ask for it many times
## over when they redraw (once per foe on the cast board), and each time costs a look in
## every foe's takes folder. invalidate() forgets it (a choice made, a take saved).
static var _built: Array[Dictionary] = []
static var _built_frame := -1
static var _takes := {}  # character id -> the take names in its folder, for one build


static func invalidate() -> void:
	_built_frame = -1
	_takes.clear()


static func build() -> Array[Dictionary]:
	var frame := Engine.get_process_frames()
	if frame == _built_frame and not _built.is_empty():
		return _built
	_takes.clear()
	var out: Array[Dictionary] = []
	for pair in foes():
		var id: String = pair[0]
		var d: Dictionary = pair[1]
		var who := slug(d)
		var spd: float = float(d.get("speed", 1.0))
		var idle: String = d.get("idle", "steady")
		out.append(_row(who, id, d, "idle_" + idle, "idle", "%s (loops)" % IDLE_TEXT.get(idle, "standing ready"), "", 0.0, true))
		var done := {}
		for a in d.attacks:
			if done.has(a):
				continue
			done[a] = true
			out.append(_attack(who, id, d, a, spd))
			var nxt: String = EnemyDefs.ATTACKS[a].get("next", "")
			if nxt != "" and not done.has(nxt):
				done[nxt] = true
				out.append(_attack(who, id, d, nxt, spd, float(EnemyDefs.ATTACKS[a].get("next_windup", 0.6))))
		for a in d.get("combos", {}).values():
			if not done.has(a):
				done[a] = true
				out.append(_attack(who, id, d, a, spd))
		if d.has("riposte") and not done.has(d.riposte):
			out.append(_attack(who, id, d, d.riposte, spd, float(d.get("riposte_windup", -1.0))))
		# (feints need no clip of their own: the game plays the attack it starts and blends
		# into the one it switches to)
		if d.has("combos"):
			for k in d.combos:
				var row := _attack(who, id, d, k, spd)
				row.clip = "act_combo_" + k
				row.windup2 = float(d.get("combo_windup", 0.6)) / spd
				row.gap = COMBO_GAP / spd + COMBO_PAUSE
				row.what = "%s, and without resetting run straight into %s (%.2fs, then %.2fs wind-up)" % [_name(k), _name(d.combos[k]), row.windup, row.windup2]
				out.append(row)
		if d.has("guard_stance"):
			var how := "shield up and forward" if d.get("guard", false) else "blade level across the body, off hand on it"
			out.append(_row(who, id, d, "act_guard", "guard", "raise the guard: %s, hold it %.1f-%.1fs, then drop it back to ready" % [how, float(d.guard_stance.time[0]), float(d.guard_stance.time[1])], "", 0.0))
		out.append(_row(who, id, d, "act_flinch", "reaction", "a hit lands: a sharp recoil, then back to ready", "", 0.0))
		out.append(_row(who, id, d, "act_stagger", "reaction", "knocked out of whatever it was doing (a parry, a shock): snap back off balance, guard open, about a second, then recover. The game cuts into this from any moment, mid-swing included", "", 0.0))
		out.append(_row(who, id, d, "act_broken", "reaction", "the stagger meter breaks: slumped, dazed, open, for a few seconds", "", 0.0))
	_share(out)
	_built = out
	_built_frame = frame
	return out


## The list as cue-sheet text (tools/shot_list.gd writes it to shot_list.txt).
static func sheet() -> String:
	var lines: PackedStringArray = [
		"# Hoardsman: the shot list, as a HeadnHands cue sheet (tools/shot_list.gd writes it).",
		"#   character | clip | what to perform",
		"# Wind-up times are at the foe's own speed: hold the wind-up that long, then strike.",
		"# A field that moves (pan, turn, chase) is the weapon moving: perform the motion.",
	]
	var last := ""
	for c in build():
		if c.character != last:
			last = c.character
			lines.append("")
			lines.append("# --- %s (%s)" % [c.title, c.where])
		lines.append("%s | %s | %s" % [c.character, c.clip, c.what])
	lines.append("")
	return "\n".join(lines)


static func _name(id: String) -> String:
	return str(Codex.ATTACK_NAMES.get(id, id.replace("_", " "))).to_lower()


static func _row(who: String, id: String, d: Dictionary, clip: String, kind: String, what: String, attack: String, windup: float, loops := false) -> Dictionary:
	if windup > 0.0:
		what += " (%.2fs wind-up)" % windup
	return {"character": who, "clip": clip, "what": what, "kind": kind, "enemy": id, "attack": attack,
		"windup": windup, "loops": loops, "title": str(d.name), "where": Codex.foe_where(d)}


static func _attack(who: String, id: String, d: Dictionary, a: String, spd: float, windup := -1.0) -> Dictionary:
	var at: Dictionary = EnemyDefs.ATTACKS[a]
	var what: String = at.get("act", POSE_TEXT.get(at.pose, at.pose))
	var w: float = (float(at.windup) if windup < 0.0 else windup) / spd
	var notes: Array = ["%.2fs wind-up" % w]
	if at.has("pan"):
		notes.append("the weapon travels as it winds up (pan)")
	if at.has("turn"):
		notes.append("the swing's line turns as it winds up")
	if at.has("chase"):
		notes.append("follow the player's hand for the first %d%%, then commit" % roundi(float(at.chase) * 100.0))
	if at.get("track", false):
		notes.append("aimed at the player's hand")
	if at.has("next"):
		notes.append("then straight into %s" % _name(at.next))
	var row := _row(who, id, d, "act_" + a, "attack", "%s (%s)" % [what, "; ".join(PackedStringArray(notes))], a, 0.0)
	row.windup = w
	return row
