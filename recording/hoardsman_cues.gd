@tool
## Hoardsman's cue list for the HeadnHands recorder, built straight from EnemyDefs so it's
## always in step with the game: every clip each foe needs performed, with what to do and,
## for attacks, which attack it is and its wind-up time at the foe's own speed (the
## recording suite shows the attack's field and times the take from these).
## Project Settings > headnhands/cues/provider points here; tools/shot_list.gd writes the
## same list out as a plain cue sheet (shot_list.txt) for reading at the desk.
##
## Each cue: {character, clip, what, kind, enemy, attack, windup, loops, title, where}
##   kind     "idle", "attack", "guard", "reaction" or "death"
##   enemy    the EnemyDefs id ("WARDEN" for the Vault Warden)
##   attack   the EnemyDefs.ATTACKS id an act_ clip performs ("" if none)
##   windup   seconds from the start of the wind-up to the strike (0 if none)
class_name HoardsmanCues
extends HHCueProvider

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


func cues(character := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in build():
		if character == "" or c.character == character:
			out.append(c)
	return out


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


static func build() -> Array[Dictionary]:
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
		if d.has("feint"):
			out.append(_row(who, id, d, "act_feint", "attack", "start any attack's wind-up, break it off about %d%% of the way in, and go straight into a different one" % roundi(float(d.feint.at) * 100.0), "", float(d.feint.windup) / spd))
		if d.has("combos"):
			for k in d.combos:
				out.append(_row(who, id, d, "act_combo_" + k, "attack", "%s, and without resetting run straight into %s" % [_name(k), _name(d.combos[k])], k, float(d.get("combo_windup", 0.6)) / spd))
		if d.has("guard_stance"):
			var how := "shield up and forward" if d.get("guard", false) else "blade level across the body, off hand on it"
			out.append(_row(who, id, d, "act_guard", "guard", "raise the guard: %s, hold it %.1f-%.1fs, then drop it back to ready" % [how, float(d.guard_stance.time[0]), float(d.guard_stance.time[1])], "", 0.0))
		out.append(_row(who, id, d, "act_flinch", "reaction", "a hit lands: a sharp recoil, then back to ready", "", 0.0))
		out.append(_row(who, id, d, "act_stagger", "reaction", "knocked out of whatever it was doing (a parry, a shock): snap back off balance, guard open, about a second, then recover. The game cuts into this from any moment, mid-swing included", "", 0.0))
		out.append(_row(who, id, d, "act_broken", "reaction", "the stagger meter breaks: slumped, dazed, open, for a few seconds", "", 0.0))
		out.append(_row(who, id, d, "act_death", "death", "killed: it goes down", "", 0.0))
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
