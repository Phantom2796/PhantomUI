-- PhantomUI: schlichter Chat. Pfeil-Knoepfe weg, Mausrad zum Blaettern
-- (Shift = ganz nach oben/unten), Schrift mit Umriss, durchsichtiger
-- Hintergrund; ueber die Ankerpunkte verschieb- und in der Groesse ziehbar.

local P = PhantomUI

local hidden = CreateFrame("Frame")
hidden:Hide()

local function Kill(f)
	if f then
		f:Hide()
		f:SetAlpha(0)
		if f.EnableMouse then
			f:EnableMouse(false)
		end
		f:SetParent(hidden)
		f.Show = function() end
	end
end

-- Eingabezeile: alte Steinrahmen-Grafik weg, flacher PhantomUI-Kasten
local function StyleEditBox()
	local box = ChatFrameEditBox
	if not box then
		return
	end
	local db = P.DB().chat
	local regions = { box:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		if r and r.GetObjectType and r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	P.Box(box, 0.85)
	box:SetBackdropBorderColor(0, 0, 0, 1)
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", -2, -4)
	box:SetPoint("TOPRIGHT", ChatFrame1, "BOTTOMRIGHT", 2, -4)
	box:SetHeight(22)
	box:SetTextInsets(6, 6, 0, 0)
	local font = P.FontPath(db.font)
	box:SetFont(font, db.fontSize or 13, "")
	box:SetShadowOffset(1, -1)
	local header = ChatFrameEditBoxHeader
	if header then
		header:SetFont(font, db.fontSize or 13, "")
		header:SetShadowOffset(1, -1)
		header:ClearAllPoints()
		header:SetPoint("LEFT", box, "LEFT", 6, 0)
	end
	-- Rand in der Akzentfarbe, solange man schreibt
	if not box.phantomHooked then
		box.phantomHooked = true
		local oldShow = box:GetScript("OnShow")
		box:SetScript("OnShow", function()
			if oldShow then
				oldShow()
			end
			this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1)
		end)
	end
end

local function ApplyFade(chat)
	local secs = P.DB().chat.fade or 10
	if secs > 0 then
		chat:SetFading(true)
		chat:SetTimeVisible(secs)
		chat:SetFadeDuration(2)
	else
		chat:SetFading(false)
	end
end

local function Style(i)
	local chat = getglobal("ChatFrame" .. i)
	if not chat then
		return
	end
	Kill(getglobal("ChatFrame" .. i .. "UpButton"))
	Kill(getglobal("ChatFrame" .. i .. "DownButton"))
	Kill(getglobal("ChatFrame" .. i .. "BottomButton"))
	chat:EnableMouseWheel(true)
	chat:SetScript("OnMouseWheel", function()
		if arg1 > 0 then
			if IsShiftKeyDown() then this:ScrollToTop() else this:ScrollUp() end
		else
			if IsShiftKeyDown() then this:ScrollToBottom() else this:ScrollDown() end
		end
	end)
	-- Alte Zeilen nach ein paar Sekunden ausblenden (Mausrad holt sie zurueck)
	ApplyFade(chat)
	-- Schrift: modern, ohne Umriss, mit leichtem Schatten
	local db = P.DB().chat
	chat:SetFont(P.FontPath(db.font), db.fontSize or 13, "")
	chat:SetShadowColor(0, 0, 0, 1)
	chat:SetShadowOffset(1, -1)
	-- Reiter flacher machen
	local tab = getglobal("ChatFrame" .. i .. "Tab")
	if tab then
		for _, part in ipairs({ "Left", "Middle", "Right" }) do
			local t = getglobal("ChatFrame" .. i .. "Tab" .. part)
			if t then
				t:SetAlpha(0)
			end
		end
	end
end

local function ApplyAlpha()
	local alpha = P.DB().chat.bgAlpha or 0
	-- Beim Drueberfahren blendet das Spiel sonst einen Hintergrund ein
	DEFAULT_CHATFRAME_ALPHA = alpha
	for i = 1, (NUM_CHAT_WINDOWS or 7) do
		local chat = getglobal("ChatFrame" .. i)
		if chat then
			if FCF_SetWindowColor then
				pcall(FCF_SetWindowColor, chat, 0.06, 0.06, 0.07)
			end
			if FCF_SetWindowAlpha then
				pcall(FCF_SetWindowAlpha, chat, alpha)
			end
			chat.oldAlpha = alpha
		end
	end
end

local function ApplySize()
	local db = P.DB().chat
	if db.width and db.height then
		ChatFrame1:SetWidth(db.width)
		ChatFrame1:SetHeight(db.height)
	end
end

local function Init()
	if not P.DB().chat.enabled or DFRL then
		-- Mit SurvivorsDragonUi bleibt dessen Chat.
		return
	end
	for i = 1, (NUM_CHAT_WINDOWS or 7) do
		Style(i)
	end
	-- Sprechblasen-Knopf (Chat-Menue) braucht keiner
	Kill(ChatFrameMenuButton)
	StyleEditBox()
	ApplyAlpha()
	ApplySize()

	-- Bisherigen Platz merken: der gilt als Standard, bis man ihn verschiebt.
	local point, rel, relPoint, x, y = ChatFrame1:GetPoint(1)
	if not point then
		point, rel, relPoint, x, y = "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95
	end
	P.RegisterMover("chat", ChatFrame1, "Chat", function(f)
		f:SetPoint(point, rel or UIParent, relPoint or point, x or 0, y or 0)
	end, {
		scale = nil,
		get = function()
			return ChatFrame1:GetWidth(), ChatFrame1:GetHeight()
		end,
		set = function(w, h)
			local db = P.DB().chat
			db.width = P.Clamp(w, 200, 900)
			db.height = P.Clamp(h, 80, 600)
		end,
	})
	if ChatFrame1.SetUserPlaced then
		ChatFrame1:SetUserPlaced(true)
	end
	P.OnApply(function()
		ApplyAlpha()
		ApplySize()
		for i = 1, (NUM_CHAT_WINDOWS or 7) do
			local chat = getglobal("ChatFrame" .. i)
			if chat then
				chat:SetFont(P.FontPath(P.DB().chat.font), P.DB().chat.fontSize or 13, "")
				ApplyFade(chat)
			end
		end
		StyleEditBox()
	end)
end

P.OnInit(Init)
