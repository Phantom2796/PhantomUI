-- PhantomUI: Minimap im Phantom-Stil und eine Knopfleiste fuer Addons.
-- Jedes Addon bekommt einen eigenen Knopf (statt eines Zahnrads mit Menue).
-- Andere Addons koennen sich mit PhantomUI.AddMinimapButton(...) anmelden; fremde
-- Minimap-Knoepfe werden zusaetzlich eingesammelt und in die Leiste gestellt.

local P = PhantomUI

local root, box, topPanel, strip
local buttons = {}
local collected = {}

-- Knoepfe des Spiels, die nicht eingesammelt werden duerfen.
local SKIP = {
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MiniMapTrackingFrame = true,
	MiniMapTrackingButton = true,
	MiniMapMailFrame = true,
	MinimapZoneTextButton = true,
	MiniMapBattlefieldFrame = true,
	MiniMapMeetingStoneFrame = true,
	GameTimeFrame = true,
	MinimapToggleButton = true,
	MinimapTopPanel = true,
	MinimapTimeFrame = true,
	CompactSCTMinimapButton = true,
	MinimapBackdrop = true,
}

------------------------------------------------------------------------
-- Knopfleiste
------------------------------------------------------------------------

local function MakeButton(def)
	local b = CreateFrame("Button", nil, strip)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetTexture(P.FLAT)
	b.edge:SetVertexColor(0, 0, 0, 1)
	b.edge:SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(def.icon)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b:SetHighlightTexture(P.FLAT)
	local hl = b:GetHighlightTexture()
	hl:SetVertexColor(1, 1, 1, 0.2)
	hl:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.def = def
	b:SetScript("OnClick", function()
		if arg1 == "RightButton" and this.def.right then
			this.def.right()
		elseif this.def.left then
			this.def.left()
		end
	end)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.def.title)
		if this.def.leftText then
			GameTooltip:AddLine("Linksklick: " .. this.def.leftText, 1, 1, 1)
		end
		if this.def.rightText then
			GameTooltip:AddLine("Rechtsklick: " .. this.def.rightText, 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- def: { title, icon, left = fn, right = fn, leftText, rightText, available = fn }
function P.AddMinimapButton(def)
	table.insert(buttons, { def = def })
	if strip then
		P.Apply()
	end
end

local function Collect()
	if not P.DB().minimap.collect or not Minimap then
		return
	end
	local kids = { Minimap:GetChildren() }
	for i = 1, table.getn(kids) do
		local f = kids[i]
		local name = f.GetName and f:GetName()
		if name and not SKIP[name] and not collected[name]
			and f:GetObjectType() == "Button"
			and (string.find(name, "Minimap") or string.find(name, "MiniMap") or string.find(name, "LibDBIcon")) then
			collected[name] = f
			f:SetParent(strip)
			f.puiCollected = true
		end
	end
end

local function LayoutStrip()
	local db = P.DB().minimap
	local size = db.buttonSize
	local list = {}
	for i = 1, table.getn(buttons) do
		local entry = buttons[i]
		local ok = not entry.def.available or entry.def.available()
		if ok then
			if not entry.button then
				entry.button = MakeButton(entry.def)
			end
			table.insert(list, entry.button)
		elseif entry.button then
			entry.button:Hide()
		end
	end
	for _, f in pairs(collected) do
		table.insert(list, f)
	end

	local n = table.getn(list)
	local vertical = db.buttons == "left" or db.buttons == "right"
	local step = size - 1 -- buendig: Raender ueberlappen
	strip:ClearAllPoints()
	if vertical then
		strip:SetWidth(size)
		strip:SetHeight(math.max(1, n * step + 1))
	else
		strip:SetWidth(math.max(1, n * step + 1))
		strip:SetHeight(size)
	end
	if db.buttons == "top" then
		strip:SetPoint("BOTTOMLEFT", topPanel or Minimap, "TOPLEFT", topPanel and 0 or -1, -1)
	elseif db.buttons == "left" then
		strip:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", 0, 1)
	elseif db.buttons == "right" then
		strip:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 0, 1)
	else
		strip:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -1, 0)
	end
	for i = 1, n do
		local b = list[i]
		b:SetParent(strip)
		b:ClearAllPoints()
		b:SetWidth(size)
		b:SetHeight(size)
		if b.SetScale then
			b:SetScale(1)
		end
		if vertical then
			b:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, -(i - 1) * step)
		else
			b:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * step, 0)
		end
		b:Show()
	end
end

------------------------------------------------------------------------
-- Minimap selbst
------------------------------------------------------------------------

-- Goldrahmen, Schatten und Hintergruende von SurvivorsDragonUi entfernen.
local function StripArt(frame, pattern)
	if not frame then
		return
	end
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		if r:GetObjectType() == "Texture" then
			local tex = r:GetTexture()
			if not pattern or (tex and string.find(string.lower(tex), pattern, 1, true)) then
				r:Hide()
				r:SetAlpha(0)
			end
		end
	end
end

local function LayoutMap()
	local db = P.DB().minimap
	root:SetScale(db.scale)
	root:SetWidth(db.size)
	root:SetHeight(db.size)
	Minimap:SetWidth(db.size)
	Minimap:SetHeight(db.size)
	P.Box(box, 0.9)
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -1, 1)
	box:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 1, -1)

	if topPanel then
		topPanel:ClearAllPoints()
		topPanel:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -1, 0)
		topPanel:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 1, 0)
		topPanel:SetHeight(16)
		P.Box(topPanel, 0.9)
		if MinimapZoneText then
			MinimapZoneText:SetFont(P.Font(), 10, "OUTLINE")
		end
		if MinimapZoneTextButton then
			MinimapZoneTextButton:ClearAllPoints()
			MinimapZoneTextButton:SetPoint("LEFT", topPanel, "LEFT", 5, 0)
		end
		local time = getglobal("MinimapTimeFrame")
		if time then
			time:ClearAllPoints()
			time:SetPoint("RIGHT", topPanel, "RIGHT", -4, 0)
			time:SetHeight(16)
		end
		local timeText = getglobal("MinimapTimeText")
		if timeText then
			timeText:SetFont(P.Font(), 10, "OUTLINE")
		end
	end
	LayoutStrip()
end

local function Init()
	local db = P.DB().minimap
	if not Minimap then
		return
	end

	-- Eigene Knoepfe
	P.AddMinimapButton({
		title = "PhantomUI",
		icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
		left = function() P.ToggleOptions() end,
		right = function() P.Unlock() end,
		leftText = "Einstellungen",
		rightText = "Rahmen verschieben an/aus",
	})
	P.AddMinimapButton({
		title = "Fähigkeiten-Plan",
		icon = "Interface\\Icons\\INV_Misc_Book_09",
		left = function() P.TogglePlanEditor() end,
		right = function()
			P.DB().plan.enabled = not P.DB().plan.enabled
			P.Apply()
		end,
		leftText = "Plan bearbeiten",
		rightText = "Fenster ein/aus",
	})
	P.AddMinimapButton({
		title = "Schadenszahlen",
		icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
		available = function() return CompactSCT and CompactSCT.API end,
		left = function() P.ShowOptions(5) end,
		right = function() CompactSCT.API.Test() end,
		leftText = "Einstellungen",
		rightText = "Vorschau",
	})
	P.AddMinimapButton({
		title = "Schadensmeter",
		icon = "Interface\\Icons\\INV_Misc_Note_01",
		available = function() return SlashCmdList and SlashCmdList.AZSSPELLMETER end,
		left = function() SlashCmdList.AZSSPELLMETER("toggle") end,
		right = function() P.ShowOptions(6) end,
		leftText = "ein/aus",
		rightText = "Einstellungen (Schaden / Boss / Heilung)",
	})

	-- Das Zahnrad von CompactSCT wird durch die Leiste ersetzt.
	local gear = getglobal("CompactSCTMinimapButton")
	if gear then
		gear:Hide()
		gear.Show = function() end
	end

	strip = CreateFrame("Frame", "PhantomUI_MinimapButtons", Minimap)
	strip:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	Collect()

	if not db.enabled then
		-- Nur die Knopfleiste, Minimap bleibt wie sie ist.
		LayoutStrip()
		P.OnApply(LayoutStrip)
		return
	end

	root = getglobal("DFRL_Minimap")
	topPanel = getglobal("MinimapTopPanel")
	if not root then
		-- Ohne SurvivorsDragonUi: eckige Minimap selbst bauen.
		root = CreateFrame("Frame", "PhantomUI_Minimap", UIParent)
		root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -32)
		Minimap:SetParent(root)
		Minimap:ClearAllPoints()
		Minimap:SetAllPoints(root)
		Minimap:SetFrameStrata("MEDIUM")
		Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
		if MinimapCluster then
			MinimapCluster:EnableMouse(false)
		end
		for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapToggleButton", "GameTimeFrame",
			"MiniMapWorldMapButton", "MinimapNorthTag" }) do
			local f = getglobal(name)
			if f then
				f:Hide()
				f.Show = function() end
			end
		end
		Minimap:EnableMouseWheel(true)
		Minimap:SetScript("OnMouseWheel", function()
			local zoom = Minimap:GetZoom()
			if arg1 > 0 and zoom < Minimap:GetZoomLevels() - 1 then
				Minimap:SetZoom(zoom + 1)
			elseif arg1 < 0 and zoom > 0 then
				Minimap:SetZoom(zoom - 1)
			end
		end)
		-- Leiste oben: Gebietsname und Uhrzeit
		topPanel = CreateFrame("Frame", "PhantomUI_MinimapTop", Minimap)
		if MinimapZoneTextButton then
			MinimapZoneTextButton:SetParent(topPanel)
		end
		if MinimapZoneText then
			MinimapZoneText:SetJustifyH("LEFT")
		end
		local timeFrame = CreateFrame("Frame", "MinimapTimeFrame", topPanel)
		timeFrame:SetWidth(40)
		local timeText = timeFrame:CreateFontString("MinimapTimeText", "OVERLAY")
		timeText:SetPoint("RIGHT", timeFrame, "RIGHT", 0, 0)
		timeText:SetFont(P.Font(), 10, "OUTLINE")
		local nextAt = 0
		timeFrame:SetScript("OnUpdate", function()
			local now = GetTime()
			if now >= nextAt then
				nextAt = now + 5
				timeText:SetText(date("%H:%M"))
			end
		end)
		for _, name in ipairs({ "MiniMapMailFrame", "MiniMapTrackingFrame" }) do
			local f = getglobal(name)
			if f then
				f:SetParent(Minimap)
				f:ClearAllPoints()
				f:SetScale(0.7)
			end
		end
		if MiniMapMailFrame then
			MiniMapMailFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)
		end
		if MiniMapTrackingFrame then
			MiniMapTrackingFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
		end
		for _, name in ipairs({ "MiniMapMailBorder", "MiniMapTrackingBorder" }) do
			local f = getglobal(name)
			if f then
				f:Hide()
			end
		end
	end
	StripArt(Minimap, "dragonflight")
	if topPanel then
		StripArt(topPanel)
	end
	for _, name in ipairs({ "MinimapZoomIn", "MinimapZoomOut" }) do
		local f = getglobal(name)
		if f then
			f:Hide()
			f.Show = function() end
		end
	end

	-- Rahmen hinter der Karte: am Elternrahmen, eine Ebene unter der Minimap.
	box = CreateFrame("Frame", nil, Minimap:GetParent() or UIParent)
	box:SetFrameStrata(Minimap:GetFrameStrata())
	box:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))

	LayoutMap()

	-- Karte dreht sich mit der Blickrichtung (Einstellung des Spiels)
	local function ApplyRotate()
		local on = P.DB().minimap.rotate
		if SetCVar then
			pcall(SetCVar, "rotateMinimap", on and "1" or "0")
		end
		if MinimapCompassTexture then
			MinimapCompassTexture:Hide()
			MinimapCompassTexture.Show = function() end
		end
	end
	ApplyRotate()
	P.OnApply(ApplyRotate)

	if root ~= Minimap then
		P.RegisterMover("minimap", root, "Minimap", function(f)
			f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -32)
		end, {
			scale = "minimap",
			get = function()
				local d = P.DB().minimap
				return d.size, d.size
			end,
			set = function(w, h, which)
				P.DB().minimap.size = P.Clamp(which == "w" and w or h, 100, 400)
			end,
		})
	end

	-- Spaet geladene Addons: noch eine Weile nach neuen Knoepfen schauen.
	local t, rounds = 0, 0
	strip:SetScript("OnUpdate", function()
		t = t + arg1
		if t < 3 or rounds >= 10 then
			return
		end
		t = 0
		rounds = rounds + 1
		local before = 0
		for _ in pairs(collected) do
			before = before + 1
		end
		Collect()
		local after = 0
		for _ in pairs(collected) do
			after = after + 1
		end
		if after ~= before then
			LayoutStrip()
		end
	end)

	P.OnApply(LayoutMap)
end

P.OnInit(Init)
