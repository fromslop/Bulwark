@tool
## The workspace's look: one palette, one type scale, one set of panel styles, so every
## window in the headset reads the same way.
##
## Built for reading in a headset: dark glass so the stage shows through and the eyes
## rest, one accent (cyan) for "this is live / selected", and status colours used only for
## status (red = recording, amber = needs attention, green = done). Text is big, few
## weights, and dimmed rather than shrunk to show it matters less.
class_name HHStyle
extends RefCounted

# --- palette -------------------------------------------------------------------
const GLASS := Color(0.035, 0.05, 0.07, 0.86)       # panel body
const GLASS_EDGE := Color(0.32, 0.78, 0.95, 0.35)   # the hairline round a panel
const HEADER := Color(0.06, 0.09, 0.12, 0.92)       # title strip
const ROW := Color(1, 1, 1, 0.035)                  # alternate list rows
const ROW_HOVER := Color(0.32, 0.78, 0.95, 0.12)
const ROW_PICKED := Color(0.32, 0.78, 0.95, 0.24)

const TEXT := Color(0.91, 0.95, 0.98)
const TEXT_DIM := Color(0.58, 0.66, 0.74)
const TEXT_FAINT := Color(0.36, 0.42, 0.49)

const ACCENT := Color(0.32, 0.82, 1.0)   # live, selected, the thing to look at
const OK := Color(0.38, 0.9, 0.55)       # recorded, done
const WARN := Color(1.0, 0.72, 0.28)     # missing, needs you
const REC := Color(1.0, 0.3, 0.37)       # recording
const FIELD := Color(1.0, 0.36, 0.3)     # an attack's field (the game's own red)

# --- type ----------------------------------------------------------------------
## Sizes in panel pixels. Panels are drawn at PX_PER_M, so 1 px = 1/1600 m: body text is
## about 2 cm tall, easy to read at arm's length plus a bit.
const PX_PER_M := 1600.0
const SIZE_HERO := 64    # the one big thing on a panel (REC timer, the cue's name)
const SIZE_TITLE := 40
const SIZE_BODY := 30
const SIZE_SMALL := 24
const PAD := 24
const RADIUS := 18

static var _sans: Font
static var _mono: Font
static var _bold: Font


static func sans() -> Font:
	if _sans == null:
		_sans = _system(["Bahnschrift", "Segoe UI", "Inter", "Roboto", "DejaVu Sans"], 400)
	return _sans


static func bold() -> Font:
	if _bold == null:
		_bold = _system(["Bahnschrift", "Segoe UI", "Inter", "Roboto", "DejaVu Sans"], 600)
	return _bold


## Numbers, timers and ids: tabular, so columns line up and timers don't jitter.
static func mono() -> Font:
	if _mono == null:
		_mono = _system(["Cascadia Mono", "Consolas", "JetBrains Mono", "DejaVu Sans Mono"], 400)
	return _mono


static func _system(names: Array, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.multichannel_signed_distance_field = false
	f.generate_mipmaps = true
	return f


## A panel's body: dark glass with a hairline edge.
static func glass(radius := RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = GLASS
	s.border_color = GLASS_EDGE
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	s.set_content_margin_all(0)
	return s


## A flat fill, rounded (rows, chips, buttons).
static func fill(col: Color, radius := 10, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	s.anti_aliasing = true
	return s


## A label in the house style.
static func label(text: String, size := SIZE_BODY, col := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else sans())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## The Theme every panel's controls inherit (buttons, scroll bars...).
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := Color(1, 1, 1, 0.06)
		match state:
			"hover": col = ROW_HOVER
			"pressed": col = ROW_PICKED
			"disabled": col = Color(1, 1, 1, 0.02)
			"focus": col = Color(0, 0, 0, 0)
		var sb := fill(col, 12, GLASS_EDGE if state == "hover" else Color(0, 0, 0, 0))
		sb.set_content_margin_all(14)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font_size("font_size", "Button", SIZE_BODY)
	var grab := fill(Color(1, 1, 1, 0.18), 6)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", fill(ACCENT, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", fill(ACCENT, 6))
	t.set_stylebox("scroll", "VScrollBar", fill(Color(1, 1, 1, 0.03), 6))
	return t
