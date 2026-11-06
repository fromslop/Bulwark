## The beat an attack take is performed to. After the 3-2-1, recording runs:
##
##   SETTLE      hold the ready pose (where the rest-pose ghosts are)       LEAD s
##   WIND-UP     a tone, and the bar fills over the attack's game wind-up   W s
##   STRIKE      a high tone and a buzz: the blow lands now. Pull the trigger
##               the moment yours does, and that's the mark the clip is fitted to
##   FOLLOW      the follow-through; the take stops by itself              FOLLOW s
##
## A combo has two blows: after the first strike comes the game's pause between them
## (GAP), then the second wind-up and strike, then the follow-through.
##
## The take keeps its marks: "windup" (when the first wind-up tone sounded), "strike" and
## for a combo "strike2" (your trigger pulls, or the guide's strikes if you didn't pull).
## Baking pins them to the game's own times (HHCleanupRecipe.fit_marks), so its blows land
## on yours however fast you actually swung.
class_name StudioGuide
extends RefCounted

const LEAD := 1.0
const FOLLOW := 1.5
const TRIGGER_ON := 0.7

var windup := 0.0    # the (first) wind-up, seconds
var windup2 := 0.0   # a combo's second wind-up (0: not a combo)
var gap := 0.0       # a combo's pause between the first blow and the second wind-up
var strike_mark := -1.0   # trigger pulls, seconds into the take (-1 = none yet)
var strike2_mark := -1.0
var _played := {}
var _trigger_was := false


func _init(p_windup: float, p_windup2 := 0.0, p_gap := 0.0) -> void:
	windup = p_windup
	windup2 = p_windup2
	gap = p_gap


func is_combo() -> bool:
	return windup2 > 0.0


func strike_at() -> float:
	return LEAD + windup


func windup2_at() -> float:
	return strike_at() + gap


func strike2_at() -> float:
	return windup2_at() + windup2


## The last blow, as guided.
func last_strike_at() -> float:
	return strike2_at() if is_combo() else strike_at()


## When the take stops by itself.
func stop_at() -> float:
	return maxf(last_strike_at(), maxf(strike_mark, strike2_mark)) + FOLLOW


## Which beat a moment of the take is in: "settle", "windup", "gap", "windup2", "follow" or "done".
func phase(t: float) -> String:
	if t < LEAD:
		return "settle"
	if t < strike_at():
		return "windup"
	if is_combo():
		if t < windup2_at():
			return "gap"
		if t < strike2_at():
			return "windup2"
	if t < stop_at():
		return "follow"
	return "done"


## How far through the wind-up it's in (0..1) at this moment.
func progress(t: float) -> float:
	if is_combo() and t >= windup2_at():
		return clampf((t - windup2_at()) / maxf(windup2, 0.001), 0.0, 1.0)
	return clampf((t - LEAD) / maxf(windup, 0.001), 0.0, 1.0)


## Call every frame while recording: returns the cues to play this frame ("windup",
## "strike"), each once per blow, and notes the trigger pulls.
func tick(t: float, trigger: float) -> Array:
	var out := []
	var beats := [["windup", LEAD], ["strike", strike_at()]]
	if is_combo():
		beats.append_array([["windup2", windup2_at()], ["strike2", strike2_at()]])
	for b in beats:
		if t >= b[1] and not _played.has(b[0]):
			_played[b[0]] = true
			out.append(str(b[0]).trim_suffix("2"))
	var down := trigger > TRIGGER_ON
	if down and not _trigger_was and t >= LEAD:
		if strike_mark < 0.0:
			strike_mark = t
		elif is_combo() and strike2_mark < 0.0 and t > strike_mark + 0.2:
			strike2_mark = t
	_trigger_was = down
	return out


## The take's marks and the fitting that pins them to the game's timing.
func marks() -> Dictionary:
	var m := {"windup": LEAD, "strike": strike_mark if strike_mark > 0.0 else strike_at()}
	if is_combo():
		m["strike2"] = strike2_mark if strike2_mark > 0.0 else strike2_at()
	return m


func fit() -> Dictionary:
	var f := {"windup": 0.0, "strike": windup}
	if is_combo():
		f["strike2"] = windup + gap + windup2
	return f
