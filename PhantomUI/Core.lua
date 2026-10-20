-- PhantomUI: eigene Oberflaeche fuer Azeroth Survivors, Stueck fuer Stueck als
-- Ersatz fuer SurvivorsDragonUi. Kern: Einstellungen, Texturen, Schriften und das
-- Verschieben der Rahmen.

PhantomUI = {}
local P = PhantomUI

P.FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
P.MEDIA = "Interface\\AddOns\\PhantomUI\\media\\"
P.ACCENT = { 0.62, 0.30, 0.92 }

P.TEXTURES = {
	{ key = "phantom", name = "Phantom", path = P.MEDIA .. "Phantom" },
	{ key = "glanz", name = "Glanz", path = P.MEDIA .. "Glanz" },
	{ key = "verlauf", name = "Verlauf", path = P.MEDIA .. "Verlauf" },
	{ key = "flach", name = "Flach", path = P.FLAT },
	{ key = "blizzard", name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
}

P.FONTS = {
	{ key = "friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ key = "arial", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ key = "roboto", name = "Roboto (modern)", path = "Interface\\AddOns\\PhantomUI\\media\\Roboto.ttf" },
}

-- Sprache der eigenen Texte (Menues, Ankermodus, Meldungen): Deutsch oder
-- Englisch. "auto" folgt der Spielsprache (aus den Spieldaten erkannt), sonst
-- der Client-Sprache; alles ausser Deutsch zeigt Englisch.
P.EN = P.EN or {}
P.LOC = P.LOC or {}
-- Alle Sprachen, die Azeroth Survivors anbietet
P.LANGS = { "enUS", "deDE", "frFR", "esES", "ptBR", "plPL", "csCZ", "roRO", "trTR", "ruRU", "ukUA", "zhCN", "jaJP", "koKR" }
local LANG_OK = {}
for i = 1, table.getn(P.LANGS) do
	LANG_OK[P.LANGS[i]] = true
end
function P.UILang()
	local db = PhantomUIDB
	local set = db and db.uiLang
	if set and LANG_OK[set] then
		return set
	end
	local game = db and db.lang
	if game and LANG_OK[game] then
		return game
	end
	return "enUS"
end

-- Deutschen Text uebersetzen (Schluessel = deutscher Text, siehe Locale.lua).
-- Fehlt eine Sprache, gilt Englisch.
function P.T(text)
	if type(text) ~= "string" then
		return text
	end
	local lang = P.UILang()
	if lang == "deDE" then
		return text
	end
	local t = P.LOC[lang]
	return (t and t[text]) or P.EN[text] or text
end

-- Fuer zusammengesetzte Texte: deutsche und englische Fassung direkt angeben
function P.L(de, en)
	if P.UILang() == "deDE" then
		return de
	end
	return en
end

-- Schrift, die die Buchstaben der Sprache auch hat: Friz kennt nur
-- westeuropaeische Zeichen. Osteuropaeisch, Tuerkisch, Kyrillisch -> Roboto;
-- Chinesisch/Japanisch und Koreanisch -> die Schriften des Spiels.
local LATIN_EXT = { plPL = true, csCZ = true, roRO = true, trTR = true, ruRU = true, ukUA = true }
function P.ScriptFont(path)
	local db = PhantomUIDB
	local a = P.UILang()
	local b = db and db.lang or a
	if a == "koKR" or b == "koKR" then
		return "Fonts\\AZS_KR.TTF"
	end
	if a == "zhCN" or b == "zhCN" or a == "jaJP" or b == "jaJP" then
		return "Fonts\\AZS_SC.TTF"
	end
	if LATIN_EXT[a] or LATIN_EXT[b] then
		if path and string.find(path, "Roboto") then
			return path
		end
		return "Interface\\AddOns\\PhantomUI\\media\\Roboto.ttf"
	end
	return path
end

function P.FontPath(key)
	for i = 1, table.getn(P.FONTS) do
		if P.FONTS[i].key == key then
			return P.ScriptFont(P.FONTS[i].path)
		end
	end
	return P.ScriptFont(P.FONTS[1].path)
end

local DEFAULTS = {
	uiLang = "auto",
	texture = "phantom",
	font = "friz",
	grid = true,
	gridSize = 24,
	pos = {},
	bar = {
		enabled = true,
		size = 34,
		spacing = -1,
		padding = 0,
		background = false,
		bgAlpha = 0.6,
		border = true,
		scale = 1,
	},
	unit = {
		enabled = true,
		width = 145,
		height = 25,
		nameHeight = 12,
		portrait = true,
		portrait3d = false,
		level = true,
		class = true,
		percent = true,
		short = false,
		colorPlayer = "class",
		colorTarget = "reaction",
		bgAlpha = 0.85,
		scale = 1.06,
		fontSize = 11,
	},
	power = {
		enabled = true,
		width = 197,
		height = 17,
		text = true,
		shards = true,
		showMana = false,
		border = 2,
		scale = 1.07,
		bgAlpha = 0,
	},
	run = {
		enabled = true,
		width = 300,
		height = 8,
		bossHeight = 18,
		scale = 1,
	},
	-- Boss-Leisten: eigene Breite (0 = so breit wie das Zielfenster), Hoehe, Skalierung
	bosses = {
		width = 0,
		height = 18,
		scale = 1,
	},
	xp = {
		enabled = true,
		width = 232,
		height = 6,
		scale = 1,
	},
	menu = { enabled = true },
	chat = { enabled = true, bgAlpha = 0, font = "roboto", fontSize = 13, fade = 10 },
	plates = { enabled = true },
	plan = {
		enabled = true,
		choice = false,
		size = 28,
		data = {},
	},
	auras = {
		enabled = true,
		size = 30,
	},
	minimap = {
		enabled = true,
		size = 180,
		scale = 1,
		buttons = "bottom",
		buttonSize = 22,
		collect = true,
		rotate = true,
	},
	stats = { enabled = true, scale = 1, bgAlpha = 0 },
	alerts = { enabled = true, hideNative = true, errors = true, size = 13, scale = 1, width = 360 },
	-- Speicherbereinigung steuern: im Kampf aufschieben (MB Puffer), in ruhigen Momenten aufraeumen
	gc = { enabled = true, budget = 48 },
	tally = {
		enabled = true,
		width = 170,
		height = 20,
		scale = 1.11,
		bgAlpha = 0,
	},
}

local DB_VERSION = 15

local function Merge(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			Merge(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function Copy(source)
	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = Copy(value)
		else
			result[key] = value
		end
	end
	return result
end

function P.DB()
	return PhantomUIDB
end

function P.Defaults()
	return DEFAULTS
end

function P.ResetSection(section)
	local db = P.DB()
	if section then
		db[section] = Copy(DEFAULTS[section])
	else
		local pos = db.pos
		for key in pairs(db) do
			db[key] = nil
		end
		Merge(db, DEFAULTS)
		db.pos = pos
	end
	P.Apply()
end

function P.Clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function P.Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9d4de8PhantomUI|r: " .. P.T(message))
end

function P.Texture()
	local key = P.DB().texture
	for i = 1, table.getn(P.TEXTURES) do
		if P.TEXTURES[i].key == key then
			return P.TEXTURES[i].path
		end
	end
	return P.TEXTURES[1].path
end

function P.Font()
	return P.FontPath(P.DB().font)
end

-- Dunkle Flaeche mit 1-Pixel-Rand, der Grundbaustein aller Kaesten.
function P.Box(frame, alpha, edge)
	edge = edge or 1
	frame:SetBackdrop({
		bgFile = P.FLAT,
		edgeFile = P.FLAT,
		edgeSize = edge,
		insets = { left = edge, right = edge, top = edge, bottom = edge },
	})
	frame:SetBackdropColor(0.06, 0.06, 0.07, alpha or 0.85)
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

function P.Text(parent, size, flags)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(P.Font(), size or 12, flags or "OUTLINE")
	text:SetTextColor(1, 1, 1)
	return text
end

function P.Short(value)
	if not value then
		return "0"
	end
	-- Endlos-Modus: Werte wachsen in Milliarden und Billionen
	if value >= 1000000000000 then
		return string.format("%.1fT", value / 1000000000000)
	elseif value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

------------------------------------------------------------------------
-- Aktualisieren nach Aenderungen im Menue
------------------------------------------------------------------------

local appliers = {}

function P.OnApply(fn)
	table.insert(appliers, fn)
end

function P.Apply()
	if not P.ready then
		return
	end
	for i = 1, table.getn(appliers) do
		appliers[i]()
	end
	P.PlaceAll()
end

------------------------------------------------------------------------
-- Rahmen verschieben
-- Positionen werden als Abstand der Rahmenmitte zur Bildschirmmitte gespeichert,
-- in Bildschirm-Einheiten, damit eine geaenderte Groesse sie nicht verschiebt.
------------------------------------------------------------------------

local movers = {}

-- Standardplaetze (Abstand der Rahmenmitte zur Bildschirmmitte), so wie Nobby
-- sie eingerichtet hat. Spieler und Ziel spiegelgleich.
local DEFAULT_POS = {
	actionbar = { x = 0, y = -232 },
	auras = { x = 0, y = -95 },
	power = { x = 0, y = -143 },
	tally = { x = 0, y = -172 },
	-- Laufwerte: Mitte genau auf Gitter X -11 / Y -11 (24 px je Kaestchen)
	stats = { x = -264, y = -264 },
	player = { x = -229, y = -148 },
	target = { x = 229, y = -148 },
}
P.unlocked = false

function P.Place(key)
	local m = movers[key]
	if not m or m.ext then
		return -- fremder Rahmen (z. B. Schadensmeter) merkt sich seinen Platz selbst
	end
	local frame = m.frame
	local pos = P.DB().pos[key] or DEFAULT_POS[key]
	frame:ClearAllPoints()
	frame.docked = nil -- nur der Standardplatz darf an andere Fenster andocken
	if pos and pos.x and pos.y then
		local us = UIParent:GetEffectiveScale()
		local fs = frame:GetEffectiveScale()
		frame:SetPoint("CENTER", UIParent, "CENTER", pos.x * us / fs, pos.y * us / fs)
	else
		m.default(frame)
	end
end

function P.PlaceAll()
	for key in pairs(movers) do
		P.Place(key)
	end
end

local function SavePosition(key)
	if movers[key].ext then
		movers[key].ext.save()
		return
	end
	local frame = movers[key].frame
	local cx, cy = frame:GetCenter()
	if not cx then
		return
	end
	local fs = frame:GetEffectiveScale()
	local us = UIParent:GetEffectiveScale()
	local ux, uy = UIParent:GetCenter()
	P.DB().pos[key] = { x = cx * fs / us - ux, y = cy * fs / us - uy }
	P.Place(key)
end

local function MakeOverlay(key)
	local m = movers[key]
	local overlay = CreateFrame("Button", nil, UIParent)
	-- ueber allen Rahmen, auch ueber den Boss-Leisten (FULLSCREEN_DIALOG)
	overlay:SetFrameStrata("FULLSCREEN_DIALOG")
	overlay:SetFrameLevel(60)
	overlay:SetAllPoints(m.frame)
	overlay:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
	overlay:SetBackdropColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 0.35)
	overlay:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
	overlay:RegisterForDrag("LeftButton")
	overlay:RegisterForClicks("RightButtonUp")
	local label = overlay:CreateFontString(nil, "OVERLAY")
	label:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 11, "OUTLINE")
	label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
	label:SetText(P.T(m.label))
	overlay:SetScript("OnDragStart", function()
		m.frame:SetMovable(true)
		m.frame:StartMoving()
	end)
	overlay:SetScript("OnDragStop", function()
		m.frame:StopMovingOrSizing()
		SavePosition(key)
	end)
	-- Rechtsklick: zurueck an den Standardplatz.
	overlay:SetScript("OnClick", function()
		if m.ext then
			m.frame:ClearAllPoints()
			m.default(m.frame)
			m.ext.save()
			return
		end
		P.DB().pos[key] = nil
		P.Place(key)
	end)
	overlay:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(P.T(m.label))
		GameTooltip:AddLine(P.T("Ziehen: verschieben"), 1, 1, 1)
		GameTooltip:AddLine(P.T("Rechtsklick: Standardplatz"), 1, 1, 1)
		if m.sizer and m.sizer.get then
			GameTooltip:AddLine(P.T("Kanten ziehen: Breite / Höhe"), 1, 1, 1)
		end
		if m.sizer and m.sizer.scale then
			GameTooltip:AddLine(P.T("Ecke unten rechts: alles skalieren"), 1, 1, 1)
		end
		if m.sizer and m.sizer.scale then
			GameTooltip:AddLine(P.T("Mausrad: Skalierung"), 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Mausrad: Skalierung (bzw. Groesse bei "uniform")
	if m.sizer and m.sizer.uniform then
		overlay:EnableMouseWheel(true)
		overlay:SetScript("OnMouseWheel", function()
			local w, h = m.sizer.get()
			m.sizer.set(w, h + arg1, "h")
			P.Apply()
		end)
	elseif m.sizer and m.sizer.scale then
		overlay:EnableMouseWheel(true)
		overlay:SetScript("OnMouseWheel", function()
			local section = P.DB()[m.sizer.scale]
			section.scale = math.max(0.5, math.min(2, math.floor((section.scale + arg1 * 0.05) * 100 + 0.5) / 100))
			P.Apply()
		end)
	end

	-- Griffe: Kanten aendern nur Breite bzw. Hoehe, die Ecke unten rechts skaliert alles.
	if m.sizer then
		local function Begin(mode)
			SavePosition(key) -- Mitte als Anker, damit beide Seiten gleich wachsen
			local x, y = GetCursorPosition()
			local st = { x = x, y = y, mode = mode, es = m.frame:GetEffectiveScale() }
			if mode == "corner" then
				st.W = m.frame:GetWidth() * st.es
				if m.sizer.uniform then
					st.w, st.h = m.sizer.get()
				else
					st.scale = P.DB()[m.sizer.scale].scale
				end
			else
				st.w, st.h = m.sizer.get()
			end
			return st
		end
		local function Step(st)
			local x, y = GetCursorPosition()
			if st.mode == "corner" then
				local d = ((x - st.x) + (st.y - y)) / 2
				local factor = (st.W + 2 * d) / st.W
				if m.sizer.uniform then
					m.sizer.set(math.floor(st.w * factor + 0.5), math.floor(st.h * factor + 0.5), "h")
				else
					local scale = math.floor(P.Clamp(st.scale * factor, 0.5, 2.5) * 100 + 0.5) / 100
					P.DB()[m.sizer.scale].scale = scale
				end
			else
				local dx = (x - st.x) / st.es
				local dy = (y - st.y) / st.es
				local w, h = st.w, st.h
				if st.mode == "left" then
					m.sizer.set(math.floor(w - 2 * dx + 0.5), h, "w")
				elseif st.mode == "right" then
					m.sizer.set(math.floor(w + 2 * dx + 0.5), h, "w")
				elseif st.mode == "top" then
					m.sizer.set(w, math.floor(h + 2 * dy + 0.5), "h")
				else
					m.sizer.set(w, math.floor(h - 2 * dy + 0.5), "h")
				end
			end
			P.Apply()
		end
		local function Grip(mode, tip)
			local grip = CreateFrame("Button", nil, overlay)
			grip:SetFrameLevel(overlay:GetFrameLevel() + 2)
			local tex = grip:CreateTexture(nil, "OVERLAY")
			tex:SetTexture(P.FLAT)
			tex:SetAllPoints(grip)
			local idle = mode == "corner" and 0.9 or 0.45
			tex:SetVertexColor(1, 1, 1, idle)
			grip:RegisterForDrag("LeftButton")
			grip:SetScript("OnEnter", function()
				tex:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
				GameTooltip:SetOwner(this, "ANCHOR_TOP")
				GameTooltip:SetText(P.T(tip))
				GameTooltip:Show()
			end)
			grip:SetScript("OnLeave", function()
				tex:SetVertexColor(1, 1, 1, idle)
				GameTooltip:Hide()
			end)
			grip:SetScript("OnDragStart", function()
				this.st = Begin(mode)
				this.wait = 0
			end)
			grip:SetScript("OnDragStop", function()
				this.st = nil
				SavePosition(key)
				P.Apply()
			end)
			grip:SetScript("OnUpdate", function()
				if not this.st then
					return
				end
				this.wait = this.wait + arg1
				if this.wait >= 0.04 then
					this.wait = 0
					Step(this.st)
				end
			end)
			return grip
		end
		local T = 5
		if m.sizer.get then
			local l = Grip("left", "Breite ziehen")
			l:SetWidth(T)
			-- kleine Randabstaende, damit die Griffe auch bei schmalen Leisten bleiben
			l:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, -3)
			l:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 3)
			local r = Grip("right", "Breite ziehen")
			r:SetWidth(T)
			r:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, -3)
			r:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 3)
			local t = Grip("top", "Höhe ziehen")
			t:SetHeight(T)
			t:SetPoint("TOPLEFT", overlay, "TOPLEFT", 12, 0)
			t:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -12, 0)
			local b = Grip("bottom", "Höhe ziehen")
			b:SetHeight(T)
			b:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 12, 0)
			b:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -12, 0)
		end
		if m.sizer.scale or m.sizer.uniform then
			local c = Grip("corner", "Alles größer/kleiner skalieren")
			c:SetFrameLevel(overlay:GetFrameLevel() + 3)
			c:SetWidth(12)
			c:SetHeight(12)
			c:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
		end
	end
	overlay:Hide()
	m.overlay = overlay
end

-- sizer (optional): { get = function() return w, h end, set = function(w, h) end, scale = "abschnitt" }
-- ext (optional): { save = function() end } fuer Rahmen, die ihren Platz selbst speichern.
function P.RegisterMover(key, frame, label, default, sizer, ext)
	movers[key] = { frame = frame, label = label, default = default, sizer = sizer, ext = ext }
	MakeOverlay(key)
	if P.ready then
		P.Place(key)
	end
end

------------------------------------------------------------------------
-- Gitter fuer die Ankerpunkte. Die Mittellinien (X 0 / Y 0) sind schwarz; die
-- Linien gleich weit links und rechts (bzw. oben und unten) der Mitte haben
-- dieselbe Farbe, damit man Rahmen spiegelgleich ausrichten kann.
------------------------------------------------------------------------

-- Schwarz nur fuer die Mittellinien; danach 5 Violetttoene von dunkel bis hell,
-- und dann wieder von vorne.
local GRID_COLORS = {
	{ 0.30, 0.10, 0.50, 0.75 },
	{ 0.42, 0.18, 0.68, 0.65 },
	{ 0.55, 0.28, 0.85, 0.55 },
	{ 0.70, 0.48, 0.95, 0.5 },
	{ 0.85, 0.72, 1, 0.45 },
}
local grid
local gridLines = {}
local gridLabels = {}

local function GridLabel(i)
	local label = gridLabels[i]
	if not label then
		label = grid:CreateFontString(nil, "OVERLAY")
		label:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
		label:SetTextColor(1, 0.82, 0)
		gridLabels[i] = label
	end
	return label
end

local function GridLine(i)
	local line = gridLines[i]
	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		line:SetTexture(P.FLAT)
		gridLines[i] = line
	end
	return line
end

function P.DrawGrid()
	if not grid then
		grid = CreateFrame("Frame", "PhantomUI_Grid", UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid:SetAllPoints(UIParent)
	end
	for i = 1, table.getn(gridLines) do
		gridLines[i]:Hide()
	end
	for i = 1, table.getn(gridLabels) do
		gridLabels[i]:Hide()
	end
	local db = P.DB()
	if not P.unlocked or not db.grid then
		grid:Hide()
		return
	end
	grid:Show()
	local size = db.gridSize
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local n = 0
	local function Put(k, vertical)
		n = n + 1
		local line = GridLine(n)
		line:ClearAllPoints()
		local r, g, b, a
		if k == 0 then
			r, g, b, a = 0, 0, 0, 1
		else
			local c = GRID_COLORS[math.mod(math.abs(k) - 1, table.getn(GRID_COLORS)) + 1]
			r, g, b, a = c[1], c[2], c[3], c[4]
		end
		line:SetVertexColor(r, g, b, a)
		if vertical then
			line:SetWidth(k == 0 and 3 or 1)
			line:SetPoint("TOP", grid, "TOP", k * size, 0)
			line:SetPoint("BOTTOM", grid, "BOTTOM", k * size, 0)
		else
			line:SetHeight(k == 0 and 3 or 1)
			line:SetPoint("LEFT", grid, "LEFT", 0, k * size)
			line:SetPoint("RIGHT", grid, "RIGHT", 0, k * size)
		end
		line:Show()
	end
	local nx = math.floor(w / 2 / size)
	local ny = math.floor(h / 2 / size)
	for k = -nx, nx do
		Put(k, true)
	end
	for k = -ny, ny do
		Put(k, false)
	end

	-- Nummern am Nullkreuz: unter der X-Achse und rechts neben der Y-Achse.
	local m = 0
	local function Label(text, x, y, point)
		m = m + 1
		local label = GridLabel(m)
		label:ClearAllPoints()
		label:SetPoint(point, grid, "CENTER", x, y)
		label:SetText(text)
		label:Show()
	end
	Label("0", 4, -3, "TOPLEFT")
	for k = -nx, nx do
		if k ~= 0 then
			Label(tostring(k), k * size, -3, "TOP")
		end
	end
	for k = -ny, ny do
		if k ~= 0 then
			Label(tostring(k), 4, k * size, "LEFT")
		end
	end
end

-- Kleine Leiste oben in der Mitte, solange die Ankerpunkte aktiv sind (wie bei ElvUI).
local lockBar
local function LockBar()
	if lockBar then
		return lockBar
	end
	lockBar = CreateFrame("Frame", "PhantomUI_LockBar", UIParent)
	lockBar:SetFrameStrata("FULLSCREEN_DIALOG")
	lockBar:SetWidth(280)
	lockBar:SetHeight(80)
	lockBar:SetPoint("TOP", UIParent, "TOP", 0, -120)
	P.Box(lockBar, 0.95)
	lockBar:EnableMouse(true)
	lockBar:SetMovable(true)
	lockBar:RegisterForDrag("LeftButton")
	lockBar:SetScript("OnDragStart", function() this:StartMoving() end)
	lockBar:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	local title = lockBar:CreateFontString(nil, "OVERLAY")
	title:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 12, "OUTLINE")
	title:SetTextColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3])
	title:SetPoint("TOP", lockBar, "TOP", 0, -7)
	title:SetText(P.T("Ankerpunkte"))
	-- Gitter: an/aus und Abstand
	local function Small(text, width, x, onClick)
		local b = CreateFrame("Button", nil, lockBar)
		b:SetWidth(width)
		b:SetHeight(18)
		b:SetPoint("TOPLEFT", lockBar, "TOPLEFT", x, -26)
		b:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
		b:SetBackdropColor(0.1, 0.1, 0.13, 1)
		b:SetBackdropBorderColor(0, 0, 0, 1)
		b.label = b:CreateFontString(nil, "OVERLAY")
		b.label:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
		b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.label:SetText(text)
		b:SetScript("OnEnter", function() this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1) end)
		b:SetScript("OnLeave", function() this:SetBackdropBorderColor(0, 0, 0, 1) end)
		b:SetScript("OnClick", onClick)
		return b
	end
	local toggle
	local value = lockBar:CreateFontString(nil, "OVERLAY")
	value:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
	value:SetPoint("TOPLEFT", lockBar, "TOPLEFT", 160, -29)
	value:SetWidth(50)
	local function Refresh()
		toggle.label:SetText(P.T(P.DB().grid and "Gitter: an" or "Gitter: aus"))
		value:SetText(P.DB().gridSize .. " px")
		P.DrawGrid()
	end
	toggle = Small("", 100, 12, function()
		P.DB().grid = not P.DB().grid
		Refresh()
	end)
	local steps = { 8, 16, 24, 32, 48, 64, 96, 128 }
	local function Step(dir)
		local cur = P.DB().gridSize
		local idx = 4
		for i = 1, table.getn(steps) do
			if steps[i] == cur then
				idx = i
			end
		end
		idx = P.Clamp(idx + dir, 1, table.getn(steps))
		P.DB().gridSize = steps[idx]
		Refresh()
	end
	Small("-", 20, 136, function() Step(-1) end)
	Small("+", 20, 212, function() Step(1) end)
	lockBar.Refresh = Refresh
	Refresh()

	local button = CreateFrame("Button", nil, lockBar)
	button:SetWidth(120)
	button:SetHeight(20)
	button:SetPoint("BOTTOM", lockBar, "BOTTOM", 0, 7)
	button:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
	button:SetBackdropColor(0.12, 0.06, 0.18, 1)
	button:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	local label = button:CreateFontString(nil, "OVERLAY")
	label:SetFont(P.ScriptFont("Fonts\\FRIZQT__.TTF"), 11, "OUTLINE")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(P.T("Sperren"))
	button:SetScript("OnEnter", function() this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1) end)
	button:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1) end)
	button:SetScript("OnClick", function()
		P.Unlock(false)
		if P.ShowOptions then
			P.ShowOptions()
		end
	end)
	return lockBar
end

function P.Unlock(state)
	if state == nil then
		state = not P.unlocked
	end
	P.unlocked = state
	if state then
		LockBar():Show()
		lockBar.Refresh()
	elseif lockBar then
		lockBar:Hide()
	end
	P.DrawGrid()
	for _, m in pairs(movers) do
		if state then
			m.overlay:Show()
		else
			m.overlay:Hide()
			m.frame:SetMovable(false)
		end
	end
	P.Apply()
	if state then
		P.Print("Rahmen entsperrt: ziehen verschiebt, Kanten ändern Breite/Höhe, die Ecke skaliert alles, Rechtsklick setzt zurück. Fertig mit /pui lock")
	else
		P.Print("Rahmen gesperrt.")
	end
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

local inits = {}
function P.OnInit(fn)
	table.insert(inits, fn)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
local wait
boot:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		local fresh = PhantomUIDB == nil
		PhantomUIDB = PhantomUIDB or {}
		Merge(PhantomUIDB, DEFAULTS)
		local db = PhantomUIDB
		if fresh then
			-- Neue Installation: Standardwerte gelten, keine Umbauten alter Versionen.
			db.version = DB_VERSION
		end
		if (db.version or 1) < 2 and db.unit then
			-- neue Masse fuer Spieler/Ziel: flacher Name, hoeheres Leben
			db.unit.width, db.unit.height, db.unit.nameHeight, db.unit.fontSize = 200, 30, 16, 11
		end
		if (db.version or 1) < 3 and db.unit then
			-- Name flacher, Leben breiter; 3D-Portraet bleibt im Client schwarz -> 2D
			db.unit.width, db.unit.nameHeight, db.unit.portrait3d = 240, 12, false
		end
		if (db.version or 1) < 4 and db.bar then
			-- Aktionsleiste ohne Hintergrund, Tasten buendig (Raender ueberlappen)
			db.bar.background, db.bar.spacing, db.bar.padding = false, -1, 0
		end
		if (db.version or 1) < 5 and db.bar then
			-- Tastengroesse und Skalierung zusammengelegt
			db.bar.size = math.floor((db.bar.size or 36) * (db.bar.scale or 1) + 0.5)
			db.bar.scale = 1
		end
		if db.bar then
			db.bar.text = nil
		end
		if (db.version or 1) < 6 then
			-- Buffs bekommen ihren neuen Standardplatz ueber der Ressource
			db.pos.auras = nil
			if db.auras then
				db.auras.scale = nil
			end
		end
		if (db.version or 1) < 8 then
			-- Ressource und Gold: innen durchsichtig, nur der schwarze Rahmen bleibt
			if db.power then
				db.power.bgAlpha = 0
			end
			if db.tally then
				db.tally.bgAlpha = 0
			end
			-- Boss-Leisten: neuer Standardplatz weiter unten
			db.pos.bosses = nil
		end
		if (db.version or 1) < 13 and db.plan then
			-- Kartenwahl: das Spiel zeichnet darueber, der Plan bleibt an seinem Platz
			db.plan.choice = false
		end
		if (db.version or 1) < 12 and db.power then
			-- Ressourcenleiste bei allen Klassen aus (in Allgemein wieder einschaltbar)
			db.power.enabled = false
		end
		if (db.version or 1) < 11 then
			-- Boss-Leisten: neuer Standardplatz ueber dem Zielfenster
			db.pos.bosses = nil
		end
		if (db.version or 1) < 9 and db.stats then
			-- Laufwerte: ganz durchsichtig
			db.stats.bgAlpha = 0
		end
		if (db.version or 1) < 15 and db.power then
			-- Wutleiste wieder an (zeigt sich nur beim Krieger)
			db.power.enabled = true
		end
		if (db.version or 1) < 14 and db.run and db.bosses then
			-- Boss-Leisten haben eigene Groesse (vorher mit der Laufuhr geteilt)
			db.bosses.height = db.run.bossHeight or db.bosses.height
		end
		if (db.version or 1) < 7 and db.run and db.run.height == 16 then
			-- Laufuhr: schmale Leiste, Zeit steht jetzt darueber
			db.run.height = 8
		end
		db.version = DB_VERSION
		return
	end
	-- Kurz warten, bis SurvivorsDragonUi seine Rahmen gebaut hat; wir bauen darauf um.
	wait = 0.5
end)
boot:SetScript("OnUpdate", function()
	if not wait then
		return
	end
	wait = wait - arg1
	if wait > 0 then
		return
	end
	wait = nil
	if not PhantomUIDB then
		return
	end
	if not P.ready then
		P.ready = true
		for i = 1, table.getn(inits) do
			local ok, err = pcall(inits[i])
			if not ok then
				P.Print(P.L("Fehler beim Start: ", "Error while starting: ") .. tostring(err))
			end
		end
	end
	P.Apply()
end)

SLASH_PHANTOMUI1 = "/pui"
SLASH_PHANTOMUI2 = "/phantom"
SlashCmdList["PHANTOMUI"] = function(msg)
	msg = string.lower(msg or "")
	local _, _, perfArg = string.find(msg, "^perf%s*(%d*)")
	if string.find(msg, "^perf") then
		P.Perf(perfArg)
		return
	end
	-- /pui lang de | en | auto: Sprache der PhantomUI-Texte
	local _, _, langArg = string.find(msg, "^lang%s*(%a*)")
	if langArg then
		local map = { de = "deDE", deutsch = "deDE", german = "deDE", en = "enUS", english = "enUS", auto = "auto",
			fr = "frFR", es = "esES", pt = "ptBR", br = "ptBR", pl = "plPL", cs = "csCZ", cz = "csCZ", ro = "roRO",
			tr = "trTR", ru = "ruRU", uk = "ukUA", ua = "ukUA", zh = "zhCN", cn = "zhCN", ja = "jaJP", jp = "jaJP", ko = "koKR", kr = "koKR" }
		if map[langArg] then
			P.DB().uiLang = map[langArg]
			ReloadUI()
		else
			P.Print(P.L("Sprache: /pui lang auto | en | de | fr | es | pt | pl | cs | ro | tr | ru | uk | zh | ja | ko", "Language: /pui lang auto | en | de | fr | es | pt | pl | cs | ro | tr | ru | uk | zh | ja | ko"))
		end
		return
	end
	if msg == "combo" then
		if P.ComboDebug then
			P.ComboDebug()
		end
		return
	end
	if msg == "unlock" or msg == "move" then
		P.Unlock(true)
	elseif msg == "lock" then
		P.Unlock(false)
	elseif msg == "reset" then
		P.DB().pos = {}
		P.Apply()
		P.Print("Positionen zurückgesetzt.")
	elseif P.ToggleOptions then
		P.ToggleOptions()
	end
end

------------------------------------------------------------------------
-- PhantomUI: Messung, was im Spiel Zeit kostet. /pui perf [Sekunden]
-- Misst fuer jeden Rahmen mit Skript (Addons und Spiel) die Zeit in OnEvent und
-- OnUpdate, dazu Speicher-Abfall, Speicherbereinigungen und Bild-Haenger.
-- Am Ende steht eine kurze Auswertung im Chat; danach laeuft alles wie vorher.


local running = false
local stats, wrapped = {}, {}
local gcCount, gcFreed, lastMem, startMem = 0, 0, 0, 0
local spikes, worst, frames, elapsedTotal = 0, 0, 0, 0
local duration = 30
local probe

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9d4de8PhantomUI|r " .. text)
end

local function Label(f)
	local name = f:GetName()
	if name then
		return name
	end
	local parent = f:GetParent()
	local pname = parent and parent:GetName()
	if pname then
		return pname .. " (Kind)"
	end
	return "ohne Namen"
end

local function Wrap(f, script)
	local orig = f:GetScript(script)
	if not orig then
		return
	end
	local key = Label(f) .. " " .. script
	local s = stats[key]
	if not s then
		s = { ms = 0, calls = 0, max = 0 }
		stats[key] = s
	end
	f:SetScript(script, function()
		local t = debugprofilestop()
		orig()
		local d = debugprofilestop() - t
		s.ms = s.ms + d
		s.calls = s.calls + 1
		if d > s.max then
			s.max = d
		end
	end)
	table.insert(wrapped, { f = f, script = script, orig = orig })
end

local function Report()
	running = false
	for i = 1, table.getn(wrapped) do
		local w = wrapped[i]
		w.f:SetScript(w.script, w.orig)
	end
	probe:SetScript("OnUpdate", nil)
	local list = {}
	for key, s in pairs(stats) do
		table.insert(list, { key = key, ms = s.ms, calls = s.calls, max = s.max })
	end
	table.sort(list, function(a, b) return a.ms > b.ms end)
	local secs = math.max(1, elapsedTotal)
	Say(string.format(P.L("Messung %ds: %.0f Bilder/s, %d Haenger > 50 ms (laengster %.0f ms)", "Run %ds: %.0f fps, %d hitches > 50 ms (longest %.0f ms)"),
		secs, frames / secs, spikes, worst * 1000))
	Say(string.format(P.L("Speicher: %d KB Abfall/s, %d Bereinigungen (alle %.1f s), jetzt %d KB", "Memory: %d KB garbage/s, %d collections (every %.1f s), now %d KB"),
		math.floor((gcFreed + gcinfo() - startMem) / secs), gcCount,
		gcCount > 0 and secs / gcCount or 0, gcinfo()))
	if not list[1] or list[1].ms <= 0 then
		Say(P.L("(Zeit je Teil misst dieser Client nicht.)", "(This client does not time individual parts.)"))
		stats, wrapped = {}, {}
		return
	end
	Say(P.L("Teuerste Teile (ms pro Sekunde | laengster Aufruf):", "Most expensive parts (ms per second | longest call):"))
	for i = 1, math.min(10, table.getn(list)) do
		local e = list[i]
		Say(string.format("  %2d. %s: %.2f ms/s | %.1f ms", i, e.key, e.ms / secs, e.max))
	end
	stats, wrapped = {}, {}
end

function P.Perf(seconds)
	if running then
		Say(P.L("Messung laeuft schon.", "A measurement is already running."))
		return
	end
	if not debugprofilestop or not EnumerateFrames then
		Say(P.L("Dieser Client bietet keine Zeitmessung.", "This client offers no timing."))
		return
	end
	duration = tonumber(seconds) or 30
	running = true
	stats, wrapped = {}, {}
	gcCount, gcFreed, spikes, worst, frames, elapsedTotal = 0, 0, 0, 0, 0, 0
	if debugprofilestart then
		debugprofilestart()
	end
	local f = EnumerateFrames()
	while f do
		Wrap(f, "OnEvent")
		Wrap(f, "OnUpdate")
		f = EnumerateFrames(f)
	end
	startMem = gcinfo()
	lastMem = startMem
	if not probe then
		probe = CreateFrame("Frame")
	end
	probe:SetScript("OnUpdate", function()
		local dt = arg1 or 0
		frames = frames + 1
		elapsedTotal = elapsedTotal + dt
		if dt > 0.05 then
			spikes = spikes + 1
		end
		if dt > worst then
			worst = dt
		end
		local mem = gcinfo()
		if mem < lastMem then
			-- Speicher ist geschrumpft: eine Bereinigung lief
			gcCount = gcCount + 1
			gcFreed = gcFreed + (lastMem - mem)
		end
		lastMem = mem
		if elapsedTotal >= duration then
			Report()
		end
	end)
	Say(P.L("Messung laeuft " .. duration .. " Sekunden – spiel ganz normal weiter (am besten mit vielen Gegnern).", "Measuring for " .. duration .. " seconds – just keep playing (ideally with lots of enemies)."))
end

------------------------------------------------------------------------
-- Speicherbereinigung steuern (gegen Ruckler)
-- Der Client raeumt den Lua-Speicher sonst mehrmals pro Sekunde auf und haelt
-- dabei jedes Mal das ganze Spiel an (gemessen: alle 0,2 s bei 20 MB). Wir
-- schieben die Grenze im Kampf weit nach oben und raeumen lieber dann auf, wenn
-- ohnehin Ruhe ist: Kartenwahl, Pause, Tod, ausserhalb des Kampfes. Wird der
-- Puffer trotzdem voll, wird sofort aufgeraeumt.
------------------------------------------------------------------------

local gcFrame = CreateFrame("Frame", "PhantomUI_GCManager")
local gcBase = 0          -- Speicher direkt nach der letzten Bereinigung (KB)
local gcTick = 0
local calmSince = 0
local CALM_PHASES = { choosing = true, paused = true, ready = true, dead = true, victory = true }

local function CollectNow()
	collectgarbage(0) -- Grenze 0: sofort aufraeumen
	gcBase = gcinfo()
end

gcFrame:SetScript("OnUpdate", function()
	gcTick = gcTick + arg1
	if gcTick < 0.1 then
		return
	end
	local dt = gcTick
	gcTick = 0
	local db = PhantomUIDB and PhantomUIDB.gc
	if not db or not db.enabled or not collectgarbage or not gcinfo then
		return
	end
	local used, threshold = gcinfo()
	if gcBase == 0 or used < gcBase then
		gcBase = used
	end
	local budget = (db.budget or 48) * 1024
	local grown = used - gcBase

	-- Ruhige Momente erkennen
	local phase = AZS_GetPhase and AZS_GetPhase()
	-- "Im Kampf" = in den letzten 3 Sekunden eigene Treffer im Kampflog (die
	-- Kampf-Markierung des Spiels ist in AZS kaum gesetzt)
	local lastHit = CompactSCT and CompactSCT.lastHit or 0
	local inCombat = (GetTime() - lastHit) < 3 or (UnitAffectingCombat and UnitAffectingCombat("player"))
	if CALM_PHASES[phase or ""] or not inCombat then
		calmSince = calmSince + dt
	else
		calmSince = 0
	end
	if (CALM_PHASES[phase or ""] and grown > 2048) or (calmSince > 2 and grown > 8192) then
		CollectNow()
		return
	end
	if grown > budget then
		-- Puffer voll: lieber einmal jetzt als staendig
		CollectNow()
		return
	end
	-- Grenze immer ein gutes Stueck ueber dem aktuellen Stand halten
	if threshold and threshold < used + 4096 then
		collectgarbage(gcBase + budget + 4096)
	end
end)
