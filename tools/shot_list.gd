extends SceneTree
## Writes the performance shot list as a HeadnHands cue sheet (res://shot_list.txt): every
## clip each foe needs performed, one per line, `character | clip | what to perform`, the
## character being the foe's model slug. Point HeadnHands' Project Settings >
## headnhands/cues/sheet at a copy of it and the recorder steps through the cues in the
## headset (right stick). Built from EnemyDefs, so it's always in step with the game:
## re-run it after changing an enemy.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/shot_list.gd

const OUT := "res://shot_list.txt"

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


func _initialize() -> void:
	var lines: PackedStringArray = [
		"# Hoardsman: the shot list, as a HeadnHands cue sheet (tools/shot_list.gd writes it).",
		"#   character | clip | what to perform",
		"# Wind-up times are at the foe's own speed: hold the wind-up that long, then strike.",
		"# A field that moves (pan, turn, chase) is the weapon moving: perform the motion.",
		"",
	]
	var foes: Array = EnemyDefs.ENEMIES.values()
	foes.append(EnemyDefs.WARDEN)
	for d in foes:
		var who := Enemy.model_path(d).get_file().get_basename()
		var spd: float = float(d.get("speed", 1.0))
		lines.append("# --- %s (%s)" % [d.name, Codex.foe_where(d)])
		lines.append("%s | idle_%s | %s (loops)" % [who, d.get("idle", "steady"), IDLE_TEXT.get(d.get("idle", "steady"), "standing ready")])
		var done := {}
		for id in d.attacks:
			if done.has(id):
				continue
			done[id] = true
			lines.append(_cue(who, id, spd, d))
			var a: Dictionary = EnemyDefs.ATTACKS[id]
			var nxt: String = a.get("next", "")
			if nxt != "" and not done.has(nxt):
				done[nxt] = true
				lines.append(_cue(who, nxt, spd, d, float(a.get("next_windup", 0.6))))
		for id in d.get("combos", {}).values():
			if not done.has(id):
				done[id] = true
				lines.append(_cue(who, id, spd, d))
		if d.has("riposte") and not done.has(d.riposte):
			lines.append(_cue(who, d.riposte, spd, d))
		if d.has("feint"):
			lines.append("%s | act_feint | start any attack's wind-up, break it off about %d%% of the way in, and go straight into a different one (%.2fs wind-up)" %
				[who, roundi(float(d.feint.at) * 100.0), float(d.feint.windup) / spd])
		if d.has("combos"):
			for k in d.combos:
				lines.append("%s | act_combo_%s | %s, and without resetting run straight into %s (%.2fs)" % [who, k, _name(k), _name(d.combos[k]), float(d.get("combo_windup", 0.6)) / spd])
		lines.append("%s | act_flinch | a hit lands: a sharp recoil, then back to ready" % who)
		lines.append("%s | act_reel | thrown off balance by a parry: stumbling back, guard open, about a second" % who)
		lines.append("%s | act_broken | the stagger meter breaks: slumped, dazed, open, for a few seconds" % who)
		lines.append("%s | act_death | killed: it goes down" % who)
		lines.append("")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("shot list: %d cues -> %s" % [lines.size(), ProjectSettings.globalize_path(OUT)])
	quit(0)


func _name(id: String) -> String:
	return str(Codex.ATTACK_NAMES.get(id, id.replace("_", " "))).to_lower()


func _cue(who: String, id: String, spd: float, d: Dictionary, windup: float = -1.0) -> String:
	var a: Dictionary = EnemyDefs.ATTACKS[id]
	var what: String = a.get("act", POSE_TEXT.get(a.pose, a.pose))
	var w: float = (float(a.windup) if windup < 0.0 else windup) / spd
	var notes: Array = ["%.2fs wind-up" % w]
	if a.has("pan"):
		notes.append("the weapon travels as it winds up (pan)")
	if a.has("turn"):
		notes.append("the swing's line turns as it winds up")
	if a.has("chase"):
		notes.append("follow the player's hand for the first %d%%, then commit" % roundi(float(a.chase) * 100.0))
	if a.get("track", false):
		notes.append("aimed at the player's hand")
	if a.has("next"):
		notes.append("then straight into %s" % _name(a.next))
	return "%s | act_%s | %s (%s)" % [who, id, what, "; ".join(PackedStringArray(notes))]
