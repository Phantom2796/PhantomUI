-- PhantomUI: Totems und Begleiter ueber dem Spielerfenster: nur Symbol mit
-- Anzahl darin. Totems des Schamanen werden gezaehlt, dauerhafte Begleiter aus
-- Talenten (Woelfe, Wichtel, Teufelswache, Treants, Wasserelementar) angezeigt.
-- Das Spiel meldet Addons keine Totems. Wir erkennen das Aufstellen daran, dass
-- die Abklingzeit der Totem-Faehigkeit neu startet (AZS_SPELLS: cd/cdmax, mit
-- allen Verbesserungen). Die Dauer steht im Tooltip der Faehigkeit; den liest
-- ein unsichtbarer Tooltip im Hintergrund, die Maus muss nicht drauf.
-- Talente: "Ruf der Elemente" (twin_totems) setzt jedes Totem doppelt,
-- "Totemischer Zorn" (totemic_call) stellt alle 14 Sek. ein Totem der
-- Verbrennung von selbst auf.

local P = PhantomUI

local TOTEMS = {
	{ key = "searing_totem", icon = "Spell_Fire_SearingTotem", fallback = 30 },
	{ key = "magma_totem", icon = "Spell_Fire_SelfDestruct", fallback = 20 },
}
local AUTO_EVERY = 14
local MAX_PER_KIND = 40 -- seit AS 0.105: hoechstens 40 je Art, das aelteste faellt weg

-- Dauerhafte Begleiter aus Talenten: Talent-Schluessel, Symbol, Anzahl
local PETS = {
	SHAMAN = { { key = "stormstrike", icon = "Spell_Nature_SpiritWolf", n = 2 } },          -- Wildgeist: zwei Geisterwoelfe
	HUNTER = { { key = "tame_beast", icon = "Ability_Hunter_Pet_Wolf", n = 1 },              -- Wolf
		{ key = "bestial_wrath", icon = "Ability_Hunter_Pet_Raptor", n = 1 } },               -- Raptor
	WARLOCK = { { key = "summon_imp", icon = "Spell_Shadow_SummonImp", n = 1 },
		{ key = "felguard", icon = "Spell_Shadow_SummonInfernal", n = 1 } },                  -- Teufelswache
	DRUID = { { key = "force_of_nature", icon = "Spell_Nature_ForceOfNature", n = 2 } },     -- zwei Treants
	MAGE = { { key = "water_elemental", icon = "Spell_Frost_SummonWaterElemental", n = 1 } },
}
local myPets = {}

-- Talent geskillt? Von Hand in den Einstellungen (Allgemein -> Totems &
-- Begleiter) oder, falls das Spiel es mitschickt, aus der Faehigkeitenliste.
local function Has(spells, key)
	local t = P.DB().totems.talents
	return (t and t[key]) or spells[key] ~= nil
end

-- Talente je Klasse fuer die Einstellungen: Schluessel und Name (deutsch,
-- wird uebersetzt)
P.TOTEM_TALENTS = {
	SHAMAN = {
		{ key = "twin_totems", name = "Ruf der Elemente (jedes Totem doppelt)" },
		{ key = "totemic_call", name = "Totemischer Zorn (Totem alle 14 Sek.)" },
		{ key = "stormstrike", name = "Wildgeist (2 Geisterwölfe)" },
	},
	HUNTER = {
		{ key = "tame_beast", name = "Wolf (Meilenstein)" },
		{ key = "bestial_wrath", name = "Raptor (Schlussstein)" },
	},
	WARLOCK = {
		{ key = "summon_imp", name = "Wichtel beschwören" },
		{ key = "felguard", name = "Teufelswache beschwören" },
	},
	DRUID = { { key = "force_of_nature", name = "Naturgewalt (2 Treants)" } },
	MAGE = { { key = "water_elemental", name = "Wasserelementar beschwören" } },
}

local frame
local slots = {}
local state = {}   -- key -> { up = { Ablaufzeiten }, lastCd, duration, scanned }
local scan

-- Faehigkeiten und Talente des Laufs (nur neu aufbauen, wenn das Spiel eine
-- neue Liste schickt – spart Arbeit und Speicher-Abfall)
local cachedSrc, cachedList
local function Spells()
	local spells = AZS_SPELLS
	if spells == cachedSrc and cachedList then
		return cachedList
	end
	local list = {}
	cachedSrc, cachedList = spells, list
	if type(spells) == "table" then
		for i = 1, table.getn(spells) do
			local s = spells[i]
			if type(s) == "table" and s.key then
				list[s.key] = s
			end
		end
	end
	return list
end

-- Tooltip der Faehigkeit lesen: erste Zahl in der Beschreibung = Dauer.
-- Die 25 (Abstand, ab dem das Totem faellt) wird uebersprungen. Der Platz auf
-- der Aktionsleiste wird gemerkt, damit nicht jedes Mal gesucht werden muss.
local slotOf = {}
local function FindSlot(def)
	local want = string.lower(def.icon)
	local known = slotOf[def.key]
	if known then
		local tex = GetActionTexture(known)
		if tex and string.find(string.lower(tex), want, 1, true) then
			return known
		end
	end
	for slot = 1, 120 do
		local tex = GetActionTexture(slot)
		if tex and string.find(string.lower(tex), want, 1, true) then
			slotOf[def.key] = slot
			return slot
		end
	end
	return nil
end

local function ScanDuration(def)
	if not GetActionTexture then
		return nil
	end
	if not scan then
		scan = CreateFrame("GameTooltip", "PhantomUI_TotemScan", nil, "GameTooltipTemplate")
	end
	local slot = FindSlot(def)
	do
		if slot then
			scan:SetOwner(WorldFrame, "ANCHOR_NONE")
			scan:ClearLines()
			scan:SetAction(slot)
			local lines = scan.NumLines and scan:NumLines() or 0
			for i = 3, lines do
				local fs = getglobal("PhantomUI_TotemScanTextLeft" .. i)
				local text = fs and fs:GetText()
				if text then
					local first
					for num in string.gfind(text, "(%d+%.?%d*)") do
						local n = tonumber(num)
						if n and n ~= 25 then
							first = n
							break
						end
					end
					-- nur eine Zeile mit echter Beschreibung (lang genug)
					if first and string.len(text) > 40 then
						scan:Hide()
						return first
					end
				end
			end
			scan:Hide()
			return nil
		end
	end
	return nil
end

local function Slot(i)
	local s = slots[i]
	if s then
		return s
	end
	s = CreateFrame("Frame", nil, frame)
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	s.icon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
	s.icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
	s.edge = s:CreateTexture(nil, "BACKGROUND")
	s.edge:SetTexture(P.FLAT)
	s.edge:SetVertexColor(0, 0, 0, 1)
	s.edge:SetAllPoints(s)
	-- nur das Symbol und mittendrin die Zahl
	-- Zahl ueber die ganze Breite und zentriert, auch zweistellig
	s.count = s:CreateFontString(nil, "OVERLAY")
	s.count:SetPoint("CENTER", s, "CENTER", 1, 0)
	s.count:SetJustifyH("CENTER")
	if s.count.SetJustifyV then
		s.count:SetJustifyV("MIDDLE")
	end
	s:EnableMouse(true)
	s:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(this.name or "", 1, 1, 1)
		if this.duration then
			GameTooltip:AddLine(string.format("%s: %.0f s", P.T("Dauer"), this.duration), 0.8, 0.8, 0.8)
		end
		if this.soon then
			GameTooltip:AddLine(string.format("%.0f s", math.max(0, this.soon - GetTime())), 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	s:SetScript("OnLeave", function() GameTooltip:Hide() end)
	slots[i] = s
	return s
end

local function Layout()
	local size = P.DB().totems.size or 32
	local font = P.Font()
	local count = table.getn(TOTEMS) + table.getn(myPets)
	frame:SetWidth(math.max(1, count) * (size + 3))
	frame:SetHeight(size)
	for i = 1, count do
		local s = Slot(i)
		s:SetWidth(size)
		s:SetHeight(size)
		s.count:SetFont(font, math.max(10, math.floor(size * 0.55)), "THICKOUTLINE")
		s.count:SetWidth(size + 8)
		s.count:SetHeight(size)
	end
end

-- sichtbare Symbole von rechts nach links aufreihen
local function Place(s, index)
	local size = P.DB().totems.size or 32
	if s.index ~= index then
		s.index = index
		s:ClearAllPoints()
		s:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(index - 1) * (size + 3), 0)
	end
end

local function Update()
	local now = GetTime()
	local spells = Spells()
	local twin = Has(spells, "twin_totems") and 2 or 1
	local shown = 0
	for i = 1, table.getn(TOTEMS) do
		local def = TOTEMS[i]
		local st = state[def.key]
		if not st then
			st = { up = {}, nextAuto = 0 }
			state[def.key] = st
		end
		local sp = spells[def.key]
		local s = Slot(i)
		if sp then
			-- Dauer alle paar Sekunden neu lesen (Verbesserungen aendern sie)
			if not st.scanned or now - st.scanned > 5 then
				st.scanned = now
				st.duration = ScanDuration(def) or st.duration
			end
			local duration = st.duration or def.fallback
			local cd = tonumber(sp.cd) or 0
			-- Abklingzeit springt hoch = Totem aufgestellt
			if st.lastCd and cd > st.lastCd + 0.5 then
				for k = 1, twin do
					table.insert(st.up, now + duration)
				end
			end
			st.lastCd = cd
			-- Totemischer Zorn: alle 14 Sek. ein Totem der Verbrennung von selbst
			if def.key == "searing_totem" and Has(spells, "totemic_call") and (AZS_GetPhase and AZS_GetPhase() == "playing") then
				if st.nextAuto == 0 then
					st.nextAuto = now + AUTO_EVERY
				elseif now >= st.nextAuto then
					st.nextAuto = now + AUTO_EVERY
					table.insert(st.up, now + duration)
				end
			end
			-- mehr als 40: die aeltesten (kuerzeste Restzeit) fallen weg
			while table.getn(st.up) > MAX_PER_KIND do
				local oldest = 1
				for k = 2, table.getn(st.up) do
					if st.up[k] < st.up[oldest] then
						oldest = k
					end
				end
				table.remove(st.up, oldest)
			end
			-- abgelaufene entfernen, kuerzeste Restzeit suchen
			local soon
			for k = table.getn(st.up), 1, -1 do
				if st.up[k] <= now then
					table.remove(st.up, k)
				elseif not soon or st.up[k] < soon then
					soon = st.up[k]
				end
			end
			local n = table.getn(st.up)
			s.name = sp.spell or def.key
			s.duration, s.n, s.soon = duration, n, soon
			if n > 0 or P.unlocked then
				if s.iconPath ~= def.icon then
					s.iconPath = def.icon
					s.icon:SetTexture("Interface\\Icons\\" .. def.icon)
				end
				if s.shownN ~= n then
					s.shownN = n
					s.count:SetText(n)
				end
				shown = shown + 1
				Place(s, shown)
				s:Show()
			else
				s:Hide()
			end
		else
			st.up, st.lastCd = {}, nil
			s:Hide()
		end
	end
	-- dauerhafte Begleiter aus Talenten
	for j = 1, table.getn(myPets) do
		local def = myPets[j]
		local s = Slot(table.getn(TOTEMS) + j)
		local has = Has(spells, def.key)
		if has or P.unlocked then
			if s.iconPath ~= def.icon then
				s.iconPath = def.icon
				s.icon:SetTexture("Interface\\Icons\\" .. def.icon)
			end
			if s.shownN ~= def.n then
				s.shownN = def.n
				s.count:SetText(def.n)
			end
			s.name = spells[def.key] and spells[def.key].spell or def.key
			s.duration, s.soon = nil, nil
			shown = shown + 1
			Place(s, shown)
			s:Show()
		else
			s:Hide()
		end
	end
	-- neuer Lauf: Zaehler leeren
	local phase = AZS_GetPhase and AZS_GetPhase()
	if phase == "ready" or phase == "dead" or phase == "victory" then
		for key, st in pairs(state) do
			st.up, st.nextAuto = {}, 0
		end
	end
	if shown > 0 then
		frame:Show()
	else
		frame:Hide()
	end
end

local function Init()
	local _, class = UnitClass("player")
	myPets = PETS[class] or {}
	if not P.DB().totems.enabled or (class ~= "SHAMAN" and table.getn(myPets) == 0) then
		return
	end
	if class ~= "SHAMAN" then
		TOTEMS = {}
	end
	frame = CreateFrame("Frame", "PhantomUI_Totems", UIParent)
	frame:SetFrameStrata("LOW")
	Layout()
	-- ueber dem Spielerfenster, rechtsbuendig
	P.RegisterMover("totems", frame, "Totems & Begleiter", function(f)
		local player = getglobal("PhantomUI_Player")
		if player then
			f:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, 4)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", -200, -110)
		end
	end, {
		uniform = true,
		get = function()
			local s = P.DB().totems.size or 32
			return s, s
		end,
		set = function(w, h)
			P.DB().totems.size = P.Clamp(h, 14, 48)
		end,
	})
	P.OnApply(Layout)
	local t = 0
	local ticker = CreateFrame("Frame", "PhantomUI_TotemTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.25 then
			t = 0
			Update()
		end
	end)
end

P.OnInit(Init)

-- /pui totems: was das Addon gerade sieht (zum Pruefen)
function P.TotemDebug()
	local spells = Spells()
	for i = 1, table.getn(TOTEMS) do
		local def = TOTEMS[i]
		local sp = spells[def.key]
		P.Print(def.key .. ": " .. (sp and ("cd " .. tostring(sp.cd) .. "/" .. tostring(sp.cdmax)) or "-")
			.. ", " .. P.T("Dauer") .. " " .. tostring(ScanDuration(def) or "?"))
	end
	P.Print("twin_totems " .. tostring(spells.twin_totems ~= nil) .. ", totemic_call " .. tostring(spells.totemic_call ~= nil))
	for j = 1, table.getn(myPets) do
		P.Print(myPets[j].key .. " " .. tostring(spells[myPets[j].key] ~= nil))
	end
	local keys = ""
	for k in pairs(spells) do
		keys = keys .. k .. " "
	end
	P.Print("AZS_SPELLS: " .. keys)
end
