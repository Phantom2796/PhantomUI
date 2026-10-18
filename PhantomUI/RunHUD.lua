-- PhantomUI: Laufuhr mit Boss-Markierungen und Boss-Lebensleisten (ersetzt die
-- Anzeigen des Spiels bzw. von SurvivorsDragonUi). Werte aus der AZS-Schnittstelle.

local P = PhantomUI

local L = {
	enUS = { next = "Next boss", endless = "Endless", won = "Victory" },
	deDE = { next = "Nächster Boss", endless = "Endlos", won = "Sieg" },
}
local function T(key)
	local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
	return (L[lang] or L.enUS)[key] or L.enUS[key]
end

local function Clock(s)
	s = math.max(0, math.floor(s or 0))
	return string.format("%02d:%02d", math.floor(s / 60), math.mod(s, 60))
end

local timer, fill, text, nextText
local markers = {}
local bossFrame
local pills = {}

------------------------------------------------------------------------
-- Laufuhr
------------------------------------------------------------------------

-- Farben fuer die Texte: Zeit hell, Gesamtzeit/Beschriftung gedaempft, Zeit bis zum Boss violett
local MUTED = "|cff9a8fb0"
local BRIGHT = "|cffffffff"
local VIOLET = "|cffc08af5"

local function LayoutTimer()
	local db = P.DB().run
	local e = 2
	timer:SetScale(db.scale)
	timer:SetWidth(db.width)
	timer:SetHeight(db.height)
	P.Box(timer, 0.85, e)
	fill:ClearAllPoints()
	fill:SetPoint("TOPLEFT", timer, "TOPLEFT", e, -e)
	fill:SetPoint("BOTTOMLEFT", timer, "BOTTOMLEFT", e, e)
	fill:SetTexture(P.Texture())
	-- Verlauf von dunklem zu hellem Violett
	fill:SetGradient("HORIZONTAL", 0.36, 0.14, 0.6, P.ACCENT[1] + 0.12, P.ACCENT[2] + 0.2, P.ACCENT[3])
	text:SetFont(P.Font(), 16, "OUTLINE")
	text:SetShadowOffset(1, -1)
	nextText:SetFont(P.Font(), 11, "OUTLINE")
	nextText:SetShadowOffset(1, -1)
end

local function UpdateTimer()
	local phase = AZS_GetPhase and AZS_GetPhase()
	local t = AZS_GetRunTime and AZS_GetRunTime()
	if not phase or phase == "ready" or not t then
		if P.unlocked then
			timer:Show()
			text:SetText(BRIGHT .. "00:00|r" .. MUTED .. "  /  16:00|r")
			fill:SetWidth(1)
			nextText:SetText("")
		else
			timer:Hide()
		end
		return
	end
	timer:Show()
	-- Laufdauer = wann der Endboss kommt. AZS_ZONE.len fehlt manchmal (z. B. nach
	-- /reload); dann gilt der spaeteste Boss im Zeitplan (20-Minuten-Karten!).
	local len = tonumber(AZS_GetRunLength and AZS_GetRunLength()) or 0
	local sched = AZS_SCHEDULE
	if type(sched) == "table" then
		for i = 1, table.getn(sched) do
			local at = type(sched[i]) == "table" and tonumber(sched[i].at)
			if at and at > len then
				len = at
			end
		end
	end
	if len <= 0 then
		len = 960
	end
	local inner = timer:GetWidth() - 4
	local share = math.min(1, t / len)
	fill:SetWidth(math.max(1, inner * share))
	local run = AZS_RUN
	if type(run) == "table" and run.endl == 1 then
		text:SetText(BRIGHT .. Clock(t) .. "|r" .. MUTED .. "  " .. T("endless") .. "|r")
	else
		text:SetText(BRIGHT .. Clock(t) .. "|r" .. MUTED .. "  /  " .. Clock(len) .. "|r")
	end

	-- Markierungen fuer die Bosse des Gebiets
	local schedule = AZS_SCHEDULE
	local n = 0
	if type(schedule) == "table" then
		for i = 1, table.getn(schedule) do
			local b = schedule[i]
			if type(b) == "table" and b.at then
				n = n + 1
				local m = markers[n]
				if not m then
					m = timer:CreateTexture(nil, "OVERLAY")
					m:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
					markers[n] = m
				end
				local size = math.max(14, timer:GetHeight() + 8)
				m:SetWidth(size)
				m:SetHeight(size)
				m:ClearAllPoints()
				m:SetPoint("CENTER", timer, "LEFT", 2 + inner * math.min(1, b.at / len), 0)
				if b.state == "dead" then
					m:SetVertexColor(0.3, 0.9, 0.3, 0.9)
				elseif b.state == "up" then
					m:SetVertexColor(1, 0.25, 0.25, 1)
				else
					m:SetVertexColor(1, 1, 1, 0.9)
				end
				m:Show()
			end
		end
	end
	for i = n + 1, table.getn(markers) do
		markers[i]:Hide()
	end

	-- Naechster Boss
	local upcoming = AZS_GetUpcomingBosses and AZS_GetUpcomingBosses()
	local first = type(upcoming) == "table" and upcoming[1]
	if first and first.name then
		nextText:SetText(MUTED .. T("next") .. ":|r  " .. BRIGHT .. first.name .. "|r  " .. VIOLET .. Clock(first.left) .. "|r")
	elseif type(run) == "table" and run.nbn and run.nbn ~= "" and (tonumber(run.nb) or -1) >= 0 then
		nextText:SetText(MUTED .. T("next") .. ":|r  " .. BRIGHT .. run.nbn .. "|r  " .. VIOLET .. Clock(run.nb) .. "|r")
	elseif type(run) == "table" and run.won == 1 then
		nextText:SetText(VIOLET .. T("won") .. "|r")
	else
		nextText:SetText("")
	end
end

------------------------------------------------------------------------
-- Boss-Leisten
------------------------------------------------------------------------

local function Pill(i)
	local p = pills[i]
	if p then
		return p
	end
	p = CreateFrame("Frame", nil, bossFrame)
	p.bar = CreateFrame("StatusBar", nil, p)
	p.bar:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
	p.bar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
	p.bar:SetFrameLevel(p:GetFrameLevel() + 1)
	p.bg = p.bar:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints(p.bar)
	local holder = CreateFrame("Frame", nil, p)
	holder:SetAllPoints(p)
	holder:SetFrameLevel(p.bar:GetFrameLevel() + 2)
	p.name = holder:CreateFontString(nil, "OVERLAY")
	p.name:SetPoint("LEFT", p, "LEFT", 5, 0)
	p.pct = holder:CreateFontString(nil, "OVERLAY")
	p.pct:SetPoint("RIGHT", p, "RIGHT", -5, 0)
	pills[i] = p
	return p
end

local function UpdateBosses()
	local db = P.DB().run
	local list = {}
	local bosses = AZS_GetBosses and AZS_GetBosses()
	if type(bosses) == "table" then
		for i = 1, table.getn(bosses) do
			table.insert(list, bosses[i])
		end
	end
	local guardians = AZS_GetGuardians and AZS_GetGuardians()
	if type(guardians) == "table" then
		for i = 1, table.getn(guardians) do
			local g = guardians[i]
			if g.awake == true or g.awake == 1 then
				table.insert(list, { name = g.name, hp = g.hp, hpm = g.hpm, guardian = true })
			end
		end
	end
	if P.unlocked and table.getn(list) == 0 then
		-- Vorschau im Ankermodus: zwei Leisten, damit man das Stapeln sieht
		list = { { name = "Boss", hp = 7, hpm = 10 }, { name = "Wächter", hp = 4, hpm = 10, guardian = true } }
	end
	local tex = P.Texture()
	local bdb = P.DB().bosses
	local h = bdb.height
	-- Am Zielfenster angedockt: genau so breit wie das Ziel (beide Ecken verankert).
	-- Frei verschoben: eigene Breite und Skalierung (Ankermodus: Kanten / Ecke).
	local docked = bossFrame.docked
	local wantScale = docked and 1 or bdb.scale
	if bossFrame.lastScale ~= wantScale then
		bossFrame.lastScale = wantScale
		bossFrame:SetScale(wantScale)
	end
	local width
	if docked then
		width = bossFrame:GetWidth()
		if width and width > 0 then
			bossFrame.dockWidth = math.floor(width + 0.5)
		end
		width = bossFrame.dockWidth or 260
		bossFrame.lastWidth = nil
	else
		width = (bdb.width and bdb.width > 0) and bdb.width or bossFrame.dockWidth or 260
		if bossFrame.lastWidth ~= width then
			bossFrame.lastWidth = width
			bossFrame:SetWidth(width)
		end
	end
	-- Nur die unterste Leiste zaehlt fuer Platz und Anker; weitere Bosse
	-- stapeln sich darueber (die Leiste waechst nach oben).
	if bossFrame.lastH ~= h then
		bossFrame.lastH = h
		bossFrame:SetHeight(h)
	end
	-- Rahmen, Textur und Schrift nur neu setzen, wenn sich Groesse oder Stil
	-- aendern: das Neuanlegen ist fuer das Spiel teuer (war ein Ruckler-Grund).
	local font = P.Font()
	local styleKey = width .. ":" .. h .. ":" .. tex .. ":" .. font
	for i = 1, table.getn(list) do
		local b = list[i]
		local p = Pill(i)
		if p.styleKey ~= styleKey then
			p.styleKey = styleKey
			p:ClearAllPoints()
			-- etwas Abstand zwischen den Bossen
			p:SetPoint("BOTTOMLEFT", bossFrame, "BOTTOMLEFT", 0, (i - 1) * (h + 3))
			p:SetWidth(width)
			p:SetHeight(h)
			P.Box(p, 0.85)
			p.bar:SetStatusBarTexture(tex)
			p.bg:SetTexture(tex)
			p.name:SetFont(font, math.max(9, h - 6), "OUTLINE")
			p.pct:SetFont(font, math.max(9, h - 6), "OUTLINE")
			-- Name begrenzen: lange Namen werden gekuerzt statt in die Zahlen zu laufen
			p.name:SetJustifyH("LEFT")
			p.name:SetHeight(h)
			p.name:SetWidth(math.max(40, width - 105))
		end
		local max = tonumber(b.hpm) or 1
		if max <= 0 then
			max = 1
		end
		local cur = tonumber(b.hp) or 0
		p.bar:SetMinMaxValues(0, max)
		p.bar:SetValue(cur)
		local r, g, bl = 0.84, 0.13, 0.15
		if b.guardian then
			r, g, bl = 0.62, 0.3, 0.92
		elseif b.enraged then
			r, g, bl = 1, 0.45, 0.1
		end
		if p.r ~= r or p.g ~= g or p.b ~= bl then
			p.r, p.g, p.b = r, g, bl
			p.bar:SetStatusBarColor(r, g, bl)
			p.bg:SetVertexColor(r * 0.2, g * 0.2, bl * 0.2, 0.9)
		end
		local name = b.name or ""
		if p.lastName ~= name then
			p.lastName = name
			p.name:SetText(name)
		end
		local pct = P.Short(cur) .. "  " .. math.floor(cur / max * 100 + 0.5) .. "%"
		if p.lastPct ~= pct then
			p.lastPct = pct
			p.pct:SetText(pct)
		end
		p:Show()
	end
	for i = table.getn(list) + 1, table.getn(pills) do
		pills[i]:Hide()
	end
	if table.getn(list) == 0 then
		bossFrame:Hide()
	else
		bossFrame:Show()
	end
end

------------------------------------------------------------------------

-- Teile der Spiel-Anzeige ausblenden, die PhantomUI selbst zeigt.
local function TakeOverHud()
	if type(AZS_SetHudShown) ~= "function" then
		return
	end
	local db = P.DB().run
	if db.enabled then
		pcall(AZS_SetHudShown, "clock", false)
		pcall(AZS_SetHudShown, "bosses", false)
	end
	if P.DB().tally.enabled then
		pcall(AZS_SetHudShown, "tally", false)
	end
end

local function Init()
	local db = P.DB().run
	TakeOverHud()
	if not db.enabled then
		return
	end
	timer = CreateFrame("Frame", "PhantomUI_RunTimer", UIParent)
	timer:SetFrameStrata("LOW")
	fill = timer:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", timer, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", timer, "BOTTOMLEFT", 1, 1)
	fill:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 0.9)
	local holder = CreateFrame("Frame", nil, timer)
	holder:SetAllPoints(timer)
	holder:SetFrameLevel(timer:GetFrameLevel() + 3)
	-- Zeit ueber der Leiste, naechster Boss darunter
	text = holder:CreateFontString(nil, "OVERLAY")
	text:SetPoint("BOTTOM", timer, "TOP", 0, 5)
	nextText = holder:CreateFontString(nil, "OVERLAY")
	nextText:SetPoint("TOP", timer, "BOTTOM", 0, -6)
	LayoutTimer()

	bossFrame = CreateFrame("Frame", "PhantomUI_Bosses", UIParent)
	-- Boss-Leisten ganz oben: ueber allen anderen Fenstern und Zahlen
	bossFrame:SetFrameStrata("FULLSCREEN_DIALOG")

	P.RegisterMover("runtimer", timer, "Laufuhr", function(f)
		f:SetPoint("TOP", UIParent, "TOP", 0, -30)
	end, {
		scale = "run",
		get = function()
			local d = P.DB().run
			return d.width, d.height
		end,
		set = function(w, h)
			local d = P.DB().run
			d.width = P.Clamp(w, 120, 600)
			d.height = P.Clamp(h, 4, 30)
		end,
	})
	P.RegisterMover("bosses", bossFrame, "Bosse", function(f)
		-- buendig auf dem Zielfenster, gleich breit; weitere Bosse stapeln sich nach oben
		local target = getglobal("PhantomUI_Target")
		if target then
			f:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 5)
			f:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 5)
			f.docked = true
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 229, -100)
		end
	end, {
		scale = "bosses",
		get = function()
			local d = P.DB().bosses
			local w = d.width
			if not w or w <= 0 then
				w = bossFrame.dockWidth or 260
			end
			return w, d.height
		end,
		set = function(w, h)
			local d = P.DB().bosses
			d.width = P.Clamp(w, 120, 700)
			d.height = P.Clamp(h, 12, 40)
		end,
	})

	local t, h = 0, 0
	local ticker = CreateFrame("Frame", "PhantomUI_RunTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		h = h + arg1
		if t > 0.1 then
			t = 0
			UpdateTimer()
		end
		if h > 0.25 then
			h = 0
			UpdateBosses()
		end
	end)
	P.OnApply(function()
		LayoutTimer()
		UpdateTimer()
		UpdateBosses()
	end)
end

P.OnInit(Init)
