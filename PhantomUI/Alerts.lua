-- PhantomUI: eigene Einblendungen (Boss naht, Boss besiegt, Waechter getoetet,
-- Hort zurueckerobert) klein und links unter dem Chat. Die grossen Banner des
-- Spiels werden dafuer ausgeblendet. Die Ereignisse leitet PhantomUI aus den
-- Laufdaten ab (AZS_SCHEDULE, Waechter, Horte); Texte aus den Spieldaten.

local P = PhantomUI
local MAX_LINES = 5
local LIFE = 6      -- Sekunden sichtbar
local FADE = 1.5    -- davon die letzten Sekunden ausblenden

local frame
local lines = {}    -- { text, color, age }
local labels = {}

local function Text(key, name)
	local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
	local t = PhantomUI_AlertTexts and (PhantomUI_AlertTexts[lang] or PhantomUI_AlertTexts.enUS)
	local s = t and t[key] or key
	if key == "claims" then
		return (name or "") .. " " .. s
	end
	return (string.gsub(s, "{name}", name or ""))
end

local COLORS = {
	approach = { 1, 0.55, 0.35 },
	come = { 1, 0.3, 0.3 },
	defeated = { 0.45, 1, 0.5 },
	slain = { 0.45, 1, 0.5 },
	claims = { 0.85, 0.65, 1 },
}

local function Layout()
	local db = P.DB().alerts
	frame:SetScale(db.scale or 1)
	for i = 1, MAX_LINES do
		local l = labels[i]
		l:SetFont(P.Font(), db.size or 13, "OUTLINE")
		l:SetShadowOffset(1, -1)
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * ((db.size or 13) + 5))
	end
	frame:SetWidth(360)
	frame:SetHeight(MAX_LINES * ((db.size or 13) + 5))
end

local function Redraw()
	for i = 1, MAX_LINES do
		local entry = lines[i]
		local l = labels[i]
		if entry then
			l:SetText(entry.text)
			l:SetTextColor(entry.color[1], entry.color[2], entry.color[3])
			local left = LIFE - entry.age
			l:SetAlpha(left < FADE and math.max(0, left / FADE) or 1)
			l:Show()
		elseif P.unlocked and i == 1 then
			l:SetText(Text("approach", "Boss"))
			l:SetTextColor(1, 0.55, 0.35)
			l:SetAlpha(1)
			l:Show()
		else
			l:Hide()
		end
	end
end

local function Push(text, color)
	-- Gleiche Meldung kurz hintereinander nicht doppelt
	if lines[1] and lines[1].text == text and lines[1].age < 1.5 then
		lines[1].age = 0
		Redraw()
		return
	end
	table.insert(lines, 1, { text = text, color = color, age = 0 })
	while table.getn(lines) > MAX_LINES do
		table.remove(lines)
	end
	Redraw()
end

-- Fehler- und Hinweiszeile des Spiels (z. B. "Diese Truhe benoetigt 50 Gold.")
-- hierher umleiten statt mitten auf den Bildschirm.
local function HookErrors()
	if not UIErrorsFrame or UIErrorsFrame.puiHooked then
		return
	end
	UIErrorsFrame.puiHooked = true
	local orig = UIErrorsFrame.AddMessage
	UIErrorsFrame.AddMessage = function(self, msg, r, g, b, a, hold)
		if frame and P.DB().alerts.errors and msg and msg ~= "" then
			Push(msg, { r or 1, g or 0.2, b or 0.2 })
			return
		end
		return orig(self, msg, r, g, b, a, hold)
	end
end

function P.Alert(key, name)
	if not frame then
		return
	end
	Push(Text(key, name), COLORS[key] or { 1, 1, 1 })
end

------------------------------------------------------------------------
-- Ereignisse aus den Laufdaten ableiten
------------------------------------------------------------------------

local seen = false
local bossState = {}
local guardians = {}  -- id -> { name, awake }
local lairState = {}

local function Watch()
	local fresh = not seen
	seen = true

	local sched = AZS_SCHEDULE
	if type(sched) == "table" then
		for i = 1, table.getn(sched) do
			local b = sched[i]
			if type(b) == "table" and b.name then
				local key = tostring(b.index or i)
				local old = bossState[key]
				if not fresh and old and old ~= b.state then
					if b.state == "up" then
						P.Alert((b.final == 1 or b.final == true) and "come" or "approach", b.name)
					elseif b.state == "dead" then
						P.Alert("defeated", b.name)
					end
				end
				bossState[key] = b.state
			end
		end
	end

	local list = AZS_GetGuardians and AZS_GetGuardians()
	local now = {}
	if type(list) == "table" then
		for i = 1, table.getn(list) do
			local g = list[i]
			local id = tostring(g.id or g.name)
			local awake = g.awake == true or g.awake == 1
			now[id] = true
			local old = guardians[id]
			if not fresh and awake and old and not old.awake then
				P.Alert("approach", g.name)
			end
			guardians[id] = { name = g.name, awake = awake }
		end
	end
	for id, g in pairs(guardians) do
		if not now[id] then
			if not fresh and g.awake then
				P.Alert("slain", g.name)
			end
			guardians[id] = nil
		end
	end

	local lairs = AZS_GetLairs and AZS_GetLairs()
	if type(lairs) == "table" then
		for i = 1, table.getn(lairs) do
			local l = lairs[i]
			local key = tostring(l.index or i)
			local old = lairState[key]
			if not fresh and old == "empty" and l.state ~= "empty" and l.name and l.name ~= "" then
				P.Alert("claims", l.name)
			end
			lairState[key] = l.state
		end
	end
end

local function Init()
	local db = P.DB().alerts
	if not db.enabled then
		-- Banner des Spiels wieder zeigen, falls PhantomUI sie frueher ausgeblendet hat
		if type(AZS_SetHudShown) == "function" then
			pcall(AZS_SetHudShown, "banners", true)
		end
		return
	end
	if db.hideNative and type(AZS_SetHudShown) == "function" then
		pcall(AZS_SetHudShown, "banners", false)
	end
	frame = CreateFrame("Frame", "PhantomUI_Alerts", UIParent)
	frame:SetFrameStrata("MEDIUM")
	for i = 1, MAX_LINES do
		labels[i] = frame:CreateFontString(nil, "OVERLAY")
		labels[i]:SetJustifyH("LEFT")
	end
	Layout()
	HookErrors()
	P.RegisterMover("alerts", frame, "Einblendungen", function(f)
		if ChatFrame1 then
			f:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", 0, -34)
		else
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 60)
		end
	end, {
		uniform = true,
		get = function()
			local s = P.DB().alerts.size or 13
			return s, s
		end,
		set = function(w, h)
			P.DB().alerts.size = P.Clamp(h, 9, 24)
		end,
	})
	local w, a = 0, 0
	local ticker = CreateFrame("Frame", "PhantomUI_AlertsTicker")
	ticker:SetScript("OnUpdate", function()
		w = w + arg1
		a = a + arg1
		if w > 0.25 then
			w = 0
			Watch()
		end
		if a > 0.1 then
			local changed = P.unlocked
			for i = table.getn(lines), 1, -1 do
				lines[i].age = lines[i].age + a
				if lines[i].age >= LIFE then
					table.remove(lines, i)
				end
				changed = true
			end
			a = 0
			if changed then
				Redraw()
			end
		end
	end)
	P.OnApply(function()
		Layout()
		Redraw()
	end)
end

P.OnInit(Init)

SLASH_PHANTOMALERT1 = "/puialert"
SlashCmdList["PHANTOMALERT"] = function()
	P.Alert("approach", "Hogger")
	P.Alert("defeated", "Hogger")
end
