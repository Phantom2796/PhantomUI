-- PhantomUI: kleines Spielmenue (Escape) im Phantom-Stil und Knoepfe fuer
-- Charakter, Talente und Menue an der Minimap (statt des Mikromenues).

local P = PhantomUI

local L = {
	enUS = { resume = "Resume", options = "Options", ui = "PhantomUI", quit = "Exit game", character = "Character", talents = "Talents", menu = "Game menu" },
	deDE = { resume = "Weiterspielen", options = "Optionen", ui = "PhantomUI", quit = "Spiel beenden", character = "Charakter", talents = "Talente", menu = "Spielmenü" },
}
local function T(key)
	local lang = PhantomUI_Lang and PhantomUI_Lang() or "enUS"
	return (L[lang] or L.enUS)[key] or L.enUS[key]
end

local menu

local function Button(label, y, onClick)
	local b = CreateFrame("Button", nil, menu)
	b:SetWidth(170)
	b:SetHeight(26)
	b:SetPoint("TOP", menu, "TOP", 0, y)
	b:SetBackdrop({ bgFile = P.FLAT, edgeFile = P.FLAT, edgeSize = 1 })
	b:SetBackdropColor(0.12, 0.06, 0.18, 1)
	b:SetBackdropBorderColor(0.4, 0.2, 0.6, 1)
	b.text = b:CreateFontString(nil, "OVERLAY")
	b.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetTextColor(0.85, 0.75, 1)
	b.label = label
	b:SetScript("OnEnter", function() this:SetBackdropBorderColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3], 1) end)
	b:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.2, 0.6, 1) end)
	b:SetScript("OnClick", onClick)
	return b
end

local buttons = {}

local function BuildMenu()
	menu = CreateFrame("Frame", "PhantomUI_GameMenu", UIParent)
	menu:SetWidth(210)
	menu:SetFrameStrata("DIALOG")
	menu:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	P.Box(menu, 0.97)
	menu:EnableMouse(true)
	local title = menu:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
	title:SetTextColor(P.ACCENT[1] + 0.15, P.ACCENT[2] + 0.15, P.ACCENT[3])
	title:SetPoint("TOP", menu, "TOP", 0, -12)
	title:SetText("Azeroth Survivors")
	local y = -38
	table.insert(buttons, Button("resume", y, function() menu:Hide() end))
	y = y - 30
	local optionsFrame = BenillaOptionsFrame or OptionsFrame
	if optionsFrame then
		table.insert(buttons, Button("options", y, function()
			menu:Hide()
			ShowUIPanel(optionsFrame)
		end))
		y = y - 30
	end
	table.insert(buttons, Button("ui", y, function()
		menu:Hide()
		P.ShowOptions()
	end))
	y = y - 30
	table.insert(buttons, Button("quit", y, function() Quit() end))
	y = y - 30
	menu:SetHeight(-y + 10)
	menu:SetScript("OnShow", function()
		for i = 1, table.getn(buttons) do
			buttons[i].text:SetText(T(buttons[i].label))
		end
	end)
	menu:Hide()
end

local function CloseOptions()
	local o = BenillaOptionsFrame
	if o and o:IsShown() then
		if BenillaOptionsFrameCloseButton then
			BenillaOptionsFrameCloseButton:Click()
		else
			HideUIPanel(o)
		end
		return true
	end
	if OptionsFrame and OptionsFrame:IsShown() then
		HideUIPanel(OptionsFrame)
		return true
	end
	return false
end

local function Init()
	if not P.DB().menu.enabled or DFRL then
		-- Mit SurvivorsDragonUi bleibt dessen Menue.
		return
	end
	BuildMenu()
	if GameMenuFrame then
		GameMenuFrame:Hide()
		GameMenuFrame.Show = function() end
	end
	ToggleGameMenu = function(clicked)
		if clicked then
			CloseOptions()
			if menu:IsShown() then
				menu:Hide()
			else
				CloseMenus()
				CloseAllWindows()
				menu:Show()
			end
			return
		end
		if StaticPopup_EscapePressed and StaticPopup_EscapePressed() then return end
		if CloseOptions() then return end
		if menu:IsShown() then
			menu:Hide()
			return
		end
		if CloseMenus and CloseMenus() then return end
		if SpellStopCasting and SpellStopCasting() then return end
		if SpellStopTargeting and SpellStopTargeting() then return end
		if CloseAllWindows and CloseAllWindows() then return end
		if UnitExists("target") then
			ClearTarget()
		else
			menu:Show()
		end
	end
end

P.OnInit(Init)

-- Knoepfe an der Minimap (sie ersetzen das Mikromenue des Spiels)
P.OnInit(function()
	P.AddMinimapButton({
		title = "Charakter / Character",
		icon = "Interface\\Icons\\INV_Chest_Plate04",
		left = function()
			if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
		end,
		leftText = "Charakterfenster",
	})
	P.AddMinimapButton({
		title = "Spielmenü / Game menu",
		icon = "Interface\\Icons\\INV_Misc_Gear_01",
		left = function() ToggleGameMenu(true) end,
		leftText = "Menü",
	})
end)
