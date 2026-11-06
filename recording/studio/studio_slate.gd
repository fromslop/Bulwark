## The slate: the one window to read while performing. It sits low and straight ahead, under
## the mirror, so a glance down tells you what you're doing and whether you're rolling.
##
##   [ STATE ]   CHARACTER · CLIP                               WIND-UP
##               what to perform, in plain words                0.80 s
##   ─────────────────────────────────────────────────────────────────────
##   the controls that matter right now
class_name StudioSlate
extends HHPanel

var studio
var _state: Label
var _state_box: PanelContainer
var _who: Label
var _clip: Label
var _what: Label
var _time_caption: Label
var _time: Label
var _kind: Label
var _hints: Label
var _beat: StudioBeat
var _col := Color.BLACK


func _init(p_studio) -> void:
	super._init("Slate", Vector2(1.05, 0.27))
	studio = p_studio
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# the state light: READY / 3 / REC 00:04.2
	_state_box = PanelContainer.new()
	_state_box.custom_minimum_size = Vector2(250, 150)
	_state_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_state_box)
	_state = HHStyle.label("READY", HHStyle.SIZE_TITLE, HHStyle.ACCENT, HHStyle.bold())
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_box.add_child(_state)
	# what you're performing
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	mid.add_child(line)
	_who = HHStyle.label("", HHStyle.SIZE_BODY, HHStyle.TEXT_DIM, HHStyle.bold())
	line.add_child(_who)
	_kind = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold())
	_kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_kind)
	_clip = HHStyle.label("", HHStyle.SIZE_HERO, HHStyle.TEXT, HHStyle.bold())
	_clip.clip_text = true
	mid.add_child(_clip)
	_what = HHStyle.label("", HHStyle.SIZE_BODY, HHStyle.TEXT_DIM)
	_what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_what.max_lines_visible = 2
	mid.add_child(_what)
	# the wind-up time, big: it's the beat the take has to land on
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(230, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	_time_caption = HHStyle.label("WIND-UP", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.bold())
	_time_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_time_caption)
	_time = HHStyle.label("", HHStyle.SIZE_HERO, HHStyle.WARN, HHStyle.mono())
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_time)
	_beat = StudioBeat.new()
	body.add_child(_beat)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.07)
	rule.custom_minimum_size = Vector2(0, 2)
	body.add_child(rule)
	_hints = HHStyle.label("", HHStyle.SIZE_SMALL, HHStyle.TEXT_FAINT, HHStyle.mono())
	body.add_child(_hints)


func refresh() -> void:
	var cue: Dictionary = studio.current_cue()
	var who := "No character"
	if studio.character:
		who = studio.character.profile.display_name
	_who.text = who.to_upper()
	if cue.is_empty():
		_clip.text = "Free take"
		_what.text = "Not tied to a cue: name it afterwards in the Takes dock." if studio.character else "Pick a character on the Cast board."
		_kind.text = ""
	else:
		_clip.text = StudioSlate.clip_title(cue)
		_what.text = StudioSlate.direction(cue)
		_kind.text = "·   %s%s" % [str(cue.kind).to_upper(), "   ·   RECORDED" if cue.recorded else ""]
		_kind.add_theme_color_override("font_color", HHStyle.OK if cue.recorded else HHStyle.TEXT_FAINT)
	var w := float(cue.get("windup", 0.0))
	var w2 := float(cue.get("windup2", 0.0))
	_time.text = ("%.2f s" % w if w2 <= 0.0 else "%.2f + %.2f" % [w, w2]) if w > 0.0 else ("loop" if cue.get("loops", false) else "free")
	_time.add_theme_color_override("font_color", HHStyle.WARN if w > 0.0 else HHStyle.TEXT_DIM)
	_time_caption.text = "WIND-UP" if w > 0.0 else "LENGTH"
	tick()


## Every frame: the state light and the hints follow what the recorder's doing.
func tick() -> void:
	var col: Color = HHStyle.ACCENT
	var text := "READY"
	if studio.state == studio.State.COUNTDOWN:
		col = HHStyle.WARN
		text = "%d" % ceili(studio.countdown)
		_hints.text = "STAND ON THE MARK  ·  LOOK AHEAD  ·  MENU to cancel"
	elif studio.is_recording():
		col = HHStyle.REC
		var t: float = studio.recording_time()
		text = "●  %02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
		_hints.text = "RECORDING  ·  MENU to stop"
		var g: StudioGuide = studio.guide
		if g:
			match g.phase(t):
				"settle":
					text = "SETTLE"
					col = HHStyle.TEXT_DIM
					_hints.text = "HOLD THE READY POSE  ·  the wind-up starts on the tone"
				"windup":
					text = "WIND-UP"
					col = HHStyle.WARN
					_hints.text = "WIND UP  ·  strike on the high tone  ·  TRIGGER as your blow lands"
				"gap":
					text = "STRIKE" if t - g.strike_at() < 0.35 else "AGAIN"
					col = HHStyle.REC if t - g.strike_at() < 0.35 else HHStyle.TEXT_DIM
					_hints.text = "FIRST BLOW IN  ·  straight into the second  ·  TRIGGER on each blow"
				"windup2":
					text = "WIND-UP 2"
					col = HHStyle.WARN
					_hints.text = "SECOND WIND-UP  ·  strike on the high tone"
				"follow":
					text = "STRIKE" if t - g.last_strike_at() < 0.35 else "FOLLOW"
					col = HHStyle.REC
					_hints.text = "FOLLOW THROUGH  ·  back to the ready pose  ·  stops by itself"
	else:
		if studio.replay:
			text = "REPLAY"
			col = HHStyle.OK
		var punch: String = studio.punch_group()
		_hints.text = "MENU  record     ◀ ▶  cue     A  %s%s" % [
			"live" if studio.replay else "replay", ("     PUNCH-IN: " + punch.to_upper()) if punch != "" else ""]
	if _state.text != text:
		_state.text = text
		_state.add_theme_font_size_override("font_size", HHStyle.SIZE_HERO if text.length() <= 2 else HHStyle.SIZE_TITLE)
	if col != _col:
		_col = col
		_state.add_theme_color_override("font_color", col)
		_state_box.add_theme_stylebox_override("panel", HHStyle.fill(Color(col, 0.12), 14, Color(col, 0.55)))
	var n: int = studio.cues.size()
	set_subtitle("CUE %d / %d" % [studio.cue_index + 1, n] if studio.cue_index >= 0 else ("FREE TAKE" if n > 0 else ""))
	_beat.guide = studio.guide if studio.is_recording() and studio.guide else studio.plan
	_beat.t = studio.recording_time() if studio.is_recording() and studio.guide else -1.0
	_beat.visible = _beat.guide != null
	_beat.queue_redraw()


## What to perform, in a sentence: the cue's direction without its timing (the slate shows
## that big), with what the attack does in the game after it.
static func direction(cue: Dictionary) -> String:
	var what := str(cue.what)
	var cut := what.rfind(" (")
	if cut > 0 and what.ends_with(")"):
		what = what.substr(0, cut)
	return _sentence(what) + "."


## A clip's name in plain words: an attack by the codex's name for it ("High slash, from
## the right"), a combo as its two blows ("Overhead, left  →  Thrust"), an idle as "Idle ·
## steady".
static func clip_title(cue: Dictionary) -> String:
	var clip := str(cue.clip)
	if clip.begins_with("idle_"):
		return "Idle  ·  " + clip.trim_prefix("idle_").replace("_", " ")
	if clip.begins_with("act_combo_"):
		var k := clip.trim_prefix("act_combo_")
		var d: Dictionary = HoardsmanCues.def_of(str(cue.get("enemy", "")))
		return "%s  →  %s" % [_attack_name(k), _attack_name(str(d.get("combos", {}).get(k, "")))]
	var a: String = cue.get("attack", "")
	if a != "" and clip == "act_" + a:
		return _attack_name(a)
	return _sentence(clip.trim_prefix("act_").replace("_", " "))


static func _attack_name(id: String) -> String:
	return _sentence(str(Codex.ATTACK_NAMES.get(id, id.replace("_", " "))))


static func _sentence(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t
