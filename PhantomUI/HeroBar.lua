-- PhantomUI: die 6 Faehigkeiten und die passive (Volks-)Faehigkeit noch einmal
-- klein und halb durchsichtig um den Helden, damit man Abklingzeiten sieht,
-- ohne nach unten zu schauen. Nur eine Anzeige (Symbol + Abklingzeit), keine
-- Maus, kein Tooltip; die Aktionsleiste unten bleibt, wie sie ist.
-- Links Platz 1-3, rechts 4-6 (von oben nach unten, symmetrisch), darunter mittig Platz 12.

local P = PhantomUI

local SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
-- Lage je Symbol in Symbolgroessen, ab dem Helden (x rechts, y oben):
-- zwei gerade Spalten links und rechts mit Platz fuer den Helden dazwischen,
-- spiegelgleich, und die passive Faehigkeit mittig darunter.
local SPOTS = {
	{ -2.2, 1.2 }, { -2.2, 0 }, { -2.2, -1.2 },
	{ 2.2, 1.2 }, { 2.2, 0 }, { 2.2, -1.2 },
	{ 0, -2.4 },
}

local frame
local icons = {}

local function Layout()
	local db = P.DB().herobar
	local s = db.size or 18
	frame:SetWidth(s * 7)
	frame:SetHeight(s * 10)
	frame:SetAlpha(db.alpha or 0.5)
	-- ein/aus wirkt sofort
	if db.enabled then
		frame:Show()
	else
		frame:Hide()
	end
	for i = 1, table.getn(SLOTS) do
		local b = icons[i]
		b:SetWidth(s)
		b:SetHeight(s)
		b:ClearAllPoints()
		b:SetPoint("CENTER", frame, "CENTER", SPOTS[i][1] * s, SPOTS[i][2] * s)
	end
end

local function Make(i)
	local b = CreateFrame("Frame", nil, frame)
	b:EnableMouse(false)
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetTexture(P.FLAT)
	b.edge:SetVertexColor(0, 0, 0, 1)
	b.edge:SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	-- Abklingzeit wie auf der Leiste (Uhrzeiger-Schatten)
	local ok, cd = pcall(CreateFrame, "Model", nil, b, "CooldownFrameTemplate")
	if ok and cd then
		cd:SetAllPoints(b.icon)
		if cd.EnableMouse then
			cd:EnableMouse(false)
		end
		b.cd = cd
	end
	icons[i] = b
	return b
end

local function Update()
	for i = 1, table.getn(SLOTS) do
		local b = icons[i]
		local slot = SLOTS[i]
		local tex = GetActionTexture and GetActionTexture(slot)
		if tex or P.unlocked then
			tex = tex or "Interface\\Icons\\INV_Misc_QuestionMark"
			if b.tex ~= tex then
				b.tex = tex
				b.icon:SetTexture(tex)
			end
			if b.cd and GetActionCooldown and CooldownFrame_SetTimer then
				local start, duration, enable = GetActionCooldown(slot)
				if b.cdStart ~= start or b.cdDur ~= duration then
					b.cdStart, b.cdDur = start, duration
					CooldownFrame_SetTimer(b.cd, start, duration, enable)
				end
			end
			b:Show()
		else
			b:Hide()
		end
	end
end

local function Init()
	frame = CreateFrame("Frame", "PhantomUI_HeroBar", UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:EnableMouse(false)
	for i = 1, table.getn(SLOTS) do
		Make(i)
	end
	Layout()
	-- um den Helden: die Kamera zeigt ihn in der Bildschirmmitte
	P.RegisterMover("herobar", frame, "Fähigkeiten am Helden", function(f)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -UIParent:GetHeight() * 0.018)
	end, {
		uniform = true,
		get = function()
			local s = P.DB().herobar.size or 18
			return s, s
		end,
		set = function(w, h)
			P.DB().herobar.size = P.Clamp(h, 10, 48)
		end,
	})
	P.OnApply(Layout)
	local t = 0
	frame:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.1 then
			t = 0
			Update()
		end
	end)
	Update()
end

P.OnInit(Init)
