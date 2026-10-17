-- PhantomUI: Laufwerte immer sichtbar (neben der Minimap). Dieselben Zahlen wie
-- im Charakterfenster (C), aus AZS_STATS; links die Grundwerte, rechts die
-- Laufwerte. Zeilen fuer Sonderschaden erscheinen erst, wenn sie etwas bringen.

local P = PhantomUI
local ROW = 12
local COL_W = 118

local frame, title
local rows = {}

local function Label(key)
	local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
	local t = PhantomUI_StatLabels and (PhantomUI_StatLabels[lang] or PhantomUI_StatLabels.enUS)
	return t and t[key] or key
end

local function Pct(v)
	return string.format("%+.0f%%", (v or 0) * 100)
end

-- { Beschriftung, Wert, immer zeigen? }
local function Lines(s)
	local left = {
		{ "Health", string.format("%.0f", s.hp or 0) },
		{ "Damage", Pct((s.dmg or 1) - 1) },
		{ "Haste", Pct(1 - (s.cd or 1)) },
		{ "Crit", string.format("%.1f%%", (s.crit or 0) * 100) },
		{ "Crit Dmg", string.format("%.0f%%", (s.cm or 0) * 100) },
		{ "Armor", string.format("%.0f%%", (s.arm or 0) * 100) },
		{ "Area", Pct((s.area or 1) - 1) },
		{ "Targets", string.format("+%d", s.cnt or 0) },
		{ "Echo", string.format("%.0f%%", (s.echo or 0) * 100) },
		{ "Speed", Pct((s.spd or 1) - 1) },
		{ "Regen", string.format("%.1f", s.reg or 0) },
		{ "Pickup", string.format("%.0f", s.pick or 0) },
	}
	local right = {
		{ "Lifesteal", string.format("%.1f%%", (s.lch or 0) * 100) },
		{ "Kill Heal", string.format("%.0f", s.heal or 0) },
		{ "Thorns", string.format("%.0f%%", (s.thn or 0) * 100) },
		{ "Lives", string.format("%d", s.liv or 0) },
		{ "Experience", Pct((s.xp or 1) - 1) },
		{ "Gold", Pct((s.gold or 1) - 1) },
		{ "Luck", Pct(s.luck) },
		{ "Buff Power", Pct(s.bp) },
		{ "DoT Stacks", string.format("%d", s.dots or 0) },
		{ "DoT Haste", Pct(s.doth) },
	}
	local extra = {
		{ "Vs Elites", s.big }, { "Execute", s.exe }, { "Vs Controlled", s.cc },
		{ "Vs Afflicted", s.dotd }, { "Shielded", s.shd }, { "Melee", s.auto }, { "Pet Damage", s.pet },
	}
	for i = 1, table.getn(extra) do
		local v = extra[i][2]
		if v and v ~= 0 then
			table.insert(right, { extra[i][1], Pct(v) })
		end
	end
	return left, right
end

local function Row(i)
	local r = rows[i]
	if r then
		return r
	end
	r = {}
	r.label = frame:CreateFontString(nil, "OVERLAY")
	r.value = frame:CreateFontString(nil, "OVERLAY")
	r.label:SetJustifyH("LEFT")
	r.value:SetJustifyH("RIGHT")
	-- Unsichtbare Flaeche fuer den Tooltip mit der Erklaerung des Spiels
	r.hover = CreateFrame("Frame", nil, frame)
	r.hover:EnableMouse(true)
	r.hover:SetHeight(ROW)
	r.hover:SetWidth(COL_W)
	r.hover:SetScript("OnEnter", function()
		local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
		local tips = PhantomUI_StatTips and (PhantomUI_StatTips[lang] or PhantomUI_StatTips.enUS)
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(Label(this.key) .. " " .. (this.val or ""), 1, 1, 1)
		if tips and tips[this.key] then
			GameTooltip:AddLine(tips[this.key], 1, 0.82, 0, 1)
		end
		GameTooltip:Show()
	end)
	r.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = r
	return r
end

local function Update()
	local db = P.DB().stats
	if not frame then
		return
	end
	local s = AZS_STATS
	if type(s) ~= "table" then
		if P.unlocked then
			s = {}
		else
			frame:Hide()
			return
		end
	end
	frame:Show()
	local font = P.Font()
	-- Stil nur bei Aenderung neu setzen (SetFont/SetBackdrop sind teuer)
	local styleKey = font .. ":" .. tostring(db.scale) .. ":" .. tostring(db.bgAlpha)
	local restyle = frame.styleKey ~= styleKey
	if restyle then
		frame.styleKey = styleKey
		frame:SetScale(db.scale or 1)
		title:SetFont(font, 11, "OUTLINE")
		title:SetText(Label("Run Stats"))
	end
	local left, right = Lines(s)
	local n = 0
	local function Put(list, col)
		for i = 1, table.getn(list) do
			n = n + 1
			local r = Row(n)
			local x = 8 + (col - 1) * (COL_W + 10)
			local y = -22 - (i - 1) * ROW
			if restyle or r.font ~= font then
				r.font = font
				r.label:SetFont(font, 10, "OUTLINE")
				r.value:SetFont(font, 10, "OUTLINE")
			end
			r.label:ClearAllPoints()
			r.label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
			r.value:ClearAllPoints()
			r.value:SetPoint("TOPRIGHT", frame, "TOPLEFT", x + COL_W, y)
			r.label:SetText(Label(list[i][1]))
			r.label:SetTextColor(0.75, 0.68, 0.85)
			r.value:SetText(list[i][2])
			r.value:SetTextColor(1, 1, 1)
			r.hover:ClearAllPoints()
			r.hover:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y + 1)
			r.hover.key = list[i][1]
			r.hover.val = list[i][2]
			r.label:Show()
			r.value:Show()
			r.hover:Show()
		end
	end
	Put(left, 1)
	Put(right, 2)
	for i = n + 1, table.getn(rows) do
		rows[i].label:Hide()
		rows[i].value:Hide()
		rows[i].hover:Hide()
	end
	local lines = math.max(table.getn(left), table.getn(right))
	if frame.lines ~= lines or restyle then
		frame.lines = lines
		frame:SetWidth(16 + 2 * COL_W + 10)
		frame:SetHeight(28 + lines * ROW)
		-- Durchsichtig: ohne Hintergrund auch kein Rahmen
		local alpha = db.bgAlpha or 0
		P.Box(frame, alpha)
		frame:SetBackdropBorderColor(0, 0, 0, alpha > 0 and 1 or 0)
	end
end

local function Init()
	local db = P.DB().stats
	if not db.enabled then
		return
	end
	frame = CreateFrame("Frame", "PhantomUI_Stats", UIParent)
	frame:SetFrameStrata("LOW")
	title = frame:CreateFontString(nil, "OVERLAY")
	title:SetPoint("TOP", frame, "TOP", 0, -6)
	title:SetTextColor(P.ACCENT[1] + 0.2, P.ACCENT[2] + 0.25, P.ACCENT[3] + 0.08)
	frame:SetWidth(16 + 2 * COL_W + 10)
	frame:SetHeight(180)
	P.RegisterMover("stats", frame, "Laufwerte", function(f)
		local map = getglobal("PhantomUI_Minimap") or Minimap
		f:SetPoint("TOPRIGHT", map, "TOPLEFT", -6, 0)
	end, {
		uniform = true,
		get = function()
			local s = P.DB().stats.scale or 1
			return s * 100, s * 100
		end,
		set = function(w, h)
			P.DB().stats.scale = P.Clamp(h, 50, 200) / 100
		end,
	})
	local last, t = nil, 0
	local ticker = CreateFrame("Frame")
	ticker:SetScript("OnUpdate", function()
		t = t + arg1
		if t < 0.5 then
			return
		end
		t = 0
		-- Neu zeichnen, wenn das Spiel neue Werte geschickt hat
		if AZS_STATS ~= last or (P.unlocked and not frame:IsShown()) then
			last = AZS_STATS
			Update()
		end
	end)
	P.OnApply(Update)
	Update()
end

P.OnInit(Init)
