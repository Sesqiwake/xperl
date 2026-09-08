-- Hidden debuffs on unit frames (blacklist by spell ID; UI shows names)

local format = format
local tinsert = tinsert
local sort = sort
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local wipe = wipe
local strmatch = strmatch
local GetSpellInfo = GetSpellInfo
local UnitDebuff = UnitDebuff
local UnitAura = UnitAura
local strtrim = strtrim or function(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local FRAME_KEYS = {
	XPerl_Player = "player",
	XPerl_Target = "target",
	XPerl_TargetTarget = "targettarget",
	XPerl_Focus = "focus",
	XPerl_FocusTarget = "focustarget",
}

-- name -> true for numeric IDs in list (fast ShouldHide when aura has no spellId)
local nameLookup = {}
local nameLookupDirty = true
local nameLookupForList

local function RebuildNameLookup(cfg)
	wipe(nameLookup)
	nameLookupForList = cfg and cfg.list
	if (not cfg or not cfg.list) then
		nameLookupDirty = false
		return
	end
	for key in pairs(cfg.list) do
		if (type(key) == "number") then
			local name = GetSpellInfo(key)
			if (name and name ~= "") then
				nameLookup[name] = true
			end
		elseif (type(key) == "string" and key ~= "") then
			-- legacy name-keyed entries from older configs
			nameLookup[key] = true
		end
	end
	nameLookupDirty = false
end

local function EnsureNameLookup(cfg)
	if (nameLookupDirty or nameLookupForList ~= (cfg and cfg.list)) then
		RebuildNameLookup(cfg)
	end
end

function XPerl_HiddenDebuffs_Defaults()
	return {
		enable = true,
		player = true,
		party = true,
		target = true,
		targettarget = true,
		focus = true,
		focustarget = true,
		list = {},
	}
end

function XPerl_HiddenDebuffs_EnsureConfig(db)
	if (not db) then
		return XPerl_HiddenDebuffs_Defaults()
	end
	if (not db.hiddenDebuffs) then
		db.hiddenDebuffs = XPerl_HiddenDebuffs_Defaults()
		nameLookupDirty = true
	end
	local cfg = db.hiddenDebuffs
	if (not cfg.list) then
		cfg.list = {}
		nameLookupDirty = true
	end
	EnsureNameLookup(cfg)
	return cfg
end

function XPerl_HiddenDebuffs_GetFrameKey(unitFrame)
	if (not unitFrame) then
		return
	end
	local name = unitFrame:GetName()
	if (FRAME_KEYS[name]) then
		return FRAME_KEYS[name]
	end
	if (name and string.sub(name, 1, 11) == "XPerl_party") then
		return "party"
	end
end

-- Resolve spellId from UnitDebuff / UnitAura (11th return on Sirus / later clients).
function XPerl_HiddenDebuffs_GetAuraSpellId(unit, index, filter)
	if (not unit or not index or index < 1) then
		return
	end
	local id = select(11, UnitDebuff(unit, index, filter))
	if (type(id) == "number" and id > 0) then
		return id
	end
	if (UnitAura) then
		local auraFilter = "HARMFUL"
		if (filter and filter ~= "") then
			auraFilter = "HARMFUL|"..filter
		end
		id = select(11, UnitAura(unit, index, auraFilter))
		if (type(id) == "number" and id > 0) then
			return id
		end
	end
end

function XPerl_HiddenDebuffs_ParseInput(text)
	text = strtrim(text or "")
	if (text == "") then
		return
	end
	local linkId = strmatch(text, "spell:(%d+)")
	if (linkId) then
		return tonumber(linkId)
	end
	local asNumber = tonumber(text)
	if (asNumber and asNumber > 0) then
		return asNumber
	end
end

function XPerl_HiddenDebuffs_DisplayName(spellId, fallbackName)
	if (type(spellId) == "number") then
		local name = GetSpellInfo(spellId)
		if (name and name ~= "") then
			return name
		end
		return fallbackName or ("#"..tostring(spellId))
	end
	if (type(spellId) == "string" and spellId ~= "") then
		return spellId
	end
	return fallbackName or "?"
end

function XPerl_HiddenDebuffs_ShouldHide(unitFrame, debuffName, spellId)
	if (not XPerlDB) then
		return false
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	if (not cfg.enable) then
		return false
	end

	local frameKey = XPerl_HiddenDebuffs_GetFrameKey(unitFrame)
	if (not frameKey or not cfg[frameKey]) then
		return false
	end

	if (type(spellId) == "number" and spellId > 0 and cfg.list[spellId]) then
		return true
	end

	-- Legacy name keys, or ID list mirrored into nameLookup for clients without aura spellId
	if (debuffName and debuffName ~= "" and nameLookup[debuffName]) then
		return true
	end

	return false
end

-- Sorted rows for UI: { key = spellId|legacyName, name = displayName }
function XPerl_HiddenDebuffs_GetSortedList()
	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	local rows = {}
	for key in pairs(cfg.list) do
		if ((type(key) == "number" and key > 0) or (type(key) == "string" and key ~= "")) then
			tinsert(rows, {
				key = key,
				name = XPerl_HiddenDebuffs_DisplayName(key),
			})
		end
	end
	sort(rows, function(a, b)
		if (a.name == b.name) then
			return tostring(a.key) < tostring(b.key)
		end
		return a.name < b.name
	end)
	return rows
end

function XPerl_HiddenDebuffs_Add(spellIdOrText, displayName)
	local spellId = spellIdOrText
	if (type(spellId) ~= "number") then
		spellId = XPerl_HiddenDebuffs_ParseInput(spellIdOrText)
	end
	if (not spellId or spellId <= 0) then
		return false
	end
	spellId = tonumber(spellId)

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	if (cfg.list[spellId]) then
		return false
	end
	cfg.list[spellId] = true
	nameLookupDirty = true
	RebuildNameLookup(cfg)

	local shown = XPerl_HiddenDebuffs_DisplayName(spellId, displayName)
	local msg = _G.XPERL_CONF_HIDENDEBUFFS_ADDED
	if (msg) then
		DEFAULT_CHAT_FRAME:AddMessage(format(msg, shown), 0.3, 1, 0.3)
	else
		DEFAULT_CHAT_FRAME:AddMessage(format("[XPerl] Hidden debuff: %s", shown), 0.3, 1, 0.3)
	end

	if (XPerl_Options_HiddenDebuffs_FillList) then
		XPerl_Options_HiddenDebuffs_FillList()
	end

	XPerl_HiddenDebuffs_OnOptionClick()
	return true
end

function XPerl_HiddenDebuffs_Remove(key)
	if (key == nil or key == "") then
		return false
	end
	if (type(key) == "string") then
		local asId = tonumber(key)
		if (asId) then
			key = asId
		end
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	if (not cfg.list[key]) then
		return false
	end

	cfg.list[key] = nil
	nameLookupDirty = true
	RebuildNameLookup(cfg)

	if (XPerl_Options_HiddenDebuffs_FillList) then
		XPerl_Options_HiddenDebuffs_FillList()
	end

	XPerl_HiddenDebuffs_OnOptionClick()
	return true
end

local REFRESH_BUFF_FRAMES = {
	XPerl_Target = true,
	XPerl_TargetTarget = true,
	XPerl_Focus = true,
	XPerl_FocusTarget = true,
}

function XPerl_HiddenDebuffs_RefreshUnitFrame(unitFrame)
	if (not unitFrame or not unitFrame.partyid or not unitFrame.conf) then
		return
	end

	local frameName = unitFrame:GetName()
	if (frameName and REFRESH_BUFF_FRAMES[frameName] and XPerl_Targets_BuffUpdate) then
		XPerl_Targets_BuffUpdate(unitFrame)
		return
	end

	if (not unitFrame.buffFrame) then
		return
	end

	if (XPerl_Unit_UpdateBuffs) then
		XPerl_Unit_UpdateBuffs(unitFrame, nil, nil, unitFrame.conf.buffs and unitFrame.conf.buffs.castable, unitFrame.conf.debuffs and unitFrame.conf.debuffs.curable)
	end
end

function XPerl_HiddenDebuffs_RefreshAll()
	local frames = {
		XPerl_Player, XPerl_Target, XPerl_TargetTarget, XPerl_Focus, XPerl_FocusTarget,
	}
	for i = 1, #frames do
		XPerl_HiddenDebuffs_RefreshUnitFrame(frames[i])
	end
	for i = 1, 4 do
		XPerl_HiddenDebuffs_RefreshUnitFrame(_G["XPerl_party"..i])
	end
end

function XPerl_HiddenDebuffs_OnOptionClick(checkbox)
	if (checkbox and checkbox.configBase == "XPerlDB.hiddenDebuffs" and checkbox.configIndex) then
		local cfg = XPerlDB and XPerlDB.hiddenDebuffs
		if (cfg) then
			cfg[checkbox.configIndex] = checkbox:GetChecked() and true or false
		end
	end
	if (XPerl_OptionActions) then
		XPerl_OptionActions()
	end
	XPerl_HiddenDebuffs_RefreshAll()
end

function XPerl_HiddenDebuffs_HandleClick(button, mouseButton)
	if (mouseButton ~= "LeftButton") then
		return false
	end
	if (not XPerl_Options or not XPerl_Options:IsShown()) then
		return false
	end
	if (not IsControlKeyDown() or not IsShiftKeyDown()) then
		return false
	end

	local debuffFrame = button:GetParent()
	if (not debuffFrame) then
		return false
	end

	local unitFrame = debuffFrame:GetParent()
	if (not unitFrame or not unitFrame.partyid) then
		return false
	end

	local partyid = unitFrame.partyid
	local index = button:GetID()
	local filter = button.filter
	local name = button.debuffName
	local spellId = button.debuffSpellId

	-- Fallback only if the icon was drawn without spellId (old client / rare path)
	if ((not spellId or spellId <= 0) and index and index >= 1) then
		spellId = XPerl_HiddenDebuffs_GetAuraSpellId(partyid, index, filter)
	end
	if (not name and index and index >= 1 and XPerl_UnitDebuff) then
		name = XPerl_UnitDebuff(partyid, index, filter)
	end

	if (not spellId or spellId <= 0) then
		return true
	end

	if (XPerl_HiddenDebuffs_Add(spellId, name)) then
		XPerl_HiddenDebuffs_RefreshUnitFrame(unitFrame)
	end

	return true
end
