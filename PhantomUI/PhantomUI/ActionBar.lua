-- PhantomUI: Aktionsleiste. Die Knoepfe selbst (Zauber, Abklingzeit, Klicks,
-- Belegung) bleiben die des Spiels bzw. von SurvivorsDragonUi; wir nehmen sie in
-- eine eigene, schlichte Leiste und entfernen Rahmen und Classic-Hintergrund.

local P = PhantomUI
local COUNT = 7
local bar
local buttons = {}

local function Hide(region)
	if type(region) == "table" and region.Hide then
		region:Hide()
		if region.SetAlpha then
			region:SetAlpha(0)
		end
	end
end

-- Die Spiel-Funktion setzt den Standard-Rahmen bei jeder Aktualisierung neu.
local function StripNormal(button)
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetTexture(nil)
		normal:SetAlpha(0)
	end
end

local function Inset(region, button, inset)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
	region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function Style(button, index)
	local db = P.DB().bar
	local name = button:GetName()
	local size = db.size
	local inset = db.border and 1 or 0

	button:SetParent(bar)
	button:SetScale(1)
	button:SetAlpha(1)
	button:SetWidth(size)
	button:SetHeight(size)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", bar, "TOPLEFT", db.padding + (index - 1) * (size + db.spacing), -db.padding)
	button:SetFrameStrata("LOW")
	button:SetFrameLevel(bar:GetFrameLevel() + 2)

	-- Reste von SurvivorsDragonUi weg
	Hide(button.DFRL_BorderOverlay)
	Hide(getglobal(name .. "DFRL_BorderOverlay"))
	Hide(getglobal("DFRL_ActionButtonBg" .. index))
	StripNormal(button)

	-- Schwarze Kante als eigener Rahmen HINTER dem Knopf: als Textur auf dem Knopf
	-- laege sie in derselben Ebene wie das Symbol und verdeckte es.
	if not button.puiEdge then
		local edge = CreateFrame("Frame", nil, bar)
		edge.tex = edge:CreateTexture(nil, "BACKGROUND")
		edge.tex:SetTexture(P.FLAT)
		edge.tex:SetAllPoints(edge)
		button.puiEdge = edge
	end
	button.puiEdge:SetFrameLevel(bar:GetFrameLevel() + 1)
	button.puiEdge:ClearAllPoints()
	button.puiEdge:SetAllPoints(button)
	button.puiEdge.tex:SetVertexColor(0, 0, 0, 1)
	if db.border then
		button.puiEdge:Show()
	else
		button.puiEdge:Hide()
	end

	local icon = getglobal(name .. "Icon")
	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		Inset(icon, button, inset)
	end

	-- Abklingzeit-Uhr bleibt so, wie das Spiel sie anlegt (nicht umsetzen).

	-- Das Blinken fuer "aktive" Angriffe laeuft in AZS dauernd (Zauber wirken sich
	-- selbst) und dunkelte die Symbole ab: ausblenden.
	local flash = getglobal(name .. "Flash")
	if flash then
		flash:SetAlpha(0)
		flash:Hide()
		flash.Show = function() end
	end

	button:SetHighlightTexture(P.FLAT)
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetVertexColor(1, 1, 1, 0.18)
		highlight:SetBlendMode("ADD")
		Inset(highlight, button, inset)
	end
	button:SetPushedTexture(P.FLAT)
	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetVertexColor(1, 1, 1, 0.25)
		Inset(pushed, button, inset)
	end
	if button.SetCheckedTexture then
		button:SetCheckedTexture(P.FLAT)
		local checked = button:GetCheckedTexture()
		if checked then
			-- In Azeroth Survivors wirken sich die Zauber selbst und gelten dauerhaft als
			-- "aktiv" (angehakt). Eine Faerbung dafuer lag deshalb immer ueber dem Symbol
			-- und liess es dunkel aussehen: unsichtbar machen.
			checked:SetVertexColor(1, 1, 1, 0)
			checked:SetAlpha(0)
			Inset(checked, button, inset)
		end
	end

	local count = getglobal(name .. "Count")
	if count then
		count:SetFont(P.Font(), 12, "OUTLINE")
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	end
	local label = getglobal(name .. "Name")
	if label then
		label:SetFont(P.Font(), 10, "OUTLINE")
		label:ClearAllPoints()
		label:SetPoint("TOP", button, "TOP", 0, -2)
		label:SetAlpha(0) -- kein Text auf den Tasten
	end
	local hotkey = getglobal(name .. "HotKey")
	if hotkey then
		hotkey:SetText("")
		hotkey:Hide()
	end
	button.pui = true
end

local function Layout()
	local db = P.DB().bar
	bar:SetScale(1)
	bar:SetWidth(COUNT * db.size + (COUNT - 1) * db.spacing + 2 * db.padding)
	bar:SetHeight(db.size + 2 * db.padding)
	if db.background then
		bar:SetBackdrop({
			bgFile = P.FLAT,
			edgeFile = P.FLAT,
			edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		bar:SetBackdropColor(0.06, 0.06, 0.07, db.bgAlpha)
		bar:SetBackdropBorderColor(0, 0, 0, math.min(1, db.bgAlpha + 0.3))
	else
		bar:SetBackdrop(nil)
	end
	for i = 1, table.getn(buttons) do
		Style(buttons[i], i)
	end
end

-- Ohne SurvivorsDragonUi: die Leisten des Spiels selbst aufraeumen.
-- AZS fuellt die Plaetze 1-6, die immer verfuegbare Faehigkeit liegt auf Platz 12;
-- der 7. Knopf zeigt deshalb Platz 12 (Tastenbelegung ACTIONBUTTON7 bleibt).
local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 12 }

local function Kill(frame)
	if not frame then
		return
	end
	frame:Hide()
	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
	frame.Show = function() end
end

local function Standalone()
	for i = 1, COUNT do
		local b = getglobal("ActionButton" .. i)
		if b then
			b.puiSlot = ACTION_SLOTS[i]
		end
	end
	local getPaged = ActionButton_GetPagedID
	ActionButton_GetPagedID = function(button)
		if button and button.puiSlot then
			return button.puiSlot
		end
		return getPaged(button)
	end
	for i = COUNT + 1, 12 do
		Kill(getglobal("ActionButton" .. i))
	end
	for _, prefix in ipairs({ "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
		"MultiBarRightButton", "BonusActionButton", "PetActionButton", "ShapeshiftButton" }) do
		for i = 1, 12 do
			Kill(getglobal(prefix .. i))
		end
	end
	for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
		"PetActionBarFrame", "ShapeshiftBarFrame", "BonusActionBarFrame", "MainMenuExpBar",
		"ReputationWatchBar", "MainMenuBarPerformanceBarFrame", "MainMenuBarBackpackButton",
		"CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton",
		"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber" }) do
		Kill(getglobal(name))
	end
	-- Mikromenue des Spiels: ersetzt durch Knoepfe an der Minimap.
	for _, name in ipairs({ "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
		"QuestLogMicroButton", "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton" }) do
		Kill(getglobal(name))
	end
	-- Die Hauptleiste selbst nur unsichtbar machen (ihre Ereignisse brauchen die Knoepfe).
	if MainMenuBar then
		MainMenuBar:SetAlpha(0)
		MainMenuBar:EnableMouse(false)
		if MainMenuBarArtFrame then
			MainMenuBarArtFrame:EnableMouse(false)
		end
	end
	-- Immer Seite 1, keine fremden Leisten
	local changePage = ChangeActionBarPage
	local function MainPage()
		CURRENT_ACTIONBAR_PAGE = 1
		if changePage then
			changePage()
		end
	end
	ChangeActionBarPage = MainPage
	ActionBar_PageUp = MainPage
	ActionBar_PageDown = MainPage
	MultiActionBar_Update = function() end
	ShowBonusActionBar = function() end
	HideBonusActionBar = function() end
	SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2, SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4 = nil, nil, nil, nil
	MainPage()
	local down, up = ActionButtonDown, ActionButtonUp
	ActionButtonDown = function(id)
		if id >= 1 and id <= COUNT then down(id) end
	end
	ActionButtonUp = function(id, onSelf)
		if id >= 1 and id <= COUNT then up(id, onSelf) end
	end
	for _, name in ipairs({ "MultiActionButtonDown", "MultiActionButtonUp", "BonusActionButtonDown",
		"BonusActionButtonUp", "PetActionButtonDown", "PetActionButtonUp", "ShapeshiftBar_ChangeForm" }) do
		setglobal(name, function() end)
	end
	ActionButton_UpdateHotkeys = function()
		for i = 1, table.getn(buttons) do
			local hk = getglobal(buttons[i]:GetName() .. "HotKey")
			if hk then
				hk:SetText("")
				hk:Hide()
			end
		end
	end
end

local function Init()
	if not P.DB().bar.enabled then
		return
	end
	bar = CreateFrame("Frame", "PhantomUI_ActionBar", UIParent)
	bar:SetFrameStrata("LOW")
	bar:SetFrameLevel(2)
	bar:SetClampedToScreen(true)

	-- Den alten Hintergrund von SurvivorsDragonUi ausblenden.
	Hide(getglobal("DFRL_ActionBar"))
	Hide(getglobal("DFRL_ActionBarLeftTexture"))
	Hide(getglobal("DFRL_ActionBarRightTexture"))

	for i = 1, COUNT do
		local button = getglobal("ActionButton" .. i)
		if button then
			table.insert(buttons, button)
		end
	end

	if not DFRL then
		Standalone()
		local previous = this
		for i = 1, table.getn(buttons) do
			this = buttons[i]
			if ActionButton_Update then
				ActionButton_Update()
			end
		end
		this = previous
	end

	-- Symbole immer in voller Helligkeit: das Spiel graut sie ab, wenn es eine
	-- Faehigkeit fuer "nicht nutzbar" haelt; in AZS wirkt aber der Server die Zauber.
	-- Abgedunkelt wird nur noch durch die Abklingzeit-Uhr.
	local function Bright(button)
		local icon = getglobal(button:GetName() .. "Icon")
		if icon then
			icon:SetVertexColor(1, 1, 1)
		end
		local normal = button:GetNormalTexture()
		if normal then
			normal:SetVertexColor(1, 1, 1)
		end
	end
	local usable = ActionButton_UpdateUsable
	if usable then
		ActionButton_UpdateUsable = function()
			usable()
			if this and this.pui then
				Bright(this)
			end
		end
	end
	for i = 1, table.getn(buttons) do
		Bright(buttons[i])
	end

	-- Nach jeder Aktualisierung durch das Spiel den Standard-Rahmen wieder entfernen.
	local original = ActionButton_Update
	if original then
		ActionButton_Update = function()
			original()
			if this and this.pui then
				StripNormal(this)
			end
		end
	end

	Layout()
	P.RegisterMover("actionbar", bar, "Aktionsleiste", function(frame)
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 55)
	end, {
		uniform = true, -- Ecke aendert die Tastengroesse (Groesse und Skalierung sind eins)
		-- Breite = Tastengroesse x Anzahl, Hoehe = Tastengroesse
		get = function()
			local db = P.DB().bar
			return db.size * COUNT, db.size
		end,
		set = function(w, h, which)
			local size = which == "w" and math.floor(w / COUNT + 0.5) or h
			P.DB().bar.size = P.Clamp(size, 16, 80)
		end,
	})
	P.OnApply(Layout)
end

P.OnInit(Init)
