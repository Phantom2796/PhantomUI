-- PhantomUI: Schadensmeter in die Ankerpunkte einhaengen. Der Meter merkt sich
-- seinen Platz selbst; PhantomUI verschiebt ihn nur und laesst ihn dann speichern.

local P = PhantomUI

P.OnInit(function()
	local frame = getglobal("AZSSpellMeterFrame")
	if not frame or not AZSSpellMeter_SavePoint then
		return
	end
	P.RegisterMover("meter", frame, "Schadensmeter", function()
		SlashCmdList.AZSSPELLMETER("resetpos")
	end, nil, { save = AZSSpellMeter_SavePoint })
end)
