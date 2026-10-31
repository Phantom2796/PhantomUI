-- PhantomUI: Minimap-Markierungen
-- Wächter-Höhlen (Totenkopf, immer sichtbar, am Rand festgehalten) und Truhen.
-- Daten: AZS_LAIRS / AZS_CHESTS (Welt- und Kartenkoordinaten).

local P = PhantomUI

local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local CHEST = "Interface\\Icons\\INV_Box_01"
-- Minimap-Durchmesser in Metern (Yards) je Zoomstufe, draussen
local ZOOM_YD = { [0] = 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }

local pins = {}

-- Sekunden -> "1:05"
local function Clock(sec)
	sec = math.floor(sec + 0.5)
	return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60))
end
local holder

local function Pin(i)
	local p = pins[i]
	if p then
		return p
	end
	p = CreateFrame("Frame", nil, holder)
	p:SetFrameLevel(Minimap:GetFrameLevel() + 6)
	p:EnableMouse(true)
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetTexture(P.FLAT)
	p.bg:SetVertexColor(0, 0, 0, 0.75)
	p.bg:SetAllPoints(p)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
	p.icon:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
	p.txt = p:CreateFontString(nil, "OVERLAY")
	p.txt:SetFont(P.Font(), 8, "OUTLINE")
	p.txt:SetPoint("TOP", p, "BOTTOM", 0, -1)
	p:SetScript("OnEnter", function()
		if this.tip then
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetText(this.tip, 1, 1, 1)
			if this.sub then
				GameTooltip:AddLine(this.sub, 0.8, 0.8, 0.8)
			end
			GameTooltip:Show()
		end
	end)
	p:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pins[i] = p
	return p
end

-- Kartenwerte 0..1 (falls Prozent geliefert: /100)
local function Norm(v)
	v = tonumber(v) or 0
	if v > 1.5 then
		v = v / 100
	end
	return v
end

-- Zonengrösse in Yards aus zwei Punkten (Welt + Karte); pro Zone merken
local function ZoneSize(points)
	local db = P.DB().pins
	db.scale = db.scale or {}
	local zone = GetRealZoneText and GetRealZoneText() or "?"
	local bw, bh, dw, dh = nil, nil, 0, 0
	local n = table.getn(points)
	for i = 1, n do
		for j = i + 1, n do
			local a, b = points[i], points[j]
			local dmx = math.abs(Norm(a.mx) - Norm(b.mx))
			local dmy = math.abs(Norm(a.my) - Norm(b.my))
			-- Karte x ~ Welt y, Karte y ~ Welt x
			if dmx > dw and dmx > 0.02 then
				dw = dmx
				bw = math.abs((tonumber(a.y) or 0) - (tonumber(b.y) or 0)) / dmx
			end
			if dmy > dh and dmy > 0.02 then
				dh = dmy
				bh = math.abs((tonumber(a.x) or 0) - (tonumber(b.x) or 0)) / dmy
			end
		end
	end
	if bw and bh and bw > 50 and bh > 50 then
		db.scale[zone] = { bw, bh }
	end
	local s = db.scale[zone]
	if s then
		return s[1], s[2]
	end
end

local function Collect()
	local list, points = {}, {}
	local db = P.DB().pins
	local lairs = type(AZS_GetLairs) == "function" and AZS_GetLairs() or AZS_LAIRS
	if db.lairs and type(lairs) == "table" then
		for i = 1, table.getn(lairs) do
			local l = lairs[i]
			if type(l) == "table" and l.mx then
				table.insert(points, l)
				table.insert(list, { kind = "lair", d = l })
			end
		end
	end
	if type(AZS_CHESTS) == "table" then
		for i = 1, table.getn(AZS_CHESTS) do
			local c = AZS_CHESTS[i]
			if type(c) == "table" and c.mx then
				table.insert(points, c)
				if db.chests then
					table.insert(list, { kind = "chest", d = c })
				end
			end
		end
	end
	return list, points
end

local function Update()
	if not Minimap:IsVisible() then
		return
	end
	local list, points = Collect()
	local w, h = ZoneSize(points)
	local px, py
	if not (WorldMapFrame and WorldMapFrame:IsVisible()) then
		if SetMapToCurrentZone then
			SetMapToCurrentZone()
		end
		px, py = GetPlayerMapPosition("player")
	end
	local n = 0
	if w and px and (px > 0 or py > 0) then
		local size = Minimap:GetWidth()
		local half = size / 2
		local ppy = size / (ZOOM_YD[Minimap:GetZoom()] or 466.6667)
		local pin = P.DB().pins.size or 14
		for i = 1, table.getn(list) do
			local e = list[i]
			local dx = (Norm(e.d.mx) - px) * w * ppy
			local dy = -(Norm(e.d.my) - py) * h * ppy
			local inside = math.abs(dx) <= half - 4 and math.abs(dy) <= half - 4
			local show = inside
			if e.kind == "lair" and not inside then
				-- Höhlen immer zeigen: am Rand festhalten
				local m = math.max(math.abs(dx), math.abs(dy))
				local k = (half - pin / 2) / m
				dx, dy = dx * k, dy * k
				show = true
			end
			if show then
				n = n + 1
				local p = Pin(n)
				p:SetWidth(pin)
				p:SetHeight(pin)
				p:ClearAllPoints()
				p:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
				if e.kind == "lair" then
					local active = e.d.state ~= "empty"
					p.icon:SetTexture(SKULL)
					p.icon:SetTexCoord(0, 1, 0, 1)
					p:SetAlpha(active and 1 or 0.55)
					local left = tonumber(e.d.left) or 0
					p.txt:SetText((not active and left > 0) and Clock(left) or "")
					p.tip = e.d.name or P.T("Wächter")
					p.sub = active and P.T("Wächter da") or P.T("Höhle leer")
				else
					p.icon:SetTexture(CHEST)
					p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					p:SetAlpha(1)
					p.txt:SetText("")
					p.tip = P.T("Truhe")
					p.sub = nil
				end
				p:Show()
			end
		end
	end
	for i = n + 1, table.getn(pins) do
		pins[i]:Hide()
	end
end

local function Init()
	if not P.DB().pins.enabled then
		return
	end
	holder = CreateFrame("Frame", "PhantomUI_MinimapPins", Minimap)
	holder:SetAllPoints(Minimap)
	local t = 0
	holder:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.1 then
			t = 0
			Update()
		end
	end)
end

P.OnInit(Init)
