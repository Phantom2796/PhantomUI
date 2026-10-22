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
		-- ganze Pixel, sonst sitzt das Uhr-Modell leicht schief auf dem Symbol
		b:SetPoint("CENTER", frame, "CENTER", math.floor(SPOTS[i][1] * s + 0.5), math.floor(SPOTS[i][2] * s + 0.5))
		if b.cd then
			-- Das Uhr-Modell des Classic-Clients: drei Arten, es aufs Symbol zu
			-- legen (/puicd 1-3), weil es je nach Client anders zeichnet.
			local mode = db.cdMode or 2
			b.cd:ClearAllPoints()
			if mode == 2 then
				b.cd:SetScale(1)
				b.cd:SetAllPoints(b)
			else
				local size = mode == 3 and (s - 2) or s
				b.cd:SetScale(math.max(0.1, size / 36))
				b.cd:SetWidth(36)
				b.cd:SetHeight(36)
				b.cd:SetPoint("CENTER", b, "CENTER", 0, 0)
			end
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
			-- alle Symbole gleich hell; die Abklingzeit zeigt nur der Uhrzeiger
			-- (zusaetzliches Abdunkeln machte sie fast schwarz)
			if b.dimmed ~= a then
				b.dimmed = a
				b.icon:SetAlpha(a)
				b.edge:SetAlpha(a)
				b.icon:SetVertexColor(1, 1, 1)
			end
			-- keine Zahlen, nur Uhrzeiger und Abdunkeln
			local txt = ""
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
	-- neuer Standard 0.7 (0.9.77): alte 0.5 einmal anheben
	local hb = P.DB().herobar
	-- Uhr wie auf der Aktionsleiste: nicht skaliert, sondern auf das Symbol
	-- gezogen (Skalieren liess Naehte bei 6 und 9 Uhr stehen)
	if not hb.cdNoScale then
		hb.cdNoScale = true
		hb.cdMode = nil
	end
	if not hb.alpha07 then
		hb.alpha07 = true
		if not hb.alpha or hb.alpha == 0.5 then
			hb.alpha = 0.7
		end
	end
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

-- /puicd 1|2|3: Art des Uhrzeigers ausprobieren (wirkt sofort)
SLASH_PHANTOMHEROCD1 = "/puicd"
SlashCmdList["PHANTOMHEROCD"] = function(msg)
	local n = tonumber(msg)
	if n and n >= 1 and n <= 3 then
		P.DB().herobar.cdMode = n
		if frame then
			Layout()
		end
	end
	P.Print(P.L("Uhrzeiger-Art: ", "Cooldown sweep mode: ") .. tostring(P.DB().herobar.cdMode or 2) .. "  (/puicd 1, 2, 3)")
end
