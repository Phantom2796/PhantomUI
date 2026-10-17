-- PhantomUI: schmale Erfahrungsleiste im Phantom-Stil.

local P = PhantomUI
local frame, bar, bg, text

local function Layout()
	local db = P.DB().xp
	frame:SetScale(db.scale)
	frame:SetWidth(db.width)
	frame:SetHeight(db.height)
	P.Box(frame, 0.85)
	bar:SetStatusBarTexture(P.Texture())
	bg:SetTexture(P.Texture())
	text:SetFont(P.Font(), 10, "OUTLINE")
end

local function Update()
	local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 0
	local run = AZS_RUN
	-- AZS meldet Erfahrung des Laufs selbst; die ist genauer als die des Clients.
	if type(run) == "table" and tonumber(run.xpn) and tonumber(run.xpn) > 0 then
		cur, max = tonumber(run.xp) or cur, tonumber(run.xpn)
	end
	if max <= 0 then
		if P.unlocked then
			frame:Show()
		else
			frame:Hide()
		end
		return
	end
	frame:Show()
	bar:SetMinMaxValues(0, max)
	bar:SetValue(cur)
	frame.cur, frame.max = cur, max
end

local function Init()
	local db = P.DB().xp
	if not db.enabled then
		return
	end
	-- Leiste des Spiels und von SurvivorsDragonUi weg
	for _, name in ipairs({ "MainMenuExpBar", "ReputationWatchBar", "DFRL_XPBar" }) do
		local f = getglobal(name)
		if f then
			f:Hide()
			f.Show = function() end
		end
	end
	frame = CreateFrame("Frame", "PhantomUI_XP", UIParent)
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(true)
	bar = CreateFrame("StatusBar", nil, frame)
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	bar:SetStatusBarColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3])
	bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bg:SetVertexColor(0.12, 0.06, 0.18, 0.9)
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(bar:GetFrameLevel() + 2)
	text = holder:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	text:Hide()
	frame:SetScript("OnEnter", function()
		if this.max then
			text:SetText(this.cur .. " / " .. this.max .. "  (" .. math.floor(this.cur / this.max * 100) .. "%)")
			text:Show()
		end
	end)
	frame:SetScript("OnLeave", function() text:Hide() end)
	Layout()
	P.RegisterMover("xp", frame, "Erfahrung", function(f)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -252)
	end, {
		scale = "xp",
		get = function()
			local d = P.DB().xp
			return d.width, d.height
		end,
		set = function(w, h)
			local d = P.DB().xp
			d.width = P.Clamp(w, 60, 800)
			d.height = P.Clamp(h, 3, 20)
		end,
	})
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_XP_UPDATE")
	events:RegisterEvent("PLAYER_LEVEL_UP")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", Update)
	local t = 0
	events:SetScript("OnUpdate", function()
		t = t + arg1
		if t > 0.5 then
			t = 0
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
