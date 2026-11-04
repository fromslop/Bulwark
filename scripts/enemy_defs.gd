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
	"maul_low_l": {"zone": [Vector2(0, 0.5), Vector2(0.62, 0.5), Vector2(0.62, 1), Vector2(0, 1)],
		"dir": Vector2(1, 0.1), "damage": 42.0, "impact": 2.2, "push": 45000.0, "windup": 1.6, "pose": "low_left", "cleave": 0.3},
	"maul_low_r": {"zone": [Vector2(0.38, 0.5), Vector2(1, 0.5), Vector2(1, 1), Vector2(0.38, 1)],
		"dir": Vector2(-1, 0.1), "damage": 42.0, "impact": 2.2, "push": 45000.0, "windup": 1.6, "pose": "low", "cleave": 0.3},
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
	"drag_low": {"zone": [Vector2(0, 0.72), Vector2(1, 0.72), Vector2(1, 0.9), Vector2(0, 0.9)],
		"dir": Vector2(1, 0.05), "damage": 24.0, "impact": 1.0, "push": 20000.0, "windup": 1.3, "pose": "low_left", "trait": "corrosive", "cleave": 0.25},
	"rake": {"zone": [Vector2(0, 0.18), Vector2(0.14, 0.1), Vector2(1, 0.78), Vector2(0.86, 0.9)],
		"dir": Vector2(1, 0.75), "damage": 30.0, "impact": 1.4, "push": 28000.0, "windup": 1.4, "pose": "sweep", "trait": "corrosive"},
	"spit": {"zone": [Vector2(0.5, 0.44), Vector2(0.56, 0.5), Vector2(0.5, 0.56), Vector2(0.44, 0.5)],
		"dir": Vector2.ZERO, "damage": 14.0, "impact": 3.0, "push": 3000.0, "windup": 1.0, "pose": "spit", "trait": "corrosive", "track": true},
	# --- the Zealot's brazier-flail: burning coals. Wood and leather catch; metal heats up ---
	"flail_arc": {"zone": [Vector2(0.85, 0.08), Vector2(1, 0.2), Vector2(0.15, 0.92), Vector2(0, 0.8)],
		"dir": Vector2(-1, 0.85), "damage": 32.0, "impact": 1.3, "push": 34000.0, "windup": 1.4, "pose": "sweep", "trait": "burning"},
	"ember_rain": {"zone": [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.45), Vector2(0, 0.45)],
		"dir": Vector2.ZERO, "damage": 16.0, "impact": 0.6, "push": 2000.0, "windup": 1.6, "pose": "overhead_r", "trait": "burning"},
	"brand": {"zone": [Vector2(0.5, 0.43), Vector2(0.54, 0.5), Vector2(0.5, 0.57), Vector2(0.46, 0.5)],
		"dir": Vector2.ZERO, "damage": 30.0, "impact": 2.0, "push": 8000.0, "windup": 0.9, "pose": "thrust", "trait": "burning"},
	# --- the Wraith: huge, soft hits that reach everywhere, and a grasp that comes for the hand ---
	"grasp": {"zone": [Vector2(0.38, 0.38), Vector2(0.62, 0.38), Vector2(0.62, 0.62), Vector2(0.38, 0.62)],
		"dir": Vector2.ZERO, "damage": 22.0, "impact": 0.5, "push": 0.0, "windup": 1.2, "pose": "grasp", "track": true},
	"shroud_l": {"zone": [Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 1), Vector2(0, 1)],
		"dir": Vector2(1, 0), "damage": 20.0, "impact": 0.5, "push": 15000.0, "windup": 1.5, "pose": "high_left"},
	"shroud_r": {"zone": [Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1)],
		"dir": Vector2(-1, 0), "damage": 20.0, "impact": 0.5, "push": 15000.0, "windup": 1.5, "pose": "high_right"},
	# --- the Headsman's axe: slow, enormous, and it goes through gear like kindling ---------
	"cleave": {"zone": [Vector2(0.3, 0), Vector2(0.7, 0), Vector2(0.7, 1), Vector2(0.3, 1)],
		"dir": Vector2(0, 1), "damage": 50.0, "impact": 3.2, "push": 60000.0, "windup": 2.2, "pose": "slam", "cleave": 0.45},
	"low_cleave": {"zone": [Vector2(0, 0.55), Vector2(1, 0.55), Vector2(1, 0.95), Vector2(0, 0.95)],
		"dir": Vector2(-1, 0.05), "damage": 48.0, "impact": 3.0, "push": 55000.0, "windup": 2.0, "pose": "low", "cleave": 0.45},
	# --- the Lamplighter's staff: lightning. What blocks it is charged, and charge flows through metal ---
	"spark": {"zone": [Vector2(0.5, 0.42), Vector2(0.58, 0.5), Vector2(0.5, 0.58), Vector2(0.42, 0.5)],
		"dir": Vector2.ZERO, "damage": 20.0, "impact": 1.0, "push": 4000.0, "windup": 0.8, "pose": "thrust", "trait": "charged", "track": true},
	"arc_lash": {"zone": [Vector2(0, 0.6), Vector2(0.12, 0.72), Vector2(1, 0.22), Vector2(0.9, 0.1)],
		"dir": Vector2(1, -0.55), "damage": 26.0, "impact": 0.9, "push": 20000.0, "windup": 1.1, "pose": "sweep", "trait": "charged"},
	"lantern_swing": {"zone": [Vector2(0, 0.66), Vector2(1, 0.66), Vector2(1, 0.84), Vector2(0, 0.84)],
		"dir": Vector2(-1, 0.1), "damage": 24.0, "impact": 1.1, "push": 40000.0, "windup": 1.2, "pose": "low", "trait": "charged"},
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
#   fireproof     can't be set alight
#   power scales how hard every attack hits the hand (gear wear is unaffected), so the
#   first stages teach instead of ending a run over one missed block
const ENEMIES := {
	# A conscript with a sword. Scared, slow, and he flinches badly: block him once and he's open.
	"Footman": {"name": "Footman", "stagger": 22.0, "hp": 90.0, "poise": 9.0, "armor": 0.4, "speed": 0.8, "power": 0.5, "reward": 12,
		"attacks": ["cut_ml", "cut_mr", "cut_tc", "slash_high_r"], "rest": [1.0, 1.7], "color": Color(0.45, 0.4, 0.35),  # (no fast high corner cuts: he's the first foe)
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
		"bio": "Drilled since he could walk. Everything comes from above: a pile on the floor is no shield."},
	# A giant with a maul. Every swing is wide and low and wrecks gear. Gets faster as it gets angry.
	"Brute": {"name": "Brute", "stagger": 230.0, "hp": 220.0, "poise": 65.0, "armor": 0.6, "speed": 0.85, "power": 0.6, "reward": 24,
		"attacks": ["ground_pound", "maul_low_l", "maul_low_r", "slam", "sweep"], "rest": [1.3, 2.2], "color": Color(0.4, 0.3, 0.25),
		"weapon": "maul", "idle": "heavy", "enrage": {"below": 0.34, "speed": 1.3},
		"bio": "A maul the size of a door. He hits the whole floor at once, and he's angrier the more he bleeds."},
	# A fencer: thin, fast lines that slip past a cluttered floor, and a riposte at your hand
	# the moment you block clean. Goes down easily; just hard to land on.
	"Duelist": {"name": "Duelist", "stagger": 20.0, "hp": 120.0, "poise": 8.0, "armor": 0.2, "speed": 1.35, "power": 0.75, "reward": 22,
		"attacks": ["lunge", "flick_high", "cut_tl", "cut_tr", "cut_mr", "jab"], "rest": [0.5, 0.9], "color": Color(0.5, 0.2, 0.3),
		"weapon": "rapier", "idle": "bounce", "riposte": "riposte", "stagger_time": 0.5, "flinch": 0.6,
		"bio": "Light on his feet and bored of you. His point finds the gaps in a pile, and he answers every clean block with a riposte at your hand."},
	# Rotten armour and a rotten blade: what blocks it rusts, and the rust spreads through your
	# metal. His own plate is barely hanging on, though.
	"Rusted": {"name": "The Rusted", "stagger": 110.0, "hp": 190.0, "poise": 34.0, "armor": 0.5, "speed": 0.9, "power": 0.9, "reward": 24,
		"attacks": ["drag_low", "rake", "spit", "drag_low"], "rest": [1.2, 2.0], "color": Color(0.4, 0.3, 0.18),
		"weapon": "rusted", "idle": "shamble", "armor_breaks": [0.2, 0.45], "corrode_mult": 2.0,
		"bio": "Something that was a knight once. Its blade is eaten through and so is anything that blocks it. Its own plate is a shell."},
	# A zealot with a brazier on a chain. Burning coals heat whatever blocks them: wood and
	# leather catch, metal gets too hot to hold. Frost is the answer; the cold stops it dead.
	"Zealot": {"name": "Pyre Zealot", "stagger": 55.0, "hp": 160.0, "poise": 18.0, "armor": 0.5, "speed": 1.0, "power": 0.9, "reward": 24,
		"attacks": ["flail_arc", "ember_rain", "brand", "flail_arc"], "rest": [1.0, 1.8], "color": Color(0.6, 0.25, 0.1),
		"weapon": "flail", "idle": "steady", "fireproof": true, "cold_stagger": true, "elemental_mult": 1.5,
		"bio": "Swings a brazier on a chain and sings while he does it. Everything that blocks him comes away hot. He hates the cold."},
	# No body, two hands. Its reach is half the screen at a time but its touch is soft; the
	# grasp comes for wherever your hand was. Plain steel passes through it; charge and fire don't.
	"Wraith": {"name": "Wraith", "stagger": 28.0, "hp": 140.0, "poise": 10.0, "armor": 0.0, "speed": 0.95, "power": 0.7, "reward": 26,
		"attacks": ["shroud_l", "shroud_r", "grasp", "grasp"], "rest": [1.0, 1.9], "color": Color(0.25, 0.22, 0.3),
		"weapon": "none", "idle": "drift", "look": "Wraith", "weapon_mult": 0.5, "elemental_mult": 1.6, "punch_mult": 0.0,
		"bio": "There's nothing under the hood. Its hands sweep whole halves of the room and reach for your hand. Steel barely touches it; lightning and fire do."},
	# --- rare: only a deep run meets them ---------------------------------------------
	# A headsman with an axe taller than you. Two swings, both enormous, both slow, and
	# whatever blocks them is kindling. Only something heavy stops it.
	"Headsman": {"name": "Headsman", "stagger": 300.0, "hp": 280.0, "poise": 80.0, "armor": 0.8, "speed": 0.75, "power": 0.65, "reward": 34,
		"attacks": ["cleave", "low_cleave"], "rest": [1.6, 2.6], "color": Color(0.25, 0.2, 0.2),
		"weapon": "axe", "idle": "heavy", "flinch": 0.7, "prestige": 2, "tier": 3, "chance": 0.3,
		"bio": "Hooded and patient. Two swings in all, each of them the end of whatever's underneath. Nothing light will stop them."},
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
		"bio": "Keeper of the gate. He carries a wall of his own and keeps it between you and him; knock him reeling to get past it. He answers a tidy defence by scattering it."},
	# The Hollow King: a wraith wearing a crown and a guard it doesn't need. Everything the
	# Wraith does, and a sword to go with it.
	"Hollow King": {"name": "Hollow King", "stagger": 70.0, "hp": 450.0, "poise": 20.0, "armor": 0.3, "speed": 1.05, "power": 0.8, "reward": 60,
		"attacks": ["shroud_l", "shroud_r", "grasp", "overhead_l", "overhead_r", "sweep"], "rest": [0.9, 1.6], "color": Color(0.3, 0.25, 0.4),
		"weapon": "sword", "idle": "drift", "look": "Wraith", "weapon_mult": 0.6, "elemental_mult": 1.6, "punch_mult": 0.2, "boss": true,
		"riposte": "grasp",
		"bio": "A crown with no head under it. It has the Wraith's reach and a sword besides, and it reaches for you every time you block it."},
}

# A run is five stages: four fights, then a boss. Each stage draws from a tier; prestige
# pushes every stage a tier deeper, so later runs start where earlier ones ended.
const TIERS := [["Footman"], ["Woodcutter"], ["Brute", "Duelist"], ["Knight", "Rusted", "Zealot", "Wraith"]]
const BOSSES := [["Castellan"], ["Castellan", "Hollow King"]]
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
	var d: Dictionary = ENEMIES[id].duplicate(true)
	d.hp *= _prestige_step(PRESTIGE_HP, prestige, 1.6)
	d.power *= _prestige_step(PRESTIGE_POWER, prestige, 1.4)
	d.speed *= _prestige_step(PRESTIGE_SPEED, prestige, 1.1)
	d.stagger = float(d.get("stagger", 40.0)) * _prestige_step(PRESTIGE_STAGGER, prestige, 1.3)
	d.poise *= _prestige_step(PRESTIGE_STAGGER, prestige, 1.3)
	d.reward += 8 * prestige
	d.prestige = prestige
	return d


## A prestige's multiplier from a table, growing by `beyond` per step past its end.
static func _prestige_step(table: Array, prestige: int, beyond: float) -> float:
	var last := table.size() - 1
	if prestige <= last:
		return float(table[prestige])
	return float(table[last]) * pow(beyond, prestige - last)
