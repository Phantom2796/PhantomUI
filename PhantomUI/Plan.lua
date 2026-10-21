-- PhantomUI: Faehigkeiten-Plan. Vor dem Lauf im Editor anklicken, welche
-- Faehigkeiten man in welcher Reihenfolge nehmen will; das wird je Klasse
-- gespeichert und im Spiel als kleines Fenster angezeigt. Schon genommene
-- Faehigkeiten verschwinden aus dem Fenster, sobald man sie hat (AZS_SPELLS),
-- Gegenstaende, sobald man sie traegt.

local P = PhantomUI

local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.5, 0, 0.25 },
	ROGUE = { 0.5, 0.75, 0, 0.25 },
	DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local GREEN = { 0.2, 0.9, 0.3 }
-- Reiter im Editor und Zeilen im Fenster: Faehigkeiten, dann Gegenstaende
local CATS = { "ABILITY", "NECK", "RING", "TRINKET" }

local L = {
	enUS = { ABILITY = "Abilities", NECK = "Neck", RING = "Ring", TRINKET = "Trinket", editItems = "Click items in the order you want them.", base = "Base value - higher rarity raises it", title = "Ability plan", edit = "Click abilities in the order you want to take them.", clear = "Clear", done = "Done", empty = "Plan: click to choose abilities", owned = "already taken", hint = "Left click: edit  -  Right click: hide" },
	deDE = { ABILITY = "Fähigkeiten", NECK = "Hals", RING = "Ring", TRINKET = "Schmuck", editItems = "Gegenstände in der Reihenfolge anklicken, in der du sie willst.", base = "Grundwert – höhere Seltenheit verstärkt ihn", title = "Fähigkeiten-Plan", edit = "Fähigkeiten in der Reihenfolge anklicken, in der du sie nehmen willst.", clear = "Leeren", done = "Fertig", empty = "Plan: klicken zum Auswählen", owned = "schon genommen", hint = "Linksklick: bearbeiten  -  Rechtsklick: ausblenden" },
}
local function T(key)
	-- eigene Texte in der PhantomUI-Sprache: Deutsch/Englisch hier, alle
	-- anderen Sprachen ueber die Uebersetzungen in Locale.lua
	local lang = P.UILang()
	local t = L[lang]
	if t and t[key] then
		return t[key]
	end
	if L.deDE[key] then
		return P.T(L.deDE[key])
	end
	return L.enUS[key]
end

local function Lang()
	return PhantomUI_Lang and PhantomUI_Lang() or "enUS"
end

local function PlayerClass()
	local _, class = UnitClass("player")
	return class or "WARRIOR"
end

-- Auswahl je Reiter: Faehigkeiten der Klasse oder Gegenstaende eines Platzes
-- Legendaere Halsketten: das Spiel hat eine pro Faehigkeit ("gestaltet X
-- neu"), jede Klasse also ihre eigenen. Name und Werte der einzelnen Ketten
-- stehen nicht lesbar in den Spieldaten, darum hier je Faehigkeit der Klasse
-- ein Eintrag mit deren Symbol und dem Text des Spiels.
local legendaryCache = {}
local function NeckWithLegendaries(class, items)
	if legendaryCache[class] then
		return legendaryCache[class]
	end
	local list = {}
	for i = 1, table.getn(items) do
		table.insert(list, items[i])
	end
	local spells = PhantomUI_PlanData and PhantomUI_PlanData[class] or {}
	local tmpl = PhantomUI_LegendaryName or {}
	for i = 1, table.getn(spells) do
		local sp = spells[i]
		local names = {}
		for lang, spell in pairs(sp.names or {}) do
			local t = tmpl[lang] or tmpl.enUS or "Legendary amulet · remakes {spell}"
			names[lang] = (string.gsub(t, "{spell}", spell))
		end
		table.insert(list, { id = "legendary_" .. sp.id, icon = sp.icon, names = names, q = 5, legendary = true,
			dyn = sp.dyn, dynNames = sp.names })
	end
	legendaryCache[class] = list
	return list
end

local function Choices(class, cat)
	if cat == "ABILITY" then
		return PhantomUI_PlanData and PhantomUI_PlanData[class] or {}
	end
	local items = PhantomUI_PlanItems and PhantomUI_PlanItems[cat] or {}
	if cat == "NECK" then
		return NeckWithLegendaries(class, items)
	end
	return items
end

local function Ability(class, id, cat)
	local list = Choices(class, cat or "ABILITY")
	if not list then
		return nil
	end
	for i = 1, table.getn(list) do
		if list[i].id == id then
			return list[i]
		end
	end
	return nil
end

-- Symbol; bei neuen Zaubern (dyn) das echte von der Aktionsleiste, sobald da
local function IconPath(a)
	if a.dyn and PhantomUI.ActionIconFor then
		local names = a.dynNames or a.names or {}
		local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
		local tex = PhantomUI.ActionIconFor(names[lang] or names.enUS)
		if tex then
			return tex
		end
	end
	return "Interface\\Icons\\" .. a.icon
end

local function NameOf(a)
	return a.names[Lang()] or a.names.enUS or a.id
end

-- Wirkung eines Gegenstands (Faehigkeiten haben keine)
-- Tooltip wie bei einem echten Gegenstand: Name in der Qualitaetsfarbe,
-- Platz weiss, Wirkung gruen ("Equip: ..."), darunter der Hinweis grau.
local QUALITY = {
	[2] = { 0.12, 1, 0 },        -- gruen
	[3] = { 0, 0.44, 0.87 },     -- blau
	[4] = { 0.64, 0.21, 0.93 },  -- lila
	[5] = { 1, 0.5, 0 },         -- orange (legendaer)
}
local SLOT_NAME = { NECK = "Hals", RING = "Finger", TRINKET = "Schmuck" }
local function ItemTooltip(b)
	if not b.cat or b.cat == "ABILITY" then
		GameTooltip:SetText(b.name or "", 1, 1, 1)
		return
	end
	local c = QUALITY[b.q or 3] or QUALITY[3]
	GameTooltip:SetText(b.name or "", c[1], c[2], c[3])
	GameTooltip:AddLine(P.T(SLOT_NAME[b.cat] or b.cat), 1, 1, 1)
	if b.desc then
		local equip = ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"
		for line in string.gfind(b.desc, "[^\n]+") do
			GameTooltip:AddLine(equip .. " " .. line, 0.12, 1, 0.12, 1)
		end
		GameTooltip:AddLine(T("base"), 0.6, 0.6, 0.65)
	end
end

local function DescOf(a)
	if not a or not a.desc then
		return nil
	end
	return a.desc[Lang()] or a.desc.enUS
end

-- Plan je Klasse; Gegenstaende unter "KLASSE:PLATZ"
local function Plan(class, cat)
	local db = P.DB().plan
	local key = class
	if cat and cat ~= "ABILITY" then
		key = class .. ":" .. cat
	end
	db.data[key] = db.data[key] or {}
	return db.data[key]
end

local function IndexIn(list, id)
	for i = 1, table.getn(list) do
		if list[i] == id then
			return i
		end
	end
	return nil
end

-- Faehigkeiten, die der Held in diesem Lauf schon hat.
local function Owned()
	local owned = {}
	local spells = AZS_SPELLS
	if type(spells) == "table" then
		for i = 1, table.getn(spells) do
			local s = spells[i]
			if type(s) == "table" and s.key then
				owned[s.key] = true
			end
		end
	end
	return owned
end

-- Getragene Gegenstaende (Hals 2, Ringe 11/12, Schmuck 13/14): Symbol und Name
-- aus den Ausruestungsplaetzen. Liefert das Spiel dort nichts, bleibt die Liste
-- leer und die Gegenstaende bleiben einfach im Plan stehen.
local GEAR_SLOTS = { NECK = { 2 }, RING = { 11, 12 }, TRINKET = { 13, 14 } }
-- Aufwertungen haengen eine roemische Stufe an ("... II", "... X", "... X+"):
-- fuer den Vergleich weglassen
local function BaseName(name)
	if not name then
		return nil
	end
	local base = string.gsub(name, "%s+[IVXL]+%+*$", "")
	return base
end
-- Ist das eine der normalen Halsketten (Name in irgendeiner Sprache)?
local knownNecks
local function KnownNeck(name)
	if not knownNecks then
		knownNecks = {}
		local list = PhantomUI_PlanItems and PhantomUI_PlanItems.NECK or {}
		for i = 1, table.getn(list) do
			for lang, n in pairs(list[i].names or {}) do
				knownNecks[n] = true
			end
		end
	end
	return knownNecks[name]
end

local function Worn(cat)
	local worn = { icons = {}, names = {} }
	local slots = GEAR_SLOTS[cat]
	if not slots then
		return worn
	end
	for i = 1, table.getn(slots) do
		local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slots[i])
		if tex then
			local _, _, file = string.find(string.lower(tex), "([^\\]+)$")
			worn.icons[file or string.lower(tex)] = true
		end
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slots[i])
		if link then
			local _, _, name = string.find(link, "%[(.-)%]")
			if name then
				worn.names[BaseName(name)] = true
			end
			-- Legendaere Kette: orange UND keine der normalen Halsketten (auch
			-- normale Ketten koennen als legendaere Seltenheit, also orange, fallen)
			if cat == "NECK" and name and ((PhantomUI_LegendaryNecks and PhantomUI_LegendaryNecks[BaseName(name)])
				or (string.find(string.lower(link), "|cffff8000", 1, true) and not KnownNeck(BaseName(name)))) then
				worn.legendary = true
			end
		end
	end
	return worn
end

local function IsWorn(worn, a)
	if not a then
		return false
	end
	if a.legendary then
		return worn.legendary and true or false
	end
	-- Name ist eindeutig; das Symbol nur, wenn das Spiel keine Namen liefert
	if next(worn.names) then
		return worn.names[BaseName(NameOf(a))] and true or false
	end
	return a.icon and worn.icons[string.lower(a.icon)] and true or false
end

------------------------------------------------------------------------
-- Knopf mit Symbol (fuer Fenster und Editor)
------------------------------------------------------------------------

local function IconButton(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(size)
	b:SetHeight(size)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetTexture(P.FLAT)
	b.edge:SetAllPoints(b)
	b.edge:SetVertexColor(0, 0, 0, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.shade = b:CreateTexture(nil, "OVERLAY")
	b.shade:SetTexture(P.FLAT)
	b.shade:SetAllPoints(b.icon)
	b.shade:SetVertexColor(0, 0, 0, 0.55)
	b.shade:Hide()
	b.num = b:CreateFontString(nil, "OVERLAY")
	b.num:SetFont(P.Font(), math.max(9, math.floor(size * 0.38)), "OUTLINE")
	b.num:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -1)
	b:SetHighlightTexture(P.FLAT)
	local hl = b:GetHighlightTexture()
	hl:SetVertexColor(1, 1, 1, 0.18)
	hl:SetAllPoints(b.icon)
	return b
end

------------------------------------------------------------------------
-- Editor
------------------------------------------------------------------------

local editor, editorClass
local editorCat = "ABILITY"
local editorButtons, classTabs, catTabs = {}, {}, {}
local SIZE, GAP, COLS = 36, 4, 7
local GRID_TOP = -110
local window
local RefreshWindow

local function RefreshEditor()
	if not editor or not editor:IsShown() then
		return
	end
	local list = Choices(editorClass, editorCat)
	local plan = Plan(editorClass, editorCat)
	for i = 1, table.getn(list) do
		local a = list[i]
		local b = editorButtons[i]
		if not b then
			b = IconButton(editor, SIZE)
			editorButtons[i] = b
			b:SetScript("OnClick", function()
				local p = Plan(editorClass, editorCat)
				local idx = IndexIn(p, this.id)
				if idx then
					table.remove(p, idx)
				else
					table.insert(p, this.id)
				end
				RefreshEditor()
				RefreshWindow()
			end)
			b:SetScript("OnEnter", function()
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				ItemTooltip(this)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		local col = math.mod(i - 1, COLS)
		local row = math.floor((i - 1) / COLS)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", editor, "TOPLEFT", 16 + col * (SIZE + GAP), GRID_TOP - row * (SIZE + GAP))
		b.id = a.id
		b.name = NameOf(a)
		b.desc = DescOf(a)
		b.q = a.q
		b.cat = editorCat
		b.icon:SetTexture(IconPath(a))
		local idx = IndexIn(plan, a.id)
		if idx then
			b.edge:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
			b.num:SetText(idx)
			b.shade:Hide()
		else
			b.edge:SetVertexColor(0, 0, 0, 1)
			b.num:SetText("")
			b.shade:Show()
		end
		b:Show()
	end
	for i = table.getn(list) + 1, table.getn(editorButtons) do
		editorButtons[i]:Hide()
	end
	local rows = math.ceil(table.getn(list) / COLS)
	editor:SetHeight(-GRID_TOP + rows * (SIZE + GAP) + 44)
	for i = 1, table.getn(classTabs) do
		local tab = classTabs[i]
		if tab.class == editorClass then
			tab.edge:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
			tab.shade:Hide()
		else
			tab.edge:SetVertexColor(0, 0, 0, 1)
			tab.shade:Show()
		end
	end
	for i = 1, table.getn(catTabs) do
		local tab = catTabs[i]
		tab.text:SetText(T(tab.cat))
		if tab.cat == editorCat then
			tab:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
			tab:SetBackdropColor(0.25, 0.12, 0.38, 1)
		else
			tab:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
			tab:SetBackdropColor(0.12, 0.06, 0.18, 1)
		end
	end
	editor.title:SetText(T("title"))
	editor.help:SetText(editorCat == "ABILITY" and T("edit") or T("editItems"))
	editor.clear.text:SetText(T("clear"))
	editor.done.text:SetText(T("done"))
end

local function SmallButton(parent, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width)
	b:SetHeight(22)
	b:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
	b:SetBackdropColor(0.12, 0.06, 0.18, 1)
	b:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	b.text = b:CreateFontString(nil, "OVERLAY")
	b.text:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 11, "OUTLINE")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetTextColor(P.ACCENT[1] + 0.2, P.ACCENT[2] + 0.25, P.ACCENT[3] + 0.08)
	b:SetScript("OnEnter", function() this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1) end)
	b:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1) end)
	b:SetScript("OnClick", onClick)
	return b
end

local function BuildEditor()
	editor = CreateFrame("Frame", "PhantomUI_PlanEditor", UIParent)
	editor:SetWidth(16 * 2 + COLS * SIZE + (COLS - 1) * GAP)
	editor:SetFrameStrata("DIALOG")
	-- oeffnet unter dem Zielfenster, nach rechts versetzt (Mitte unter seiner rechten Kante)
	editor:SetClampedToScreen(true)
	local target = getglobal("PhantomUI_Target")
	if target then
		editor:SetPoint("TOP", target, "BOTTOMRIGHT", 0, -30)
	else
		editor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -320, 40)
	end
	P.Box(editor, 0.97)
	editor:EnableMouse(true)
	editor:SetMovable(true)
	editor:RegisterForDrag("LeftButton")
	editor:SetScript("OnDragStart", function() this:StartMoving() end)
	editor:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	if UISpecialFrames then
		table.insert(UISpecialFrames, "PhantomUI_PlanEditor")
	end

	editor.title = editor:CreateFontString(nil, "OVERLAY")
	editor.title:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 14, "OUTLINE")
	editor.title:SetTextColor(P.ACCENT[1] + 0.1, P.ACCENT[2] + 0.1, P.ACCENT[3])
	editor.title:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -12)

	-- Klassen zum Umschalten (Plan je Klasse)
	for i = 1, table.getn(CLASS_ORDER) do
		local class = CLASS_ORDER[i]
		local tab = IconButton(editor, 22)
		tab:SetPoint("TOPLEFT", editor, "TOPLEFT", 16 + (i - 1) * 25, -34)
		tab.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		local c = CLASS_COORDS[class]
		tab.icon:SetTexCoord(c[1] + 0.02, c[2] - 0.02, c[3] + 0.02, c[4] - 0.02)
		tab.class = class
		tab:SetScript("OnClick", function()
			editorClass = this.class
			RefreshEditor()
		end)
		classTabs[i] = tab
	end

	-- Reiter: Faehigkeiten / Hals / Ring / Schmuck
	local catW = (editor:GetWidth() - 32 - 3 * 2) / 4
	for i = 1, table.getn(CATS) do
		local tab = SmallButton(editor, catW, function()
			editorCat = this.cat
			RefreshEditor()
		end)
		tab:SetHeight(20)
		tab:SetPoint("TOPLEFT", editor, "TOPLEFT", 16 + (i - 1) * (catW + 2), -62)
		tab.text:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
		tab.cat = CATS[i]
		tab:SetScript("OnLeave", function()
			if this.cat ~= editorCat then
				this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
			end
		end)
		catTabs[i] = tab
	end

	editor.help = editor:CreateFontString(nil, "OVERLAY")
	editor.help:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 9, "OUTLINE")
	editor.help:SetTextColor(0.6, 0.6, 0.65)
	editor.help:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -88)
	editor.help:SetWidth(editor:GetWidth() - 32)
	editor.help:SetJustifyH("LEFT")

	local half = (editor:GetWidth() - 38) / 2
	editor.clear = SmallButton(editor, half, function()
		local p = Plan(editorClass, editorCat)
		for i = table.getn(p), 1, -1 do
			table.remove(p, i)
		end
		RefreshEditor()
		RefreshWindow()
	end)
	editor.clear:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 16, 12)
	editor.done = SmallButton(editor, half, function() editor:Hide() end)
	editor.done:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -16, 12)
	editor:SetScript("OnShow", RefreshEditor)
	editor:Hide()
end

function P.TogglePlanEditor()
	if not editor then
		BuildEditor()
	end
	if editor:IsShown() then
		editor:Hide()
	else
		editorClass = PlayerClass()
		if not editorCat then
			editorCat = "ABILITY"
		end
		editor:Show()
		RefreshEditor()
	end
end

------------------------------------------------------------------------
-- Kleines Fenster im Spiel
------------------------------------------------------------------------

local windowButtons = {}

function RefreshWindow()
	if not window then
		return
	end
	local db = P.DB().plan
	local class = PlayerClass()
	local size = db.size
	local step = size - 1
	if not db.enabled and not P.unlocked then
		window:Hide()
		return
	end
	window:Show()
	local owned = Owned()
	local used, rows, widest, planned = 0, 0, 0, 0
	for c = 1, table.getn(CATS) do
		local cat = CATS[c]
		local plan = Plan(class, cat)
		local n = table.getn(plan)
		planned = planned + n
		local worn = cat ~= "ABILITY" and Worn(cat) or nil
		-- Reihenfolge = Rangliste: Traegt man schon so viele Teile aus dem Plan,
		-- wie es Plaetze gibt (Hals 1, Ring/Schmuck 2), fallen alle schlechteren
		-- darunter weg. Bessere bleiben stehen.
		local slotCount = GEAR_SLOTS[cat] and table.getn(GEAR_SLOTS[cat]) or 0
		local wornAbove = 0
		local col = 0
		for i = 1, n do
			local a = Ability(class, plan[i], cat)
			-- Schon genommen bzw. getragen: verschwindet aus dem Fenster,
			-- die uebrigen ruecken auf (Nummer bleibt die aus dem Plan)
			local have
			if cat == "ABILITY" then
				have = owned[plan[i]] and true or false
			else
				have = IsWorn(worn, a)
				-- traegt man eine legendaere Kette, ist jede normale schlechter
				if not have and worn.legendary and a and not a.legendary then
					have = true
				elseif have then
					wornAbove = wornAbove + 1
				elseif slotCount > 0 and wornAbove >= slotCount and not (a and a.legendary) then
					-- (legendaere Ketten sind immer besser als normale und bleiben)
					have = true -- schlechter als alles, was man schon traegt
				end
			end
			if not have then
				used = used + 1
				col = col + 1
				local b = windowButtons[used]
				if not b then
					b = IconButton(window, size)
					windowButtons[used] = b
					b:SetScript("OnClick", function()
						if arg1 == "RightButton" then
							P.DB().plan.enabled = false
							RefreshWindow()
						else
							editorCat = this.cat or "ABILITY"
							P.TogglePlanEditor()
						end
					end)
					b:SetScript("OnEnter", function()
						GameTooltip:SetOwner(this, "ANCHOR_TOP")
						ItemTooltip(this)
						if this.owned then
							GameTooltip:AddLine(T("owned"), GREEN[1], GREEN[2], GREEN[3])
						end
						GameTooltip:AddLine(T("hint"), 0.7, 0.7, 0.7)
						GameTooltip:Show()
					end)
					b:SetScript("OnLeave", function() GameTooltip:Hide() end)
				end
				b.cat = cat
				-- Groesse/Schrift/Platz nur bei Aenderung (einmal pro Sekunde neu
				-- setzen war unnoetige Arbeit fuer das Spiel)
				local font = P.Font()
				local key = size .. ":" .. font .. ":" .. col .. ":" .. rows
				if b.layoutKey ~= key then
					b.layoutKey = key
					b:SetWidth(size)
					b:SetHeight(size)
					b.num:SetFont(font, math.max(9, math.floor(size * 0.38)), "OUTLINE")
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", window, "TOPLEFT", (col - 1) * step, -rows * step)
				end
				local iconPath = a and IconPath(a) or "Interface\\Icons\\INV_Misc_QuestionMark"
				if b.iconPath ~= iconPath then
					b.iconPath = iconPath
					b.icon:SetTexture(iconPath)
				end
				if a then
					b.name = NameOf(a)
					b.desc = DescOf(a)
					b.q = a.q
				else
					b.desc = nil
					b.name = plan[i]
				end
				b.num:SetText(i)
				b.owned = false
				b.edge:SetVertexColor(0, 0, 0, 1)
				b.shade:Hide()
				if cat == "ABILITY" then
					b.edge:SetVertexColor(0, 0, 0, 1)
					b.shade:Hide()
					b.num:SetTextColor(1, 1, 1)
				else
					b.edge:SetVertexColor(0, 0, 0, 1)
					b.shade:Hide()
					b.num:SetTextColor(0.8, 0.65, 1)
				end
				b:Show()
			end
		end
		if col > 0 then
			rows = rows + 1
			if col > widest then
				widest = col
			end
		end
	end
	for i = used + 1, table.getn(windowButtons) do
		windowButtons[i]:Hide()
	end
	-- Leerer Plan: Hinweis-Feld, das den Editor oeffnet
	if used == 0 and planned > 0 and not P.unlocked then
		-- alles aus dem Plan genommen: Fenster weg (der Plan-Knopf bleibt)
		window.empty:Hide()
		window:Hide()
		return
	elseif used == 0 then
		window.empty:Show()
		window.emptyText:SetText(T("empty"))
		window:SetWidth(math.max(120, (window.emptyText:GetStringWidth() or 104) + 16))
		window:SetHeight(size)
	else
		window.empty:Hide()
		-- Nur die erste Zeile zaehlt fuer Platz und Anker: weitere Zeilen
		-- (Hals, Ring, Schmuck) haengen darunter und klappen nach unten auf.
		window:SetWidth(widest * step + 1)
		window:SetHeight(size)
		window.rowsShown = rows
	end
end

local function Init()
	local db = P.DB().plan
	window = CreateFrame("Frame", "PhantomUI_Plan", UIParent)
	window:SetFrameStrata("LOW")
	window.empty = CreateFrame("Button", nil, window)
	window.empty:SetAllPoints(window)
	P.Box(window.empty, 0.85)
	window.emptyText = window.empty:CreateFontString(nil, "OVERLAY")
	window.emptyText:SetFont(P.Font(), 10, "OUTLINE")
	window.emptyText:SetTextColor(0.75, 0.75, 0.8)
	window.emptyText:SetPoint("CENTER", window.empty, "CENTER", 0, 0)
	window.empty:SetScript("OnClick", function() P.TogglePlanEditor() end)

	-- Kleiner "Plan"-Knopf unter Aktionsleiste/EP-Leiste: oeffnet immer den
	-- Editor, auch wenn das Fenster leer ist (alles schon genommen)
	local pb = CreateFrame("Button", "PhantomUI_PlanButton", UIParent)
	pb:SetFrameStrata("LOW")
	pb:SetWidth(44)
	pb:SetHeight(14)
	P.Box(pb, 0.85)
	pb.text = pb:CreateFontString(nil, "OVERLAY")
	pb.text:SetPoint("CENTER", pb, "CENTER", 0, 0)
	-- Schrift vor dem Text setzen (der neue Client verlangt das)
	pb.text:SetFont(P.Font(), 9, "OUTLINE")
	pb.text:SetText("Plan")
	pb.text:SetTextColor(0.85, 0.75, 1)
	pb:RegisterForClicks("LeftButtonUp")
	pb:SetScript("OnClick", function() P.TogglePlanEditor() end)
	pb:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(T("title"))
		GameTooltip:Show()
	end)
	pb:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(0, 0, 0, 1)
		GameTooltip:Hide()
	end)
	local function StylePlanButton()
		pb.text:SetFont(P.Font(), 9, "OUTLINE")
	end
	StylePlanButton()
	P.OnApply(StylePlanButton)
	P.RegisterMover("planbutton", pb, "Plan-Knopf", function(f)
		local xp = getglobal("PhantomUI_XP")
		local bar = getglobal("PhantomUI_ActionBar")
		if xp and P.DB().xp.enabled then
			f:SetPoint("TOP", xp, "BOTTOM", 0, -3)
		elseif bar then
			f:SetPoint("TOP", bar, "BOTTOM", 0, -3)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
		end
	end)

	RefreshWindow()
	P.RegisterMover("plan", window, "Plan", function(f)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -270)
	end, {
		uniform = true,
		get = function()
			local d = P.DB().plan
			return d.size, d.size
		end,
		set = function(w, h)
			P.DB().plan.size = P.Clamp(h, 16, 56)
		end,
	})

	-- Waehrend der Kartenauswahl: Plan groesser unten in der Mitte, auf der
	-- obersten Ebene (der Auswahlbildschirm des Spiels liegt sonst darueber).
	local choosing = false
	local function ChoiceMode(on)
		if on == choosing then
			return
		end
		choosing = on
		if on then
			local scale = 1.35
			local rows = window.rowsShown or 1
			window:SetFrameStrata("TOOLTIP")
			window:SetScale(scale)
			window:ClearAllPoints()
			window:SetPoint("TOP", UIParent, "BOTTOM", 0, rows * (P.DB().plan.size - 1) + 70 / scale)
		else
			window:SetFrameStrata("LOW")
			window:SetScale(1)
			P.Place("plan")
		end
	end

	-- AZS_SPELLS aendert sich beim Waehlen: einmal pro Sekunde nachsehen.
	local t, c = 0, 0
	local ticker = CreateFrame("Frame", "PhantomUI_PlanTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		c = c + arg1
		if c > 0.2 then
			c = 0
			local phase = AZS_GetPhase and AZS_GetPhase()
			ChoiceMode(P.DB().plan.choice and phase == "choosing" and not P.unlocked)
		end
		if t > 1 then
			t = 0
			RefreshWindow()
		end
	end)
	P.OnApply(RefreshWindow)
end

P.OnInit(Init)

SLASH_PHANTOMPLAN1 = "/plan"
SlashCmdList["PHANTOMPLAN"] = function()
	P.TogglePlanEditor()
end

-- /pui gear: was das Spiel fuer Hals, Ringe und Schmuck meldet (zum Pruefen)
function PhantomUI.GearDebug()
	for _, slot in ipairs({ 2, 11, 12, 13, 14 }) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		PhantomUI.Print(slot .. ": " .. (link and string.gsub(link, "|", "||") or "-"))
	end
end

-- Symbol eines Zaubers von der Aktionsleiste holen (fuer neue Zauber, deren
-- Symbol PhantomUI noch nicht kennt): unsichtbarer Tooltip liest die Namen.
local actionIcons, actionScanAt = {}, -100
local actionTip
function PhantomUI.ActionIconFor(name)
	if not name or not GetActionTexture then
		return nil
	end
	if actionIcons[name] then
		return actionIcons[name]
	end
	local now = GetTime and GetTime() or 0
	if now - actionScanAt < 5 then
		return nil
	end
	actionScanAt = now
	if not actionTip then
		actionTip = CreateFrame("GameTooltip", "PhantomUI_ActionScan", nil, "GameTooltipTemplate")
	end
	for slot = 1, 120 do
		local tex = GetActionTexture(slot)
		if tex then
			actionTip:SetOwner(WorldFrame, "ANCHOR_NONE")
			actionTip:ClearLines()
			actionTip:SetAction(slot)
			local fs = getglobal("PhantomUI_ActionScanTextLeft1")
			local n = fs and fs:GetText()
			if n and n ~= "" then
				actionIcons[n] = tex
			end
		end
	end
	actionTip:Hide()
	return actionIcons[name]
end
