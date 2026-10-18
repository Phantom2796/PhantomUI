-- PhantomUI: Ressource frei unter dem Charakter. Immer nur EINE Leiste, je
-- nach Klasse: Wut (Krieger, Baer), 5 Kaestchen fuer Kombopunkte (Schurke,
-- Katze) oder Seelensplitter (Hexer). Mana spielt in AZS keine Rolle.

local P = PhantomUI
local SEGMENTS = 5

-- Farben wie im aktuellen WoW
local COLORS = {
	[0] = { 0, 0.55, 1 }, -- Mana
	[1] = { 1, 0, 0 }, -- Wut (WoW-Rot)
	[2] = { 1, 0.5, 0.25 }, -- Fokus
	[3] = { 1, 0.96, 0.41 }, -- Energie
}
local SHARD = { 0.58, 0.32, 0.86 } -- Seelensplitter-Violett
local COMBO = { 0.95, 0.25, 0.1 } -- Kombopunkte

local frame, bar, bg, text, segRow
local segs = {}
local mode

------------------------------------------------------------------------
-- Seelensplitter: wo das Spiel sie haelt, ist noch nicht geklaert. Gesucht wird
-- an denselben Stellen wie bei CompactShards, dessen Rekorder das gerade klaert.
------------------------------------------------------------------------

local function ShardsFromBags()
	local count, found = 0, false
	for bagIndex = 0, 4 do
		local slots = GetContainerNumSlots(bagIndex) or 0
		for slot = 1, slots do
			local link = GetContainerItemLink(bagIndex, slot)
			if link and (string.find(link, "item:6265:", 1, true) or string.find(link, "Seelensplitter", 1, true)) then
				local _, n = GetContainerItemInfo(bagIndex, slot)
				count = count + (n or 1)
				found = true
			end
		end
	end
	if found then
		return count
	end
	return nil
end

-- Welche Leiste: "bar" (Wut/Energie/Fokus), "combo", "shards" oder nil
local function Mode()
	-- Nur der Krieger bekommt eine Leiste (Wut). Mana braucht in Azeroth
	-- Survivors keiner, Kombopunkte zeigt das Spiel selbst (siehe UnitFrames).
	local _, class = UnitClass("player")
	if class == "WARRIOR" then
		return "bar"
	end
	return nil
end

-- Kombopunkte: das Spiel meldet sie ueber PLAYER_COMBO_POINTS. Je nach Client
-- liefert GetComboPoints sie mit oder ohne Einheit; zusaetzlich die Zahl aus
-- der Kampftext-Meldung (COMBAT_TEXT_UPDATE "COMBO_POINTS").
local comboText = 0

-- "Schicksal besiegeln" fuehrt die Punkte nur im Spiel selbst. Nachgerechnet
-- nach seiner Beschreibung: jeder Stoss +1, ein kritischer +2, hoechstens 2,5
-- pro Sekunde; bei 5 kommt ein kostenloses Ausweiden und die Punkte sind weg.
local comboEst, lastGain = 0, 0
local GAIN_GAP = 0.4
local function HasSealFate()
	local spells = AZS_SPELLS
	if type(spells) ~= "table" then
		return false
	end
	for i = 1, table.getn(spells) do
		if type(spells[i]) == "table" and spells[i].key == "seal_fate" then
			return true
		end
	end
	return false
end
local function NoteStrike(msg)
	local _, _, spell, how = string.find(msg, "^Your (.+) (%a+) .- for %d+")
	if not spell or (how ~= "hits" and how ~= "crits") then
		return
	end
	if spell == "Eviscerate" then
		comboEst = 0
		return
	end
	local now = GetTime()
	if now - lastGain >= GAIN_GAP then
		comboEst = math.min(SEGMENTS, comboEst + (how == "crits" and 2 or 1))
		lastGain = now
	end
end

local function Combo()
	local n = 0
	if GetComboPoints then
		local ok, a = pcall(GetComboPoints)
		if ok and tonumber(a) then
			n = math.max(n, tonumber(a))
		end
		ok, a = pcall(GetComboPoints, "player", "target")
		if ok and tonumber(a) then
			n = math.max(n, tonumber(a))
		end
		ok, a = pcall(GetComboPoints, "player")
		if ok and tonumber(a) then
			n = math.max(n, tonumber(a))
		end
	end
	if comboText > n then
		n = comboText
	end
	if comboEst > n then
		n = comboEst
	end
	return math.min(n, SEGMENTS)
end

-- Diagnose: was meldet das Spiel? (/pui combo, am besten mitten im Kampf)
local comboEvents, comboArgs = 0, ""
function P.ComboDebug()
	local function Try(...)
		if not GetComboPoints then
			return "fehlt"
		end
		local ok, v = pcall(GetComboPoints, unpack(arg))
		return ok and tostring(v) or ("Fehler")
	end
	local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff9d4de8PhantomUI|r " .. t) end
	say("GetComboPoints(): " .. Try() .. "  (player,target): " .. Try("player", "target") .. "  (player): " .. Try("player"))
	say("PLAYER_COMBO_POINTS: " .. comboEvents .. "x, zuletzt: " .. comboArgs .. "  Kampftext: " .. tostring(comboText)
		.. "  nachgerechnet: " .. comboEst .. (HasSealFate() and " (Schicksal besiegeln da)" or " (kein Schicksal besiegeln)"))
	local buffs = {}
	if type(AZS_BUFFS) == "table" then
		for i = 1, table.getn(AZS_BUFFS) do
			local b = AZS_BUFFS[i]
			table.insert(buffs, tostring(b.spell) .. "=" .. tostring(b.left))
		end
	end
	say("AZS_BUFFS: " .. (table.getn(buffs) > 0 and table.concat(buffs, ", ") or "-"))
	local tex = {}
	for i = 0, 15 do
		local ok, t = pcall(GetPlayerBuffTexture or function() end, i)
		if ok and t then
			local ok2, apps = pcall(GetPlayerBuffApplications or function() end, i)
			local _, _, short = string.find(t, "([^\\]+)$")
			table.insert(tex, (short or t) .. "x" .. tostring(apps))
		end
	end
	say("Buffs: " .. (table.getn(tex) > 0 and table.concat(tex, ", ") or "-"))
end

-- AZS legt die Seelensplitter des Hexers in die Manaleiste: 0-100, 20 je Splitter.
local function Shards()
	local cur, max = UnitMana("player") or 0, UnitManaMax("player") or 0
	if UnitPowerType("player") == 0 and max > 0 then
		return math.floor(cur / max * SEGMENTS + 0.001)
	end
	return ShardsFromBags() or 0
end

------------------------------------------------------------------------

local function Layout()
	local db = P.DB().power
	local tex = P.Texture()
	local e = db.border or 2
	frame:SetScale(db.scale)
	frame:SetWidth(db.width)
	frame:SetHeight(db.height)
	mode = Mode()
	local shown = mode or (P.unlocked and "bar")

	-- Leiste
	P.Box(bar.box, db.bgAlpha, e)
	bar.box:SetBackdropColor(0, 0, 0, 0)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", bar.box, "TOPLEFT", e, -e)
	bar:SetPoint("BOTTOMRIGHT", bar.box, "BOTTOMRIGHT", -e, e)
	bar:SetStatusBarTexture(tex)
	bg:SetTexture(tex)
	text:SetFont(P.Font(), math.max(8, db.height - 2 * e + 1), "OUTLINE")
	if db.text then
		text:Show()
	else
		text:Hide()
	end

	-- 5 Kaestchen ohne Abstand: jedes mit schwarzem Rahmen, die Raender
	-- ueberlappen sich; innen durchsichtig, Farbe nur wenn gefuellt.
	local w = (db.width + (SEGMENTS - 1) * e) / SEGMENTS
	for i = 1, SEGMENTS do
		local s = segs[i]
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", segRow, "TOPLEFT", (i - 1) * (w - e), 0)
		s:SetWidth(w)
		s:SetHeight(db.height)
		P.Box(s, db.bgAlpha, e)
		s.fill:ClearAllPoints()
		s.fill:SetPoint("TOPLEFT", s, "TOPLEFT", e, -e)
		s.fill:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -e, e)
		s.fill:SetTexture(tex)
	end

	if shown == "bar" then
		bar.box:Show()
		segRow:Hide()
	elseif shown then
		bar.box:Hide()
		segRow:Show()
	else
		bar.box:Hide()
		segRow:Hide()
	end
end

local function Update()
	if not frame then
		return
	end
	if Mode() ~= mode then
		Layout()
	end
	if not mode and not P.unlocked then
		frame:Hide()
		return
	end
	frame:Show()

	if mode == "combo" or mode == "shards" then
		local n, color
		if mode == "combo" then
			n, color = Combo(), COMBO
		else
			n, color = Shards(), SHARD
		end
		for i = 1, SEGMENTS do
			if i <= n then
				segs[i].fill:SetVertexColor(color[1], color[2], color[3], 1)
				segs[i].fill:Show()
			else
				segs[i].fill:Hide()
			end
		end
		return
	end

	local cur, max = UnitMana("player") or 0, UnitManaMax("player") or 0
	local kind = UnitPowerType("player") or 0
	if kind == 1 and max <= 0 then
		max = 100
	end
	if max <= 0 then
		max = 1
	end
	bar:SetMinMaxValues(0, max)
	bar:SetValue(cur)
	local c = COLORS[kind] or COLORS[0]
	bar:SetStatusBarColor(c[1], c[2], c[3])
	bg:SetVertexColor(c[1] * 0.2, c[2] * 0.2, c[3] * 0.2, P.DB().power.bgAlpha or 0)
	if kind == 0 then
		text:SetText(cur .. " / " .. max)
	else
		text:SetText(cur)
	end
end

local function Init()
	if not P.DB().power.enabled then
		return
	end
	frame = CreateFrame("Frame", "PhantomUI_Power", UIParent)
	frame:SetFrameStrata("LOW")

	local box = CreateFrame("Frame", nil, frame)
	box:SetAllPoints(frame)
	bar = CreateFrame("StatusBar", nil, box)
	bar.box = box
	bar:SetFrameLevel(box:GetFrameLevel() + 1)
	bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	-- Rahmen ueber der Leiste, damit er nicht verdeckt wird
	local holder = CreateFrame("Frame", nil, box)
	holder:SetAllPoints(box)
	holder:SetFrameLevel(bar:GetFrameLevel() + 2)
	text = P.Text(holder, 11)
	text:SetPoint("CENTER", box, "CENTER", 0, 0)

	segRow = CreateFrame("Frame", nil, frame)
	segRow:SetAllPoints(frame)
	for i = 1, SEGMENTS do
		local s = CreateFrame("Frame", nil, segRow)
		s.fill = s:CreateTexture(nil, "ARTWORK")
		segs[i] = s
	end

	Layout()
	P.RegisterMover("power", frame, "Ressource", function(f)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -110)
	end, {
		scale = "power",
		get = function()
			local db = P.DB().power
			return db.width, db.height
		end,
		set = function(w, h)
			local db = P.DB().power
			db.width = P.Clamp(w, 60, 500)
			db.height = P.Clamp(h, 6, 40)
		end,
	})

	local events = CreateFrame("Frame", "PhantomUI_PowerEvents")
	for _, e in ipairs({
		"PLAYER_ENTERING_WORLD",
		"UNIT_MANA",
		"UNIT_MAXMANA",
		"UNIT_RAGE",
		"UNIT_MAXRAGE",
		"UNIT_ENERGY",
		"UNIT_MAXENERGY",
		"UNIT_FOCUS",
		"UNIT_DISPLAYPOWER",
		"PLAYER_COMBO_POINTS",
		"COMBAT_TEXT_UPDATE",
		"CHAT_MSG_SPELL_SELF_DAMAGE",
		"PLAYER_TARGET_CHANGED",
		"BAG_UPDATE",
	}) do
		events:RegisterEvent(e)
	end
	events:SetScript("OnEvent", function()
		if string.find(event, "^UNIT_") and arg1 ~= "player" then
			return
		end
		if event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
			if mode == "combo" and HasSealFate() then
				NoteStrike(arg1 or "")
				Update()
			end
			return
		end
		if event == "PLAYER_COMBO_POINTS" then
			comboEvents = comboEvents + 1
			comboArgs = tostring(arg1) .. "/" .. tostring(arg2)
		end
		if event == "COMBAT_TEXT_UPDATE" then
			if arg1 == "COMBO_POINTS" then
				comboText = tonumber(arg2) or 0
			else
				return
			end
		end
		Update()
	end)
	local elapsed = 0
	events:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed > 0.5 then
			elapsed = 0
			-- Ohne neue Stoesse verfallen die nachgerechneten Punkte
			if comboEst > 0 and GetTime() - lastGain > 8 then
				comboEst = 0
			end
			Update()
		end
	end)

	P.OnApply(function()
		Layout()
		Update()
	end)
	Update()
end

P.OnInit(Init)
