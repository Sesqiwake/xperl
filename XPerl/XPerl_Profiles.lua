-- X-Perl Profiles: named layout + raid/party display presets (account-wide list)

local format = format
local tinsert = tinsert
local sort = sort
local pairs = pairs
local ipairs = ipairs
local type = type

local SCALE_KEYS = {
	"player", "pet", "target", "targettarget", "targettargettarget",
	"focus", "focustarget", "party", "partypet", "raid",
}

local POSITION_FRAMES = {
	"XPerl_Player", "XPerl_Player_Pet", "XPerl_Target", "XPerl_TargetTarget",
	"XPerl_TargetTargetTarget", "XPerl_Focus", "XPerl_FocusTarget",
	"XPerl_Party_Anchor",
	"XPerl_Raid_Title1", "XPerl_Raid_Title2", "XPerl_Raid_Title3", "XPerl_Raid_Title4",
	"XPerl_Raid_Title5", "XPerl_Raid_Title6", "XPerl_Raid_Title7", "XPerl_Raid_Title8",
	"XPerl_Raid_Title9", "XPerl_Raid_Title10", "XPerl_Raid_TitlePets",
	"XPerl_RaidMonitor_Anchor", "XPerl_MTList_Anchor", "XPerl_Assists_FrameAnchor",
	"XPerl_AggroAnchor", "XPerl_AdminFrameAnchor", "XPerl_CheckAnchor",
}

local profilesMigrated
local PROFILE_ROW_COUNT = 9
local PROFILE_ROW_PREFIX = "XPerl_Options_Profiles_List"

local function GetProfileRow(i)
	return _G[PROFILE_ROW_PREFIX..i]
end

local function ProfileMsg(key, fallback)
	local msg = _G[key]
	if (msg) then
		return msg
	end
	return fallback
end

local function CopyTable(src)
	if (XPerl_CopyTable) then
		return XPerl_CopyTable(src)
	end
	local dest = {}
	for k, v in pairs(src) do
		if (type(v) == "table") then
			dest[k] = CopyTable(v)
		else
			dest[k] = v
		end
	end
	return dest
end

local function GetRealmPlayer()
	return GetRealmName(), UnitName("player")
end

local function IsValidSnapshot(snap)
	return type(snap) == "table" and type(snap.positions) == "table"
end

local function SanitizeProfileList(list)
	if (type(list) ~= "table") then
		return {}
	end
	local clean = {}
	for name, snap in pairs(list) do
		if (type(name) == "string" and name ~= "" and name ~= "Line" and IsValidSnapshot(snap)) then
			clean[name] = snap
		end
	end
	return clean
end

local function ImportLegacyStore(merged, chars, root)
	for realm, realmData in pairs(root) do
		if (realm ~= "list" and realm ~= "chars" and type(realmData) == "table") then
			for player, playerData in pairs(realmData) do
				if (type(playerData) == "table") then
					if (type(playerData.list) == "table") then
						for name, snap in pairs(playerData.list) do
							if (type(name) == "string" and IsValidSnapshot(snap) and not merged[name]) then
								merged[name] = snap
							end
						end
					end
					if (not chars[realm]) then
						chars[realm] = {}
					end
					if (not chars[realm][player]) then
						chars[realm][player] = {}
					end
					if (playerData.active) then
						chars[realm][player].active = playerData.active
					end
					if (playerData.autoApply) then
						chars[realm][player].autoApply = playerData.autoApply
					end
				end
			end
		end
	end
end

local function MigrateProfiles()
	if (profilesMigrated or not XPerlConfigNew) then
		return
	end
	profilesMigrated = true

	local root = XPerlConfigNew.profiles
	if (not root) then
		XPerlConfigNew.profiles = {list = {}, chars = {}}
		return
	end

	if (type(root.list) == "table") then
		local merged = SanitizeProfileList(root.list)
		local chars = (type(root.chars) == "table") and root.chars or {}
		ImportLegacyStore(merged, chars, root)
		XPerlConfigNew.profiles = {list = merged, chars = chars}
		return
	end

	local merged = {}
	local chars = {}
	ImportLegacyStore(merged, chars, root)
	XPerlConfigNew.profiles = {list = merged, chars = chars}
end

local function GetCharMeta(create)
	MigrateProfiles()
	local realm, player = GetRealmPlayer()
	local root = XPerlConfigNew.profiles
	if (not root.chars[realm]) then
		if (not create) then
			return
		end
		root.chars[realm] = {}
	end
	if (not root.chars[realm][player]) then
		if (not create) then
			return
		end
		root.chars[realm][player] = {}
	end
	return root.chars[realm][player]
end

function XPerl_Profiles_GetStore(create)
	if (not XPerlConfigNew) then
		return
	end

	MigrateProfiles()

	local root = XPerlConfigNew.profiles
	if (not root) then
		if (not create) then
			return
		end
		XPerlConfigNew.profiles = {list = {}, chars = {}}
		root = XPerlConfigNew.profiles
	end

	if (not root.list) then
		if (not create) then
			return
		end
		root.list = {}
	end

	root.list = SanitizeProfileList(root.list)

	if (not root.chars) then
		root.chars = {}
	end

	return root
end

function XPerl_Profiles_GetActive()
	local meta = GetCharMeta()
	return meta and meta.active
end

function XPerl_Profiles_SetActive(name)
	local meta = GetCharMeta(true)
	if (meta) then
		meta.active = name
	end
end

function XPerl_Profiles_FlushPositions()
	if (not XPerl_SavePosition) then
		return
	end

	local saved = {}
	for i = 1, #POSITION_FRAMES do
		local frame = _G[POSITION_FRAMES[i]]
		if (frame) then
			XPerl_SavePosition(frame)
			saved[POSITION_FRAMES[i]] = true
		end
	end

	if (XPerl_GetSavePositionTable) then
		local table = XPerl_GetSavePositionTable()
		if (table) then
			for frameName in pairs(table) do
				if (not saved[frameName]) then
					local frame = _G[frameName]
					if (frame) then
						XPerl_SavePosition(frame)
					end
				end
			end
		end
	end
end

local function CopyRaidGroup(group)
	local copy = {}
	for i = 1, 10 do
		if (group) then
			copy[i] = group[i]
		end
	end
	return copy
end

local function CopyRaidClass(class)
	local copy = {}
	if (not class) then
		return copy
	end
	for i = 1, 10 do
		if (class[i]) then
			copy[i] = {
				enable = class[i].enable,
				name = class[i].name,
			}
		end
	end
	return copy
end

function XPerl_Profiles_Capture()
	if (not XPerlDB) then
		return
	end

	XPerl_Profiles_FlushPositions()

	local snapshot = {
		positions = CopyTable(XPerl_GetSavePositionTable(true) or {}),
		scales = {},
		raid = {},
		party = {},
	}

	for i = 1, #SCALE_KEYS do
		local key = SCALE_KEYS[i]
		if (XPerlDB[key]) then
			snapshot.scales[key] = XPerlDB[key].scale or 1
		end
	end

	if (XPerlDB.raid) then
		snapshot.raid.scale = XPerlDB.raid.scale
		snapshot.raid.spacing = XPerlDB.raid.spacing
		snapshot.raid.anchor = XPerlDB.raid.anchor
		snapshot.raid.sortByClass = XPerlDB.raid.sortByClass or XPerlDB.sortByClass
		snapshot.raid.sortAlpha = XPerlDB.raid.sortAlpha
		snapshot.raid.group = CopyRaidGroup(XPerlDB.raid.group)
		snapshot.raid.class = CopyRaidClass(XPerlDB.raid.class)
	end

	if (XPerlDB.party) then
		snapshot.party.scale = XPerlDB.party.scale
		snapshot.party.smallRaid = XPerlDB.party.smallRaid
	end

	return snapshot
end

local function ApplyRaidGroup(target, source)
	if (not target) then
		return
	end
	if (not target.group) then
		target.group = {}
	end
	source = source or {}
	for i = 1, 10 do
		target.group[i] = source[i]
	end
end

local function ApplyRaidClass(target, source)
	if (not target or not source) then
		return
	end
	if (not target.class) then
		target.class = {}
	end
	for i = 1, 10 do
		if (source[i]) then
			if (not target.class[i]) then
				target.class[i] = {}
			end
			target.class[i].enable = source[i].enable
			if (source[i].name) then
				target.class[i].name = source[i].name
			end
		end
	end
end

local function ApplyRaidSettings(raidSnap)
	if (not raidSnap or not XPerlDB.raid) then
		return
	end

	local raid = XPerlDB.raid
	if (raidSnap.scale) then
		raid.scale = raidSnap.scale
	end
	if (raidSnap.spacing ~= nil) then
		raid.spacing = raidSnap.spacing
	end
	if (raidSnap.anchor) then
		raid.anchor = raidSnap.anchor
	end
	if (raidSnap.sortByClass ~= nil) then
		raid.sortByClass = raidSnap.sortByClass
		XPerlDB.sortByClass = raidSnap.sortByClass
	end
	if (raidSnap.sortAlpha ~= nil) then
		raid.sortAlpha = raidSnap.sortAlpha
	end
	ApplyRaidGroup(raid, raidSnap.group)
	ApplyRaidClass(raid, raidSnap.class)
end

local function RestoreProfilePositions(snapshot, realm, player)
	if (not snapshot.positions) then
		return
	end
	if (not XPerlConfigNew.savedPositions) then
		XPerlConfigNew.savedPositions = {}
	end
	if (not XPerlConfigNew.savedPositions[realm]) then
		XPerlConfigNew.savedPositions[realm] = {}
	end
	XPerlConfigNew.savedPositions[realm][player] = CopyTable(snapshot.positions)
	if (XPerl_RestoreAllPositions) then
		XPerl_RestoreAllPositions()
	end
end

local function RefreshProfileFrames(snapshot)
	if (InCombatLockdown()) then
		tinsert(XPerl_OutOfCombatQueue, function()
			RefreshProfileFrames(snapshot)
		end)
		return
	end

	if (XPerl_Raid_ChangeAttributes) then
		XPerl_Raid_ChangeAttributes()
	end
	if (XPerl_OptionActions) then
		XPerl_OptionActions()
	end
	if (snapshot.positions and XPerl_RestoreAllPositions) then
		XPerl_RestoreAllPositions()
	end
end

local function SchedulePositionFixup()
	if (not XPerl_RestoreAllPositions) then
		return
	end

	local fixup = CreateFrame("Frame")
	fixup.elapsed = 0
	fixup:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < 0.1) then
			return
		end
		self:SetScript("OnUpdate", nil)
		if (InCombatLockdown()) then
			return
		end
		XPerl_RestoreAllPositions()
		if (XPerl_Raid_HideShowRaid) then
			XPerl_Raid_HideShowRaid()
		end
		if (XPerl_ScaleRaid) then
			XPerl_ScaleRaid()
		end
	end)
end

local function DoApplyProfile(snapshot)
	if (not snapshot or not XPerlDB) then
		return
	end

	local realm, player = GetRealmPlayer()

	if (snapshot.scales) then
		for key, scale in pairs(snapshot.scales) do
			if (XPerlDB[key]) then
				XPerlDB[key].scale = scale
			end
		end
	end

	ApplyRaidSettings(snapshot.raid)

	if (snapshot.party and XPerlDB.party) then
		if (snapshot.party.scale) then
			XPerlDB.party.scale = snapshot.party.scale
		end
		if (snapshot.party.smallRaid ~= nil) then
			XPerlDB.party.smallRaid = snapshot.party.smallRaid
		end
	end

	if (XPerl_GiveConfig) then
		XPerl_GiveConfig()
	end

	if (XPerl_ScaleRaid) then
		XPerl_ScaleRaid()
	end

	RestoreProfilePositions(snapshot, realm, player)
	RefreshProfileFrames(snapshot)

	if (snapshot.positions) then
		SchedulePositionFixup()
	end
end

function XPerl_Profiles_Apply(name)
	local store = XPerl_Profiles_GetStore()
	if (not store or not name or name == "") then
		return
	end

	local snapshot = store.list[name]
	if (not snapshot) then
		if (XPerl_Notice) then
			XPerl_Notice(format(ProfileMsg("XPERL_CONF_PROFILES_NOT_FOUND", "Profile not found: %s"), name))
		end
		return
	end

	if (InCombatLockdown()) then
		tinsert(XPerl_OutOfCombatQueue, function()
			DoApplyProfile(snapshot)
		end)
	else
		DoApplyProfile(snapshot)
	end

	XPerl_Profiles_SetActive(name)
	if (XPerl_Notice) then
		XPerl_Notice(format(ProfileMsg("XPERL_CONF_PROFILES_APPLIED", "Profile applied: %s"), name))
	end
end

function XPerl_Profiles_Save(name)
	name = (name or ""):match("^%s*(.-)%s*$")
	if (not name or name == "" or name == "Line") then
		return
	end

	local store = XPerl_Profiles_GetStore(true)
	if (not store) then
		return
	end

	local snapshot = XPerl_Profiles_Capture()
	if (not snapshot) then
		return
	end

	store.list[name] = snapshot
	XPerl_Profiles_SetActive(name)

	if (XPerl_Notice) then
		XPerl_Notice(format(ProfileMsg("XPERL_CONF_PROFILES_SAVED", "Profile saved: %s"), name))
	end
end

function XPerl_Profiles_Delete(name)
	if (not name or name == "") then
		return false
	end

	local store = XPerl_Profiles_GetStore()
	if (not store or not store.list or not store.list[name]) then
		return false
	end

	store.list[name] = nil
	if (XPerl_Profiles_GetActive() == name) then
		XPerl_Profiles_SetActive(nil)
	end
	return true
end

function XPerl_Profiles_DeleteChecked(panel)
	local store = XPerl_Profiles_GetStore()
	if (not store or not store.list or not panel or not panel.marked) then
		return 0
	end

	local toDelete = {}
	for name in pairs(panel.marked) do
		if (store.list[name]) then
			tinsert(toDelete, name)
		end
	end

	local count = 0
	for i = 1, #toDelete do
		if (XPerl_Profiles_Delete(toDelete[i])) then
			count = count + 1
		end
	end

	if (count > 0) then
		panel.marked = {}
		local nameBox = _G[panel:GetName().."_Name"]
		if (nameBox) then
			nameBox:SetText("")
		end
		panel:FillList()
	end

	return count
end

function XPerl_Profiles_InitPanel(panel)
	if (not panel) then
		return
	end

	panel.rows = panel.rows or {}
	panel.marked = panel.marked or {}

	for i = 1, PROFILE_ROW_COUNT do
		local row = GetProfileRow(i)
		if (row) then
			panel.rows[i] = row
			row.master = panel
			row.nameText = row.nameText or _G[row:GetName().."_LabelText"]
			row:Hide()
		end
	end

	if (not panel.scrollBar) then
		panel.scrollBar = _G[panel:GetName().."_ListScrollBar"]
	end
	if (panel.scrollBar and not panel.scrollBar.bar) then
		panel.scrollBar.bar = _G[panel.scrollBar:GetName().."ScrollBar"]
	end
end

function XPerl_Profiles_GetNameList()
	local store = XPerl_Profiles_GetStore()
	local list = {}
	if (store and store.list) then
		for profileName in pairs(store.list) do
			if (IsValidSnapshot(store.list[profileName])) then
				tinsert(list, profileName)
			end
		end
		sort(list)
	end
	return list
end

function XPerl_Profiles_HasProfiles()
	return #XPerl_Profiles_GetNameList() > 0
end

function XPerl_Profiles_AddMinimapMenuButtons(level)
	local list = XPerl_Profiles_GetNameList()
	local active = XPerl_Profiles_GetActive()
	local info

	for i = 1, #list do
		local profileName = list[i]
		info = UIDropDownMenu_CreateInfo()
		info.text = profileName
		info.checked = (profileName == active)
		info.keepShownOnClick = 1
		info.func = function()
			XPerl_Profiles_Apply(profileName)
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(info, level)
	end
end

function XPerl_Profiles_MinimapHoverMenu_Initialize()
	local info = UIDropDownMenu_CreateInfo()
	info.isTitle = 1
	info.text = ProfileMsg("XPERL_MINIMENU_PROFILES", "Profiles")
	UIDropDownMenu_AddButton(info)

	XPerl_Profiles_AddMinimapMenuButtons(1)
end

function XPerl_Profiles_IsHoverMenuOpen()
	return XPerl_Minimap_ProfilesDropdown
		and UIDROPDOWNMENU_OPEN_MENU == XPerl_Minimap_ProfilesDropdown
		and DropDownList1
		and DropDownList1:IsShown()
end

function XPerl_Profiles_IsProfileMenuHovered(minimapBtn)
	local f = GetMouseFocus()
	while f do
		if (minimapBtn and f == minimapBtn) then
			return true
		end
		if (DropDownList1 and DropDownList1:IsShown() and f == DropDownList1) then
			return true
		end
		if (DropDownList1 and DropDownList1:IsShown()) then
			local parent = f:GetParent()
			while parent do
				if (parent == DropDownList1) then
					return true
				end
				parent = parent:GetParent()
			end
		end
		f = f:GetParent()
	end
	return false
end

function XPerl_Profiles_HideHoverMenu()
	if (XPerl_Minimap_ProfilesDropdown and UIDROPDOWNMENU_OPEN_MENU == XPerl_Minimap_ProfilesDropdown) then
		CloseDropDownMenus()
	end
end

function XPerl_Profiles_ShowHoverMenu(anchor)
	if (not anchor or not XPerl_Profiles_HasProfiles()) then
		return false
	end

	if (not XPerl_Minimap_ProfilesDropdown) then
		CreateFrame("Frame", "XPerl_Minimap_ProfilesDropdown", UIParent)
		XPerl_Minimap_ProfilesDropdown.displayMode = "MENU"
		UIDropDownMenu_Initialize(XPerl_Minimap_ProfilesDropdown, XPerl_Profiles_MinimapHoverMenu_Initialize)
	end

	if (UIDROPDOWNMENU_OPEN_MENU == XPerl_Minimap_ProfilesDropdown and DropDownList1 and DropDownList1:IsShown()) then
		return true
	end

	CloseDropDownMenus()
	ToggleDropDownMenu(1, nil, XPerl_Minimap_ProfilesDropdown, anchor:GetName(), 0, -5)
	return true
end

local function SetProfileRow(row, profileName, listIndex, panel, active, selection)
	if (not row) then
		return
	end

	row.profileName = profileName
	row.listIndex = listIndex

	local mark = _G[row:GetName().."_Mark"]
	local label = _G[row:GetName().."_Label"]
	local labelText = row.nameText or _G[row:GetName().."_LabelText"]
	local del = _G[row:GetName().."_Del"]

	local function SetLabelText(text)
		if (labelText) then
			labelText:SetText(text or "")
		elseif (label) then
			label:SetText(text or "")
		end
	end

	if (not profileName) then
		row:Hide()
		if (mark) then
			mark:Hide()
			mark:SetChecked(false)
		end
		SetLabelText("")
		if (label) then
			label:UnlockHighlight()
		end
		if (del) then
			del:Hide()
		end
		return
	end

	row:Show()
	if (mark) then
		mark:Show()
		mark:SetChecked(panel.marked and panel.marked[profileName] and true or false)
	end
	if (active and profileName == active) then
		SetLabelText("|cff00ff00"..profileName.."|r")
	else
		SetLabelText(profileName)
	end
	if (label) then
		if (listIndex == selection) then
			label:LockHighlight()
		else
			label:UnlockHighlight()
		end
	end
	if (del) then
		del:Show()
	end
end

function XPerl_Profiles_Fill(panel, selectName)
	if (not panel) then
		return
	end

	XPerl_Profiles_InitPanel(panel)

	local list = XPerl_Profiles_GetNameList()
	local active = XPerl_Profiles_GetActive()
	local scroll = panel.scrollBar
	local offset = 0
	if (scroll) then
		offset = FauxScrollFrame_GetOffset(scroll) or 0
	end
	local selection = panel.selection or 1

	panel.start = offset + 1

	if (selectName) then
		for i, profileName in ipairs(list) do
			if (profileName == selectName) then
				selection = i
				break
			end
		end
	end
	if (selection < 1) then
		selection = 1
	elseif (selection > #list and #list > 0) then
		selection = #list
	end
	panel.selection = selection

	for i = 1, PROFILE_ROW_COUNT do
		local row = panel.rows[i] or GetProfileRow(i)
		SetProfileRow(row, nil, nil, panel, active, selection)
	end

	local rowNum = 1
	for i = panel.start, panel.start + PROFILE_ROW_COUNT - 1 do
		if (i > #list) then
			break
		end
		local row = panel.rows[rowNum] or GetProfileRow(rowNum)
		SetProfileRow(row, list[i], i, panel, active, selection)
		rowNum = rowNum + 1
	end

	if (scroll) then
		FauxScrollFrame_Update(scroll, #list, PROFILE_ROW_COUNT, 16)
		if (scroll.bar) then
			if (#list > PROFILE_ROW_COUNT) then
				scroll.bar:Show()
			else
				scroll.bar:Hide()
			end
		end
	end

	local nameBox = _G[panel:GetName().."_Name"]
	if (nameBox) then
		if (selectName) then
			nameBox:SetText(selectName)
		elseif (list[selection]) then
			nameBox:SetText(list[selection])
		elseif (#list == 0) then
			nameBox:SetText("")
		end
	end

	local activeText = _G[panel:GetName().."_ActiveText"]
	if (activeText) then
		if (active) then
			activeText:SetFormattedText(ProfileMsg("XPERL_CONF_PROFILES_ACTIVE_FMT", "Active profile: %s"), active)
		else
			activeText:SetText(ProfileMsg("XPERL_CONF_PROFILES_ACTIVE_NONE", "Active profile: none"))
		end
	end
end

function XPerl_Profiles_UpdateAutoApply(checked)
	local meta = GetCharMeta(true)
	if (meta) then
		meta.autoApply = checked and 1 or nil
	end
end

function XPerl_Profiles_GetAutoApply()
	local meta = GetCharMeta()
	return meta and meta.autoApply
end

local profileBootstrap = CreateFrame("Frame")
profileBootstrap:RegisterEvent("PLAYER_ENTERING_WORLD")
profileBootstrap:SetScript("OnEvent", function(self, event)
	if (event ~= "PLAYER_ENTERING_WORLD") then
		return
	end
	self:UnregisterEvent(event)

	MigrateProfiles()

	local store = XPerl_Profiles_GetStore()
	local active = XPerl_Profiles_GetActive()
	if (store and XPerl_Profiles_GetAutoApply() and active and store.list and store.list[active]) then
		DoApplyProfile(store.list[active])
	end
end)
