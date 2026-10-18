-- CompactSCT: kleine, kompakte Schadenszahlen mit dem Symbol der Faehigkeit,
-- direkt ueber dem getroffenen Gegner. Fuer Azeroth Survivors (WoW-1.12-Client).

CompactSCT = CompactSCT or {}

local ADDON = "CompactSCT"
local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local SOLID = "Interface\\Buttons\\WHITE8X8"
local ICON_MELEE = "Interface\\Icons\\INV_Sword_04"
local ICON_PET = "Interface\\Icons\\Ability_Hunter_BeastCall"
local ICON_SHIELD = "Interface\\Icons\\Spell_Nature_Thorns"

local FONTS = {
	arial = "Fonts\\ARIALN.TTF",
	friz = "Fonts\\FRIZQT__.TTF",
	skurri = "Fonts\\SKURRI.TTF",
	morpheus = "Fonts\\MORPHEUS.TTF",
}

local DEFAULTS = {
	enabled = true,
	size = 15,          -- Schriftgroesse normaler Treffer
	critScale = 1.6,    -- Crits so viel groesser
	icons = true,       -- Faehigkeits-Symbol anzeigen
	color = "school",   -- school | white | gold
	short = true,       -- 12345 -> 12.3k
	dots = true,        -- Schaden ueber Zeit anzeigen
	minAmount = 0,      -- kleinere Treffer ausblenden (fester Wert, nur per /csct min)
	minPercent = 0,     -- Treffer unter so viel Prozent des aktuellen Spitzentreffers ausblenden
	maxTexts = 30,      -- hoechstens so viele Zahlen gleichzeitig
	merge = true,       -- gleiche Treffer kurz hintereinander zu einer Zahl zusammenfassen
	duration = 0.9,     -- Sekunden sichtbar
	rise = 32,          -- so weit steigen sie nach oben
	track = true,       -- Positionen auch mit ausgeblendeten Namensplaketten
	font = "friz",
	offsetY = 6,        -- Abstand ueber der Plakette
	opacity = 0.6,      -- Sichtbarkeit 0 bis 1
	spread = 2.3,       -- wie weit die Zahlen auseinander liegen (1 = eng)
}

local SCHOOL_COLORS = {
	Physical = { 1.00, 0.93, 0.78 },
	Holy     = { 1.00, 0.90, 0.45 },
	Fire     = { 1.00, 0.50, 0.12 },
	Nature   = { 0.45, 1.00, 0.30 },
	Frost    = { 0.45, 0.85, 1.00 },
	Shadow   = { 0.72, 0.48, 1.00 },
	Arcane   = { 1.00, 0.55, 1.00 },
}
local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local CRIT_GOLD = { 1, 0.62, 0.10 }
local CRIT_RED = { 1, 0.15, 0.15 }
local DB_VERSION = 11

local db

local function Print(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCompactSCT|r: " .. text)
	end
end

local function LoadSettings()
	if type(CompactSCTDB) ~= "table" then
		CompactSCTDB = {}
	end
	for key, value in pairs(DEFAULTS) do
		if CompactSCTDB[key] == nil then
			CompactSCTDB[key] = value
		end
	end
	-- Version 2: groesser, fette Schrift, rote Crits. Alte gespeicherte Werte einmal anheben.
	if (CompactSCTDB.version or 1) < DB_VERSION then
		CompactSCTDB.size = DEFAULTS.size
		CompactSCTDB.critScale = DEFAULTS.critScale
		CompactSCTDB.font = DEFAULTS.font
		CompactSCTDB.opacity = DEFAULTS.opacity
		CompactSCTDB.spread = DEFAULTS.spread
		CompactSCTDB.maxTexts = DEFAULTS.maxTexts
		CompactSCTDB.merge = DEFAULTS.merge
		-- Der feste Mindestwert wird durch den prozentualen ersetzt.
		CompactSCTDB.minAmount = 0
		CompactSCTDB.version = DB_VERSION
	end
	-- Namen, die die Tabelle aus den Spieldaten kennt, braucht der Zwischenspeicher
	-- nicht (sie gehen vor; z. B. hatte Seelenfeuer frueher das Symbol von Zorn).
	if type(CompactSCTDB.iconCache) == "table" and AZSSpellMeterLocaleIcons then
		local drop = {}
		local n
		for n in pairs(CompactSCTDB.iconCache) do
			if AZSSpellMeterLocaleIcons[n] then
				table.insert(drop, n)
			end
		end
		for i = 1, table.getn(drop) do
			CompactSCTDB.iconCache[drop[i]] = nil
		end
	end
	db = CompactSCTDB
end

------------------------------------------------------------------------
-- Die eigenen gelben Zahlen des Spiels ab- und wieder anschalten
------------------------------------------------------------------------

local NATIVE_CVARS = { "CombatDamage", "PetMeleeDamage" }

local function GetCVarSafe(name)
	local ok, value = pcall(GetCVar, name)
	if ok then
		return value
	end
	return nil
end

local function SetCVarSafe(name, value)
	pcall(SetCVar, name, value)
end

local function DisableNative()
	if type(db.native) ~= "table" then
		db.native = {}
		for i = 1, table.getn(NATIVE_CVARS) do
			local name = NATIVE_CVARS[i]
			db.native[name] = GetCVarSafe(name)
		end
	end
	for i = 1, table.getn(NATIVE_CVARS) do
		SetCVarSafe(NATIVE_CVARS[i], "0")
	end
end

local function RestoreNative()
	if type(db.native) == "table" then
		for name, value in pairs(db.native) do
			if value ~= nil then
				SetCVarSafe(name, value)
			end
		end
	else
		SetCVarSafe("CombatDamage", "1")
	end
	db.native = nil
end

-- Kampflog-Reichweite erhoehen, sonst fehlen Treffer auf weiter entfernte Mobs.
local function WidenCombatLog()
	local names = {
		"CombatLogRangeCreature",
		"CombatLogRangeHostilePlayers",
		"CombatLogRangeHostilePlayersPets",
		"CombatLogRangeParty",
		"CombatLogRangePartyPet",
	}
	for i = 1, table.getn(names) do
		SetCVarSafe(names[i], "200")
	end
end

------------------------------------------------------------------------
-- Symbole: Zaubername -> Textur
------------------------------------------------------------------------

local icons = {}
local missing = {}
-- Ob eine Quelle ueber den Mobs ausgeblendet ist, je Quelle zwischengespeichert:
-- sonst wuerde bei jedem Treffer das Symbol gesucht und verglichen. Wird beim
-- Umschalten eines Hakens und nach jedem Einlesen der Symbole geleert.
local hiddenCache = {}
local unresolved = {}
local lastScan = 0
local scanTip

-- Feste Zuordnungen fuer deutsche Namen, die keine Quelle im Spiel (richtig) liefert.
-- Sie gehen allem anderen vor.
local MANUAL_ICONS = {
	["Göttliche Gunst"] = "Interface\\Icons\\Spell_Holy_Heal",
	["Dornen"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Schadensschild"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Klingenwirbel"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
	["Tödliches Gift"] = "Interface\\Icons\\Ability_Rogue_DualWeild",
	["Schicksal besiegeln"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
	["Schicksal besiegelt"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
	["Einbruch der Nacht"] = "Interface\\Icons\\Spell_Shadow_Twilight",
	["Einbruch der Dunkelheit"] = "Interface\\Icons\\Spell_Shadow_Twilight",
	["Saat der Verderbnis"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
	["Feuersbrunst"] = "Interface\\Icons\\Spell_Fire_Fireball",
	["Blitzüberladung"] = "Interface\\Icons\\Spell_Nature_CallStorm",
	["Lightning Overload"] = "Interface\\Icons\\Spell_Nature_CallStorm",
	["Schockwelle"] = "Interface\\Icons\\Ability_ShockWave",
	["Shockwave"] = "Interface\\Icons\\Ability_ShockWave",
	["Titan"] = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras",
	-- Weitere Sprachen des Spiels (Englisch, Franzoesisch, Spanisch)
	["Thorns"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Damage Shield"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Divine Favor"] = "Interface\\Icons\\Spell_Holy_Heal",
	["Faveur divine"] = "Interface\\Icons\\Spell_Holy_Heal",
	["Favor divino"] = "Interface\\Icons\\Spell_Holy_Heal",
	["Épines"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Espinas"] = "Interface\\Icons\\Spell_Nature_Thorns",
	["Blade Flurry"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
	["Déluge de lames"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
	["Aluvión de acero"] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
	["Deadly Poison"] = "Interface\\Icons\\Ability_Rogue_DualWeild",
	["Poison mortel"] = "Interface\\Icons\\Ability_Rogue_DualWeild",
	["Veneno mortal"] = "Interface\\Icons\\Ability_Rogue_DualWeild",
	["Seal Fate"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
	["Scelle le destin"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
	["Sellar destino"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
	["Nightfall"] = "Interface\\Icons\\Spell_Shadow_Twilight",
	["Crépuscule"] = "Interface\\Icons\\Spell_Shadow_Twilight",
	["Graine de Corruption"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
	["Semilla de corrupción"] = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
	["Conflagrate"] = "Interface\\Icons\\Spell_Fire_Fireball",
	["Conflagration"] = "Interface\\Icons\\Spell_Fire_Fireball",
	["Conflagrar"] = "Interface\\Icons\\Spell_Fire_Fireball",
	["Surcharge de foudre"] = "Interface\\Icons\\Spell_Nature_CallStorm",
	["Sobrecarga de relámpagos"] = "Interface\\Icons\\Spell_Nature_CallStorm",
	["Onde de choc"] = "Interface\\Icons\\Ability_ShockWave",
	["Ola de choque"] = "Interface\\Icons\\Ability_ShockWave",
	["Diablotin"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
	["Diablillo"] = "Interface\\Icons\\Spell_Shadow_SummonImp",
	["Gangregarde"] = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
	["Guardia vil"] = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
	["Marcheur du Vide"] = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
	["Abisario"] = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
	["Succube"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
	["Súcubo"] = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
	["Chasseur corrompu"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
	["Manáfago"] = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
}

local PREFIX_ICONS = {
	{ "^Schattenspalt", "Interface\\Icons\\Spell_Shadow_ScourgeBuild" },
	{ "^Feuersbrunst", "Interface\\Icons\\Spell_Fire_Fireball" },
}

local function Remember(name, texture)
	if name and texture and name ~= "" and texture ~= "" and not icons[name] then
		icons[name] = texture
	end
end

local function Tip()
	if scanTip == nil then
		local ok, tip = pcall(CreateFrame, "GameTooltip", "CompactSCTScanTip", UIParent, "GameTooltipTemplate")
		scanTip = ok and tip or false
	end
	if scanTip then
		scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	return scanTip
end

local function TipTitle()
	local line = getglobal("CompactSCTScanTipTextLeft1")
	local text = line and line:GetText()
	if text == "" then
		return nil
	end
	return text
end

-- Alten Tooltip-Text loeschen. Schlaegt das Fuellen fehl (eigene Faehigkeiten von
-- Azeroth Survivors), stuende sonst der vorige Name neben dem falschen Symbol.
local function TipClear(tip)
	if tip.ClearLines then
		tip:ClearLines()
	end
	local line = getglobal("CompactSCTScanTipTextLeft1")
	if line then
		line:SetText("")
	end
end

local function LinkName(link)
	if not link then
		return nil
	end
	local _, _, name = string.find(link, "%[(.-)%]")
	return name
end

local function ScanSpellbook()
	local i = 1
	while true do
		local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
		if not name then
			break
		end
		Remember(name, GetSpellTexture(i, BOOKTYPE_SPELL or "spell"))
		i = i + 1
	end
end

-- Aktionsleiste: die selbst wirkenden Faehigkeiten liegen dort.
local function ScanActionBar()
	local tip = Tip()
	if not tip or not tip.SetAction then
		return
	end
	for slot = 1, 120 do
		if HasAction(slot) then
			TipClear(tip)
			if pcall(tip.SetAction, tip, slot) then
				Remember(TipTitle(), GetActionTexture(slot))
			end
		end
	end
	tip:Hide()
end

-- Talentbaum: Talente, die selbst Schaden machen (Procs), stehen in keinem Zauberbuch.
local function ScanTalents()
	for tab = 1, GetNumTalentTabs() or 0 do
		for index = 1, GetNumTalents(tab) or 0 do
			local name, texture = GetTalentInfo(tab, index)
			Remember(name, texture)
		end
	end
end

-- Ausruestung: Amulette, Ringe und Schmuckstuecke mit eigenem Schaden.
local function ScanItems()
	for slot = 0, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			Remember(LinkName(link), GetInventoryItemTexture("player", slot))
		end
	end
end

-- Eigene Buffs: viele Talent-Procs laufen als Buff mit eigenem Symbol.
local function ScanBuffs()
	local tip = Tip()
	if not tip or not tip.SetUnitBuff then
		return
	end
	for index = 1, 32 do
		local texture = UnitBuff("player", index)
		if not texture then
			break
		end
		TipClear(tip)
		if pcall(tip.SetUnitBuff, tip, "player", index) then
			Remember(TipTitle(), texture)
		end
	end
	tip:Hide()
end

local function ScanIcons()
	lastScan = GetTime()
	-- Jede Quelle einzeln absichern: der Client von Azeroth Survivors ist ein Nachbau.
	if GetSpellName and GetSpellTexture then pcall(ScanSpellbook) end
	if HasAction and GetActionTexture then pcall(ScanActionBar) end
	if GetNumTalentTabs and GetNumTalents and GetTalentInfo then pcall(ScanTalents) end
	if GetInventoryItemLink and GetInventoryItemTexture then pcall(ScanItems) end
	if UnitBuff then pcall(ScanBuffs) end
end

-- Geplantes Einlesen: 2 Sekunden nach der letzten Aenderung (Levelaufstieg, neue
-- Faehigkeit, Ausruestung), hoechstens alle 20 Sekunden. Viele Aenderungen kurz
-- hintereinander (z. B. mehrere Level auf einmal) ergeben so nur ein Einlesen.
local scanDue = 0
local SCAN_DELAY, SCAN_MIN_GAP = 2, 20

local function ScheduleScan()
	local now = GetTime()
	local due = now + SCAN_DELAY
	if due < lastScan + SCAN_MIN_GAP then
		due = lastScan + SCAN_MIN_GAP
	end
	scanDue = due
end

function CompactSCT.ScanIfDue(now)
	if scanDue > 0 and now >= scanDue then
		scanDue = 0
		missing = {}
		hiddenCache = {}
		ScanIcons()
	end
end

local function Lookup(name)
	if not name or name == "" then
		return nil
	end
	-- [Nobby] Zuerst die Tabelle aus den Spieldaten (PhantomUI, alle Sprachen).
	local generated = AZSSpellMeterLocaleIcons and AZSSpellMeterLocaleIcons[name]
	if generated then
		return "Interface\\Icons\\" .. generated
	end
	if MANUAL_ICONS[name] then
		return MANUAL_ICONS[name]
	end
	if icons[name] then
		return icons[name]
	end
	-- Einmal gefundene Symbole bleiben gespeichert: manche kommen nur kurz als Buff vor.
	local saved = db and db.iconCache and db.iconCache[name]
	if saved then
		return saved
	end
	local file = AZSSpellMeterIcon and AZSSpellMeterIcon[name]
	if file then
		if not string.find(file, "\\", 1, true) then
			file = "Interface\\Icons\\" .. file
		end
		return file
	end
	return nil
end

-- "Amulett des Infernos: Weihe" -> erst das Amulett, sonst der verstaerkte Zauber.
-- "Weihe (Rang 3)" -> "Weihe".
local function Resolve(name)
	local texture = Lookup(name)
	if texture then
		return texture
	end
	local _, _, left, right = string.find(name, "^(.-):%s*(.+)$")
	if left then
		texture = Lookup(left) or Lookup(right)
		if texture then
			return texture
		end
	end
	local _, _, bare = string.find(name, "^(.-)%s*%(.-%)$")
	if bare then
		texture = Lookup(bare)
		if texture then
			return texture
		end
	end
	for i = 1, table.getn(PREFIX_ICONS) do
		if string.find(name, PREFIX_ICONS[i][1]) then
			return PREFIX_ICONS[i][2]
		end
	end
	return nil
end

local function ResolveFresh(name)
	local texture = Resolve(name)
	if texture then
		return texture
	end
	-- Nie mitten im Kampf neu einlesen: das Einlesen fragt jeden Aktionsplatz per
	-- Tooltip ab und war ein Ruckler. Neu eingelesen wird nur geplant (siehe ScheduleScan).
	missing[name] = true
	return nil
end

local function IconFor(info)
	if info.kind == "melee" then
		return GetInventoryItemTexture("player", 16) or ICON_MELEE
	elseif info.kind == "shield" then
		return ICON_SHIELD
	elseif info.kind == "pet" and not info.spell then
		return ICON_PET
	end
	local spell = info.spell
	if not spell or spell == "" then
		return nil
	end
	if icons[spell] then
		return icons[spell]
	end
	local texture = ResolveFresh(spell)
	if texture then
		icons[spell] = texture
	else
		unresolved[spell] = true
	end
	return texture
end

-- Die gefundenen Symbole auch an AZS Spell Meter weitergeben, damit dort
-- Talent- und Amulett-Zeilen kein Fragezeichen mehr zeigen.
local METER_FALLBACKS = { Melee = true, ["Damage Shield"] = true, Pet = true }
local lastFeed = 0


-- Das Meter des Spiels nennt Quellen auf Deutsch, das Kampflog auf Englisch.
-- Wir zaehlen den Schaden je englischem Zaubernamen mit und ordnen eine deutsche
-- Meter-Zeile dem englischen Namen mit (fast) gleicher Schadenssumme zu.
local logTotals = {}
local lastRunTime = 0
local MATCH_TOLERANCE = 0.04
local MATCH_MIN_DAMAGE = 500

function CompactSCT.CountDamage(info)
	if info.spell and info.spell ~= "" then
		logTotals[info.spell] = (logTotals[info.spell] or 0) + info.amount
	end
end

local function NewRunCheck()
	if type(AZS_GetRunTime) ~= "function" then
		return
	end
	local ok, t = pcall(AZS_GetRunTime)
	if ok and type(t) == "number" then
		if t + 2 < lastRunTime then
			logTotals = {}
		end
		lastRunTime = t
	end
end

local function IconKey(texture)
	if not texture then
		return nil
	end
	local _, _, file = string.find(string.lower(texture), "([^\\]+)$")
	return file
end

-- Nur eindeutige Treffer: genau ein englischer Name passt, dessen Symbol noch keiner
-- anderen Meter-Zeile gehoert. Zwei aehnlich grosse Summen = lieber kein Symbol.
local function MatchByDamage(damage, claimed, usedIcons)
	if not damage or damage < MATCH_MIN_DAMAGE then
		return nil
	end
	local best, count = nil, 0
	for spell, total in pairs(logTotals) do
		if not claimed[spell] then
			local diff = math.abs(total - damage) / damage
			if diff <= MATCH_TOLERANCE * 2 then
				local texture = Resolve(spell)
				if texture and not usedIcons[IconKey(texture)] then
					count = count + 1
					if diff <= MATCH_TOLERANCE then
						best = spell
					end
				end
			end
		end
	end
	if count == 1 then
		return best
	end
	return nil
end

local function FeedSpellMeter(now)
	if now - lastFeed < 3 then
		return
	end
	lastFeed = now
	if type(AZSSpellMeterIcon) ~= "table" or type(AZS_GetMeter) ~= "function" then
		return
	end
	NewRunCheck()
	local ok, lines = pcall(AZS_GetMeter)
	if not ok or type(lines) ~= "table" then
		return
	end
	-- Englische Namen und Symbole, die schon einer Meter-Zeile gehoeren, nicht doppelt vergeben.
	local claimed = {}
	local usedIcons = {}
	for index = 1, table.getn(lines) do
		local name = lines[index] and lines[index].name
		if name then
			claimed[name] = true
			local known = AZSSpellMeterIcon[name] or Resolve(name)
			if known then
				usedIcons[IconKey(known)] = true
			end
		end
	end
	for index = 1, table.getn(lines) do
		local line = lines[index]
		local name = line and line.name
		if name and not METER_FALLBACKS[name] and not AZSSpellMeterIcon[name] then
			local texture = MANUAL_ICONS[name] or ResolveFresh(name)
			if not texture then
				local spell = MatchByDamage(line.dmg, claimed, usedIcons)
				if spell then
					texture = Resolve(spell)
					claimed[spell] = true
					usedIcons[IconKey(texture)] = true
				end
			end
			if texture then
				AZSSpellMeterIcon[name] = texture
				icons[name] = texture
				unresolved[name] = nil
				if not MANUAL_ICONS[name] then
					if type(db.iconCache) ~= "table" then db.iconCache = {} end
					db.iconCache[name] = texture
				end
			else
				unresolved[name] = true
			end
		end
	end
end

function CompactSCT.Unresolved()
	local list = {}
	for name in pairs(unresolved) do
		if not Resolve(name) then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end


------------------------------------------------------------------------
-- Namensplaketten finden und ihre Position verfolgen
------------------------------------------------------------------------

local plates = {}       -- Plakette -> { nameText, bar, origin, masked }
local origins = {}      -- alle aktuellen und kuerzlich verschwundenen Gegner-Positionen
local knownChildren = 0
local userPlates = false   -- hat der Spieler die Plaketten selbst eingeschaltet (V)?
local backing = nil         -- haben wir die Plaketten intern eingeschaltet?
local nativeShow, nativeHide

local GHOST_TIME = 0.6      -- so lange bleibt ein toter/verschwundener Mob als Ziel gueltig
local LOSS_TIME = 0.3

local function UIScale()
	return UIParent:GetEffectiveScale() or 1
end

local function Discover()
	local count = WorldFrame:GetNumChildren() or 0
	if count == knownChildren then
		return
	end
	-- Neue Rahmen haengen hinten an: nur die neuen pruefen, nicht alle.
	local from = knownChildren + 1
	if count < knownChildren then
		from = 1
	end
	knownChildren = count
	local kids = { WorldFrame:GetChildren() }
	for i = from, table.getn(kids) do
		local f = kids[i]
		if f and not plates[f] and not f:GetName() then
			local border = f:GetRegions()
			if border and border.GetObjectType and border:GetObjectType() == "Texture"
				and border:GetTexture() == BORDER then
				local nameText
				local regions = { f:GetRegions() }
				for r = 1, table.getn(regions) do
					if regions[r]:GetObjectType() == "FontString" then
						nameText = regions[r]
						break
					end
				end
				local bar
				local children = { f:GetChildren() }
				for c = 1, table.getn(children) do
					if children[c]:GetObjectType() == "StatusBar" then
						bar = children[c]
						break
					end
				end
				if nameText and bar then
					plates[f] = { nameText = nameText, bar = bar }
				end
			end
		end
	end
end

local function Retire(data, now)
	local o = data.origin
	if o then
		o.live = false
		o.gone = now
		data.origin = nil
	end
end

local function Mask(plate, data, masked, now)
	if masked then
		-- Nur alle halbe Sekunde nachsetzen, falls das Spiel die Transparenz zurueckstellt.
		if not data.masked or now - (data.maskAt or 0) > 0.5 then
			plate:SetAlpha(0)
			data.maskAt = now
		end
		if not data.masked then
			data.masked = true
			if plate.EnableMouse then
				plate:EnableMouse(false)
			end
		end
	elseif data.masked then
		data.masked = nil
		plate:SetAlpha(1)
		if plate.EnableMouse then
			plate:EnableMouse(true)
		end
	end
end

local function WantBacking()
	return db and db.enabled and db.track and not userPlates
end

local function ApplyBacking()
	local want = WantBacking() and true or false
	if want ~= backing then
		backing = want
		if want then
			if nativeShow then nativeShow() end
		elseif not userPlates then
			if nativeHide then nativeHide() end
		end
	end
end

local function Sample(now)
	Discover()
	local masked = WantBacking()
	local scale = UIScale()
	for plate, data in pairs(plates) do
		Mask(plate, data, masked, now)
		if plate:IsShown() then
			local name = data.nameText:GetText()
			if not name or name == "" then
				Retire(data, now)
			else
				local o = data.origin
				if o and o.name ~= name then
					Retire(data, now)
					o = nil
				end
				if not o then
					o = { name = name, live = true }
					data.origin = o
					table.insert(origins, o)
				end
				local x, y = plate:GetCenter()
				if x and y then
					local ratio = (plate:GetEffectiveScale() or scale) / scale
					local top = plate:GetTop() or y
					o.x = x * ratio
					o.y = top * ratio
					o.seen = now
				end
				local value = data.bar:GetValue()
				local low, high = data.bar:GetMinMaxValues()
				if value and high and low and high > low then
					if o.hp and o.high == high and value < o.hp then
						local lost = o.hp - value
						if o.lossAt and now - o.lossAt <= LOSS_TIME then
							o.loss = (o.loss or 0) + lost
						else
							o.loss = lost
						end
						o.lossAt = now
					end
					o.hp, o.low, o.high = value, low, high
					o.absolute = high - low > 100
				end
			end
		else
			Retire(data, now)
		end
	end
	for i = table.getn(origins), 1, -1 do
		local o = origins[i]
		if not o.live and now - (o.gone or 0) > GHOST_TIME then
			table.remove(origins, i)
		end
	end
end

-- Welcher Gegner wurde getroffen? Das 1.12-Kampflog nennt nur den Namen,
-- daher hilft der gerade gesunkene Lebensbalken, den richtigen Mob zu finden.
-- Wiederverwendete Listen: kein neuer Abfall pro Treffer (Lua 5.0 raeumt in
-- einem Rutsch auf, das waren die Ruckler bei vielen Zahlen).
-- Eigene Zaehler statt table.getn: in Lua 5.0 behaelt eine Liste ihre alte
-- Laenge, auch wenn man die Eintraege leert (das war der Fehler in Zeile 800).
local cands, losers, exact = {}, {}, {}
local function Resolve(info, now, final)
	local nc, nl, ne = 0, 0, 0
	for i = 1, table.getn(origins) do
		local o = origins[i]
		if o.name == info.target and o.x and (o.live or now - (o.gone or 0) <= GHOST_TIME) then
			nc = nc + 1
			cands[nc] = o
			if o.lossAt and now - o.lossAt <= LOSS_TIME and (o.loss or 0) > 0 then
				nl = nl + 1
				losers[nl] = o
				if o.absolute then
					local dead = o.hp and o.low and o.hp <= o.low
					if math.abs(o.loss - info.amount) < 0.5 or (dead and info.amount >= o.loss) then
						ne = ne + 1
						exact[ne] = o
					end
				end
			end
		end
	end
	local pick
	if ne > 0 then
		pick = exact[math.random(1, ne)]
	elseif nl > 0 then
		pick = losers[1]
		for i = 2, nl do
			if losers[i].lossAt > pick.lossAt then
				pick = losers[i]
			end
		end
	elseif nc == 1 or (final and nc > 0) then
		pick = cands[math.random(1, nc)]
	end
	-- Verweise loesen, damit alte Gegner freigegeben werden koennen
	for i = 1, nc do
		cands[i] = nil
	end
	for i = 1, nl do
		losers[i] = nil
	end
	for i = 1, ne do
		exact[i] = nil
	end
	if pick then
		if pick.absolute and pick.loss then
			pick.loss = math.max(0, pick.loss - info.amount)
		end
		return pick.x, pick.y, pick
	end
	if not final then
		return nil
	end
	-- Kein passender Mob sichtbar: in einem Ring um den Helden (Bildschirmmitte).
	local angle = math.random() * 6.2832
	local reach = (70 + math.random() * 60) * (db.spread or 1)
	return UIParent:GetWidth() / 2 + math.cos(angle) * reach,
		UIParent:GetHeight() / 2 + 40 + math.sin(angle) * reach * 0.6, nil
end

------------------------------------------------------------------------
-- Die Zahlen selbst
------------------------------------------------------------------------

local pool = {}
local active = {}
local pending = {}
local fontVersion = 1

local function FontPath()
	return FONTS[db.font] or FONTS.arial
end

local function ApplyFont(t)
	if t.fontVersion ~= fontVersion then
		t.fontVersion = fontVersion
		t.label:SetFont(FontPath(), db.size, "THICKOUTLINE")
		t.icon:SetWidth(db.size)
		t.icon:SetHeight(db.size)
		t.iconBack:SetWidth(db.size + 2)
		t.iconBack:SetHeight(db.size + 2)
	end
end

local function NewText()
	local f = CreateFrame("Frame", nil, UIParent)
	-- Schadenszahlen ganz unten: hinter allen Fenstern
	f:SetFrameStrata("BACKGROUND")
	f:SetWidth(1)
	f:SetHeight(1)
	f:EnableMouse(false)
	local label = f:CreateFontString(nil, "OVERLAY")
	label:SetShadowOffset(1, -1)
	label:SetShadowColor(0, 0, 0, 0.8)
	local iconBack = f:CreateTexture(nil, "ARTWORK")
	iconBack:SetTexture(SOLID)
	iconBack:SetVertexColor(0, 0, 0, 0.85)
	local icon = f:CreateTexture(nil, "OVERLAY")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	iconBack:SetPoint("CENTER", icon, "CENTER", 0, 0)
	f:Hide()
	return { frame = f, label = label, icon = icon, iconBack = iconBack }
end

local function Release(index)
	local t = table.remove(active, index)
	t.frame:Hide()
	t.origin = nil
	table.insert(pool, t)
end

local function Format(amount)
	if db.short then
		if amount >= 1000000 then
			return string.format("%.1fm", amount / 1000000)
		elseif amount >= 10000 then
			return string.format("%.1fk", amount / 1000)
		end
	end
	return tostring(amount)
end

local function ColorFor(info)
	if info.crit then
		return CRIT_RED
	end
	if db.color == "white" then
		return info.crit and CRIT_GOLD or WHITE
	elseif db.color == "gold" then
		return info.crit and CRIT_GOLD or GOLD
	end
	return SCHOOL_COLORS[info.school] or SCHOOL_COLORS.Physical
end

local function Show(info, x, y, origin)
	if table.getn(active) >= db.maxTexts then
		Release(1)
	end
	local t = table.remove(pool) or NewText()
	ApplyFont(t)

	local color = ColorFor(info)
	t.label:SetText(Format(info.amount))
	t.label:SetTextColor(color[1], color[2], color[3])

	local texture = db.icons and IconFor(info)
	t.label:ClearAllPoints()
	t.icon:ClearAllPoints()
	if texture then
		local shift = (db.size + 4) / 2
		t.label:SetPoint("CENTER", t.frame, "CENTER", shift, 0)
		t.icon:SetPoint("RIGHT", t.label, "LEFT", -4, 0)
		t.icon:SetTexture(texture)
		t.icon:Show()
		t.iconBack:Show()
	else
		t.label:SetPoint("CENTER", t.frame, "CENTER", 0, 0)
		t.icon:Hide()
		t.iconBack:Hide()
	end

	t.origin = origin
	t.baseX, t.baseY = x, y
	local spread = db.spread or 1
	t.jitterX = (math.random() - 0.5) * 60 * spread
	t.jitterY = (math.random() - 0.5) * 24 * spread
	t.drift = (math.random() - 0.5) * 16 * spread
	t.crit = info.crit
	t.dot = info.kind == "dot"
	t.age = 0
	t.life = info.crit and db.duration * 1.25 or db.duration
	t.frame:SetAlpha((t.dot and 0.85 or 1) * db.opacity)
	t.frame:SetScale(1)
	t.lastScale, t.lastAlpha = 1, nil
	t.amount = info.amount
	t.mergeKey = info.mergeKey
	t.frame:ClearAllPoints()
	t.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	t.frame:Show()
	table.insert(active, t)
end

local POP_TIME = 0.12

local function UpdateTexts(elapsed)
	for i = table.getn(active), 1, -1 do
		local t = active[i]
		t.age = t.age + elapsed
		local p = t.age / t.life
		if p >= 1 then
			Release(i)
		else
			-- Am lebenden Mob mitlaufen.
			local o = t.origin
			if o and o.live and o.x then
				t.baseX = t.baseX + (o.x - t.baseX) * 0.35
				t.baseY = t.baseY + (o.y - t.baseY) * 0.35
			end
			local eased = 1 - (1 - p) * (1 - p)
			local scale = t.dot and 0.85 or 1
			if t.crit then
				scale = db.critScale
				if t.age < POP_TIME then
					scale = scale * (1 + 0.5 * (1 - t.age / POP_TIME))
				end
			end
			local x = t.baseX + t.jitterX + t.drift * eased
			local y = t.baseY + db.offsetY + t.jitterY + db.rise * eased
			-- Nur aendern, was sich wirklich aendert: jeder Aufruf geht an die Engine.
			if t.lastScale ~= scale then
				t.frame:SetScale(scale)
				t.lastScale = scale
			end
			-- Ankerabstaende gelten im Massstab des Rahmens selbst. Derselbe Ankerpunkt
			-- ersetzt den alten, ClearAllPoints ist dafuer nicht noetig.
			t.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
			if p > 0.6 then
				local alpha = (1 - p) / 0.4
				if t.dot then
					alpha = alpha * 0.85
				end
				alpha = alpha * db.opacity
				if not t.lastAlpha or math.abs(t.lastAlpha - alpha) > 0.03 then
					t.frame:SetAlpha(alpha)
					t.lastAlpha = alpha
				end
			end
		end
	end
end

local SETTLE = 0.04
local FALLBACK = 0.14
local MERGE_TIME = 0.25

-- Gleiche Faehigkeit, gleiches Ziel, kurz hintereinander: in die schon sichtbare Zahl
-- einrechnen statt eine neue zu erzeugen. Spart bei Flaechenschaden viele Zahlen.
local function MergeIntoActive(info)
	if not db.merge or not info.mergeKey then
		return false
	end
	for i = table.getn(active), 1, -1 do
		local t = active[i]
		if t.age > MERGE_TIME then
			break
		end
		if t.mergeKey == info.mergeKey then
			t.amount = t.amount + info.amount
			t.label:SetText(Format(t.amount))
			return true
		end
	end
	return false
end

local function UpdatePending(now)
	local i = 1
	while i <= table.getn(pending) do
		local entry = pending[i]
		local age = now - entry.time
		local shown = false
		if age >= SETTLE then
			if MergeIntoActive(entry) then
				shown = true
			else
				local x, y, origin = Resolve(entry, now, age >= FALLBACK)
				if x then
					Show(entry, x, y, origin)
					shown = true
				end
			end
		end
		if shown then
			table.remove(pending, i)
		else
			i = i + 1
		end
	end
end

local function ClearAll()
	for i = table.getn(active), 1, -1 do
		Release(i)
	end
	pending = {}
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

local frame = CreateFrame("Frame", "CompactSCTFrame")
local lastSample = 0
local lastPending = 0

-- Welche Quellen ueber den Mobs ausgeblendet sind (Haken im AZS Spell Meter).
-- Gespeichert nach Name (deutsch oder englisch) und nach Symbol: das Meter nennt
-- Zauber auf Deutsch, das Kampflog auf Englisch, das Symbol ist bei beiden gleich.
-- Begleiter: das Kampflog nennt sie englisch, das Meter deutsch.
local PET_GERMAN = {
	["Imp"] = "Wichtel",
	["Felguard"] = "Teufelswache",
	["Voidwalker"] = "Leerwandler",
	["Succubus"] = "Sukkubus",
	["Felhunter"] = "Teufelsjäger",
	["Infernal"] = "Höllenbestie",
	["Doomguard"] = "Verdammniswache",
}

local KIND_NAMES = {
	melee = { "Melee", "Nahkampf" },
	pet = { "Pets", "Pet", "Begleiter" },
	shield = { "Dornen", "Damage Shield", "Schadensschild" },
}

local function HiddenTables()
	if type(db.hiddenNames) ~= "table" then db.hiddenNames = {} end
	if type(db.hiddenIcons) ~= "table" then db.hiddenIcons = {} end
	return db.hiddenNames, db.hiddenIcons
end

local function IsHidden(name, texture)
	local names, iconsHidden = HiddenTables()
	if name and names[name] then
		return true
	end
	local key = IconKey(texture)
	return key ~= nil and iconsHidden[key] == true
end

local function ToggleHidden(name, texture)
	hiddenCache = {}
	local names, iconsHidden = HiddenTables()
	local key = IconKey(texture)
	if IsHidden(name, texture) then
		if name then names[name] = nil end
		if key then iconsHidden[key] = nil end
	else
		if name then names[name] = true end
		-- Das Fragezeichen nie als Schluessel: sonst traefe es alle unbekannten Quellen.
		if key and not string.find(key, "questionmark", 1, true) then iconsHidden[key] = true end
	end
end

local function HiddenHit(info)
	local names, iconsHidden = HiddenTables()
	if not next(names) and not next(iconsHidden) then
		return false
	end
	local cacheKey = (info.spell or "") .. "\031" .. (info.kind or "") .. "\031" .. (info.source or "")
	local cached = hiddenCache[cacheKey]
	if cached ~= nil then
		return cached
	end
	local result = false
	if info.spell and names[info.spell] then
		result = true
	end
	-- Treffer eines Begleiters: Haken bei "Wichtel", "Teufelswache" usw. im Meter.
	if not result and info.source and info.source ~= UnitName("player") then
		if names[info.source] or names[PET_GERMAN[info.source] or ""] then
			result = true
		end
	end
	local aliases = KIND_NAMES[info.kind]
	if not result and aliases and not info.spell then
		for i = 1, table.getn(aliases) do
			if names[aliases[i]] then
				result = true
			end
		end
	end
	if not result then
		local key = IconKey(IconFor(info))
		result = key ~= nil and iconsHidden[key] == true
	end
	hiddenCache[cacheKey] = result
	return result
end

-- Spitzentreffer der letzten Zeit (ohne Crits und DoTs, die verzerren). Halbiert
-- sich ohne neue grosse Treffer etwa alle 20 Sekunden.
local peak, peakAt = 0, 0
local PEAK_DECAY = 0.966

local function HandleCombat(eventName, message)
	if not db or not db.enabled then
		return
	end
	local info = CompactSCT.Parse(eventName, message)
	if not info then
		return
	end
	CompactSCT.CountDamage(info)
	if HiddenHit(info) then
		return
	end
	if info.kind == "dot" and not db.dots then
		return
	end
	if info.amount < (db.minAmount or 0) then
		return
	end
	-- Prozentualer Mindestschaden: gemessen am aktuellen Spitzentreffer, der langsam
	-- abklingt. So waechst die Grenze mit, egal ob die groessten Zahlen 500 oder 15000 sind.
	local now = GetTime()
	peak = peak * math.pow(PEAK_DECAY, now - peakAt)
	peakAt = now
	if not info.crit and info.kind ~= "dot" and info.amount > peak then
		peak = info.amount
	end
	if (db.minPercent or 0) > 0 and info.amount < peak * db.minPercent / 100 then
		return
	end
	info.mergeKey = (info.spell or info.kind or "") .. "\031" .. (info.target or "") .. (info.crit and "\031c" or "")
	if db.merge then
		for i = 1, table.getn(pending) do
			local other = pending[i]
			if other.mergeKey == info.mergeKey then
				other.amount = other.amount + info.amount
				return
			end
		end
	end
	-- Bei einem Hagel aus Treffern nicht unbegrenzt stauen: die aeltesten fallen weg.
	if table.getn(pending) >= 40 then
		table.remove(pending, 1)
	end
	info.time = now
	table.insert(pending, info)
end

local function RegisterCombat(on)
	for eventName in pairs(CompactSCT.Handlers) do
		if on then
			frame:RegisterEvent(eventName)
		else
			frame:UnregisterEvent(eventName)
		end
	end
end

local function HookPlateToggles()
	if nativeShow or type(ShowNameplates) ~= "function" or type(HideNameplates) ~= "function" then
		return
	end
	nativeShow = ShowNameplates
	nativeHide = HideNameplates
	ShowNameplates = function()
		userPlates = true
		nativeShow()
		ApplyBacking()
	end
	HideNameplates = function()
		userPlates = false
		-- Plaketten fuer die Positionen intern anlassen, nur unsichtbar.
		if WantBacking() then
			backing = true
		else
			backing = false
			nativeHide()
		end
	end
end

local function Enable()
	db.enabled = true
	DisableNative()
	WidenCombatLog()
	RegisterCombat(true)
	ScanIcons()
	ApplyBacking()
end

local function Disable()
	db.enabled = false
	RegisterCombat(false)
	ClearAll()
	RestoreNative()
	ApplyBacking()
	for plate, data in pairs(plates) do
		Mask(plate, data, false, GetTime())
	end
end

frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

frame:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		LoadSettings()
		userPlates = NAMEPLATES_ON and true or false
		HookPlateToggles()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not db then
			LoadSettings()
		end
		HookPlateToggles()
		backing = nil
		if db.enabled then
			Enable()
		else
			RestoreNative()
		end
	elseif event == "PLAYER_LEAVING_WORLD" then
		ClearAll()
	elseif event == "SPELLS_CHANGED" or event == "ACTIONBAR_SLOT_CHANGED"
		or event == "CHARACTER_POINTS_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
		if db and db.enabled and db.icons then
			ScheduleScan()
		end
	else
		HandleCombat(event, arg1)
	end
end)

frame:SetScript("OnUpdate", function()
	if not db or not db.enabled then
		return
	end
	local now = GetTime()
	-- Plaketten 30-mal pro Sekunde abfragen statt in jedem Bild: reicht fuer
	-- fluessiges Mitlaufen und halbiert bei hohen FPS die Arbeit.
	if now - lastSample >= 0.033 then
		lastSample = now
		Sample(now)
	end
	FeedSpellMeter(now)
	CompactSCT.ScanIfDue(now)
	if table.getn(pending) > 0 and now - lastPending >= 0.02 then
		lastPending = now
		UpdatePending(now)
	end
	if table.getn(active) > 0 then
		UpdateTexts(arg1 or 0)
	end
end)

------------------------------------------------------------------------
-- Test und Befehle
------------------------------------------------------------------------

local function Test()
	if not db.enabled then
		Print("ist aus. Erst |cffffff00/csct on|r.")
		return
	end
	local spells = {}
	for name in pairs(icons) do
		table.insert(spells, name)
		if table.getn(spells) >= 6 then
			break
		end
	end
	local schools = { "Physical", "Fire", "Frost", "Nature", "Shadow", "Arcane", "Holy" }
	local targets = {}
	for i = 1, table.getn(origins) do
		if origins[i].live and origins[i].x then
			table.insert(targets, origins[i])
		end
	end
	for n = 1, 14 do
		local info = {
			amount = math.random(8, 400),
			crit = math.random() < 0.25,
			school = schools[math.random(1, table.getn(schools))],
			kind = "spell",
			spell = spells[math.random(1, math.max(1, table.getn(spells)))],
		}
		if n == 14 then
			info.amount = 23456
			info.crit = true
		end
		local x, y, o
		if table.getn(targets) > 0 then
			o = targets[math.random(1, table.getn(targets))]
			x, y = o.x, o.y
		else
			x = UIParent:GetWidth() / 2 + (math.random() - 0.5) * 300
			y = UIParent:GetHeight() / 2 + (math.random() - 0.5) * 160
		end
		Show(info, x, y, o)
	end
end

local function Status()
	Print("Status: " .. (db.enabled and "|cff00ff00an|r" or "|cffff4040aus|r")
		.. ", Groesse " .. db.size
		.. ", Crit x" .. db.critScale
		.. ", Symbole " .. (db.icons and "an" or "aus")
		.. ", Farben " .. db.color
		.. ", Schrift " .. db.font
		.. ", DoTs " .. (db.dots and "an" or "aus")
		.. ", Mindestwert " .. db.minAmount .. " / " .. (db.minPercent or 0) .. "%"
		.. ", max " .. db.maxTexts
		.. ", Dauer " .. db.duration .. "s"
		.. ", Sichtbarkeit " .. db.opacity
		.. ", Verfolgung " .. (db.track and "an" or "aus"))
end

local function Help()
	Print("Befehle:")
	local lines = {
		"/csct  - Einstellungsfenster",
		"/csct on | off  - Addon an/aus (aus = Zahlen des Spiels zurueck)",
		"/csct test  - Beispielzahlen anzeigen",
		"/csct size 8-30  - Schriftgroesse",
		"/csct crit 1-2  - Crit-Vergroesserung (z. B. 1.35)",
		"/csct icons  - Symbole an/aus",
		"/csct color school|white|gold  - Farben",
		"/csct font arial|friz|skurri|morpheus",
		"/csct short  - grosse Zahlen kuerzen (12.3k) an/aus",
		"/csct dots  - Schaden ueber Zeit an/aus",
		"/csct min Zahl  - kleinere Treffer ausblenden",
		"/csct max Zahl  - hoechstens so viele Zahlen gleichzeitig",
		"/csct time Sekunden  - Anzeigedauer (z. B. 0.9)",
		"/csct rise Pixel  - wie weit sie steigen",
		"/csct alpha 0.1-1  - Sichtbarkeit (z. B. 0.8)",
		"/csct spread 0.5-4  - wie weit die Zahlen auseinander liegen",
		"/csct merge  - gleiche Treffer zusammenfassen an/aus",
		"/csct track  - Positionen auch bei ausgeblendeten Plaketten",
		"/csct missing  - Faehigkeiten ohne Symbol auflisten",
		"/csct status | reset",
	}
	for i = 1, table.getn(lines) do
		Print("  " .. lines[i])
	end
end

local function Number(text, low, high)
	local n = tonumber(text)
	if not n then
		return nil
	end
	if n < low then n = low end
	if n > high then n = high end
	return n
end

-- Schnittstelle fuer das Einstellungsfenster (Options.lua).
CompactSCT.API = {
	DB = function()
		if not db then
			LoadSettings()
		end
		return db
	end,
	Defaults = DEFAULTS,
	Enable = function() Enable() end,
	Disable = function() Disable() end,
	FontChanged = function() fontVersion = fontVersion + 1 end,
	TrackChanged = function()
		ApplyBacking()
		if not db.track then
			for plate, data in pairs(plates) do
				Mask(plate, data, false, GetTime())
			end
		end
	end,
	Test = function() Test() end,
	Print = Print,
	IsHidden = function(name, texture)
		if not db then LoadSettings() end
		return IsHidden(name, texture)
	end,
	ToggleHidden = function(name, texture)
		if not db then LoadSettings() end
		ToggleHidden(name, texture)
	end,
}

SLASH_COMPACTSCT1 = "/csct"
SlashCmdList["COMPACTSCT"] = function(msg)
	if not db then
		LoadSettings()
	end
	msg = string.lower(msg or "")
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd or ""
	rest = rest or ""

	if cmd == "" or cmd == "opt" or cmd == "menu" or cmd == "optionen" then
		if CompactSCT.ToggleOptions then
			CompactSCT.ToggleOptions()
		else
			Help()
		end
	elseif cmd == "help" or cmd == "hilfe" then
		Help()
		Status()
	elseif cmd == "on" or cmd == "an" then
		Enable()
		Print("an. Die gelben Zahlen des Spiels sind aus.")
	elseif cmd == "off" or cmd == "aus" then
		Disable()
		Print("aus. Die Zahlen des Spiels sind zurueck.")
	elseif cmd == "test" then
		Test()
	elseif cmd == "size" then
		local n = Number(rest, 8, 30)
		if n then
			db.size = math.floor(n + 0.5)
			fontVersion = fontVersion + 1
		end
		Print("Schriftgroesse " .. db.size)
	elseif cmd == "crit" then
		local n = Number(rest, 1, 2)
		if n then db.critScale = n end
		Print("Crits x" .. db.critScale)
	elseif cmd == "icons" then
		db.icons = not db.icons
		Print("Symbole " .. (db.icons and "an" or "aus"))
	elseif cmd == "color" or cmd == "farbe" then
		if rest == "school" or rest == "white" or rest == "gold" then
			db.color = rest
		elseif db.color == "school" then
			db.color = "white"
		elseif db.color == "white" then
			db.color = "gold"
		else
			db.color = "school"
		end
		Print("Farben: " .. db.color)
	elseif cmd == "font" then
		if FONTS[rest] then
			db.font = rest
			fontVersion = fontVersion + 1
		end
		Print("Schrift: " .. db.font)
	elseif cmd == "short" then
		db.short = not db.short
		Print("Kurze Zahlen " .. (db.short and "an" or "aus"))
	elseif cmd == "dots" then
		db.dots = not db.dots
		Print("Schaden ueber Zeit " .. (db.dots and "an" or "aus"))
	elseif cmd == "minp" then
		local n = Number(rest, 0, 50)
		if n then db.minPercent = math.floor(n) end
		Print("Mindestschaden " .. db.minPercent .. "% vom Spitzentreffer")
	elseif cmd == "min" then
		local n = Number(rest, 0, 1000000)
		if n then db.minAmount = math.floor(n) end
		Print("Mindestwert " .. db.minAmount)
	elseif cmd == "max" then
		local n = Number(rest, 5, 200)
		if n then db.maxTexts = math.floor(n) end
		Print("Hoechstens " .. db.maxTexts .. " Zahlen")
	elseif cmd == "time" then
		local n = Number(rest, 0.3, 3)
		if n then db.duration = n end
		Print("Anzeigedauer " .. db.duration .. "s")
	elseif cmd == "alpha" then
		local n = Number(rest, 0.1, 1)
		if n then db.opacity = n end
		Print("Sichtbarkeit " .. db.opacity)
	elseif cmd == "merge" then
		db.merge = not db.merge
		Print("Zusammenfassen " .. (db.merge and "an" or "aus"))
	elseif cmd == "spread" or cmd == "abstand" then
		local n = Number(rest, 0.5, 4)
		if n then db.spread = n end
		Print("Abstand x" .. db.spread)
	elseif cmd == "rise" then
		local n = Number(rest, 0, 120)
		if n then db.rise = n end
		Print("Steigen " .. db.rise .. " Pixel")
	elseif cmd == "track" then
		db.track = not db.track
		ApplyBacking()
		if not db.track then
			for plate, data in pairs(plates) do
				Mask(plate, data, false, GetTime())
			end
		end
		Print("Verfolgung " .. (db.track and "an" or "aus (Zahlen nur bei sichtbaren Plaketten ueber den Mobs)"))
	elseif cmd == "missing" or cmd == "fehlt" then
		local list = CompactSCT.Unresolved()
		if table.getn(list) == 0 then
			Print("Alle bisher gesehenen Faehigkeiten haben ein Symbol.")
		else
			Print("Ohne Symbol (" .. table.getn(list) .. "):")
			for i = 1, table.getn(list) do
				Print("  " .. list[i])
			end
		end
	elseif cmd == "status" then
		Status()
	elseif cmd == "reset" then
		local native = db.native
		for key in pairs(db) do
			db[key] = nil
		end
		LoadSettings()
		db.native = native
		fontVersion = fontVersion + 1
		Enable()
		Print("Einstellungen zurueckgesetzt.")
	else
		Help()
	end
end
