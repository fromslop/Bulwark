extends SceneTree
## An autopilot that plays the first few fights, for recording footage. It reads every
## incoming blow's lanes, gets a shield onto them and braces it as the blow lands, then
## swaps to a weapon and swings at the enemy's head while it's open. Between fights it
## skips the shop. Starts with a showcase kit on top of the rolled one: an iron kite shield
## (Riposte Guard) and a superheated steel Stormcaller longsword.
## Record: Godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --write-movie shots/playthrough.ogv -s res://tools/autoplay.gd

const LENGTH := 70.0  # seconds of footage
const FPS := 60.0

var main: Node
var f := 0
var shield: Item
var sword: Item
var braced := false
var swing_wait := 0.0
var shop_wait := 0.0
var fights := 0
var clock := 0.0
var snaps := 0
var _last_atk := ""
var _inj := 0.0
var _last_cov: Array = []
var _last_held := ""
var _last_d := 0.0


func _initialize() -> void:
	SaveData.PATH = "user://bulwark_autoplay_save.txt"  # never the player's real home
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call_deferred("_start_run")


func _process(delta: float) -> bool:
	f += 1
	if f == 8:
		shield = main._spawn(ItemDefs.make("kite_shield", "wood", ["counter"]), Vector2(300, 600))
		main.hand.upgrades["strength"] = 2  # a practised grip: it can throw a shield across in time
		sword = main._spawn(ItemDefs.make("longsword", "steel", ["stormcaller", "superheated"]), Vector2(1000, 600))
	if f < 20:
		return false
	clock += delta
	if clock > LENGTH:
		return true
	var hand: Hand = main.hand
	if OS.has_feature("editor") and f % 150 == 0:
		var foe0: Enemy = _first()
		print("t=%.1f fight=%d state=%s foe=%s hp=%.0f hand=%.0f held=%s" % [f / FPS, fights, main.state,
			foe0.data.name if foe0 else "-", foe0.hp if foe0 else 0.0, hand.injury, hand.held.def.name if hand.held else "-"])
	hand.injury = minf(hand.injury, hand.max_hp * 0.3)  # the footage shouldn't end in a defeat screen
	if main.state == main.State.SHOP:
		shop_wait += delta
		if shop_wait > 1.5:
			shop_wait = 0.0
			fights += 1
			main._close_shop()
		return false
	if main.state != main.State.COMBAT:
		return false
	if not _ok(shield) or not _ok(sword):
		return false
	var e: Enemy = _winding()
	if OS.has_feature("editor"):
		if e and _last_atk == "":
			_last_atk = str(e.current.get("pose", "")) + "/" + str(e.current.get("damage", 0))
			_inj = hand.injury
		elif e:
			_last_cov = e.get_meta("lane_cover", [])
			_last_held = hand.held.def.name if hand.held else "-"
			_last_d = (shield.to_global(shield.center_of_mass) - hand.position).length()
		elif _last_atk != "":
			print("blow %s: took %.1f, arrows %s, holding %s, shield-hand %.0f" % [_last_atk, hand.injury - _inj, _last_cov, _last_held, _last_d])
			_last_atk = ""
	if e:
		swing_wait = 0.0
		if _hold(shield):
			var cover := _cover_point(e)
			var centre := shield.to_global(shield.center_of_mass)
			hand.pinned = cover - (centre - shield.to_global(hand.grab_local))
			if OS.has_feature("editor") and e.progress > 0.9 and snaps < 0 and not e.has_meta("snapped"):
				e.set_meta("snapped", true)
				snaps += 1
				print("snap %d: %s cover=%s centre=%s hand=%s preview=%s braced=%s" % [snaps, e.current.get("pose", ""), cover, centre, hand.position, e.get_meta("lane_cover", []), shield.brace_time])
				root.get_texture().get_image().save_png("res://shots/auto_%d.png" % snaps)
			if _left(e) < 0.3 and not braced and centre.distance_to(cover) < 60.0:
				hand._activate()  # brace
				braced = true
	else:
		braced = false
		var foe: Enemy = _first()
		if foe == null:
			return false
		var open: bool = foe.off_balance > 0.0 or foe.state in ["stagger", "broken"]
		if not open:
			# guard: shield up in the middle, ready for whatever comes
			if _hold(shield):
				var centre := shield.to_global(shield.center_of_mass)
				hand.pinned = Vector2(640, 400) - (centre - shield.to_global(hand.grab_local))
			return false
		if _hold(sword):
			var head: Dictionary = {}
			for r in foe.regions():
				if r.id == "head":
					head = r
			if head.is_empty():
				return false
			var t := clock
			var aim: Vector2 = head.center + Vector2(-90.0 + sin(t * 3.0) * 20.0, 70.0)
			hand.pinned = aim
			swing_wait -= delta
			if hand.position.distance_to(aim) < 40.0 and sword.cooldown <= 0.0 and swing_wait <= 0.0:
				hand._activate()
				swing_wait = 0.5
	return false


func _ok(it) -> bool:
	return it != null and is_instance_valid(it) and not it.is_queued_for_deletion()


func _first() -> Enemy:
	var l: Array = main.living()
	return l[0] if not l.is_empty() else null


func _winding() -> Enemy:
	for e in main.living():
		if e.state == "windup" and not e.current.is_empty():
			return e
	return null


## Get `it` into the hand: let go of anything else, reach for it, take hold. True once held.
func _hold(it: Item) -> bool:
	var hand: Hand = main.hand
	if hand.held == it:
		return true
	if hand.held:
		hand.release()
	var at := it.to_global(it.center_of_mass)
	hand.pinned = at
	if hand.position.distance_to(at) < 30.0:
		hand.grab(it, at)  # by the middle, so the hand is behind it whichever way a blow comes
		return true
	return false


## Where the shield's centre should be to sit across the blow's lanes.
func _cover_point(e: Enemy) -> Vector2:
	var zone: PackedVector2Array = main._zone_px(e.current)
	var dir: Vector2 = (e.current.dir as Vector2).normalized()
	var lanes := Lanes.build(zone, dir)
	var sum := Vector2.ZERO
	var n := 0
	for lane in lanes:
		var mid: Vector2 = lane[lane.size() / 2]
		sum += mid
		n += 1
	var c := sum / maxf(1.0, n)
	if absf(dir.x) > 0.7:
		c.x = clampf(main.hand.position.x, 380.0, 900.0)  # anywhere along a sideways swing does
	elif absf(dir.y) > 0.7:
		c.y = clampf(main.hand.position.y, 300.0, 560.0)
	return c


## Seconds until the wind-up lands: brace about then, as a player would (a brace lasts 0.45 s).
func _left(e: Enemy) -> float:
	return (1.0 - e.progress) * float(e.current.get("windup", 1.0)) / maxf(0.1, e.cur_speed())
