class_name ItemDefs
extends RefCounted
## Item templates, pixel masks, random modifiers and hand upgrades.
## Mask legend: M = the item's main material, w wood, i iron, l leather, c cloth, s stone,
## g gem, h a wrapped weapon handle (wood bound in leather: always safe to hold), . empty.

const CELL := 7.5

const PRICE_SCALE := 0.7  # all gear prices; tune the shop's generosity here
const UPGRADE_PRICE_SCALE := 0.75

const MASK_MATS := {"w": "wood", "i": "iron", "l": "leather", "c": "cloth", "s": "stone", "g": "gem", "h": "wood"}

# materials are listed cheapest first; later rounds roll further down the list
# "shop": false keeps a def out of random shop stock
const DEFS := {
	"coin": {"title": "Coin", "kind": "coin", "shape": "coin", "price": 0, "materials": ["gold"], "value": 1, "shop": false},
	"coin5": {"title": "Fat Coin", "kind": "coin", "shape": "coin5", "price": 0, "materials": ["gold"], "value": 5, "shop": false},
	"coin25": {"title": "Gold Bar", "kind": "coin", "shape": "bar", "price": 0, "materials": ["gold"], "value": 25, "shop": false},
	"pauldron": {"title": "Pauldron", "kind": "junk", "shape": "pauldron", "price": 0, "materials": ["iron"], "shop": false},
	"buckler": {"title": "Buckler", "kind": "shield", "shape": "buckler", "price": 3, "weight": 0.55,
		"materials": ["wood", "leather", "copper", "iron", "steel"]},
	"round_shield": {"title": "Round Shield", "kind": "shield", "shape": "round", "price": 5,
		"materials": ["wood", "copper", "iron", "steel"]},
	"kite_shield": {"title": "Kite Shield", "kind": "shield", "shape": "kite", "price": 6,
		"materials": ["wood", "copper", "iron", "steel"]},
	"tower_shield": {"title": "Tower Shield", "kind": "shield", "shape": "tower", "price": 8,
		"materials": ["wood", "iron", "steel"]},
	"rock": {"title": "Rock", "kind": "junk", "shape": "rock", "price": 1, "materials": ["stone"]},
	"glue_pot": {"title": "Glue Pot", "kind": "consumable", "shape": "pot", "price": 3, "materials": ["wood"],
		"applies": "sticky", "uses": 1},
	"coin_purse": {"title": "Coin Purse", "kind": "utility", "utility": "purse", "shape": "purse", "price": 6,
		"materials": ["leather"], "effect": "After each fight: drops 3 coins. Keep it in one piece."},
	"ledger": {"title": "Ledger", "kind": "utility", "utility": "ledger", "shape": "book", "price": 7,
		"materials": ["leather"], "effect": "After each fight: +1 coin for every 5 you hold (up to +5)."},
	"whetstone": {"title": "Whetstone", "kind": "utility", "utility": "whetstone", "shape": "whetstone", "price": 5,
		"materials": ["stone", "iron", "steel"], "effect": "Weapons resting against it slowly sharpen back up. It wears away as it works: harder ones last longer."},
	"anvil": {"title": "Anvil", "kind": "utility", "utility": "anvil", "shape": "anvil", "price": 7,
		"materials": ["iron", "steel"], "effect": "Metal resting against it slowly hammers back into shape. Heavy. It takes a beating as it works: steel lasts longer."},
	"horseshoe": {"title": "Horseshoe", "kind": "utility", "utility": "horseshoe", "shape": "horseshoe", "price": 6,
		"materials": ["iron"], "effect": "One free shop reroll every visit."},
	# Hoard utilities: they pay you for what's piled at the bottom of the screen
	"weapon_rack": {"title": "Weapon Rack", "kind": "utility", "utility": "rack", "shape": "rack", "price": 6,
		"materials": ["wood"], "effect": "+4 hand HP for every weapon you own (up to +40)."},
	"trophy_pegs": {"title": "Trophy Pegs", "kind": "utility", "utility": "pegs", "shape": "pegs", "price": 7,
		"materials": ["iron"], "effect": "Every enemy pauldron you keep: your gear takes 8% less wear from blows (up to 40%)."},
	"scales": {"title": "Merchant's Scales", "kind": "utility", "utility": "scales", "shape": "scales", "price": 5,
		"materials": ["copper"], "effect": "After each fight: +1 coin for every 4 things you own (up to +6)."},
	"packrat_idol": {"title": "Packrat Idol", "kind": "utility", "utility": "idol", "shape": "idol", "price": 9,
		"materials": ["gold"], "effect": "Weapons hit 2% harder for every whole weapon, shield and utility you own (up to +20%)."},
	"war_banner": {"title": "War Banner", "kind": "utility", "utility": "banner", "shape": "banner", "price": 6,
		"materials": ["cloth"], "effect": "Your blocks stagger the enemy 15% more for every shield you own (up to +45%)."},
	"crucible": {"title": "Crucible", "kind": "utility", "utility": "crucible", "shape": "crucible", "price": 8,
		"materials": ["iron"], "effect": "After each fight: metal scraps and pauldrons resting on it melt down into coins."},
	"lodestone": {"title": "Lodestone", "kind": "utility", "utility": "lodestone", "shape": "lodestone", "price": 5,
		"materials": ["stone"], "fixed_mods": ["magnetic"], "effect": "Draws your coins, scraps and pauldrons into a pile around it, out of the way."},
	"sentinel_stone": {"title": "Sentinel Stone", "kind": "utility", "utility": "sentinel", "shape": "sentinel", "price": 4,
		"materials": ["stone"], "effect": "Everything you aren't holding blocks better. Stacks: each stone closes 12% more of what gets past (up to 6)."},
	"mortar": {"title": "Apothecary's Mortar", "kind": "utility", "utility": "mortar", "shape": "mortar", "price": 7,
		"materials": ["stone"], "effect": "After each fight: heals your hand 15. Keep it in one piece."},
	"hair_shirt": {"title": "Hair Shirt", "kind": "utility", "utility": "hairshirt", "shape": "shirt", "price": 6,
		"materials": ["cloth"], "effect": "In a fight it chafes: your hand takes 1 every 2s (never the last point). Weapon hits do +40%."},
	# Kits: dab a modifier onto a piece of gear (like the Glue Pot)
	"resin": {"title": "Resin Block", "kind": "consumable", "shape": "resin", "price": 4, "materials": ["wood"],
		"applies": "reinforced", "uses": 1},
	"wisp_jar": {"title": "Bottled Wisp", "kind": "consumable", "shape": "wisp", "price": 7, "materials": ["glass"],
		"applies": "weightless", "uses": 1},
	"spike_kit": {"title": "Spike Kit", "kind": "consumable", "shape": "spikes", "price": 5, "materials": ["iron"],
		"applies": "spiked", "uses": 1},
	"potion_prestigium": {"title": "Ascendant Draught", "kind": "potion", "liquid": "to_prestigium", "liquid_color": Color(0.85, 0.75, 1.0), "shape": "flask",
		"price": 20, "materials": ["glass"], "effect": "Turns what it soaks to prestigium. Pour it over a legendary to ascend it."},
	"potion_steel": {"title": "Steelwater", "kind": "potion", "liquid": "to_steel", "liquid_color": Color(0.75, 0.8, 0.9), "shape": "flask",
		"price": 9, "materials": ["glass"], "effect": "Shatters into liquid that turns whatever it touches to steel."},
	"potion_iron": {"title": "Ironwater", "kind": "potion", "liquid": "to_iron", "liquid_color": Color(0.5, 0.5, 0.55), "shape": "flask",
		"price": 6, "materials": ["glass"], "effect": "Shatters into liquid that turns whatever it touches to iron."},
	"potion_copper": {"title": "Copperwater", "kind": "potion", "liquid": "to_copper", "liquid_color": Color(0.85, 0.5, 0.3), "shape": "flask",
		"price": 3, "materials": ["glass"], "effect": "Shatters into liquid that turns whatever it touches to copper."},
	"potion_gold": {"title": "Aurum", "kind": "potion", "liquid": "to_gold", "liquid_color": Color(1.0, 0.82, 0.25), "shape": "flask",
		"price": 10, "materials": ["glass"], "effect": "Turns what it touches to gold. Gilded scraps become coins."},
	"potion_stone": {"title": "Petrify", "kind": "potion", "liquid": "to_stone", "liquid_color": Color(0.55, 0.55, 0.5), "shape": "flask",
		"price": 4, "materials": ["glass"], "effect": "Turns what it touches to stone: heavy, tough, never conducts or burns."},
	"potion_wood": {"title": "Wildwood", "kind": "potion", "liquid": "to_wood", "liquid_color": Color(0.55, 0.4, 0.2), "shape": "flask",
		"price": 2, "materials": ["glass"], "effect": "Turns what it touches to wood: light, but it splinters and burns."},
	"potion_poison": {"title": "Venom", "kind": "potion", "liquid": "poison", "liquid_color": Color(0.4, 0.9, 0.3), "shape": "flask",
		"price": 5, "materials": ["glass"], "effect": "Coats what it soaks in poison: a coated weapon poisons the enemy."},
	"potion_oil": {"title": "Lamp Oil", "kind": "potion", "liquid": "oil", "liquid_color": Color(0.4, 0.3, 0.1), "shape": "flask",
		"price": 2, "materials": ["glass"], "effect": "Soaked things catch fire easily, even metal."},
	"potion_frost": {"title": "Rime", "kind": "potion", "liquid": "frost", "liquid_color": Color(0.7, 0.95, 1.0), "shape": "flask",
		"price": 3, "materials": ["glass"], "effect": "Freezes what it soaks. Quench red-hot metal with it to temper it."},
	"potion_fire": {"title": "Firewater", "kind": "potion", "liquid": "fire", "liquid_color": Color(1.0, 0.45, 0.1), "shape": "flask",
		"price": 3, "materials": ["glass"], "effect": "Heats what it soaks red-hot."},
	"potion_lightning": {"title": "Stormglass", "kind": "potion", "liquid": "lightning", "liquid_color": Color(0.5, 0.75, 1.0), "shape": "flask",
		"price": 4, "materials": ["glass"], "effect": "Charges what it soaks."},
	"potion_glue": {"title": "Pitch", "kind": "potion", "liquid": "glue", "liquid_color": Color(0.85, 0.9, 0.4), "shape": "flask",
		"price": 3, "materials": ["glass"], "effect": "Makes what it soaks sticky."},
	"potion_mending": {"title": "Mending Draught", "kind": "potion", "liquid": "mending", "liquid_color": Color(0.5, 1.0, 0.6), "shape": "flask",
		"price": 5, "materials": ["glass"], "effect": "Mends whole every piece of gear it splashes, and scours the rust off."},
	"potion_levitation": {"title": "Featherdraught", "kind": "potion", "liquid": "levitation", "liquid_color": Color(0.8, 0.7, 1.0), "shape": "flask",
		"price": 6, "materials": ["glass"], "effect": "What it soaks turns weightless: no gravity, almost no mass, easy to fling (and easy to knock away)."},
	"potion_growth": {"title": "Giant's Brew", "kind": "potion", "liquid": "grow", "liquid_color": Color(0.9, 0.55, 0.2), "shape": "flask",
		"price": 6, "materials": ["glass"], "effect": "What it soaks grows half again as big: more cover, more weight, more toughness."},
	"potion_shrink": {"title": "Pixie Dust", "kind": "potion", "liquid": "shrink", "liquid_color": Color(1.0, 0.75, 0.9), "shape": "flask",
		"price": 4, "materials": ["glass"], "effect": "What it soaks shrinks to two-thirds: lighter and quicker, less cover."},
	"potion_lead": {"title": "Leaden Draught", "kind": "potion", "liquid": "lead", "liquid_color": Color(0.35, 0.35, 0.4), "shape": "flask",
		"price": 4, "materials": ["glass"], "effect": "What it soaks turns heavy: tougher, harder to lift, parries poorly."},
	"potion_homeward": {"title": "Homeward Brew", "kind": "potion", "liquid": "homeward", "liquid_color": Color(0.5, 0.85, 0.7), "shape": "flask",
		"price": 12, "materials": ["glass"], "phases": true,
		"effect": "Passes through your gear. Hold it over something and press Space (or let it break): the nearest thing is whisked home to keep. Rare."},
	"smith_hammer": {"title": "Smith's Hammer", "kind": "weapon", "shape": "hammer", "price": 8, "materials": ["iron"],
		"swing_damage": 30.0, "swing_speed": 9.0, "cooldown": 1.4, "guard": 0.8, "shop": false},
	"lantern": {"title": "Grave Lantern", "kind": "utility", "utility": "lantern", "shape": "lantern", "price": 5,
		"materials": ["iron"], "gem": Color(1.0, 0.8, 0.35), "effect": "Gives off light: in the dark you can see around it."},
	"skull": {"title": "Skull", "kind": "junk", "shape": "skull", "price": 1, "materials": ["bone"], "shop": false},
	"stormbrand": {"title": "Stormbrand", "kind": "weapon", "shape": "longsword", "price": 9, "materials": ["steel"],
		"swing_damage": 24.0, "swing_speed": 12.0, "cooldown": 1.2, "guard": 1.0, "fixed_mods": ["electrified", "regenerating"],
		"legend": "chain", "effect": "Lightning leaps from every hit to every other foe (half damage) and locks up any swing being wound up.",
		"ascended_effect": "Ascended: the lightning strikes every foe at full strength and stops every one of them mid-swing, every hit."},
	"aegis": {"title": "The Aegis", "kind": "shield", "shape": "tower", "price": 10, "materials": ["steel"],
		"fixed_mods": ["reinforced", "spiked", "tempered"],
		"legend": "unyielding", "effect": "Nothing gets past it: whatever it stands in front of is stopped dead, even a cleaving blow.",
		"ascended_effect": "Ascended: nothing gets past it, and every blow it stops is a parry."},
	"hearthblade": {"title": "Hearthblade", "kind": "weapon", "shape": "shortsword", "price": 8, "materials": ["steel"],
		"swing_damage": 16.0, "swing_speed": 17.0, "cooldown": 0.8, "guard": 0.92, "fixed_mods": ["superheated", "weightless"],
		"legend": "flare", "effect": "Hitting a burning foe sets the fire off: double damage, and the flames go out.",
		"ascended_effect": "Ascended: every hit sets the foe alight, and a hit on a burning foe does four times the damage without putting it out."},
	"venom_fang": {"title": "Venom Fang", "kind": "weapon", "shape": "spear", "price": 8, "materials": ["steel"],
		"swing_damage": 20.0, "swing_speed": 11.0, "cooldown": 1.1, "guard": 0.88, "fixed_mods": ["poisoned", "corrosive"],
		"legend": "rot", "effect": "Its poison stacks: every hit adds four seconds (up to 24), and a poisoned foe takes a quarter more from it.",
		"ascended_effect": "Ascended: the poison stacks up to a minute, and a poisoned foe takes 60% more from it."},
	"crate": {"title": "Crate", "kind": "crate", "shape": "crate", "price": 2, "materials": ["wood"], "loot": 1},
	"strongbox": {"title": "Strongbox", "kind": "crate", "shape": "crate", "price": 3, "materials": ["iron"], "loot": 2},
	"reliquary": {"title": "Reliquary", "kind": "crate", "shape": "crate", "price": 4, "materials": ["steel"], "loot": 3},
	"club": {"title": "Club", "kind": "weapon", "shape": "club", "price": 2, "materials": ["wood"],
		"swing_damage": 12.0, "swing_speed": 13.0, "cooldown": 1.0, "guard": 0.92},
	# Swords come in a few patterns: the same name can be a leaf blade, a tapered point or a
	# straight blade, each a slightly different shape (and so a slightly different weapon).
	"shortsword": {"title": "Shortsword", "kind": "weapon", "shape": "shortsword", "price": 4, "variants": ["shortsword", "leaf_short", "tapered_short"],
		"materials": ["copper", "iron", "steel"], "swing_damage": 14.0, "swing_speed": 16.0, "cooldown": 0.9, "guard": 0.92},
	"longsword": {"title": "Longsword", "kind": "weapon", "shape": "longsword", "price": 7, "variants": ["longsword", "leaf_long", "tapered_long"],
		"materials": ["copper", "iron", "steel"], "swing_damage": 22.0, "swing_speed": 12.0, "cooldown": 1.3, "guard": 1.0},
	"dagger": {"title": "Dagger", "kind": "weapon", "shape": "dagger", "price": 3,
		"materials": ["copper", "iron", "steel"], "swing_damage": 9.0, "swing_speed": 20.0, "cooldown": 0.5, "guard": 0.8},
	"falchion": {"title": "Falchion", "kind": "weapon", "shape": "falchion", "price": 5,
		"materials": ["copper", "iron", "steel"], "swing_damage": 17.0, "swing_speed": 14.0, "cooldown": 1.0, "guard": 0.9},
	"greatsword": {"title": "Greatsword", "kind": "weapon", "shape": "greatsword", "price": 9,
		"materials": ["iron", "steel"], "swing_damage": 30.0, "swing_speed": 9.0, "cooldown": 1.8, "guard": 1.0},
	"axe": {"title": "Axe", "kind": "weapon", "shape": "axe", "price": 5,
		"materials": ["copper", "iron", "steel"], "swing_damage": 24.0, "swing_speed": 11.0, "cooldown": 1.4, "guard": 0.85},
	"warhammer": {"title": "Warhammer", "kind": "weapon", "shape": "warhammer", "price": 7,
		"materials": ["iron", "steel"], "swing_damage": 28.0, "swing_speed": 8.0, "cooldown": 1.7, "guard": 0.9},
	"mace": {"title": "Mace", "kind": "weapon", "shape": "mace", "price": 6,
		"materials": ["copper", "iron", "steel"], "swing_damage": 26.0, "swing_speed": 9.0, "cooldown": 1.6, "guard": 0.9},
	"spear": {"title": "Spear", "kind": "weapon", "shape": "spear", "price": 5,
		"materials": ["copper", "iron", "steel"], "swing_damage": 18.0, "swing_speed": 10.0, "cooldown": 1.2, "guard": 0.88},
	"bandage": {"title": "Bandage", "kind": "consumable", "shape": "bandage", "price": 4,
		"materials": ["cloth"], "heal": 30.0},
	"field_dressing": {"title": "Field Dressing", "kind": "consumable", "shape": "dressing", "price": 7,
		"materials": ["cloth"], "heal": 45.0, "auto_heal": 0.3,
		"effect": "Binds itself: the moment your hand drops below 30% in a fight, it flies to it and heals 45 (from anywhere in your pile). Space binds it sooner."},
	# Prestige legendaries: only turn up once the run has been pushed past its first boss.
	"mirror_shield": {"title": "Mirror Shield", "kind": "shield", "shape": "kite", "price": 11, "materials": ["steel"],
		"fixed_mods": ["reinforced", "regenerating", "magnetic"],
		"legend": "reflect", "effect": "Sends half the force of every blow it takes back at whoever threw it.",
		"ascended_effect": "Ascended: sends back half again more than it takes."},
	"sunderer": {"title": "Sunderer", "kind": "weapon", "shape": "greatsword", "price": 14, "materials": ["steel"],
		"swing_damage": 30.0, "swing_speed": 9.0, "cooldown": 1.8, "guard": 1.0, "fixed_mods": ["huge", "tempered", "regenerating"],
		"legend": "sunder", "effect": "Every hit tears armour away: a pauldron comes off every few hits.",
		"ascended_effect": "Ascended: every hit strips all of it and shakes them to their boots (fills the stagger meter)."},
	# Prestigium legendaries: only past the prestige 3 wall, and born ascended.
	"paragon": {"title": "Paragon", "kind": "weapon", "shape": "longsword", "price": 18, "materials": ["prestigium"],
		"swing_damage": 26.0, "swing_speed": 13.0, "cooldown": 1.1, "guard": 1.0, "fixed_mods": [],
		"legend": "echo", "effect": "Every hit strikes again a beat later.",
		"ascended_effect": "Every hit strikes three more times, a beat apart."},
	"bastion": {"title": "Bastion", "kind": "shield", "shape": "tower", "price": 18, "materials": ["prestigium"],
		"fixed_mods": ["reinforced"],
		"legend": "vigil", "effect": "Braces itself whenever it's ready: the next blow it meets is a parry.",
		"ascended_effect": "Always braced: every blow it meets is a parry."},
	# Home furniture: menus you hold. Never sold.
	"gilded_tooth": {"title": "Gilded Tooth", "kind": "junk", "shape": "tooth", "price": 0, "materials": ["gold"], "shop": false,
		"effect": "The chute coughed it up. It hums near the gong."},
	# The collections, one object each; each opens the index at its own page.
	"codex": {"title": "Armoury Ledger", "kind": "menu", "menu": "codex", "tab": 0, "shape": "book", "price": 0, "materials": ["leather"], "shop": false,
		"effect": "Every piece of gear you've laid hands on."},
	"rune_tablet": {"title": "Rune Tablet", "kind": "menu", "menu": "codex", "tab": 1, "shape": "tablet", "price": 0, "materials": ["stone"], "shop": false,
		"effect": "Every modifier you've seen, rare ones in gold. Turn it over for the element circle: the reactions you've set off."},
	"bestiary": {"title": "Bestiary", "kind": "menu", "menu": "codex", "tab": 2, "shape": "book", "price": 0, "materials": ["bone"], "shop": false,
		"effect": "Everything you've fought."},
	"wall_map": {"title": "Wall Map", "kind": "menu", "menu": "codex", "tab": 3, "shape": "map", "price": 0, "materials": ["cloth"], "shop": false,
		"effect": "Every place you've been."},
	"mirror": {"title": "Hand Mirror", "kind": "menu", "menu": "mirror", "shape": "mirror", "price": 0, "materials": ["copper"], "shop": false,
		"effect": "Have a look at yourself. Try a different gauntlet."},
}

# Which run prestige an item needs before it can turn up (anything not listed: from the start).
const PRESTIGE := {"aegis": 1, "hearthblade": 1, "packrat_idol": 1, "potion_homeward": 1,
	"venom_fang": 2, "potion_gold": 2, "mirror_shield": 2, "sunderer": 3,
	"paragon": 4, "bastion": 4, "potion_prestigium": 4}
# Prestigium: from this prestige on (past the prestige 3 wall), some weapons and shields
# are forged from it, and the Ascendant Draught turns up.
const PRESTIGIUM_PRESTIGE := 4
const PRESTIGIUM_CHANCE := 0.2
const ASCEND_DAMAGE := 2.0  # an ascended legendary's swing, against the original's
static var run_prestige := 0  # set by the game as the run deepens

# density / hp multiply the item's cells; price multiplies its cost; size rescales the pixel mask
# (more cells = more coverage, more weight, more total toughness). Mods in the same group exclude each other.
# Old modifiers that became another: weightless took over from floating and featherweight
# (saved homes still carry the old names).
const RENAMED_MODS := {"floating": "weightless", "featherweight": "weightless"}


## A modifier list with any old names brought up to date (and no doubles).
static func current_mods(mods: Array) -> Array:
	var out: Array = []
	for m in mods:
		var cur: String = RENAMED_MODS.get(m, m)
		if MODIFIERS.has(cur) and not out.has(cur):
			out.append(cur)
	return out

const MODIFIERS := {
	"heavy": {"desc": "heavier and tougher", "price": 1.1, "density": 1.8, "hp": 1.2, "group": "weight"},
	"weightless": {"desc": "weighs next to nothing: doesn't fall, flicks round with no effort, adds almost nothing to what it's glued to (and a blow knocks it away)",
		"price": 1.7, "density": 0.04, "group": "weight"},
	"reinforced": {"desc": "set in resin: twice as tough", "price": 1.4, "hp": 2.0},
	"bouncy": {"desc": "springs off everything", "price": 1.0},
	"spiked": {"desc": "returns 25% of blocked damage", "price": 1.5},
	"electrified": {"desc": "charged: shocks whatever it touches, flows through metal", "price": 1.6},
	"superheated": {"desc": "red hot: sets wood alight, heats metal", "price": 1.6, "group": "temp"},
	"frosty": {"desc": "freezes what it touches: slippery, brittle, puts out fires", "price": 1.5, "group": "temp"},
	"sticky": {"desc": "has a patch of wet glue (the glossy amber pixels). Press that patch against something, one of them in your hand, and they fuse into one thing: each part still works as what it was (a buckler glued to a sword blocks like a buckler), and their modifiers pool. A blade that meets the glue is gummed up", "price": 1.2, "rolls": false},  # only from glue: the Glue Pot, Pitch
	"poisoned": {"desc": "coated in venom: weapon hits poison the enemy", "price": 1.5},
	"oiled": {"desc": "soaked in oil: catches fire easily, even metal", "price": 0.9},
	"tempered": {"desc": "quenched while red-hot: 30% tougher", "price": 1.4},
	"magnetic": {"desc": "draws coins, scraps and pauldrons to it; the enemy's blade is drawn to it too (blocks a little wider)", "price": 1.5},
	"corrosive": {"desc": "rusts any metal it touches (rust it gives stays put: it doesn't spread on). On a weapon it eats a foe's armour: about three hits rust a pauldron off, exposing the flesh under it (x1.6) long before force would", "price": 1.2},
	"volatile": {"desc": "explodes when heated, shocked or struck hard", "price": 0.8},
	"regenerating": {"desc": "slowly heals itself", "price": 1.7},
	"soothing": {"desc": "held in a fight, it slowly heals your hand (2 a second)", "price": 1.6},
	"small": {"desc": "two-thirds size", "price": 0.8, "size": 0.65, "group": "size"},
	"large": {"desc": "half again as big", "price": 1.4, "size": 1.5, "group": "size"},
	"huge": {"desc": "twice the size", "price": 1.9, "size": 2.0, "group": "size"},
	# --- rare, weapons only: conditional. Meet the condition and the payout is big ---------
	"wispfire": {"name": "Wisp Cannon", "desc": "swung fast, it spits wisps at the foe. They carry its element: fire scorches, frost slows, lightning can lock up a swing, venom poisons, rot corrodes. Heavy, they're cannonballs; bigger, bigger wisps", "price": 2.2, "rare": true},
	"headhunter": {"name": "Headhunter", "desc": "hits to the head do triple", "price": 1.9, "rare": true},
	"desperate": {"name": "Desperate", "desc": "does double while your hand is below a third of its health", "price": 1.8, "rare": true},
	"lone": {"name": "Lone Blade", "desc": "does double while it's the only weapon you have", "price": 1.9, "rare": true},
	"pristine": {"name": "Pristine", "desc": "does double while its edge is near perfect (keep it whetted)", "price": 1.9, "rare": true},
	"guardbreaker": {"name": "Guardbreaker", "desc": "hits on a foe that's winding up do double and fill its stagger meter five times over", "price": 2.0, "rare": true},
	"merciless": {"name": "Merciless", "desc": "triple damage on a foe below a third of its health", "price": 1.9, "rare": true},
	"avenging": {"name": "Avenging", "desc": "after it parries a blow, its next hit within 3s does triple", "price": 2.0, "rare": true},
	"stormcaller": {"name": "Stormcaller", "desc": "a parry with it calls lightning on the foe: double what it stopped, through armour. Hot, it's a firestorm; frosty, a blizzard; venomous, acid rain; corrosive, a rust storm; electrified, it strikes every foe twice as hard", "price": 2.1, "rare": true},
	# juggling: swap gear round, throw it, hand off between weapons
	"rested": {"name": "Rested", "desc": "+50% for every second it spent out of your hand (up to x4), spent on its first hit", "price": 1.9, "rare": true},
	"baton": {"name": "Baton", "desc": "its hit marks the foe: the next hit with a different weapon within 4s does x2.5", "price": 1.9, "rare": true},
	"javelin": {"name": "Javelin", "desc": "let go of it mid-swing and it flies at the foe: a thrown hit does x4", "price": 2.0, "rare": true},
	"mimic": {"name": "Mimic", "desc": "picked up, it takes on the rare modifiers of the last weapon you held", "price": 2.2, "rare": true},
	# builds: lean the whole pile one way
	"lightning_rod": {"name": "Lightning Rod", "desc": "its hit draws the charge out of every charged piece you own: +10 each, through armour", "price": 2.0, "rare": true},
	"kindred": {"name": "Kindred", "desc": "+20% for every other piece you own of its metal (up to x3)", "price": 1.9, "rare": true},
	"reckless": {"name": "Reckless", "desc": "hits do x2.5, but each one chews its own edge", "price": 1.7, "rare": true},
	# blood: heal from the fight, or pay into it
	"sanguine": {"name": "Sanguine", "desc": "its hits heal your hand by 15% of the damage they do", "price": 2.0, "rare": true},
	"bloodprice": {"name": "Blood Price", "desc": "every hit cuts your own hand for 4 (never the last point), and does x2.5", "price": 1.8, "rare": true},
	"bloodthirsty": {"name": "Bloodthirsty", "desc": "the more your hand is hurt, the harder it hits: up to x3 at death's door", "price": 1.9, "rare": true},
	"kindling": {"name": "Kindling", "desc": "a hit while it's hot sets every other weapon you own red-hot too", "price": 1.8, "rare": true},
	# shields
	"counter": {"name": "Riposte Guard", "desc": "what it stops is banked (up to 80): your next weapon hit adds it all", "price": 2.0, "rare": true, "kinds": ["shield"]},
	"hallowed": {"name": "Hallowed", "desc": "a parry with it heals your hand 8; a clean block, 3", "price": 1.9, "rare": true, "kinds": ["shield"]},
	"rally": {"name": "Rally", "desc": "a parry with it readies every weapon you own and makes the next hit within 3s x1.5", "price": 1.9, "rare": true, "kinds": ["shield"]},
}

# Hand upgrades. They're sold as physical items (shape/material/gem); hold one and press
# Space to put it on. Rings go in the single ring slot and fire on right mouse.
const UPGRADES := {
	"strength": {"title": "Gauntlet", "desc": "+25% grip strength", "cost": 8, "shape": "gauntlet", "material": "iron"},
	"toughness": {"title": "Salve", "desc": "+25 hand HP", "cost": 7, "shape": "salve", "material": "wood"},
	"steady": {"title": "Calm Charm", "desc": "-40% shaking when hurt", "cost": 5, "shape": "charm", "material": "stone"},
	"quick": {"title": "Wristband", "desc": "+20% swing speed", "cost": 7, "shape": "wristband", "material": "leather"},
	"slots": {"title": "Ring Fitting", "desc": "+1 ring slot (one per finger, up to 5)", "cost": 8, "shape": "band", "material": "gold"},
	# Stat draughts: cheap, stackable, and one is always on the shop's stat shelf
	"vigor": {"title": "Oxblood Draught", "desc": "+15 hand HP", "cost": 4, "shape": "salve", "material": "glass", "gem": Color(0.6, 0.1, 0.1)},
	"tonic": {"title": "Iron Tonic", "desc": "+12% grip strength: lift heavier things", "cost": 5, "shape": "salve", "material": "glass", "gem": Color(0.5, 0.55, 0.6)},
	"haste": {"title": "Quicksilver Drop", "desc": "weapons recover 10% faster", "cost": 5, "shape": "salve", "material": "glass", "gem": Color(0.8, 0.85, 0.9)},
	"thick_skin": {"title": "Troll Marrow", "desc": "hits that get through hurt 10% less", "cost": 6, "shape": "salve", "material": "glass", "gem": Color(0.4, 0.6, 0.3)},
	"ring_levitation": {"title": "Ring of Levitation", "desc": "RMB: item under hand goes weightless for 6s", "cost": 10,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(0.6, 0.85, 1.0), "cooldown": 8.0},
	"ring_recall": {"title": "Ring of Recall", "desc": "RMB: all your items fly to your hand", "cost": 9,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(0.7, 0.4, 1.0), "cooldown": 6.0},
	"ring_mending": {"title": "Ring of Mending", "desc": "RMB: patch up the item under hand", "cost": 11,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(0.4, 1.0, 0.5), "cooldown": 12.0},
	"ring_tempo": {"title": "Ring of Tempo", "desc": "RMB: enemy moves at half speed for 3s", "cost": 12,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(1.0, 1.0, 1.0), "cooldown": 14.0},
	"ring_desperation": {"title": "Ring of Desperation", "desc": "below 30% hand health: grip and swing are maxed", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.6, 0.05, 0.1)},
	"ring_untouched": {"title": "Ring of the Untouched", "desc": "+80% weapon damage while your hand is above 90%", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.98, 0.85)},
	"ring_miser": {"title": "Ring of the Miser", "desc": "+3% weapon damage per coin you hold (up to +100%)", "cost": 9,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.95, 0.75, 0.2)},
	"ring_momentum": {"title": "Ring of Momentum", "desc": "after a clean block your next hit within 2s does x2.5; after a parry, x4", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.5, 0.15)},
	"ring_executioner": {"title": "Ring of the Executioner", "desc": "weapon hits on a reeling or broken foe do triple", "cost": 12,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.5, 0.05, 0.05)},
	"ring_grudge": {"title": "Ring of Grudges", "desc": "every clean block banks a grudge (a parry, two; up to 5): your next hit spends them for +60% each", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.35, 0.3, 0.6)},
	"ring_wrath": {"title": "Ring of Wrath", "desc": "RMB: every weapon hit for the next 4s does x2.5", "cost": 13,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.15, 0.1), "cooldown": 14.0},
	"ring_storm": {"title": "Ring of the Storm", "desc": "RMB: the weapon in your hand crackles with lightning for 6s (as if electrified)", "cost": 12,
		"ring": true, "shape": "ring", "material": "gold", "gem": Color(0.55, 0.8, 1.0), "cooldown": 15.0},
	# --- the strange ones: rings that bend the rules -----------------------------------
	"ring_thorns": {"title": "Ring of Thorns", "desc": "whatever hurts your hand takes double back", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.35, 0.6, 0.2)},
	"ring_glass": {"title": "Glass Cannon Ring", "desc": "your weapon hits do double, but your hand takes double too", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.85, 0.95, 1.0)},
	"ring_vampire": {"title": "Ring of the Leech", "desc": "your weapon hits heal your hand by a tenth of the damage they do", "cost": 12,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.55, 0.0, 0.1)},
	"ring_frenzy": {"title": "Ring of Frenzy", "desc": "each hit within 2.5s of the last does +25% more (up to +200%); getting hurt breaks the streak", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.35, 0.6)},
	"ring_midas": {"title": "Midas Ring", "desc": "coins in your pile soak up blows to your hand: each coin spent stops 3 damage", "cost": 12,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.85, 0.2)},
	"ring_phoenix": {"title": "Phoenix Ring", "desc": "once, when your hand would die, it comes back at half health (the ring burns away)", "cost": 14,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.55, 0.1)},
	"ring_martyr": {"title": "Ring of the Martyr", "desc": "damage your hand takes fills the enemy's stagger meter three times over", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.75, 0.75, 0.9)},
	"ring_pacifist": {"title": "Ring of the Pacifist", "desc": "you can't swing weapons at all; every clean block hits back for 1.5x what it stopped (a parry, 3x)", "cost": 9,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 1.0, 1.0)},
	"ring_static": {"title": "Ring of Static", "desc": "every parry electrifies every weapon you own for 4s", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.5, 0.75, 1.0)},
	"ring_inferno": {"title": "Ring of Inferno", "desc": "every parry sets the enemy alight", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.4, 0.05)},
	"ring_winter": {"title": "Ring of Winter", "desc": "every clean block slows the enemy to half speed for 2s", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.65, 0.95, 1.0)},
	"ring_magpie": {"title": "Ring of the Magpie", "desc": "kills drop double coins, but shop prices are 30% higher", "cost": 8,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.15, 0.15, 0.2)},
	"ring_echoes": {"title": "Ring of Echoes", "desc": "RMB: the last blow you blocked strikes the enemy instead, two and a half times as hard", "cost": 12,
		"ring": true, "cooldown": 10.0, "shape": "ring", "material": "gold", "gem": Color(0.7, 0.5, 1.0)},
	"ring_juggler": {"title": "Juggler's Ring", "desc": "RMB: your whole pile is flung into the air, for a fresh arrangement where it lands", "cost": 8,
		"ring": true, "cooldown": 9.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.8, 0.9)},
	"ring_well": {"title": "Ring of the Well", "desc": "RMB: for 3s your whole pile is dragged toward your hand", "cost": 10,
		"ring": true, "cooldown": 12.0, "shape": "ring", "material": "gold", "gem": Color(0.2, 0.1, 0.35)},
	"ring_reversal": {"title": "Ring of Reversal", "desc": "RMB: for 3s your pile falls up", "cost": 10,
		"ring": true, "cooldown": 12.0, "shape": "ring", "material": "gold", "gem": Color(0.4, 1.0, 0.85)},
	"ring_alchemy": {"title": "Alchemist's Ring", "desc": "RMB: the item under your hand goes up a metal: wood, bone, stone and leather to copper, copper to iron, iron to steel, steel to gold", "cost": 13,
		"ring": true, "cooldown": 30.0, "shape": "ring", "material": "gold", "gem": Color(0.9, 0.7, 0.2)},
	"ring_gambler": {"title": "Gambler's Ring", "desc": "RMB: a coin flip. Heads, your next hit does x6. Tails, your hand takes 12", "cost": 9,
		"ring": true, "cooldown": 8.0, "shape": "ring", "material": "gold", "gem": Color(0.2, 0.8, 0.3)},
	# --- blood: healing, and pain that pays ----------------------------------------------
	"ring_second_wind": {"title": "Ring of Second Wind", "desc": "once a fight, when your hand drops below a quarter, it heals 35", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.5, 1.0, 0.6)},
	"ring_resolve": {"title": "Ring of Resolve", "desc": "every parry heals your hand 6; every clean block, 2", "cost": 10,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.9, 0.6)},
	"ring_scars": {"title": "Ring of Scars", "desc": "+1.5% weapon damage for every point your hand has lost this fight, to blows, burns or your own blood (up to +150%)", "cost": 11,
		"ring": true, "cooldown": 0.0, "shape": "ring", "material": "gold", "gem": Color(0.6, 0.25, 0.25)},
	"ring_bloodletting": {"title": "Ring of Bloodletting", "desc": "RMB: cut your own hand for 10 (never the last point); your next hit does x3", "cost": 9,
		"ring": true, "cooldown": 6.0, "shape": "ring", "material": "gold", "gem": Color(0.7, 0.0, 0.05)},
	"ring_grounding": {"title": "Ring of Grounding", "desc": "shocks can't hurt you", "cost": 9, "ring": true, "shape": "ring", "material": "gold", "gem": Color(0.9, 0.8, 0.3), "cooldown": 0.0},
	"ring_fireward": {"title": "Ring of Fireward", "desc": "heat, fire and frost can't hurt you", "cost": 9, "ring": true, "shape": "ring", "material": "gold", "gem": Color(1.0, 0.3, 0.2), "cooldown": 0.0},
}


# How rare each item is: 0 common, 1 uncommon, 2 rare, 3 legendary (anything not listed
# is uncommon). The shop leans further up this ladder as the run goes on.
const RARITY := {
	"club": 0, "shortsword": 0, "dagger": 0, "buckler": 0, "round_shield": 0, "crate": 0, "rock": 0, "bandage": 0,
	"glue_pot": 0, "resin": 0, "potion_oil": 0, "potion_wood": 0, "coin_purse": 0, "whetstone": 0, "scales": 0, "sentinel_stone": 0,
	"tower_shield": 2, "greatsword": 2, "warhammer": 2, "reliquary": 2, "anvil": 2, "lantern": 2, "potion_iron": 2, "potion_levitation": 2,
	"packrat_idol": 2, "crucible": 2, "wisp_jar": 2,
	"potion_steel": 3, "potion_gold": 3, "potion_homeward": 3, "paragon": 3, "bastion": 3, "potion_prestigium": 3, "stormbrand": 3, "aegis": 3, "hearthblade": 3, "venom_fang": 3, "mirror_shield": 3, "sunderer": 3,
}
# Potions are a novelty, not the stock: they roll at a fraction of the weight of other gear,
# and a shop never holds more than one at a time. Weapons and shields roll a little more
# often than the rest: about three shops in four have a weapon and two in five a shield, so
# an unlucky shop or two still happens, just not as often.
const KIND_WEIGHT := {"potion": 0.22, "weapon": 1.75, "shield": 1.5}
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]
const RARITY_COLORS := [Color(0.7, 0.68, 0.62), Color(0.45, 0.85, 0.4), Color(0.4, 0.65, 1.0), Color(0.95, 0.6, 1.0)]
# per stage of the run: [rounds up to, rarity weights, best material index, modifier chance]
const SHOP_ODDS := [
	[1, [85, 15, 0, 0], 0, 0.12],
	[3, [47, 40, 13, 0], 1, 0.3],
	[5, [25, 42, 32, 1], 2, 0.45],
	[999, [15, 42, 40, 3], 2, 0.55],
]

# More than one modifier is rare, and more than two exceptional. Once a thing has its first,
# the second rolls at EXTRA_MOD (a little more on rarer stock, a lot more as the run
# prestiges), and each one after that at a quarter of the chance before it.
const EXTRA_MOD := 0.06
const EXTRA_MOD_PER_RARITY := 0.02
const EXTRA_MOD_PER_PRESTIGE := 0.05
const EXTRA_MOD_FALLOFF := 0.25
const MAX_MODS := 5
# Rare conditional modifiers (weapons only) roll on their own, on top of the rest.
const RARE_MOD := 0.035
const RARE_MOD_PER_RARITY := 0.02
const RARE_MOD_PER_PRESTIGE := 0.03


# How advanced a material is: an item whose cheapest material is beyond what the run
# allows yet (iron-only strongboxes in the first shop, say) doesn't turn up.
const MAT_RANK := {"iron": 1, "steel": 2, "gold": 2}


static func rarity_of(id: String) -> int:
	return RARITY.get(id, 1)


static func ring_ids() -> Array:
	return UPGRADES.keys().filter(func(k: String) -> bool: return UPGRADES[k].get("ring", false))


static func stat_ids() -> Array:
	return UPGRADES.keys().filter(func(k: String) -> bool: return not UPGRADES[k].get("ring", false))


## A hand upgrade or stat draught for the shop's stat shelf (or a crate). Draughts are
## twice as likely as the dearer permanent upgrades.
static func roll_stat(rng: RandomNumberGenerator, allow_slots: bool = true) -> String:
	var pool: Array = []
	for k in stat_ids():
		if k == "slots" and not allow_slots:
			continue
		pool.append(k)
		if UPGRADES[k].get("material", "") == "glass":
			pool.append(k)
	return pool[rng.randi() % pool.size()]


static func make(id: String, material: String, mods: Array = []) -> Dictionary:
	var d: Dictionary = DEFS[id].duplicate(true)
	d.id = id
	d.material = material
	if d.has("fixed_mods"):
		mods = d.fixed_mods.duplicate()
	if d.has("variants"):
		d.shape = d.variants[randi() % d.variants.size()]
	d.modifiers = mods
	d.rarity = rarity_of(id)
	d.name = d.title if d.has("fixed_mods") else "%s %s" % [material.capitalize(), d.title]
	var price: float = d.price * Materials.get_mat(material).value
	d.size = 1.0
	for m in mods:
		price *= MODIFIERS[m].price
		d.size *= MODIFIERS[m].get("size", 1.0)
	if d.has("swing_damage"):
		d.swing_damage *= d.size  # bigger weapons hit harder (and swing slower, being heavier)
	if material == "prestigium":
		ascend(d)
	d.cost = maxi(1, roundi(price * PRICE_SCALE))
	return d


## A hand upgrade as a physical item.
static func make_upgrade(uid: String) -> Dictionary:
	var u: Dictionary = UPGRADES[uid]
	var d := {"id": uid, "title": u.title, "name": u.title, "kind": "upgrade", "upgrade": uid,
		"shape": u.shape, "material": u.material, "modifiers": [], "size": 1.0,
		"cost": maxi(1, roundi(float(u.cost) * UPGRADE_PRICE_SCALE))}
	if u.has("gem"):
		d.gem = u.gem
	return d


# What a crate holds, by tier: how many rolls, the chance each find carries a modifier,
# and weighted entries. An entry is [weight, def id or "coins" / "upgrade" / "ring", material or coin range].
const LOOT := {
	1: {"rolls": [1, 2], "mod_chance": 0.0, "table": [
		[4, "coins", [2, 5]], [3, "bandage", "cloth"], [2, "glue_pot", "wood"], [2, "rock", "stone"],
		[2, "club", "wood"], [2, "buckler", "wood"], [1, "shortsword", "copper"],
		[2, "potion_oil", "glass"], [1, "potion_mending", "glass"], [1, "potion_copper", "glass"], [1, "potion_frost", "glass"]]},
	2: {"rolls": [2, 2], "mod_chance": 0.3, "table": [
		[4, "coins", [5, 10]], [2, "bandage", "cloth"], [2, "shortsword", "iron"], [2, "shortsword", "copper"],
		[2, "buckler", "iron"], [1, "round_shield", "iron"], [1, "mace", "copper"], [1, "upgrade", ""], [1, "ring", ""],
		[1, "potion_poison", "glass"], [1, "potion_lightning", "glass"], [1, "potion_levitation", "glass"]]},
	3: {"rolls": [3, 3], "mod_chance": 0.5, "table": [
		[3, "coins", [10, 20]], [2, "longsword", "steel"], [2, "mace", "iron"], [2, "kite_shield", "steel"],
		[1, "spear", "steel"], [2, "upgrade", ""], [2, "ring", ""], [1, "potion_iron", "glass"], [1, "potion_steel", "glass"]]},
}


# The starting kit: one cheap weapon, one cheap shield, and a third thing that's usually
# junk but now and then something good. Third-item entries are [weight, id, material or
# coin count / "upgrade" / "ring", modifier chance].
const KIT_WEAPONS := [["club", "wood"], ["shortsword", "copper"], ["spear", "copper"]]
const KIT_SHIELDS := [["buckler", "wood"], ["buckler", "leather"], ["round_shield", "wood"], ["kite_shield", "wood"]]
const KIT_EXTRA := [
	[20, "rock", "stone", 0.0], [15, "bandage", "cloth", 0.0], [12, "glue_pot", "wood", 0.0],
	[15, "crate", "wood", 0.0], [10, "coins", 3, 0.0], [8, "buckler", "copper", 1.0],
	[6, "strongbox", "iron", 0.0], [4, "upgrade", "", 0.0], [3, "ring", "", 0.0],
	[2, "longsword", "steel", 0.5], [1, "reliquary", "steel", 0.0],
	[6, "potion_oil", "glass", 0.0], [4, "potion_mending", "glass", 0.0], [1, "potion_copper", "glass", 0.0]]


## The run's opening kit: item defs, plus {"coins": n} entries.
static func roll_kit(rng: RandomNumberGenerator) -> Array:
	var w: Array = KIT_WEAPONS[rng.randi() % KIT_WEAPONS.size()]
	var sh: Array = KIT_SHIELDS[rng.randi() % KIT_SHIELDS.size()]
	var out: Array = [make(w[0], w[1]), make(sh[0], sh[1])]
	var total := 0
	for e in KIT_EXTRA:
		total += int(e[0])
	var pick := rng.randi() % total
	for e in KIT_EXTRA:
		pick -= int(e[0])
		if pick >= 0:
			continue
		match e[1]:
			"coins":
				out.append({"coins": e[2]})
			"upgrade":
				out.append(make_upgrade(roll_stat(rng)))
			"ring":
				var rings := UPGRADES.keys().filter(func(k: String) -> bool: return UPGRADES[k].get("ring", false))
				out.append(make_upgrade(rings[rng.randi() % rings.size()]))
			_:
				out.append(make(e[1], e[2], roll_mods(rng, float(e[3]), 0, e[1])))
		break
	return out


## Roll a crate's contents: a list of item defs, plus {"coins": n} entries.
static func roll_loot(tier: int, rng: RandomNumberGenerator) -> Array:
	var spec: Dictionary = LOOT[clampi(tier, 1, 3)]
	var table: Array = spec.table
	var total := 0
	for e in table:
		total += int(e[0])
	var out: Array = []
	for r in rng.randi_range(spec.rolls[0], spec.rolls[1]):
		var pick := rng.randi() % total
		var entry: Array = table[0]
		for e in table:
			pick -= int(e[0])
			if pick < 0:
				entry = e
				break
		match entry[1]:
			"coins":
				out.append({"coins": rng.randi_range(entry[2][0], entry[2][1])})
			"upgrade":
				out.append(make_upgrade(roll_stat(rng)))
			"ring":
				var rings := UPGRADES.keys().filter(func(k: String) -> bool: return UPGRADES[k].get("ring", false))
				out.append(make_upgrade(rings[rng.randi() % rings.size()]))
			_:
				out.append(make(entry[1], _maybe_prestigium(entry[1], entry[2], rng), roll_mods(rng, spec.mod_chance, rarity_of(entry[1]), entry[1])))
	return out


## Where a round sits on the shop's ladder. Each prestige pushes the whole run up a stage.
static func shop_stage(round_num: int) -> Array:
	var r := round_num + run_prestige * 2
	for o in SHOP_ODDS:
		if r <= int(o[0]):
			return o
	return SHOP_ODDS[SHOP_ODDS.size() - 1]


static func allowed_now(k: String, best_mat: int) -> bool:
	return DEFS[k].get("shop", true) and MAT_RANK.get(DEFS[k].materials[0], 0) <= best_mat \
		and PRESTIGE.get(k, 0) <= run_prestige


## Shop stock for this point in the run: first a rarity (weighted by how far along it is),
## then an item of that rarity, a material no better than the run allows, and maybe
## modifiers. Early shops are copper and wood; late ones turn up steel and legendaries.
## `only` limits the kinds that can come up (a consumable shelf); `never` rules kinds out.
static func roll_offer(round_num: int, rng: RandomNumberGenerator, only: Array = [], never: Array = []) -> Dictionary:
	var odds: Array = shop_stage(round_num)
	var weights: Array = odds[1]
	var wsum := 0.0
	for w in weights:
		wsum += float(w)
	var pick := rng.randf() * wsum
	var tier := 0
	for i in weights.size():
		pick -= float(weights[i])
		if pick < 0.0:
			tier = i
			break
	var best_mat := int(odds[2]) + (1 if run_prestige >= PRESTIGIUM_PRESTIGE else 0)
	var allowed := func(k: String) -> bool:
		var kind: String = DEFS[k].kind
		return allowed_now(k, best_mat) and (only.is_empty() or only.has(kind)) and not never.has(kind)
	var ids := DEFS.keys().filter(func(k: String) -> bool: return allowed.call(k) and rarity_of(k) == tier)
	if ids.is_empty():
		ids = DEFS.keys().filter(func(k: String) -> bool: return allowed.call(k) and rarity_of(k) <= 1)
	if ids.is_empty():
		ids = DEFS.keys().filter(func(k: String) -> bool: return allowed.call(k))
	var total := 0.0
	for k in ids:
		total += float(KIND_WEIGHT.get(DEFS[k].kind, 1.0))
	var roll := rng.randf() * total
	var id: String = ids[0]
	for k in ids:
		roll -= float(KIND_WEIGHT.get(DEFS[k].kind, 1.0))
		if roll < 0.0:
			id = k
			break
	var mats: Array = DEFS[id].materials
	var best := mini(int(odds[2]), mats.size() - 1)
	var idx := best if rng.randf() < 0.5 else rng.randi_range(0, best)
	return make(id, _maybe_prestigium(id, mats[idx], rng), roll_mods(rng, float(odds[3]) + tier * 0.1, tier, id))


## Past the wall, some plain weapons and shields come in prestigium instead.
static func _maybe_prestigium(id: String, mat: String, rng: RandomNumberGenerator) -> String:
	var d: Dictionary = DEFS[id]
	if run_prestige < PRESTIGIUM_PRESTIGE or d.has("fixed_mods") or not d.kind in ["weapon", "shield"]:
		return mat
	return "prestigium" if rng.randf() < PRESTIGIUM_CHANCE else mat


## A legendary in prestigium: ascended. Double the swing, and its unique behaviour goes
## absurd (main.gd and item.gd read "ascended"). The prestigium-born ones keep their names.
static func ascend(d: Dictionary) -> void:
	if not d.has("legend") or d.get("ascended", false):
		return
	d.ascended = true
	if d.has("swing_damage"):
		d.swing_damage *= ASCEND_DAMAGE
	if d.has("ascended_effect"):
		d.effect = d.ascended_effect
	if DEFS[d.id].materials[0] != "prestigium":
		d.name = "Prestigium " + str(d.title)


## Modifiers for a new thing: `first` is the chance of having any at all; past the first,
## see EXTRA_MOD. Clashing modifiers (same group) are rerolled, not stacked.
static func roll_mods(rng: RandomNumberGenerator, first: float, rarity: int = 0, id: String = "") -> Array:
	var mods: Array = []
	var kind: String = DEFS[id].kind if DEFS.has(id) else ""
	if kind in ["weapon", "shield"] and not DEFS[id].has("fixed_mods") 			and rng.randf() < RARE_MOD + RARE_MOD_PER_RARITY * rarity + RARE_MOD_PER_PRESTIGE * run_prestige:
		var rares := MODIFIERS.keys().filter(func(k: String) -> bool:
			return MODIFIERS[k].get("rare", false) and kind in MODIFIERS[k].get("kinds", ["weapon"]))
		mods.append(rares[rng.randi() % rares.size()])
	if rng.randf() >= first:
		return mods
	var ids := MODIFIERS.keys().filter(func(k: String) -> bool: return not MODIFIERS[k].get("rare", false) and MODIFIERS[k].get("rolls", true))
	var chance := EXTRA_MOD + EXTRA_MOD_PER_RARITY * rarity + EXTRA_MOD_PER_PRESTIGE * run_prestige
	while mods.size() < MAX_MODS:
		for attempt in 8:
			var m: String = ids[rng.randi() % ids.size()]
			if _compatible(m, mods):
				mods.append(m)
				break
		if rng.randf() >= chance:
			break
		chance *= EXTRA_MOD_FALLOFF
	return mods


static func _compatible(m: String, mods: Array) -> bool:
	if mods.has(m):
		return false
	var g: String = MODIFIERS[m].get("group", "")
	if g == "":
		return true
	for other in mods:
		if MODIFIERS[other].get("group", "") == g:
			return false
	return true


## Nearest-neighbour rescale of a pixel mask.
static func scale_mask(mask: PackedStringArray, f: float) -> PackedStringArray:
	if is_equal_approx(f, 1.0) or mask.is_empty():
		return mask
	var w := maxi(1, roundi(mask[0].length() * f))
	var h := maxi(1, roundi(mask.size() * f))
	var out := PackedStringArray()
	for y in h:
		var src: String = mask[mini(int(y / f), mask.size() - 1)]
		var row := ""
		for x in w:
			row += src[mini(int(x / f), src.length() - 1)]
		out.append(row)
	return out


static func shape_mask(shape: String) -> PackedStringArray:
	match shape:
		"buckler":
			return _round(9, 1.5)
		"round":
			return _round(15, 2.0)
		"kite":
			return _kite()
		"tower":
			return _tower()
		"crate":
			return _fill(11, 11, "M")
		"club":
			return _club()
		"shortsword":
			return _blade(2, 13, 6, 4)
		"leaf_short":
			return _leaf(13, 6, 4)
		"tapered_short":
			return _tapered(13, 6, 4)
		"longsword":
			return _blade(2, 24, 8, 7)
		"leaf_long":
			return _leaf(24, 8, 7)
		"tapered_long":
			return _tapered(24, 8, 7)
		"dagger":
			return _tapered(8, 4, 3)
		"falchion":
			return _falchion()
		"greatsword":
			return _blade(3, 28, 10, 8)
		"axe":
			return _axe()
		"warhammer":
			return _warhammer()
		"mace":
			return _mace()
		"spear":
			return _spear()
		"rack":
			return PackedStringArray(["M.M.M.M.M", "MMMMMMMMM", "M.M.M.M.M", "MMMMMMMMM"])
		"pegs":
			return PackedStringArray(["MMMMMMMM", "M..M..M.", "M..M..M."])
		"scales":
			return PackedStringArray(["...M...", "MMMMMMM", "M..M..M", "MM.M.MM", "...M...", "..MMM.."])
		"idol":
			return PackedStringArray([".MM.", "MggM", ".MM.", "MMMM", "MMMM", ".MM.", "MMMM"])
		"banner":
			return PackedStringArray(["wwwwwww", ".MMMMM.", ".MMMMM.", ".MMMMM.", ".MM.MM.", ".M...M."])
		"crucible":
			return PackedStringArray(["MMMMMMM", ".MMMMM.", ".MMMMM.", "..MMM..", ".MMMMM."])
		"lodestone":
			return PackedStringArray([".MMM.", "MMMMM", "MMMMM", "MMMMM", ".MMM."])
		"dressing":
			return PackedStringArray([".cccc.", "cccccc", "llllll", "cccccc", ".cccc."])
		"mortar":
			return PackedStringArray(["....w", "M..wM", "MMMMM", ".MMM.", ".MMM."])
		"shirt":
			return PackedStringArray(["MM.MM", "MMMMM", ".MMM.", ".MMM.", ".MMM."])
		"sentinel":
			return PackedStringArray(["..M..", ".MMM.", ".MgM.", ".MMM.", "MMMMM", "MMMMM"])
		"wisp":
			return PackedStringArray([".hh.", "MMMM", "MggM", "MggM", ".MM."])
		"resin":
			return PackedStringArray(["MMMMM", "MMMMM", "MMMMM"])
		"spikes":
			return PackedStringArray(["M.M.M.M", "MMMMMMM", "MMMMMMM"])
		"mirror":
			return PackedStringArray([".MMM.", "MgggM", "MgggM", ".MMM.", "..w..", "..w.."])
		"bandage":
			return _fill(5, 3, "c")
		"rock":
			var rows := _round(7, 0.0)
			for i in rows.size():
				rows[i] = rows[i].replace("M", "s")
			return rows
		"pot":
			return PackedStringArray([".cc.", "wwww", "wwww", ".ww."])
		"coin":
			return PackedStringArray(["MM", "MM"])
		"coin5":
			return PackedStringArray([".MM.", "MMMM", "MMMM", ".MM."])
		"bar":
			return PackedStringArray([".MMMMM.", "MMMMMMM", "MMMMMMM"])
		"pauldron":
			return PackedStringArray(["..MMM..", ".MMMMM.", "MMMMMMM", "MM...MM"])
		"gauntlet":
			return PackedStringArray([".M.M.", "MMMMM", "MMMMM", ".MMM.", ".lll."])
		"salve":
			return PackedStringArray([".cc.", "wwww", "wwww"])
		"charm":
			return PackedStringArray([".M.", "MMM", ".M."])
		"wristband":
			return PackedStringArray(["MMMMMM", "MMMMMM"])
		"ring":
			return PackedStringArray([".M.", "MgM", ".M."])
		"purse":
			return PackedStringArray([".MM.", "MMMM", "MMMM", ".MM."])
		"book":
			return PackedStringArray(["MMMMMM", "MccccM", "MMMMMM"])
		"tooth":
			return PackedStringArray(["MMM", "MMM", "MMM", "M.M"])
		"journal":
			return PackedStringArray(["MMMMM", "McccM", "MMMMM", "..g.."])
		"tablet":
			return PackedStringArray([".MMMM.", "MMMMMM", "MgMgMM", "MMgMgM", "MMMMMM"])
		"map":
			return PackedStringArray(["wccccccw", ".cccccc.", ".cccccc.", "wccccccw"])
		"whetstone":
			return PackedStringArray(["MMMMMMM", "MMMMMMM"])
		"anvil":
			return PackedStringArray(["MMMMMMMM", ".MMMMMM.", "..MMMM..", ".MMMMMM."])
		"horseshoe":
			return PackedStringArray(["M...M", "M...M", "M...M", ".MMM."])
		"flask":
			return PackedStringArray([".w.", ".M.", "MMM", "MMM", ".M."])
		"hammer":
			var rows := PackedStringArray(["MMMMMMM", "MMMMMMM", "MMMMMMM"])
			for y in 13:
				rows.append("...h..." if y >= 5 else "...w...")
			return rows
		"lantern":
			return PackedStringArray([".M.", "MMM", "MgM", "MgM", "MMM"])
		"skull":
			return PackedStringArray([".MMMM.", "MMMMMM", "M.MM.M", "MMMMMM", ".M.M.."])
		"band":
			return PackedStringArray([".MM.", "M..M", ".MM."])
	return PackedStringArray(["M"])


static func _round(d: int, boss: float) -> PackedStringArray:
	var out := PackedStringArray()
	var r := d / 2.0
	for y in d:
		var row := ""
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			row += "i" if dist < boss else ("M" if dist <= r else ".")
		out.append(row)
	return out


static func _kite() -> PackedStringArray:
	var w := 12
	var h := 18
	var out := PackedStringArray()
	for y in h:
		var half: float
		if y < 4:
			half = 6.0 * sqrt(1.0 - pow((4 - y - 0.5) / 4.0, 2))
		else:
			half = 6.0 * (1.0 - float(y - 4) / float(h - 4)) + 0.6
		var row := ""
		for x in w:
			row += "M" if absf(x + 0.5 - 6.0) <= half else "."
		out.append(row)
	return out


static func _tower() -> PackedStringArray:
	var out := PackedStringArray()
	for y in 22:
		out.append(("i" if y % 7 == 3 else "M").repeat(13))
	return out


static func _fill(w: int, h: int, ch: String) -> PackedStringArray:
	var out := PackedStringArray()
	for y in h:
		out.append(ch.repeat(w))
	return out


static func _centered(fill: String, width: int, total: int) -> String:
	var off := int((total - width) / 2.0)
	return ".".repeat(off) + fill.repeat(width) + ".".repeat(total - off - width)


static func _blade(bw: int, blen: int, gw: int, glen: int) -> PackedStringArray:
	var out := PackedStringArray()
	for y in blen:
		out.append(_centered("M", bw, gw))
	out.append("M".repeat(gw))
	for y in glen:
		out.append(_centered("h", bw, gw))
	out.append(_centered("M", bw, gw))
	return out


## A leaf blade: swells in the middle, comes to a point.
static func _leaf(blen: int, gw: int, glen: int) -> PackedStringArray:
	var out := PackedStringArray()
	for y in blen:
		var k := float(y) / float(blen - 1)
		var w := 1 if k < 0.12 else (3 if k > 0.3 and k < 0.75 else 2)
		out.append(_centered("M", w, gw))
	out.append("M".repeat(gw))
	for y in glen:
		out.append(_centered("h", 2, gw))
	out.append(_centered("M", 2, gw))
	return out


## A tapered blade: wide at the guard, narrowing to a point.
static func _tapered(blen: int, gw: int, glen: int) -> PackedStringArray:
	var out := PackedStringArray()
	for y in blen:
		var k := float(y) / float(blen - 1)
		var w := 1 if k < 0.2 else (2 if k < 0.6 else 3)
		out.append(_centered("M", w, gw))
	out.append("M".repeat(gw))
	for y in glen:
		out.append(_centered("h", 2, gw))
	out.append(_centered("M", 2, gw))
	return out


## A falchion: a cleaver-like blade, broad towards the tip, with a short guard.
static func _falchion() -> PackedStringArray:
	var out := PackedStringArray()
	for y in 15:
		var w := 2 if y < 2 else (4 if y < 9 else 3)
		out.append(".".repeat(1) + "M".repeat(w) + ".".repeat(5 - w))
	out.append("MMMMM.")
	for y in 4:
		out.append(".hh...")
	out.append(".MM...")
	return out


## An axe: a head on one side of a long haft.
static func _axe() -> PackedStringArray:
	var out := PackedStringArray(["MMMM..", "MMMMw.", "MMMMw.", "MMMMw.", ".MMMw.", "..MMw."])
	for y in 14:
		out.append("....w." if y < 6 else "....h.")
	return out


## A warhammer: a square head with a spike behind it, on a shorter haft.
static func _warhammer() -> PackedStringArray:
	var out := PackedStringArray(["MMMMM.M", "MMMMMMM", "MMMMM.M", "MMMMM.."])
	for y in 12:
		out.append("..w...." if y < 5 else "..h....")
	return out


static func _club() -> PackedStringArray:
	var out := PackedStringArray()
	for y in 6:
		out.append("wwww")
	for y in 4:
		out.append(".ww.")
	for y in 8:
		out.append(".hh.")
	return out


static func _mace() -> PackedStringArray:
	var out := PackedStringArray([".MMMM.", "MMMMMM", "MMMMMM", "MMMMMM", ".MMMM."])
	for y in 15:
		out.append("..ww.." if y < 8 else "..hh..")
	return out


static func _spear() -> PackedStringArray:
	var out := PackedStringArray([".MM.", "MMMM", "MMMM", ".MM."])
	for y in 28:
		out.append(".ww." if y < 16 else ".hh.")
	return out
