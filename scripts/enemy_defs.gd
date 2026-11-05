class_name EnemyDefs
extends RefCounted
## Attacks and enemy movesets.
## zone      polygon in normalized screen space (0..1); whatever sits there when it lands gets hit
## dir       which way the blade travels: it's stopped by the first things it meets along that line
##           (zero = a thrust straight at the screen: every point is its own line)
## damage    total damage if nothing blocks (goes to the player's hands)
## impact    cell damage where the blade meets an item (how hard it chews up gear). Nothing ever
##           pierces a block: an attack that's "good against gear" just wrecks what blocks it.
## push      impulse on items for full coverage
## windup    seconds of telegraph (divided by the enemy's speed)
## pose      procedural hand pose; once HeadnHands clips exist, "clip" names the act_ clip to play instead
## trait     what the weapon does to gear it touches: corrosive (rusts metal), burning (heats it)
## track     the zone is centred on wherever your hand was when the wind-up began
## next      a follow-up attack chained straight after this one, with its own short wind-up
## cleave    0..1: how much of the blow goes on through each thing that blocks it. A big
##           enemy's swing chews through the front of your pile and into what's behind it
##           (each piece still takes the full hit; only a parry stops it outright).

const ATTACKS := {
	# --- plain steel ---------------------------------------------------------------
	"slash_high_r": {"zone": [Vector2(0, 0.19), Vector2(1, 0.19), Vector2(1, 0.35), Vector2(0, 0.35)],
		"dir": Vector2(-1, 0), "damage": 28.0, "impact": 1.3, "push": 26000.0, "windup": 1.1, "pose": "high_right"},
	"slash_high_l": {"zone": [Vector2(0, 0.19), Vector2(1, 0.19), Vector2(1, 0.35), Vector2(0, 0.35)],
		"dir": Vector2(1, 0), "damage": 28.0, "impact": 1.3, "push": 26000.0, "windup": 1.1, "pose": "high_left"},
	"slash_low": {"zone": [Vector2(0, 0.65), Vector2(1, 0.65), Vector2(1, 0.81), Vector2(0, 0.81)],
		"dir": Vector2(-1, 0.1), "damage": 26.0, "impact": 1.2, "push": 24000.0, "windup": 1.0, "pose": "low"},
	"overhead_l": {"zone": [Vector2(0.235, 0), Vector2(0.325, 0), Vector2(0.325, 1), Vector2(0.235, 1)],
		"dir": Vector2(0, 1), "damage": 32.0, "impact": 1.6, "push": 30000.0, "windup": 1.3, "pose": "overhead_l"},
	"overhead_r": {"zone": [Vector2(0.675, 0), Vector2(0.765, 0), Vector2(0.765, 1), Vector2(0.675, 1)],
		"dir": Vector2(0, 1), "damage": 32.0, "impact": 1.6, "push": 30000.0, "windup": 1.3, "pose": "overhead_r"},
	"thrust": {"zone": [Vector2(0.5, 0.44), Vector2(0.535, 0.5), Vector2(0.5, 0.56), Vector2(0.465, 0.5)],
		"dir": Vector2.ZERO, "damage": 34.0, "impact": 2.6, "push": 8000.0, "windup": 0.9, "pose": "thrust"},
	"sweep": {"zone": [Vector2(0, 0.5), Vector2(1, 0.25), Vector2(1, 0.42), Vector2(0, 0.67)],
		"dir": Vector2(1, -0.3), "damage": 36.0, "impact": 1.4, "push": 40000.0, "windup": 1.5, "pose": "sweep"},
	"slam": {"zone": [Vector2(0.32, 0.6), Vector2(0.68, 0.6), Vector2(0.68, 1), Vector2(0.32, 1)],
		"dir": Vector2(0, 1), "damage": 44.0, "impact": 2.0, "push": 45000.0, "windup": 1.7, "pose": "slam", "cleave": 0.45},
	# --- the secret guardians' own attacks ------------------------------------------
	# Coin Golem: a gold bar hurled at the hand, and a body-slam that buries the floor in coin
	"coin_toss": {"zone": [Vector2(0.5, 0.43), Vector2(0.55, 0.5), Vector2(0.5, 0.57), Vector2(0.45, 0.5)],
		"dir": Vector2.ZERO, "damage": 30.0, "impact": 2.2, "push": 12000.0, "windup": 1.0, "pose": "thrust", "track": true},
	# Housecat: swipes from either side, a pounce at the hand, a tail lash along the floor
	"swipe_l": {"zone": [Vector2(0, 0.25), Vector2(0.55, 0.25), Vector2(0.55, 0.6), Vector2(0, 0.6)],
		"dir": Vector2(1, 0.2), "damage": 20.0, "impact": 1.0, "push": 30000.0, "windup": 0.9, "pose": "high_left"},
	"swipe_r": {"zone": [Vector2(0.45, 0.25), Vector2(1, 0.25), Vector2(1, 0.6), Vector2(0.45, 0.6)],
		"dir": Vector2(-1, 0.2), "damage": 20.0, "impact": 1.0, "push": 30000.0, "windup": 0.9, "pose": "high_right"},
	"pounce": {"zone": [Vector2(0.5, 0.4), Vector2(0.58, 0.5), Vector2(0.5, 0.6), Vector2(0.42, 0.5)],
		"dir": Vector2.ZERO, "damage": 30.0, "impact": 1.6, "push": 20000.0, "windup": 1.1, "pose": "lunge", "track": true},
	"tail_lash": {"zone": [Vector2(0, 0.72), Vector2(1, 0.72), Vector2(1, 0.92), Vector2(0, 0.92)],
		"dir": Vector2(1, 0), "damage": 18.0, "impact": 0.9, "push": 50000.0, "windup": 1.0, "pose": "low_left"},
	# The Astronomer: a comet down at the hand, an orbit sweeping the middle, and the pull of the
	# heavens let go of: everything you own falls upward for a moment
	"comet": {"zone": [Vector2(0.5, 0.42), Vector2(0.55, 0.5), Vector2(0.5, 0.58), Vector2(0.45, 0.5)],
		"dir": Vector2.ZERO, "damage": 34.0, "impact": 2.4, "push": 9000.0, "windup": 1.0, "pose": "thrust", "trait": "charged", "track": true},
	"orbit": {"zone": [Vector2(0, 0.55), Vector2(1, 0.3), Vector2(1, 0.46), Vector2(0, 0.71)],
		"dir": Vector2(1, -0.25), "damage": 28.0, "impact": 1.2, "push": 36000.0, "windup": 1.3, "pose": "sweep", "trait": "charged"},
	"unmoor": {"zone": [Vector2(0, 0.6), Vector2(1, 0.6), Vector2(1, 1), Vector2(0, 1)],
		"dir": Vector2(0, -1), "damage": 12.0, "impact": 0.5, "push": 4000.0, "windup": 1.6, "pose": "grasp", "unmoor": true},
	# --- the Woodcutter's felling axe: big, wide, honest swings, every one called out from
	# far off. Any shield in the right place stops them. No thrusts, nothing quick.
	"chop_l": {"zone": [Vector2(0.12, 0), Vector2(0.4, 0), Vector2(0.4, 1), Vector2(0.12, 1)],
		"dir": Vector2(0, 1), "damage": 22.0, "impact": 1.4, "push": 26000.0, "windup": 1.5, "pose": "overhead_l"},
	"chop_r": {"zone": [Vector2(0.6, 0), Vector2(0.88, 0), Vector2(0.88, 1), Vector2(0.6, 1)],
		"dir": Vector2(0, 1), "damage": 22.0, "impact": 1.4, "push": 26000.0, "windup": 1.5, "pose": "overhead_r"},
	"hew": {"zone": [Vector2(0, 0.38), Vector2(1, 0.38), Vector2(1, 0.56), Vector2(0, 0.56)],
		"dir": Vector2(-1, 0), "damage": 24.0, "impact": 1.3, "push": 30000.0, "windup": 1.6, "pose": "high_right"},
	"fell": {"zone": [Vector2(0, 0.68), Vector2(1, 0.68), Vector2(1, 0.86), Vector2(0, 0.86)],
		"dir": Vector2(1, 0.05), "damage": 22.0, "impact": 1.2, "push": 28000.0, "windup": 1.4, "pose": "low_left"},
	# --- the Brute's maul: the whole floor at once. Everything down there takes the hit,
	# and the maul chews gear up. Fragile hoards get wrecked; spiked steel hoards eat it alive.
	"ground_pound": {"zone": [Vector2(0, 0.62), Vector2(1, 0.62), Vector2(1, 1), Vector2(0, 1)],
		"dir": Vector2(0, 1), "damage": 40.0, "impact": 2.4, "push": 50000.0, "windup": 1.9, "pose": "slam", "cleave": 0.3},
	# (act: the maul dragged back along the floor, then heaved across it: the field travels with the head)
	"maul_low_l": {"zone": [Vector2(0, 0.55), Vector2(0.38, 0.55), Vector2(0.38, 1), Vector2(0, 1)],
		"dir": Vector2(1, 0.1), "damage": 42.0, "impact": 2.2, "push": 45000.0, "windup": 1.7, "pose": "low_left", "cleave": 0.2, "pan": Vector2(0.45, 0)},
	"maul_low_r": {"zone": [Vector2(0.62, 0.55), Vector2(1, 0.55), Vector2(1, 1), Vector2(0.62, 1)],
		"dir": Vector2(-1, 0.1), "damage": 42.0, "impact": 2.2, "push": 45000.0, "windup": 1.7, "pose": "low", "cleave": 0.2, "pan": Vector2(-0.45, 0)},
	# --- light blades: small cuts all over the screen, quick and soft. Some chain a second cut.
	"cut_tl": {"zone": [Vector2(0.04, 0.12), Vector2(0.34, 0.12), Vector2(0.34, 0.21), Vector2(0.04, 0.21)],
		"dir": Vector2(1, 0), "damage": 14.0, "impact": 0.7, "push": 8000.0, "windup": 0.65, "pose": "high_left",
		"next": "cut_mr", "next_windup": 0.4},
	"cut_tr": {"zone": [Vector2(0.66, 0.12), Vector2(0.96, 0.12), Vector2(0.96, 0.21), Vector2(0.66, 0.21)],
		"dir": Vector2(-1, 0), "damage": 14.0, "impact": 0.7, "push": 8000.0, "windup": 0.65, "pose": "high_right",
		"next": "cut_ml", "next_windup": 0.4},
	"cut_ml": {"zone": [Vector2(0.04, 0.4), Vector2(0.34, 0.4), Vector2(0.34, 0.49), Vector2(0.04, 0.49)],
		"dir": Vector2(1, 0), "damage": 13.0, "impact": 0.7, "push": 8000.0, "windup": 0.65, "pose": "high_left"},
	"cut_mr": {"zone": [Vector2(0.66, 0.4), Vector2(0.96, 0.4), Vector2(0.96, 0.49), Vector2(0.66, 0.49)],
		"dir": Vector2(-1, 0), "damage": 13.0, "impact": 0.7, "push": 8000.0, "windup": 0.65, "pose": "high_right"},
	"cut_tc": {"zone": [Vector2(0.36, 0.24), Vector2(0.64, 0.24), Vector2(0.64, 0.32), Vector2(0.36, 0.32)],
		"dir": Vector2(-1, 0), "damage": 15.0, "impact": 0.8, "push": 8000.0, "windup": 0.7, "pose": "high_right"},
	"jab": {"zone": [Vector2(0.5, 0.45), Vector2(0.53, 0.5), Vector2(0.5, 0.55), Vector2(0.47, 0.5)],
		"dir": Vector2.ZERO, "damage": 15.0, "impact": 1.0, "push": 4000.0, "windup": 0.6, "pose": "thrust", "track": true},
	# --- the Duelist's rapier: thin, quick lines that slip between whatever's piled up ----
	"lunge": {"zone": [Vector2(0.3, 0.47), Vector2(1, 0.47), Vector2(1, 0.53), Vector2(0.3, 0.53)],
		"dir": Vector2(-1, 0), "damage": 24.0, "impact": 0.8, "push": 6000.0, "windup": 0.6, "pose": "lunge"},
	"flick_high": {"zone": [Vector2(0, 0.13), Vector2(1, 0.13), Vector2(1, 0.2), Vector2(0, 0.2)],
		"dir": Vector2(-1, 0), "damage": 18.0, "impact": 0.7, "push": 8000.0, "windup": 0.55, "pose": "high_right"},
	"riposte": {"zone": [Vector2(0.5, 0.45), Vector2(0.54, 0.5), Vector2(0.5, 0.55), Vector2(0.46, 0.5)],
		"dir": Vector2.ZERO, "damage": 26.0, "impact": 1.6, "push": 6000.0, "windup": 0.5, "pose": "thrust", "track": true},
	# --- the Rusted's rotten blade: what blocks it starts to rust ------------------------
	# (act: the blade's point dragged along the floor from left to right, scraping)
	"drag_low": {"zone": [Vector2(0, 0.72), Vector2(0.45, 0.72), Vector2(0.45, 0.9), Vector2(0, 0.9)],
		"dir": Vector2(1, 0.05), "damage": 24.0, "impact": 1.0, "push": 20000.0, "windup": 1.4, "pose": "low_left", "trait": "corrosive", "cleave": 0.25, "pan": Vector2(0.55, 0)},
	"rake": {"zone": [Vector2(0, 0.18), Vector2(0.14, 0.1), Vector2(1, 0.78), Vector2(0.86, 0.9)],
		"dir": Vector2(1, 0.75), "damage": 30.0, "impact": 1.4, "push": 28000.0, "windup": 1.4, "pose": "sweep", "trait": "corrosive"},
	"spit": {"zone": [Vector2(0.5, 0.44), Vector2(0.56, 0.5), Vector2(0.5, 0.56), Vector2(0.44, 0.5)],
		"dir": Vector2.ZERO, "damage": 14.0, "impact": 3.0, "push": 3000.0, "windup": 1.0, "pose": "spit", "trait": "corrosive", "track": true},
	# --- the Zealot's brazier-flail: burning coals. Wood and leather catch; metal heats up ---
	# (act: the chain whirled overhead, the line of the swing turning with it, then let fly)
	"flail_arc": {"zone": [Vector2(0.85, 0.08), Vector2(1, 0.2), Vector2(0.15, 0.92), Vector2(0, 0.8)],
		"dir": Vector2(-1, 0.85), "damage": 32.0, "impact": 1.3, "push": 34000.0, "windup": 1.5, "pose": "sweep", "trait": "burning", "turn": 0.55},
	"ember_rain": {"zone": [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.45), Vector2(0, 0.45)],
		"dir": Vector2.ZERO, "damage": 16.0, "impact": 0.6, "push": 2000.0, "windup": 1.6, "pose": "overhead_r", "trait": "burning"},
	# (act: the brazier held out at arm's length, following the player's hand, then thrust)
	"brand": {"zone": [Vector2(0.5, 0.43), Vector2(0.54, 0.5), Vector2(0.5, 0.57), Vector2(0.46, 0.5)],
		"dir": Vector2.ZERO, "damage": 30.0, "impact": 2.0, "push": 8000.0, "windup": 1.1, "pose": "thrust", "trait": "burning", "chase": 0.65},
	# --- the Wraith: huge, soft hits that reach everywhere, and a grasp that comes for the hand ---
	# (act: both hands reach out and follow the player's hand round the screen, then close)
	"grasp": {"zone": [Vector2(0.38, 0.38), Vector2(0.62, 0.38), Vector2(0.62, 0.62), Vector2(0.38, 0.62)],
		"dir": Vector2.ZERO, "damage": 22.0, "impact": 0.5, "push": 0.0, "windup": 1.4, "pose": "grasp", "chase": 0.8},
	"shroud_l": {"zone": [Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 1), Vector2(0, 1)],
		"dir": Vector2(1, 0), "damage": 20.0, "impact": 0.5, "push": 15000.0, "windup": 1.5, "pose": "high_left"},
	"shroud_r": {"zone": [Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1)],
		"dir": Vector2(-1, 0), "damage": 20.0, "impact": 0.5, "push": 15000.0, "windup": 1.5, "pose": "high_right"},
	# --- the Headsman's axe: slow, enormous, and it goes through gear like kindling ---------
	"cleave": {"zone": [Vector2(0.3, 0), Vector2(0.7, 0), Vector2(0.7, 1), Vector2(0.3, 1)],
		"dir": Vector2(0, 1), "damage": 50.0, "impact": 3.2, "push": 60000.0, "windup": 2.2, "pose": "slam", "cleave": 0.45},
	"low_cleave": {"zone": [Vector2(0, 0.55), Vector2(1, 0.55), Vector2(1, 0.95), Vector2(0, 0.95)],
		"dir": Vector2(-1, 0.05), "damage": 48.0, "impact": 3.0, "push": 55000.0, "windup": 2.0, "pose": "low", "cleave": 0.45},
	"behead": {"zone": [Vector2(0, 0.44), Vector2(1, 0.44), Vector2(1, 0.56), Vector2(0, 0.56)],
		"dir": Vector2(-1, 0), "damage": 46.0, "impact": 2.8, "push": 50000.0, "windup": 2.0, "pose": "high_right", "cleave": 0.45,
		"chase": 0.65, "chase_axis": Vector2(0, 1),
		"act": "the axe drawn back level at shoulder height, its line rising and falling with the player's hand, then swung flat across"},
	# --- the Lamplighter's staff: lightning. What blocks it is charged, and charge flows through metal ---
	# (act: the staff's tip points at the player's hand and follows it, crackling, then jabs)
	"spark": {"zone": [Vector2(0.5, 0.42), Vector2(0.58, 0.5), Vector2(0.5, 0.58), Vector2(0.42, 0.5)],
		"dir": Vector2.ZERO, "damage": 20.0, "impact": 1.0, "push": 4000.0, "windup": 1.0, "pose": "thrust", "trait": "charged", "chase": 0.6},
	# (act: the staff swung up from low left, the arc of it rising as it comes)
	"arc_lash": {"zone": [Vector2(0, 0.6), Vector2(0.12, 0.72), Vector2(1, 0.22), Vector2(0.9, 0.1)],
		"dir": Vector2(1, -0.55), "damage": 26.0, "impact": 0.9, "push": 20000.0, "windup": 1.2, "pose": "sweep", "trait": "charged", "turn": -0.2},
	"lantern_swing": {"zone": [Vector2(0, 0.66), Vector2(1, 0.66), Vector2(1, 0.84), Vector2(0, 0.84)],
		"dir": Vector2(-1, 0.1), "damage": 24.0, "impact": 1.1, "push": 40000.0, "windup": 1.2, "pose": "low", "trait": "charged"},
	# --- the Halberdier's polearm: reach. A blade swept along the whole floor, a pike that
	# hunts your hand along its line, a hook pulled down from above, a jab with the butt.
	# (act: both hands on one long pole throughout)
	"reap": {"zone": [Vector2(0.04, 0.38), Vector2(0.2, 0.38), Vector2(0.2, 0.96), Vector2(0.04, 0.96)],
		"dir": Vector2(1, 0), "damage": 30.0, "impact": 1.6, "push": 40000.0, "windup": 1.8, "pose": "reap", "pan": Vector2(0.72, 0),
		"act": "the blade swung low from the left and walked steadily across to the right"},
	"pike": {"zone": [Vector2(0.14, 0.465), Vector2(1, 0.465), Vector2(1, 0.535), Vector2(0.14, 0.535)],
		"dir": Vector2(-1, 0), "damage": 28.0, "impact": 1.2, "push": 20000.0, "windup": 1.3, "pose": "lunge", "chase": 0.7, "chase_axis": Vector2(0, 1),
		"act": "the pole levelled at the player's hand, rising and dipping with it, then driven straight out"},
	"hook": {"zone": [Vector2(0, 0.06), Vector2(1, 0.06), Vector2(1, 0.2), Vector2(0, 0.2)],
		"dir": Vector2(-1, 0.15), "damage": 24.0, "impact": 1.1, "push": 26000.0, "windup": 1.4, "pose": "high_right", "pan": Vector2(0, 0.3),
		"act": "the hooked back of the head raised high, then hauled down and across"},
	"butt": {"zone": [Vector2(0.5, 0.74), Vector2(0.55, 0.81), Vector2(0.5, 0.88), Vector2(0.45, 0.81)],
		"dir": Vector2.ZERO, "damage": 16.0, "impact": 1.4, "push": 9000.0, "windup": 0.7, "pose": "thrust",
		"act": "a short, sharp jab low with the butt of the pole"},
	# --- the Twinblade's two sabres: one cut after the other, crossing. (act: a blade in each hand)
	"x_right": {"zone": [Vector2(0.6, 0.06), Vector2(0.76, 0.06), Vector2(0.4, 0.94), Vector2(0.24, 0.94)],
		"dir": Vector2(-0.45, 1), "damage": 18.0, "impact": 0.9, "push": 12000.0, "windup": 0.85, "pose": "high_right", "next": "x_left", "next_windup": 0.3,
		"act": "right blade cuts down from high right to low left; the left blade answers across it"},
	"x_left": {"zone": [Vector2(0.24, 0.06), Vector2(0.4, 0.06), Vector2(0.76, 0.94), Vector2(0.6, 0.94)],
		"dir": Vector2(0.45, 1), "damage": 18.0, "impact": 0.9, "push": 12000.0, "windup": 0.85, "pose": "off_high",
		"act": "left blade cuts down from high left to low right"},
	"scissor_hi": {"zone": [Vector2(0, 0.12), Vector2(1, 0.12), Vector2(1, 0.24), Vector2(0, 0.24)],
		"dir": Vector2(1, 0), "damage": 16.0, "impact": 0.8, "push": 10000.0, "windup": 1.0, "pose": "off_high", "pan": Vector2(0, 0.18), "next": "scissor_lo", "next_windup": 0.28,
		"act": "both blades opened wide, one high and one low; the high one closes down first"},
	"scissor_lo": {"zone": [Vector2(0, 0.76), Vector2(1, 0.76), Vector2(1, 0.88), Vector2(0, 0.88)],
		"dir": Vector2(-1, 0), "damage": 16.0, "impact": 0.8, "push": 10000.0, "windup": 0.9, "pose": "low", "pan": Vector2(0, -0.18),
		"act": "the low blade closes up to meet it"},
	"flurry_l": {"zone": [Vector2(0.04, 0.4), Vector2(0.46, 0.4), Vector2(0.46, 0.5), Vector2(0.04, 0.5)],
		"dir": Vector2(1, 0), "damage": 12.0, "impact": 0.7, "push": 8000.0, "windup": 0.6, "pose": "off_low", "next": "flurry_r", "next_windup": 0.22,
		"act": "a quick flat cut with the left, the right already coming"},
	"flurry_r": {"zone": [Vector2(0.54, 0.5), Vector2(0.96, 0.5), Vector2(0.96, 0.6), Vector2(0.54, 0.6)],
		"dir": Vector2(-1, 0), "damage": 12.0, "impact": 0.7, "push": 8000.0, "windup": 0.6, "pose": "high_right",
		"act": "the right answers, a hand's width lower"},
	# --- the Bonebreaker's mace: it hits the same place twice. The first blow knocks your gear
	# loose; the second lands where it was. (act: one heavy flanged mace, right hand)
	"crush_l": {"zone": [Vector2(0.18, 0), Vector2(0.36, 0), Vector2(0.36, 1), Vector2(0.18, 1)],
		"dir": Vector2(0, 1), "damage": 28.0, "impact": 2.8, "push": 42000.0, "windup": 1.3, "pose": "overhead_l", "next": "recrush_l", "next_windup": 0.5,
		"act": "mace raised over the left shoulder and brought straight down, then lifted and dropped again on the same spot"},
	"recrush_l": {"zone": [Vector2(0.18, 0), Vector2(0.36, 0), Vector2(0.36, 1), Vector2(0.18, 1)],
		"dir": Vector2(0, 1), "damage": 22.0, "impact": 2.4, "push": 30000.0, "windup": 0.5, "pose": "overhead_l",
		"act": "the second drop, shorter"},
	"crush_r": {"zone": [Vector2(0.64, 0), Vector2(0.82, 0), Vector2(0.82, 1), Vector2(0.64, 1)],
		"dir": Vector2(0, 1), "damage": 28.0, "impact": 2.8, "push": 42000.0, "windup": 1.3, "pose": "overhead_r", "next": "recrush_r", "next_windup": 0.5,
		"act": "mace over the right shoulder, straight down, and again"},
	"recrush_r": {"zone": [Vector2(0.64, 0), Vector2(0.82, 0), Vector2(0.82, 1), Vector2(0.64, 1)],
		"dir": Vector2(0, 1), "damage": 22.0, "impact": 2.4, "push": 30000.0, "windup": 0.5, "pose": "overhead_r",
		"act": "the second drop, shorter"},
	"mace_arc": {"zone": [Vector2(0, 0.38), Vector2(0.6, 0.38), Vector2(0.6, 0.56), Vector2(0, 0.56)],
		"dir": Vector2(1, 0.1), "damage": 26.0, "impact": 2.2, "push": 36000.0, "windup": 1.2, "pose": "high_left", "turn": 0.5,
		"act": "a wide backhand that rolls over as it comes, the head dipping"},
	"pommel": {"zone": [Vector2(0.5, 0.44), Vector2(0.55, 0.5), Vector2(0.5, 0.56), Vector2(0.45, 0.5)],
		"dir": Vector2.ZERO, "damage": 16.0, "impact": 1.6, "push": 8000.0, "windup": 0.75, "pose": "thrust", "track": true,
		"act": "a short punch with the butt of the haft at the player's hand"},
	# --- the Sexton's bell and grave spade (act: a great bell on a pole in the right hand, a
	# spade in the left). The bell tolls twice on one spot, and the second ring scatters what's there.
	"toll": {"zone": [Vector2(0.37, 0), Vector2(0.63, 0), Vector2(0.63, 1), Vector2(0.37, 1)],
		"dir": Vector2(0, 1), "damage": 38.0, "impact": 2.6, "push": 40000.0, "windup": 1.5, "pose": "slam", "cleave": 0.25,
		"next": "toll_echo", "next_windup": 0.45, "sound": ["gong", -2.0, 0.55],
		"act": "the bell heaved up overhead in both hands and brought straight down; it rings, and he lets it ring down again on the same spot"},
	"toll_echo": {"zone": [Vector2(0.37, 0), Vector2(0.63, 0), Vector2(0.63, 1), Vector2(0.37, 1)],
		"dir": Vector2(0, 1), "damage": 20.0, "impact": 1.4, "push": 70000.0, "windup": 0.45, "pose": "slam", "sound": ["gong", -6.0, 0.8],
		"act": "the second, shorter toll: the ring that scatters"},
	"peal": {"zone": [Vector2(0, 0.5), Vector2(1, 0.25), Vector2(1, 0.42), Vector2(0, 0.67)],
		"dir": Vector2(1, -0.3), "damage": 32.0, "impact": 1.8, "push": 45000.0, "windup": 1.5, "pose": "sweep", "turn": 0.25, "sound": ["gong", -8.0, 1.1],
		"act": "the bell swung round on its pole in a wide arc, the line of it turning as it comes"},
	"dig": {"zone": [Vector2(0, 0.66), Vector2(0.32, 0.66), Vector2(0.32, 0.95), Vector2(0, 0.95)],
		"dir": Vector2(1, 0), "damage": 26.0, "impact": 2.0, "push": 30000.0, "windup": 1.4, "pose": "off_low", "cleave": 0.2, "pan": Vector2(0.62, 0),
		"act": "the spade (left hand) driven into the floor at the left and scooped steadily across to the right"},
	"bury": {"zone": [Vector2(0.4, 0.3), Vector2(0.6, 0.3), Vector2(0.6, 0.7), Vector2(0.4, 0.7)],
		"dir": Vector2(0, 1), "damage": 34.0, "impact": 2.4, "push": 30000.0, "windup": 1.3, "pose": "off_high", "cleave": 0.3, "chase": 0.6,
		"act": "the spade raised high over the player's hand, following it, then driven straight down"},
	"knell": {"zone": [Vector2(0.5, 0.42), Vector2(0.56, 0.5), Vector2(0.5, 0.58), Vector2(0.44, 0.5)],
		"dir": Vector2.ZERO, "damage": 24.0, "impact": 1.8, "push": 20000.0, "windup": 1.0, "pose": "thrust", "chase": 0.7, "sound": ["gong", -10.0, 1.3],
		"act": "the bell's mouth shoved out at the player's hand, following it, then thrust"},
	# --- the Smelter: molten slag. Everything it throws burns what blocks it, and the floor
	# itself erupts. (act: no weapon: two huge fists of hot rock)
	"pour": {"zone": [Vector2(0.06, 0), Vector2(0.2, 0), Vector2(0.2, 1), Vector2(0.06, 1)],
		"dir": Vector2(0, 1), "damage": 28.0, "impact": 1.6, "push": 20000.0, "windup": 1.8, "pose": "overhead_r", "trait": "burning", "pan": Vector2(0.72, 0),
		"act": "one fist raised high, molten rock pouring out of it, the pour walked steadily from left to right"},
	"eruption": {"zone": [Vector2(0, 0.7), Vector2(1, 0.7), Vector2(1, 1), Vector2(0, 1)],
		"dir": Vector2(0, -1), "damage": 32.0, "impact": 2.2, "push": 60000.0, "windup": 1.6, "pose": "slam", "trait": "burning", "cleave": 0.2,
		"act": "both fists pounded into the ground: the lava bursts up from under the floor"},
	"slag_fist": {"zone": [Vector2(0.34, 0.2), Vector2(0.66, 0.2), Vector2(0.66, 1), Vector2(0.34, 1)],
		"dir": Vector2(0, 1), "damage": 38.0, "impact": 2.6, "push": 45000.0, "windup": 1.4, "pose": "slam", "trait": "burning", "cleave": 0.3,
		"act": "both fists locked together overhead and brought down like a hammer"},
	"slag_tide": {"zone": [Vector2(0, 0.82), Vector2(1, 0.82), Vector2(1, 1), Vector2(0, 1)],
		"dir": Vector2(0, -1), "damage": 34.0, "impact": 2.8, "push": 70000.0, "windup": 2.2, "pose": "slam", "trait": "burning", "cleave": 0.5, "pan": Vector2(0, -0.32),
		"act": "both arms dragged up from the floor: a tide of molten slag rising up through the pile"},
	"magma_grip": {"zone": [Vector2(0.4, 0.38), Vector2(0.6, 0.38), Vector2(0.6, 0.62), Vector2(0.4, 0.62)],
		"dir": Vector2.ZERO, "damage": 24.0, "impact": 1.2, "push": 0.0, "windup": 1.3, "pose": "grasp", "trait": "burning", "chase": 0.7,
		"act": "one glowing hand reaches out after the player's hand, following it, then closes"},
	# --- the Castellan's shield: a bash that scatters your pile, then the sword comes down ---
	"shield_bash": {"zone": [Vector2(0.2, 0.3), Vector2(0.8, 0.3), Vector2(0.8, 0.78), Vector2(0.2, 0.78)],
		"dir": Vector2(1, 0.2), "damage": 20.0, "impact": 0.8, "push": 60000.0, "windup": 1.2, "pose": "bash",
		"next": "overhead_r", "next_windup": 0.85, "cleave": 0.3},
	"tower_slam": {"zone": [Vector2(0.15, 0.55), Vector2(0.85, 0.55), Vector2(0.85, 1), Vector2(0.15, 1)],
		"dir": Vector2(0, 1), "damage": 40.0, "impact": 2.0, "push": 50000.0, "windup": 1.6, "pose": "slam", "cleave": 0.35},
}

# Every enemy is a character with a check built into it. Fields beyond the basics:
#   weapon        what the rig holds (sword, maul, rapier, rusted, flail, none, shield)
#   idle          how it carries itself between swings (steady, heavy, bounce, shamble, drift, guard)
#   flinch        how long a parry leaves it reeling, relative to normal
#   enrage        {"below": hp fraction, "speed": multiplier}: it speeds up when hurt
#   riposte       attack it answers a clean block with
#   bash_after    clean blocks in a row before it bashes your pile apart
#   armor_breaks  hp fractions lost at which its pauldrons come off
#   weapon_mult   how much plain weapon hits do to it; elemental_mult for charged/hot/cold ones
#   punch_mult    how much punches do
#   cold_stagger  cold weapon hits stagger it outright
#   guard         off-hand shield: the torso is covered until it's reeling or broken
#   feint         {chance, at, windup}: a wind-up that breaks off at `at` into another attack
#   combos        {attack: follow-up}: with combo_chance, that attack runs straight into the
#                 follow-up (combo_windup), its field shown faintly ahead
# Attack fields beyond the basics: pan (the field slides while it winds up), turn (it swings
# round its middle), chase (it follows the hand until this much of the wind-up, along
# chase_axis), next (a follow-up, shown ahead), act (what the performer does, for recording)
#   fireproof     can't be set alight
#   power scales how hard every attack hits the hand (gear wear is unaffected), so the
#   first stages teach instead of ending a run over one missed block
const ENEMIES := {
	# A conscript with a sword. Scared, slow, and he flinches badly: block him once and he's open.
	"Footman": {"name": "Footman", "stagger": 22.0, "hp": 90.0, "poise": 9.0, "armor": 0.4, "speed": 0.8, "power": 0.5, "reward": 12,
		"attacks": ["cut_ml", "cut_mr", "cut_tc", "slash_high_r"], "rest": [1.0, 1.7], "color": Color(0.32, 0.4, 0.6),  # (no fast high corner cuts: he's the first foe)
		"weapon": "sword", "idle": "steady", "flinch": 1.8,
		"bio": "A pressed man with a borrowed sword. Block him clean and he loses his nerve."},
	# --- secret guardians: each found only in its secret place (secrets.gd) ---------
	"Coin Golem": {"name": "Coin Golem", "stagger": 120.0, "hp": 300.0, "poise": 40.0, "armor": 0.8, "speed": 0.85, "power": 0.6, "reward": 120,
		"attacks": ["ground_pound", "slam", "sweep", "coin_toss"], "rest": [1.1, 1.8], "color": Color(0.95, 0.72, 0.22),
		"weapon": "none", "idle": "heavy", "greedy": true, "secret": true,
		"bio": "A hoard that stood up. Its blows swallow any coin in their path and it grows back on them. Spend your gold before it does."},
	"Housecat": {"name": "Housecat", "stagger": 50.0, "hp": 240.0, "poise": 15.0, "armor": 0.0, "speed": 1.3, "power": 0.9, "reward": 80,
		"attacks": ["swipe_l", "swipe_r", "pounce", "tail_lash"], "rest": [0.8, 1.5], "color": Color(0.85, 0.5, 0.2),
		"weapon": "none", "idle": "bounce", "distractible": true, "revive": 0.3, "secret": true,
		"bio": "Enormous, bored, and quick. Fling a gold coin past it mid-swing and it forgets you to chase it. It has a life to spare."},
	"The Astronomer": {"name": "The Astronomer", "stagger": 50.0, "hp": 240.0, "poise": 16.0, "armor": 0.3, "speed": 1.15, "power": 1.0, "reward": 90,
		"attacks": ["comet", "orbit", "unmoor", "spark"], "rest": [1.0, 1.6], "color": Color(0.25, 0.3, 0.7),
		"weapon": "staff", "idle": "steady", "secret": true,
		"bio": "Keeps the orrery turning. Brings a comet down on your hand, and lets go of the weight of everything you own."},
	# The hardest thing in the game, on purpose: only a hoard heavy enough to break the floor
	# ever reaches it, so it's built to melt a hoard. Every blow cleaves and burns, the floor
	# itself rises as slag, it shrugs off staggers, it speeds up as it cracks open, and it
	# hides its blows behind feints.
	"The Smelter": {"name": "The Smelter", "stagger": 320.0, "hp": 1100.0, "poise": 90.0, "armor": 1.0, "speed": 1.05, "power": 1.35, "reward": 260,
		"attacks": ["pour", "eruption", "slag_fist", "magma_grip", "slag_tide", "slag_fist"], "rest": [0.7, 1.2], "color": Color(0.1, 0.08, 0.08),
		"weapon": "none", "idle": "heavy", "fireproof": true, "cold_stagger": true, "elemental_mult": 0.8, "weapon_mult": 0.75, "punch_mult": 0.2, "secret": true,
		"enrage": {"below": 0.4, "speed": 1.35}, "stagger_time": 0.5, "flinch": 0.5,
		"feint": {"chance": 0.25, "at": 0.55, "windup": 0.6},
		"combos": {"eruption": "slag_fist", "pour": "magma_grip", "slag_tide": "eruption"}, "combo_chance": 0.55, "combo_windup": 0.6,
		"bio": "Cooled black rock over a heart that never stops burning, and the hardest thing below the earth. Every blow burns and cuts through what blocks it, slag rises up through your pile, and it only gets faster as it cracks open. Cold still checks it."},
	"Errata": {"name": "Errata", "stagger": 60.0, "hp": 200.0, "poise": 18.0, "armor": 0.3, "speed": 1.1, "power": 1.0, "reward": 90,
		"attacks": ["slash_high_r", "slash_low", "thrust"], "rest": [1.0, 1.6], "color": Color(0.05, 0.05, 0.08),
		"weapon": "sword", "idle": "steady", "ink": true, "model": "footman", "secret": true,
		"bio": "A misprint of the last thing you fought, in wet ink: its moves, its body, a little faster and a little wrong."},
	# A woodcutter called up with the levy. Slow, wide chops called out from far off, no thrusts.
	"Woodcutter": {"name": "Woodcutter", "stagger": 35.0, "hp": 150.0, "poise": 12.0, "armor": 0.3, "speed": 0.85, "power": 0.55, "reward": 15,
		"attacks": ["chop_l", "chop_r", "hew", "fell"], "rest": [1.2, 2.0], "color": Color(0.35, 0.42, 0.25),
		"weapon": "axe", "idle": "heavy", "flinch": 1.5,
		"bio": "Called up with the levy and handed nothing new. He swings like he's felling a tree: slow, wide, and from a long way back."},
	# A trained knight: overheads and thrusts. Hits high. Whatever's on the floor won't help you.
	"Knight": {"name": "Knight", "stagger": 75.0, "hp": 170.0, "poise": 20.0, "armor": 0.9, "speed": 1.15, "power": 0.65, "reward": 18,
		"attacks": ["overhead_l", "overhead_r", "thrust", "slash_high_r"], "rest": [0.9, 1.6], "color": Color(0.55, 0.57, 0.62),
		"weapon": "sword", "idle": "steady",
		"combos": {"overhead_l": "thrust", "overhead_r": "thrust", "slash_high_r": "overhead_l"}, "combo_chance": 0.3, "combo_windup": 0.8,
		"bio": "Drilled since he could walk. Everything comes from above, and his overheads run straight into a thrust: watch for the second blow."},
	# A giant with a maul. Every swing is wide and low and wrecks gear. Gets faster as it gets angry.
	"Brute": {"name": "Brute", "stagger": 125.0, "hp": 160.0, "poise": 42.0, "armor": 0.45, "speed": 0.85, "power": 0.45, "reward": 24,
		"attacks": ["ground_pound", "maul_low_l", "maul_low_r", "slam", "sweep"], "rest": [1.4, 2.3], "color": Color(0.4, 0.3, 0.25),
		"weapon": "maul", "idle": "heavy", "enrage": {"below": 0.34, "speed": 1.3},
		"bio": "A maul the size of a door. His low swings drag across the floor: follow the head with your shield. He's angrier the more he bleeds."},
	# A fencer: thin, fast lines that slip past a cluttered floor, and a riposte at your hand
	# the moment you block clean. Goes down easily; just hard to land on.
	"Duelist": {"name": "Duelist", "stagger": 24.0, "hp": 130.0, "poise": 9.0, "armor": 0.2, "speed": 1.35, "power": 0.9, "reward": 22,
		"attacks": ["lunge", "flick_high", "cut_tl", "cut_tr", "cut_mr", "jab"], "rest": [0.5, 0.9], "color": Color(0.5, 0.2, 0.3),
		"weapon": "rapier", "idle": "bounce", "riposte": "riposte", "stagger_time": 0.5, "flinch": 0.6,
		"feint": {"chance": 0.35, "at": 0.5, "windup": 0.5},
		"bio": "Light on his feet and bored of you. Half his wind-ups are lies: he breaks off and comes from somewhere else. Answer a clean block of yours with a riposte at your hand."},
	# Rotten armour and a rotten blade: what blocks it rusts, and the rust spreads through your
	# metal. His own plate is barely hanging on, though.
	"Rusted": {"name": "The Rusted", "stagger": 110.0, "hp": 190.0, "poise": 34.0, "armor": 0.5, "speed": 0.9, "power": 0.9, "reward": 24,
		"attacks": ["drag_low", "rake", "spit", "drag_low"], "rest": [1.2, 2.0], "color": Color(0.4, 0.3, 0.18),
		"weapon": "rusted", "idle": "shamble", "armor_breaks": [0.2, 0.45], "corrode_mult": 2.0,
		"bio": "Something that was a knight once. Its blade is eaten through and so is anything that blocks it. Its own plate is a shell."},
	# A zealot with a brazier on a chain. Burning coals heat whatever blocks them: wood and
	# leather catch, metal gets too hot to hold. Frost is the answer; the cold stops it dead.
	"Zealot": {"name": "Pyre Zealot", "stagger": 55.0, "hp": 160.0, "poise": 18.0, "armor": 0.5, "speed": 1.0, "power": 0.9, "reward": 24,
		"attacks": ["flail_arc", "ember_rain", "brand", "flail_arc"], "rest": [1.0, 1.8], "color": Color(0.68, 0.62, 0.55),
		"weapon": "flail", "idle": "steady", "fireproof": true, "cold_stagger": true, "elemental_mult": 1.5,
		"bio": "Swings a brazier on a chain and sings while he does it. Everything that blocks him comes away hot. He hates the cold."},
	# No body, two hands. Its reach is half the screen at a time but its touch is soft; the
	# grasp comes for wherever your hand was. Plain steel passes through it; charge and fire don't.
	"Wraith": {"name": "Wraith", "stagger": 28.0, "hp": 140.0, "poise": 10.0, "armor": 0.0, "speed": 0.95, "power": 0.7, "reward": 26,
		"attacks": ["shroud_l", "shroud_r", "grasp", "grasp"], "rest": [1.0, 1.9], "color": Color(0.25, 0.22, 0.3),
		"weapon": "none", "idle": "drift", "look": "Wraith", "weapon_mult": 0.5, "elemental_mult": 1.6, "punch_mult": 0.0,
		"bio": "There's nothing under the hood. Its hands sweep whole halves of the room and reach for your hand. Steel barely touches it; lightning and fire do."},
	# A pikeman with a halberd: reach. His fields move: a blade walked along the floor, a pike
	# that hunts your hand along its line, a hook hauled down from above.
	"Halberdier": {"name": "Halberdier", "stagger": 70.0, "hp": 170.0, "poise": 18.0, "armor": 0.6, "speed": 1.0, "power": 0.7, "reward": 24,
		"attacks": ["reap", "pike", "hook", "butt", "pike"], "rest": [1.0, 1.7], "color": Color(0.25, 0.35, 0.65),
		"weapon": "halberd", "idle": "steady",
		"bio": "All reach and patience. Nothing he swings stays where it started: walk your shield along with the blade, and get out from in front of the pike."},
	# Two sabres, one in each hand: every cut comes with a second, crossing it. Feints too.
	"Twinblade": {"name": "Twinblade", "stagger": 30.0, "hp": 140.0, "poise": 10.0, "armor": 0.3, "speed": 1.25, "power": 0.85, "reward": 26,
		"attacks": ["x_right", "x_left", "scissor_hi", "flurry_l", "jab"], "rest": [0.7, 1.2], "color": Color(0.5, 0.15, 0.2),
		"weapon": "twin", "idle": "bounce", "flinch": 0.8,
		"feint": {"chance": 0.3, "at": 0.55, "windup": 0.45},
		"bio": "A sabre in each hand and never one cut alone: block the first and the second is already crossing it. Some of what it shows you is a lie."},
	# A mace that hits twice in the same place: the first knocks your gear loose, the second
	# lands where it was. Slow, heavy, honest; brace for the second blow.
	"Bonebreaker": {"name": "Bonebreaker", "stagger": 90.0, "hp": 180.0, "poise": 24.0, "armor": 0.7, "speed": 0.9, "power": 0.6, "reward": 22,
		"attacks": ["crush_l", "crush_r", "mace_arc", "pommel"], "rest": [1.2, 1.9], "color": Color(0.5, 0.18, 0.16),
		"weapon": "mace", "idle": "heavy",
		"bio": "A flanged mace and a habit: he hits the same place twice. The first blow scatters what you put there; have something ready for the second."},
	# --- rare: only a deep run meets them ---------------------------------------------
	# A headsman with an axe taller than you. Two swings, both enormous, both slow, and
	# whatever blocks them is kindling. Only something heavy stops it.
	"Headsman": {"name": "Headsman", "stagger": 300.0, "hp": 280.0, "poise": 80.0, "armor": 0.8, "speed": 0.75, "power": 0.65, "reward": 34,
		"attacks": ["cleave", "low_cleave", "behead"], "rest": [1.6, 2.6], "color": Color(0.25, 0.2, 0.2),
		"weapon": "axe", "idle": "heavy", "flinch": 0.7, "prestige": 2, "tier": 3, "chance": 0.3,
		"bio": "Hooded and patient. Three swings in all, each the end of whatever's underneath, and the level one finds the height of your hand. Nothing light will stop them."},
	# The Lamplighter puts the lights out and fights by its own. Its staff charges whatever
	# blocks it, and charge runs through a metal pile straight to the hand holding it.
	"Lamplighter": {"name": "Lamplighter", "stagger": 28.0, "hp": 150.0, "poise": 9.0, "armor": 0.3, "speed": 1.2, "power": 0.8, "reward": 34,
		"attacks": ["spark", "arc_lash", "lantern_swing", "cut_tl", "cut_mr", "spark"], "rest": [0.6, 1.1], "color": Color(0.2, 0.3, 0.45),
		"weapon": "staff", "idle": "bounce", "dark": true, "shockproof": true, "elemental_mult": 0.6, "prestige": 3, "tier": 3, "chance": 0.3,
		"bio": "It snuffs every light but its own. Its staff leaves lightning in whatever blocks it, and a pile of metal carries that lightning to your hand."},
	# --- bosses ---------------------------------------------------------------------
	# The Castellan: a knight with a tower shield of his own. His torso is covered until you
	# rattle him, and after three clean blocks he bashes your pile apart and brings the sword down.
	"Castellan": {"name": "Castellan", "stagger": 220.0, "hp": 480.0, "poise": 55.0, "armor": 1.0, "speed": 1.0, "power": 0.6, "reward": 50,
		"attacks": ["tower_slam", "overhead_l", "overhead_r", "tower_slam", "shield_bash"], "rest": [1.0, 1.7], "color": Color(0.35, 0.4, 0.55),
		"weapon": "shield", "idle": "guard", "guard": true, "bash_after": 3, "boss": true,
		"combos": {"tower_slam": "overhead_r", "overhead_l": "thrust"}, "combo_chance": 0.4, "combo_windup": 0.7,
		"bio": "Keeper of the gate. He carries a wall of his own and keeps it between you and him; knock him reeling to get past it. He answers a tidy defence by scattering it."},
	# The Sexton: keeper of the bell and the graveyard. A great bronze bell on a pole and a grave
	# spade: the bell tolls twice on one spot (the second ring scatters your pile), the spade
	# scoops along the floor and buries what's under your hand.
	"Sexton": {"name": "The Sexton", "stagger": 160.0, "hp": 460.0, "poise": 40.0, "armor": 0.5, "speed": 1.0, "power": 0.75, "reward": 60,
		"attacks": ["toll", "peal", "dig", "bury", "knell"], "rest": [1.0, 1.7], "color": Color(0.42, 0.48, 0.58),
		"weapon": "bell", "idle": "heavy", "boss": true, "model": "sexton",
		"combos": {"dig": "bury", "peal": "toll"}, "combo_chance": 0.35, "combo_windup": 0.7,
		"feint": {"chance": 0.2, "at": 0.5, "windup": 0.6},
		"bio": "He rings the bell for the dead and digs their beds. Every toll rings twice on the same spot, and the second scatters what you put there; his spade scoops your floor and buries what's under your hand."},
}

# A run is five stages: four fights, then a boss. Each stage draws from a tier; prestige
# pushes every stage a tier deeper, so later runs start where earlier ones ended.
const TIERS := [["Footman"], ["Woodcutter"], ["Brute", "Duelist", "Bonebreaker"], ["Knight", "Rusted", "Zealot", "Wraith", "Halberdier", "Twinblade"]]
const BOSSES := [["Castellan"], ["Castellan", "Sexton"]]
const STAGES := 5
const BOSS_STAGE := 4
# The first run's second and third fights come before most runs have found a good weapon:
# they go down quicker so a plain starting kit can still get through them.
const FIRST_RUN_HP := [1.0, 0.6, 0.7, 1.0, 1.0]  # per stage, boss last

# The guardian of the Hidden Vault: tough, gilded, and worth a fortune.
const WARDEN := {"name": "Vault Warden", "stagger": 70.0, "hp": 200.0, "poise": 26.0, "armor": 1.0, "speed": 1.0,
	"power": 0.9, "reward": 60, "attacks": ["slash_high_r", "slash_high_l", "overhead_l", "overhead_r", "thrust"],
	"rest": [1.0, 1.7], "color": Color(0.85, 0.65, 0.25), "weapon": "sword", "idle": "steady",
	"bio": "Paid to stand in a room full of gold and not touch any of it."}


# Pairs that fight together (past the first boss, on the middle stages, some of the time).
# Each is scaled down a little: two at once is the check.
const DUOS := [["Footman", "Footman"], ["Footman", "Duelist"], ["Knight", "Footman"], ["Duelist", "Duelist"], ["Footman", "Zealot"]]
const DUO_PRESTIGE := 1
const DUO_CHANCE := 0.35


## The enemy for a stage of the run. `prestige` is how many bosses the run has beaten;
## `rng` picks within a tier. Rare enemies take a slot in their tier some of the time.
static func for_round(n: int, prestige: int = 0, rng: RandomNumberGenerator = null) -> Dictionary:
	var stage := n % STAGES
	var id: String
	if stage == BOSS_STAGE:
		var pool: Array = BOSSES[mini(prestige, BOSSES.size() - 1)]
		id = pool[_pick(rng, pool.size())]
	else:
		var tier_i := mini(stage + prestige, TIERS.size() - 1)
		id = ""
		for rare in ENEMIES:
			var e: Dictionary = ENEMIES[rare]
			if e.has("prestige") and prestige >= int(e.prestige) and tier_i >= int(e.tier):
				if (rng.randf() if rng else randf()) < float(e.chance):
					id = rare
					break
		if id == "":
			var tier: Array = TIERS[tier_i]
			id = tier[_pick(rng, tier.size())]
	var d := scaled(id, prestige)
	if prestige == 0:
		d.hp *= FIRST_RUN_HP[stage]
	return d


## Everyone in a stage's fight: usually one, sometimes (deep in, on the middle stages) two.
static func encounter(n: int, prestige: int, rng: RandomNumberGenerator) -> Array:
	var stage := n % STAGES
	if prestige >= DUO_PRESTIGE and stage >= 1 and stage < BOSS_STAGE and rng.randf() < DUO_CHANCE:
		var pair: Array = DUOS[rng.randi() % DUOS.size()]
		var out: Array = []
		for id in pair:
			var d := scaled(id, prestige)
			d.hp *= 0.75
			d.reward = int(d.reward * 0.7)
			d.rest = [float(d.rest[0]) * 1.4, float(d.rest[1]) * 1.4]
			out.append(d)
		return out
	return [for_round(n, prestige, rng)]


static func _pick(rng: RandomNumberGenerator, n: int) -> int:
	return (rng.randi() if rng else randi()) % n


# How much harder each prestige makes every enemy. Each step is a real jump; prestige 3 is
# the wall: foes with six times the health, hitting three and a half times as hard, with
# their wind-ups nearly halved. Only a broken build gets through it. Past the table, the
# curve keeps climbing.
const PRESTIGE_HP := [1.0, 2.0, 3.5, 6.0]
const PRESTIGE_POWER := [1.0, 1.6, 2.4, 3.5]
const PRESTIGE_SPEED := [1.0, 1.2, 1.45, 1.75]
const PRESTIGE_STAGGER := [1.0, 1.4, 1.9, 2.6]  # so a bigger health bar can't just be stun-locked


## An enemy's stats at a given prestige.
static func scaled(id: String, prestige: int) -> Dictionary:
	return scale_def(ENEMIES[id].duplicate(true), prestige)


## Any foe made a prestige deeper (the Vault Warden too).
static func scale_def(d: Dictionary, prestige: int) -> Dictionary:
	d.hp *= _prestige_step(PRESTIGE_HP, prestige, 1.6)
	d.power = float(d.get("power", 1.0)) * _prestige_step(PRESTIGE_POWER, prestige, 1.4)
	d.speed = float(d.get("speed", 1.0)) * _prestige_step(PRESTIGE_SPEED, prestige, 1.1)
	d.stagger = float(d.get("stagger", 40.0)) * _prestige_step(PRESTIGE_STAGGER, prestige, 1.3)
	d.poise = float(d.get("poise", 10.0)) * _prestige_step(PRESTIGE_STAGGER, prestige, 1.3)
	d.reward = int(d.get("reward", 10)) + 8 * prestige
	d.prestige = prestige
	return d


## A prestige's multiplier from a table, growing by `beyond` per step past its end.
static func _prestige_step(table: Array, prestige: int, beyond: float) -> float:
	var last := table.size() - 1
	if prestige <= last:
		return float(table[prestige])
	return float(table[last]) * pow(beyond, prestige - last)
