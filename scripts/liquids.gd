class_name Liquids
extends Node2D
## Spilled potion: liquid pixels that fly, fall and splash. Each one that lands on an item
## soaks into the cell it touched (the game decides what that does); ones that hit the floor
## or walls leave a brief puddle and are gone.

const CAP := 500
const GRAVITY := 900.0

var _drops: Array = []    # {pos, vel, liquid, color}
var _puddles: Array = []  # {pos, color, life}
var _game: Node


func setup(game: Node) -> void:
	_game = game


func spill(at: Vector2, liquid: String, color: Color, count: int, base_vel: Vector2) -> void:
	for i in mini(count, CAP - _drops.size()):
		var v := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 320.0) + Vector2(0, -120.0) + base_vel * 0.5
		_drops.append({"pos": at + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "vel": v, "liquid": liquid, "color": color, "age": 0.0})


func _physics_process(delta: float) -> void:
	if _drops.is_empty() and _puddles.is_empty():
		return
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var keep: Array = []
	for d in _drops:
		d.vel += Vector2(0, GRAVITY * delta)
		d.pos += d.vel * delta
		d.age += delta
		if d.pos.y >= 716.0 or d.pos.x <= 2.0 or d.pos.x >= 1278.0:
			_puddles.append({"pos": Vector2(clampf(d.pos.x, 2, 1278), minf(d.pos.y, 716.0)), "color": d.color, "life": 1.5})
			continue
		q.position = d.pos
		var soaked := false
		if d.age > 0.04:  # don't soak into the shards of the flask it came from
			for h in space.intersect_point(q, 4):
				var it := h.collider as Item
				if it and not it.is_queued_for_deletion() and it.def.kind != "potion":
					_game.soak(it, d.pos, d.liquid)
					soaked = true
					break
		if not soaked:
			keep.append(d)
	_drops = keep
	for p in _puddles:
		p.life -= delta
	_puddles = _puddles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in _puddles:
		var col: Color = p.color
		col.a = minf(0.8, p.life)
		draw_rect(Rect2(p.pos - Vector2(3, 1), Vector2(6, 2)), col)
	for d in _drops:
		draw_rect(Rect2(d.pos - Vector2(2, 2), Vector2(4, 4)), d.color)
