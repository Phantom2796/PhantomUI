-- PhantomUI: Gruppen-DPS im Koop – eigenes Fenster, ein Held pro Zeile.
-- Daten: AZS_GetPartyMeter (Name, Klasse, Schaden, DPS, Anteil).

local P = PhantomUI
local MAX = 8

local frame, title, total
local rows = {}

-- Klassenfarbe aus dem Klassen-Schluessel des Spiels
local function ClassRGB(key)
	local c = key and RAID_CLASS_COLORS and RAID_CLASS_COLORS[string.upper(key)]
	if c then
		return c.r, c.g, c.b
	end
	return 0.7, 0.7, 0.7
end

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	r = CreateFrame("Frame", nil, frame)
	r.bar = CreateFrame("StatusBar", nil, r)
	r.bar:SetAllPoints(r)
	r.bar:SetMinMaxValues(0, 1)
	r.bg = r.bar:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints(r.bar)
	local holder = CreateFrame("Frame", nil, r)
	holder:SetAllPoints(r)
	holder:SetFrameLevel(r.bar:GetFrameLevel() + 2)
	r.name = holder:CreateFontString(nil, "OVERLAY")
	r.name:SetPoint("LEFT", r, "LEFT", 4, 0)
	r.name:SetJustifyH("LEFT")
	r.dmg = holder:CreateFontString(nil, "OVERLAY")
	r.dps = holder:CreateFontString(nil, "OVERLAY")
	r.dps:SetPoint("RIGHT", r, "RIGHT", -4, 0)
	r.dps:SetJustifyH("RIGHT")
	r.dmg:SetPoint("RIGHT", r.dps, "LEFT", -10, 0)
	r.dmg:SetJustifyH("RIGHT")
	rows[i] = r
	return r
end

local function Layout()
	local db = P.DB().partymeter
	local w, h = db.width or 260, db.row or 16
	local font, tex = P.Font(), P.Texture()
	frame:SetWidth(w)
	frame:SetHeight(22 + MAX * (h + 1))
	title:SetFont(font, 11, "OUTLINE")
	total:SetFont(font, 10, "OUTLINE")
	for i = 1, MAX do
		local r = Row(i)
		r:SetWidth(w - 8)
		r:SetHeight(h)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -20 - (i - 1) * (h + 1))
		r.bar:SetStatusBarTexture(tex)
		r.bg:SetTexture(tex)
		r.name:SetFont(font, math.max(9, h - 5), "OUTLINE")
		r.dmg:SetFont(font, math.max(9, h - 5), "OUTLINE")
		r.dps:SetFont(font, math.max(9, h - 5), "OUTLINE")
		r.name:SetWidth(w - 140)
		r.name:SetHeight(h)
	end
end

local function Update()
	local lines, sum, rate
	if type(AZS_GetPartyMeter) == "function" then
		lines, sum, rate = AZS_GetPartyMeter()
	end
	lines = type(lines) == "table" and lines or {}
	local n = table.getn(lines)
	if n == 0 and P.unlocked then
		-- Vorschau im Ankermodus
		lines = { { name = "Phantom", class = "SHAMAN", dmg = 968100, dps = 2500 }, { name = P.T("Mitspieler"), class = "ROGUE", dmg = 411900, dps = 1100 } }
		n, sum, rate = 2, 1380000, 3600
	end
	if n == 0 then
		frame:Hide()
		return
	end
	local top = tonumber(lines[1].dmg) or 1
	if top <= 0 then
		top = 1
	end
	for i = 1, MAX do
		local r = rows[i]
		local l = lines[i]
		if l then
			local cr, cg, cb = ClassRGB(l.class)
			r.bar:SetValue((tonumber(l.dmg) or 0) / top)
			r.bar:SetStatusBarColor(cr * 0.6, cg * 0.6, cb * 0.6)
			r.bg:SetVertexColor(cr * 0.12, cg * 0.12, cb * 0.12, 0.85)
			r.name:SetText(i .. ". " .. (l.name or "?"))
			r.name:SetTextColor(cr, cg, cb)
			r.dmg:SetText(P.Short(tonumber(l.dmg) or 0))
			r.dps:SetText(P.Short(tonumber(l.dps) or 0))
			r:Show()
		else
			r:Hide()
		end
	end
	total:SetText(P.Short(tonumber(sum) or 0) .. "  |  " .. P.Short(tonumber(rate) or 0) .. " " .. P.T("DPS"))
	frame:SetHeight(22 + math.min(n, MAX) * ((P.DB().partymeter.row or 16) + 1) + 2)
	frame:Show()
end

local function Init()
	if not P.DB().partymeter.enabled then
		return
	end
	frame = CreateFrame("Frame", "PhantomUI_PartyMeter", UIParent)
	frame:SetFrameStrata("LOW")
	P.Box(frame, 0.85)
	title = frame:CreateFontString(nil, "OVERLAY")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
	title:SetTextColor(1, 0.82, 0)
	total = frame:CreateFontString(nil, "OVERLAY")
	total:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
	total:SetTextColor(0.75, 0.7, 0.9)
	Layout()
	title:SetText(P.T("Gruppen-DPS"))
	-- Standard: ueber dem Schadensmeter
	P.RegisterMover("partymeter", frame, "Gruppen-DPS", function(f)
		local meter = getglobal("AZSSpellMeterFrame")
		if meter then
			f:SetPoint("BOTTOMLEFT", meter, "TOPLEFT", 0, 6)
		else
			f:SetPoint("RIGHT", UIParent, "RIGHT", -20, 120)
		end
	end, {
		get = function()
			local d = P.DB().partymeter
			return d.width or 260, d.row or 16
		end,
		set = function(w, h)
			local d = P.DB().partymeter
			d.width = P.Clamp(w, 160, 500)
			d.row = P.Clamp(h, 10, 28)
		end,
	})
	P.OnApply(Layout)
	local t = 0
	local ticker = CreateFrame("Frame", "PhantomUI_PartyMeterTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.5 then
			t = 0
			Update()
		end
	end)
	Update()
end

P.OnInit(Init)
