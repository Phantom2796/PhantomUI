# PhantomUI – Changelog

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
