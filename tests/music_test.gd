extends SceneTree
## The score's timing: a fight's drums build up on bar lines, a boss goes straight to full
## drums and then works through melody / bridge / arp / bridge without repeating a melody,
## the shop drops the drums, home stops the score. Uses the music node alone, no files needed.
## Run: Godot_console.exe --headless --fixed-fps 60 --path . -s res://tests/music_test.gd

var music: Music
var frame := 0
var fails := PackedStringArray()


func _initialize() -> void:
	music = Music.new()
	root.add_child(music)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


## When the trace says `what` happened first, at or after `since`; -1 if never.
func _when(what: String, since := 0.0) -> float:
	for t in music.trace:
		if t[1] == what and t[0] >= since - 0.1:
			return t[0]
	return -1.0


func _on_bar(t: float) -> bool:
	var off := fposmod(t + 0.1, Music.BAR) - 0.1
	return absf(off) <= 0.1


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		5:
			music.set_mode(Music.Mode.FIGHT)
		11 * 60:  # 11 s in
			var kick := _when("drum_kick -> 1")
			var full := _when("drum_full -> 1")
			var claps := _when("drum_claps -> 1")
			_check(kick >= 0.0 and kick < 0.2, "a fight should bring the kick in at once (%.2f)" % kick)
			_check(absf(full - Music.FULL_AFTER * Music.BAR) < 0.1, "the full kit should come in %d bars later (%.2f)" % [Music.FULL_AFTER, full])
			_check(absf(claps - Music.CLAPS_AFTER * Music.BAR) < 0.1, "the claps should join after %d bars (%.2f)" % [Music.CLAPS_AFTER, claps])
			_check(_when("drum_kick -> 0") > 0.0, "the kick-only loop should drop out when the full kit comes in")
			music.set_mode(Music.Mode.CALM)
		13 * 60:
			var out := _when("drum_full -> 0", 11.0)
			_check(out >= 0.0 and _on_bar(out), "the shop should drop the drums on a bar line (%.2f)" % out)
			_check(music._target.base_bass == 1.0, "the base should play on through the shop")
			music.set_mode(Music.Mode.BOSS)
		15 * 60:
			var t := _when("drum_full -> 1", 13.0)
			_check(t >= 0.0 and _on_bar(t + Music.SWITCH), "a boss should bring the full drums in on the next bar line (%.2f)" % t)
			_check(_when("drum_claps -> 1", 13.0) >= 0.0, "a boss should start with the claps already in")
		80 * 60:
			var leads: Array = []
			for tr in music.trace:
				if String(tr[1]).begins_with("lead "):
					leads.append([tr[0], String(tr[1]).substr(5)])
			_check(leads.size() >= 8, "the boss guitar should have played a run of phrases (%d)" % leads.size())
			if leads.size() >= 2:
				var boss_line := _when("mode BOSS")
				_check(leads[0][0] - boss_line >= Music.LEAD_AFTER * Music.BAR - 0.1, "the first melody should wait %d bars of drums" % Music.LEAD_AFTER)
				_check(Music.MELODIES.has(leads[0][1]), "the boss should open with a melody (%s)" % leads[0][1])
			var order: Array = []
			for l in leads:
				_check(_on_bar(l[0]), "every phrase should start on a bar line (%s at %.2f)" % [l[1], l[0]])
				if order.is_empty() or order[-1] != l[1]:
					order.append(l[1])
			var melodies := order.filter(func(x): return Music.MELODIES.has(x))
			for i in range(1, melodies.size()):
				_check(melodies[i] != melodies[i - 1], "the same melody shouldn't come round twice in a row (%s)" % [order])
			for i in range(1, order.size()):
				var both := [Music.MELODIES.has(order[i - 1]), Music.MELODIES.has(order[i])]
				_check(both != [true, true], "two melodies shouldn't play back to back (%s)" % [order])
			print("boss phrases: ", order)
			music.set_mode(Music.Mode.AMBIENT)
		85 * 60:
			_check(_when("stopped", 79.0) >= 0.0, "home should fade the score out and stop it")
			_check(music._target.amb_night == 1.0 and music._target.amb_cinder == 0.0, "home should bring up the night (fire and crickets)")
			music.set_mode(Music.Mode.FIGHT)
		86 * 60:
			_check(music.trace.filter(func(x): return x[1] == "start").size() == 2 and music._clock < 2.5, "the next run should start the score from the top")
			print("music test: %d failures" % fails.size())
			for f in fails:
				print("  FAIL ", f)
			quit(1 if fails.size() > 0 else 0)
	return false
