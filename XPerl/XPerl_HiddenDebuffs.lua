-- Hidden buffs/debuffs on unit frames (blacklist by spell ID; UI shows names)

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
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitAura = UnitAura
local strtrim = strtrim or function(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local conf
XPerl_RequestConfig(function(new)
	conf = new
end, "$Revision: 401 $")

local FRAME_KEYS = {
	XPerl_Player = "player",
	XPerl_Target = "target",
	XPerl_TargetTarget = "targettarget",
	XPerl_Focus = "focus",
	XPerl_FocusTarget = "focustarget",
}

-- Per-list name lookups (legacy names + GetSpellInfo mirrors for ID keys)
local nameLookupBuffs = {}
local nameLookupDebuffs = {}
local nameLookupDirty = true
local nameLookupForBuffs
local nameLookupForDebuffs

local function RebuildOneLookup(dest, list)
	wipe(dest)
	if (not list) then
		return
	end
	for key in pairs(list) do
		if (type(key) == "number") then
			local name = GetSpellInfo(key)
			if (name and name ~= "") then
				dest[name] = true
			end
		elseif (type(key) == "string" and key ~= "") then
			dest[key] = true
		end
	end
end

local function RebuildNameLookups(cfg)
	RebuildOneLookup(nameLookupBuffs, cfg and cfg.buffs)
	RebuildOneLookup(nameLookupDebuffs, cfg and cfg.debuffs)
	nameLookupForBuffs = cfg and cfg.buffs
	nameLookupForDebuffs = cfg and cfg.debuffs
	nameLookupDirty = false
end

local function EnsureNameLookups(cfg)
	if (nameLookupDirty
		or nameLookupForBuffs ~= (cfg and cfg.buffs)
		or nameLookupForDebuffs ~= (cfg and cfg.debuffs)) then
		RebuildNameLookups(cfg)
	end
end

local function GetAuraList(cfg, isDebuff)
	if (isDebuff) then
		return cfg.debuffs
	end
	return cfg.buffs
end

local function GetNameLookup(isDebuff)
	if (isDebuff) then
		return nameLookupDebuffs
	end
	return nameLookupBuffs
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
		buffs = {},
		debuffs = {},
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
	if (not cfg.buffs) then
		cfg.buffs = {}
		nameLookupDirty = true
	end
	if (not cfg.debuffs) then
		cfg.debuffs = {}
		nameLookupDirty = true
	end
	-- Migrate legacy single list -> debuffs
	if (cfg.list) then
		for key, val in pairs(cfg.list) do
			if (val and cfg.debuffs[key] == nil) then
				cfg.debuffs[key] = true
			end
		end
		cfg.list = nil
		nameLookupDirty = true
	end
	EnsureNameLookups(cfg)
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

-- Resolve spellId from UnitBuff/UnitDebuff/UnitAura (11th return when client provides it).
function XPerl_HiddenDebuffs_GetAuraSpellId(unit, index, filter, isDebuff)
	if (not unit or not index or index < 1) then
		return
	end
	local id
	if (isDebuff) then
		id = select(11, UnitDebuff(unit, index, filter))
	else
		id = select(11, UnitBuff(unit, index, filter))
	end
	if (type(id) == "number" and id > 0) then
		return id
	end
	if (UnitAura) then
		local auraFilter = isDebuff and "HARMFUL" or "HELPFUL"
		if (filter and filter ~= "") then
			auraFilter = auraFilter.."|"..filter
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
	if (asNumber and asNumber > 0 and strmatch(text, "^%s*%d+%s*$")) then
		return asNumber
	end
end

-- Returns key (number spellId or string name), displayName. Nil key = reject.
function XPerl_HiddenDebuffs_ResolveManual(text)
	text = strtrim(text or "")
	if (text == "") then
		return
	end

	local linkId = strmatch(text, "spell:(%d+)")
	if (linkId) then
		local id = tonumber(linkId)
		if (not id or id <= 0) then
			return
		end
		local name = GetSpellInfo(id)
		if (not name or name == "") then
			return
		end
		return id, name
	end

	if (strmatch(text, "^%s*%d+%s*$")) then
		local id = tonumber(text)
		if (not id or id <= 0) then
			return
		end
		local name = GetSpellInfo(id)
		if (not name or name == "") then
			return
		end
		return id, name
	end

	local known = GetSpellInfo(text)
	if (known and known ~= "") then
		return known, known
	end
	return text, text
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

-- isDebuff: true = debuff list, false = buff list
function XPerl_HiddenDebuffs_ShouldHide(unitFrame, auraName, spellId, isDebuff)
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

	local list = GetAuraList(cfg, isDebuff)
	if (type(spellId) == "number" and spellId > 0 and list[spellId]) then
		return true
	end

	local lookup = GetNameLookup(isDebuff)
	if (auraName and auraName ~= "" and lookup[auraName]) then
		return true
	end

	return false
end

-- Sorted rows for UI: { key, name }
function XPerl_HiddenDebuffs_GetSortedList(isDebuff)
	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	local list = GetAuraList(cfg, isDebuff)
	local rows = {}
	for key in pairs(list) do
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

-- isDebuff defaults to true for manual add (legacy)
function XPerl_HiddenDebuffs_Add(spellIdOrText, displayName, isDebuff)
	if (isDebuff == nil) then
		isDebuff = true
	end

	local key, shown
	if (type(spellIdOrText) == "number") then
		key = spellIdOrText
		if (not key or key <= 0 or not GetSpellInfo(key)) then
			return false
		end
		shown = XPerl_HiddenDebuffs_DisplayName(key, displayName)
	else
		key, shown = XPerl_HiddenDebuffs_ResolveManual(spellIdOrText)
		if (displayName and displayName ~= "") then
			shown = displayName
		end
	end
	if (key == nil or key == "") then
		return false
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	local list = GetAuraList(cfg, isDebuff)
	if (list[key]) then
		return false
	end
	list[key] = true
	nameLookupDirty = true
	RebuildNameLookups(cfg)

	shown = shown or XPerl_HiddenDebuffs_DisplayName(key, displayName)
	local msg
	if (isDebuff) then
		msg = _G.XPERL_CONF_HIDENDEBUFFS_ADDED
	else
		msg = _G.XPERL_CONF_HIDENDEBUFFS_ADDED_BUFF
	end
	if (msg) then
		DEFAULT_CHAT_FRAME:AddMessage(format(msg, shown), 0.3, 1, 0.3)
	else
		DEFAULT_CHAT_FRAME:AddMessage(format("[XPerl] Hidden %s: %s", isDebuff and "debuff" or "buff", shown), 0.3, 1, 0.3)
	end

	if (XPerl_Options_HiddenDebuffs_FillList) then
		XPerl_Options_HiddenDebuffs_FillList()
	end

	XPerl_HiddenDebuffs_OnOptionClick()
	return true
end

function XPerl_HiddenDebuffs_Remove(key, isDebuff)
	if (key == nil or key == "") then
		return false
	end
	if (isDebuff == nil) then
		isDebuff = true
	end
	if (type(key) == "string") then
		local asId = tonumber(key)
		if (asId) then
			key = asId
		end
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	local list = GetAuraList(cfg, isDebuff)
	if (not list[key]) then
		return false
	end

	list[key] = nil
	nameLookupDirty = true
	RebuildNameLookups(cfg)

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

	-- Player buffs use XPerl_PlayerBuffs counts/cooldown override
	if (unitFrame == XPerl_Player and XPerlDB and XPerlDB.player and XPerlDB.player.buffs and XPerlDB.player.buffs.enable) then
		local pconf = XPerlDB.player
		if (XPerl_Player_Buffs_PushCooldownConfig) then
			XPerl_Player_Buffs_PushCooldownConfig()
		end
		XPerl_Unit_UpdateBuffs(unitFrame, pconf.buffs.count, pconf.buffs.count, 0, 0)
		if (XPerl_Player_Buffs_PopCooldownConfig) then
			XPerl_Player_Buffs_PopCooldownConfig()
		end
		if (XPerl_Player_Buffs_Position) then
			XPerl_Player_Buffs_Position(unitFrame)
		end
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

local function HiddenDebuffsFindUnitFrame(button)
	if (button.xperlUnitFrame and button.xperlUnitFrame.partyid) then
		return button.xperlUnitFrame
	end
	-- Player debuffs sit on debuffFrame under buffFrame; walk up until partyid
	local f = button:GetParent()
	while (f) do
		if (f.partyid) then
			return f
		end
		f = f:GetParent()
	end
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

	local unitFrame = HiddenDebuffsFindUnitFrame(button)
	if (not unitFrame or not unitFrame.partyid) then
		return false
	end

	local isDebuff = button.xperlIsDebuff and true or false
	local partyid = unitFrame.partyid
	local index = button:GetID()
	local filter = button.filter
	local name = isDebuff and button.debuffName or button.buffName
	local spellId = isDebuff and button.debuffSpellId or button.buffSpellId

	if ((not spellId or spellId <= 0) and index and index >= 1) then
		spellId = XPerl_HiddenDebuffs_GetAuraSpellId(partyid, index, filter, isDebuff)
	end
	if (not name and index and index >= 1) then
		if (isDebuff and XPerl_UnitDebuff) then
			name = XPerl_UnitDebuff(partyid, index, filter)
		elseif ((not isDebuff) and XPerl_UnitBuff) then
			name = XPerl_UnitBuff(partyid, index, filter)
		end
	end

	if (not spellId or spellId <= 0) then
		return true
	end

	if (XPerl_HiddenDebuffs_Add(spellId, name, isDebuff)) then
		XPerl_HiddenDebuffs_RefreshUnitFrame(unitFrame)
	end

	return true
end
