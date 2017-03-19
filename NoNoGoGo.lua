local NNGG = LibStub("AceAddon-3.0"):NewAddon("NoNoGoGo", "AceTimer-3.0", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LW = LibStub("LibWindow-1.1")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local ADB = LibStub("AceDB-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local LDS = LibStub("LibDualSpec-1.0")

local match, sub, gsub = string.match, string.sub, string.gsub
local type, tonumber = type, tonumber
local InCombatLockdown, IsEncounterInProgress = InCombatLockdown, IsEncounterInProgress
local UnitIsGroupLeader, UnitIsGroupAssistant = UnitIsGroupLeader, UnitIsGroupAssistant
local LoggingCombat = LoggingCombat
local pullTimerCount = nil
local pullTimerStarted = nil
local timedResetStarted = nil
local NNGGPullTimerStarted = nil
local nnggPullTimerCount = nil
local updateInterval = nil
local disableCombatLoggingDelay = nil
local testMode = nil
local statusBar = nil
local statusBarTimer = nil
local statusBarTestMode = nil
local NNGGPullTimerMode = nil
local DBMPullTimerMode = nil
local BWPullTimerMode = nil
local resetPullTimerTicker = nil
local disableCombatLoggingTicker = nil
local enableFramesTimer = nil
local addonName = nil
local popupDialogShown = nil
local autoLogging = nil
local readyCheckPassed = nil
local readyCheckFailedTicker = nil
local readyCheckCompleted = nil
local readyCount = 0
local readyCountSelf = 0
local readyInitName = nil

local db
local defaults = {
	profile = {
		AnchorFrame = {},
		StatusBarFrame = {},
		AnchorWidth = 100,
		AnchorHeight = 150,
		AnchorBorder = 2,
		Font = "Morpheus",
		FontColor = {r = 0, g = 0, b = 0, a = 1},
		FontOutline = "",
		FontSize = 14,
		Background = "Blizzard Marble",
		BackgroundColor = {r = 1, g = 1, b = 1, a = 1},
		ButtonBackground = "Blizzard Parchment",
		ButtonBackgroundColor = {r = 1, g = 1, b = 1, a = 1},
		StatusBar = {
			BarWidth = 250,
			BarHeight = 20,
			BarTexture = "Blizzard",
			BarColor = {r = 1, g = 0, b = 0, a = 1},
			BarBackgroundTexture = "Blizzard",
			BarBackgroundColor = {r = 0.0862745098039216, g = 0.0862745098039216, b = 0.0862745098039216, a = 1},
			Font = "Arial Narrow",
			FontColor = {r = 1, g = 1, b = 1, a = 1},
			FontOutline = "OUTLINE",
			FontSize = 14
		},
	},
	global = {
		PullTimerCount = 5,
		DisableCombatLoggingDelay = 5,
		TestMode = false,
		StatusBar = false,
		StatusBarTestMode = false,
		CombatLogging = false,
		PullTimerMode = "NNGG"
	}
}

local function initializeLocalVars()
	pullTimerCount = NNGG.db.global.PullTimerCount
	testMode = NNGG.db.global.TestMode
	logCombat = NNGG.db.global.CombatLogging
	statusBar = NNGG.db.global.StatusBar
	statusBarTestMode = NNGG.db.global.StatusBarTestMode
	disableCombatLoggingDelay = NNGG.db.global.DisableCombatLoggingDelay
	
	initializeLocalVars = nil
end

local order = 0
local function getOrder()
	order = order + 1
	return order
end

local options = {
	name = "NoNoGoGo",
	handler = NNGG,
	type = "group",
	guiInline = true,
	args = {
		generalsettings = {
			order = getOrder(),
			type = "group",
			name = "General Settings",
			guiInline = true,
			args = {
				pulltimermode = {
					type = "select",
					order = getOrder(),
					name = "Pull Timer Mode",
					desc = "Set the pull timer mode.",
					values = {
						["NNGG"]  = "NoNoGoGo",
						["DBM"] = "Deadly Boss Mods",
						["BW"]  = "Big Wigs",
					},
					set = function(info, value)
						NNGG.db.global.PullTimerMode = value
						NNGG:SetPullTimerMode(value)
					end,
					get = function(info) return NNGG.db.global.PullTimerMode end
				},
				anchorwidth = {
					order = getOrder(),
					type = "range",
					name = "Width",
					desc = "Set the width of the main frames.",
					min = 50, max = 200, step = 1,
					set = function(info, value)
						NNGG.db.profile.AnchorWidth = value
						NNGG.AA_f:SetWidth(value+10)
						NNGG.A_f:SetWidth(value)
						NNGG.PT_f:SetWidth(value-(NNGG.db.profile.AnchorBorder*2))
						NNGG.RC_f:SetWidth(value-(NNGG.db.profile.AnchorBorder*2))
					end,
					get = function(info) return NNGG.db.profile.AnchorWidth end
				},
				anchorheight = {
					order = getOrder(),
					type = "range",
					name = "Height",
					desc = "Set the height of the main frames.",
					min = 50, max = 200, step = 1,
					set = function(info, value)
						NNGG.db.profile.AnchorHeight = value
						NNGG.AA_f:SetHeight(value+10)
						NNGG.A_f:SetHeight(value)
						NNGG.PT_f:SetHeight((value/2)-(NNGG.db.profile.AnchorBorder*1.5))
						NNGG.RC_f:SetHeight((value/2)-(NNGG.db.profile.AnchorBorder*1.5))
					end,
					get = function(info) return NNGG.db.profile.AnchorHeight end
				},
				anchorborder = {
					order = getOrder(),
					type = "range",
					name = "Border",
					desc = "Set the offset of the frames.",
					min = 0, max = 10, step = 1,
					set = function(info, value)
						NNGG.db.profile.AnchorBorder = value
						NNGG.PT_f:SetHeight((NNGG.db.profile.AnchorHeight/2)-(value*1.5))
						NNGG.RC_f:SetHeight((NNGG.db.profile.AnchorHeight/2)-(value*1.5))
						NNGG.PT_f:SetWidth(NNGG.db.profile.AnchorWidth-(value*2))
						NNGG.RC_f:SetWidth(NNGG.db.profile.AnchorWidth-(value*2))
						NNGG.RC_f:SetPoint("BOTTOM", NNGG.A_f, "BOTTOM", 0, value)
						NNGG.PT_f:SetPoint("TOP", NNGG.A_f, "TOP", 0, -value)
					end,
					get = function(info) return NNGG.db.profile.AnchorBorder end
				},
				testmode = {
					order = getOrder(),
					type = "toggle",
					name = "Test Mode",
					desc = "Toggle test mode.",
					set = function(info, value)
						NNGG.db.global.TestMode = value
						testMode = value
						NNGG:SetTestMode(value)
					end,
					get = function(info) return NNGG.db.global.TestMode end
				},
				combatlogging = {
					order = getOrder(),
					type = "toggle",
					name = "Combat Logging",
					desc = "Toggle automatic combat logging.",
					set = function(info, value)
						NNGG.db.global.CombatLogging = value
						logCombat = value
					end,
					get = function(info) return NNGG.db.global.CombatLogging end
				},
				disablecombatloggingdelay = {
					order = getOrder(),
					type = "range",
					name = "Terminate Combat Logging",
					desc = "Set the delay in seconds at which combat logging will be disabled after leaving or not entering combat.",
					min = 5, max = 15, step = 1,
					set = function(info, value)
						NNGG.db.global.DisableCombatLoggingDelay = value
						disableCombatLoggingDelay = value
					end,
					get = function(info) return NNGG.db.global.DisableCombatLoggingDelay end
				},
				statusbar = {
					order = getOrder(),
					type = "toggle",
					name = "Status Bar",
					desc = "Toggle status bar.",
					set = function(info, value)
						NNGG.db.global.StatusBar = value
						statusBar = value
					end,
					get = function(info) return NNGG.db.global.StatusBar end
				},
				statusbartestmode = {
					order = getOrder(),
					type = "toggle",
					name = "Status Bar Test Mode",
					desc = "Toggle status bar test mode.",
					set = function(info, value)
						NNGG.db.global.StatusBarTestMode = value
						statusBarTestMode = value
						NNGG:ResetStatusBar()
					end,
					get = function(info) return NNGG.db.global.StatusBarTestMode end
				},
				font = {
					type = "select", dialogControl = 'LSM30_Font',
					order = getOrder(),
					name = "Font",
					desc = "Set the font of the button text.",
					values = AceGUIWidgetLSMlists.font,
					set = function(info, value)
						NNGG.db.profile.Font = value
						NNGG.PT_f.pullTimerText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
						NNGG.RC_f.readyCheckText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.Font end
				},
				fontoutline = {
					type = "select",
					order = getOrder(),
					name = "Font Outline",
					desc = "Set the font outline of the button text.",
					values = {
						[""]             = "None",
						["OUTLINE"]      = "Outline",
						["THICKOUTLINE"] = "Thick Outline",
					},
					set = function(info, value)
						NNGG.db.profile.FontOutline = value
						NNGG.PT_f.pullTimerText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
						NNGG.RC_f.readyCheckText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.FontOutline end
				},
				fontcolor = {
					type = "color",
					order = getOrder(),
					name = "Font Color",
					desc = "Set the font color of the button text.",
					hasAlpha = true,
					set = function(info, r, g, b, a)
						NNGG.db.profile.FontColor.r, NNGG.db.profile.FontColor.g, NNGG.db.profile.FontColor.b, NNGG.db.profile.FontColor.a = r, g, b, a
						NNGG.PT_f.pullTimerText:SetTextColor(r, g, b, a)
						NNGG.RC_f.readyCheckText:SetTextColor(r, g, b, a)
					end,
					get = function(info) return NNGG.db.profile.FontColor.r, NNGG.db.profile.FontColor.g, NNGG.db.profile.FontColor.b, NNGG.db.profile.FontColor.a end,
				},
				fontsize = {
					type = "range",
					order = getOrder(),
					name = "Font Size",
					desc = "Set the font size of the button text.",
					min = 6, max = 25, step = 1,
					set = function(info, value)
						NNGG.db.profile.FontSize = value
						NNGG.PT_f.pullTimerText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
						NNGG.RC_f.readyCheckText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.FontSize end
				},
				texture = {
					type = "select", dialogControl = 'LSM30_Background',
					order = getOrder(),
					name = "Frame Texture",
					desc = "Set the texture for the backdrop of the main frames.",
					values = AceGUIWidgetLSMlists.background,
					set = function(info, value)
						NNGG.db.profile.Background = value
						NNGG.A_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.Background))
					end,
					get = function(info) return NNGG.db.profile.Background end
				},
				backgroundcolor = {
				   type = "color",
				   order = getOrder(),
				   name = "Frame Color",
				   desc = "Set the color for the main frames.",
				   hasAlpha = true,
				   set = function(info, r, g, b, a)
						NNGG.db.profile.BackgroundColor.r, NNGG.db.profile.BackgroundColor.g, NNGG.db.profile.BackgroundColor.b, NNGG.db.profile.BackgroundColor.a = r, g, b, a
						NNGG.A_t:SetVertexColor(r, g, b, a)
				   end,
				   get = function(info) return NNGG.db.profile.BackgroundColor.r, NNGG.db.profile.BackgroundColor.g, NNGG.db.profile.BackgroundColor.b, NNGG.db.profile.BackgroundColor.a end
				},
				buttontexture = {
					type = "select", dialogControl = 'LSM30_Background',
					order = getOrder(),
					name = "Button Texture",
					desc = "Set the texture for the buttons.",
					values = AceGUIWidgetLSMlists.background,
					set = function(info, value)
						NNGG.db.profile.ButtonBackground = value
						NNGG.PT_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.ButtonBackground))
						NNGG.RC_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.ButtonBackground))
					end,
					get = function(info) return NNGG.db.profile.ButtonBackground end
				},
				buttonbackgroundcolor = {
				   type = "color",
				   order = getOrder(),
				   name = "Button Color",
				   desc = "Set the color for the buttons.",
				   hasAlpha = true,
				   set = function(info, r, g, b, a)
						NNGG.db.profile.ButtonBackgroundColor.r, NNGG.db.profile.ButtonBackgroundColor.g, NNGG.db.profile.ButtonBackgroundColor.b, NNGG.db.profile.ButtonBackgroundColor.a = r, g, b, a
						NNGG.PT_t:SetVertexColor(r, g, b, a)
						NNGG.RC_t:SetVertexColor(r, g, b, a)
				   end,
				   get = function(info) return NNGG.db.profile.ButtonBackgroundColor.r, NNGG.db.profile.ButtonBackgroundColor.g, NNGG.db.profile.ButtonBackgroundColor.b, NNGG.db.profile.ButtonBackgroundColor.a end
				},
			}
		},
		pulltimerstatusbarsettings = {
			order = 2,
			type = "group",
			name = "Status Bar Settings",
			guiInline = true,
			args = {
				FontSize = {
					type = "range",
					order = getOrder(),
					name = "Font Size",
					desc = "Set the font size of the status bar text.",
					min = 6, max = 25, step = 1,
					set = function(info, value)
						NNGG.db.profile.StatusBar.FontSize = value
						NNGG.SB_f.pulltext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
						NNGG.SB_f.timertext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.FontSize end
				},
				width = {
					order = getOrder(),
					type = "range",
					name = "Width",
					desc = "Set the width of the status bar.",
					min = 100, max = 500, step = 0.5,
					set = function(info, value)
						NNGG.db.profile.StatusBar.BarWidth = value
						NNGG.SB_f:SetWidth(NNGG.db.profile.StatusBar.BarWidth)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarWidth end
				},
				height = {
					order = getOrder(),
					type = "range",
					name = "Height",
					desc = "Set the height of the status bar.",
					min = 1, max = 50, step = 0.5,
					set = function(info, value)
						NNGG.db.profile.StatusBar.BarHeight = value
						NNGG.SB_f:SetHeight(NNGG.db.profile.StatusBar.BarHeight)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarHeight end
				},
				font = {
					type = "select", dialogControl = 'LSM30_Font',
					order = getOrder(),
					name = "Font",
					desc = "Set the font of the status bar text.",
					values = AceGUIWidgetLSMlists.font,
					set = function(info, value)
						NNGG.db.profile.StatusBar.Font = value
						NNGG.SB_f.pulltext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
						NNGG.SB_f.timertext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.Font end
				},
				Texture = {
					type = "select", dialogControl = 'LSM30_Statusbar',
					order = getOrder(),
					name = "Bar Texture",
					desc = "Set the texture for the status bar.",
					values = AceGUIWidgetLSMlists.statusbar,
					set = function(info, value)
						NNGG.db.profile.StatusBar.BarTexture = value
						NNGG.SB_f:SetStatusBarTexture(LSM:Fetch("statusbar", NNGG.db.profile.StatusBar.BarTexture))
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarTexture end
				},
				backgroundtexture = {
					type = "select", dialogControl = 'LSM30_Statusbar',
					order = getOrder(),
					name = "Background Texture",
					desc = "Set the background texture for the status bar.",
					values = AceGUIWidgetLSMlists.statusbar,
					set = function(info, value)
						NNGG.db.profile.StatusBar.BarBackgroundTexture = value
						NNGG.SB_t:SetTexture(LSM:Fetch("statusbar", NNGG.db.profile.StatusBar.BarBackgroundTexture))
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarBackgroundTexture end
				},
				FontColor = {
					type = "color",
					order = getOrder(),
					name = "Font Color",
					desc = "Set the font color of the status bar text.",
					hasAlpha = true,
					set = function(info, r, g, b, a)
						NNGG.db.profile.StatusBar.FontColor.r, NNGG.db.profile.StatusBar.FontColor.g, NNGG.db.profile.StatusBar.FontColor.b, NNGG.db.profile.StatusBar.FontColor.a = r, g, b, a
						NNGG.SB_f.pulltext:SetTextColor(r, g, b, a)
						NNGG.SB_f.timertext:SetTextColor(r, g, b, a)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.FontColor.r, NNGG.db.profile.StatusBar.FontColor.g, NNGG.db.profile.StatusBar.FontColor.b, NNGG.db.profile.StatusBar.FontColor.a end,
				},
				color = {
					type = "color",
					order = getOrder(),
					name = "Bar Color",
					desc = "Set the color of the status bar",
					hasAlpha = true,
					set = function(info, r, g, b, a)
						NNGG.db.profile.StatusBar.BarColor.r, NNGG.db.profile.StatusBar.BarColor.g, NNGG.db.profile.StatusBar.BarColor.b, NNGG.db.profile.StatusBar.BarColor.a = r, g, b, a
						NNGG.SB_f:SetStatusBarColor(r, g, b, a)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarColor.r, NNGG.db.profile.StatusBar.BarColor.g, NNGG.db.profile.StatusBar.BarColor.b, NNGG.db.profile.StatusBar.BarColor.a end
				},
				backgroundcolor = {
					type = "color",
					order = getOrder(),
					name = "Background Color",
					desc = "Set the background color of the status bar.",
					hasAlpha = true,
					set = function(info, r, g, b, a)
						NNGG.db.profile.StatusBar.BarBackgroundColor.r, NNGG.db.profile.StatusBar.BarBackgroundColor.g, NNGG.db.profile.StatusBar.BarBackgroundColor.b, NNGG.db.profile.StatusBar.BarBackgroundColor.a = r, g, b, a
						NNGG.SB_t:SetVertexColor(r, g, b, a)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.BarBackgroundColor.r, NNGG.db.profile.StatusBar.BarBackgroundColor.g, NNGG.db.profile.StatusBar.BarBackgroundColor.b, NNGG.db.profile.StatusBar.BarBackgroundColor.a end
				},
				FontOutline = {
					type = "select",
					order = getOrder(),
					name = "Font Outline",
					desc = "Set the font outline of the status bar text.",
					values = {
						[""] = "None",
						["OUTLINE"] = "Outline",
						["THICKOUTLINE"] = "Thick Outline",
					},
					set = function(info, value)
						NNGG.db.profile.StatusBar.FontOutline = value
						NNGG.SB_f.pulltext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
						NNGG.SB_f.timertext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
					end,
					get = function(info) return NNGG.db.profile.StatusBar.FontOutline end
				},
			}
		}
	}
}

function NNGG:ToggleFrames(toggle)
	if toggle then
		NNGG.A_f:Show()
		NNGG.RC_f:Show()
		NNGG.PT_f:Show()
	else
		NNGG.A_f:Hide()
		NNGG.RC_f:Hide()
		NNGG.PT_f:Hide()
	end
end

function NNGG:SetPullTimerMode(mode)
	if mode == "DBM" then
		NNGGPullTimerMode = false
		DBMPullTimerMode = true
		BWPullTimerMode = false
	elseif mode == "BW" then
		NNGGPullTimerMode = false
		DBMPullTimerMode = false
		BWPullTimerMode = true
	elseif mode == "NNGG" then
		NNGGPullTimerMode = true
		DBMPullTimerMode = false
		BWPullTimerMode = false
	end
end

local function isLeadOrAssist()
	if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
		return true
	end
	return false
end

local function isRaidWarningEligible()
	if UnitInRaid("player") and isLeadOrAssist() then
		return true
	end
	return false
end

local function isInPartyOrRaid()
	local unit
	if UnitInParty("player") and not UnitInRaid("player") then
		unit = "party"
	else
		unit = "raid"
	end
	return unit
end

local function inCombat()
	if not InCombatLockdown() and not IsEncounterInProgress() then
		return false
	end
	return true
end

local function getAddonChannel()
	local unit
	if isRaidWarningEligible() then
		unit = "RAID"
	elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		unit = "INSTANCE_CHAT"
	elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
		unit = "PARTY"
	end
	return unit
end


local function getUnit()
	local unit
	if isRaidWarningEligible() then
		unit = "RAID_WARNING"
	elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not UnitInRaid("player") then
		unit = "INSTANCE_CHAT"
	elseif IsInGroup(LE_PARTY_CATEGORY_HOME) and not UnitInRaid("player") then
		unit = "PARTY"
	else
		return nil
	end
	return unit
end

function NNGG:SetTestMode(enable)
	if enable then
		NNGG:ToggleFrames(true)
	else
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			if not inCombat() then
				NNGG:ToggleFrames(true)
			else
				NNGG:ToggleFrames(false)
			end
		else
			NNGG:ToggleFrames(false)
		end
	end
end

local function statusBarOnUpdate(self)
	local timeLeft = statusBarTimer - GetTime()
	if timeLeft and timeLeft > 0 then
		NNGG.SB_f:SetValue(timeLeft)
		NNGG.SB_f.pulltext:SetFormattedText("Pull in:")
		NNGG.SB_f.timertext:SetFormattedText("%.1f", timeLeft)
	else
		NNGG:ResetStatusBar()
	end
end

function NNGG:InitiateStatusBar(timer)
	if statusBar or statusBarTestMode then
		NNGG.SB_f:Show()
		NNGG.SB_f:SetMinMaxValues(0, timer)
		statusBarTimer = GetTime() + timer
		NNGG.SB_f:SetScript("OnUpdate", statusBarOnUpdate)
	end
end

function NNGG:ResetStatusBar()
	if statusBarTestMode then
		NNGG:InitiateStatusBar(12)
	else
		NNGG.SB_f:SetScript("OnUpdate", nil)
		NNGG.SB_f:Hide()
	end
end

local function sendSync(prefix, msg)
	msg = msg or ""
	SendAddonMessage("NoNoGoGo", prefix .. "\t" .. msg, getAddonChannel())
end

function NNGG:EnableCombatLogging()
	if logCombat and not autoLogging then
		print("|cffDA2820NoNoGoGo|r|cffFFFF00: Combat logging |cff77C8FFenabled|r|cffFFFF00.|r")
		LoggingCombat(true)
		autoLogging = true
	end
end

function NNGG:DisableCombatLogging()
	if not inCombat() then
		if logCombat and autoLogging then
			print("|cffDA2820NoNoGoGo|r|cffFFFF00: Combat logging |cff77C8FFdisabled|r|cffFFFF00.|r")
			LoggingCombat(false)
			autoLogging = false
		end
	end
end

function NNGG:ResetNNGGPullTimer()
	NNGG.RWPT_f:SetScript("OnUpdate", nil)
	NNGGPullTimerStarted = nil
	nnggPullTimerCount = nil
	updateInterval = 0
end

function NNGG:ResetPullTimer()
	NNGG.PT_f.pullTimerText:SetFormattedText("Pull Timer")
	addonName = nil
	pullTimerStarted = false
	timedResetStarted = false
end

function NNGG:StartTimedReset(timer)
	if readyCheckPassed then
		NNGG.RC_f.readyCheckText:SetFormattedText("Ready Check")
	end
	NNGG.PT_f.pullTimerText:SetFormattedText("Cancel")
	NNGG:CancelTimer(disableCombatLoggingTicker)
	NNGG:CancelTimer(resetPullTimerTicker)
	disableCombatLoggingTicker = NNGG:ScheduleTimer("DisableCombatLogging", timer + disableCombatLoggingDelay)
	resetPullTimerTicker = NNGG:ScheduleTimer("ResetPullTimer", timer)
	pullTimerStarted = true
	timedResetStarted = true
end

local function handleMessage(timer, addon, sender)
	if not tonumber(timer) then return end
	timer = tonumber(match(timer, "%d+"))
	if timer > 0 then
		if addon == "NoNoGoGo" then
			print("|cffDA2820NoNoGoGo|r|cffFFFF00: |r"..sender.." |cffFFFF00sent a pull timer!|r")
		end
		NNGG:StartTimedReset(timer)
		NNGG:InitiateStatusBar(timer)
		NNGG:EnableCombatLogging()
	else
		if addon == "NoNoGoGo" then
			print("|cffDA2820NoNoGoGo|r|cffFFFF00: |r"..sender.." |cffFFFF00cancelled the pull timer!|r")
		end
		NNGG:ResetPullTimer()
		NNGG:ResetNNGGPullTimer()
		NNGG:ResetStatusBar()
		NNGG:DisableCombatLogging()
	end
end

local function updateNNGGPullTimer(self, elapsed)
	local messg
	if not NNGGPullTimerStarted then
	 	NNGGPullTimerStarted = true
		messg = gsub("Pulling in $c sec.", "$c", nnggPullTimerCount)
		SendChatMessage(messg, getUnit())
	end
	updateInterval = updateInterval + elapsed
	if updateInterval >= 1 then
		nnggPullTimerCount = nnggPullTimerCount - 1
		if nnggPullTimerCount > 0 then
			messg = gsub(nnggPullTimerCount, "", "")
			SendChatMessage(messg, getUnit())
		else
			SendChatMessage("Pull now!", getUnit())
			NNGG:ResetNNGGPullTimer()
		end
		updateInterval = 0
    end
end

local function pullTimerOnEvent(self, event, prefix, message, channel, sender)
	if prefix == "D4" and sub(message, 1, 2) == "PT" then
		local _, timer = strsplit("\t", message)
		addonName = "DBM"
		handleMessage(timer, prefix, sender)
	elseif prefix == "BigWigs" then
		local bwPrefix, bwMsg = message:match("^(%u-):(.+)")
		if bwPrefix == "T" then
			local _, timer = strsplit("", bwMsg)
			addonName = "BW"
			handleMessage(timer, prefix, sender)
		end
	elseif prefix == "NoNoGoGo" and sub(message, 1, 2) == "PT" then
		local _, timer = strsplit("\t", message)
		addonName = "NNGG"
		handleMessage(timer, prefix, sender)
	end
end

local function combatCheck()
	if inCombat() then
		enableFramesTimer = NNGG:ScheduleTimer(combatCheck, 5)
	else
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			NNGG:ToggleFrames(true)
		end
	end
end

local function onPlayerRoleAssigned()
	if testMode then return end
	if not inCombat() then
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			NNGG:ToggleFrames(true)
		else
			NNGG:ToggleFrames(false)
		end
	else
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			if enableFramesTimer == nil then
				enableFramesTimer = NNGG:ScheduleTimer(combatCheck, 5)
			end
		end
	end
end

local function onPlayerRegenDisabled()
	if not testMode then
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			NNGG:CancelTimer(enableFramesTimer)
			enableFramesTimer = NNGG:ScheduleTimer(combatCheck, 5)
		end
		NNGG:ToggleFrames(false)
	end
end

local function onPlayerEnteringWorld()
	if not testMode and not inCombat() then
		if isLeadOrAssist() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			NNGG:ToggleFrames(true)
		else
			NNGG:ToggleFrames(false)
		end
	elseif inCombat() then
		enableFramesTimer = NNGG:ScheduleTimer(combatCheck, 5)
	end
end

local function pullTimerOnMouseDown(self, button)
	if button == "LeftButton" then
		if not pullTimerStarted and not timedResetStarted then
			if DBMPullTimerMode and IsAddOnLoaded("DBM-Core") and isLeadOrAssist() then
				SlashCmdList.DEADLYBOSSMODS("pull ".. pullTimerCount)
				pullTimerStarted = true
			elseif BWPullTimerMode and IsAddOnLoaded("BigWigs_Core") and isLeadOrAssist() then
				SlashCmdList.BIGWIGSPULL("".. pullTimerCount)
				pullTimerStarted = true
			elseif NNGGPullTimerMode and IsAddOnLoaded("NoNoGoGo") and UnitInParty("player") then
				if pullTimerCount >= 0 and pullTimerCount <= 10 then
					if getUnit() ~= nil then
						SlashCmdList.NONOGOGO("pull ".. pullTimerCount)
						pullTimerStarted = true
					else
						pullTimerStarted = false
						print("|cffDA2820NoNoGoGo|r|cffFFFF00: You must be leader or assistant.|r")
					end
				else
					print("|cffDA2820NoNoGoGo|r|cffFFFF00: The pull timer command must be between 0 and 10 seconds.|r")
				end
			end
		elseif pullTimerStarted and timedResetStarted then
			if addonName == "DBM" or addonName == "BW" then
				if IsAddOnLoaded("DBM-Core") then
					SlashCmdList.DEADLYBOSSMODS("pull 0")
					pullTimerStarted = false
				elseif IsAddOnLoaded("BigWigs_Core") then
					SlashCmdList.BIGWIGSPULL("0")
					pullTimerStarted = false
				end
			elseif addonName == "NNGG" and IsAddOnLoaded("NoNoGoGo") then
				SlashCmdList.NONOGOGO("pull 0")
				pullTimerStarted = false
			end
		end
	elseif button == "RightButton" then
		if not popupDialogShown then
			StaticPopup_Show("SET_PULL_TIMER")
			popupDialogShown = true
		else
			StaticPopup_Hide("SET_PULL_TIMER")
			popupDialogShown = false
		end
	end
end

local function readyCheckOnMouseDown(self, button)
	if button == "LeftButton" then
		DoReadyCheck()
	end
end

local function onAccept(self, seconds)
	popupDialogShown = false
	if not tonumber(seconds) then return end
	seconds = tonumber(seconds)
	if seconds >= 1 and seconds <= 60 then
		NNGG.db.global.PullTimerCount = seconds
		pullTimerCount = seconds
		print("|cffDA2820NoNoGoGo|r|cffFFFF00: Pull Timer set to:|r|cff77C8FF "..seconds.."|r |cff77C8FFseconds|r|cffFFFF00.|r")
	else
		print("|cffDA2820NoNoGoGo|r|cffFFFF00: The global pull timer must be between 1 and 60 seconds.|r")
	end
end

StaticPopupDialogs["SET_PULL_TIMER"] =
{
	text = "Set pull timer.",
	button1 = "Set",
	button2 = "Cancel",
	OnAccept = function(self)
		onAccept(self, self.editBox:GetText())
	end,
	OnCancel = function()
		popupDialogShown = false
	end,
	EditBoxOnEscapePressed = function(self)
		popupDialogShown = false
		self:GetParent():Hide()
	end,
	EditBoxOnEnterPressed = function(self)
		onAccept(self, self:GetParent().editBox:GetText())
		self:GetParent():Hide()
	end,
	maxLetters = 2,
	preferredIndex = 3,
	hasEditBox = true,
	whileDead = true,
}

local function pullCommandNNGG(seconds)
	if seconds > 0 then
		NNGG:ResetNNGGPullTimer()
		nnggPullTimerCount = seconds
		sendSync("PT", nnggPullTimerCount.."\t")
		NNGG.RWPT_f:SetScript("OnUpdate", updateNNGGPullTimer)
	elseif NNGGPullTimerStarted then
		NNGG:ResetNNGGPullTimer()
		nnggPullTimerCount = seconds
		sendSync("PT", nnggPullTimerCount.."\t")
	end
end

SLASH_NONOGOGO1 = "/nngg"
SlashCmdList["NONOGOGO"] = function(msg)
	local cmd = msg:lower()
	if cmd == "" then
		InterfaceOptionsFrame_OpenToCategory("NoNoGoGo")
		InterfaceOptionsFrame_OpenToCategory("NoNoGoGo")
		InterfaceOptionsFrame_OpenToCategory("NoNoGoGo")
	elseif cmd:sub(1, 4) == "pull" then
		if isRaidWarningEligible() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInGroup(LE_PARTY_CATEGORY_HOME) then
			local seconds = tonumber(cmd:sub(6))
			if not seconds or seconds ~= math.floor(seconds) then return end
			if seconds >= 0 and seconds <= 10 then
				if getUnit() ~= nil then
					pullCommandNNGG(seconds)
				else
					print("|cffDA2820NoNoGoGo|r|cffFFFF00: You must be leader or assistant.|r")
				end
			else
				print("|cffDA2820NoNoGoGo|r|cffFFFF00: The pull timer command must be between 0 and 10 seconds.|r")
			end
		end
	end
end

local function readyCheckFailed()
	NNGG.RC_f.readyCheckText:SetFormattedText("No response")
end

local function membersInGroup()
	local members
	-- While in a group determine amount of players in that group
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		members = GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE)
	elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
		members = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
	else return end

	-- While in an instance, check if the amount of members in the group exceeds instance limit,
	-- in that case set amount of members to instance limit
	if select(3, GetInstanceInfo()) ~= 0 then
		local maxMembers = select(5, GetInstanceInfo())
		if members > maxMembers then
			members = maxMembers
		end
	end
	return members
end

local function readyCheckOnEvent(self, event, id, response)
	if not UnitInRaid("player") then return end
	
	local unit = isInPartyOrRaid()
	local members = membersInGroup()
	
	if event=="READY_CHECK" then
		NNGG.RC_f.readyCheckText:SetFormattedText("Checking...")
		NNGG:CancelTimer(readyCheckFailedTicker)
		readyCheckPassed = false
		readyCheckCompleted = false
		readyCount = 0
		readyCountSelf = 0
		
		-- check for ready check initializer anywhere in group
		for i = 1, members do
			if readyCountSelf==0 then
				if UnitName(unit..i)==id:match("%a+") then
					readyCountSelf = 1
				end
			end
		end
	end
	
	if event=="READY_CHECK_FINISHED" then
		-- passed
		if readyCount+readyCountSelf==members then
			NNGG.RC_f.readyCheckText:SetFormattedText("Let's go")
			readyCheckPassed = true
			readyCheckCompleted = true
		elseif not readyCheckPassed and not readyCheckCompleted then
			readyCheckFailedTicker = NNGG:ScheduleTimer(readyCheckFailed, 1)
		end
	end
	
	if event=="READY_CHECK_CONFIRM" then
		-- Loop through the members and check if everyone is ready
		for i = 1, members do
			-- continue
			if id==unit..i and response==true then
				readyCount = readyCount + 1
			-- abort
			elseif id==unit..i and response==false then
				NNGG.RC_f.readyCheckText:SetFormattedText("Hold up")
				readyCheckCompleted = true
				return
			end
		end
		-- passed
		if readyCount+readyCountSelf==members then
			NNGG.RC_f.readyCheckText:SetFormattedText("Let's go")
			readyCheckPassed = true
			readyCheckCompleted = true
		end
	end
end

function NNGG:createFrames()
	-- Anchor frame
	NNGG.AA_f = CreateFrame("Frame", "NNGGAnchorAnchorFrame", UIParent)
	LW.RegisterConfig(NNGG.AA_f, NNGG.db.profile.AnchorFrame)
	LW.RestorePosition(NNGG.AA_f)
	LW.MakeDraggable(NNGG.AA_f)
	LW.EnableMouseOnAlt(NNGG.AA_f)
	NNGG.AA_f:SetFrameStrata("BACKGROUND")
	NNGG.AA_f:SetPoint("CENTER", NNGG.A_f)
	NNGG.AA_f:SetClampedToScreen(true)
	
	-- Backdrop frame
	NNGG.A_f = CreateFrame("Frame", "NNGGAnchorFrame", UIParent)
	NNGG.A_f:SetFrameStrata("BACKGROUND")
	NNGG.A_f:SetPoint("CENTER", NNGG.AA_f)
	NNGG.A_f:SetClampedToScreen(true)
	
	NNGG.A_t = NNGG.A_f:CreateTexture(nil, "BACKGROUND")
	NNGG.A_t:SetAllPoints(true)
	
	-- Ready Check frame
	NNGG.RC_f = CreateFrame("Button", "NNGGReadyCheckFrame", UIParent)
	NNGG.RC_f:SetFrameStrata("LOW")
	NNGG.RC_f:SetPoint("BOTTOM", NNGG.A_f, "BOTTOM", 0, NNGG.db.profile.AnchorBorder)
	NNGG.RC_f:RegisterForClicks("LeftButtonDown")
	NNGG.RC_f:SetClampedToScreen(true)
	NNGG.RC_f.readyCheckText = NNGG.RC_f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	NNGG.RC_f.readyCheckText:SetPoint("CENTER", NNGG.RC_f)
	NNGG.RC_f.readyCheckText:SetFormattedText("Ready Check")
	NNGG.RC_f:SetScript("OnMouseDown", readyCheckOnMouseDown)
	NNGG.RC_f:RegisterEvent("READY_CHECK_CONFIRM")
	NNGG.RC_f:RegisterEvent("READY_CHECK")
	NNGG.RC_f:RegisterEvent("READY_CHECK_FINISHED")
	NNGG.RC_f:SetScript("OnEvent", readyCheckOnEvent)
	NNGG.RC_f:SetHighlightTexture("interface\\addons\\NoNoGoGo\\textureHighlight.tga")
	
	NNGG.RC_t = NNGG.RC_f:CreateTexture(nil, "BACKGROUND")
	NNGG.RC_t:SetAllPoints(true)

   -- Pull Timer frame
	NNGG.PT_f = CreateFrame("Button", "NNGGPullTimerFrame", UIParent)
	NNGG.PT_f:SetFrameStrata("LOW")
	NNGG.PT_f:SetPoint("TOP", NNGG.A_f, "TOP", 0, -NNGG.db.profile.AnchorBorder)
	NNGG.PT_f:RegisterForClicks("LeftButtonDown")
	NNGG.PT_f:SetClampedToScreen(true)
	NNGG.PT_f.pullTimerText = NNGG.PT_f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	NNGG.PT_f.pullTimerText:SetPoint("CENTER", NNGG.PT_f)
	NNGG.PT_f.pullTimerText:SetFormattedText("Pull Timer")
	NNGG.PT_f:SetScript("OnMouseDown", pullTimerOnMouseDown)
	NNGG.PT_f:SetHighlightTexture("interface\\addons\\NoNoGoGo\\textureHighlight.tga")
	
	NNGG.PT_t = NNGG.PT_f:CreateTexture(nil, "BACKGROUND")
	NNGG.PT_t:SetAllPoints(true)

	-- Pull Timer Event frame
	NNGG.PTE_f = CreateFrame("Frame")
	NNGG.PTE_f:RegisterEvent("CHAT_MSG_ADDON")
	NNGG.PTE_f:SetScript("OnEvent", pullTimerOnEvent)
	
	-- Raid warning pull timer frame
	NNGG.RWPT_f = CreateFrame("Frame")

	-- Status Bar frame
	NNGG.SB_f = CreateFrame("StatusBar", "NNGGStatusBarFrame", UIParent)
	LW.RegisterConfig(NNGG.SB_f, NNGG.db.profile.StatusBarFrame)
	LW.RestorePosition(NNGG.SB_f)
	LW.MakeDraggable(NNGG.SB_f)
	LW.EnableMouseOnAlt(NNGG.SB_f)
	NNGG.SB_f:SetPoint("CENTER")
	NNGG.SB_f:SetClampedToScreen(true)
	NNGG.SB_f.pulltext = NNGG.SB_f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	NNGG.SB_f.pulltext:SetPoint("LEFT", NNGG.SB_f, "LEFT", 5, 0)
	NNGG.SB_f.timertext = NNGG.SB_f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	NNGG.SB_f.timertext:SetPoint("RIGHT", NNGG.SB_f, "RIGHT", -5, 0)
	
	NNGG.SB_t = NNGG.SB_f:CreateTexture(nil, "BACKGROUND")
	NNGG.SB_t:SetAllPoints(true)

	-- Status Bar Event frame
	NNGG.SBE_f = CreateFrame("Frame")
	NNGG.SBE_f:RegisterEvent("CHAT_MSG_ADDON")
	NNGG.SBE_f:SetScript("OnEvent", statusBarOnEvent)
	
	NNGG:RefreshSettings()
	
	NNGG.createFrames = nil
end

function NNGG:RefreshSettings()
	-- Anchor frame
	LW.RegisterConfig(NNGG.AA_f, NNGG.db.profile.AnchorFrame)
	LW.RestorePosition(NNGG.AA_f)
	NNGG.AA_f:SetWidth(NNGG.db.profile.AnchorWidth+10)
	NNGG.AA_f:SetHeight(NNGG.db.profile.AnchorHeight+10)
	
	-- Backdrop frame
	NNGG.A_f:SetWidth(NNGG.db.profile.AnchorWidth)
	NNGG.A_f:SetHeight(NNGG.db.profile.AnchorHeight)
	NNGG.A_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.Background))
	NNGG.A_t:SetVertexColor(NNGG.db.profile.BackgroundColor.r, NNGG.db.profile.BackgroundColor.g, NNGG.db.profile.BackgroundColor.b, NNGG.db.profile.BackgroundColor.a)

	-- Ready Check frame
	NNGG.RC_f:SetWidth(NNGG.db.profile.AnchorWidth-(NNGG.db.profile.AnchorBorder*2))
	NNGG.RC_f:SetHeight((NNGG.db.profile.AnchorHeight/2)-(NNGG.db.profile.AnchorBorder*1.5))
	NNGG.RC_f.readyCheckText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
	NNGG.RC_f.readyCheckText:SetTextColor(NNGG.db.profile.FontColor.r, NNGG.db.profile.FontColor.g, NNGG.db.profile.FontColor.b, NNGG.db.profile.FontColor.a)
	NNGG.RC_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.ButtonBackground))
	NNGG.RC_t:SetVertexColor(NNGG.db.profile.ButtonBackgroundColor.r, NNGG.db.profile.ButtonBackgroundColor.g, NNGG.db.profile.ButtonBackgroundColor.b, NNGG.db.profile.ButtonBackgroundColor.a)
	
	-- Pull Timer frame
	NNGG.PT_f:SetWidth(NNGG.db.profile.AnchorWidth-(NNGG.db.profile.AnchorBorder*2))
	NNGG.PT_f:SetHeight((NNGG.db.profile.AnchorHeight/2)-(NNGG.db.profile.AnchorBorder*1.5))
	NNGG.PT_f.pullTimerText:SetFont(LSM:Fetch("font", NNGG.db.profile.Font), NNGG.db.profile.FontSize, NNGG.db.profile.FontOutline)
	NNGG.PT_f.pullTimerText:SetTextColor(NNGG.db.profile.FontColor.r, NNGG.db.profile.FontColor.g, NNGG.db.profile.FontColor.b, NNGG.db.profile.FontColor.a)
	NNGG.PT_t:SetTexture(LSM:Fetch("background", NNGG.db.profile.ButtonBackground))
	NNGG.PT_t:SetVertexColor(NNGG.db.profile.ButtonBackgroundColor.r, NNGG.db.profile.ButtonBackgroundColor.g, NNGG.db.profile.ButtonBackgroundColor.b, NNGG.db.profile.ButtonBackgroundColor.a)
	
	-- Status Bar frame
	LW.RegisterConfig(NNGG.SB_f, NNGG.db.profile.StatusBarFrame)
	LW.RestorePosition(NNGG.SB_f)
	NNGG.SB_f:SetWidth(NNGG.db.profile.StatusBar.BarWidth)
	NNGG.SB_f:SetHeight(NNGG.db.profile.StatusBar.BarHeight)
	NNGG.SB_f.pulltext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
	NNGG.SB_f.pulltext:SetTextColor(NNGG.db.profile.StatusBar.FontColor.r, NNGG.db.profile.StatusBar.FontColor.g, NNGG.db.profile.StatusBar.FontColor.b, NNGG.db.profile.StatusBar.FontColor.a)
	NNGG.SB_f.timertext:SetFont(LSM:Fetch("font", NNGG.db.profile.StatusBar.Font), NNGG.db.profile.StatusBar.FontSize, NNGG.db.profile.StatusBar.FontOutline)
	NNGG.SB_f.timertext:SetTextColor(NNGG.db.profile.StatusBar.FontColor.r, NNGG.db.profile.StatusBar.FontColor.g, NNGG.db.profile.StatusBar.FontColor.b, NNGG.db.profile.StatusBar.FontColor.a)
	NNGG.SB_f:SetStatusBarTexture(LSM:Fetch("statusbar", NNGG.db.profile.StatusBar.BarTexture))
	NNGG.SB_f:SetStatusBarColor(NNGG.db.profile.StatusBar.BarColor.r, NNGG.db.profile.StatusBar.BarColor.g, NNGG.db.profile.StatusBar.BarColor.b, NNGG.db.profile.StatusBar.BarColor.a)
	
	NNGG.SB_t:SetTexture(LSM:Fetch("statusbar", NNGG.db.profile.StatusBar.BarBackgroundTexture))
	NNGG.SB_t:SetVertexColor(NNGG.db.profile.StatusBar.BarBackgroundColor.r, NNGG.db.profile.StatusBar.BarBackgroundColor.g, NNGG.db.profile.StatusBar.BarBackgroundColor.b, NNGG.db.profile.StatusBar.BarBackgroundColor.a)
end

function NNGG:OnInitialize()
	print("|cffDA2820NoNoGoGo|r|cffFFFF00:|r |cff00FF00/nngg|r |cffFFFF00for options.|r")
	NNGG.db = ADB:New("NoNoGoGoDB", defaults, true)
	InterfaceOptions_AddCategory("NoNoGoGo")
	ACD:AddToBlizOptions("NoNoGoGo")
	ACD:AddToBlizOptions("NoNoGoGoProfiles", "Profiles", "NoNoGoGo")
	AC:RegisterOptionsTable("NoNoGoGo", options)
	AC:RegisterOptionsTable("NoNoGoGoProfiles", ADBO:GetOptionsTable(NNGG.db))
	LDS:EnhanceDatabase(NNGG.db, "NoNoGoGoDB")
	LDS:EnhanceOptions(ADBO:GetOptionsTable(NNGG.db), NNGG.db)
	NNGG.db.RegisterCallback(self, "OnProfileChanged", "RefreshSettings")
	NNGG.db.RegisterCallback(self, "OnProfileCopied", "RefreshSettings")
	NNGG.db.RegisterCallback(self, "OnProfileReset", "RefreshSettings")
	RegisterAddonMessagePrefix("D4")
	RegisterAddonMessagePrefix("BigWigs")
	RegisterAddonMessagePrefix("NoNoGoGo")
	NNGG:RegisterEvent("PLAYER_REGEN_DISABLED", onPlayerRegenDisabled)
	NNGG:RegisterEvent("PLAYER_ENTERING_WORLD", onPlayerEnteringWorld)
	NNGG:RegisterEvent("PLAYER_ROLES_ASSIGNED", onPlayerRoleAssigned)
	initializeLocalVars()
	NNGG:createFrames()
	NNGG:ResetStatusBar()
	NNGG:SetPullTimerMode(NNGG.db.global.PullTimerMode)
	
	NNGG.OnInitialize = nil
end