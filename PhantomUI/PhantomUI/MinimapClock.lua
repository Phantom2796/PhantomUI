-- PhantomUI: eigene Uhr innen in der Minimap (unten mittig, schwarzer Hintergrund)
-- Spieluhr unter der Minimap dafür aus (AS 0.136: AZS_SetHudShown "localClock")

local P = PhantomUI

local function Init()
	local db = P.DB().minimap
	if db.clock == false then
		-- eigene Uhr aus -> Spieluhr wieder an
		if type(AZS_SetHudShown) == "function" then
			pcall(AZS_SetHudShown, "localClock", true)
		end
		return
	end
	-- Spieluhr unter der Minimap weg
	if type(AZS_SetHudShown) == "function" then
		pcall(AZS_SetHudShown, "localClock", false)
	end
	local f = CreateFrame("Frame", "PhantomUI_MinimapClock", Minimap)
	f:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	f:SetHeight(14)
	f:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 3)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(P.FLAT)
	f.bg:SetVertexColor(0, 0, 0, 0.8)
	f.bg:SetAllPoints(f)
	f.text = f:CreateFontString(nil, "OVERLAY")
	f.text:SetFont(P.Font(), 11, "OUTLINE")
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetTextColor(1, 1, 1)
	local t = 1
	f:SetScript("OnUpdate", function()
		t = t + arg1
		if t < 1 then
			return
		end
		t = 0
		local txt
		if type(AZS_GetLocalTime) == "function" then
			local lt = AZS_GetLocalTime()
			txt = lt and lt.text
		end
		if not txt and date then
			txt = date("%H:%M")
		end
		txt = txt or ""
		if txt ~= this.last then
			this.last = txt
			this.text:SetText(txt)
			this:SetWidth(this.text:GetStringWidth() + 10)
		end
	end)
end

P.OnInit(Init)
