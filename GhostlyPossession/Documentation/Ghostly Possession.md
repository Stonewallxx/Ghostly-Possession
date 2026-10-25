# Ghostly Possession

Now and then a Ghost possesses one of your team, and some wild Pokémon have a Ghost inside. A possessed Pokémon battles as the fusion of the two (the Ghost is the head, the host is the body) and the Ghost acts on its own at times. Catch a possessed wild Pokémon and keep the Ghost or the Pokémon, or cast the Ghost out to try for both.

It works on its own on KIF Beta. When Kanto Reloaded is installed, it uses Kanto Reloaded's screens and settings instead.

## How It Works

- **The Note:** A possessed Pokémon carries a note: which Ghost, its Will, how long it stays, the battles left, the move slot its move takes. It's plain data, so saves, the PC, the Transfer Box and trades never meet anything of this mod, and saves still load with the mod removed ([Note.rb](../Core/Note.rb)).
- **Only in Battle:** Outside battle the Pokémon stays itself. Each battle turns it into the fusion and back. Screens outside battle draw the possessed look from the note.
- **Shared:** Who is possessed (one at a time), the steps since the last possession, the Channeler, and what waits for the map after a battle (a cast-out Ghost's own battle, the Possessed! card when a Ghost leaps into yours) are kept on the game's own global data the same way, so saving and loading between a battle and the map loses nothing.
- **On Its Own or With Kanto Reloaded:** [KR.rb](../Core/KR.rb) checks at load that Kanto Reloaded booted (mod.json `load_after` makes it load first), and each screen checks again when it opens.

## The Engine and Battles

[Engine.rb](../Core/Engine.rb) turns a possessed Pokémon into the fusion and back; [Battle.rb](../Core/Battle.rb) does it at the right moments:

- **Into the Fusion:** when a battle sets up its sides (`pbSetUpSides`), before it builds its battlers. That covers your own possessed Pokémon (only the ones really in your party) and, in a wild battle, possessed wild ones. The species becomes the Ghost's head on the host's body (`B<host>H<ghost>`; a host that's already a fusion keeps its body). The type and sprite are the fusion's. Its stats are the best of both: each the higher of the host's own and the fusion's, so it's never weaker and is stronger where the Ghost is (the host's worked out by the game's own stat code on a copy of it, so KIF's stat rules all apply; again after a level-up). It's always Ghost first: a Ghost whose first type isn't Ghost (Sableye, Honedge, Rotom...) would give the fusion its other type by KIF's fusion rules, so possession sets Ghost as its first type with KIF's own type override. Its level, EXP, growth, ability, nature, gender and shininess stay its own, and the Ghost's move takes its slot.
- **While It's the Fusion:** it learns its own moves by level and never evolves. A level-up move goes in among its own moves, the Ghost's keeps its slot. It can't Mega Evolve (Megas). The Pokédex learns the host, never the fusion.
- **Back to Itself:** after the battle ends (`pbEndOfBattle`), or if the battle stops early. What the battle did stays: HP as the same share of its total (a fainted Pokémon stays at 0), status, EXP, level-ups, PP, the held item. The Ghost's move's PP goes back into the note; a full PP heal (a Pokémon Center) refills it. Nothing else changes.
- **Autosaves:** held while anything is the fusion, and made once everyone is back and the battle is counted, so a save never holds a fusion.
- **Not in These Battles:** the Bug Contest, recorded and Battle Frontier battles, Self-Battle copies, multiplayer battles. A trainer's Pokémon is never possessed.
- **Nothing of PIF's Fusing Is Used:** no `pbFuse`, no unfusing. The species is changed in place and put back from a snapshot kept in memory only.
- **No Fusing or Unfusing While Possessed** ([Fusing.rb](../Core/Fusing.rb)): a possessed Pokémon can't be fused (either one of the two) or unfused, in the party, the PC (Kanto Reloaded's too) or when fusing a newly caught Pokémon: "A Ghost is inside Pikachu. It can't be unfused while it's possessed." The game's fusing keeps copies of the two halves and gives the copies back when they unfuse, so a Ghost inside would vanish, come back with its count reset, turn up twice or move to the other half. Reversers still work: it's the same Pokémon, and the Ghost stays inside.

## In Battle

While it's the fusion, a possessed Pokémon is marked on PIF's battle screen, and on EBDX's when that's on ([BattleLook.rb](../UI/BattleLook.rb)):

- **The Aura:** a pulsing purple outline round its sprite and a see-through purple double behind it, risen up and swaying, as if the Ghost is half out of it (the Aura setting shows both, or just one). Both are silhouettes of the battler's own picture, so they follow its frame, mirroring, bobbing, EBDX's camera, opacity and visibility.
- **The Mark:** a ghost badge on its databox. On PIF's screen, left of your Pokémon's name and after a foe's; on EBDX's, always left of the name, 4 px clear, following EBDX's shift for a long name. It turns gold when a wild one's grip slips.
- **Its Move:** the Ghost's move has the ghost badge on its button in the Fight menu.
- **Taking Control** ([Control.rb](../Core/Control.rb)): after you've chosen, each turn, a possessed Pokémon that was to use a move may use the Ghost's move instead, by the Ghost's Will (Calm 10%, Normal 20%, Wild 35%). Not when it chose the Ghost's move anyway, nor while it's locked into a move (a two-turn move, Encore, Struggle), nor when the Ghost's move can't be used. Switching, items and running stay yours. As it moves, its sprite flashes purple and the Ghost shows through: "The Gastly inside Pikachu took control!"
- **Its Name:** it keeps its own name in battle (Pikachu, not the fusion's name).

## A Ghost Wanders In

Now and then, as you walk, a Ghost possesses one of your team ([Team.rb](../Core/Team.rb), [Ghosts.rb](../Core/Ghosts.rb)):

- **When:** a chance on each step: 1 in 4000 (Normal) or 2000 (Often), twice that at night and four times that in haunted places (Lavender Town and its houses, the Pokémon Tower, Ecruteak City and Morty's Ghost Gym, the Burned Tower, the Bell Tower, the Hidden Tomb, the Pokémon Mansion, and the dark places: Dark Cave, the Moonlit Forest, the Ruins of Alph, the Sinjoh Ruins). None for 500 steps after the last possession ended (and from the start), and none while anyone is possessed: one at a time, even in the PC or the Day Care. A possessed Pokémon that's released or traded away lets go.
- **Only on a Quiet Step:** on the map, with no event running, no message, menu, transfer or fade, not sliding, not in the Safari Zone or the Bug Contest, not on an autosave step. That step starts no wild battle.
- **Which Ghost:** one of this area's own wild Ghosts in any kind of encounter (Classic, Remix or randomized), else one from the classic list, which grows with your badges (Gastly; then Misdreavus, Duskull, Shuppet, Drifloon at 2; Litwick, Yamask, Phantump, Pumpkaboo, Sableye at 4; Spiritomb, Honedge, Golett, Sandygast, Rotom, Mimikyu, Dhelmise, Froslass, Oricorio (Sensu) at 6). On the list the Gastly line counts three times, every other line once. Never a legendary or Shedinja. It comes at the host's level, as the stage that suits it: from its first stage up, a level evolution at its level, any other kind from level 40 unless KIF gives it a level too.
- **Its Move:** the newest Ghost-type attack it knows at that level (its earlier stages' too, up to when they evolved) that the host doesn't know; else a Ghost-type move of any kind; else Lick or the like. It takes a random move slot (an empty one while the host has fewer than four moves).
- **Which Teammate:** any that can still battle, not an Egg, not a Ghost (by type, so a fusion with a Ghost half too), not a triple fusion or a Shadow Pokémon. Fusions can be: the Ghost takes the head's place.
- **Its Will and Stay:** rolled 30 / 50 / 20 (Calm / Normal / Wild; 5 / 10 / 15 battles).
- **Possessed!:** the screen chills, the Ghost drifts down into you and sinks in with a glow ([Moment.rb](../UI/Moment.rb)). Then, on its own, the game's message under a window in your menu frame: the Pokémon + the Ghost -> the fusion, their names under them ([Alone.rb](../UI/Alone.rb)). With Kanto Reloaded, a purple card in its notice look: before and after with the Ghost over three chevrons between, the new types, what it means ([Card.rb](../UI/Card.rb)). The chill lifts after. Nothing saved is touched by the moment: it's sprites only.
- **The Debug Menu:** with KIF's Debug option, Ghostly Possession... in the Debug menu: Possess on the Next Step (no chance, no wait, even with Team Possession Off), Leave After the Next Battle, Get a Cleanse Tag, Haunt the Next Wild Pokémon (see Haunted Wilds), and Clear Possession ([Debug.rb](../Core/Debug.rb)).

## Party Look and Possession Info

A possessed Pokémon shows as the fusion on the party screen, drawn from its note ([PartyLook.rb](../UI/PartyLook.rb)):

- **On Its Own:** the game's party panel shows the fusion's icon (Big Pokémon Icons too), its Poké Ball turns ghost purple (shading kept; hidden anyway with Big Pokémon Icons) and its name lavender.
- **With Kanto Reloaded:** its Party Screen shows the fusion's icon and types (the card is purple: the fusion is Ghost first), a dashed purple outline and a ghost badge on the card; the details show the Ghost's picture and name, top right.
- **In the PC** ([PCLook.rb](../UI/PCLook.rb)): the fusion's icon with the battle's ghost badge in its slot's corner, wherever its icon shows: the boxes, the party column or row, held in the hand. On its own, the side panel shows its name lavender, the fusion's picture and Ghost-first types, and the Ghost small in the picture's corner. With Kanto Reloaded's Reloaded PC, the plate is lit ghost purple with the Party Screen's dashed outline, the fusion's picture, and the Ghost and its name top right; Compare shows the fusion's picture and types, and the badge after its name.
- **Its Summary** ([SummaryLook.rb](../UI/SummaryLook.rb)) shows it as it is in battle: the fusion's picture, species and Ghost-first types (the Info page's Head and Body rows say which), its stats as possession makes them, and the Ghost's move in its slot. The Ghost is small in the picture's corner, the name lavender with the ghost badge, and what possession changes is ghost purple: each stat it raises and that stat's base, and the Ghost's move with the badge (its details too, when you pick it). Its name, level, nature, IVs, EVs, ability, item and Exp stay its own. Only the drawing sees the fusion: reordering moves and the Summary's other actions keep the Pokémon itself, and learning a move shows its own moves, the one you'd replace.

Its party menu has **Possession** ([Info.rb](../UI/Info.rb)): which Ghost is inside, its Will and how long it'll stay as hints (Will: "It's quiet." / "It stirs now and then." / "It's restless."; Stay, by the battles left: "It's settling in." / "It'll stay a while." / "It won't stay long."), and its move.

- **On Its Own:** after Summary in the game's list (not in battle), then a window in your menu frame over the screen's own message.
- **With Kanto Reloaded:** a command in its Party Screen's menu, then a popup: the Ghost on a purple disc, WILL, STAY, ITS MOVE, and what happens when it leaves.
- **Cast It Out:** with Kanto Reloaded, a button in the popup ("Uses 1 Cleanse Tag (you have 2)" in green, red with none); on its own, "Use a Cleanse Tag to cast it out? You have 2." Yes or No. Then the party screen and the menu close themselves and it happens on the map.

## With Kanto Reloaded: the Overworld Menu and Bug Reports

- **The Possession Readout:** a readout for Kanto Reloaded's Overworld Menu ([Readout.rb](../UI/Readout.rb)): the possessed teammate's name, and a purple pill with its Ghost and roughly how long it'll stay ("GASTLY: A WHILE"; Not Long / A While / Settling In, as the Stay hint). Shown only while one of your team is possessed. Like every readout it starts on no page: put it on one with Edit Pages. A shows the Possession popup over the menu (with its own hints); Cast It Out closes the menu and it happens on the map.
- **Party View:** in the Overworld Menu's Party View, a possessed one's card shows as on the Party Screen ([PartyLook.rb](../UI/PartyLook.rb)): the fusion's picture (Full: its battle sprite; Compact: its icon), Ghost-first types, the card lit ghost purple (its fill and edge) with the Party Screen's dashed purple outline inside (on a Compact card, close to its edge, clear of the name and under the HP bar), and on a Full card the ghost mark by its level. Its name stays its own.
- **Recent Steps:** every line of this mod's log (possessions, Ghosts leaving or cast out, wild ones with a Ghost inside, Keep Which?, the Leap, anything that failed) is also a note in Kanto Reloaded's Bug Report Recent Steps (a line the same as the last isn't noted again).

## Leaving and Casting Out

A Ghost stays for a number of battles, then leaves by itself; a Cleanse Tag or the Channeler casts it out sooner ([Leave.rb](../Core/Leave.rb)).

- **Battles Count Down:** after each battle the possessed Pokémon took part in (sent out at least once), one fewer. Nothing counts while it's in the PC or the Day Care, or in battles that aren't really yours.
- **It Leaves:** back on the map, once nothing else is going on (no menu, message, event or walking), the Ghost rises out of you. Most of the time it fades away: The Gastly Left. 20% of the time it lingers, hovering: The Gastly Lingers!, then its own wild battle.
- **Cast Out:** a cold white flash and the Ghost torn out above you, then Cast Out! and always its own wild battle.
- **The Ghost's Battle:** the Ghost at the Pokémon's level, wild, to catch.
- **With KIF's Nuzlocke:** the Ghost can't be caught. It still fights, Poké Balls are blocked ("Nuzlocke: The Gastly can't be caught."), the route's encounter isn't used up, and the cards and messages say it wants to fight instead of "yours to catch". A shiny Ghost follows KIF's Shiny Clause: with it On, it can be caught.
- **Afterwards:** the Pokémon is itself again (its own move back too), nobody is possessed, and the 500 quiet steps start over.
- **The Looks:** with Kanto Reloaded, cards like Possessed!: The Gastly Left (purple), The Gastly Lingers! and Cast Out! (gold, Battle!). On its own, the game's messages.

### The Cleanse Tag

The game's Cleanse Tag still keeps wild Pokémon away when the lead holds it, and now casts a Ghost out ([CleanseTag.rb](../Core/CleanseTag.rb)):

- **From the Bag:** Use, a yes or no, then the Bag and the menus close and it happens on the map.
- **From the Possession Popup:** Cast It Out (above).
- **In Battle:** on a possessed wild Pokémon whose Ghost's grip is slipping (see Haunted Wilds).
- **Lavender Town's Poké Mart** sells it at 1,000 (the game's price is 5,000). The Channeler gives the first one.
- Only how the game sees the item changes (usable from the Bag, and in battle on a foe; its description); its data isn't changed.

### The Channeler

A Channeler in Lavender Town's Volunteer House (Mr. Fuji's, map 418), in the corner by the cribs (13, 10), facing left; free ([Channeler.rb](../Core/Channeler.rb)). Added with KIF's map patches as the map loads, so the map's file isn't changed.

- With a possessed Pokémon with you: "I sense a Gastly inside your Pikachu... Shall I set it free?" Yes casts it out.
- The first time she gives a Cleanse Tag.
- Her event only calls in if Ghostly Possession is there, so a save still loads with the mod removed.

## Haunted Wilds

Some wild Pokémon have a Ghost inside ([Wilds.rb](../Core/Wilds.rb), [WildBattle.rb](../Core/WildBattle.rb)).

- **Which Encounters:** a random one: walking in grass, a cave or on water, or fishing. Never an event's battle (legendaries, statics, Headbutt, Rock Smash), a roamer, a Poké Radar chain, the Safari Zone or the Bug Contest.
- **Alone Only:** only a lone wild Pokémon, never one in a double, a 1v2 or 1v3, or a Horde.
- **Never Both:** with Alpha Encounters, an alpha is never possessed.
- **How Often:** 1 in 100 encounters (Normal) or 1 in 50 (Often), twice that at night and four times that in the haunted places.
- **The Host and the Ghost:** as for your team: any wild Pokémon that isn't a Ghost (fusions too), with this area's own Ghost or one from the classic list, at its level.
- **When:** rolled as the battle starts, before KIF's Nuzlocke judges the encounter.
- **In Battle:** it's the fusion with the aura and the ghost mark, and the intro says "A possessed Rattata appeared!" ("The possessed Rattata was caught off guard!").
- **Keep Which?:** Poké Balls work on it. Where the game would ask for a nickname, you keep the host or the Ghost, and the other goes free ("The Gastly drifted away." / "The Rattata ran off."). With Kanto Reloaded, the Keep Which? card: both Pokémon with the ball between, the chosen one on the disc, Keep Rattata / Keep Gastly, and B doesn't close it. On its own, a window up top (the Rattata "or" the Gastly) over the battle's question and its choice list ([Keep.rb](../UI/Keep.rb)). A kept Ghost is a new Pokémon at the host's level (the stage that suits it, its shininess) in the same ball. Both are seen in the Pokédex.
- **With KIF's Nuzlocke:** the kept one is the route's catch. With the Dupes Clause, a line you have already can't be kept (dimmed on the card; on its own, "Nuzlocke: You already have the Rattata's line."), and the encounter counts if either line is new.
- **The Slip:** in the red (a quarter of its HP), the Ghost's grip slips: the mark turns gold, the aura thins, and once a battle, "The Gastly's grip is slipping! Cast it out: Dark or Ghost moves, or a Cleanse Tag."
- **Casting Out in Battle:** a Dark- or Ghost-type hit that leaves it in the red (once that turn is over), or a Cleanse Tag from the battle's Bag (in EBDX's, under Battle Items; aimed at it like a Poké Ball, used up; before the red, "The Gastly's grip is still too strong."). A cold white light, the Ghost rises out of it and away, and it's itself again as it is: "The Gastly burst out of Rattata and fled! Rattata is itself again: Catch it!" It holds a Cleanse Tag 10% of the time. Its move that turn is its own move in that slot.
- **The Ghost's Own Battle:** after the battle (won, run from or caught), on the map, the Ghost at the host's level: "The angry Gastly came back to fight! Catch it while you can!" With KIF's Nuzlocke it can't be caught ("The angry Gastly came back to fight!"), and a freed host whose line you have is a dupe again.
- **The Leap:** knock it out with the Ghost still in, and half the time the angry Ghost leaps into your Pokémon that knocked it out (else another of yours in the battle that may be possessed), with Team Possession On and nobody possessed yet: "Its angry Gastly leaped at Pikachu!", the Gastly rises out of the fainted one's place and leaps across in an arc with a faint purple trail, a purple flash as it goes in, Pikachu is the fusion, "The Gastly possessed Pikachu!". After the battle, on the map, the Possessed! card telling how ("When Rattata fainted, its angry Gastly leaped into Pikachu..."; on its own, "Rattata's Gastly leaped into Pikachu!"), with no chill. It's the same Ghost; its move, Will and stay are rolled as for one that wanders in, and that battle doesn't count down its stay. Otherwise: "The Gastly inside it slipped away..."
- **The Debug Menu:** Haunt the Next Wild Pokémon (no chance, any kind of battle, even with Haunted Wilds Off).

### With Hoenn Overworld Encounters

Its wild Pokémon walk the routes, and grass steps there start no battles, so Haunted Wilds happen on the map ([Compat.rb](../Core/Compat.rb), [MapAura.rb](../UI/MapAura.rb)).

- **At Spawn:** its route, cave and surf spawns roll as an encounter does (not its town wildlife or water, Poké Radar patches, alphas, or the disguised Ditto, Mew, Zorua and Zoroark).
- **On the Map:** the battle's aura, Outline and Echo (the Aura setting picks both or one): purple silhouettes a pixel round it and a see-through double risen beside it.
- **Flickers:** it roams as its kind, but now and then fades slowly out, stays gone a moment, and fades back in two or three tiles away, on its own kind of ground. Never while you're within two tiles, once it's noticed you, while a battle's gathering, or when it's about to fuse.
- **Alone Only:** its battle is always one on one: it never joins another's battle, and none join its battle. After any wild battle, the walking wilds wait a second before starting another.
- **Fusing on the Map:** if one of two walking wilds that fuse has a Ghost inside, the new one keeps it (its move and slot fit the new host). Two possessed never fuse.

### With Alpha Encounters

- **Never Both:** a wild alpha is never possessed, and Hordes never have one.
- **One That Turns Alpha:** a possessed walking wild can still turn alpha as its battle starts. It stays both: in battle only the Echo shows (no outline), and caught, you keep the alpha and the Ghost goes free (no Keep Which?).
- **The Ghost's Own Battle:** it can turn alpha, as any wild battle can.
- **Load Order:** this mod loads after both mods (mod.json), so it can hook their parts.

## Will-o'-Wisp Trails

Any night, all year, with no setting, a will-o'-wisp may appear and lead you somewhere ([Wisps.rb](../Core/Wisps.rb), [WispLook.rb](../UI/WispLook.rb)).

- **When:** on a quiet step at night, on routes, in caves and in haunted places, never on dark maps or where there's little room to walk. It's 1 in 5,000 steps, twice that in haunted places, one at a time, then 300 steps before the next. It takes the step, so no battle starts on it.
- **The Wisp:** a soft light-purple flame with two tiny motes circling it, the far one passing under it, glowing (added light) and never night-tinted. It appears 5 or 6 tiles ahead with a chime (`PRSFX- Confuse Ray`). With Kanto Reloaded, a toast: "A strange light flickers nearby..." with its flame.
- **The Trail:** come within 4 tiles and it fades slowly away, about a second and a half, while its two motes leave it and fly on along the trail, bigger and brighter with short tails, showing the way. It reappears 10 to 14 tiles further on from where you are, on a spot you can walk to, even off screen: follow its motes. Starting near your map's edge, its trail may lead you onto the map connected there (one connection, one the game has in view), and its end is always well in from that map's edges. It makes 2 to 4 hops, then sinks into the ground at the trail's end. Walk more than 22 tiles from it, leave its maps, let the night end, or leave it waiting an in-game hour at a spot (a real minute on the map, battles and menus aside), and it's lost.
- **The Ends:**
  - **A Treasure (55%):** an item ball with the wisp's glow and motes. Mostly ghostly items (Spell Tag, Reaper Cloth, Dusk Stone, Spooky Plate), often ghost-hunting gear (a Cleanse Tag, 3 Dusk Balls), sometimes valuables (Nugget, Star Piece, Big Pearl), and now and then a rare find (Rare Candy, PP Up, very rarely an Ability Capsule). It's gone by morning, and it's lifted out of every save, then put back.
  - **A Possessed Wild (30%):** one of the map's own Pokémon with a Ghost inside, battled there. With Hoenn Overworld Encounters it appears there as a walker instead.
  - **A Possession (10%):** a Ghost possesses one of your team, when Team Possession is on and nobody is possessed.
  - **A Grave (5%):** a Nuzlocke grave (Restless Spirits, below).
  - An end that can't happen becomes a treasure.
- **With Light Patches:** the wisp and the trail's ball each light their own patch.
- **Debug:** A Will-o'-Wisp on the Next Step, and A Will-o'-Wisp Ending In...

## Restless Spirits

In KIF's Nuzlocke, now and then a will-o'-wisp's trail ends at the grave of one of the run's fallen ([Spirits.rb](../Core/Spirits.rb), [SpiritLook.rb](../UI/SpiritLook.rb)). With the Restless Spirits setting On.

- **Whose:** a Pokémon that died in the run and is no longer with you (sent to KIF's Graveyard, or released), while the run hasn't ended. With "stays fainted", the body keeps its spirit, so no grave.
- **How Often:** 1 in 20 wisp trails, only while one of the fallen is waiting.
- **Where:** one that died on this map, or one joined to it, comes first. For a Gym or a building, the maps round its town count. Else any of the fallen.
- **The Grave:** a small headstone with the treasure ball's glow and motes, waiting where the wisp sank until morning. With Light Patches it lights its own patch.
- **Reading It:** A on the grave. With Kanto Reloaded, the Memorial Card: "Here Lies Sparky", its faded picture, its kind and level, where it fell, then Call Its Spirit or Pay Respects. B closes it and the grave keeps waiting. On its own, the game's message with its faded picture, then the same choice.
- **One Chance:** once its spirit has risen, whatever happens, its grave never shows again.
- **Pay Respects:** its spirit rises from the grave and drifts up into sparks: laid to rest, and it leaves a gift.
- **Call Its Spirit:** its spirit rises and battles you as a Ghost fusion: its own body (a fusion's body half), a Ghost's head that suits its level, its name. It's see-through and lilac, with a Restless count under its HP bar.
  - **Restless:** after 5 turns it fades away and the battle ends, as if you ran.
  - **Beat It:** laid to rest, and it leaves a gift.
  - **Catch It:** it comes back to you: "Sparky Came Back!", old and new side by side. It keeps all it can (nickname, Trainer, nature, IVs, EVs, shininess; its gender, ability and moves where its new form can have them, else the same ability slot) and leaves KIF's Graveyard (the death record stays). It doesn't use up the Nuzlocke's encounter there. It stays a Ghost: it can't be unfused ("Sparky's spirit is bound to its Ghost. It can't be unfused.").
  - **A Spirit, Not a Wild:** never an alpha, never a Haunted Wild, no nickname to ask for, never handed to a partner.
- **The Gift:** its held item if the Graveyard kept it, else a treasure, with a rare find twice as likely. With a full Bag, it's sent to your PC.
- **Debug:** A Grave Here (one of the fallen, else your lead Pokémon's spirit, to try it out).

## On KIF's Title

With KIF 1.2's Living title, now and then one of the Pokémon walking KIF's world has a Ghost inside, drawn in the Outline and Echo look (the Aura setting picks both or one) ([TitleLook.rb](../UI/TitleLook.rb)). Walkers only, never one Kanto Reloaded made an Alpha, with or without Kanto Reloaded.

## Nights

The nights' darkness and their lights, on their own: Darkness, Town Lights and Light Patches work with the Spooky Season On or Off.

### The Night

With a Darkness, nights on outdoor maps turn violet and darker than KIF's own ([Season.rb](../Core/Season.rb)). Each is the lit night, Tone(-114, -166, -70, 120), with its own dark over it, taken off away from lights:

| Darkness | Away From Lights |
|---|---|
| Off | KIF's own nights, untouched |
| Deepest Violet (a new save's) | 30 off |
| Midnight Violet | 48 off |
| Pitch Black | 71 off (28% of white), with light round you |

- **When:** KIF's own evening until 8 pm, halfway at 9 pm, the season's night from 10 pm to 3 am, halfway at 4 am, and KIF's morning from 5. The game blends minute by minute between hours (`PBDayNight.getToneInternal`).
- **EBDX:** the battle backdrops take each Darkness's shade as a plain tone (`BattleSceneRoom#daylightTint`). Pitch Black battles are Midnight Violet's.
- **The Darkrai darkness** still wins: while it's on, nothing here changes. Caves keep their own darkness.

### Light Patches

With Light Patches On (a new save's), every light lifts the dark round it back to the lit night ([SeasonDark.rb](../UI/SeasonDark.rb)): the map's own lamps (its `OutdoorLight` and `Light` events), Town Lights' panes, doors and lamps, the lighthouses' beams, and anything that gives light: `Season.light(:wisp) { [screen_x, screen_y, radius] }`, and `Season.unlight(:wisp)`. Self gives you a light of your own instead, 96 px round you, and On + Self gives both. Off, Deepest Violet and Midnight Violet are their shade as one even tone, and Pitch Black, which always has the light round you, keeps only that.

- **How:** a subtracting sprite over the scene, white where it's dark, with a soft black stamp at each light, at each Darkness's depth (`Season::DARK`; Pitch Black's `SeasonDark::DEPTH`). Each frame is one fill and a stamp per light.
- **When:** it fades in from 9 pm and out at 4 am, with the night.

### Pitch Black

The caves' darkness brought outdoors at night, with more room and drawn smooth:

- **Round You:** 96 px; after Flash or KIF's Lantern, 176 px, as in caves. While it's up it is the game's darkness sprite, so Flash and the Lantern work with the game's own code, and Flash may be used there. A Flash lasts until you leave the map, after battles too.
- **How Dark:** not quite black: away from the lights you can still make out roofs, trees and paths in deep blue.

### Town Lights

With Town Lights On and Darkness on Deepest Violet or darker, from 9 pm to 4:30 am, towns and routes light up ([TownLights.rb](../UI/TownLights.rb)). Only the glow: no light-source shapes, so no dot on the lamps and no doorway-sized blocks.

- **Lit Fixtures:** the windows' and glass doors' own panes and the lamps' own bulbs glow. They're about two-thirds lit and look the same on any Darkness (as on Deepest Violet).
- **Which Buildings:** houses (their doors' windows too), Marts (their doors and the MART letters too), Saffron's blocks, Celadon's brownstones and Department Store, the Pokémon Centers (each pane a cool white, their sign unlit), the Gyms (their windows, glass tops and glass doors; the door's frame, handle and foot stay white), Goldenrod's office blocks and Radio Tower, Silph Co. (its glass doors too), the Pokémon Mansion, Johto's wooden houses and pagodas, Vermilion's port and orange houses, the Seagallop harbors and the Power Plant, the pink and teal houses, the S.S. Anne (its cabin windows, portholes, the curved band of its bridge's windows and its front window), Lavender's Pokémon Tower, and the lighthouses.
- **The Pokémon Tower:** its eight bands of slits and the four windows at its base glow a ghostly green, and so does their light. The slits are high up, so they light only the tower's wall; the base windows light the ground in front too.
- **The Lighthouses:** Olivine's Glitter Lighthouse, its twin on Cerulean Cape and Cianwood's lighthouse shine a bright, near-white beacon: their lantern's panes (Cianwood's dark gallery band) light up as brightly as a lamp's bulb, and a steady light spreads about four tiles round from the lantern. Cianwood's two portholes light their wall.
- **The Torch Pillar:** Route 34's torch pillar burns at night: its flame in its own fire colours (not the gold bowl or the pillar), and a warm light about four tiles round it that flickers like fire. With Light Patches its patch of light flickers with it. (Sinjoh Ruins' two aren't on an outdoor map, so they stay as they are.)
- **The Beam:** a soft beam turns round each lantern, a full turn every 8 seconds, fading in from the lantern and out at its end. It leaves the panes: turning away it passes behind the roof, turning toward you it crosses in front of the tower. With Light Patches it lifts the dark where it falls.
- **Ground Light:** each window's and door's light on the ground: a soft oval at its foot that fans out as it fades, the way the glass faces (a Pokémon Center's curved glass to its side), on open ground only, never over a building. The panes light their wall a little. A window high on a tall building has no ground near it, so only its wall glows. The Pokémon Centers' light is cool and brighter, and their upper band lights the building round it.
- **Next Door:** a map connected to yours lights up as it comes into view: Viridian's arch and lamps from Route 1, a town's windows from the route outside it. Its patches lift the dark too, and KIF's own lamp glow is hidden there.
- **No Stacking:** where lights overlap, the brightest shows, not their sum, and a lamp's light wins over the others under it.
- **Lamps:** an area light about four tiles round each, for the map's light events and the lamps drawn in its tiles (a lantern arch, or a lamp two tiles wide, is one light). Each lamp's own head lights up: the orange lamps, Pewter's twin lanterns, the globe lamps and the lanterns of Olivine's and Celadon's arches. KIF's own lamp glow is hidden while it's on.
- **With Light Patches:** every lit pane lifts its own patch of the dark, sized by the pane (a porthole a small one, a big window or a glass top a bigger one), upper storeys too; so does every door and lamp, and each ground light where it falls.
- **Where:** 87 outdoor maps (towns, and the routes with lamps or gatehouses), with 2,733 windows, 304 doors and 128 lamps.

The lights come with the mod, worked out ahead of time, so the game only shows them: three pictures per map, the lit pixels (`Graphics/GhostlyPossession/TownLights/MapNNN.png`), the glow (`MapNNNg.png`, made at half size, shown at twice that and added over the scene) and the light patches (`MapNNNh.png`, half size, laid into the dark in one go), in their own folder so no other mod's files can clash, and where each light and patch is (`Data/town_lights.json`).

## The Spooky Season

Halloween in the game this year: Ghostly Possession is the one-off Halloween mod for now (Kanto Reloaded runs the seasons later). It's on with the Spooky Season setting.

### Fog, Music, a Hat and Night Ghosts

All with Spooky Season On ([SeasonExtras.rb](../Core/SeasonExtras.rb)):

- **Fog:** at night in the haunted places (Lavender Town, the Pokémon Tower, the Pokémon Mansion, Ecruteak's Burned and Bell Towers). It's the game's own fog picture, thin and shaded grey-violet (the game doesn't tint fog at night), drifting slowly and fading in and out with the night. Never over a map's own weather (Lavender's rain). It's its own layer, never the map's saved fog.
- **Haunted Music** (its own row): on routes at night, one of Lavender Town, the Pokémon Tower remix, the Strange House or the Mansion remix, a different one each night. Night coming or going while you're on the route swaps it within a second. Towns and places with their own themes keep them, and only the map's own music is ever swapped: never a battle's, an event's or a rival's.
- **The Witchy Hat:** on 31 October, the Poké Mart clerk hands it to you once, as PIF's clerk hands out the Santa hat at Christmas (`give_date_specific_hats`).
- **The Clerks Wear It** ([ClerkHat.rb](../UI/ClerkHat.rb)): all Spooky Season, the Poké Mart clerks in the green apron wear the Witchy Hat: the game's own hat art, turning as they turn. Only clerks running a Mart (the shop, or the game's PokéMart common event), and not the clerk who hands the hats out, who keeps her own blue hat. The maps and the clerks' pictures aren't changed.
- **Night Ghosts:** at night on routes and in caves, 1 in 10 encounters is a Ghost instead. It's the area's own Ghost, else a classic one by your badges, at the stage that suits the encounter's level. Not with the Poké Radar, in the Safari Zone or the Bug Contest.

### Debug

Ghostly Possession's Debug menu has Night Now (11 pm), Evening Now (8 pm) and Morning Now (7 am). They move the game's clock (`UnrealTime.advance_to`) and update the map at once.

## Settings

As KIF settings, so they survive the mod being removed and added again ([Settings.rb](../Core/Settings.rb)): all per save but the Aura (how a possessed Pokémon looks in battle), which is for all saves.

| Setting | Values | Default |
|---|---|---|
| Team Possession | Off / On | On |
| How Often | Normal / Often | Normal |
| Haunted Wilds | Off / On | On |
| How Often | Normal / Often | Normal |
| Restless Spirits | Off / On | On |
| Aura | Both / Outline / Echo | Both |
| Darkness | Off / Deepest Violet / Midnight Violet / Pitch Black | Deepest Violet |
| Town Lights | Off / On | On |
| Light Patches | Off / Self / On / On + Self | On |
| Spooky Season | Off / On | On |
| Haunted Music | Off / On | On |

- **On Its Own:** a Ghostly Possession heading in KIF Settings' Pokémon section, after Fusion, then Nights and Spooky Season headings. Each How Often is hidden while its switch is Off, Town Lights and Light Patches while Darkness is Off, and Haunted Music while Spooky Season is Off.
- **With Kanto Reloaded:** its own Ghostly Possession section in the Kanto Reloaded section, with Ghostly Possession, Nights and Spooky Season headers and all eleven rows. Kanto Reloaded reads and writes the same values, and each child row is locked until its switch is On.
- **At Once:** changing Darkness or Light Patches changes the night straight away.

## The Numbers

The defaults; each is one constant in the file named.

| What | Now | Where |
|---|---|---|
| A Ghost possesses your team | 1 in 4,000 steps (Often: 2,000) | `Team::RATES` ([Team.rb](../Core/Team.rb)) |
| ...at night / in haunted places | ×2 / ×4 (both: ×8) | `Team::NIGHT`, `Team::HAUNTED`, `Team::HAUNTED_MAPS` |
| ...none after one ends for | 500 steps | `Team::COOLDOWN` |
| A wild one has a Ghost inside | 1 in 100 encounters (Often: 50); the same boosts; with Hoenn Overworld Encounters, per spawn | `Wilds::RATES` ([Wilds.rb](../Core/Wilds.rb)) |
| How long it stays | 5 / 10 / 15 battles (Short / Normal / Long); the Stay hint: up to 5 left "won't stay long", up to 10 "a while", 11 or more "settling in" | `Ghosts::STAY_BATTLES`, `Ghosts::STAY_HINTS` ([Ghosts.rb](../Core/Ghosts.rb)) |
| The Ghost takes control | 10 / 20 / 35% of turns (Calm / Normal / Wild) | `Control::WILL_CHANCE` ([Control.rb](../Core/Control.rb)) |
| Will and Stay rolled | 30 / 50 / 20% | `Ghosts::ROLL` |
| A stone or trade evolution counts from | level 40 | `Ghosts::OTHER_EVOLUTION_LEVEL` |
| It lingers to fight when it leaves by itself | 20% | `Leave::LINGER` ([Leave.rb](../Core/Leave.rb)) |
| Its grip slips (the cast-out window) | a quarter of its HP | `WildBattle::SLIP` ([WildBattle.rb](../Core/WildBattle.rb)) |
| The Leap | 50% | `WildBattle::LEAP_CHANCE` |
| A freed host holds a Cleanse Tag | 10% | `WildBattle::TAG_CHANCE` |
| The Cleanse Tag at Lavender's Mart | 1,000 | `CleanseTag::PRICE` ([CleanseTag.rb](../Core/CleanseTag.rb)) |
| A walking wild flickers every | 5 to 10 seconds (never within 2 tiles of you; 2 or 3 tiles away), fading out and in over 30 frames, gone 45 frames between | `Compat::FLICKER_*` ([Compat.rb](../Core/Compat.rb)) |
| The walking wilds wait after a battle | a second | `Compat::HOLD` |
| A will-o'-wisp appears | 1 in 5,000 quiet steps at night (×2 in haunted places), then 300 steps before the next | `Wisps::RATE`, `Wisps::HAUNTED`, `Wisps::COOLDOWN` ([Wisps.rb](../Core/Wisps.rb)) |
| Its trail | 2 to 4 hops of 10 to 14 tiles (on screen or not); fades away over 60 frames, in over 16; lost 22 tiles away, or after waiting an in-game hour (2,400 steps of map time) at a spot | `Wisps::HOPS`, `Wisps::HOP`, `Wisps::FADE_OUT`, `Wisps::FADE_IN`, `Wisps::LOST`, `Wisps::WAIT` |
| A night encounter is a Ghost (Spooky Season) | 1 in 10, on routes and in caves | `SeasonExtras::GHOST_CHANCE` ([SeasonExtras.rb](../Core/SeasonExtras.rb)) |
| The haunted places' fog | about 0.42 opacity, shaded (150, 140, 178) | `SeasonExtras::FOG_OPACITY`, `FOG_TONE`, `FOG_MAPS` |
| Town Lights' hours | 9 pm to 4:30 am, fading in and out over 20 frames | `TownLights.hours_on?`, `TownLights::FADE` ([TownLights.rb](../UI/TownLights.rb)) |
| A lamp's light | about four tiles round (128 px) | in the glow pictures |
| A window's ground light / a door's | a soft oval at the foot fanning out over 46 / 50 px, 20 to 64 / 26 to 72 px wide, strength 0.21 / 0.26 (a Pokémon Center's 2.6 times) | in the glow pictures |
| How lit the fixtures are | panes 170/255 amber, bulbs 215/255 | in the lit pictures |
| Its light patches | lamp 110, door 56, ground light 40 px, each lit pane by its size (12 to 90 px) | in the patches pictures |
| Its ends | Treasure 55 / Possessed Wild 30 / Possession 10 / Grave 5 | `Wisps::ENDS`; the treasure's items and weights in `Wisps::GHOSTLY`, `GEAR`, `VALUABLES`, `RARE` |
| A restless spirit stays | 5 turns | `Spirits::TURNS` ([Spirits.rb](../Core/Spirits.rb)) |
| Its gift's rare find | twice as likely | `Spirits::RARE` |

## Files

- `main.rb`: loads the files in `FILES`, then boots `SYSTEMS`. A file that fails is logged (`[Ghostly Possession]` in KIF's log) and skipped.
- `Core/`: [KR.rb](../Core/KR.rb), [Note.rb](../Core/Note.rb), [Settings.rb](../Core/Settings.rb), [Engine.rb](../Core/Engine.rb), [Battle.rb](../Core/Battle.rb), [Control.rb](../Core/Control.rb), [Ghosts.rb](../Core/Ghosts.rb), [Team.rb](../Core/Team.rb), [Wilds.rb](../Core/Wilds.rb), [Leave.rb](../Core/Leave.rb), [WildBattle.rb](../Core/WildBattle.rb), [CleanseTag.rb](../Core/CleanseTag.rb), [Channeler.rb](../Core/Channeler.rb), [Compat.rb](../Core/Compat.rb) (other mods), [Season.rb](../Core/Season.rb) (the Spooky Season's night), [SeasonExtras.rb](../Core/SeasonExtras.rb) (its fog, music, hat and night Ghosts), [Debug.rb](../Core/Debug.rb), [Wisps.rb](../Core/Wisps.rb) (will-o'-wisp trails), [Spirits.rb](../Core/Spirits.rb) (Restless Spirits), [Fusing.rb](../Core/Fusing.rb) (no fusing or unfusing while possessed).
- `UI/`: [Shapes.rb](../UI/Shapes.rb) (the arrow, chevron and plus), [Moment.rb](../UI/Moment.rb) (the chill on the map), [Alone.rb](../UI/Alone.rb) (the game's own windows), [Card.rb](../UI/Card.rb) (Kanto Reloaded's card), [Keep.rb](../UI/Keep.rb) (Keep Which?), [Possessed.rb](../UI/Possessed.rb) (what's said, in either look), [PartyLook.rb](../UI/PartyLook.rb) (the party screens), [PCLook.rb](../UI/PCLook.rb) (the PC), [SummaryLook.rb](../UI/SummaryLook.rb) (the Summary), [Info.rb](../UI/Info.rb) (the Possession command), [BattleLook.rb](../UI/BattleLook.rb) (the battle screen), [MapAura.rb](../UI/MapAura.rb) (a walking wild on the map), [ClerkHat.rb](../UI/ClerkHat.rb) (the Mart clerks' Witchy Hat), [WispLook.rb](../UI/WispLook.rb) (the wisp and its ball), [SpiritLook.rb](../UI/SpiritLook.rb) (the grave, the Memorial Card, the spirit), [SeasonDark.rb](../UI/SeasonDark.rb) (Pitch Black), [TownLights.rb](../UI/TownLights.rb) (the town lights), [Readout.rb](../UI/Readout.rb) (the Overworld Menu readout), [TitleLook.rb](../UI/TitleLook.rb) (KIF's Living title).
- `Data/town_lights.json` and `Graphics/GhostlyPossession/TownLights/`: the town lights' spots and lit pictures.
- `Documentation/Changelogs/`: each version's changelog ([v1.0.0.md](Changelogs/v1.0.0.md) and on), which Kanto Reloaded's What's New shows.
