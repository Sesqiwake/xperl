-- Hidden debuffs on unit frames (blacklist by spell name)

local format = format
local tinsert = tinsert
local sort = sort
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
	end
	local cfg = db.hiddenDebuffs
	if (not cfg.list) then
		cfg.list = {}
	end
	if (cfg.enable == nil) then
		cfg.enable = true
	end
	if (cfg.player == nil) then
		cfg.player = true
	end
	if (cfg.party == nil) then
		cfg.party = true
	end
	if (cfg.target == nil) then
		cfg.target = true
	end
	if (cfg.targettarget == nil) then
		cfg.targettarget = true
	end
	if (cfg.focus == nil) then
		cfg.focus = true
	end
	if (cfg.focustarget == nil) then
		cfg.focustarget = true
	end
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

function XPerl_HiddenDebuffs_ShouldHide(unitFrame, debuffName)
	if (not debuffName or debuffName == "") then
		return false
	end
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

	return cfg.list[debuffName] and true or false
end

function XPerl_HiddenDebuffs_GetSortedList()
	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	local names = {}
	for name in pairs(cfg.list) do
		if (type(name) == "string" and name ~= "") then
			tinsert(names, name)
		end
	end
	sort(names)
	return names
end

function XPerl_HiddenDebuffs_Add(debuffName)
	debuffName = strtrim(debuffName or "")
	if (debuffName == "") then
		return false
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	cfg.list[debuffName] = true

	local msg = _G.XPERL_CONF_HIDENDEBUFFS_ADDED
	if (msg) then
		DEFAULT_CHAT_FRAME:AddMessage(format(msg, debuffName), 0.3, 1, 0.3)
	else
		DEFAULT_CHAT_FRAME:AddMessage(format("[XPerl] Hidden debuff: %s", debuffName), 0.3, 1, 0.3)
	end

	if (XPerl_Options_HiddenDebuffs_FillList) then
		XPerl_Options_HiddenDebuffs_FillList()
	end

	XPerl_OptionActions()
	return true
end

function XPerl_HiddenDebuffs_Remove(debuffName)
	if (not debuffName or debuffName == "") then
		return false
	end

	local cfg = XPerl_HiddenDebuffs_EnsureConfig(XPerlDB)
	if (not cfg.list[debuffName]) then
		return false
	end

	cfg.list[debuffName] = nil

	if (XPerl_Options_HiddenDebuffs_FillList) then
		XPerl_Options_HiddenDebuffs_FillList()
	end

	XPerl_OptionActions()
	return true
end

function XPerl_HiddenDebuffs_RefreshUnitFrame(unitFrame)
	if (not unitFrame or not unitFrame.partyid or not unitFrame.conf) then
		return
	end
	if (XPerl_Unit_UpdateBuffs) then
		XPerl_Unit_UpdateBuffs(unitFrame, nil, nil, unitFrame.conf.buffs and unitFrame.conf.buffs.castable, unitFrame.conf.debuffs and unitFrame.conf.debuffs.curable)
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

	local debuffFrame = button:GetParent()
	if (not debuffFrame) then
		return false
	end

	local unitFrame = debuffFrame:GetParent()
	if (not unitFrame or not unitFrame.partyid) then
		return false
	end

	local name = button.debuffName
	if (not name) then
		local partyid = unitFrame.partyid
		local index = button:GetID()
		if (not index or index < 1) then
			return false
		end
		name = XPerl_UnitDebuff(partyid, index, button.filter)
	end
	if (not name or name == "") then
		return false
	end

	if (XPerl_HiddenDebuffs_Add(name)) then
		XPerl_HiddenDebuffs_RefreshUnitFrame(unitFrame)
	end

	return true
end

