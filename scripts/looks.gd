class_name Looks
extends Node
## Design exploration: a part of the game with several completely different designs,
## switchable live so they can be compared in play: F6 the hand. (The telegraph, the items
## and the foes have settled on one each: Red Zone, Material Texture and Character.) A name
## tag shows briefly at the bottom; the choice is remembered.

signal changed(part: String)

const SAVE_PATH := "user://looks.cfg"
const OPTIONS := {
	"telegraph": ["Red Zone"],
	"hand": ["Gauntlet", "Pixel Hand", "Bone", "Shadow Puppet"],
	"items": ["Material Texture"],
	"enemy": ["Character"],
}
const KEYS := {KEY_F6: "hand"}

static var choice := {"telegraph": 0, "hand": 0, "items": 0, "enemy": 0}

var _label: Label
var _label_t := 0.0


## The name of the design currently chosen for a part, e.g. Looks.pick("hand") == "Bone".
static func pick(part: String) -> String:
	return OPTIONS[part][choice[part]]


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 105
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 690)
	_label.add_theme_font_size_override("font_size", 18)
	_label.modulate.a = 0.0
	layer.add_child(_label)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for part in choice:
			choice[part] = clampi(cfg.get_value("looks", part, 0), 0, OPTIONS[part].size() - 1)


func set_choice(part: String, i: int, announce: bool = true) -> void:
	choice[part] = posmod(i, OPTIONS[part].size())
	changed.emit(part)
	get_tree().call_group("items", "queue_redraw")
	if announce:
		_label.text = "%s: %s" % [part, OPTIONS[part][choice[part]]]
		_label_t = 1.8
		var cfg := ConfigFile.new()
		for p in choice:
			cfg.set_value("looks", p, choice[p])
		cfg.save(SAVE_PATH)


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or not KEYS.has(k.keycode) or not OS.is_debug_build():  # (off in a release build)
		return
	var part: String = KEYS[k.keycode]
	set_choice(part, choice[part] + (-1 if k.shift_pressed else 1))


func _process(delta: float) -> void:
	_label_t = maxf(0.0, _label_t - delta)
	_label.modulate.a = minf(1.0, _label_t * 2.0)
