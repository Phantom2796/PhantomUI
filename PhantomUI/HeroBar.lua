-- PhantomUI: die 6 Faehigkeiten und die passive (Volks-)Faehigkeit noch einmal
-- klein und halb durchsichtig um den Helden, damit man Abklingzeiten sieht,
-- ohne nach unten zu schauen. Nur eine Anzeige (Symbol + Abklingzeit), keine
-- Maus, kein Tooltip; die Aktionsleiste unten bleibt, wie sie ist.
-- Links Platz 1-3, rechts 4-6 (von oben nach unten, symmetrisch), darunter mittig Platz 12.

local P = PhantomUI

local SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
-- Lage je Symbol in Symbolgroessen, ab dem Helden (x rechts, y oben): zwei
-- Halbmonde, die den Helden von unten umfassen. Links 1-3 von Hueftehoehe
-- nach unten, rechts 4-6 gespiegelt, die 7. ganz unten in der Mitte; alle
-- spiegelgleich; 3 und 6 etwas weiter aussen/unten, die 7. tiefer darunter.
local SPOTS = {
	{ -2.90, 0.00 }, { -2.51, -1.45 }, { -2.10, -3.00 },
	{ 2.90, -0.00 }, { 2.51, -1.45 }, { 2.10, -3.00 },
	{ 0, -4.20 },
}

local frame
local icons = {}

local function Layout()
	local db = P.DB().herobar
	local s = db.size or 18
	frame:SetWidth(s * 7)
	frame:SetHeight(s * 10)
	-- Durchsichtig sind nur die Symbole; Uhrzeiger und Restzeit bleiben voll
	-- sichtbar, damit man die Abklingzeit auch bei 0.5 gut erkennt.
	frame:SetAlpha(1)
	frame.iconAlpha = db.alpha or 0.5
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
		if b.cd then
			b.cd:SetScale(math.max(0.1, (s - 2) / 36))
		end
		b.left:SetFont(P.Font(), math.max(9, math.floor(s * 0.6)), "THICKOUTLINE")
		b.dimmed = nil
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
	-- Im Classic-Client zeichnet das Cooldown-Modell immer 36 px gross; fuer
	-- kleinere Symbole wird es skaliert statt gestreckt (sonst kein Uhrzeiger).
	local ok, cd = pcall(CreateFrame, "Model", "PhantomUI_HeroBarCooldown" .. i, b, "CooldownFrameTemplate")
	if ok and cd then
		cd:SetWidth(36)
		cd:SetHeight(36)
		cd:SetPoint("CENTER", b, "CENTER", 0, 0)
		if cd.EnableMouse then
			cd:EnableMouse(false)
		end
		b.cd = cd
	end
	-- Restsekunden mittig, ueber dem Uhrzeiger
	b.text = CreateFrame("Frame", nil, b)
	b.text:SetAllPoints(b)
	b.text:SetFrameLevel(b:GetFrameLevel() + 5)
	b.left = b.text:CreateFontString(nil, "OVERLAY")
	b.left:SetPoint("CENTER", b, "CENTER", 1, 0)
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
			-- waehrend der Abklingzeit: Symbol dunkler, Sekunden gross darauf
			local start, duration = 0, 0
			if GetActionCooldown then
				start, duration = GetActionCooldown(slot)
			end
			local left = (start and duration and start > 0 and duration > 1.5) and (start + duration - GetTime()) or 0
			local a = frame.iconAlpha or 0.5
			local dim = left > 0
			if b.dimmed ~= dim then
				b.dimmed = dim
				b.icon:SetAlpha(dim and a * 0.5 or a)
				b.edge:SetAlpha(a)
				if dim then
					b.icon:SetVertexColor(0.45, 0.45, 0.45)
				else
					b.icon:SetVertexColor(1, 1, 1)
				end
			end
			local txt = ""
			if left > 0 then
				txt = left >= 10 and tostring(math.floor(left + 0.5)) or string.format("%.1f", left)
			end
			if b.shownTxt ~= txt then
				b.shownTxt = txt
				b.left:SetText(txt)
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
