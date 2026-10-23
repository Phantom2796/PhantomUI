-- PhantomUI: Gruppenanzeige fuer den Koop-Modus.
-- Mitspieler (party1-4): Name in Klassenfarbe, Lebensleiste, Klick = Ziel.
-- Verschiebbar/skalierbar im Ankermodus.

local P = PhantomUI
local MAX = 4

local frame
local rows = {}

-- Klassenfarbe einer Einheit
local function ClassRGB(unit)
	local _, class = UnitClass(unit)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 0.6, 0.6, 0.6
end
P.PartyClassRGB = ClassRGB

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	r = CreateFrame("Button", "PhantomUI_Party" .. i, frame)
	r.unit = "party" .. i
	r:EnableMouse(true)
	r:RegisterForClicks("LeftButtonUp")
	r:SetScript("OnClick", function()
		if UnitExists(this.unit) then
			TargetUnit(this.unit)
		end
	end)
	r:SetScript("OnEnter", function()
		if UnitExists(this.unit) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetUnit(this.unit)
			GameTooltip:Show()
		end
	end)
	r:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	r.edge = r:CreateTexture(nil, "BACKGROUND")
	r.edge:SetTexture(P.FLAT)
	r.edge:SetVertexColor(0, 0, 0, 0.85)
	r.edge:SetAllPoints(r)
	r.bar = CreateFrame("StatusBar", nil, r)
	r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
	r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -1, 1)
	r.bg = r.bar:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints(r.bar)
	local holder = CreateFrame("Frame", nil, r)
	holder:SetAllPoints(r)
	holder:SetFrameLevel(r.bar:GetFrameLevel() + 2)
	r.name = holder:CreateFontString(nil, "OVERLAY")
	r.name:SetPoint("LEFT", r, "LEFT", 5, 0)
	r.name:SetJustifyH("LEFT")
	r.hp = holder:CreateFontString(nil, "OVERLAY")
	r.hp:SetPoint("RIGHT", r, "RIGHT", -5, 0)
	rows[i] = r
	return r
end

local function Layout()
	local db = P.DB().party
	local w, h = db.width or 160, db.height or 22
	local font, tex = P.Font(), P.Texture()
	frame:SetWidth(w)
	frame:SetHeight(MAX * (h + 3))
	for i = 1, MAX do
		local r = Row(i)
		r:SetWidth(w)
		r:SetHeight(h)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * (h + 3))
		r.bar:SetStatusBarTexture(tex)
		r.bg:SetTexture(tex)
		r.name:SetFont(font, math.max(9, h - 10), "OUTLINE")
		r.hp:SetFont(font, math.max(9, h - 11), "OUTLINE")
		r.name:SetWidth(w - 60)
		r.name:SetHeight(h)
	end
end

local function Update()
	local shown = 0
	for i = 1, MAX do
		local r = rows[i]
		local unit = r.unit
		if UnitExists(unit) then
			shown = shown + 1
			local cr, cg, cb = ClassRGB(unit)
			local cur, max = UnitHealth(unit) or 0, UnitHealthMax(unit) or 1
			if max <= 0 then
				max = 1
			end
			r.bar:SetMinMaxValues(0, max)
			r.bar:SetValue(cur)
			local dead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) or cur <= 0
			local off = UnitIsConnected and not UnitIsConnected(unit)
			if dead or off then
				r.bar:SetStatusBarColor(0.3, 0.3, 0.3)
				r.bg:SetVertexColor(0.08, 0.08, 0.08, 0.9)
			else
				r.bar:SetStatusBarColor(cr * 0.75, cg * 0.75, cb * 0.75)
				r.bg:SetVertexColor(cr * 0.2, cg * 0.2, cb * 0.2, 0.9)
			end
			r.name:SetText(UnitName(unit) or "")
			r.name:SetTextColor(cr, cg, cb)
			if off then
				r.hp:SetText(P.T("Offline"))
			elseif dead then
				r.hp:SetText(P.T("Tot"))
			else
				r.hp:SetText(math.floor(cur / max * 100 + 0.5) .. "%")
			end
			r:Show()
		elseif P.unlocked and i <= 2 then
			-- Vorschau im Ankermodus
			shown = shown + 1
			r.bar:SetMinMaxValues(0, 1)
			r.bar:SetValue(0.7)
			r.bar:SetStatusBarColor(0.5, 0.6, 0.75)
			r.name:SetText(P.T("Mitspieler"))
			r.name:SetTextColor(1, 1, 1)
			r.hp:SetText("70%")
			r:Show()
		else
			r:Hide()
		end
	end
	if shown > 0 then
		frame:Show()
	else
		frame:Hide()
	end
end

local function Init()
	if not P.DB().party.enabled then
		return
	end
	frame = CreateFrame("Frame", "PhantomUI_PartyFrame", UIParent)
	frame:SetFrameStrata("LOW")
	Layout()
	-- Standard: links unter dem Spielerfenster
	P.RegisterMover("party", frame, "Gruppe", function(f)
		local player = getglobal("PhantomUI_Player")
		if player then
			f:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -40)
		else
			f:SetPoint("LEFT", UIParent, "LEFT", 40, 60)
		end
	end, {
		get = function()
			local d = P.DB().party
			return d.width or 160, d.height or 22
		end,
		set = function(w, h)
			local d = P.DB().party
			d.width = P.Clamp(w, 80, 400)
			d.height = P.Clamp(h, 12, 40)
		end,
	})
	P.OnApply(Layout)
	-- Blizzard-Gruppenfenster weg
	for i = 1, MAX do
		local f = getglobal("PartyMemberFrame" .. i)
		if f then
			f:Hide()
			f:UnregisterAllEvents()
			f.Show = function() end
		end
	end
	local t = 0
	local ticker = CreateFrame("Frame", "PhantomUI_PartyTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.15 then
			t = 0
			Update()
		end
	end)
	Update()
end

P.OnInit(Init)
