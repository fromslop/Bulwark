# Hoardsman

A visually-3D, functionally-2D medieval roguelike. A waist-up enemy (head + two hands,
recorded with HeadnHands) attacks regions of the screen; you drag physical pixel-art
gear into those regions to block, and swing weapons at specific body parts.

Mechanics prototype: visuals are placeholders on purpose.

## Controls
- **LMB**: grab and drag (heavy things sag; a hurt hand grips weaker). Things dangle from
  where you took them. **Keep Space held after a swing** and a weapon held by its handle
  comes back up to a **ready position**, blade up from the grip (Q/E turns it to a new
  resting angle, which it then holds; a hurt hand holds it up weaker). Let go of Space and
  it dangles again.
- **Space**: swing a held weapon / brace a held shield / use or put on a held item / punch
  with an empty hand (you can punch on every snare hit in the music, every other beat: the
  cooldown is 0.85 s against the snare's 1 s, and a press up to 0.2 s early is held and lands
  as soon as the fist is ready) /
  open a held menu item at home
- **Q / E**: rotate the held item (turn the codex's pages while it's open)
- **Enter** (at home, holding something): name it
- **Esc**: pause menu (Resume / Settings / Controls / Restart run / Quit); Controls lists every key
- **F11**: fullscreen
- **Settings** (in the pause menu, `scripts/settings.gd`, saved to `user://settings.cfg`):
  fullscreen, VSync, frame rate cap; master, music and effects volume (music and effects
  have their own audio buses) and muting in the background; screen shake strength, damage
  numbers on/off, and whether inspecting with Alt pauses the game.
- **R**: restart (back home; the run is lost)
- **Alt (hold)**: inspect. The hand becomes a magnifying glass; the item under it (or in it)
  gets an inspect card (title, coin price, stat bars, modifier chips, what Space does);
  your stats show in a strip along the top and your rings down the left (hover one for its
  card). Nothing shows otherwise.
- **RMB**: fire every ready ring. **1-5**: fire one finger's ring. Two ring slots to start;
  Ring Fittings add more, up to five (one per finger).
- **Developer keys** (only in the editor and debug builds; off in the builds players get):
- **F1**: developer readout (hidden by default; players never need it)
- **F4**: preview the "dark" stage modifier (only a pool of light around your hand)
- **F9**: cycle the setting
- **F5 / F6 / F7 / F8**: cycle designs for attack telegraphs / hand / items / enemy (Shift goes back; remembered)

## Where damage comes from
A plain weapon hits soft. The big numbers come from what you've built:
- **Infusions:** each element or coating on the weapon (electrified, superheated, frosty,
  poisoned, corrosive) multiplies its hits by 1.35.
- **Rings** (below).
- **Openings your blocks make:** a reeling or broken enemy takes 1.5x.

Weapon hits barely fill the stagger meter (20%; punches 50%, and a punch never hurts your
own hand, armour or not). **Blocking is what breaks an
enemy**, and a shield best of all: a blow a shield takes the brunt of counts double, and a
braced shield turns every block into a parry (which counts double again).

**Damage rings:**
- **Momentum:** after a clean block your next hit within 2 s does x2.5; after a parry, x4.
- **Grudges:** every clean block banks a grudge (a parry, two; up to 5), and your next hit
  spends them for +60% each.
- **Executioner:** weapon hits on a reeling or broken foe do triple.
- **Wrath (RMB):** x2.5 on every hit for 4 s.
- **Storm (RMB):** the weapon in your hand is electrified for 6 s.
- **Untouched:** +80% above 90% hand health.
- **Miser:** +3% per coin held, up to +100%.

They stack. A braced shield parry, then a grudge-and-momentum hit with Wrath up on a broken
enemy with an infused blade, is where the absurd numbers live.

**The strange rings** bend the rules (RMB ones fire on right mouse or their finger's number):

| Ring | What it does |
|---|---|
| Thorns | whatever hurts your hand takes double back |
| Glass Cannon | weapon hits x2, and your hand takes x2 |
| Leech | weapon hits heal your hand a tenth of their damage |
| Frenzy | each hit within 2.5 s of the last does +25% more (up to +200%); getting hurt breaks it |
| Midas | coins in your pile soak blows to the hand, 3 damage a coin |
| Phoenix | once, a killing blow leaves the hand at half health instead (the ring burns away) |
| Martyr | damage the hand takes fills the enemy's stagger meter x3 |
| Pacifist | you can't swing weapons; clean blocks hit back 1.5x what they stopped, parries 3x |
| Static | every parry electrifies every weapon you own for 4 s |
| Inferno | every parry sets the enemy alight |
| Winter | every clean block slows the enemy to half speed for 2 s |
| Magpie | kills drop double coins; shop prices +30% |
| Echoes (RMB) | the last blow you blocked strikes the enemy instead, x2.5 |
| Juggler (RMB) | your whole pile is flung into the air |
| the Well (RMB) | for 3 s your pile is dragged toward your hand |
| Reversal (RMB) | for 3 s your pile falls up |
| Alchemist (RMB) | the item under your hand goes up a metal (wood, bone, stone, leather -> copper -> iron -> steel -> gold) |
| Gambler (RMB) | coin flip: your next hit x6, or your hand takes 12 |

**Blood: healing, and pain that pays.** Getting low is a resource. The rings that answer
pain (Desperation, Thorns, the Martyr, Scars) answer it whether it came from the enemy, a
red-hot blade grabbed by the steel on purpose, or your own blood. **Self-inflicted damage
never takes the last point of the hand** (`Hand.wound()`): it can bring you to the brink,
not over it, and it can't burn a Phoenix Ring. It doesn't drop what you're holding, and the
Midas Ring won't spend coins on it.

| Ring | What it does |
|---|---|
| Second Wind | once a fight, when the hand drops below a quarter, it heals 35 |
| Resolve | every parry heals 6, every clean block 2 |
| Scars | +1.5% weapon damage per point the hand has lost this fight, to anything (up to +150%) |
| Bloodletting (RMB) | cut your own hand for 10; your next hit does x3 |

Gear: the **Field Dressing** (a better bandage: the moment the hand drops below 30% in a
fight it flies to it from anywhere in the pile and heals 45; Space binds it sooner), the
**Apothecary's Mortar** (utility: heals the hand 15 after each fight), and the **Hair Shirt**
(utility: in a fight it chafes a point every 2 s, and weapon hits do +40%). The plain
modifier **soothing** heals the hand 2 a second while it's held in a fight.

## Inspecting
Hold **Alt** and the game **freezes**; the hand becomes a magnifying glass. Point it at:
- **An item** for its card.
- **A worn ring** (left side) for what it does.
- **An entry in the stat strip** along the top (HAND, GRIP, SWING, STEADY, HASTE, SKIN,
  rings, coins) for what it means.
- **An enemy** for its card: name, description, health, stagger, damage, speed, poise and
  armour as bars, what state it's in right now (reeling, broken, burning, poisoned,
  corroded), and its quirks in plain words (cleaves, hard to stagger, enrages, ripostes,
  fireproof...).

Let go and the game carries on. It never fights the pause menu.

## The hand
You are the hand. By default it's a chunky plate **gauntlet** with articulated fingers, a
riveted knuckle plate and a leather cuff, and it acts like a character: it points at
anything it could pick up, grips what it holds, balls into a fist to punch, leans into the
way it's moving, recoils when hurt and gives a thumbs-up after a parry. Hits dent it, crack
it, and eventually knock plates off so the bandaged hand shows through. Upgrades show on it
(knuckle wrap, wristband, charm, an iron bar for Iron Tonic, a green stain for Troll Marrow)
and so do the rings, one per finger, gems lighting back up as they recharge. F6 (or the
mirror at home) tries the other designs: Pixel Hand, Bone, Shadow Puppet.

## Home and the run
The game opens at **home**: a timber homestead with a hearth, a window on the night, a weapon
rack (four pegs, left), two shelves (six spots, right), and a gong by the door. Let go of a
weapon near a peg and it hangs itself there; anything goes on a shelf. Whatever is in the
room is remembered between sessions, where it sits, how worn it is, and what you named it.

Along the top beam hang the **collections**, one object each. Point at one with an empty
hand (a little plate names it) and press **Space** to open it, no need to take it down (or
hold it and press Space). Each is its own book (`scripts/codex.gd`), made for what it holds,
with a list on the left page and a picture window on the right showing whatever you click,
live. Click to pick, mouse wheel or the arrow keys to move, Q / E or the book spines along the
top for another book, Space, Esc or right-click to close. Its inspect card counts how many
you've found; the spines do too.

| Object | What's in it, and how it's laid out |
|---|---|
| Armoury Ledger | Every piece of gear, rings and hand upgrades too: a ruled ledger with bookmarks for each kind (weapons, shields, utility, kits and potions, crates and junk, rings, hand) over a scrolling grid. Found pieces are drawn, the rest are dark silhouettes. The facing page shows the real item, live (its modifiers moving), in each metal it comes in (click one), with bars for damage, swing speed, recovery, how well it blocks and how tough it is, its price, and what it does. |
| Rune Tablet | Every modifier and every element reaction, on a slate with two faces (tabs at the top turn it over). **Runes:** every modifier, the five elemental ones first (superheated fire, frosty frost, electrified storm, corrosive rot, poisoned venom), then common, then rare in gold; the facing side shows the rune on a real piece of gear, moving the way it does in a fight, with what it does, its price and what it never comes with, and for an elemental rune its four reactions (click one). **The element circle:** the five elemental runes round a pentagon with a groove between every pair, one per reaction, lit in both colours once you've set it off (faint and dashed till then), and every reaction named on a chip below. A reaction's page shows the two runes side by side, live, what it does, how to set it off (the mark, then the strike) and where each element comes from. |
| Bestiary | Every foe, by where you meet it: the way down stage by stage, further in, the bosses, the guardians of secret places, the vault. The facing page has a live portrait in the kind of place you meet it, bars for health, armour, speed, strength and poise, its bounty, and **every attack**: a little map of where it lands on the screen, its damage and wind-up, whether it cleaves or aims at your hand. Click one (the first plays on its own) and the window, which is the fight's own camera at the screen's shape, plays it over and over as it would come at you: the real telegraph filling over its real wind-up, its lane arrows (how many is on each row), a wind-up bar under the window, then the swing and the lanes flashing. |
| Wall Map | The way down drawn as a map: home, stages 1-2, 3-4, the deep, the vault off a dashed road, the secret places in the corners (a question mark until found). Click a place for a window onto it, what's there to use (the props, from `Props.LAYOUT`) and who you meet there. |

`tests/codex_shots.gd` (windowed) opens each book (both faces of the tablet) with nearly
everything found and saves `shots/codex_*.png`.

Also in the room (`scripts/props.gd`, the "Homestead" props): the **Hand Mirror** (Space:
try another gauntlet); a **Training Dummy** (swing at it: it shows what that hit would do,
rings and infusions included, and keeps your best); the **Trophy Board** (a cup per
prestige reached, a skull per boss felled; Alt over it for the lifetime tallies: runs,
deaths, foes felled, bosses, best hit); **the cat** asleep on the window sill (rest your
empty hand on it; punch it and it jumps); and the **hearth**, which melts junk down (leave
scraps, pauldrons, skulls or rocks in the fire: every 10 scrap value melted, saved across
sessions, pops out a **Coin Purse** to take on a run; Alt over the hearth shows the tally).
A small wooden **placard** under the Trophy Board reads HOARDSMAN and the build's version
(`application/config/version` in `project.godot`: bump it for each build you hand out).
Outside it's
night: crickets, and the hearth crackling. **Punch the gong** to start a run. If you're
holding something when you ring it, it comes with you.

A run is **five stages**: four fights and a **boss**. After the boss, the shop grows a
**door**. Punch the door holding one thing and you go home with it, for keeps. Or ring the
gong instead and the run **prestiges**: enemies tougher and faster, every stage a tier
deeper, rarer gear in the shop, and content that only exists past a prestige (a second boss,
rare enemies, rare places, prestige legendaries). Dying sends you home empty-handed.

Each prestige is a big jump (`EnemyDefs.PRESTIGE_*`):

| prestige | health | damage | speed | stagger needed |
|---|---|---|---|---|
| 0 | x1 | x1 | x1 | x1 |
| 1 | x2 | x1.6 | x1.2 | x1.4 |
| 2 | x3.5 | x2.4 | x1.45 | x1.9 |
| 3 | x6 | x3.5 | x1.75 | x2.6 |

Prestige 3 is the wall: only a broken build gets past it. Beyond 3 it keeps climbing.

**Layout rule:** everything you're meant to interact with, every secret and anything
worth looking at goes in the **top half** of the screen. On a long run the bottom half is
buried under the pile.
The codex records the deepest run.

Kept gear can be **named** (Enter while holding it at home) and every weapon keeps a count
of the **bosses it has slain**; the inspect card shows both. A **Homeward Brew** passes
through your gear: hold it right over something and press Space (or let it break) and the
nearest whole thing goes straight home mid-run.

## No HUD
Everything the player needs is an object in the play field or shows on a body. The one
exception is **damage numbers**: a red number rises off the hand for whatever got through to
it, and a grey one off every item that blocked, for how much of the blow it took on itself
(gold when it was a parry).
- **Money** is gold coins (small = 1, fat = 5, gold bar = 25) lying in your pile. A kill
  spills the enemy's purse onto the screen. A big hoard fuses on its own: past 30 loose
  coins in the bottom half, five small ones become one bigger one (same value, far fewer
  bodies). Coins are never cleared by the body cap.
- **Your health** is the hand: dents, then cracks, then plates come away and the bandaged,
  bleeding hand shows through. It flinches red when hit.
- **The enemy's health** shows as it darkens, hunches and breathes harder. Its pauldrons
  break off at 2/3 and 1/3 HP and fall into your play field as iron you can use.
- **Weapon cooldown**: a weapon goes grey while recovering and glints when it's ready. A
  swing leaves a smear of the blade behind it and the blade flashes when it lands.
- **Modifiers** each have a look: spikes, rivets, sticky drips, corrosive bubbles, a
  volatile rune, magnetic pulses, rust flecks, outlines for heavy and bouncy, a pale shimmer for weightless.
- **Shop**: items sit on shelves, with the price shown as coin pips on the shelf's front
  edge (lit for as much as your coins cover). Pick an item up to buy it. **Punch the gong**
  to leave; after a boss, **punch the door** holding something to go home.
- **Attack telegraphs** are tinted by what the weapon does: red steel, green rot, orange
  fire, blue lightning.
- **Losing**: the hand goes limp and falls, and you wake up at home.

## The shop
Seven shelves. Four hold **gear**: weapons, shields, crates, utilities and consumables mixed
together; the first stocking of every visit puts a consumable on the first shelf (rerolls
don't). Potions are a novelty: a fraction of the weight of other gear, never more than one
on the shelves at once. Weapons and shields roll a little more often than the rest
(`ItemDefs.KIND_WEIGHT`): about three shops in four have a weapon, and a third to two in
five a shield. The fifth shelf (green cloth) is the **stat shelf**: always a hand
upgrade or a stat draught (Oxblood Draught +15 HP, Iron Tonic +12% grip, Quicksilver Drop
weapons recover 10% faster, Troll Marrow hits that get through hurt 10% less; they stack).
The last two (gold cloth) hold **rings**, always two different ones you don't wear.

**The gong's face shows what's next.** The next fight is decided when the shop opens
(`Main._plan_fight`), and the gong's polished face (`scripts/scrying.gd`,
`shaders/gong_face.gdshader`) shows it: the actual next place and the foe waiting in it,
live and idling, mirrored and bulged like a convex mirror, rippling, graded through that
place's own colours and washed in bronze. From across the shop it's just a shifting tint in
the metal; it clears as your hand comes close. A boss beyond makes the gong tremble; a secret
place gives the face a slow gold sweep. Nothing is written: Alt over the gong only says to
look closely. (A secret opened while you're in the shop still takes over.)

**The fight bonus.** A fight's coin reward goes up the faster it's won and the less of your
hand it cost (`Main.fight_bonus`): won in half its par time (20 s, plus 0.08 s per point of
the foes' health) pays +50%, falling to nothing at 1.5x par; losing 5% of the hand or less
pays +60%, falling to nothing at half. The extra spills out when the fight ends, named:
SWIFT, and FLAWLESS / UNSCATHED / GUARDED.

## Glue and fused gear
Glue goes on as a **patch**: the Glue Pot dabs a few pixels where it touches (or under the
hand), each drop of Pitch glues the pixel it lands on, and a *sticky* item from the shop has
one small patch on an edge. Only the glued pixels grab: press the patch against something,
one of the two in your hand, and they **fuse**. The patch is used up.

Fused things are **one item** (`Item.fuse` in `item.gd`): the other piece comes across
**whole**, turned to the nearest quarter turn and moved as one block onto the held one's grid
where it lies (sliding a few pixels clear if they overlap), so neither piece loses a pixel,
warps or wears: gluing costs nothing but the glue, and pressing two things together on wet
glue isn't a knock. They're bridged by a seam of **glue** cells (amber; tough, and if
it's chewed through the parts come apart). One body, so nothing jitters at a joint, and
blocking, breakage and the save all treat it like any other piece. Each pixel remembers the
piece it came from:
- **It blocks as what it was.** A buckler glued to a sword blocks like a buckler where the
  buckler is (0.98 on steel) and like a blade where the blade is (0.73), and a blow it
  takes the brunt of rattles the attacker like a shield's.
- **Space does what the part you're holding does.** Held by the sword, it swings, with the
  longsword's own speed, recovery and damage; held by the buckler, it braces. Either way
  every part keeps blocking: the buckler on a swung sword soaks lanes, and swept through a
  blow it parries with the swing's speed (a shield dragged on its own still can't).
- **It weighs what it weighed**, and glued-on parts count **half** to a swing: a steel
  buckler (now built light, 0.55) on a steel longsword swings about 15% slower than the
  sword alone.
- **Modifiers pool**: glue an electrified dagger to a superheated sword and every hit
  carries both (reactions on every hit).
- **Heft**: junk glued to a weapon (not a shield) makes it hit harder, up to x1.6: a rock on
  a club is a mace.
- **A whetstone glued on** keeps the blade sharp, wearing itself instead.
- **Torn apart**: a part knocked off mostly whole (70%+) falls away as itself again.
- Coins, potions, rings and menu items don't take glue; frozen things (shop stock) don't
  either. Pixie Dust can't shrink a fused thing.

## How modifiers look
Every modifier shows on the thing that has it, small enough not to clutter the pile
(`Item.MOD_LOOKS` for the ones that had nothing else; the older ones draw their own):

| Look | Modifiers |
|---|---|
| edges washed in a colour | tempered (quench blue), Merciless (dark red) |
| an inner outline | Kindred (in its own metal's colour), Riposte Guard (pale blue) |
| stripes | Baton (red) |
| a crosshair at its point | Headhunter |
| a heartbeat along the edges | Avenging (gold), Blood Price (dark red) |
| a slow glow | Rested (blue) |
| specks rising | soothing (pale green), Sanguine (red), Kindling (embers), Stormcaller (grey cloud) |
| drops falling | Reckless (chips), Bloodthirsty (blood) |
| a wisp circling it | Wisp Cannon |
| a crackle at its point | Lightning Rod |
| a sheen running across | Pristine (white), Javelin (pale gold) |
| stars twinkling | Lone Blade (white), Rally (gold) |
| sparks at the edges | Desperate (red), Guardbreaker (orange) |
| an edge cycling through colours | Mimic |
| a halo above it | Hallowed |

Already shown their own way: heavy (dark edge), weightless (shimmer, floats), reinforced
(amber resin), bouncy (pink edge), spiked (spikes), electrified (crackle), superheated (red
hot), frosty (frost), sticky (the glue patch), poisoned (green top edge), oiled (dark),
magnetic (a red pulse), corrosive (bubbles), volatile (a pulsing rune), regenerating (green
sparkles), small / large / huge (size). `tests/mod_looks_shot.gd` (windowed) lays one dagger
per modifier out in a grid, named, in `shots/mod_looks.png`.

## Rare modifiers
Rolled separately from the rest, on weapons and shields (about 1 in 20 early, more on
rarer stock and deeper runs; gold chips marked RARE on the inspect card). Each pays out
big when its condition is met, and many change with what else is going on.

| Modifier | Condition and payout |
|---|---|
| Wisp Cannon | while it's moving fast, spits a homing wisp at the nearest foe every 0.45 s (4 x the material's sharpness). The wisps carry its element (below); heavy, they're cannonballs (x2.2, slower); large or huge, bigger |
| Headhunter | head hits do x3 |
| Desperate | x2 while your hand is below a third of its health |
| Lone Blade | x2 while it's the only weapon you own |
| Pristine | x2 while its edge is at 90%+ (keep it whetted) |
| Guardbreaker | hits on a foe winding up do x2 and fill its stagger meter x5 |
| Merciless | x3 on a foe below a third of its health |
| Avenging | after it parries, its next hit within 3 s does x3 |
| Stormcaller | a parry with it calls lightning: double what it stopped, through armour. Its element turns it into a storm (below) |

**Juggling** (swap gear round, throw it, hand off between weapons):

| Modifier | Condition and payout |
|---|---|
| Rested | +50% per second it spent out of your hand (up to x4), spent on its first hit |
| Baton | its hit marks the foe: the next hit with a *different* weapon within 4 s does x2.5 |
| Javelin | let go of it mid-swing (faster than 650 px/s) and it flies: a thrown hit does x4 |
| Mimic | picked up, it takes on the rare modifiers of the last weapon you held (a Mimic after a Mimic passes the first one's on) |

**Builds** (lean the whole pile one way):

| Modifier | Condition and payout |
|---|---|
| Lightning Rod | its hit draws the charge from every charged piece you own: +10 each, through armour |
| Kindred | +20% per other piece you own of its metal (up to x3) |
| Reckless | x2.5, but every hit chews its own edge |
| Kindling | a hit while it's hot sets every other weapon you own red-hot |
| Sanguine | its hits heal your hand 15% of the damage |
| Blood Price | every hit cuts your own hand for 4, and does x2.5 |
| Bloodthirsty | x(1 + 2 x how hurt the hand is): x2 at half health, up to x3 at death's door |

**Shields:**

| Modifier | Condition and payout |
|---|---|
| Riposte Guard | what it stops is banked (up to 80): your next weapon hit adds it all |
| Rally | a parry with it (a braced block) readies every weapon you own, and the next hit within 3 s is x1.5 |
| Hallowed | a parry with it heals your hand 8; a clean block, 3 |

**Elements ride the rare effects.** A piece's element is whatever it carries right now:
hot (superheated, burning or forge-hot) is fire; frosty or cold is frost; poisoned is
venom; corrosive is rot; charged is storm.

| | Stormcaller parry | Wisp Cannon wisps |
|---|---|---|
| fire | **Firestorm**: a fire tornado rages on the foe for 3 s, burning it | scorch (the default) |
| frost | **Blizzard**: a whirl of snow that slows it | slow it for 1.5 s |
| venom | **Acid Rain**: keeps it poisoned | poison |
| rot | **Rust Storm**: eats its armour | corrode |
| storm | **Thunderhead**: the lightning doubles and strikes every foe | a jolt can lock up a swing |

A storm deals 4 every quarter-second on top of its element. Combinations stack the way
you'd hope: a Mimic picked up after a superheated Stormcaller is a Stormcaller too, and its
own element decides the storm; Kindling turns a whole rack of Wisp Cannons and
Stormcallers to fire at once; a Lightning Rod in an electrified pile cashes in every charge.

## Rules
- **Blocking is by lanes** (`scripts/lanes.gd`). Every swing runs through its zone as a few
  parallel **lanes**, drawn as arrows over the telegraph the way the blade travels (up to
  8; about one every 46 px across the swing; a thrust is a closing ring with a dot for each
  point it strikes). Along each lane the blade is stopped, bit by bit, by whatever of
  yours it meets *on that arrow*: material, condition and speed set how much. While it
  winds up each arrow shows what's on it right now: **blue**, stopped; **amber**, partly;
  **red**, open. When it lands, each lane flashes how it ended, so a hit that got through
  shows which arrow had nothing on it.
- **What slips past is checked.** The blow that gets through is scaled by
  1 - 0.75 x (share stopped): catch two lanes of three and the third is a glancing hit
  (~17%, not 33%). A hand caught in the swing before your gear isn't checked.
- **Nothing pierces a block.** Attacks that are "good
  against gear" wreck what blocks them instead: a maul chews gear up, a rotten blade rusts
  it, a brazier heats it, a lightning staff charges it.
- **Velocity parry.** Above 450 px/s an item blocks extra, and at 2400 px/s it blocks
  everything, lane by lane. A parry is anything of yours that meets the blade fast
  (or a braced shield), **however much else gets through**: the damage it stopped counts
  again toward the stagger meter and throws the enemy off balance. A parry that also
  stops nearly everything staggers it outright. Swinging a weapon through an attack is a
  real way to block; **shields are too heavy to parry by swinging** (a fifth as well):
  brace them (Space) instead. Fast items glint; spark size scales with momentum.
- **Shield wear by material.** Each material has a `wear` (in `materials.gd`): how fast
  enemy blows chew it as it blocks, on top of its toughness. A round shield blocking the
  Woodcutter's hew over and over holds about 15 blows in wood, 26 in copper, 70 in iron
  and 260 in steel before blows start getting through. Metal shields' bosses and bands are
  their own metal.
- **Charged gear shocks whoever strikes it**: 6 plus 60% of what that piece stopped,
  through armour (x1 + 1.5 x the enemy's armour). An electrified shield is a weapon.
- **Grounded breakage.** Wood splinters along the grain, metal dents (copper fast, steel
  slow), and leather and cloth tear. Pieces that lose their connection fall off as
  their own bodies.
- **Hit locations.** Head (x1.6), torso (armoured), hands (hitting the swinging hand
  during a windup staggers it more easily). Where a pauldron has been stripped the flesh is
  **exposed** for the rest of the fight (x1.6).
- **Armour is hard to beat off.** A pauldron only gives way to force late in a fight (60% and
  90% of the foe's health lost; `Enemy.ARMOR_BREAKS`). **Corrosion** strips it on its own,
  far sooner (`Enemy.CORRODE_BREAKS`: about three corrosive hits for the first, five for the
  second), so a corrosive weapon is how you get at the exposed flesh early. The Rusted's
  rotten plate still falls early by itself.
- **Stagger.** An invisible meter fills from damage you prevent (parries count double) and
  damage you deal; the enemy sways more as it fills. Full: it's **broken** for 2.5s (slumped,
  hits x1.5) and a **weak point** opens; the first hit on it does x3 and closes it.
- **Elements come from modifiers.** *electrified* charge flows through metal; *superheated*
  heat spreads by contact and sets wood, leather and cloth alight. Your hand is hurt by
  anything charged or hot it holds or touches, unless the matching ring protects it. The
  enemy gets zapped or scalded when it hits charged or hot gear.
- **The pile is a catalyst.** You can only hold one thing, so gear piles up at the
  bottom of the screen, and contact keeps it interacting:
  - Hard knocks damage the cell they land on (judged by closing speed and the other
    thing's mass and hardness).
  - *magnetic* gathers your coins, scraps and pauldrons into a pile around it (whole gear
    is left alone, so a magnetic shield is still a shield), and the enemy's blade is drawn
    to it too: it blocks a little wider than it is. The Lodestone utility is a magnet.
  - *sticky* never comes on gear from the shop or crates: only from glue (the Glue Pot,
    Pitch). It means a **patch of wet glue** (glossy amber pixels), not glue all over: see
    **Glue and fused gear** below. A blade that meets the glue comes away gummed up and the
    enemy's next wind-up is slower.
  - *frosty* spreads cold, puts out fires, and makes things slippery and brittle.
  - *corrosive* starts **rust**: a state like heat. Rusting metal loses a cell now and
    then, and it fades unless something corrosive keeps feeding it. Only the corrosive
    thing itself spreads rust, to metal it touches directly; rust caught from it stays put.
    Mending scours it off.
  - *volatile* explodes when heated, shocked, struck hard or hit by an attack. Blasts
    shove, shred and ignite nearby items, and they hurt the enemy if they go off over
    one of its body parts.
  - *regenerating* heals itself.
- **Hoard utilities** pay you for what's piled up: Weapon Rack (+4 hand HP per weapon you
  own, up to +40), Trophy Pegs (gear takes 8% less wear per enemy pauldron you keep, up to
  40%), War Banner (blocks stagger 15% more per shield, up to +45%), Packrat Idol (weapons
  hit 2% harder per whole weapon, shield and utility you own, up to +20%; broken-off chunks
  don't count for any of these), Merchant's Scales (+1 coin per 4 things
  after a fight), Crucible (metal scraps and pauldrons resting on it melt into coins after
  a fight), Lodestone (gathers loose metal), Sentinel Stone (everything you aren't holding
  blocks better: each stone closes 12% of what would get past it, stacking up to six, about
  54%; cheap and common, for a pile that tanks blows by itself). Plus the old ones: Coin Purse, Ledger,
  Whetstone, Anvil, Horseshoe, Grave Lantern.
- **Whetstones and anvils wear out.** Each takes a share of the condition it puts back (a
  whetstone 10%, an anvil 5%), chipping away one edge cell at a time so you can watch it go.
  They come in harder materials later in a run: sharpening a half-worn iron longsword back
  to full, a stone whetstone is good for about 3 of those, iron 4, steel 7.
- **Several modifiers** on one thing are rare, and more than two exceptional: once a thing
  rolls its first, the second comes in about 6% of the time (more on rarer stock, +5% per
  prestige), and each after that at a quarter of the chance before. Clashing ones (two
  sizes, heavy and weightless) never stack.
- **Shields are worth holding.** They're 40% lighter than the same metal as a lump. A blow
  a shield takes the brunt of fills the enemy's stagger meter 50% more. **Space braces**
  a held shield: for a moment (0.45 s) every block it makes is a parry, then it needs its
  cooldown to reset. Weapons still block, but only three-quarters as well as their
  material would.
- **Kits** dab a modifier on the whole piece (the Glue Pot only a patch, where it touches): Glue Pot (sticky), Resin Block (reinforced:
  twice as tough, every crack filled, an amber glaze), Spike Kit (spiked), Bottled Wisp
  (weightless).
- **The shop is a sandbox.** Stock is real physics items with live modifiers, so the
  shelf interacts with your gear before you buy anything. Lean into this.
- **Crates hold loot.** Knock about a third off one and it bursts open. The ways in:
  - **Smash it** (`Item.smash`): a swing that strikes one of your crates lands like a weapon
    hit, its swing damage cut down by how much harder the crate is than the weapon. A steel
    warhammer or an iron mace bursts a wooden crate in about three swings, a shortsword or
    greatsword in about five, a wooden club barely dents one. A strongbox wants steel and
    a lot of swings, and a steel reliquary all but ignores anything short of **prestigium**
    (which cuts uncapped: a few swings). Only crates take this: swinging through your pile
    in a fight doesn't chip the rest of your gear.
  - **Rust** eats a metal crate's lock: set something corrosive against a strongbox or
    reliquary (or let the Rusted's blade find it) and it springs open in about six seconds,
    and a **corrosive weapon** eats a third of the lock with every hit (three swings).
  - **Blow it up:** a blast right beside any crate, steel included, blows its lock
    (`Item.BLAST_LOCK`); at the edge of the blast it only shakes it.

  Crates on a shop shelf stay shut until they're bought. Knocks between your things are
  judged by how fast the bits that met were moving, spin included, so a swung blade's head
  hits at its own speed.
- **Hazards only hurt what you hold.** Hovering or inspecting is always safe, and so is
  holding a weapon by its wrapped handle.
- **Scraps have somewhere to go.** The shop has a **scrap chute** (top centre): drop or
  toss scraps and broken-off chunks into it and they're gone, and metal pays a little back
  (per cell: copper 0.1 coin, iron 0.15, steel 0.25, gold and gems 1; rust halves it).
  After each fight, scraps burnt to a crisp or rusted through **crumble to dust** on their
  own. The Crucible and Lodestone still melt down and gather sound metal.
- **Every chain reaction ends.** Broken-off pieces keep only physical modifiers; fire burns
  at most 8s per item; rust fades. Backstops: shake, spark and body caps.
- **Potions** are glass flasks. Broken (thrown, struck, crushed, or smashed with Space in
  your hand) they spray liquid pixels that soak into whatever they land on.
  Transmutation (Steelwater, Ironwater, Copperwater, Aurum, Petrify, Wildwood) converts
  cells; once most of an item has turned it becomes that material. Coatings (Venom, Lamp
  Oil, Rime, Firewater, Stormglass, Pitch, Featherdraught) take hold once enough has soaked
  in; every drop of Mending Draught mends the whole piece it lands on by 12% (and scours the
  rust), so a splash brings a battered blade back to new. New: **Giant's Brew** (half again as big), **Pixie Dust**
  (two-thirds), **Leaden Draught** (heavy), **Featherdraught** (weightless), **Homeward Brew**
  (sent home to keep).
- **Tempering**: quench red-hot metal with frost and it becomes permanently 30% tougher.
- **Size is a modifier.** *small*, *large* and *huge* rescale the pixel mask.
- **Weight is a modifier.** *heavy* and *weightless* exclude each other. *Weightless* (4% of
  the weight, no gravity) is the one lightness mechanic: it replaced the old *floating* and
  *featherweight*. A weightless thing stays where you leave it, flicks round with no
  effort and adds almost nothing to whatever it's glued to (but a blow knocks it away).
  Featherdraught, the Bottled Wisp and the Hearthblade make things weightless for good; the
  **Ring of Levitation** makes whatever is under the hand weightless for 6 seconds. Saved
  gear with the old modifiers comes back weightless.
- **Weapons vary.** Shortswords and longswords come as straight, leaf or tapered blades;
  there are also daggers, falchions, axes, warhammers and greatswords, each its own shape
  and stats.

## Enemies
Every enemy is a character with a check built into it (`scripts/enemy_defs.gd`, each with
its own modelled low-poly body in the "Character" design (`assets/enemies/<name>.glb`, built
by `tools/enemy_models.py`) and its own idle, weapon and reactions):
**Two kinds of fighter.** The big ones (Brute, Headsman, Castellan, and the Rusted to a
degree) are very hard to stagger and swing low and wide, and their blows **cleave**: each
thing in the way takes the full hit but only part of the force stops there, so the swing
chews on into the pile behind (a parry still stops it). The light ones (Footman, Duelist,
Lamplighter, Wraith) throw lots of small, quick cuts all over the screen, some chained in
pairs, for less damage, and they stagger easily.

On the first run (prestige 0) the stage 2 and 3 enemies have 60% and 70% of their
health (`FIRST_RUN_HP`), since most runs haven't found a good weapon by then.

- **Footman** (stage 1): a conscript with a sword. Small cuts across the middle and the
  centre, and a slower high slash (none of the fast high corner cuts: those are the
  Duelist's and the Lamplighter's). Flinches badly and staggers easily.
- **Woodcutter** (stage 2): a felling axe. Slow, wide chops (left, right, across the
  middle, along the floor), each called out from far off, and no thrusts: one shield in the
  right place stops any of them.
- **Knight** (stage 4, with the Rusted, Zealot and Wraith): overheads and quick thrusts,
  all from above. A pile on the floor is no shield against him.
- **Brute**: a maul. Low swings across half the floor, slams, and a **ground pound** that
  hits the whole floor at once; all of them cleave through gear. Nearly impossible to
  stagger. Enrages below a third of his HP.
- **Duelist**: a rapier. Thin, quick lines and small cuts all over the screen, and a
  **riposte** at your hand after every clean block. Low poise, staggers easily.
- **The Rusted**: a rotten blade. What blocks it **rusts**. Its own plate is a shell: pauldrons fall early and it corrodes twice as fast.
- **Pyre Zealot**: a brazier on a chain. Everything that blocks it comes away **hot**: wood
  and leather catch, metal is too hot to hold. Fireproof. Cold hits stagger it outright.
- **Wraith**: no body. Sweeps whole halves of the screen for little damage; its **grasp**
  comes for wherever your hand was. Plain steel does half; charged, hot or cold weapons
  do more; punches pass through.
- **Castellan** (boss): a tower shield of his own. Slams the shield down low and wide, and
  overheads. His torso is covered until he's reeling or broken; after three clean blocks he
  **shield-bashes** your pile apart and brings the sword down. Very hard to stagger.
- **Hollow King** (boss, prestige 1+): the Wraith's reach with a sword, and it grasps at you
  whenever you block it.
- **Headsman** (rare, prestige 2+): two enormous, slow swings (one straight down the middle,
  one low across the floor) that cleave through gear like kindling. The hardest thing in
  the game to stagger.
- **Lamplighter** (rare, prestige 3+): puts the lights out. Its staff charges whatever
  blocks it, and charge runs through a metal pile to the hand holding it.
- Past the first boss, the middle stages are sometimes **two enemies at once**, each with its
  own health, stagger and telegraph (tinted by its weapon).
- The **Vault Warden** guards the Hidden Vault.

Attacks are data (zone, direction, damage, impact on gear, push, wind-up, pose, trait,
tracking, follow-up). Poses are procedural for now; each attack names the HeadnHands clip
to record.

## Look and design exploration
- **Settings** (`scripts/backdrop.gd`): Homestead, Dungeon Cell, Corridor, Catacombs, Crypt
  Chapel, Cistern, Forge, and the rare **Ossuary** (prestige 2+: bones drop from the
  ceiling) and **Star Chamber** (prestige 3+: nothing weighs much; everything you drop
  hangs in the air). A run goes early, early, middle, middle, late; prestige pushes it deeper.
  - Cistern: floodwater along the bottom. Things float and slow, fire goes out, red-hot
    metal is quenched (tempered), and charge spreads through the water, hand included.
  - Catacombs: pitch dark (light only around your hand). Take the Grave Lantern off the
    wall and it lights wherever you put it. Skulls on a ledge.
  - Crypt Chapel: a reliquary to smash open mid-fight.
  - Forge: a Smith's Hammer on the tool rack, often a weapon beside it, and the raised hearth
    (lower left) heats whatever you hold in it.
- **Secret: the Hidden Vault.** Late settings sometimes hide a small lever in the wall.
  Punch it or swing across it and the next fight is in the Hidden Vault.

## Stage props
Each setting has things to use mid-fight (`scripts/props.gd`), modelled into the set in
3D: each sits on whatever surface of the room is under its spot on screen (back wall, side
wall, ceiling), lit and graded like the rest; a faint ring shows a live one when the hand is
near. All in the top half. Alt over one to read it. Most are **element
sources**: hold a piece in one and it takes on the element, the way into reactions.

| Setting | Props |
|---|---|
| Dungeon Cell | wall torch (fire); *loose brick* (secret, 60%) |
| Corridor | wall torch (fire); chandelier; *loose brick* (secret) |
| Cistern | rust grate (rot: careful, it then rusts your other metal) |
| Catacombs | fungus bloom (venom) |
| Crypt Chapel | chandelier; blood altar |
| Forge | quench barrel (frost; dunk red-hot metal for *tempered*) |
| Ossuary | fungus bloom (venom); *loose brick* (secret, 50%) |
| Star Chamber | storm glass (charges a piece for 8 s); *falling stars* (secret) |

- **Chandelier**: punch its chain and it drops on the foe: 35 damage, a stagger, and it's
  set alight.
- **Blood altar**: hold a weapon on it: a third of your hand's health (never fatal) for a
  random rare modifier, once.
- **Loose brick** (only shows near the hand): punch it three times for 10-20 coins,
  sometimes a ring. **Falling stars**: every 10-18 s one streaks across the Star Chamber's
  sky; punch it for gold, sometimes a ring.

## Element reactions
Anything elemental that reaches a foe marks it for 5 s: an infused weapon's hit (a weapon
hot and charged carries both), wisps, storms, a charged or hot block, the chandelier. A small
dot over its head shows each mark, its ring running down. A **different** element landing
on a marked foe sets the pair off (at most once every 1.5 s per foe; `Main.REACTIONS`):

| Pair | Reaction | Effect |
|---|---|---|
| fire + frost | Thermal Shock | 30 damage; both spent |
| fire + storm | Overload | 20 damage and an outright stagger |
| frost + storm | Superconduct | armour cracks; vulnerable (x1.5 weapon damage) for 5 s |
| fire + venom | Toxic Blaze | set alight and poisoned 12 s |
| frost + venom | Brittle | slowed, and vulnerable for 5 s |
| storm + venom | Neurotoxin | a wind-up seizes (stagger); slowed 4 s |
| fire + rot | Slag | armour melts away, and 12 burning damage through armour |
| frost + rot | Frostbite | 16 damage, slowed 4 s |
| rot + storm | Galvanic | 18 through armour |
| rot + venom | Blight | poisoned 15 s, armour eaten through |

## Secret places
Four places that aren't dungeons at all (`scripts/secrets.gd`), each reached by a chain of
odd things done with the game's own systems, each with a guardian found nowhere else.
Finishing a chain makes the next ordinary fight happen there (never in a boss's place),
with a prize hanging on the wall: a steel weapon with an element and a rare modifier, and gold.

| Place | The chain | Guardian |
|---|---|---|
| **Gilded Gullet**: down a golden throat; coin ribs, gold teeth, gold raining down | feed 40 gold down the shop's scrap chute in one visit (it hiccups up a **Gilded Tooth**), then touch the tooth to the gong | **Coin Golem**: a hoard that stood up. Its blows swallow every coin in their path and heal it (4 per coin) |
| **Giant's Table**: you're crumb-sized on a kitchen table: cheese mountain, teacup tower, fork tree, a church-sized candle; the giant's footsteps jolt the table | open a loose brick, then push something shrunk **twice** with Pixie Dust through the hole it left | **Housecat**: swipes, pounces, tail lashes. Fling a gold coin past it mid-wind-up and it drops the swing to chase it. It has a life to spare (comes back once at 30%) |
| **Clockwork Orrery**: inside a brass orrery among the stars; two planets swing through the play field on their arms, batting your pile about; low gravity | catch two falling stars in one Star Chamber fight; a third hangs still. Reach it with something **weightless** | **The Astronomer** (a ringed planet for a head): comets at your hand, orbits, and *unmoor*: everything you own falls upward for 2 s |
| **Ink Margin**: in the codex's margins; black and cream, lines of text, giant letters, a wet ink floor that drags | set off three **different** element reactions in one fight; the third leaves an **ink blot** in the air: punch it | **Errata**: an ink-black misprint of the last ordinary foe you fought, with its moves, a little faster |
- **World grade** (`shaders/thermal.gdshader`) re-colours the 3D room and enemy through the
  setting's five-colour gradient.
- **Dark** (`shaders/candle.gdshader`) is a stage modifier: only a pool of light around the
  hand. The Catacombs and the Lamplighter use it.
- **Designs** (`scripts/looks.gd`), switched live with F5-F8:
  - Attack telegraph: Red Zone, Blade Path, Looming Shadow, Scratch Marks, Lock-on Brackets
  - Hand: Gauntlet, Pixel Hand, Bone, Shadow Puppet
  - Items: Flat Pixels, Outlined Sprite, Material Texture, Raised Tiles
  - Enemy: Character (one model per enemy), Boxes, Great Helm, Wraith, Marionette
- Render every design to `shots/`:
  `Godot_v4.7.2-stable_win64.exe --path . -s res://tests/style_shots.gd`
- Render the home, hand gestures, codex, every character, a duo and the post-boss shop:
  `Godot_v4.7.2-stable_win64.exe --path . -s res://tests/review_shots.gd`
- Render every character's modelled body with the grade off (and again with its armour
  knocked off), to judge the models as modelled:
  `Godot_v4.7.2-stable_win64.exe --path . -s res://tests/model_shots.gd`
- The world grade keeps a share of the scene's own colour (`StyleManager.KEEP_COLOUR`, or a
  setting's `keep` in `Backdrop.LOOK`), so the characters' palettes show through the ramp.

## Shop rarity
Every item is Common, Uncommon, Rare or Legendary (`ItemDefs.RARITY`). Early shops are
mostly common wood, leather and copper; iron arrives mid-run, steel late, and modifiers get
likelier as you go (`ItemDefs.SHOP_ODDS`; prestige pushes the whole ladder up). Some gear
needs a prestige before it can appear at all (`ItemDefs.PRESTIGE`): the Aegis, Hearthblade,
Packrat Idol and Homeward Brew from prestige 1, Venom Fang, Aurum and the Mirror Shield from
2, the Sunderer from 3, and the prestigium gear from 4.

**Legendaries are rare**: none before mid-run, then about 1 in 100 offers, about 1 in 30
late. Each wears a colour-cycling rim and glints, and each does something of its own
(`legend` in `item_defs.gd`, handled in `main.gd`):

| Legendary | Unique behaviour | Ascended (prestigium) |
|---|---|---|
| Stormbrand | lightning leaps from every hit to every other foe (half damage) and locks up any wind-up | full damage to every foe, and every one of them stopped mid-swing |
| The Aegis | nothing gets past it, even a cleaving blow | and every blow it stops is a parry |
| Hearthblade | a hit on a burning foe sets the fire off: double damage, fire out | every hit sets them alight; a burning foe takes x4 and keeps burning |
| Venom Fang | poison stacks (+4 s a hit, up to 24) and a poisoned foe takes +25% | up to a minute, +60% |
| Mirror Shield | sends half the force of every blow it takes back | sends back 1.5x |
| Sunderer | every hit tears armour away | strips it all and fills the stagger meter |
| Paragon (prestigium) | every hit strikes again a beat later | three more times |
| Bastion (prestigium) | braces itself whenever it's ready | always braced |

**Prestigium** is a metal only found past the prestige 3 wall (prestige 4+): nearly twice as
tough as steel, lighter, keener, and it mends itself and never rusts. Some weapons and
shields come in it (20%), and the **Ascendant Draught** turns things to it. Pour the draught
over a legendary until most of it has turned and the legendary **ascends**: "Prestigium
Stormbrand", double the swing, a paler rim and a halo, and its behaviour goes absurd (the
table's last column). Paragon and Bastion are born ascended.

**Weapons wear their history.** Every foe a weapon draws blood from cuts a tally notch in its
edge; every boss it helps kill adds four gold runes down the blade. From the third boss the
runes glow, and from the fifth the edge is gilded. The inspect card counts both.

## Sound
`scripts/sfx.gd` synthesises bare-bones effects at startup. Two **damage stings** tell you how
big a blow was without looking: a dissonant, driven *pain* sting when something gets through
to your hand (louder and a touch lower the harder the hit, full at 30), and a punchy, bright,
consonant *reward* sting when your weapon lands (louder the harder the hit, full at 60;
`Main.DAMAGE_SOUND_*`). Home is a night in: the hearth
crackling and crickets outside the window, a seamless loop synthesised by
`tools/make_night.py` into `assets/music/amb_night.ogg` (the old cinder and tunnel
recordings play over a death). Each stem plays on its own player, all started together;
every 2 s `Music._keep_in_step()` puts any stem that has drifted more than 40 ms from the
bass (or stopped) back in step, and the music clock follows the audio only once it has kept
real time for a second. The shop's calm mode holds the drums at zero.
**At death's door** (a fight, and the hand below a quarter) the whole score narrows to a band:
a low-pass and a high-pass on the Music bus close in over half a second (highs gone above
1.4 kHz, lows below 380 Hz) and open back up when you heal or the fight ends
(`Music.critical`). The boss's guitar phrases are each damped (0.12 s) right at the end of
their clip in Live (2, 2, 2, 1, 2 and 4 bars): the files run on with the guitar's delay
repeating the last notes, which rang on into the next phrase.

## Layout
- `scripts/main.gd`: game flow (home, run, shop, prestige), attack resolution, weapon hits, hoard effects
- `scripts/item.gd`: cell-grid physics items, breakage, parry speed, elements, rust, swing trail
- `scripts/hand.gd`: cursor-hand: gestures, grip, injury, hazards, rings
- `scripts/enemy.gd`: head/hands rig, modelled bodies (with primitive fallbacks), poses, combos, reactions
- `tools/enemy_models.py`: Blender script that builds every enemy's `.glb`; `tools/build_enemies.cmd` runs it and renders the shots
- `assets/enemies/`: one glTF per character, split by rig part
- `scripts/enemy_defs.gd`, `item_defs.gd`, `materials.gd`: all tunable data
- `scripts/save_data.gd`: the save file (home, codex, deepest run)
- `scripts/codex.gd`: the index (five collections), and the rename box
- `scripts/props.gd`: stage and home props, element sources, chain pieces
- `scripts/secrets.gd`: the secret places, their chains and guardians
- `scripts/lanes.gd`: how a blow is split into lanes
- `tools/autoplay.gd`: an autopilot that plays (records footage with `--write-movie`)
- `tools/balance.gd`: the autopilot against every enemy with a plain kit; time to kill and damage per blow
- `scripts/backdrop.gd`, `looks.gd`, `style_manager.gd`, `zone_overlay.gd`, `tooltip.gd`

## HeadnHands
The enemy rig uses the same three performer nodes a HeadnHands character drives. The
next step is to make the enemy an `HHRig` character, record `act_<attack>` clips, and
play those instead of the procedural poses in `Enemy.POSES`.

### The models
Every enemy has a modelled body in `assets/enemies/<name>.glb` (the display name, lower
case, spaces to underscores: `the_rusted.glb`, `hollow_king.glb`, `vault_warden.glb`).
They are generated, not hand-sculpted: `tools/enemy_models.py` builds each one in Blender
from lofted profiles and chamfered blocks (flat shaded, 700-1200 triangles) and exports
it. Rebuild them all, or one, with:
```
tools\build_enemies.cmd
tools\build_enemies.cmd footman wraith
```
(That calls `blender --background --python tools/enemy_models.py -- <slugs>` and then
renders `shots/model_*.png`.) No editor import step is needed: `enemy.gd` reads the files
at runtime with `GLTFDocument`, so headless tests see them too. If a file is missing or
has no usable parts the old primitive builder dresses the rig instead.

A model is split into objects named for the rig, and that split is the contract clips
will animate against:

| object | hung on | notes |
| --- | --- | --- |
| `Torso` | Torso (y 1.22) | the body from the belt up; follows the head's yaw and hunches with wounds |
| `Head` | Head (y 1.68) | performer; the face points +z (at the camera) |
| `RightHand`, `LeftHand` | the hands | performers; a fist closed round a vertical grip, thumb inward |
| `PauldronL`, `PauldronR` | Torso | the object sits at the shoulder; it is hidden when the armour breaks and a raw patch and a falling pauldron take its place |
| `Weapon` | RightHand | points up the hand's +y; the hilt sits at the hand's origin |
| `Shield` | LeftHand | the Castellan's wall; `shield_arm` moves it over the torso while the guard is up |
| `<Part>_<thing>` | that part | any extra piece, e.g. the Wraith's `Torso_Cowl` |

Materials are flat colours. `tint_*` ones are blended halfway with the character's
`data.color` on load; `glow_*` ones are emissive (eyes, the Hollow King's blade, the
brazier's coals) and are left alone when wounds darken the rest. Each rig gets its own
copies, so two Footmen in a duo bleed separately.

### Recording `act_<attack>` clips
The game drives three nodes: `Head`, `RightHand`, `LeftHand`. The torso is not animated
by clips; it follows the head's yaw and sags with damage. Record against the same frame
the models were built in: metres, +y up, +z towards the camera, the rig's origin on the
floor between the feet. The camera is at (0, 1.45, 1.5) with a 40 degree field of view,
so everything above y 0.9 is on screen and the hands should never leave the frame.

Rest: right hand at (0.3, 1.2, 0.25), left at (-0.3, 1.2, 0.25), both turned slightly
inward (`Enemy.REST_R` / `REST_L`). Every clip should start from and return to rest, so
the procedural idle (breathing, the Brute's heave, the Duelist's bounce) can blend back in.

A clip has two beats that the game times itself: the **wind-up**, which it stretches to
the attack's `windup / speed` seconds (so record it at the attack's listed `windup`), and
the **hit**, which is 0.09 s and lands on the zone. The attack's `zone` in
`EnemyDefs.ATTACKS` says where the blade must be at the hit, in normalized screen space.
`Enemy.POSES` is the storyboard: each pose's `wind` and `hit` give the right hand's
position and rotation at those beats, and the flags say who else moves:
- `l`: two-handed; the left hand holds the weapon a little below and behind the right
- `mirror`: the left hand mirrors the right (the Wraith's grasp: both hands open, reaching out of the screen)
- `shield`: the left hand does the moving and the sword hand stays put (the Castellan's bash)
- `head`: the head rears back and jerks forward; the hands stay low (the Rusted's spit)

One clip per attack id, named `act_<id>`, and then set `"clip": "act_<id>"` on that
attack. Attacks that share a pose today can share a clip until each has its own:

| clip | pose | who |
| --- | --- | --- |
| `act_slash_high_r`, `act_flick_high`, `act_shroud_r`, `act_behead` | high_right | Footman, Knight, Duelist, Wraith, Headsman |
| `act_slash_high_l`, `act_shroud_l` | high_left | Footman, Wraith |
| `act_slash_low`, `act_lantern_swing` | low | Footman, Lamplighter |
| `act_drag_low` | low_left | The Rusted |
| `act_overhead_l`, `act_overhead_r`, `act_ember_rain` | overhead_l / overhead_r (two-handed) | Knight, Brute, Castellan, Zealot |
| `act_thrust`, `act_riposte`, `act_brand`, `act_spark` | thrust | Knight, Duelist, Zealot, Lamplighter |
| `act_lunge` | lunge | Duelist |
| `act_sweep`, `act_rake`, `act_flail_arc`, `act_arc_lash` | sweep (two-handed) | Brute, Rusted, Zealot, Lamplighter |
| `act_slam`, `act_ground_pound`, `act_cleave` | slam (two-handed) | Brute, Headsman |
| `act_spit` | spit (head) | The Rusted |
| `act_grasp` | grasp (mirrored) | Wraith, Hollow King |
| `act_shield_bash` | bash (shield arm) | Castellan |

Tracking attacks (`riposte`, `spit`, `grasp`, `spark`) aim at wherever the player's hand
was when the wind-up began; the clip's hit should come straight at the camera and the game
shifts the zone. Follow-ups (`shield_bash` chains into `overhead_r` with a 0.6 s wind-up)
play back to back, so the bash clip should end somewhere the overhead can start from.
Besides the attacks, three reactions use fixed poses worth a clip each: the stagger
(`Enemy.stagger`, right hand flung up and out), the break (`Enemy._break`, slumped, hands
low) and the death (`Enemy._die`, the whole body pitches forward).

## Builds and versions
The version lives in `project.godot` (`application/config/version`) and is shown on the
placard at home. It goes up with the game: the last number for an ordinary batch of
changes (new items, tweaks, fixes), the middle one only for a big milestone (a new system,
a reworked core); the first only by decision.

Player builds: `python tools/build.py [linux] [windows]` (both by default) makes one file per
platform in `build/`, ready to hand to a playtester:
- **Windows** (`Hoardsman-v<version>-windows.zip`): `Hoardsman/Hoardsman.exe` (pack embedded, no
  console window) and a plain-English `How to play.txt` (unzip, double-click, what to do
  about the SmartScreen warning, the basic controls). Nothing to install.
- **Linux** (Hunter's platform; `Hoardsman-v<version>-linux-x86_64.tar.gz`): the executable
  (mode 755) and a run README.

Both are release exports, so the developer keys (F1, F4, F5-F9) are off in them.
`.github/workflows/build.yml` runs the same script on GitHub: every push to main builds both
as run artifacts, and pushing a tag `v<version>` (it must match `project.godot`) publishes them
on the repo's Releases page. A local build needs Godot's export templates for the platform.

## Tests
All headless, from the project folder:
```
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/smoke_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/enemy_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/home_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/stage_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/chaos_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/rarity_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/ring_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/block_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/ready_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/smash_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tools/balance.gd -- 0
```
The block test also covers reactions, props, every secret place's chain and guardian,
and glue (patches, fusing, a buckler on a sword, heft, the save, tearing apart).
`tools/balance.gd -- 0 hybrid` fights everything with one iron buckler glued to an iron
longsword instead of a separate shield and sword.
Windowed renders: `tests/home_shot.gd`, `tests/secret_shots.gd`, `tests/setting_shots.gd`.
`tests/storm_shot.gd` (windowed) shows a firestorm and frost wisps.
The block test prints lane counts, the glancing-hit share, how long each shield
material lasts, block shocks, rare-modifier odds and the Wisp Cannon's output.
`tests/lanes_shot.gd` (windowed) saves the lane arrows to `shots/lanes_*.png`.
The enemy test also checks that every character loads its modelled body, wears two
pauldrons on the torso, and loses them (and keeps the wounds across an F8 rebuild).
The tests write their save to `user://hoardsman_test_save.txt`, never the real one.
