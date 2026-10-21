# PhantomUI – Changelog

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
