# PhantomUI – Changelog

## 0.9.93
- Party frames show your ally's level in front of the name.
- Fixed: totems and your ally's pets flashed a health bar for a moment when they appeared – friendly plates other than your ally are now hidden the instant they show.

## 0.9.92 (co-op)
- **Party frames** for the new co-op mode: your allies with their name in class colour, health bar and percent (dead/offline shown), click to target, tooltip on mouseover. Movable and resizable in anchor mode (*Party*), on/off under `/pui` → General.
- **Ally nameplate:** in a party, only your ally gets a friendly nameplate, in their class colour; other friendly plates (NPCs, pets) stay hidden. On/off under `/pui` → General.

## 0.9.91
- Boss bars: every boss and guardian shows its debuffs (your DoTs and more) right of its bar, with stacks and a tooltip on mouseover (name, stacks, time left) – for all bosses at once.
- Click a boss bar to target that boss.

## 0.9.90
- Buffs: the classic client's clock model kept turning around the wrong point after resizing, so buffs now show their own run-down instead – a dark shade grows down over the icon as the time passes, always exactly on the icon at any size. The seconds stay as they were.

## 0.9.89
- Buffs: after resizing the buffs the clock sweep turned around the wrong point; the clocks are now rebuilt whenever the size changes.

## 0.9.88
- Buffs: the clock sweep sat off-centre after a new run or loading screen; it is now laid exactly on the icon and rebuilt fresh at every new run.

## 0.9.87
- Damage meter: summons have their icon in every language – Treant, Spirit Wolf, Water Elemental, hunter wolf and raptor and every warlock demon (Treant had none before). A summon's icon from the game is only used if it really is an icon.

## 0.9.86
- Removed the abilities at your hero again (the action bar is unchanged).

## 0.9.85
- Abilities at your hero: after a new run or a loading screen the clock sweeps only drew a quarter circle; they are now rebuilt fresh at every new run.

## 0.9.84
- Damage meter icons: talents, procs and jewelry now have their icon in every language (2,600+ names added from the game's own translations, e.g. Omen of Clarity / Omen der Klarsicht). The question marks of the last version came from the wrong language detection, which also threw away the German icon names.

## 0.9.83
- Fixed: game texts (run stats, item names, plan) sometimes came out in English in a German (or other) game while PhantomUI's own texts were right. The game language is now recognised from your run's abilities right from the first second, not only from the damage meter, and a few unknown names no longer count as "English".
- All 113 ability names in all 14 game languages straight from the game data (Wrath, Moonfire, Faerie Fire and more were missing; Czech, Romanian, Ukrainian and Japanese now included).

## 0.9.82
- Abilities at your hero: the clock sweep is fitted like on the action bar (sized to the icon, not scaled), which removes the seams at 6 and 9 o'clock.

## 0.9.81
- Abilities at your hero: the clock sweep no longer sticks out past the icon.

## 0.9.80
- Abilities at your hero: icons sit on whole pixels so the clock sweep lines up with them. `/puicd 1|2|3` switches between three ways of fitting the classic client's clock onto the small icons, live.

## 0.9.79
- Abilities at your hero: every icon equally bright; icons on cooldown are no longer darkened on top of the clock sweep (they looked almost black).

## 0.9.78
- Abilities at your hero: the clock sweep is drawn a little larger so it covers the whole icon.

## 0.9.77
- Abilities at your hero: opacity 0.7 by default (0.5 is raised once), no seconds on the icons any more – just the clock sweep and the darker icon.

## 0.9.76
- Abilities at your hero: slots 3 and 6 sit a little further out and down, the racial lower beneath your hero – still mirrored.

## 0.9.75
- Abilities at your hero: easier to read cooldowns – only the icons are see-through now, the clock sweep stays fully visible; an icon on cooldown turns darker and shows its seconds left in big numbers.

## 0.9.74
- Abilities at your hero: the cooldown now runs as a clock sweep like on the action bar (the classic client draws it at a fixed 36 px, so it is scaled to the icon size instead of stretched).

## 0.9.73
- Abilities at your hero: arranged as two half-moons around your hero – 1–3 on the left, 4–6 mirrored on the right, the racial at the bottom in the middle, evenly spaced on one circle.

## 0.9.72
- **Abilities at your hero:** your six spells and your racial once more around your hero, half transparent – three left, three right, mirrored, the racial centred below – with their cooldowns. Display only: no mouse, no tooltip; the action bar stays as it is. On/off and opacity under `/pui` → Action bar, movable and resizable in anchor mode.

## 0.9.71 (for AS 0.108 – 0.110)
- **Totems & pets** now come straight from the game (AS 0.110): every summon of every class – hunter beasts, treants, spirit wolves, water elemental and every warlock demon including Legion Gate's – with the right count. Two Felguards show "2". No more talent ticks for pets (only Call of the Elements and Totemic Wrath for shaman totems), and the game's own icon is used.
- **Alerts** use the game's banner events (AS 0.108): bosses, guardians, achievements, opened zones, magnets, caches and runes, in the game's own words in your language, even while the game's banners are hidden. Achievements are gold, zones blue.
- Damage meter: summons get their icon from the game; Soul Fire is now spelled Soulfire (English and Turkish).
- Plan: Soulfire renamed in English and Turkish.
- Unit frames: long hero names (up to 20 letters, AS 0.108) are written a little smaller instead of being cut off.

## 0.9.70
- Damage number fan: the three areas are now fan slices instead of thin rays. Every number gets its own angle within its area (inner, middle, outer in turn, slightly scattered), so the gaps fill up – still stacked, so nothing overlaps.

## 0.9.69
- Damage number fan rebuilt: three lanes above your hero – up-left, straight up, up-right. Each lane is a stack: a new number takes the bottom spot and pushes the older ones further out along the lane, so numbers no longer overlap. The left lane is right-aligned and the right lane left-aligned so the lanes stay apart. At most 8 numbers per lane; the oldest goes first.

## 0.9.68
- Totems & pets: no more seconds under the summoned demons – just the icon with the count. The time left is still in the tooltip.

## 0.9.67
- Damage number fan: the start point is now exactly on your hero (the screen centre) – 0.9.66 put it up and to the left.

## 0.9.66
- Damage number fan: numbers now start right at your hero instead of a ring around the screen centre. The start point sits where the game's camera shows your hero and can be moved in anchor mode (`/pui unlock`, *Damage number fan*).
- Slower, calmer flight: a number takes 2.4 sec to fly out at an even pace (*Fan flight time*, 1–5 sec).

## 0.9.65
- Damage numbers in a fan above your hero: three areas (left, middle, right) with three lanes each. New numbers start at your hero and fly outwards along their lane, so the older a number is, the further up it is – even when lots of hits come at once.
- Under `/pui` → Damage numbers: *Layout* (fan above you / above enemies, as before) and *Fan reach*.

## 0.9.64
- Damage numbers: merged hits now show how often they hit, e.g. `238.3k x37` – the sum of all hits of one ability on one enemy.
- A merged number keeps collecting hits for up to 1.5 sec (*Merge over* under `/pui` → Damage numbers, 0.25–3 sec) and stays on screen while hits keep coming. The count can be switched off with *Show hit count*.

## 0.9.63
- Totems & pets for the new warlock talents (AS 0.105): tick *Demonic Familiar* (imp), *Soul Devourer* (felhunter), *Soul Link* (voidwalker) and *Demonic Supremacy* under `/pui` → General.
- Infernal, Doomguard, Pit Lord and Felguard show up on their own while they are out, with the seconds they have left under the icon (read from the damage meter). With Demonic Supremacy, Infernal and Doomguard stay for good and imp, felhunter and voidwalker are hidden.
- The old "Summon Imp" tick carries over to Demonic Familiar.

## 0.9.62
- Icons: Demonic Empowerment takes its real icon straight from your action bar (plan and meter); the new demons (Infernal, Doomguard, Pit Lord, Felguard, Imp, Felhunter, Voidwalker, Succubus) have icons in the meter.

## 0.9.61
- Plan: new warlock spell Demonic Empowerment (AS 0.104).
- Totems: at most 40 of each kind, like the game (AS 0.105).

## 0.9.60
- Damage meter: with its own scale it now moves all the way to the screen edge (the keep-on-screen check used the wrong units).

## 0.9.59
- Damage meter without borders: no outer frame, no lines between the bars.

## 0.9.58
- Damage numbers: the "show above mobs" tracking option is gone; numbers appear above visible nameplates only.

## 0.9.57
- Plan: a worn legendary necklace is now recognised by its name (all 12, every language), not only by its colour. `/pui gear` shows what the game reports for neck, rings and trinkets.

## 0.9.56
- Plan: legendary necklaces always rank above normal ones, whatever their position in the plan; wearing a legendary hides all normal necklaces.

## 0.9.55
- Fixed: a normal necklace that dropped as legendary (orange) no longer counts as the legendary necklace in the plan.

## 0.9.54
- Plan: the order is your ranking. Once you wear as many planned pieces as the slot holds (neck 1, rings/trinkets 2), every worse pick below them disappears; better ones stay. A worn legendary necklace counts as your planned legendary.

## 0.9.53
- Plan: legendary necklaces of your class under *Neck* – one per ability, orange, with the ability's icon and the game's own text ("Legendary amulet · remakes …").

## 0.9.52
- Plan: necklace, ring and trinket tooltips rebuilt from the game data – every effect of an item is listed (several necklaces had only one or a wrong effect), in the game's own wording and all languages.
- Plan tooltips look like item tooltips: name in its quality colour, slot in white, "Equip:" effects in green.
- Damage meter: kills column removed so ability names have room; sources whose floating numbers are hidden show a red cross.

## 0.9.51
- Totems & pets: tick your talents under `/pui` → General → *Totems & pets: talents* (Call of the Elements, Totemic Wrath, Feral Spirit, wolf/raptor, imp/felguard, treants, water elemental) – the game does not tell addons what you have skilled.

## 0.9.50
**New**
- **Totems & pets** above the player frame – just the icon with the number inside.
  - Shaman: counts your active Searing and Magma Totems. Cooldown and duration are read from the game (the duration straight from the ability tooltip, in the background), so upgrades and talents are always included. Call of the Elements counts double, Totemic Wrath adds its free Searing Totem every 14 sec.
  - Permanent pets from talents: spirit wolves, hunter wolf & raptor, imp & felguard, treants, water elemental.
  - Movable and resizable in anchor mode, can be switched off under General.
- **All 14 game languages** for PhantomUI's own menus and texts: English, Deutsch, Français, Español, Português, Polski, Čeština, Română, Türkçe, Русский, Українська, 简体中文, 日本語, 한국어.
  - Follows your game language automatically (and notices when you switch it), or pick one under General → Language or with `/pui lang en|de|fr|…`.
  - Fonts follow the language too, so Polish, Czech, Romanian, Turkish, Cyrillic, Chinese, Japanese and Korean letters show up properly.

**Improved**
- Damage meter switches to billions/trillions past 999.99m instead of wrapping to a second line.
- Target frame shortens health automatically once it reaches a million (endless mode).
- Class / enemy type box next to the frames is off by default (can be turned back on under Units).

**Fixed**
- Works with the new game client (AS 0.101+): the plan window and plan button load again, and the damage meter fits the stricter Lua 5.0 rules.
