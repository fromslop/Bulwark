# Bulwark: state of the project and where to take it

Written after the November 2026 pass (shop rework, hoard utilities, modifier fixes, the
enemy roster, the gauntlet, home/prestige/codex, duos, potions). An outside read of the
whole thing: what's working, what isn't, what's being left on the table.

## What the game is, and why it works

The identity is the **pile**. One hand, one thing held at a time, so everything else sits
at the bottom of the screen as a physical wall that the enemy's attacks run into cell by
cell. That one rule produces the strategy layer for free: where you put things is a build,
what they're made of is a build, and the pile keeps reacting (heat, charge, rust, glue,
magnets) whether you're looking or not. The steel-and-spikes hoard you described, where the
enemy killed itself on your floor, is exactly the kind of thing a good system produces
without anyone designing it. Protect that above everything else.

Three other pillars are genuinely strong:

- **No HUD.** Coins are coins, health is the hand, the enemy wears its wounds. It's a
  constraint that keeps paying off (the stat shelf, the door home, the codex as a book you
  hold all fell out of it naturally).
- **Nothing pierces a block.** You said it and then took it back, and the take-back is the
  right call. The game's whole promise is "if it's in the way, it stops the blade". Attacks
  that are good against gear now wreck the gear instead (maul, rust, fire, lightning), which
  keeps the promise and still creates pressure.
- **Data-driven attacks and characters.** Zones, traits, tracking, follow-ups, reactions are
  all dictionary fields. Adding an enemy is an afternoon, not a week.

## Problems and imbalances

**1. The world grade erases the characters.** The thermal shader recolours the 3D layer
through the setting's five-colour ramp, so in the Corridor every enemy is orange and in the
Cistern every enemy is green. The new per-character models (fur mantle, feathered hat,
rotten plate) read by silhouette only; their palette is gone. Either exempt the enemy from
the grade (render it to the 2D layer, or grade the room only), or make the grade much
weaker on the enemy. This matters more now that the enemies are supposed to be characters.

**2. Prestige scaling is linear on the enemy and unbounded on the player.** Enemies get
+35% HP per prestige; the player gets stackable draughts every shop and hoard bonuses with
caps. By prestige 3 enemies have double HP and the player has whatever they've stacked.
It'll work for a while, then one side runs away. Decide which: if the fantasy is "the run
keeps getting harder until it kills you", enemy scaling should be superlinear and draught
prices should climb. Watch the stat shelf: a guaranteed stackable upgrade every visit is a
lot of power.

**3. Gear fear needs a counterweight.** Boss notches and names make a kept sword precious,
which is the point, but there has to be a reason to take it off the rack. Options that
don't break the fear: notches engrave visibly on the blade (pixels of the mask change);
titles at 5 / 25 / 100 bosses; a small bonus that is *earned by use* (a notched sword
recovers a touch faster), never something that makes the sword safe. Repair at home (the
anvil) should probably be slow and partial, so a legend worn to a nub is a story.

**4. The economy is opaque and slightly anti-spend.** Coins-as-objects is charming, but the
Ledger and the Ring of the Miser reward sitting on coins, and the Merchant's Scales and
Packrat Idol reward owning things, so the dominant play is "buy cheap junk, never sell".
There's no selling at all. A pawn shelf (drop an item on it, get coins) would close the
loop and make "take it home or sell it" a real choice at the boss door.

**5. The stagger meter is invisible.** Posture sway is subtle; players won't know a break is
coming, so they can't plan the big swing. Cracks spreading across the pauldrons, or the
enemy's head drooping further, would carry it without a bar.

**6. Rock-paper-scissors creep.** The counters are partial on purpose (the Knight's
overheads still touch a tall pile, the Rusted's rust fades), but every "check" enemy is a
temptation to make a hard counter. Keep every counter *expensive to ignore*, never
*impossible to survive*. The Headsman is closest to the line: 50 damage, impact 3.2, and
nothing light stops it. If playtests show runs ending on him with no answer, cut impact.

**7. main.gd is 1500 lines.** Home, shop, run structure, combat resolution and the meta are
one file. It works, but the next three features will each make it worse. Split: `run.gd`
(stages, prestige, encounter), `shop.gd`, `home.gd`, keep `main.gd` as the conductor.

**8. Save safety.** One text file, no version field. Add `"version": 1` now, before the
first player has a home full of gear a format change would eat.

## Missed potential

- **Placement is a build; let the player commit to it.** Everything shoves. A "Stand" or
  "Brace" utility (things resting on it aren't pushed by attacks) or a ring that pins the
  item under the hand would turn a lucky pile into an intentional fortification.
- **The shop sandbox is underused.** Stock interacts with the pile before you buy, which
  is great, and almost nothing is designed around it. A superheated item on a shelf next to
  a frost potion, a magnetic shelf item pulling your coins up to it, a crate you can smash
  on the shelf for free: the shop could be a puzzle every visit.
- **Settings as fights.** Cistern, Forge and Star Chamber change the rules; the others are
  backdrops. Every place should do one thing to the pile (the Ossuary's falling bones are a
  start). Darkness plus the Lamplighter is the right kind of pairing; do more of it.
- **Duos are a tactics layer waiting to be used.** Two telegraphs at once makes placement
  matter twice. Pairings with a plan (a Footman who shoves your pile left into the Duelist's
  lane) would be more interesting than two random names.
- **The hand as an actor.** It has gestures now. It could react to more: wince when
  holding something hot, wave the enemy on after a parry, drum fingers while the shop sits
  idle. Cheap, and it's the player's face.
- **Playtest telemetry.** There is no record of how runs end. A one-line CSV per run
  (stage, prestige, enemy, hand HP, coins, items owned) in user:// would make every balance
  question above answerable in a weekend.

## Direction

1. **Tune by playing.** The roster and the shop are now wide enough that the numbers need
   a human. Add the telemetry line, play twenty runs, then adjust power, impact, prices.
2. **Real models and clips.** The primitive "Character" models prove the silhouettes; the
   next step is a Blender → glTF → HeadnHands pipeline so each enemy has a modelled body and
   recorded `act_<attack>` clips driving the same three nodes. Fix the grade first or the
   models won't be seen.
3. **Give kept gear a life** (engravings, titles, slow home repair, a pawn shelf).
4. **Split main.gd** before the next feature.
5. **One rule per setting**, and pair rare settings with rare enemies.
