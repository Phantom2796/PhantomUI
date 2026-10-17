-- PhantomUI: Gold- und Kistenanzeige im Phantom-Stil. Ersetzt die goldene Leiste
-- von SurvivorsDragonUi; die Werte kommen aus AZS_RUN (gold, chest).

local P = PhantomUI

local FIELDS = {
	{ key = "gold", icon = "Interface\\Icons\\INV_Misc_Coin_01", tip = "Gold" },
	{ key = "chest", icon = "Interface\\Icons\\INV_Box_01", tip = "Nächste Kiste kostet (Gold)" },
}

local frame
local fields = {}

local function Layout()
	local db = P.DB().tally
	frame:SetScale(db.scale)
	frame:SetWidth(db.width)
	frame:SetHeight(db.height)
	P.Box(frame, db.bgAlpha)
	local count = table.getn(fields)
	local fieldW = (db.width - 2) / count
	local iconSize = db.height - 6
	for i = 1, count do
		local f = fields[i]
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + (i - 1) * fieldW, -1)
		f:SetWidth(fieldW)
		f:SetHeight(db.height - 2)
		f.icon:SetWidth(iconSize)
		f.icon:SetHeight(iconSize)
		f.text:SetFont(P.Font(), math.max(8, db.height - 8), "OUTLINE")
		if f.divider then
			f.divider:SetHeight(db.height - 2)
		end
	end
end

local function Update()
	-- Die Werte kommen je nach Client als Zahl oder als Text.
	local run = AZS_RUN
	local ok = type(run) == "table" and tonumber(run.gold) ~= nil
	if not ok and not P.unlocked then
		frame:Hide()
		return
	end
	frame:Show()
	for i = 1, table.getn(fields) do
		local value = ok and tonumber(run[fields[i].key])
		fields[i].text:SetText(value and tostring(math.floor(value)) or "-")
	end
end

-- Die goldene Leiste von SurvivorsDragonUi stilllegen (sie zeigt sich sonst 5x pro Sekunde neu).
local function SilenceOld()
	local old = getglobal("DFRL_RunTallyPill")
	if old then
		old:Hide()
		old.Show = function() end
	end
end

local function Init()
	if not P.DB().tally.enabled then
		return
	end
	SilenceOld()
	frame = CreateFrame("Frame", "PhantomUI_Tally", UIParent)
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(true)

	for i = 1, table.getn(FIELDS) do
		local def = FIELDS[i]
		local f = CreateFrame("Frame", nil, frame)
		f:EnableMouse(true)
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetTexture(def.icon)
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icon:SetPoint("LEFT", f, "LEFT", 4, 0)
		f.text = P.Text(f, 12)
		f.text:SetPoint("CENTER", f, "CENTER", 6, 0)
		if i > 1 then
			f.divider = f:CreateTexture(nil, "OVERLAY")
			f.divider:SetTexture(P.FLAT)
			f.divider:SetVertexColor(0, 0, 0, 1)
			f.divider:SetWidth(1)
			f.divider:SetPoint("LEFT", f, "LEFT", 0, 0)
		end
		f.tip = def.tip
		f.key = def.key -- fehlte: ohne Schluessel blieb jedes Feld auf "-"
		f:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:SetText(this.tip)
			GameTooltip:Show()
		end)
		f:SetScript("OnLeave", function() GameTooltip:Hide() end)
		fields[i] = f
	end

	Layout()
	P.RegisterMover("tally", frame, "Gold / Kiste", function(f)
		f:SetPoint("TOP", UIParent, "BOTTOM", 0, 39)
	end, {
		scale = "tally",
		get = function()
			local db = P.DB().tally
			return db.width, db.height
		end,
		set = function(w, h)
			local db = P.DB().tally
			db.width = P.Clamp(w, 80, 400)
			db.height = P.Clamp(h, 14, 40)
		end,
	})

	local elapsed = 0
	frame:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed > 0.2 then
			elapsed = 0
			SilenceOld()
			Update()
		end
	end)
	-- Versteckter Rahmen bekommt kein OnUpdate: eigener Taktgeber.
	local ticker = CreateFrame("Frame")
	local t = 0
	ticker:SetScript("OnUpdate", function()
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
