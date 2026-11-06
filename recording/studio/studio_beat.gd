## The slate's beat bar: the take's timeline at a glance. Settle (grey), the wind-up
## (amber, filling as it goes), the strike (a red tick, and your trigger's mark beside it
## in cyan if you pulled it early or late), and for a combo the pause and the second
## wind-up and strike, then the follow-through (grey). A playhead runs along it while
## recording; before a take it shows the plan.
class_name StudioBeat
extends Control

var guide: StudioGuide
var t := -1.0  # seconds into the take (-1: not recording: show the plan)


func _init() -> void:
	custom_minimum_size = Vector2(0, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if guide == null:
		return
	var total := guide.stop_at()
	var y := size.y * 0.5
	var h := 14.0
	var x_of := func(s: float) -> float: return size.x * clampf(s / total, 0.0, 1.0)
	var dim := Color(1, 1, 1, 0.1)
	var spans := [[0.0, StudioGuide.LEAD, false], [StudioGuide.LEAD, guide.strike_at(), true]]
	if guide.is_combo():
		spans.append([guide.strike_at(), guide.windup2_at(), false])
		spans.append([guide.windup2_at(), guide.strike2_at(), true])
	spans.append([guide.last_strike_at(), total, false])
	for sp in spans:
		var a: float = x_of.call(sp[0])
		var b: float = x_of.call(sp[1])
		var amber: bool = sp[2]
		draw_rect(Rect2(a + 3, y - h * 0.5, maxf(b - a - 6, 0.0), h), Color(HHStyle.WARN, 0.2) if amber else dim)
		if amber and t > float(sp[0]):
			var f: float = x_of.call(minf(t, sp[1]))
			draw_rect(Rect2(a + 3, y - h * 0.5, maxf(f - a - 3, 0.0), h), HHStyle.WARN)
	for s in ([guide.strike_at(), guide.strike2_at()] if guide.is_combo() else [guide.strike_at()]):
		var sx: float = x_of.call(s)
		draw_rect(Rect2(sx - 3, 0, 6, size.y), HHStyle.REC)
	for m in [guide.strike_mark, guide.strike2_mark]:
		if m > 0.0:
			var mx: float = x_of.call(m)
			draw_rect(Rect2(mx - 2, 2, 4, size.y - 4), HHStyle.ACCENT)
	if t >= 0.0:
		var px: float = x_of.call(t)
		draw_rect(Rect2(px - 1.5, 0, 3, size.y), HHStyle.TEXT)
