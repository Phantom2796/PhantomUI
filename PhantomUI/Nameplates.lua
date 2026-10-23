-- PhantomUI: Namensplaketten ueber den Gegnern im Phantom-Stil: flache Leiste mit
-- der PhantomUI-Textur, 1-Pixel-Rand, Name mit Umriss. Nur das Aussehen; ob die
-- Plaketten sichtbar sind, regeln das Spiel (Taste V) und die Schadenszahlen.

local P = PhantomUI
local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local styled = {}
local known = 0

local function Style(plate)
	local regions = { plate:GetRegions() }
	local nameText, levelText
	for i = 1, table.getn(regions) do
		local r = regions[i]
		local kind = r:GetObjectType()
		if kind == "Texture" then
			-- Rahmen, Glanz und Elite-Drache des Spiels ausblenden
			-- nur unsichtbar: die Schadenszahlen erkennen Plaketten an dieser Textur
			r:SetAlpha(0)
		elseif kind == "FontString" then
			if not nameText then
				nameText = r
			else
				levelText = r
			end
		end
	end
	local bar
	local kids = { plate:GetChildren() }
	for i = 1, table.getn(kids) do
		if kids[i]:GetObjectType() == "StatusBar" then
			bar = kids[i]
			break
		end
	end
	if not bar then
		return false
	end
	bar:SetStatusBarTexture(P.Texture())
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", plate, "CENTER", 0, -4)
	bar:SetWidth(100)
	bar:SetHeight(8)
	if not bar.puiEdge then
		local edge = CreateFrame("Frame", nil, plate)
		edge:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
		edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		edge:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
		edge:SetBackdropColor(0.06, 0.06, 0.07, 0.85)
		edge:SetBackdropBorderColor(0, 0, 0, 1)
		bar.puiEdge = edge
	end
	if nameText then
		nameText:SetFont(P.Font(), 10, "OUTLINE")
		nameText:ClearAllPoints()
		nameText:SetPoint("BOTTOM", bar, "TOP", 0, 3)
	end
	plate.puiName, plate.puiBar, plate.puiLevel = nameText, bar, levelText
	if levelText then
		levelText:SetFont(P.Font(), 9, "OUTLINE")
		levelText:ClearAllPoints()
		levelText:SetPoint("LEFT", bar, "RIGHT", 3, 0)
	end
	return true
end

local function Scan()
	local count = WorldFrame:GetNumChildren() or 0
	if count == known then
		return
	end
	-- Neue Rahmen haengen hinten an: nur die neuen pruefen.
	local from = known + 1
	if count < known then
		from = 1
	end
	known = count
	local kids = { WorldFrame:GetChildren() }
	for i = from, table.getn(kids) do
		local f = kids[i]
		if f and not styled[f] and not f:GetName() then
			local first = f:GetRegions()
			if first and first.GetObjectType and first:GetObjectType() == "Texture" and first:GetTexture() == BORDER then
				if Style(f) then
					styled[f] = true
				end
			end
		end
	end
end

-- Koop: Mitspieler-Plakette in Klassenfarbe; andere freundliche Plaketten
-- (NPCs, Begleiter) unsichtbar
local function PartyNames()
	local names = {}
	for i = 1, 4 do
		local unit = "party" .. i
		if UnitExists(unit) then
			local n = UnitName(unit)
			if n then
				names[n] = unit
			end
		end
	end
	return names
end

local friendOn = false
local function Allies()
	local inParty = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
	if not P.DB().plates.ally then
		return
	end
	-- freundliche Plaketten nur in der Gruppe einschalten
	if inParty and not friendOn and ShowFriendNameplates then
		ShowFriendNameplates()
		friendOn = true
	elseif not inParty and friendOn and HideFriendNameplates then
		HideFriendNameplates()
		friendOn = false
	end
	if not inParty then
		return
	end
	local names = PartyNames()
	for plate in pairs(styled) do
		if plate:IsShown() and plate.puiName and plate.puiBar then
			local n = plate.puiName:GetText()
			local unit = n and names[n]
			if unit then
				local r, g, b = P.PartyClassRGB(unit)
				plate.puiBar:SetStatusBarColor(r, g, b)
				plate.puiName:SetTextColor(r, g, b)
				plate:SetAlpha(1)
			else
				-- freundlich = blau/gruen eingefaerbt vom Spiel
				local r, g, b = plate.puiBar:GetStatusBarColor()
				local friendly = r < 0.2 and (g > 0.8 or b > 0.8)
				plate:SetAlpha(friendly and 0 or 1)
			end
		end
	end
end

local function Init()
	if not P.DB().plates.enabled or DFRL then
		-- Mit SurvivorsDragonUi bleiben dessen Plaketten.
		return
	end
	local t = 0
	local ticker = CreateFrame("Frame", "PhantomUI_PlatesTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.2 then
			t = 0
			Scan()
			Allies()
		end
	end)
end

P.OnInit(Init)
