class_name Settings
extends RefCounted
## Player settings: display, audio and a few comfort options. Kept in user://settings.cfg and
## applied at startup. Music and effects each get their own audio bus so they can be mixed
## apart; Settings.apply() makes the buses if they aren't there yet.

const PATH := "user://settings.cfg"
const FPS_CAPS := [30, 60, 120, 144, 240, 0]  # 0: no cap

static var fullscreen := false
static var vsync := true
static var fps_cap := 0
static var master := 0.8
static var music := 0.7
static var sfx := 0.8
static var mute_unfocused := true
static var shake := 1.0  # scales camera shake; 0 turns it off
static var damage_numbers := true
static var inspect_pauses := true  # holding Alt freezes the world

static var _loaded := false


static func load_file() -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	vsync = cfg.get_value("display", "vsync", vsync)
	fps_cap = cfg.get_value("display", "fps_cap", fps_cap)
	master = clampf(cfg.get_value("audio", "master", master), 0.0, 1.0)
	music = clampf(cfg.get_value("audio", "music", music), 0.0, 1.0)
	sfx = clampf(cfg.get_value("audio", "sfx", sfx), 0.0, 1.0)
	mute_unfocused = cfg.get_value("audio", "mute_unfocused", mute_unfocused)
	shake = clampf(cfg.get_value("game", "shake", shake), 0.0, 1.0)
	damage_numbers = cfg.get_value("game", "damage_numbers", damage_numbers)
	inspect_pauses = cfg.get_value("game", "inspect_pauses", inspect_pauses)


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "mute_unfocused", mute_unfocused)
	cfg.set_value("game", "shake", shake)
	cfg.set_value("game", "damage_numbers", damage_numbers)
	cfg.set_value("game", "inspect_pauses", inspect_pauses)
	cfg.save(PATH)


## Load (once) and push every setting to the engine.
static func apply() -> void:
	if not _loaded:
		load_file()
	_ensure_bus("Music")
	_ensure_bus("Sfx")
	apply_audio()
	apply_display()


static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap


static func apply_audio(focused: bool = true) -> void:
	var m := master if focused or not mute_unfocused else 0.0
	_set_volume("Master", m)
	_set_volume("Music", music)
	_set_volume("Sfx", sfx)


static func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_display()
	save_file()


static func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")


static func _set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))  # squared: sliders feel even
