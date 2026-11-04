class_name Popups
extends Node2D
## Damage numbers: red ones rise off the hand for what got through to it, grey ones off each
## item for what it stopped. They drift up and fade. Drawn above everything in the play field.

const LIFE := 1.0
const RISE := 46.0

var _nums: Array = []  # {pos, vel, text, color, size, life}
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	z_index = 60


## A number at `at`. Values under half a point aren't worth showing. `big` for the hand's
## own damage, which has to be read mid-fight.
func number(at: Vector2, value: float, col: Color, big: bool = false) -> void:
	if value < 0.5 or not Settings.damage_numbers:
		return
	var size := int(clampf((20.0 if big else 14.0) + value * 0.25, 14.0, 36.0))
	_nums.append({"pos": at + Vector2(randf_range(-6, 6), 0), "vel": Vector2(randf_range(-14, 14), -RISE),
		"text": str(roundi(value)), "color": col, "size": size, "life": LIFE})


## A word, for a named effect going off (FIRESTORM, BLIZZARD...). Always big; lives longer.
func word(at: Vector2, text: String, col: Color) -> void:
	_nums.append({"pos": at, "vel": Vector2(0, -RISE * 0.5), "text": text, "color": col, "size": 20, "life": LIFE * 1.3})


func _process(delta: float) -> void:
	if _nums.is_empty():
		return
	for n in _nums:
		n.pos += n.vel * delta
		n.vel *= 0.96
		n.life -= delta
	_nums = _nums.filter(func(n: Dictionary) -> bool: return n.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for n in _nums:
		var a := clampf(n.life / LIFE * 1.6, 0.0, 1.0)
		var col: Color = n.color
		var w := _font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n.size).x
		var p: Vector2 = n.pos - Vector2(w * 0.5, 0)
		draw_string_outline(_font, p, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n.size, 4, Color(0, 0, 0, a * 0.8))
		draw_string(_font, p, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n.size, Color(col.r, col.g, col.b, a))
