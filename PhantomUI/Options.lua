-- PhantomUI: Einstellungsfenster (/pui). Von Hand gebaut, im Stil der anderen
-- Fenster (CompactSCT), aber mit Reitern und Phantom-Lila als Akzent.

local P = PhantomUI

local FLAT = P.FLAT
local FONT = "Fonts\\FRIZQT__.TTF"
local GOLD = { 1, 0.82, 0 }
local TEXT = { 0.9, 0.9, 0.9 }
local MUTED = { 0.55, 0.55, 0.6 }
local ACCENT = P.ACCENT

local WIDTH = 520
local INNER = WIDTH - 32
local ROW = 22
local HEIGHT = 500

local panel
local pages = {}
local tabs = {}
local widgets = {}

local function Get(path)
	if path.get then
		return path.get()
	end
	local db = P.DB()
	if path[2] then
		return db[path[1]][path[2]]
	end
	return db[path[1]]
end

local function Set(path, value)
	if path.set then
		path.set(value)
		return
	end
	local db = P.DB()
	if path[2] then
		db[path[1]][path[2]] = value
	else
		db[path[1]] = value
	end
	P.Apply()
	if P.DrawGrid then
		P.DrawGrid()
	end
end

local function Text(parent, size, color)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(P.ScriptFont(FONT), size, "OUTLINE")
	text:SetTextColor(color[1], color[2], color[3])
	-- Alle Texte im Fenster laufen durch die Uebersetzung (Deutsch/Englisch)
	local setText = text.SetText
	text.SetText = function(self, value)
		setText(self, P.T(value))
	end
	return text
end

local function Fill(parent, layer, r, g, b, a)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(FLAT)
	texture:SetVertexColor(r, g, b, a)
	return texture
end

local function Backdrop(frame, r, g, b, a)
	frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	frame:SetBackdropColor(r, g, b, a)
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function RefreshAll()
	for i = 1, table.getn(widgets) do
		widgets[i]:Refresh()
	end
end

local function Heading(page, y, label)
	local text = Text(page, 11, GOLD)
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
	text:SetText(label)
	local rule = Fill(page, "BORDER", ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", text, "RIGHT", 8, 0)
	rule:SetPoint("RIGHT", page, "RIGHT", -16, 0)
	return y - 20
end

local function Note(page, y, label)
	local text = Text(page, 9, MUTED)
	text:SetPoint("TOPLEFT", page, "TOPLEFT", 18, y)
	text:SetText(label)
	return y - 14
end

local function Check(page, x, y, label, path)
	local check = CreateFrame("Button", nil, page)
	check:SetWidth(INNER / 2 - 6)
	check:SetHeight(ROW)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	check.edge = Fill(check, "BORDER", 0.3, 0.3, 0.35, 1)
	check.edge:SetWidth(13)
	check.edge:SetHeight(13)
	check.edge:SetPoint("LEFT", check, "LEFT", 2, 0)
	check.box = Fill(check, "ARTWORK", 0, 0, 0, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.label = Text(check, 11, TEXT)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 8, 0)
	check.label:SetText(label)
	check:SetScript("OnClick", function()
		Set(path, not Get(path))
		RefreshAll()
	end)
	check:SetScript("OnEnter", function() this.hot = true this:Refresh() end)
	check:SetScript("OnLeave", function() this.hot = nil this:Refresh() end)
	function check:Refresh()
		local on = Get(path)
		if on then
			self.box:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			self.edge:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
		else
			self.box:SetVertexColor(0.1, 0.1, 0.13, 1)
			self.edge:SetVertexColor(0.3, 0.3, 0.35, 1)
		end
		if self.hot then
			self.label:SetTextColor(1, 1, 1)
		elseif on then
			self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		else
			self.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
	table.insert(widgets, check)
end

local function Slider(page, y, label, path, low, high, step, format)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(INNER)
	holder:SetHeight(ROW)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
	holder.label = Text(holder, 11, TEXT)
	holder.label:SetPoint("LEFT", holder, "LEFT", 2, 0)
	holder.label:SetText(label)
	holder.value = Text(holder, 11, ACCENT)
	holder.value:SetPoint("RIGHT", holder, "RIGHT", -2, 0)

	local slider = CreateFrame("Slider", nil, holder)
	slider:SetOrientation("HORIZONTAL")
	slider:SetWidth(INNER - 190)
	slider:SetHeight(14)
	slider:SetPoint("LEFT", holder, "LEFT", 135, 0)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	slider.track = Fill(slider, "BACKGROUND", 0.14, 0.14, 0.18, 1)
	slider.track:SetHeight(4)
	slider.track:SetPoint("LEFT", slider, "LEFT", 0, 0)
	slider.track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	slider.fill = Fill(slider, "BORDER", ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
	slider.fill:SetHeight(4)
	slider.fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	local thumb = Fill(slider, "OVERLAY", 1, 1, 1, 1)
	thumb:SetWidth(8)
	thumb:SetHeight(14)
	slider:SetThumbTexture(thumb)

	local function ShowValue(value)
		holder.value:SetText(string.format(format, value))
		local share = (value - low) / (high - low)
		slider.fill:SetWidth(math.max(1, (slider:GetWidth() - 8) * share + 4))
	end
	slider:SetScript("OnValueChanged", function()
		local value = math.floor(this:GetValue() / step + 0.5) * step
		ShowValue(value)
		if not this.quiet and value ~= Get(path) then
			Set(path, value)
		end
	end)
	slider:SetScript("OnMouseWheel", function()
		this:SetValue(this:GetValue() + arg1 * step)
	end)
	slider:SetScript("OnEnter", function() thumb:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
	slider:SetScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, 1) end)
	function holder:Refresh()
		slider.quiet = true
		local value = Get(path) or low
		slider:SetValue(value)
		ShowValue(value)
		slider.quiet = nil
	end
	table.insert(widgets, holder)
	return y - ROW - 4
end

local function Cycle(page, y, label, path, values, names)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetWidth(INNER)
	holder:SetHeight(ROW)
	holder:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
	holder.label = Text(holder, 11, TEXT)
	holder.label:SetPoint("LEFT", holder, "LEFT", 2, 0)
	holder.label:SetText(label)
	local button = CreateFrame("Button", nil, holder)
	button:SetWidth(INNER - 135)
	button:SetHeight(ROW - 2)
	button:SetPoint("LEFT", holder, "LEFT", 135, 0)
	Backdrop(button, 0.12, 0.12, 0.15, 1)
	button.text = Text(button, 11, ACCENT)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.hint = Text(button, 9, MUTED)
	button.hint:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	button.hint:SetText(">")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function()
		local current = Get(path)
		local index = 1
		for i = 1, table.getn(values) do
			if values[i] == current then
				index = i
			end
		end
		if arg1 == "RightButton" then
			index = index - 1
			if index < 1 then
				index = table.getn(values)
			end
		else
			index = index + 1
			if index > table.getn(values) then
				index = 1
			end
		end
		Set(path, values[index])
		RefreshAll()
	end)
	button:SetScript("OnEnter", function() this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
	button:SetScript("OnLeave", function() this:SetBackdropBorderColor(0, 0, 0, 1) end)
	function holder:Refresh()
		local current = Get(path)
		local shown = tostring(current)
		for i = 1, table.getn(values) do
			if values[i] == current then
				shown = names[i]
			end
		end
		button.text:SetText(shown)
	end
	table.insert(widgets, holder)
	return y - ROW - 4
end

local function Button(parent, x, y, width, label, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(24)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	Backdrop(button, 0.12, 0.06, 0.18, 1)
	button:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	button.text = Text(button, 11, ACCENT)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(label)
	button:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	end)
	button:SetScript("OnLeave", function()
		this.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

local function TextureLists()
	local values, names = {}, {}
	for i = 1, table.getn(P.TEXTURES) do
		table.insert(values, P.TEXTURES[i].key)
		table.insert(names, P.TEXTURES[i].name)
	end
	return values, names
end

local function FontLists()
	local values, names = {}, {}
	for i = 1, table.getn(P.FONTS) do
		table.insert(values, P.FONTS[i].key)
		table.insert(names, P.FONTS[i].name)
	end
	return values, names
end

------------------------------------------------------------------------
-- Seiten
------------------------------------------------------------------------

local COLOR_VALUES = { "class", "reaction", "phantom", "green" }
local COLOR_NAMES = { "Klassenfarbe", "Freund/Feind", "Phantom-Rot", "Grün" }

local function PageBar(page)
	local y = -10
	local half = 16 + INNER / 2 + 6
	y = Heading(page, y, "Aktionsleiste")
	Check(page, 16, y, "Hintergrund", { "bar", "background" })
	Check(page, half, y, "Dünner Rand um Tasten", { "bar", "border" })
	y = y - ROW - 6
	y = Slider(page, y, "Größe", { "bar", "size" }, 16, 80, 1, "%d px")
	y = Slider(page, y, "Abstand", { "bar", "spacing" }, -1, 12, 1, "%d px")
	y = Slider(page, y, "Innenrand", { "bar", "padding" }, 0, 12, 1, "%d px")
	y = Slider(page, y, "Hintergrund", { "bar", "bgAlpha" }, 0, 1, 0.05, "%.2f")
	y = y - 6
	Button(page, 16, y, INNER, "Aktionsleiste zurücksetzen", function()
		P.ResetSection("bar")
		RefreshAll()
	end)
	return y
end

local function PageUnits(page)
	local y = -10
	local half = 16 + INNER / 2 + 6
	y = Heading(page, y, "Spieler und Ziel")
	Check(page, 16, y, "Porträt", { "unit", "portrait" })
	Check(page, half, y, "Porträt in 3D (Test)", { "unit", "portrait3d" })
	y = y - ROW
	Check(page, 16, y, "Level", { "unit", "level" })
	Check(page, half, y, "Klasse / Gegnerart", { "unit", "class" })
	y = y - ROW
	Check(page, 16, y, "Prozent am Rand", { "unit", "percent" })
	Check(page, half, y, "Zahlen kürzen (922.3K)", { "unit", "short" })
	y = y - ROW - 6
	y = Cycle(page, y, "Farbe Spieler", { "unit", "colorPlayer" }, COLOR_VALUES, COLOR_NAMES)
	y = Cycle(page, y, "Farbe Ziel", { "unit", "colorTarget" }, COLOR_VALUES, COLOR_NAMES)
	y = Slider(page, y, "Breite", { "unit", "width" }, 100, 320, 2, "%d px")
	y = Slider(page, y, "Höhe Leben", { "unit", "height" }, 14, 44, 1, "%d px")
	y = Slider(page, y, "Höhe Name", { "unit", "nameHeight" }, 8, 30, 1, "%d px")
	y = Slider(page, y, "Schriftgröße", { "unit", "fontSize" }, 8, 18, 1, "%d")
	y = Slider(page, y, "Hintergrund", { "unit", "bgAlpha" }, 0, 1, 0.05, "%.2f")
	y = Slider(page, y, "Skalierung", { "unit", "scale" }, 0.5, 2, 0.05, "x%.2f")
	y = y - 6
	Button(page, 16, y, INNER, "Einheitenfenster zurücksetzen", function()
		P.ResetSection("unit")
		RefreshAll()
	end)
	return y
end

local function PagePower(page)
	local y = -10
	local half = 16 + INNER / 2 + 6
	y = Heading(page, y, "Wutleiste (nur Krieger)")
	Check(page, 16, y, "Zahl anzeigen", { "power", "text" })
	y = y - ROW - 6
	y = Slider(page, y, "Breite", { "power", "width" }, 60, 400, 2, "%d px")
	y = Slider(page, y, "Höhe", { "power", "height" }, 6, 30, 1, "%d px")
	y = Slider(page, y, "Rahmen", { "power", "border" }, 1, 4, 1, "%d px")
	y = Slider(page, y, "Hintergrund", { "power", "bgAlpha" }, 0, 1, 0.05, "%.2f")
	y = Slider(page, y, "Skalierung", { "power", "scale" }, 0.5, 2, 0.05, "x%.2f")
	y = Note(page, y + 2, "Nur der Krieger hat eine Leiste (Wut). Kombopunkte zeigt das Spiel selbst.")
	y = y - 4
	y = Heading(page, y, "Gold / Kiste")
	y = Slider(page, y, "Breite", { "tally", "width" }, 80, 400, 2, "%d px")
	y = Slider(page, y, "Höhe", { "tally", "height" }, 14, 40, 1, "%d px")
	y = Slider(page, y, "Hintergrund", { "tally", "bgAlpha" }, 0, 1, 0.05, "%.2f")
	y = Slider(page, y, "Skalierung", { "tally", "scale" }, 0.5, 2, 0.05, "x%.2f")
	y = y - 6
	local half = (INNER - 6) / 2
	Button(page, 16, y, half, "Ressource zurücksetzen", function()
		P.ResetSection("power")
		RefreshAll()
	end)
	Button(page, 16 + half + 6, y, half, "Gold/Kiste zurücksetzen", function()
		P.ResetSection("tally")
		RefreshAll()
	end)
	return y
end

local function PageGeneral(page)
	local y = -10
	y = Heading(page, y, "Sprache")
	y = Cycle(page, y, "Sprache", {
		get = function() return P.DB().uiLang or "auto" end,
		set = function(value)
			P.DB().uiLang = value
			ReloadUI()
		end,
	}, { "auto", "enUS", "deDE", "frFR", "esES", "ptBR", "plPL", "csCZ", "roRO", "trTR", "ruRU", "ukUA", "zhCN", "jaJP", "koKR" },
	{ "Automatisch (Spielsprache)", "English", "Deutsch", "Français", "Español", "Português (Brasil)", "Polski",
		"Cestina (Czech)", "Romana (Romanian)", "Turkce (Turkish)", "Russkiy (Russian)", "Ukrainska (Ukrainian)",
		"Chinese (Simplified)", "Japanese", "Korean" })
	y = Note(page, y + 2, "Gilt für die PhantomUI-Texte; die Oberfläche lädt dafür neu.")
	y = y - 6
	y = Heading(page, y, "Aussehen")
	local tv, tn = TextureLists()
	y = Cycle(page, y, "Leisten-Textur", { "texture" }, tv, tn)
	local fv, fn = FontLists()
	y = Cycle(page, y, "Schrift", { "font" }, fv, fn)
	y = Note(page, y + 2, "Linksklick: nächste, Rechtsklick: vorherige")
	y = y - 6
	y = Heading(page, y, "Position")
	Check(page, 16, y, "Rahmen verschieben", {
		get = function() return P.unlocked end,
		set = function(value) P.Unlock(value) end,
	})
	y = y - ROW
	y = Note(page, y, "An: ziehen verschiebt, Kanten = Breite/Höhe, Ecke unten rechts = skalieren.")
	Check(page, 16, y, "Gitter anzeigen", { "grid" })
	y = y - ROW
	y = Slider(page, y, "Gitterabstand", { "gridSize" }, 8, 128, 8, "%d px")
	y = y - 4
	Button(page, 16, y, INNER, "Alle Positionen zurücksetzen", function()
		P.DB().pos = {}
		P.Apply()
	end)
	y = y - 36
	y = Heading(page, y, "Ein- und Ausschalten")
	Check(page, 16, y, "Aktionsleiste", { "bar", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Spieler / Ziel", { "unit", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Wutleiste (Krieger)", { "power", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Gold / Kiste", { "tally", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Laufuhr und Bosse", { "run", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Erfahrungsleiste", { "xp", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Spielmenü (Escape)", { "menu", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Chat-Stil", { "chat", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Namensplaketten-Stil", { "plates", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Buffs", { "auras", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Laufwerte", { "stats", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Plan bei Kartenwahl unten", { "plan", "choice" })
	y = y - ROW
	Check(page, 16, y, "Ruckler-Schutz (Speicher)", { "gc", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Totems & Begleiter", { "totems", "enabled" })
	y = y - ROW
	Check(page, 16, y, "Gruppe (Koop)", { "party", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Mitspieler-Plakette", { "plates", "ally" })
	y = y - ROW
	Check(page, 16, y, "Gruppen-DPS", { "partymeter", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Feindliche Plaketten", { "plates", "enemy" })
	y = y - ROW
	Check(page, 16, y, "Debuffs statt Name", { "plates", "debuffs" })
	Check(page, 16 + INNER / 2 + 6, y, "Nur Bosse (Plaketten)", { "plates", "bossOnly" })
	y = y - ROW
	Check(page, 16, y, "Minimap: Wächter-Höhlen", { "pins", "lairs" })
	Check(page, 16 + INNER / 2 + 6, y, "Minimap: Truhen", { "pins", "chests" })
	y = y - ROW
	y = Slider(page, y, "Debuff-Größe (Plaketten)", { "plates", "debuffSize" }, 10, 40, 1, "%d px")
	Check(page, 16, y, "Eigene Einblendungen", { "alerts", "enabled" })
	Check(page, 16 + INNER / 2 + 6, y, "Fehlermeldungen dorthin", { "alerts", "errors" })
	y = y - ROW
	y = Note(page, y, "Ein/Aus wirkt nach /reload.")
	-- Talente fuer Totems & Begleiter: das Spiel verraet Addons nicht, was
	-- geskillt ist, daher hier von Hand (nur die eigene Klasse)
	local _, myClass = UnitClass("player")
	local talents = P.TOTEM_TALENTS and P.TOTEM_TALENTS[myClass]
	-- Seit AS 0.110 meldet das Spiel die Begleiter selbst: nur noch die
	-- Totem-Talente des Schamanen brauchen einen Haken.
	if talents and P.SummonAPI and P.SummonAPI() then
		local keep = {}
		for i = 1, table.getn(talents) do
			if talents[i].key == "twin_totems" or talents[i].key == "totemic_call" then
				table.insert(keep, talents[i])
			end
		end
		talents = table.getn(keep) > 0 and keep or nil
	end
	if talents then
		y = y - 6
		y = Heading(page, y, "Totems & Begleiter: Talente")
		for i = 1, table.getn(talents) do
			local key = talents[i].key
			Check(page, 16 + math.mod(i - 1, 2) * (INNER / 2 + 6), y, talents[i].name, {
				get = function()
					local t = P.DB().totems.talents
					return t and t[key] and true or false
				end,
				set = function(on)
					P.DB().totems.talents = P.DB().totems.talents or {}
					P.DB().totems.talents[key] = on or nil
				end,
			})
			if math.mod(i, 2) == 0 or i == table.getn(talents) then
				y = y - ROW
			end
		end
		y = Note(page, y, "Haken setzen, wenn du das Talent geskillt hast.")
		if myClass == "WARLOCK" and not (P.SummonAPI and P.SummonAPI()) then
			y = Note(page, y, "Höllenbestie, Verdammniswache, Grubenlord, Teufelswache: automatisch erkannt.")
		end
	end
	return y
end

------------------------------------------------------------------------

-- Schadenszahlen (frueher CompactSCT): Einstellungen direkt in dessen Datenbank.
local function SCT(key, after)
	return {
		get = function()
			return CompactSCT and CompactSCT.API and CompactSCT.API.DB()[key]
		end,
		set = function(value)
			if not (CompactSCT and CompactSCT.API) then
				return
			end
			CompactSCT.API.DB()[key] = value
			if after then
				after(value)
			end
		end,
	}
end

local function PageNumbers(page)
	local y = -10
	local half = 16 + INNER / 2 + 6
	if not (CompactSCT and CompactSCT.API) then
		return Note(page, y, "Schadenszahlen sind nicht geladen.")
	end
	local API = CompactSCT.API
	y = Heading(page, y, "Schadenszahlen")
	Check(page, 16, y, "Aktiv", SCT("enabled", function(on)
		if on then API.Enable() else API.Disable() end
	end))
	Check(page, half, y, "Fähigkeits-Symbole", SCT("icons"))
	y = y - ROW
	Check(page, 16, y, "Schaden über Zeit", SCT("dots"))
	Check(page, half, y, "Große Zahlen kürzen", SCT("short"))
	y = y - ROW
	Check(page, 16, y, "Treffer zusammenfassen", SCT("merge"))
	Check(page, half, y, "Trefferanzahl zeigen (x12)", SCT("mergeCount"))
	y = y - ROW - 6
	y = Slider(page, y, "Zusammenfassen über", SCT("mergeTime"), 0.25, 3, 0.25, "%.2f s")
	y = Cycle(page, y, "Anordnung", SCT("layout"), { "fan", "plates" }, { "Fächer über dir", "über den Gegnern" })
	y = Slider(page, y, "Fächer-Weite", SCT("fanReach"), 100, 500, 10, "%d px")
	y = Slider(page, y, "Fächer-Flugzeit", SCT("fanTime"), 1, 5, 0.1, "%.1f s")
	y = Slider(page, y, "Schriftgröße", SCT("size", function() API.FontChanged() end), 8, 30, 1, "%d")
	y = Cycle(page, y, "Schriftart", SCT("font", function() API.FontChanged() end),
		{ "friz", "arial", "skurri", "morpheus" }, { "Friz Quadrata", "Arial Narrow", "Skurri", "Morpheus" })
	y = Cycle(page, y, "Farben", SCT("color"), { "school", "white", "gold" }, { "nach Schadensschule", "weiß", "gold" })
	y = Slider(page, y, "Crit-Größe", SCT("critScale"), 1, 2, 0.05, "x%.2f")
	y = Slider(page, y, "Sichtbarkeit", SCT("opacity"), 0.1, 1, 0.05, "%.2f")
	y = Slider(page, y, "Abstand", SCT("spread"), 0.5, 4, 0.1, "x%.1f")
	y = Slider(page, y, "Steigen", SCT("rise"), 0, 120, 2, "%d px")
	y = Slider(page, y, "Anzeigedauer", SCT("duration"), 0.3, 3, 0.05, "%.2f s")
	y = Slider(page, y, "Max. gleichzeitig", SCT("maxTexts"), 5, 100, 1, "%d")
	y = Slider(page, y, "Mindestschaden", SCT("minPercent"), 0, 50, 1, "%d %%")
	y = Note(page, y + 2, "Mindestschaden in % vom aktuell größten Treffer.")
	y = y - 6
	local third = (INNER - 12) / 3
	Button(page, 16, y, third, "Vorschau", function() API.Test() end)
	Button(page, 16 + third + 6, y, third, "Standard", function()
		local db = API.DB()
		local keep = { native = db.native, version = db.version, hidden = db.hidden, iconCache = db.iconCache }
		for key, value in pairs(API.Defaults) do
			db[key] = value
		end
		for key, value in pairs(keep) do
			db[key] = value
		end
		API.FontChanged()
		API.TrackChanged()
		if db.enabled then API.Enable() end
		RefreshAll()
	end)
	return y - 30
end

local function MeterGet(fn, default)
	return function()
		if fn then
			return fn()
		end
		return default
	end
end

local function PageMeter(page)
	local y = -10
	if not AZSSpellMeter_GetMode then
		return Note(page, y, "Schadensmeter ist nicht geladen.")
	end
	y = Heading(page, y, "Schadensmeter")
	Check(page, 16, y, "Anzeigen", {
		get = function()
			local f = getglobal("AZSSpellMeterFrame")
			return f and f:IsShown() and true or false
		end,
		set = function(on)
			SlashCmdList.AZSSPELLMETER(on and "show" or "hide")
		end,
	})
	y = y - ROW - 6
	y = Cycle(page, y, "Anzeige", {
		get = AZSSpellMeter_GetMode,
		set = AZSSpellMeter_SetMode,
	}, { "damage", "boss", "heal" }, { "Schaden", "nur Bossschaden", "Heilung" })
	y = Note(page, y + 2, "Auch per Klick auf den Titel im Meter umschaltbar.")
	y = y - 4
	y = Slider(page, y, "Hintergrund", {
		get = AZSSpellMeter_GetBgAlpha,
		set = AZSSpellMeter_SetBgAlpha,
	}, 0, 1, 0.05, "%.2f")
	y = Slider(page, y, "Skalierung", {
		get = AZSSpellMeter_GetScale,
		set = AZSSpellMeter_SetScale,
	}, 0.5, 2, 0.05, "x%.2f")
	y = Slider(page, y, "Zeilenhöhe", {
		get = AZSSpellMeter_GetRowHeight,
		set = AZSSpellMeter_SetRowHeight,
	}, 12, 30, 1, "%d px")
	y = Note(page, y + 2, "Zeilenhöhe wirkt nach /reload.")
	y = y - 6
	local half = (INNER - 6) / 2
	Button(page, 16, y, half, "Meter zurücksetzen", function()
		SlashCmdList.AZSSPELLMETER("reset")
	end)
	Button(page, 16 + half + 6, y, half, "Platz zurücksetzen", function()
		SlashCmdList.AZSSPELLMETER("resetpos")
	end)
	y = y - 30
	y = Note(page, y, "Bossschaden zeigt den letzten Bosskampf, Heilung den ganzen Lauf –")
	y = Note(page, y, "beides direkt aus den Zahlen des Spiels.")
	return y
end

local function PageMinimap(page)
	local y = -10
	local half = 16 + INNER / 2 + 6
	y = Heading(page, y, "Minimap")
	Check(page, 16, y, "Minimap im PhantomUI-Stil", { "minimap", "enabled" })
	Check(page, half, y, "Fremde Addon-Knöpfe einsammeln", { "minimap", "collect" })
	y = y - ROW
	y = y - ROW
	y = Note(page, y, "Diese beiden wirken nach /reload.")
	y = y - 6
	y = Slider(page, y, "Größe", { "minimap", "size" }, 100, 400, 2, "%d px")
	y = Slider(page, y, "Skalierung", { "minimap", "scale" }, 0.5, 2, 0.05, "x%.2f")
	y = y - 4
	y = Heading(page, y, "Knöpfe für Addons")
	y = Cycle(page, y, "Position", { "minimap", "buttons" },
		{ "bottom", "top", "left", "right" }, { "unter der Karte", "über der Karte", "links", "rechts" })
	y = Slider(page, y, "Knopfgröße", { "minimap", "buttonSize" }, 14, 40, 1, "%d px")
	y = Note(page, y + 2, "Jedes Addon hat seinen eigenen Knopf. Maus drüber zeigt, was er tut.")
	y = y - 6
	y = Heading(page, y, "Buffs")
	Check(page, 16, y, "Buffs im PhantomUI-Stil", { "auras", "enabled" })
	y = y - ROW
	y = Slider(page, y, "Größe", { "auras", "size" }, 16, 64, 1, "%d px")
	y = y - 4
	y = Heading(page, y, "Chat")
	y = Slider(page, y, "Hintergrund", { "chat", "bgAlpha" }, 0, 1, 0.05, "%.2f")
	local cfv, cfn = {}, {}
	for i = 1, table.getn(P.FONTS) do
		table.insert(cfv, P.FONTS[i].key)
		table.insert(cfn, P.FONTS[i].name)
	end
	y = Cycle(page, y, "Schrift", { "chat", "font" }, cfv, cfn)
	y = Slider(page, y, "Schriftgröße", { "chat", "fontSize" }, 9, 20, 1, "%d")
	y = Slider(page, y, "Ausblenden nach", { "chat", "fade" }, 0, 60, 1, "%d s")
	y = Note(page, y + 2, "Ausblenden 0 = nie. Mausrad holt alte Zeilen zurück.")
	return y
end

local function ShowPage(index)
	for i = 1, table.getn(pages) do
		if i == index then
			pages[i]:Show()
			tabs[i]:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			tabs[i].text:SetTextColor(1, 1, 1)
		else
			pages[i]:Hide()
			tabs[i]:SetBackdropBorderColor(0, 0, 0, 1)
			tabs[i].text:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
		end
	end
	RefreshAll()
end

local function BuildPanel()
	panel = CreateFrame("Frame", "PhantomUIOptions", UIParent)
	panel:SetWidth(WIDTH)
	panel:SetHeight(HEIGHT)
	panel:SetFrameStrata("DIALOG")
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	Backdrop(panel, 0.05, 0.05, 0.07, 0.97)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function() this:StartMoving() end)
	panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	panel:SetScript("OnShow", function() RefreshAll() end)
	if UISpecialFrames then
		table.insert(UISpecialFrames, "PhantomUIOptions")
	end

	local title = Text(panel, 15, ACCENT)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
	title:SetText("PhantomUI")
	local sub = Text(panel, 9, MUTED)
	sub:SetPoint("LEFT", title, "RIGHT", 8, -1)
	local version = GetAddOnMetadata and GetAddOnMetadata("PhantomUI", "Version")
	sub:SetText(version and ("v" .. version) or "")

	local close = CreateFrame("Button", nil, panel)
	close:SetWidth(20)
	close:SetHeight(20)
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
	close.text = Text(close, 13, MUTED)
	close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.text:SetText("x")
	close:SetScript("OnEnter", function() this.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
	close:SetScript("OnLeave", function() this.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end)
	close:SetScript("OnClick", function() panel:Hide() end)

	-- Wie bei ElvUI: Knopf "Ankerpunkte" oben. Blendet das Fenster aus und zeigt
	-- alle Rahmen zum Verschieben; "Sperren" bringt das Fenster zurueck.
	local anchors = CreateFrame("Button", nil, panel)
	anchors:SetWidth(110)
	anchors:SetHeight(20)
	anchors:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -11)
	Backdrop(anchors, 0.12, 0.06, 0.18, 1)
	anchors:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	anchors.text = Text(anchors, 11, ACCENT)
	anchors.text:SetPoint("CENTER", anchors, "CENTER", 0, 0)
	anchors.text:SetText("Ankerpunkte")
	anchors:SetScript("OnEnter", function()
		this.text:SetTextColor(1, 1, 1)
		this:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	end)
	anchors:SetScript("OnLeave", function()
		this.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	end)
	anchors:SetScript("OnClick", function()
		panel:Hide()
		P.Unlock(true)
	end)

	local names = { "Leiste", "Einheiten", "Ressource", "Minimap", "Zahlen", "Meter", "Allgemein" }
	local builders = { PageBar, PageUnits, PagePower, PageMinimap, PageNumbers, PageMeter, PageGeneral }
	local count = table.getn(names)
	local tabW = (INNER - (count - 1) * 4) / count
	local lowest = 0
	for i = 1, count do
		local tab = CreateFrame("Button", nil, panel)
		tab:SetWidth(tabW)
		tab:SetHeight(22)
		tab:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (i - 1) * (tabW + 4), -40)
		Backdrop(tab, 0.1, 0.1, 0.13, 1)
		tab.text = Text(tab, 10, MUTED)
		tab.text:SetPoint("CENTER", tab, "CENTER", 0, 0)
		tab.text:SetText(names[i])
		tab.index = i
		tab:SetScript("OnClick", function() ShowPage(this.index) end)
		tabs[i] = tab

		local page = CreateFrame("Frame", nil, panel)
		page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -68)
		page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
		local bottom = builders[i](page) or -300
		lowest = math.min(lowest, bottom)
		pages[i] = page
	end
	-- Fenster nur so hoch wie die laengste Seite
	panel:SetHeight(68 - lowest + 34)
	ShowPage(1)
	panel:Hide()
end

function P.ShowOptions(page)
	if not panel then
		BuildPanel()
	end
	panel:Show()
	if page then
		ShowPage(page)
	end
end

-- Die Schadenszahlen haben kein eigenes Fenster mehr: /csct oeffnet diesen Reiter.
CompactSCT = CompactSCT or {}
CompactSCT.ToggleOptions = function()
	P.ShowOptions(5)
end

function P.ToggleOptions()
	if not panel then
		BuildPanel()
	end
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end
