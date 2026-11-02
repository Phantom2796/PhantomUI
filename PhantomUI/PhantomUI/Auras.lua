-- PhantomUI: Buffs und Debuffs wie im aktuellen WoW.
--  * beschnittenes Symbol mit 1-Pixel-Rand (Debuffs in der Farbe ihrer Art)
--  * Restzeit als Uhr (dunkler Zeiger) im Symbol und als ganze Zahl in der Mitte
--  * Stapel klein unten rechts
--  * eine Reihe Buffs mittig ueber der Ressourcenleiste, Debuffs eine Reihe darueber
-- Die Knoepfe bleiben die des Spiels; wir stellen sie nur neu auf.

local P = PhantomUI
local GAP = -1 -- buendig, Raender ueberlappen

local container
local totals = {} -- volle Dauer je Buff (das Spiel liefert nur die Restzeit)

local BUFFS, DEBUFFS = {}, {}
for i = 0, 15 do
	table.insert(BUFFS, { name = "BuffButton" .. i })
end
table.insert(BUFFS, { name = "TempEnchant1", enchant = 1 })
table.insert(BUFFS, { name = "TempEnchant2", enchant = 2 })
for i = 16, 23 do
	table.insert(DEBUFFS, { name = "BuffButton" .. i, debuff = true })
end

------------------------------------------------------------------------

local function TimeLeft(button, entry)
	if entry.enchant then
		if not GetWeaponEnchantInfo then
			return 0
		end
		local hasMain, mainLeft, _, hasOff, offLeft = GetWeaponEnchantInfo()
		local ms
		if entry.enchant == 1 then
			ms = hasMain and mainLeft
		else
			ms = hasOff and offLeft
		end
		return ms and ms / 1000 or 0
	end
	if button.buffIndex and GetPlayerBuffTimeLeft then
		return GetPlayerBuffTimeLeft(button.buffIndex) or 0
	end
	return 0
end

local function Clock(seconds)
	if seconds >= 3600 then
		return math.ceil(seconds / 3600) .. "h"
	elseif seconds >= 60 then
		return math.ceil(seconds / 60) .. "m"
	end
	return tostring(math.ceil(seconds))
end

-- Ablaufanzeige: eine dunkle Flaeche, die von oben ueber das Symbol waechst,
-- je mehr Zeit vergangen ist. Das Uhr-Modell des Classic-Clients drehte sich
-- nach Groessenaenderungen und Ladebildschirmen nicht mehr um die Mitte.
local clockButtons = {}
local function FreshClock(button)
	if button.puiClock then
		button.puiClock:Hide()
		button.puiClock = nil
	end
	if not button.puiShade then
		local f = CreateFrame("Frame", nil, button)
		f:SetAllPoints(button)
		f:SetFrameLevel(button:GetFrameLevel() + 1)
		f.tex = f:CreateTexture(nil, "OVERLAY")
		f.tex:SetTexture(P.FLAT)
		f.tex:SetVertexColor(0, 0, 0, 0.6)
		f.tex:Hide()
		button.puiShade = f
		if button.puiHolder then
			button.puiHolder:SetFrameLevel(f:GetFrameLevel() + 2)
		end
	end
	button.puiStart = nil
end
-- Anteil 0..1 der vergangenen Zeit dunkel zeichnen
local function Shade(button, done)
	local f = button.puiShade
	if not f then
		return
	end
	local h = (button:GetHeight() or 0) - 2
	if not done or done <= 0 or h <= 0 then
		f.tex:Hide()
		return
	end
	if done > 1 then
		done = 1
	end
	f.tex:ClearAllPoints()
	f.tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	f.tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
	f.tex:SetHeight(math.max(1, h * done))
	f.tex:Show()
end
local function FreshClocks()
	for button in pairs(clockButtons) do
		FreshClock(button)
	end
end
local clockEvents = CreateFrame("Frame")
clockEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
clockEvents:SetScript("OnEvent", FreshClocks)
-- neue Runde ohne Ladebildschirm: ebenfalls frisch
local lastPhase, phaseWait = nil, 0
clockEvents:SetScript("OnUpdate", function()
	phaseWait = phaseWait + arg1
	if phaseWait < 0.5 then
		return
	end
	phaseWait = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	if phase ~= lastPhase then
		if phase == "ready" then
			FreshClocks()
		end
		lastPhase = phase
	end
end)
P.FreshAuraClocks = FreshClocks

local function Style(entry)
	local name = entry.name
	local button = getglobal(name)
	if not button then
		return
	end
	local size = P.DB().auras.size
	local font = P.Font()

	button:SetWidth(size)
	button:SetHeight(size)

	if not button.puiEdge then
		local edge = CreateFrame("Frame", nil, button:GetParent() or UIParent)
		edge.tex = edge:CreateTexture(nil, "BACKGROUND")
		edge.tex:SetTexture(P.FLAT)
		edge.tex:SetAllPoints(edge)
		button.puiEdge = edge

		-- Uhr: dunkler Zeiger ueber dem Symbol, wie bei Abklingzeiten
		local holder = CreateFrame("Frame", nil, button)
		holder:SetAllPoints(button)
		holder:SetFrameLevel(button:GetFrameLevel() + 3)
		button.puiTime = holder:CreateFontString(nil, "OVERLAY")
		button.puiTime:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.puiHolder = holder
		clockButtons[button] = true
		FreshClock(button)
	end
	button.puiEdge:SetParent(button:GetParent() or UIParent)
	button.puiEdge:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
	button.puiEdge:ClearAllPoints()
	button.puiEdge:SetAllPoints(button)
	button.puiTime:SetFont(font, math.max(9, math.floor(size * 0.42)), "OUTLINE")

	local icon = getglobal(name .. "Icon")
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	end
	local border = getglobal(name .. "Border")
	if border then
		border:SetAlpha(0)
	end
	local count = getglobal(name .. "Count")
	if count then
		count:SetFont(font, math.max(8, math.floor(size * 0.32)), "OUTLINE")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
		if button.puiHolder then
			count:SetParent(button.puiHolder)
		end
	end
	-- Die Zeit des Spiels unter dem Symbol ausblenden: wir zeigen sie innen.
	local duration = getglobal(name .. "Duration")
	if duration then
		duration:SetAlpha(0)
	end
	button.puiSize = size
end

-- Reihe mittig ausrichten.
-- Wiederverwendete Liste mit eigenem Zaehler (kein neuer Abfall pro Aufruf;
-- table.getn ist in Lua 5.0 nach dem Leeren unzuverlaessig).
local shown = {}
local function Row(list, y)
	local size = P.DB().auras.size
	local n = 0
	for i = 1, table.getn(list) do
		local b = getglobal(list[i].name)
		if b and b:IsShown() then
			if b.puiSize ~= size then
				Style(list[i])
			end
			n = n + 1
			shown[n] = b
		elseif b and b.puiEdge then
			b.puiEdge:Hide()
		end
	end
	local step = size + GAP
	local total = n * size + (n - 1) * GAP
	for i = 1, n do
		local b = shown[i]
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", container, "BOTTOM", -total / 2 + (i - 1) * step, y)
		b.puiEdge:Show()
	end
end

-- Welche Symbole gerade sichtbar sind, als Zahl: aendert sich nichts, wird
-- auch nichts neu angeordnet (das lief vorher in jedem Bild).
local function Signature(list)
	local key = 0
	for i = 1, table.getn(list) do
		local b = getglobal(list[i].name)
		key = key * 2
		if b and b:IsShown() then
			key = key + 1
		end
	end
	return key
end
local lastBuffs, lastDebuffs, lastSize

local function Layout(force)
	if not container then
		return
	end
	local size = P.DB().auras.size
	local kb, kd = Signature(BUFFS), Signature(DEBUFFS)
	if not force and kb == lastBuffs and kd == lastDebuffs and size == lastSize then
		return
	end
	-- Groesse geaendert: Uhren neu anlegen, sonst behaelt das Modell seine alte
	-- Groesse im Kopf und dreht sich nicht mehr um die Mitte
	local resized = lastSize and size ~= lastSize
	lastBuffs, lastDebuffs, lastSize = kb, kd, size
	container:SetWidth(10 * size)
	container:SetHeight(2 * size + 4)
	Row(BUFFS, 0)
	Row(DEBUFFS, size + 4)
	if resized then
		FreshClocks()
	end
end

-- Uhr, Zahl und Debuff-Farbe nachfuehren (5x pro Sekunde).
local function TickList(list, now)
	for i = 1, table.getn(list) do
		local entry = list[i]
		local b = getglobal(entry.name)
		if b and b:IsShown() and b.puiTime then
			local alpha = b:GetAlpha()
			if alpha and alpha < 1 then
				b:SetAlpha(1)
			end
			local left = TimeLeft(b, entry)
			local key = entry.name .. ":" .. tostring(b.buffIndex)
			if left and left > 0 then
				local total = totals[key]
				if not total or left > total + 0.5 then
					total = left
					totals[key] = total
				end
				b.puiTime:SetText(Clock(left))
				Shade(b, total > 0 and (1 - left / total) or 0)
			else
				totals[key] = nil
				b.puiTime:SetText("")
				Shade(b, 0)
			end
			local r, g, bl = 0, 0, 0
			if entry.debuff then
				local border = getglobal(entry.name .. "Border")
				if border and border.GetVertexColor then
					r, g, bl = border:GetVertexColor()
				end
				r, g, bl = r or 0.8, g or 0, bl or 0
			end
			b.puiEdge.tex:SetVertexColor(r, g, bl, 1)
		end
	end
end

-- Nach dem Spiel und nach SurvivorsDragonUi unsere Anordnung setzen.
-- force: das Spiel hat seine Buffs selbst neu angeordnet -> unsere Anordnung
-- wieder setzen. Ohne force (z. B. pro Bild) nur, wenn sich etwas geaendert hat.
local function After(name, force)
	local previous = getglobal(name)
	if type(previous) ~= "function" then
		return
	end
	setglobal(name, function(a1, a2, a3, a4)
		previous(a1, a2, a3, a4)
		Layout(force)
	end)
end

local function Init()
	if not P.DB().auras.enabled then
		return
	end
	container = CreateFrame("Frame", "PhantomUI_Buffs", UIParent)
	container:SetFrameStrata("LOW")

	for _, list in ipairs({ BUFFS, DEBUFFS }) do
		for i = 1, table.getn(list) do
			Style(list[i])
			local b = getglobal(list[i].name)
			if b then
				local onShow, onHide = b:GetScript("OnShow"), b:GetScript("OnHide")
				b:SetScript("OnShow", function()
					if onShow then onShow() end
					Layout(true)
				end)
				b:SetScript("OnHide", function()
					if onHide then onHide() end
					if this.puiEdge then this.puiEdge:Hide() end
					Layout(true)
				end)
			end
		end
	end
	-- Das Spiel laesst Buffs in den letzten 30 Sekunden langsam auf- und abblenden
	-- (BUFF_WARNING_TIME). Das ist das Flackern: abschalten.
	BUFF_WARNING_TIME = -1
	local onUpdate = BuffButton_OnUpdate
	if onUpdate then
		BuffButton_OnUpdate = function(a1)
			onUpdate(a1)
			if this and this.SetAlpha then
				this:SetAlpha(1)
			end
		end
	end
	After("BuffButtons_UpdatePositions", true)
	After("BuffFrame_Enchant_OnUpdate")
	After("UIParent_ManageFramePositions", true)
	After("BuffFrame_Update", true)

	Layout()
	-- Standardplatz: mittig ueber der Ressourcenleiste. Ecke/Kanten aendern die Symbolgroesse.
	P.RegisterMover("auras", container, "Buffs", function(f)
		local power = getglobal("PhantomUI_Power")
		if power then
			f:SetPoint("BOTTOM", power, "TOP", 0, 6)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
		end
	end, {
		uniform = true,
		get = function()
			local d = P.DB().auras
			return d.size, d.size
		end,
		set = function(w, h, which)
			P.DB().auras.size = P.Clamp(which == "w" and w or h, 16, 64)
		end,
	})

	local t = 0
	container:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.2 then
			t = 0
			local now = GetTime()
			TickList(BUFFS, now)
			TickList(DEBUFFS, now)
		end
	end)
	P.OnApply(function()
		for _, list in ipairs({ BUFFS, DEBUFFS }) do
			for i = 1, table.getn(list) do
				Style(list[i])
			end
		end
		Layout(true)
	end)
end

P.OnInit(Init)
