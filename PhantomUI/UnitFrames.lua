-- PhantomUI: Spieler- und Zielfenster. Aufbau (Spieler, Ziel gespiegelt):
--   [Level ] [        ] [ Name                    ]
--   [Klasse] [Portraet] [ Leben aktuell/max | 100%]
-- Mana, Wut und Splitter stehen nicht hier, sondern frei unter dem Charakter (Power.lua).

local P = PhantomUI
local GAP = -1 -- Kaesten buendig: Raender ueberlappen zu einer 1-Pixel-Linie
local COL = 22
local PCT = 42

local CLASS_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.5, 0, 0.25 },
	ROGUE = { 0.5, 0.75, 0, 0.25 },
	DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST = { 0.5, 0.75, 0.25, 0.5 },
	WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

local CLASS_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43 },
	MAGE = { 0.41, 0.8, 0.94 },
	ROGUE = { 1, 0.96, 0.41 },
	DRUID = { 1, 0.49, 0.04 },
	HUNTER = { 0.67, 0.83, 0.45 },
	SHAMAN = { 0, 0.44, 0.87 },
	PRIEST = { 1, 1, 1 },
	WARLOCK = { 0.58, 0.51, 0.79 },
	PALADIN = { 0.96, 0.55, 0.73 },
}

local FIXED = {
	phantom = { 0.84, 0.13, 0.25 },
	green = { 0.18, 0.7, 0.25 },
}

local frames = {}

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	return class and CLASS_COLORS[class]
end

local function ReactionColor(unit)
	if not UnitIsPlayer(unit) and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		return { 0.5, 0.5, 0.5 }
	end
	local reaction = UnitReaction(unit, "player")
	if reaction and reaction <= 3 then
		return { 0.84, 0.13, 0.15 }
	elseif reaction == 4 then
		return { 0.9, 0.75, 0.1 }
	end
	return { 0.18, 0.7, 0.25 }
end

local function HealthColor(unit)
	local db = P.DB().unit
	local mode = unit == "player" and db.colorPlayer or db.colorTarget
	if mode == "class" then
		if UnitIsPlayer(unit) then
			return ClassColor(unit) or FIXED.green
		end
		return ReactionColor(unit)
	elseif mode == "reaction" then
		if UnitIsPlayer(unit) and UnitIsFriend(unit, "player") then
			return FIXED.green
		end
		return ReactionColor(unit)
	end
	return FIXED[mode] or FIXED.phantom
end

local function Health(unit)
	local cur, max = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
	-- Fremde Einheiten liefert 1.12 nur in Prozent; AZS kennt die echten Werte des Ziels.
	if unit == "target" and max == 100 and AZS_TARGET and AZS_TARGET.hpm and AZS_TARGET.hpm > 100
		and AZS_TARGET.name == UnitName("target") then
		cur, max = AZS_TARGET.hp or cur, AZS_TARGET.hpm
	end
	return cur, max
end

local function KindBadge(unit)
	local kind = AZS_UnitKind and AZS_UnitKind(unit)
	if kind == "final" or kind == "boss" then
		return "B", 0.95, 0.25, 0.2
	elseif kind == "guardian" then
		return "W", 0.75, 0.45, 1
	elseif kind == "elite" then
		return "E", 1, 0.82, 0
	end
	local classification = UnitClassification(unit)
	if classification == "worldboss" then
		return "B", 0.95, 0.25, 0.2
	elseif classification == "elite" or classification == "rareelite" then
		return "E", 1, 0.82, 0
	elseif classification == "rare" then
		return "R", 0.8, 0.8, 0.85
	end
	return nil
end

------------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------------

local function NewBox(parent, level)
	local box = CreateFrame("Frame", nil, parent)
	box:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
	return box
end

local function Build(unit, mirrored)
	local f = CreateFrame("Button", "PhantomUI_" .. (unit == "player" and "Player" or "Target"), UIParent)
	f.unit = unit
	f.mirrored = mirrored
	f:SetFrameStrata("LOW")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:SetScript("OnClick", function()
		if SpellIsTargeting and SpellIsTargeting() then
			SpellTargetUnit(this.unit)
		elseif arg1 == "LeftButton" then
			TargetUnit(this.unit)
		end
	end)
	f:SetScript("OnEnter", function()
		if UnitExists(this.unit) then
			GameTooltip_SetDefaultAnchor(GameTooltip, this)
			GameTooltip:SetUnit(this.unit)
			GameTooltip:Show()
		end
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.levelBox = NewBox(f)
	f.level = nil -- wird an der Namensleiste angelegt (siehe unten)

	f.classBox = NewBox(f)
	f.classIcon = f.classBox:CreateTexture(nil, "ARTWORK")
	f.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	f.classIcon:SetPoint("TOPLEFT", f.classBox, "TOPLEFT", 2, -2)
	f.classIcon:SetPoint("BOTTOMRIGHT", f.classBox, "BOTTOMRIGHT", -2, 2)
	f.badge = P.Text(f.classBox, 12)
	f.badge:SetPoint("CENTER", f.classBox, "CENTER", 0, 0)

	f.portraitBox = NewBox(f)
	f.model = CreateFrame("PlayerModel", nil, f.portraitBox)
	f.model:SetPoint("TOPLEFT", f.portraitBox, "TOPLEFT", 1, -1)
	f.model:SetPoint("BOTTOMRIGHT", f.portraitBox, "BOTTOMRIGHT", -1, 1)
	f.model:SetFrameLevel(f.portraitBox:GetFrameLevel() + 1)
	-- Der Client laedt das Modell nur fuer sichtbare Rahmen und kennt die Kamera erst,
	-- wenn das Modell geladen ist. Darum beim Zeigen neu setzen und die Kamera ein paar
	-- Mal nachreichen.
	f.model:SetScript("OnShow", function()
		this.retry = 3
		this.wait = 0
		if UnitExists(f.unit) then
			this:SetUnit(f.unit)
			this:SetCamera(0)
		end
	end)
	f.model:SetScript("OnUpdate", function()
		if not this.retry or this.retry <= 0 then
			return
		end
		this.wait = this.wait + arg1
		if this.wait < 0.4 then
			return
		end
		this.wait = 0
		this.retry = this.retry - 1
		if UnitExists(f.unit) then
			this:SetUnit(f.unit)
			this:SetCamera(0)
		end
	end)
	f.flat = f.portraitBox:CreateTexture(nil, "ARTWORK")
	f.flat:SetPoint("TOPLEFT", f.portraitBox, "TOPLEFT", 1, -1)
	f.flat:SetPoint("BOTTOMRIGHT", f.portraitBox, "BOTTOMRIGHT", -1, 1)
	-- Das 2D-Portraet ist rund; der innere Ausschnitt fuellt den Kasten ohne Ecken.
	f.flat:SetTexCoord(0.15, 0.85, 0.15, 0.85)

	f.nameBox = NewBox(f)
	f.name = P.Text(f.nameBox, 12)
	f.level = P.Text(f.nameBox, 11)
	f.name:SetPoint("TOPLEFT", f.nameBox, "TOPLEFT", 6, -1)
	f.name:SetPoint("BOTTOMRIGHT", f.nameBox, "BOTTOMRIGHT", -6, 1)
	if f.name.SetJustifyV then
		f.name:SetJustifyV("MIDDLE")
	end

	f.healthBox = NewBox(f)
	f.bar = CreateFrame("StatusBar", nil, f.healthBox)
	f.bar:SetFrameLevel(f.healthBox:GetFrameLevel() + 1)
	f.barBg = f.bar:CreateTexture(nil, "BACKGROUND")
	f.barBg:SetAllPoints(f.bar)
	local textHolder = CreateFrame("Frame", nil, f.healthBox)
	textHolder:SetAllPoints(f.healthBox)
	textHolder:SetFrameLevel(f.bar:GetFrameLevel() + 2)
	-- Trennlinie liegt ueber der Leiste: die Lebensleiste laeuft bis in das %-Feld
	f.divider = textHolder:CreateTexture(nil, "OVERLAY")
	f.divider:SetTexture(P.FLAT)
	f.divider:SetVertexColor(0, 0, 0, 1)
	f.divider:SetWidth(1)
	f.hp = P.Text(textHolder, 12)
	f.hp:SetPoint("CENTER", f.bar, "CENTER", 0, 0)
	f.pct = P.Text(textHolder, 12)

	frames[unit] = f
	return f
end

-- Setzt alle Kaesten nach den Einstellungen neu zusammen.
local function Layout(f)
	local db = P.DB().unit
	local barW, hpH, nameH = db.width, db.height, db.nameHeight
	local portraitSize = db.portrait and (nameH + GAP + hpH) or 0
	local totalH = nameH + GAP + hpH
	-- Klassensymbol als Quadrat ueber die volle Hoehe, wie das Portraet.
	local colW = db.class and totalH or 0
	local totalW = barW
		+ (portraitSize > 0 and (portraitSize + GAP) or 0)
		+ (colW > 0 and (colW + GAP) or 0)

	f:SetScale(db.scale)
	f:SetWidth(totalW)
	f:SetHeight(totalH)

	local font = P.Font()
	local tex = P.Texture()
	for _, box in ipairs({ f.levelBox, f.classBox, f.portraitBox, f.nameBox, f.healthBox }) do
		P.Box(box, db.bgAlpha)
	end

	-- Von aussen nach innen: Spieler hat die Spalte links aussen, das Ziel rechts aussen.
	local x = 0
	local function Put(box, width, height, top)
		box:ClearAllPoints()
		box:SetWidth(width)
		box:SetHeight(height)
		if f.mirrored then
			box:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, -top)
		else
			box:SetPoint("TOPLEFT", f, "TOPLEFT", x, -top)
		end
	end

	f.levelBox:Hide()
	if colW > 0 then
		Put(f.classBox, colW, totalH, 0)
		x = x + colW + GAP
		f.classBox:Show()
	else
		f.classBox:Hide()
	end

	-- Level in der Namensleiste, in der Ecke weg vom Portraet
	-- (Spieler rechts oben, Ziel links oben); der Name macht dafuer Platz.
	local levelW = db.level and 24 or 0
	f.level:ClearAllPoints()
	f.name:ClearAllPoints()
	if f.mirrored then
		f.level:SetPoint("LEFT", f.nameBox, "LEFT", 5, 0)
		f.name:SetPoint("TOPLEFT", f.nameBox, "TOPLEFT", 6 + levelW, -1)
		f.name:SetPoint("BOTTOMRIGHT", f.nameBox, "BOTTOMRIGHT", -6, 1)
	else
		f.level:SetPoint("RIGHT", f.nameBox, "RIGHT", -5, 0)
		f.name:SetPoint("TOPLEFT", f.nameBox, "TOPLEFT", 6, -1)
		f.name:SetPoint("BOTTOMRIGHT", f.nameBox, "BOTTOMRIGHT", -6 - levelW, 1)
	end
	if db.level then
		f.level:Show()
	else
		f.level:SetText("")
		f.level:Hide()
	end
	if portraitSize > 0 then
		Put(f.portraitBox, portraitSize, portraitSize, 0)
		x = x + portraitSize + GAP
		f.portraitBox:Show()
	else
		f.portraitBox:Hide()
	end
	Put(f.nameBox, barW, nameH, 0)
	Put(f.healthBox, barW, hpH, nameH + GAP)

	-- Prozentfeld so breit wie "100%" in der eingestellten Schrift, plus Luft.
	local pctW = 0
	if db.percent then
		f.pct:SetFont(P.Font(), db.fontSize - 1, "OUTLINE")
		f.pct:SetText("100%")
		local textW = f.pct.GetStringWidth and f.pct:GetStringWidth() or 0
		pctW = math.max(PCT, math.ceil(textW) + 12)
	end
	f.bar:ClearAllPoints()
	f.bar:SetPoint("TOPLEFT", f.healthBox, "TOPLEFT", 1, -1)
	f.bar:SetPoint("BOTTOMRIGHT", f.healthBox, "BOTTOMRIGHT", -1, 1)
	-- Lebenszahl mittig im Teil links vom %-Feld
	f.hp:ClearAllPoints()
	f.hp:SetPoint("CENTER", f.healthBox, "LEFT", (barW - pctW) / 2, 0)
	f.bar:SetStatusBarTexture(tex)
	f.barBg:SetTexture(tex)
	f.divider:ClearAllPoints()
	if pctW > 0 then
		f.divider:SetPoint("TOP", f.healthBox, "TOPRIGHT", -1 - pctW, -1)
		f.divider:SetPoint("BOTTOM", f.healthBox, "BOTTOMRIGHT", -1 - pctW, 1)
		-- keine schwarze Trennlinie: die Leiste laeuft durchgehend bis ins %-Feld
		f.divider:Hide()
		f.pct:ClearAllPoints()
		f.pct:SetPoint("CENTER", f.healthBox, "RIGHT", -1 - pctW / 2, 0)
		f.pct:Show()
	else
		f.divider:Hide()
		f.pct:Hide()
	end

	local size = db.fontSize
	f.name:SetFont(font, math.min(size, nameH - 1), "OUTLINE")
	f.hp:SetFont(font, size, "OUTLINE")
	f.pct:SetFont(font, size - 1, "OUTLINE")
	f.level:SetFont(font, math.min(size - 1, nameH - 1), "OUTLINE")
	f.badge:SetFont(font, size, "OUTLINE")
	if f.mirrored then
		f.name:SetJustifyH("RIGHT")
	else
		f.name:SetJustifyH("LEFT")
	end
	f.lastModel = nil
end

------------------------------------------------------------------------
-- Inhalt
------------------------------------------------------------------------

local function UpdatePortrait(f, unit)
	local db = P.DB().unit
	if not db.portrait then
		return
	end
	if db.portrait3d and UnitIsVisible(unit) then
		f.flat:Hide()
		f.model:Show()
		local key = UnitName(unit) or ""
		if f.lastModel ~= key then
			f.lastModel = key
			f.model:SetUnit(unit)
			f.model:SetCamera(0)
			f.model.retry = 3
			f.model.wait = 0
		end
	else
		f.model:Hide()
		f.lastModel = nil
		f.flat:Show()
		SetPortraitTexture(f.flat, unit)
	end
end

local function Update(f)
	local unit = f.unit
	local db = P.DB().unit
	if not UnitExists(unit) then
		if P.unlocked then
			-- Vorschau, damit man das Zielfenster auch ohne Ziel verschieben kann.
			f:Show()
			f.name:SetText("Ziel")
			f.hp:SetText("")
			f.pct:SetText("")
			f.level:SetText("")
			f.classIcon:Hide()
			f.badge:SetText("")
			f.bar:SetMinMaxValues(0, 1)
			f.bar:SetValue(1)
			f.bar:SetStatusBarColor(0.4, 0.4, 0.4)
			f.barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
			f.model:Hide()
			f.flat:Hide()
			return
		end
		f:Hide()
		return
	end
	f:Show()

	local name = UnitName(unit) or ""
	f.name:SetText(name)
	local nc = UnitIsPlayer(unit) and ClassColor(unit) or nil
	if nc then
		f.name:SetTextColor(nc[1], nc[2], nc[3])
	else
		local rc = ReactionColor(unit)
		f.name:SetTextColor(0.6 + rc[1] * 0.4, 0.6 + rc[2] * 0.4, 0.6 + rc[3] * 0.4)
	end

	local cur, max = Health(unit)
	if max <= 0 then
		max = 1
	end
	f.bar:SetMinMaxValues(0, max)
	f.bar:SetValue(cur)
	local c = HealthColor(unit)
	f.bar:SetStatusBarColor(c[1], c[2], c[3])
	f.barBg:SetVertexColor(c[1] * 0.2, c[2] * 0.2, c[3] * 0.2, 0.9)
	if UnitIsDead(unit) or UnitIsGhost(unit) then
		f.hp:SetText("Tot")
		f.pct:SetText("0%")
	else
		if db.short then
			f.hp:SetText(P.Short(cur) .. " / " .. P.Short(max))
		else
			f.hp:SetText(cur .. " / " .. max)
		end
		f.pct:SetText(math.floor(cur / max * 100 + 0.5) .. "%")
	end

	if db.level then
		local level = UnitLevel(unit)
		if level and level > 0 then
			f.level:SetText(level)
			local color = GetDifficultyColor and GetDifficultyColor(level)
			if color and unit ~= "player" then
				f.level:SetTextColor(color.r, color.g, color.b)
			else
				f.level:SetTextColor(1, 0.82, 0)
			end
		else
			f.level:SetText("??")
			f.level:SetTextColor(1, 0.2, 0.2)
		end
	end

	if db.class then
		local _, class = UnitClass(unit)
		local coords = UnitIsPlayer(unit) and class and CLASS_COORDS[class]
		if coords then
			f.classIcon:SetTexCoord(coords[1] + 0.02, coords[2] - 0.02, coords[3] + 0.02, coords[4] - 0.02)
			f.classIcon:Show()
			f.badge:SetText("")
		else
			f.classIcon:Hide()
			local letter, r, g, b = KindBadge(unit)
			f.badge:SetText(letter or "")
			if letter then
				f.badge:SetTextColor(r, g, b)
			end
		end
	else
		f.classIcon:Hide()
		f.badge:SetText("")
	end

	UpdatePortrait(f, unit)
end

local function UpdateAll()
	for _, f in pairs(frames) do
		Update(f)
	end
end

-- Die alten Fenster des Spiels und von SurvivorsDragonUi abschalten.
local function Silence(frame)
	if not frame then
		return
	end
	frame:UnregisterAllEvents()
	frame:Hide()
	frame.Show = function() end
end

------------------------------------------------------------------------
-- Debuffs am Ziel (zeigte vorher das ausgeblendete Zielfenster des Spiels)
------------------------------------------------------------------------

local MAX_DEBUFFS = 16
local DEBUFF_COLORS = {
	Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}

-- Restzeit aus den Laufdaten, wenn das Spiel sie fuer dieses Ziel mitschickt
local function AzsTimes(target)
	local t = AZS_TARGET
	if type(t) ~= "table" or not t.id or type(AZS_GetDebuffs) ~= "function" then
		return nil
	end
	local ok, list = pcall(AZS_GetDebuffs, t.id)
	if not ok or type(list) ~= "table" or table.getn(list) == 0 then
		return nil
	end
	local byIcon = {}
	for i = 1, table.getn(list) do
		local d = list[i]
		if d.icon and d.remaining then
			local _, _, short = string.find(string.lower(d.icon), "([^\\]+)$")
			byIcon[short or string.lower(d.icon)] = d.remaining
		end
	end
	return byIcon
end

local function BuildTargetDebuffs(target)
	local row = CreateFrame("Frame", "PhantomUI_TargetDebuffs", target)
	row:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -3)
	row:SetWidth(1)
	row:SetHeight(1)
	local icons = {}
	local function Icon(i)
		local b = icons[i]
		if b then
			return b
		end
		b = CreateFrame("Frame", nil, row)
		b.edge = b:CreateTexture(nil, "BACKGROUND")
		b.edge:SetTexture(P.FLAT)
		b.edge:SetAllPoints(b)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		b.count = b:CreateFontString(nil, "OVERLAY")
		b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 1)
		b.time = b:CreateFontString(nil, "OVERLAY")
		b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
		icons[i] = b
		return b
	end
	local function Refresh()
		if not UnitExists("target") then
			row:Hide()
			return
		end
		row:Show()
		local size = math.max(16, P.DB().unit.debuffSize or 22)
		local font = P.Font()
		local times = AzsTimes()
		local n = 0
		for i = 1, MAX_DEBUFFS do
			local texture, count, kind = UnitDebuff("target", i)
			if not texture then
				break
			end
			n = n + 1
			local b = Icon(n)
			if b.size ~= size or b.font ~= font then
				b.size, b.font = size, font
				b:SetWidth(size)
				b:SetHeight(size)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", row, "TOPLEFT", (n - 1) * (size + 1), 0)
				b.count:SetFont(font, math.max(8, math.floor(size * 0.42)), "OUTLINE")
				b.time:SetFont(font, math.max(8, math.floor(size * 0.45)), "OUTLINE")
			end
			if b.texture ~= texture then
				b.texture = texture
				b.tex:SetTexture(texture)
			end
			local c = DEBUFF_COLORS[kind or ""]
			if c then
				b.edge:SetVertexColor(c[1], c[2], c[3], 1)
			else
				b.edge:SetVertexColor(0, 0, 0, 1)
			end
			b.count:SetText((count and count > 1) and count or "")
			local left
			if times then
				local _, _, short = string.find(string.lower(texture), "([^\\]+)$")
				left = times[short or ""]
			end
			if left and left > 0 then
				b.time:SetText(left >= 60 and (math.floor(left / 60) .. "m") or math.floor(left + 0.5))
			else
				b.time:SetText("")
			end
			b:Show()
		end
		for i = n + 1, table.getn(icons) do
			icons[i]:Hide()
		end
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UNIT_AURA")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:SetScript("OnEvent", function()
		if event == "UNIT_AURA" and arg1 ~= "target" then
			return
		end
		Refresh()
	end)
	local t = 0
	ev:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.5 then
			t = 0
			Refresh()
		end
	end)
	Refresh()
end

local function Init()
	if not P.DB().unit.enabled then
		return
	end
	Silence(PlayerFrame)
	Silence(TargetFrame)

	-- Kombopunkte: die Anzeige des Spiels bleibt, haengt aber nicht mehr am
	-- (versteckten) Zielfenster, sondern an einem eigenen, verschiebbaren Halter.
	if ComboFrame then
		local holder = CreateFrame("Frame", "PhantomUI_ComboHolder", UIParent)
		holder:SetWidth(ComboFrame:GetWidth() > 1 and ComboFrame:GetWidth() or 80)
		holder:SetHeight(ComboFrame:GetHeight() > 1 and ComboFrame:GetHeight() or 30)
		ComboFrame:SetParent(holder)
		ComboFrame:ClearAllPoints()
		ComboFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
		P.RegisterMover("combo", holder, "Kombopunkte", function(f)
			f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
		end, {
			uniform = true,
			get = function()
				local sc = P.DB().unit.comboScale or 1
				return sc * 100, sc * 100
			end,
			set = function(w, h)
				P.DB().unit.comboScale = P.Clamp(h, 50, 300) / 100
			end,
		})
		local function ApplyCombo()
			holder:SetScale(P.DB().unit.comboScale or 1)
		end
		ApplyCombo()
		P.OnApply(ApplyCombo)
	end

	local player = Build("player", false)
	local target = Build("target", true)
	Layout(player)
	Layout(target)

	-- Groesse ziehen aendert Breite und Hoehe der Lebensleiste (gilt fuer beide Fenster).
	local sizer = {
		scale = "unit",
		get = function()
			local db = P.DB().unit
			return db.width, db.height
		end,
		set = function(w, h)
			local db = P.DB().unit
			db.width = P.Clamp(w, 100, 360)
			db.height = P.Clamp(h, 14, 50)
		end,
	}
	P.RegisterMover("player", player, "Spieler", function(frame)
		frame:SetPoint("CENTER", UIParent, "CENTER", -260, -150)
	end, sizer)
	P.RegisterMover("target", target, "Ziel", function(frame)
		frame:SetPoint("CENTER", UIParent, "CENTER", 260, -150)
	end, sizer)

	local events = CreateFrame("Frame")
	for _, e in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_TARGET_CHANGED",
		"UNIT_HEALTH",
		"UNIT_MAXHEALTH",
		"UNIT_LEVEL",
		"UNIT_NAME_UPDATE",
		"UNIT_FACTION",
		"UNIT_PORTRAIT_UPDATE",
		"UNIT_MODEL_CHANGED",
		"PLAYER_LEVEL_UP",
	}) do
		events:RegisterEvent(e)
	end
	events:SetScript("OnEvent", function()
		if event == "PLAYER_TARGET_CHANGED" then
			target.lastModel = nil
			Update(target)
		elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
			player.lastModel = nil
			UpdateAll()
		elseif arg1 and frames[arg1] then
			if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
				frames[arg1].lastModel = nil
			end
			Update(frames[arg1])
		end
	end)
	-- Das Ziel zusaetzlich viermal pro Sekunde: AZS schickt seine Werte als Nachricht.
	local elapsed = 0
	events:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed > 0.25 then
			elapsed = 0
			Update(target)
		end
	end)

	P.OnApply(function()
		Layout(player)
		Layout(target)
		UpdateAll()
	end)
	UpdateAll()
	BuildTargetDebuffs(target)
end

P.OnInit(Init)
