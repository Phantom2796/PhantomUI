-- PhantomUI: Totem-Zaehler fuer Schamanen (neben den Buffs).
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
	s.count = s:CreateFontString(nil, "OVERLAY")
	s.count:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 2)
	s.time = s:CreateFontString(nil, "OVERLAY")
	s.time:SetPoint("TOP", s, "BOTTOM", 0, -2)
	s:EnableMouse(true)
	s:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText(this.name or "", 1, 1, 1)
		if this.duration then
			GameTooltip:AddLine(string.format("%s: %d", P.T("Totems"), this.n or 0), 0.8, 0.8, 0.8)
			GameTooltip:AddLine(string.format("%s: %.0f s", P.T("Dauer"), this.duration), 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	s:SetScript("OnLeave", function() GameTooltip:Hide() end)
	slots[i] = s
	return s
end

local function Layout()
	local size = P.DB().auras.size or 30
	local font = P.Font()
	frame:SetWidth(table.getn(TOTEMS) * (size + 4))
	frame:SetHeight(size + 14)
	for i = 1, table.getn(TOTEMS) do
		local s = Slot(i)
		s:SetWidth(size)
		s:SetHeight(size)
		s:ClearAllPoints()
		s:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(i - 1) * (size + 4), 0)
		s.count:SetFont(font, math.max(10, math.floor(size * 0.5)), "OUTLINE")
		s.time:SetFont(font, math.max(9, math.floor(size * 0.36)), "OUTLINE")
	end
end

local function Update()
	local now = GetTime()
	local spells = Spells()
	local twin = spells.twin_totems and 2 or 1
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
			if def.key == "searing_totem" and spells.totemic_call and (AZS_GetPhase and AZS_GetPhase() == "playing") then
				if st.nextAuto == 0 then
					st.nextAuto = now + AUTO_EVERY
				elseif now >= st.nextAuto then
					st.nextAuto = now + AUTO_EVERY
					table.insert(st.up, now + duration)
				end
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
			s.duration, s.n = duration, n
			if n > 0 or P.unlocked then
				if s.iconPath ~= def.icon then
					s.iconPath = def.icon
					s.icon:SetTexture("Interface\\Icons\\" .. def.icon)
				end
				s.count:SetText(n > 0 and n or "")
				s.time:SetText(soon and math.floor(soon - now + 0.5) or "")
				s:Show()
				shown = shown + 1
			else
				s:Hide()
			end
		else
			st.up, st.lastCd = {}, nil
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
	if class ~= "SHAMAN" or not P.DB().totems.enabled then
		return
	end
	frame = CreateFrame("Frame", "PhantomUI_Totems", UIParent)
	frame:SetFrameStrata("LOW")
	Layout()
	P.RegisterMover("totems", frame, "Totems", function(f)
		local buffs = getglobal("PhantomUI_Buffs")
		if buffs then
			f:SetPoint("TOPRIGHT", buffs, "TOPLEFT", -8, 0)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", -120, -95)
		end
	end)
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
end
