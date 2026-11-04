class_name Materials
extends RefCounted
## Per-cell material properties. Every item is a grid of cells and each cell has a material.
##   hp       toughness of one cell
##   block    fraction of incoming damage a healthy cell stops
##   density  mass per cell (effective, a thin metal plate isn't 13x heavier than a plank)
##   behavior how a failing cell reacts: splinter (wood), dent (metal), tear (soft)
##   spread   how much of a hit leaks into neighbours: x = sideways, y = up/down (wood grain)
##   sharp    damage multiplier when used as a weapon's main material
##   value    price multiplier in the shop
##   wear     how fast enemy blows chew it up when it blocks (on top of hp). This is what
##            sets the metals apart as armour: a copper shield dents through in a fight or
##            two, iron lasts a few, steel a whole run
##   conducts carries electric charge to whatever it touches
##   burns    catches fire when hot enough

const DATA := {
	"wood": {"wear": 1.7, "hp": 3.0, "block": 0.92, "density": 0.5, "behavior": "splinter", "spread": Vector2(0.1, 0.5),
		"sharp": 0.6, "value": 1.0, "burns": true, "color": Color(0.52, 0.34, 0.18)},
	"leather": {"wear": 1.0, "hp": 2.2, "block": 0.8, "density": 0.35, "behavior": "tear", "spread": Vector2(0.05, 0.05),
		"sharp": 0.4, "value": 1.1, "burns": true, "color": Color(0.42, 0.27, 0.16)},
	"cloth": {"wear": 1.0, "hp": 1.0, "block": 0.5, "density": 0.2, "behavior": "tear", "spread": Vector2(0.0, 0.0),
		"sharp": 0.1, "value": 1.0, "burns": true, "color": Color(0.85, 0.82, 0.72)},
	"copper": {"wear": 0.9, "hp": 4.5, "block": 0.94, "density": 1.3, "behavior": "dent", "spread": Vector2(0.3, 0.3),
		"sharp": 0.85, "value": 1.4, "conducts": true, "color": Color(0.78, 0.45, 0.25)},
	"iron": {"wear": 0.5, "hp": 8.0, "block": 0.96, "density": 1.2, "behavior": "dent", "spread": Vector2(0.25, 0.25),
		"sharp": 1.0, "value": 2.0, "conducts": true, "color": Color(0.45, 0.45, 0.48)},
	"steel": {"wear": 0.22, "hp": 14.0, "block": 0.98, "density": 1.1, "behavior": "dent", "spread": Vector2(0.2, 0.2),
		"sharp": 1.25, "value": 3.0, "conducts": true, "color": Color(0.72, 0.75, 0.8)},
	"gold": {"wear": 1.4, "hp": 3.0, "block": 0.85, "density": 2.0, "behavior": "dent", "spread": Vector2(0.3, 0.3),
		"sharp": 0.5, "value": 4.0, "conducts": true, "color": Color(0.95, 0.75, 0.22)},
	"gem": {"wear": 1.0, "hp": 1.5, "block": 0.5, "density": 0.6, "behavior": "splinter", "spread": Vector2(0.0, 0.0),
		"sharp": 0.3, "value": 5.0, "color": Color(0.9, 0.9, 1.0)},
	"glass": {"wear": 1.0, "hp": 0.6, "block": 0.2, "density": 0.4, "behavior": "splinter", "spread": Vector2(0.4, 0.4),
		"sharp": 0.2, "value": 1.0, "color": Color(0.8, 0.9, 0.95)},
	"bone": {"wear": 1.0, "hp": 2.5, "block": 0.7, "density": 0.5, "behavior": "splinter", "spread": Vector2(0.2, 0.2),
		"sharp": 0.5, "value": 0.8, "color": Color(0.85, 0.8, 0.68)},
	# The seam where glued things meet: tough, light, amber. Chew enough of it away and the
	# parts come apart (each falls away as itself if it's still mostly whole).
	"glue": {"wear": 0.8, "hp": 6.0, "block": 0.9, "density": 0.4, "behavior": "tear", "spread": Vector2(0.1, 0.1),
		"sharp": 0.3, "value": 0.5, "color": Color(0.85, 0.62, 0.18)},
	"stone": {"wear": 0.9, "hp": 6.0, "block": 0.9, "density": 1.6, "behavior": "splinter", "spread": Vector2(0.3, 0.3),
		"sharp": 0.7, "value": 0.8, "color": Color(0.4, 0.4, 0.38)},
	# Only past the prestige 3 wall. Nearly twice as tough as steel, lighter, keener; it mends
	# itself and never rusts.
	"prestigium": {"wear": 0.12, "hp": 26.0, "block": 0.99, "density": 0.8, "behavior": "dent", "spread": Vector2(0.15, 0.15),
		"sharp": 1.6, "value": 6.0, "conducts": true, "color": Color(0.82, 0.74, 1.0)},
}


const DESC := {
	"prestigium": "Metal beyond the wall. Toughest and keenest there is; mends itself, never rusts.",
	"wood": "Light. Splinters along the grain and burns.",
	"leather": "Light and soft. Tears; burns.",
	"cloth": "Barely blocks. Tears; burns.",
	"copper": "Metal. Dents quickly; carries charge.",
	"iron": "Metal. Solid; carries charge.",
	"steel": "Metal. Hardest; dents slowly; carries charge.",
	"stone": "Heavy. Cracks and chips.",
	"glue": "The seam between glued things. Tough; chew it through and they come apart.",
	"gold": "Heavy and soft. Dents; carries charge.",
	"gem": "Fragile. Shatters.",
	"bone": "Light and brittle. Cracks.",
	"glass": "Fragile. Breaks and spills what's inside.",
}


## Every material's toughness is scaled by this: tune overall item lifespan in one place.
const TOUGHNESS := 1.5


static func get_mat(id: String) -> Dictionary:
	return DATA.get(id, DATA["wood"])


static func hp_of(id: String) -> float:
	return float(get_mat(id).hp) * TOUGHNESS
