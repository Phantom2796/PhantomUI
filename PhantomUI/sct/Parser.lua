-- CompactSCT: liest die eigenen Treffer aus dem 1.12-Kampflog.
-- Die Suchmuster werden aus den Texten des Clients selbst gebaut (GlobalStrings),
-- damit sie auch bei anderer Sprache oder anderer Argument-Reihenfolge passen.

CompactSCT = CompactSCT or {}

local patterns = {}

local function Escape(c)
	if string.find(c, "[%^%$%(%)%.%[%]%*%-%+%?]") then
		return "%" .. c
	end
	return c
end

-- Baut aus z. B. "Your %s hits %s for %d." ein Lua-Muster mit Captures.
local function Compile(globalName)
	local cached = patterns[globalName]
	if cached ~= nil then
		return cached
	end
	local fmt = getglobal(globalName)
	if type(fmt) ~= "string" or fmt == "" then
		patterns[globalName] = false
		return false
	end

	local search = "^"
	local map = {}
	local count = 0
	local i = 1
	local len = string.len(fmt)
	while i <= len do
		local c = string.sub(fmt, i, i)
		if c ~= "%" then
			search = search .. Escape(c)
			i = i + 1
		elseif string.sub(fmt, i + 1, i + 1) == "%" then
			search = search .. "%%"
			i = i + 2
		else
			local j = i + 1
			local code = ""
			local kind
			while j <= len do
				local ch = string.sub(fmt, j, j)
				code = code .. ch
				if string.find(ch, "[cdEefgGiosuxX]") then
					kind = ch
					break
				end
				j = j + 1
			end
			if not kind then
				search = search .. "%%"
				i = i + 1
			else
				count = count + 1
				local _, _, pos = string.find(code, "^(%d+)%$")
				map[pos and tonumber(pos) or count] = count
				if kind == "d" then
					search = search .. "(%d+)"
				else
					search = search .. "(.-)"
				end
				i = j + 1
			end
		end
	end
	search = search .. "$"

	local p = { search = search, map = map }
	patterns[globalName] = p
	return p
end

-- fields: Namen der Format-Argumente in ihrer Reihenfolge im englischen Original.
local function Capture(message, globalName, fields)
	local p = Compile(globalName)
	if not p then
		return nil
	end
	local s, _, c1, c2, c3, c4, c5, c6 = string.find(message, p.search)
	if not s then
		return nil
	end
	local caps = { c1, c2, c3, c4, c5, c6 }
	local result = {}
	for n = 1, table.getn(fields) do
		local value = caps[p.map[n] or n]
		if fields[n] == "amount" then
			value = tonumber(value)
		end
		result[fields[n]] = value
	end
	return result
end

local SCHOOLS = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }

local function School(localized)
	if not localized or localized == "" then
		return "Physical"
	end
	for n = 1, 7 do
		local name = getglobal("SPELL_SCHOOL" .. (n - 1) .. "_CAP")
		if name and string.lower(name) == string.lower(localized) then
			return SCHOOLS[n]
		end
	end
	-- Englischer Client ohne die Globals: Gross-/Kleinschreibung angleichen.
	local lower = string.lower(localized)
	for n = 1, 7 do
		if string.lower(SCHOOLS[n]) == lower then
			return SCHOOLS[n]
		end
	end
	return "Physical"
end

local function Hit(data, kind, crit, school)
	if not data or not data.amount or data.amount <= 0 or not data.target or data.target == "" then
		return nil
	end
	data.kind = kind
	data.crit = crit
	data.school = School(school or data.school)
	return data
end

local function IsMine(name)
	if not name then
		return false
	end
	return name == UnitName("player") or (UnitExists("pet") and name == UnitName("pet"))
end

-- Nahkampf (eigene Treffer)
local function SelfMelee(msg)
	local d = Capture(msg, "COMBATHITCRITSCHOOLSELFOTHER", { "target", "amount", "school" })
	if d then return Hit(d, "melee", true) end
	d = Capture(msg, "COMBATHITSCHOOLSELFOTHER", { "target", "amount", "school" })
	if d then return Hit(d, "melee", false) end
	d = Capture(msg, "COMBATHITCRITSELFOTHER", { "target", "amount" })
	if d then return Hit(d, "melee", true, "Physical") end
	d = Capture(msg, "COMBATHITSELFOTHER", { "target", "amount" })
	if d then return Hit(d, "melee", false, "Physical") end
	return nil
end

-- Zauber und Faehigkeiten (eigene)
local function SelfSpell(msg)
	local d = Capture(msg, "SPELLLOGCRITSCHOOLSELFOTHER", { "spell", "target", "amount", "school" })
	if d then return Hit(d, "spell", true) end
	d = Capture(msg, "SPELLLOGSCHOOLSELFOTHER", { "spell", "target", "amount", "school" })
	if d then return Hit(d, "spell", false) end
	d = Capture(msg, "SPELLLOGCRITSELFOTHER", { "spell", "target", "amount" })
	if d then return Hit(d, "spell", true, "Physical") end
	d = Capture(msg, "SPELLLOGSELFOTHER", { "spell", "target", "amount" })
	if d then return Hit(d, "spell", false, "Physical") end
	return nil
end

-- Begleiter (Pet, Totem, Diener): Saetze mit Quelle vorne.
local function PetMelee(msg)
	local d = Capture(msg, "COMBATHITCRITSCHOOLOTHEROTHER", { "source", "target", "amount", "school" })
	if d then return Hit(d, "pet", true) end
	d = Capture(msg, "COMBATHITSCHOOLOTHEROTHER", { "source", "target", "amount", "school" })
	if d then return Hit(d, "pet", false) end
	d = Capture(msg, "COMBATHITCRITOTHEROTHER", { "source", "target", "amount" })
	if d then return Hit(d, "pet", true, "Physical") end
	d = Capture(msg, "COMBATHITOTHEROTHER", { "source", "target", "amount" })
	if d then return Hit(d, "pet", false, "Physical") end
	return nil
end

local function PetSpell(msg)
	local d = Capture(msg, "SPELLLOGCRITSCHOOLOTHEROTHER", { "source", "spell", "target", "amount", "school" })
	if d then return Hit(d, "spell", true) end
	d = Capture(msg, "SPELLLOGSCHOOLOTHEROTHER", { "source", "spell", "target", "amount", "school" })
	if d then return Hit(d, "spell", false) end
	d = Capture(msg, "SPELLLOGCRITOTHEROTHER", { "source", "spell", "target", "amount" })
	if d then return Hit(d, "spell", true, "Physical") end
	d = Capture(msg, "SPELLLOGOTHEROTHER", { "source", "spell", "target", "amount" })
	if d then return Hit(d, "spell", false, "Physical") end
	return nil
end

-- Schaden ueber Zeit: der Satz beschreibt das Opfer, also Quelle pruefen.
local function Periodic(msg)
	local d = Capture(msg, "PERIODICAURADAMAGESELFOTHER", { "target", "amount", "school", "spell" })
	if d then return Hit(d, "dot", false) end
	d = Capture(msg, "PERIODICAURADAMAGEOTHEROTHER", { "target", "amount", "school", "source", "spell" })
	if d and IsMine(d.source) then return Hit(d, "dot", false) end
	return nil
end

-- Dornen, Blitzschlagschild und Co.
local function Shield(msg)
	local d = Capture(msg, "DAMAGESHIELDSELFOTHER", { "amount", "school", "target" })
	if d then return Hit(d, "shield", false) end
	d = Capture(msg, "DAMAGESHIELDOTHEROTHER", { "source", "amount", "school", "target" })
	if d and IsMine(d.source) then return Hit(d, "shield", false) end
	return nil
end

CompactSCT.Handlers = {
	CHAT_MSG_COMBAT_SELF_HITS = SelfMelee,
	CHAT_MSG_SPELL_SELF_DAMAGE = SelfSpell,
	CHAT_MSG_COMBAT_PET_HITS = PetMelee,
	CHAT_MSG_SPELL_PET_DAMAGE = PetSpell,
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = Periodic,
	CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE = Periodic,
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = Shield,
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS = Shield,
}

function CompactSCT.Parse(eventName, message)
	if type(message) ~= "string" or message == "" then
		return nil
	end
	local handler = CompactSCT.Handlers[eventName]
	if handler then
		return handler(message)
	end
	return nil
end
