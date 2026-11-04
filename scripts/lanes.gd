class_name Lanes
extends RefCounted
## How a blow is split up. A swing runs through its zone as a few parallel lanes (the
## arrows drawn over every telegraph): each lane is a line the blade travels along, and
## it's stopped, bit by bit, by whatever of yours it meets on that line. Gear off the
## arrows does nothing for that lane. A thrust comes straight at the screen, so its
## lanes are a few points round where it lands.
## The same lanes are used to resolve the blow, to preview it while it winds up, and to
## draw it, so what you see is exactly what's tested.

const SPACING := 46.0  # roughly how far apart lanes sit across a swing
const MAX := 8
const STEP := 10.0  # sample spacing along a lane
const THRUST_SPREAD := 0.45  # how far the outer points of a thrust sit, of its radius


## Every lane of a zone, each an array of points ordered the way the blade travels.
static func build(poly: PackedVector2Array, dir: Vector2) -> Array:
	if poly.size() < 3:
		return []
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= poly.size()
	if dir == Vector2.ZERO:
		var r := 0.0
		for v in poly:
			r = maxf(r, v.distance_to(c))
		var out: Array = [[c]]
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var p: Vector2 = c + d * r * THRUST_SPREAD
			if Geometry2D.is_point_in_polygon(p, poly):
				out.append([p])
		return out
	dir = dir.normalized()
	var across := dir.orthogonal()
	var lo := INF
	var hi := -INF
	for v in poly:
		var a := (v - c).dot(across)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	var n := clampi(roundi((hi - lo) / SPACING), 1, MAX)
	var out: Array = []
	for i in n:
		var base := c + across * lerpf(lo, hi, (i + 0.5) / n)
		var seg := PackedVector2Array([base - dir * 3000.0, base + dir * 3000.0])
		var pts: Array = []
		for piece in Geometry2D.intersect_polyline_with_polygon(seg, poly):
			var a: Vector2 = piece[0]
			var b: Vector2 = piece[piece.size() - 1]
			if (b - a).dot(dir) < 0.0:
				var t := a
				a = b
				b = t
			var length := a.distance_to(b)
			var x := STEP * 0.5
			while x < length:
				pts.append(a + dir * x)
				x += STEP
		if not pts.is_empty():
			pts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.dot(dir) < q.dot(dir))
			out.append(pts)
	return out
