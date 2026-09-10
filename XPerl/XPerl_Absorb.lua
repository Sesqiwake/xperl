-- X-Perl UnitFrames — Sirus absorb / heal-absorb bars (Custom Sirus options)

local conf
XPerl_RequestConfig(function(new)
	conf = new
	if (conf) then
		XPerl_Absorb_EnsureConfig(conf)
	end
end, "$Revision: absorb $")

local ABSORB_RGB = {r = 0.4, g = 0.7, b = 1.0}
local HEALABSORB_RGB = {r = 0.9, g = 0.2, b = 0.4}

function XPerl_Absorb_Defaults()
	return {
		enable		= 1,
		party		= 1,
		raid		= 1,
		texture		= {"Default", "Interface\\TargetingFrame\\UI-StatusBar"},
		color		= {r = ABSORB_RGB.r, g = ABSORB_RGB.g, b = ABSORB_RGB.b},
		separateBar	= 1,
		overlay		= nil,
		healAbsorb	= {
			enable		= nil,
			texture		= {"Default", "Interface\\TargetingFrame\\UI-StatusBar"},
			color		= {r = HEALABSORB_RGB.r, g = HEALABSORB_RGB.g, b = HEALABSORB_RGB.b},
			separateBar	= nil,
			overlay		= 1,
		},
	}
end

function XPerl_Absorb_EnsureConfig(db)
	if (not db) then
		return XPerl_Absorb_Defaults()
	end
	if (not db.absorb) then
		db.absorb = XPerl_Absorb_Defaults()
	else
		local d = XPerl_Absorb_Defaults()
		if (db.absorb.enable == nil) then
			db.absorb.enable = d.enable
		end
		if (db.absorb.party == nil) then
			db.absorb.party = d.party
		end
		if (db.absorb.raid == nil) then
			db.absorb.raid = d.raid
		end
		if (not db.absorb.texture) then
			db.absorb.texture = d.texture
		end
		if (not db.absorb.color) then
			db.absorb.color = d.color
		end
		if (not db.absorb.separateBar and not db.absorb.overlay) then
			db.absorb.separateBar = 1
			db.absorb.overlay = nil
		end
		if (not db.absorb.healAbsorb) then
			db.absorb.healAbsorb = d.healAbsorb
		else
			local h = db.absorb.healAbsorb
			if (not h.texture) then
				h.texture = d.healAbsorb.texture
			end
			if (not h.color) then
				h.color = d.healAbsorb.color
			end
			if (not h.separateBar and not h.overlay) then
				h.overlay = 1
				h.separateBar = nil
			end
		end
	end
	return db.absorb
end

local function GetTex(cfg)
	if (cfg and cfg.texture and cfg.texture[2]) then
		return cfg.texture[2]
	end
	return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetColor(cfg, fallback)
	if (cfg and cfg.color and cfg.color.r) then
		return cfg.color
	end
	return fallback
end

local function FrameKind(frame)
	local name = frame and frame:GetName()
	if (not name) then
		return "unit"
	end
	if (string.find(name, "^XPerl_Raid")) then
		return "raid"
	end
	if (string.find(name, "^XPerl_party") or string.find(name, "Party_Pet") or string.find(name, "partypet")) then
		return "party"
	end
	return "unit"
end

local function FrameAllowed(frame)
	local cfg = conf and conf.absorb
	if (not cfg) then
		return false
	end
	local kind = FrameKind(frame)
	if (kind == "party" and not cfg.party) then
		return false
	end
	if (kind == "raid" and not cfg.raid) then
		return false
	end
	return true
end

local function WantSeparate(cfg)
	return cfg and cfg.separateBar and not cfg.overlay
end

-- Extra pixels for always-visible separate absorb rows (config-based).
function XPerl_Absorb_LayoutExtra(frame)
	if (not conf or not conf.absorb or not frame) then
		return 0
	end
	if (not FrameAllowed(frame)) then
		return 0
	end
	local n = 0
	if (conf.absorb.enable and WantSeparate(conf.absorb)) then
		n = n + 1
	end
	local h = conf.absorb.healAbsorb
	if (h and h.enable and WantSeparate(h)) then
		n = n + 1
	end
	if (n == 0) then
		return 0
	end
	return n * 10 + 2
end

local function FormatAbsorbText(amount)
	if (amount <= 0) then
		return ""
	end
	if (amount >= 1000000) then
		return format("%.1fM", amount / 1000000)
	elseif (amount >= 10000) then
		return format("%.1fK", amount / 1000)
	end
	return tostring(floor(amount + 0.5))
end

local function UnitShowSideValue(frame)
	local c = frame and frame.conf
	if (c) then
		return c.percent
	end
	if (conf and conf.player) then
		return conf.player.percent
	end
	return 1
end

local function GetHealthBar(frame)
	if (frame.healthBar) then
		return frame.healthBar
	end
	if (frame.statsFrame) then
		return frame.statsFrame.healthBar
	end
end

local function GetStatsFrame(frame)
	return frame.statsFrame or (frame.healthBar and frame.healthBar:GetParent())
end

local function EnsureOverlayBar(healthBar, key, levelAdd)
	local bar = healthBar[key]
	if (not bar) then
		bar = CreateFrame("StatusBar", nil, healthBar)
		healthBar[key] = bar
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		local t = bar:GetStatusBarTexture()
		if (t) then
			t:SetHorizTile(false)
			t:SetVertTile(false)
		end
	end
	local fl = healthBar:GetFrameLevel() or 1
	bar:SetFrameLevel(fl + levelAdd)
	return bar
end

local function EnsureSeparateBar(statsFrame, key)
	local bar = statsFrame[key]
	if (not bar) then
		bar = CreateFrame("StatusBar", nil, statsFrame)
		statsFrame[key] = bar
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		local bg = bar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0, 0, 0, 0.45)
		bar.bg = bg
		bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		local t = bar:GetStatusBarTexture()
		if (t) then
			t:SetHorizTile(false)
			t:SetVertTile(false)
		end
		local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("TOPLEFT")
		text:SetPoint("BOTTOMRIGHT", 0, 1)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
		text:SetTextColor(1, 1, 1)
		bar.text = text
		local percent = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		percent:SetWidth(50)
		percent:SetJustifyH("LEFT")
		percent:SetJustifyV("MIDDLE")
		percent:SetPoint("TOPLEFT", bar, "TOPRIGHT", 2, 0)
		percent:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 2, 0)
		percent:SetTextColor(1, 1, 1)
		bar.percent = percent
		if (XPerl_RegisterUnitText) then
			XPerl_RegisterUnitText(text)
			XPerl_RegisterUnitText(percent)
		end
	else
		if (bar.percent) then
			bar.percent:ClearAllPoints()
			bar.percent:SetWidth(50)
			bar.percent:SetJustifyV("MIDDLE")
			bar.percent:SetPoint("TOPLEFT", bar, "TOPRIGHT", 2, 0)
			bar.percent:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 2, 0)
		end
	end
	return bar
end

local function HideBar(bar)
	if (bar) then
		bar:Hide()
	end
end

local function SetBarTextureColor(bar, path, color)
	bar:SetStatusBarTexture(path)
	local t = bar:GetStatusBarTexture()
	if (t) then
		t:SetHorizTile(false)
		t:SetVertTile(false)
	end
	bar:SetStatusBarColor(color.r, color.g, color.b, 0.9)
	if (bar.bg) then
		-- Empty track: much darker than fill so the fill stays readable
		bar.bg:SetVertexColor(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.95)
	end
end

local function UpdateOverlayBar(bar, healthBar, amount, healthMax, texPath, color)
	if (not bar or not healthBar or amount <= 0 or healthMax <= 0) then
		HideBar(bar)
		return
	end
	local hw = healthBar:GetWidth()
	if (not hw or hw <= 0) then
		HideBar(bar)
		return
	end
	local frac = amount / healthMax
	if (frac > 1) then
		frac = 1
	end
	local w = hw * frac
	if (w < 1) then
		w = 1
	end
	SetBarTextureColor(bar, texPath, color)
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
	bar:SetWidth(w)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:Show()
end

local function FillSeparateBar(bar, amount, stickyMax, texPath, color, showSideValue, showCenterValue)
	SetBarTextureColor(bar, texPath, color)
	local maxV = stickyMax or 1
	if (amount > maxV) then
		maxV = amount
	end
	if (maxV < 1) then
		maxV = 1
	end
	bar:SetMinMaxValues(0, maxV)
	bar:SetValue(amount or 0)
	local label
	if ((amount or 0) > 0) then
		label = FormatAbsorbText(amount)
	else
		label = "0"
	end
	if (bar.text) then
		if (showCenterValue) then
			bar.text:SetText(label)
			bar.text:Show()
		else
			bar.text:SetText("")
			bar.text:Hide()
		end
	end
	if (bar.percent) then
		if (showSideValue) then
			bar.percent:SetText(label)
			bar.percent:Show()
		else
			bar.percent:SetText("")
			bar.percent:Hide()
		end
	end
	bar:Show()
	return maxV
end

-- Keep stats (+ portrait) height = natural + separate-row extra. Natural is set by Set_Bits.
local function SyncExtraHeight(frame, statsFrame, extra)
	local natural = statsFrame.xperlNaturalH
	if (not natural) then
		local prev = statsFrame.xperlAbsorbLayoutExtra or 0
		natural = (statsFrame:GetHeight() or 40) - prev
		if (natural < 20) then
			natural = 40
		end
		statsFrame.xperlNaturalH = natural
	end

	local want = natural + extra
	if (math.abs((statsFrame:GetHeight() or 0) - want) > 0.5) then
		statsFrame:SetHeight(want)
	end
	statsFrame.xperlAbsorbLayoutExtra = extra

	local portrait = frame and frame.portraitFrame
	if (portrait and portrait.SetHeight) then
		local pNatural = portrait.xperlNaturalH
		if (not pNatural) then
			local prevP = portrait.xperlAbsorbLayoutExtra or 0
			pNatural = (portrait:GetHeight() or 62) - prevP
			if (pNatural < 40) then
				pNatural = 62
			end
			portrait.xperlNaturalH = pNatural
		end
		local wantP = pNatural + extra
		if (math.abs((portrait:GetHeight() or 0) - wantP) > 0.5) then
			portrait:SetHeight(wantP)
		end
		portrait.xperlAbsorbLayoutExtra = extra
	end

	if (frame and frame.GetHeight and frame.SetHeight) then
		local extraF = extra
		local wantF
		if (frame.xperlNaturalH) then
			wantF = frame.xperlNaturalH + extraF
		else
			local prevF = frame.xperlAbsorbLayoutExtra or 0
			local curF = frame:GetHeight() or 0
			local baseF = frame.xperlAbsorbBaseH
			if (not baseF) then
				baseF = curF - prevF
				if (baseF < 1) then
					baseF = curF
				end
				frame.xperlAbsorbBaseH = baseF
			else
				local expectedF = baseF + prevF
				if (math.abs(curF - expectedF) > 1.5) then
					baseF = curF
					frame.xperlAbsorbBaseH = baseF
					prevF = 0
				end
			end
			if (frame.nameFrame and frame.portraitFrame) then
				local h1 = (frame.nameFrame:GetHeight() or 0) + (statsFrame:GetHeight() or 0) - 2
				local h2 = frame.portraitFrame:GetHeight() or 0
				wantF = h1
				if (h2 > wantF) then
					wantF = h2
				end
			else
				wantF = baseF + extraF
			end
		end
		if (not InCombatLockdown() and math.abs((frame:GetHeight() or 0) - wantF) > 0.5) then
			frame:SetHeight(wantF)
		end
		frame.xperlAbsorbLayoutExtra = extraF
	end
end

local function LayoutRaidSeparateBars(frame)
	local sf = frame.statsFrame
	if (not sf) then
		return
	end
	local healthBar = sf.healthBar
	if (not healthBar) then
		return
	end

	local topBars = {}
	if (sf.xperlAbsorbBar and sf.xperlAbsorbBar:IsShown()) then
		tinsert(topBars, sf.xperlAbsorbBar)
	end
	if (sf.xperlHealAbsorbBar and sf.xperlHealAbsorbBar:IsShown()) then
		tinsert(topBars, sf.xperlHealAbsorbBar)
	end

	local barH = 6
	local last = nil
	for i, bar in pairs(topBars) do
		bar:ClearAllPoints()
		if (not last) then
			bar:SetPoint("TOPLEFT", sf, "TOPLEFT", 3, -2)
			bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -2)
		else
			bar:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -1)
			bar:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 0, -1)
		end
		bar:SetHeight(barH)
		if (bar.percent) then
			bar.percent:Hide()
		end
		last = bar
	end

	healthBar:ClearAllPoints()
	if (last) then
		healthBar:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -1)
		healthBar:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 0, -1)
		healthBar:SetHeight(15)
	else
		healthBar:SetPoint("TOPLEFT", sf, "TOPLEFT", 3, -3)
		healthBar:SetPoint("BOTTOMRIGHT", sf, "TOPRIGHT", -3, -18)
	end

	local manaBar = sf.manaBar
	if (manaBar and manaBar:IsShown()) then
		manaBar:ClearAllPoints()
		manaBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, 0)
		manaBar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, -7)
	end
end

local function RelayoutStats(frame)
	if (not frame) then
		return
	end
	local hb = frame.statsFrame and frame.statsFrame.healthBar
	if (not hb) then
		return
	end
	-- Raid bars have no .percent and use a compact custom layout
	if (not hb.percent) then
		LayoutRaidSeparateBars(frame)
		return
	end
	if (XPerl_StatsFrameSetup) then
		XPerl_StatsFrameSetup(frame, frame.xperlStatsOthers, frame.xperlStatsOffset)
	end
end

local function SafeUnitAbsorb(unit)
	if (type(UnitGetTotalAbsorbs) == "function") then
		return UnitGetTotalAbsorbs(unit) or 0
	end
	return 0
end

local function SafeUnitHealAbsorb(unit)
	if (type(UnitGetTotalHealAbsorbs) == "function") then
		return UnitGetTotalHealAbsorbs(unit) or 0
	end
	return 0
end

function XPerl_SetAbsorbBar(frame)
	if (not frame) then
		return
	end

	local healthBar = GetHealthBar(frame)
	local statsFrame = GetStatsFrame(frame)
	if (not healthBar or not statsFrame) then
		return
	end

	local cfg = conf and conf.absorb
	local showSideValue = UnitShowSideValue(frame)
	local showCenterValue
	-- Raid: value centered on the thin bar (no room on the side)
	if (not healthBar.percent) then
		showSideValue = nil
		showCenterValue = 1
	end

	if (not cfg) then
		HideBar(healthBar.xperlAbsorbOverlay)
		HideBar(healthBar.xperlHealAbsorbOverlay)
		HideBar(statsFrame.xperlAbsorbBar)
		HideBar(statsFrame.xperlHealAbsorbBar)
		SyncExtraHeight(frame, statsFrame, 0)
		RelayoutStats(frame)
		return
	end

	local unit = frame.partyid or SecureButton_GetUnit(frame)
	local allowed = FrameAllowed(frame) and unit and UnitExists(unit)

	local dmgEnable = allowed and cfg.enable
	local healCfg = cfg.healAbsorb
	local healEnable = allowed and healCfg and healCfg.enable

	local absorbAmt = 0
	local healAmt = 0
	if (dmgEnable) then
		absorbAmt = SafeUnitAbsorb(unit)
	end
	if (healEnable) then
		healAmt = SafeUnitHealAbsorb(unit)
	end

	local healthMax = 0
	if (unit and UnitExists(unit)) then
		healthMax = UnitHealthMax(unit) or 0
	end

	local sepCount = 0
	local needRelayout = false
	local absorbColor = GetColor(cfg, ABSORB_RGB)
	local healColor = GetColor(healCfg, HEALABSORB_RGB)

	-- Damage absorb
	if (dmgEnable and WantSeparate(cfg)) then
		HideBar(healthBar.xperlAbsorbOverlay)
		local bar = EnsureSeparateBar(statsFrame, "xperlAbsorbBar")
		local wasShown = bar:IsShown()
		if (absorbAmt <= 0) then
			frame.xperlAbsorbBarMax = nil
			FillSeparateBar(bar, 0, 1, GetTex(cfg), absorbColor, showSideValue, showCenterValue)
		else
			local maxA = FillSeparateBar(bar, absorbAmt, frame.xperlAbsorbBarMax or absorbAmt, GetTex(cfg), absorbColor, showSideValue, showCenterValue)
			frame.xperlAbsorbBarMax = maxA
		end
		sepCount = sepCount + 1
		if (not wasShown) then
			needRelayout = true
		end
	elseif (dmgEnable and absorbAmt > 0) then
		HideBar(statsFrame.xperlAbsorbBar)
		local ov = EnsureOverlayBar(healthBar, "xperlAbsorbOverlay", 2)
		UpdateOverlayBar(ov, healthBar, absorbAmt, healthMax, GetTex(cfg), absorbColor)
		frame.xperlAbsorbBarMax = nil
		needRelayout = true
	else
		if (statsFrame.xperlAbsorbBar and statsFrame.xperlAbsorbBar:IsShown()) then
			needRelayout = true
		end
		HideBar(healthBar.xperlAbsorbOverlay)
		HideBar(statsFrame.xperlAbsorbBar)
		frame.xperlAbsorbBarMax = nil
	end

	-- Heal absorb
	if (healEnable and WantSeparate(healCfg)) then
		HideBar(healthBar.xperlHealAbsorbOverlay)
		local bar = EnsureSeparateBar(statsFrame, "xperlHealAbsorbBar")
		local wasShown = bar:IsShown()
		if (healAmt <= 0) then
			frame.xperlHealAbsorbBarMax = nil
			FillSeparateBar(bar, 0, 1, GetTex(healCfg), healColor, showSideValue, showCenterValue)
		else
			local maxA = FillSeparateBar(bar, healAmt, frame.xperlHealAbsorbBarMax or healAmt, GetTex(healCfg), healColor, showSideValue, showCenterValue)
			frame.xperlHealAbsorbBarMax = maxA
		end
		sepCount = sepCount + 1
		if (not wasShown) then
			needRelayout = true
		end
	elseif (healEnable and healAmt > 0) then
		HideBar(statsFrame.xperlHealAbsorbBar)
		local ov = EnsureOverlayBar(healthBar, "xperlHealAbsorbOverlay", 3)
		UpdateOverlayBar(ov, healthBar, healAmt, healthMax, GetTex(healCfg), healColor)
		frame.xperlHealAbsorbBarMax = nil
		needRelayout = true
	else
		if (statsFrame.xperlHealAbsorbBar and statsFrame.xperlHealAbsorbBar:IsShown()) then
			needRelayout = true
		end
		HideBar(healthBar.xperlHealAbsorbOverlay)
		HideBar(statsFrame.xperlHealAbsorbBar)
		frame.xperlHealAbsorbBarMax = nil
	end

	local extra = sepCount * 10
	if (sepCount > 0) then
		extra = extra + 2
	end
	local prevExtra = statsFrame.xperlAbsorbLayoutExtra or 0
	SyncExtraHeight(frame, statsFrame, extra)
	-- Raid compact layout must re-anchor whenever separate rows are active
	if (needRelayout or prevExtra ~= extra or (sepCount > 0 and not healthBar.percent)) then
		RelayoutStats(frame)
	end
end

function XPerl_RefreshAbsorbFrames(unit)
	if (not unit) then
		return
	end

	local function tryFrame(frame)
		if (frame and frame.partyid and UnitIsUnit(frame.partyid, unit)) then
			XPerl_SetAbsorbBar(frame)
			return true
		end
	end

	tryFrame(XPerl_Player)
	if (XPerl_Player_Pet) then
		tryFrame(XPerl_Player_Pet)
	end
	if (XPerl_Target) then
		tryFrame(XPerl_Target)
	end
	if (XPerl_Focus) then
		tryFrame(XPerl_Focus)
	end
	if (XPerl_TargetTarget) then
		tryFrame(XPerl_TargetTarget)
	end

	local guid = UnitGUID(unit)
	if (guid) then
		if (XPerl_Raid_GetUnitFrameByGUID) then
			local f = XPerl_Raid_GetUnitFrameByGUID(guid)
			if (f) then
				XPerl_SetAbsorbBar(f)
			end
		end
		if (XPerl_Party_GetUnitFrameByGUID) then
			local f = XPerl_Party_GetUnitFrameByGUID(guid)
			if (f) then
				XPerl_SetAbsorbBar(f)
			end
		end
		if (XPerl_Party_Pet_GetUnitFrameByGUID) then
			local f = XPerl_Party_Pet_GetUnitFrameByGUID(guid)
			if (f) then
				XPerl_SetAbsorbBar(f)
			end
		end
	end
end

function XPerl_Absorb_RefreshAll()
	-- Re-run Set_Bits so natural heights are restored before absorb extra is applied
	if (XPerl_Player_Set_Bits and XPerl_Player) then
		XPerl_Player_Set_Bits(XPerl_Player)
	end
	if (XPerl_Player_Pet_Set_Bits and XPerl_Player_Pet) then
		XPerl_Player_Pet_Set_Bits(XPerl_Player_Pet)
	end
	if (XPerl_Target_Set_Bits and XPerl_Target) then
		XPerl_Target_Set_Bits(XPerl_Target)
	end
	if (XPerl_Target_Set_Bits and XPerl_Focus) then
		XPerl_Target_Set_Bits(XPerl_Focus)
	end
	if (XPerl_TargetTarget_Set_Bits) then
		XPerl_TargetTarget_Set_Bits()
	end
	if (XPerl_Party_Set_Bits) then
		XPerl_Party_Set_Bits()
	end
	if (XPerl_Party_Pet_Set_Bits) then
		XPerl_Party_Pet_Set_Bits()
	end
	if (XPerl_Raid_Set_Bits and XPerl_Raid_Frame) then
		XPerl_Raid_Set_Bits(XPerl_Raid_Frame)
	end

	local function bump(frame)
		if (frame) then
			XPerl_SetAbsorbBar(frame)
		end
	end

	bump(XPerl_Player)
	bump(XPerl_Player_Pet)
	bump(XPerl_Target)
	bump(XPerl_Focus)
	bump(XPerl_TargetTarget)

	for i = 1, 4 do
		bump(_G["XPerl_party"..i])
		bump(_G["XPerl_partypet"..i])
	end

	if (GetNumRaidMembers() > 0 and XPerl_Raid_GetUnitFrameByUnit) then
		for i = 1, GetNumRaidMembers() do
			bump(XPerl_Raid_GetUnitFrameByUnit("raid"..i))
		end
	end
end

do
	local absorbWatch = CreateFrame("Frame")
	absorbWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
	pcall(function()
		absorbWatch:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
	end)
	pcall(function()
		absorbWatch:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
	end)
	absorbWatch:SetScript("OnEvent", function(self, event, unit)
		if (event == "PLAYER_ENTERING_WORLD") then
			XPerl_Absorb_RefreshAll()
			return
		end
		if (event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED") then
			XPerl_RefreshAbsorbFrames(unit)
		end
	end)
end
