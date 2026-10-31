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

local CheckPlate
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
					-- sofort beim Erscheinen pruefen, nicht erst beim naechsten Takt
					local old = f:GetScript("OnShow")
					f:SetScript("OnShow", function()
						if old then
							old()
						end
						CheckPlate(this)
					end)
					CheckPlate(f)
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
local enemyOff = false
local partyNames = {}
local inGroup = false

local bossNames = {}

-- Namen der Bosse, Endbosse und Waechter im Lauf
local function BossNames()
	local names = {}
	local units = AZS_UNITS
	if type(units) == "table" then
		for i = 1, table.getn(units) do
			local u = units[i]
			if type(u) == "table" and u.name and (u.kind == "boss" or u.kind == "final" or u.kind == "guardian") then
				names[u.name] = true
			end
		end
	end
	return names
end

local function Visible(plate, on)
	plate:SetAlpha(on and 1 or 0)
	-- unsichtbar heisst auch: nicht anklickbar, kein Mouseover
	plate:EnableMouse(on)
end

-- eine Plakette pruefen:
-- Mitspieler in Klassenfarbe; freundliche weg; mit "nur Bosse" nur Bosse/Waechter
CheckPlate = function(plate)
	if not plate.puiName or not plate.puiBar then
		return
	end
	local db = P.DB().plates
	local ally = inGroup and db.ally
	local bossOnly = db.bossOnly
	if not ally and not bossOnly then
		return
	end
	local n = plate.puiName:GetText()
	local unit = ally and n and partyNames[n]
	if unit then
		local r, g, b = P.PartyClassRGB(unit)
		plate.puiBar:SetStatusBarColor(r, g, b)
		plate.puiName:SetTextColor(r, g, b)
		Visible(plate, true)
		return
	end
	-- Feinde aus + Gruppe: jede andere Plakette ist freundlich (Totems, Begleiter)
	-- -> sofort weg, ohne auf die Einfaerbung zu warten (kein Aufblitzen);
	-- Hide statt nur Alpha: soll nicht mehr beim Stapeln mitzaehlen
	if ally and enemyOff then
		Visible(plate, false)
		-- Name noch leer: nur unsichtbar, nicht verstecken
		if n and n ~= "" then
			plate:Hide()
		end
		return
	end
	-- freundlich = vom Spiel blau/gruen eingefaerbt (Totems, Begleiter, NPCs)
	local r, g, b = plate.puiBar:GetStatusBarColor()
	if r < 0.2 and (g > 0.8 or b > 0.8) then
		Visible(plate, false)
	elseif bossOnly then
		Visible(plate, n and bossNames[n] and true or false)
	else
		Visible(plate, true)
	end
end

local function Allies()
	local db = P.DB().plates
	local inParty = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
	inGroup = inParty
	-- freundliche Plaketten nur in der Gruppe einschalten
	if db.ally then
		if inParty and not friendOn and ShowFriendNameplates then
			ShowFriendNameplates()
			friendOn = true
		elseif not inParty and friendOn and HideFriendNameplates then
			HideFriendNameplates()
			friendOn = false
		end
	end
	-- feindliche Plaketten aus (Einstellung): unsichtbare Plaketten wuerden
	-- beim Stapeln trotzdem Platz belegen, darum ganz abschalten
	if not db.enemy and not enemyOff and HideNameplates then
		HideNameplates()
		enemyOff = true
	elseif db.enemy and enemyOff and ShowNameplates then
		ShowNameplates()
		enemyOff = false
	end
	partyNames = inParty and PartyNames() or {}
	bossNames = db.bossOnly and BossNames() or {}
	if (inParty and db.ally) or db.bossOnly then
		for plate in pairs(styled) do
			if plate:IsShown() then
				CheckPlate(plate)
			end
		end
	end
end

local function Init()
	local pd = P.DB().plates
	-- AS 0.131: Plaketten koennen ueberlappen -> Feinde + nur Bosse wieder an (einmalig)
	if not pd.v131 then
		pd.v131 = true
		pd.enemy = true
		pd.bossOnly = true
	end
	-- nur Bosse: unsichtbare Plaketten duerfen nicht stapeln -> Ueberlappen
	if pd.bossOnly and pd.enemy and SetCVar then
		pcall(SetCVar, "nameplateLayout", "overlap")
	end
	if not P.DB().plates.enabled or DFRL then
		-- Mit SurvivorsDragonUi bleiben dessen Plaketten.
		return
	end
	local t = 0
	local ticker = CreateFrame("Frame", "PhantomUI_PlatesTicker")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		Scan()
		if t > 0.2 then
			t = 0
			Allies()
		elseif inGroup or P.DB().plates.bossOnly then
			-- jedes Bild pruefen: das Spiel faerbt eine neue Plakette erst nach
			-- dem Erscheinen ein, sonst blitzt sie kurz gruen auf
			for plate in pairs(styled) do
				if plate:IsShown() then
					CheckPlate(plate)
				end
			end
		end
	end)
end

P.OnInit(Init)
