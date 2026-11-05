class_name Secrets
extends RefCounted
## The secret places, how to get into each, and the smaller secrets. Each secret place is
## its own world (none of them is a dungeon room), reached by a chain of odd things done
## with the game's own systems, and guarded by something found nowhere else. Once a chain
## is finished the next ordinary fight is there (never a boss's). The Secret Journal at
## home lists them: a riddle for the ones not yet found, the plain chain once they have been.

const STAGES := {
	"Gilded Gullet": {"foe": "Coin Golem",
		"hint": "Feed the chute what it shouldn't eat. Let the gong taste what it coughs up.",
		"how": "Feed 40 gold down the shop's chute in one visit: it coughs up a Gilded Tooth. Touch the tooth to the gong.",
		"blurb": "Down the gong's throat. Walls of stacked coin, gold teeth, gold rain, and something that eats it."},
	"Giant's Table": {"foe": "Housecat",
		"hint": "Small enough to fit where a brick once was.",
		"how": "Open a loose brick, then push something shrunk twice with Pixie Dust into the hole.",
		"blurb": "You're the size of a crumb on a kitchen table. The cheese is a mountain. The cat has noticed you."},
	"Clockwork Orrery": {"foe": "The Astronomer",
		"hint": "Two fall; the third waits. Reach it with something that weighs nothing.",
		"how": "Catch two falling stars in one Star Chamber fight; a third hangs still. Touch it with something weightless.",
		"blurb": "Inside the great brass orrery. The planets swing through the room on their arms, and they don't stop for you."},
	"Molten Core": {"foe": "The Smelter",
		"hint": "Hoard until the floor can't take it.",
		"how": "Pile up gear so heavy (about 3000, an absurd hoard) that the shop floor cracks and gives way: you fall through the earth to its molten heart.",
		"blurb": "The bottom of everything. A cavern of black glass over a lake of lava, and the thing that keeps the fire going."},
	"Ink Margin": {"foe": "Errata",
		"hint": "Three reactions in one fight leave a stain. Strike it.",
		"how": "Set off three different element reactions in one fight; punch the ink blot it leaves.",
		"blurb": "In the margins of the codex, where the mistakes go. The floor is wet ink; the foe is a misprint of the last one."},
}

## The smaller secrets: [title, how, hint].
const FINDS := {
	"vault": ["Hidden Lever", "Pull the lever hidden in a wall: the next fight is in the Hidden Vault.", "Some walls have handles."],
	"brick": ["Loose Brick", "Punch a loose brick three times for what's stashed behind it.", "Not every brick is mortared in."],
	"star": ["Falling Star", "Punch a falling star as it crosses the Star Chamber's sky.", "Wish on one, with a fist."],
}
