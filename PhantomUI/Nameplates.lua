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
	-- Breite/Höhe/Skalierung aus den Einstellungen
	local db = P.DB().plates
	local sc = db.scale or 1
	bar:SetWidth((db.width or 100) * sc)
	bar:SetHeight((db.height or 8) * sc)
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
		nameText:SetFont(P.Font(), math.floor(10 * sc + 0.5), "OUTLINE")
		nameText:ClearAllPoints()
		nameText:SetPoint("BOTTOM", bar, "TOP", 0, 3)
	end
	plate.puiName, plate.puiBar, plate.puiLevel = nameText, bar, levelText
	if levelText then
		levelText:SetFont(P.Font(), math.floor(9 * sc + 0.5), "OUTLINE")
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
				names[u.name] = u.id or true
			end
		end
	end
	return names
end


-- Debuffs statt Name (Bosse/Wächter; das Spiel liefert Debuffs nur für sie)
local function DebuffIcon(plate, k, size)
	plate.puiDeb = plate.puiDeb or {}
	local b = plate.puiDeb[k]
	if not b then
		b = CreateFrame("Frame", nil, plate)
		b.edge = b:CreateTexture(nil, "BACKGROUND")
		b.edge:SetTexture(P.FLAT)
		b.edge:SetVertexColor(0, 0, 0, 1)
		b.edge:SetAllPoints(b)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		b.count = b:CreateFontString(nil, "OVERLAY")
		b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
		b.time = b:CreateFontString(nil, "OVERLAY")
		b.time:SetPoint("CENTER", b, "TOP", 0, 0)
		plate.puiDeb[k] = b
	end
	if b.size ~= size then
		b.size = size
		b:SetWidth(size)
		b:SetHeight(size)
		b.count:SetFont(P.Font(), math.max(7, math.floor(size * 0.5)), "OUTLINE")
		b.time:SetFont(P.Font(), math.max(7, math.floor(size * 0.45)), "OUTLINE")
	end
	return b
end

local targetPlate
local function PlateDebuffs(plate, id)
	local db = P.DB().plates
	local label = db.label or (db.debuffs == false and "name" or "debuffs")
	local list
	if label == "debuffs" then
		if id and id ~= true and type(AZS_GetDebuffs) == "function" then
			list = AZS_GetDebuffs(id) or {}
		elseif db.debuffScope == "target" and plate == targetPlate and UnitDebuff then
			-- normale Gegner: nur das Ziel (sonst kennt der Client keine Debuffs)
			list = {}
			for k = 1, 16 do
				local tex, apps = UnitDebuff("target", k)
				if not tex then
					break
				end
				table.insert(list, { icon = tex, stacks = apps })
			end
		end
	end
	local n = 0
	if list then
		local size = db.debuffSize or 18
		local count = math.min(table.getn(list), 8)
		local x0 = -(count * (size + 2) - 2) / 2
		for i = 1, count do
			local d = list[i]
			n = n + 1
			local b = DebuffIcon(plate, n, size)
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", plate.puiBar, "TOP", x0 + (i - 1) * (size + 2), 3)
			local icon = d.icon
			if icon and not string.find(icon, "\\", 1, true) then
				icon = "Interface\\Icons\\" .. icon
			end
			b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			b.count:SetText((d.stacks and d.stacks > 1) and d.stacks or "")
			b.time:SetText((d.remaining and not d.permanent) and math.ceil(d.remaining) or "")
			b:Show()
		end
	end
	if plate.puiDeb then
		for k = n + 1, table.getn(plate.puiDeb) do
			plate.puiDeb[k]:Hide()
		end
	end
	-- entweder Name oder Debuffs
	plate.puiName:SetAlpha(label == "name" and 1 or 0)
end

local function Visible(plate, on)
	plate:SetAlpha(on and 1 or 0)
	-- unsichtbar heisst auch: nicht anklickbar, kein Mouseover
	plate:EnableMouse(on)
end

-- eine Plakette pruefen:
-- Mitspieler in Klassenfarbe; freundliche weg; mit "nur Bosse" nur Bosse/Waechter
-- Einstellungen (Seite "Plaketten"):
-- enemyMode off/all/boss, friendMode off/party/all, hidePets, layout stack/overlap
local function Modes()
	local db = P.DB().plates
	return db.enemyMode or "boss", db.friendMode or "party", db.hidePets
end

CheckPlate = function(plate)
	if not plate.puiName or not plate.puiBar then
		return
	end
	local enemyMode, friendMode, hidePets = Modes()
	local n = plate.puiName:GetText()
	-- Mitspieler: Klassenfarbe
	local unit = friendMode ~= "off" and n and partyNames[n]
	if unit then
		local r, g, b = P.PartyClassRGB(unit)
		plate.puiBar:SetStatusBarColor(r, g, b)
		plate.puiName:SetTextColor(r, g, b)
		Visible(plate, true)
		PlateDebuffs(plate, nil)
		plate.puiName:SetAlpha(1)
		return
	end
	-- Feinde aus + nur Mitspieler: jede andere Plakette ist freundlich -> sofort weg
	-- (kein Aufblitzen vor der Einfaerbung)
	if enemyOff and friendMode == "party" then
		Visible(plate, false)
		if n and n ~= "" then
			plate:Hide()
		end
		return
	end
	local r, g, b = plate.puiBar:GetStatusBarColor()
	if r < 0.2 and (g > 0.8 or b > 0.8) then
		-- freundlich: blau = Spieler, gruen = Begleiter/Totems/NPCs
		local pet = g > 0.8
		Visible(plate, friendMode == "all" and not (hidePets and pet))
		PlateDebuffs(plate, nil)
		plate.puiName:SetAlpha(1)
		return
	end
	if enemyMode == "boss" then
		Visible(plate, n and bossNames[n] and true or false)
	else
		Visible(plate, true)
	end
	PlateDebuffs(plate, n and bossNames[n])
end

local layoutSet
local function Allies()
	local db = P.DB().plates
	local enemyMode, friendMode = Modes()
	local inParty = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
	inGroup = inParty
	-- freundliche Plaketten: "alle" immer, "Mitspieler" nur in der Gruppe
	local wantFriend = friendMode == "all" or (friendMode == "party" and inParty)
	if wantFriend and not friendOn and ShowFriendNameplates then
		ShowFriendNameplates()
		friendOn = true
	elseif not wantFriend and friendOn and HideFriendNameplates then
		HideFriendNameplates()
		friendOn = false
	end
	-- feindliche ganz aus statt unsichtbar
	local wantEnemy = enemyMode ~= "off"
	if not wantEnemy and not enemyOff and HideNameplates then
		HideNameplates()
		enemyOff = true
	elseif wantEnemy and enemyOff and ShowNameplates then
		ShowNameplates()
		enemyOff = false
	end
	-- Stapeln / Ueberlappen (AS 0.131)
	local layout = db.layout or "overlap"
	if layoutSet ~= layout and SetCVar then
		layoutSet = layout
		pcall(SetCVar, "nameplateLayout", layout)
	end
	partyNames = inParty and PartyNames() or {}
	bossNames = BossNames()
	-- Ziel-Plakette: nur wenn der Name eindeutig ist
	targetPlate = nil
	local tn = UnitExists("target") and UnitCanAttack("player", "target") and UnitName("target")
	if tn then
		local hits = 0
		for plate in pairs(styled) do
			if plate:IsShown() and plate.puiName and plate.puiName:GetText() == tn then
				hits = hits + 1
				targetPlate = plate
			end
		end
		if hits ~= 1 then
			targetPlate = nil
		end
	end
	for plate in pairs(styled) do
		if plate:IsShown() then
			CheckPlate(plate)
		end
	end
end

local function Init()
	local pd = P.DB().plates
	-- alte Schalter -> neue Modi (einmalig)
	if not pd.enemyMode then
		if pd.v131 == nil or (pd.enemy and pd.bossOnly) then
			pd.enemyMode = "boss"
		elseif pd.enemy then
			pd.enemyMode = "all"
		else
			pd.enemyMode = "off"
		end
		pd.friendMode = (pd.ally == false) and "off" or "party"
		pd.layout = pd.layout or "overlap"
		if pd.hidePets == nil then
			pd.hidePets = true
		end
	end
	if not pd.enabled or DFRL then
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
		else
			-- jedes Bild pruefen: das Spiel faerbt neue Plaketten erst danach ein
			for plate in pairs(styled) do
				if plate:IsShown() then
					CheckPlate(plate)
				end
			end
		end
	end)
	P.OnApply(function()
		layoutSet = nil
		for plate in pairs(styled) do
			Style(plate)
		end
	end)
end

-- /pui plates: was die Plaketten sehen (Fehlersuche)
function P.PlateDebug()
	local db = P.DB().plates
	local units = type(AZS_UNITS) == "table" and AZS_UNITS or {}
	local debs = type(AZS_DEBUFFS) == "table" and AZS_DEBUFFS or {}
	P.Print("Plaketten: Stil " .. tostring(db.enabled) .. ", Debuffs " .. tostring(db.debuffs)
		.. ", Feinde " .. tostring(db.enemyMode) .. ", Einheiten " .. table.getn(units) .. ", Debuffs gesamt " .. table.getn(debs))
	for i = 1, table.getn(units) do
		local u = units[i]
		local n = type(AZS_GetDebuffs) == "function" and table.getn(AZS_GetDebuffs(u.id) or {}) or -1
		P.Print("  Einheit: " .. tostring(u.name) .. " (" .. tostring(u.kind) .. ", id " .. tostring(u.id) .. ") Debuffs " .. n)
	end
	local shown = 0
	for plate in pairs(styled) do
		if plate:IsShown() then
			shown = shown + 1
			local n = plate.puiName and plate.puiName:GetText()
			P.Print("  Plakette: " .. tostring(n) .. " -> Boss-id " .. tostring(bossNames[n]) .. ", Alpha " .. string.format("%.1f", plate:GetAlpha()))
		end
	end
	P.Print("  sichtbare Plaketten: " .. shown)
end

P.OnInit(Init)
