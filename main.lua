---@class KeystoneRoulette : AceAddon, AceEvent-3.0, AceTimer-3.0
local KeystoneRoulette = LibStub('AceAddon-3.0'):NewAddon('Libs-KeystoneRoulette', 'AceEvent-3.0', 'AceTimer-3.0')
local LDB = LibStub('LibDataBroker-1.1')
local LDBIcon = LibStub('LibDBIcon-1.0')
local LSM = LibStub('LibSharedMedia-3.0')

-- Register addon sounds with LibSharedMedia
LSM:Register('sound', 'KR: Brass Horn Fanfare', [[Interface\AddOns\Libs-KeystoneRoulette\sounds\brass-horn-fanfare.mp3]])
LSM:Register('sound', 'KR: Arcade Game Victory', [[Interface\AddOns\Libs-KeystoneRoulette\sounds\arcade-game-victory.mp3]])
LSM:Register('sound', 'KR: Meme Fail Alert', [[Interface\AddOns\Libs-KeystoneRoulette\sounds\meme-fail-alert.mp3]])

-- Make addon globally accessible
_G.KeystoneRoulette = KeystoneRoulette

-- Debug flag (disabled in release builds)
local debug = false
--@do-not-package@
debug = true
--@end-do-not-package@

-- Initialize logger if Libs-AddonTools is available
if LibAT and LibAT.Logger and debug then
	KeystoneRoulette.logger = LibAT.Logger.RegisterAddon('Libs-KeystoneRoulette')
end

---@type table<string, string> Dungeon name to abbreviation mapping
KeystoneRoulette.DungeonAbbreviations = {
	-- Season 2 TWW
	['Cinderbrew Meadery'] = 'BREW',
	['Darkflame Cleft'] = 'DFC',
	['Operation: Floodgate'] = 'FLOOD',
	['The MOTHERLODE!!'] = 'ML',
	['Priory of the Sacred Flame'] = 'PSF',
	['The Rookery'] = 'ROOK',
	['Theater of Pain'] = 'TOP',
	['Operation: Mechagon - Workshop'] = 'WORK',
	-- Previous seasons (keep for compatibility)
	['Ara-Kara, City of Echoes'] = 'ARAK',
	['City of Threads'] = 'COT',
	['The Stonevault'] = 'SV',
	['The Dawnbreaker'] = 'DAWN',
	['Mists of Tirna Scithe'] = 'MISTS',
	['The Necrotic Wake'] = 'NW',
	['Grim Batol'] = 'GB',
	['Siege of Boralus'] = 'SOB',
}

---Get abbreviated dungeon name
---@param dungeonName string Full dungeon name
---@return string Abbreviated name or uppercase original
function KeystoneRoulette:GetDungeonAbbreviation(dungeonName)
	if not dungeonName then
		return '???'
	end
	local abbrev = self.DungeonAbbreviations[dungeonName]
	if abbrev then
		return abbrev
	end
	-- Fallback: uppercase the name
	return string.upper(dungeonName)
end

---@class KeystoneRoulette.KeystoneData
---@field player string Player name (without realm for display)
---@field playerFull string Player name with realm
---@field dungeonName string Full dungeon name
---@field dungeonAbbrev string Abbreviated dungeon name
---@field level number Keystone level
---@field classID number Player class ID
---@field rating number Player M+ rating
---@field tooltip string Full tooltip text

-- Test mode flag (set via /ksr test)
KeystoneRoulette.testMode = false

---Generate fake keystone data for testing
---@return KeystoneRoulette.KeystoneData[]
function KeystoneRoulette:GetFakeKeystoneData()
	local fakeData = {
		{ player = 'Tankyboi', dungeonName = 'Priory of the Sacred Flame', level = 12, classID = 6 }, -- DK
		{ player = 'Healzalot', dungeonName = 'Cinderbrew Meadery', level = 10, classID = 5 }, -- Priest
		{ player = 'Stabsworth', dungeonName = 'Theater of Pain', level = 8, classID = 4 }, -- Rogue
		{ player = 'Pewpewmage', dungeonName = 'Operation: Floodgate', level = 11, classID = 8 }, -- Mage
		{ player = 'Naturebro', dungeonName = 'The Rookery', level = 9, classID = 11 }, -- Druid
	}

	local keystones = {}
	for _, data in ipairs(fakeData) do
		table.insert(keystones, {
			player = data.player,
			playerFull = data.player .. '-TestRealm',
			dungeonName = data.dungeonName,
			dungeonAbbrev = self:GetDungeonAbbreviation(data.dungeonName),
			level = data.level,
			classID = data.classID,
			rating = math.random(1500, 3000),
			tooltip = data.dungeonName .. ' +' .. data.level,
		})
	end

	return keystones
end

---Get keystone data for wheel display
---@return KeystoneRoulette.KeystoneData[]
function KeystoneRoulette:GetKeystoneData()
	-- Return fake data if test mode is enabled
	if self.testMode then
		if self.logger then
			self.logger.debug('Test mode active, returning fake keystone data')
		end
		return self:GetFakeKeystoneData()
	end

	local keystones = {}
	local openRaidLib = LibStub:GetLibrary('LibOpenRaid-1.0', true)

	if self.logger then
		self.logger.debug('Fetching keystone data...')
		self.logger.debug('  LibOpenRaid available: ' .. tostring(openRaidLib ~= nil))
		self.logger.debug('  In group: ' .. tostring(IsInGroup()) .. ', In raid: ' .. tostring(IsInRaid()))
		self.logger.debug('  Group size: ' .. tostring(GetNumGroupMembers()))
	end

	-- Try LibOpenRaid first
	if openRaidLib then
		local allKeystoneInfo = openRaidLib.GetAllKeystonesInfo()
		local totalFromLib = 0
		local includedCount = 0

		if allKeystoneInfo then
			for playerName, keystoneInfo in pairs(allKeystoneInfo) do
				totalFromLib = totalFromLib + 1
				if keystoneInfo.level and keystoneInfo.level > 0 then
					local shortName = strsplit('-', playerName)
					local isInParty = UnitInParty(shortName)
					local isSelf = shortName == UnitName('player')

					if isInParty or isSelf then
						local dungeonName = ''
						if keystoneInfo.mythicPlusMapID then
							dungeonName = C_ChallengeMode.GetMapUIInfo(keystoneInfo.mythicPlusMapID) or ''
						end

						table.insert(keystones, {
							player = shortName,
							playerFull = playerName,
							dungeonName = dungeonName,
							dungeonAbbrev = self:GetDungeonAbbreviation(dungeonName),
							level = keystoneInfo.level,
							classID = keystoneInfo.classID or 1,
							rating = keystoneInfo.rating or 0,
							tooltip = dungeonName .. ' +' .. keystoneInfo.level,
						})
						includedCount = includedCount + 1

						if self.logger then
							self.logger.debug('  + Added: ' .. shortName .. ' - ' .. dungeonName .. ' +' .. keystoneInfo.level)
						end
					elseif self.logger then
						self.logger.debug('  - Skipped (not in party): ' .. playerName)
					end
				elseif self.logger then
					self.logger.debug('  - Skipped (no key or level 0): ' .. playerName)
				end
			end
		end

		if self.logger then
			self.logger.debug('LibOpenRaid results: ' .. totalFromLib .. ' total, ' .. includedCount .. ' included')
		end
	end

	-- Fallback: get own keystone if no data from LibOpenRaid
	if #keystones == 0 then
		if self.logger then
			self.logger.debug('No LibOpenRaid data, trying local keystone API...')
		end

		local ownLevel = C_MythicPlus.GetOwnedKeystoneLevel()
		local ownMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

		if self.logger then
			self.logger.debug('  Own keystone level: ' .. tostring(ownLevel))
			self.logger.debug('  Own keystone mapID: ' .. tostring(ownMapID))
		end

		if ownLevel and ownLevel > 0 and ownMapID then
			local dungeonName = C_ChallengeMode.GetMapUIInfo(ownMapID) or ''
			local _, classFile, classID = UnitClass('player')
			table.insert(keystones, {
				player = UnitName('player'),
				playerFull = UnitName('player') .. '-' .. GetRealmName(),
				dungeonName = dungeonName,
				dungeonAbbrev = self:GetDungeonAbbreviation(dungeonName),
				level = ownLevel,
				classID = classID or 1,
				rating = 0,
				tooltip = dungeonName .. ' +' .. ownLevel,
			})

			if self.logger then
				self.logger.debug('  + Added own keystone: ' .. dungeonName .. ' +' .. ownLevel)
			end
		elseif self.logger then
			self.logger.debug('  No personal keystone found')
		end
	end

	-- Sort by level descending
	table.sort(keystones, function(a, b)
		return a.level > b.level
	end)

	if self.logger then
		self.logger.info('Keystone fetch complete: ' .. #keystones .. ' keystones found')
	end

	return keystones
end

---Request keystone data from party members
function KeystoneRoulette:RequestKeystoneData()
	local openRaidLib = LibStub:GetLibrary('LibOpenRaid-1.0', true)
	if openRaidLib then
		if IsInRaid() then
			if self.logger then
				self.logger.debug('Requesting keystone data from raid (' .. GetNumGroupMembers() .. ' members)')
			end
			openRaidLib.RequestKeystoneDataFromRaid()
		elseif IsInGroup() then
			if self.logger then
				self.logger.debug('Requesting keystone data from party (' .. GetNumGroupMembers() .. ' members)')
			end
			openRaidLib.RequestKeystoneDataFromParty()
		elseif self.logger then
			self.logger.debug('Not in group, skipping keystone request')
		end
	elseif self.logger then
		self.logger.warning('LibOpenRaid not available, cannot request party keystones')
	end
end

---Setup AceConfig options
---@return table
local function GetOptions()
	return {
		name = "Lib's - Keystone Roulette",
		type = 'group',
		get = function(info)
			return KeystoneRoulette.db[info[#info]]
		end,
		set = function(info, value)
			KeystoneRoulette.db[info[#info]] = value
		end,
		args = {
			description = {
				type = 'description',
				name = 'A fun wheel-of-fortune style random keystone selector for M+ groups.\n\nUse |cff00ff00/ksr|r or |cff00ff00/keystoneroulette|r to open the wheel.',
				order = 1,
				fontSize = 'medium',
			},
			spinHeader = {
				type = 'header',
				name = 'Wheel Settings',
				order = 10,
			},
			spinDuration = {
				type = 'range',
				name = 'Spin Duration',
				desc = 'How long the wheel should spin (in seconds)',
				order = 11,
				min = 1,
				max = 30,
				step = 1,
				width = 'full',
			},
			announceWinner = {
				type = 'toggle',
				name = 'Announce Winner',
				desc = 'Announce the selected keystone in party chat',
				order = 12,
				width = 'full',
			},
			soundHeader = {
				type = 'header',
				name = 'Sound',
				order = 14,
			},
			soundEnabled = {
				type = 'toggle',
				name = 'Enable Sound',
				desc = 'Play a sound when the wheel spins and when a winner is selected',
				order = 15,
				width = 'full',
			},
			soundName = {
				type = 'select',
				dialogControl = 'LSM30_Sound',
				name = 'Sound',
				desc = 'Sound to play for spin events',
				order = 16,
				width = 'double',
				disabled = function()
					return not KeystoneRoulette.db.soundEnabled
				end,
				values = function()
					return LSM:HashTable('sound')
				end,
			},
			minimapHeader = {
				type = 'header',
				name = 'Minimap Button',
				order = 20,
			},
			minimapButton = {
				type = 'toggle',
				name = 'Show Minimap Button',
				desc = 'Display a minimap button to open the keystone roulette',
				order = 21,
				width = 'full',
				get = function()
					return not KeystoneRoulette.dbobj.profile.minimap.hide
				end,
				set = function(_, value)
					KeystoneRoulette.dbobj.profile.minimap.hide = not value
					if value then
						LDBIcon:Show('Libs Keystone Roulette')
					else
						LDBIcon:Hide('Libs Keystone Roulette')
					end
				end,
			},
		},
	}
end

function KeystoneRoulette:OnInitialize()
	---@class KeystoneRoulette.DB
	local databaseDefaults = {
		spinDuration = 5,
		announceWinner = true,
		soundEnabled = true,
		soundName = 'KR: Brass Horn Fanfare',
		minimap = {
			hide = false,
		},
	}

	-- Setup database
	self.dbobj = LibStub('AceDB-3.0'):New('LibsKeystoneRouletteDB', { profile = databaseDefaults })
	self.db = self.dbobj.profile ---@type KeystoneRoulette.DB

	-- Create options table
	self.OptTable = GetOptions()

	-- Register options with AceConfig
	LibStub('AceConfig-3.0'):RegisterOptionsTable('Libs-KeystoneRoulette', function()
		return self.OptTable
	end)
	local _, categoryID = LibStub('AceConfigDialog-3.0'):AddToBlizOptions('Libs-KeystoneRoulette', "Lib's - Keystone Roulette")
	self.settingsCategoryID = categoryID

	-- Create LibDataBroker object for minimap button
	local ldbObject = LDB:NewDataObject('Libs Keystone Roulette', {
		type = 'data source',
		text = 'Keystone Roulette',
		icon = 'Interface/Icons/inv_relics_hourglass',
		OnClick = function(_, button)
			if button == 'LeftButton' then
				self:ToggleWheel()
			elseif button == 'RightButton' then
				if self.settingsCategoryID then
					Settings.OpenToCategory(self.settingsCategoryID)
				end
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine("|cffFFFFFFLib's - Keystone Roulette|r")
			tooltip:AddLine(' ')
			tooltip:AddLine('|cff00FF00Left Click:|r Open Roulette Wheel')
			tooltip:AddLine('|cff00FF00Right Click:|r Open Options')
		end,
	})

	-- Register minimap icon
	LDBIcon:Register('Libs Keystone Roulette', ldbObject, self.db.minimap)

	-- Register slash commands
	SLASH_KEYSTONEROULETTE1 = '/ksr'
	SLASH_KEYSTONEROULETTE2 = '/keystoneroulette'
	SlashCmdList['KEYSTONEROULETTE'] = function(msg)
		if msg == 'options' or msg == 'config' then
			if self.settingsCategoryID then
				Settings.OpenToCategory(self.settingsCategoryID)
			end
		elseif msg == 'test' then
			self.testMode = not self.testMode
			if self.testMode then
				print('|cff00ff00Keystone Roulette:|r Test mode |cff00ff00ENABLED|r - using fake data')
			else
				print('|cff00ff00Keystone Roulette:|r Test mode |cffff0000DISABLED|r - using real data')
			end
			-- Refresh wheel if visible
			if self.WheelFrame and self.WheelFrame:IsShown() then
				self.WheelFrame:RefreshKeystones()
			end
		else
			self:ToggleWheel()
		end
	end

	if self.logger then
		self.logger.info('Libs-KeystoneRoulette initialized')
	end
end

function KeystoneRoulette:OnEnable()
	-- Register LibOpenRaid callback for keystone updates
	local openRaidLib = LibStub:GetLibrary('LibOpenRaid-1.0', true)
	if openRaidLib then
		openRaidLib.RegisterCallback(self, 'KeystoneUpdate', 'OnKeystoneUpdate')
	end

	-- Register events
	self:RegisterEvent('GROUP_ROSTER_UPDATE', 'OnGroupRosterUpdate')

	if self.logger then
		self.logger.info('Libs-KeystoneRoulette enabled')
	end
end

---Handle keystone update from LibOpenRaid
---@param unitName string
---@param keystoneInfo table
---@param allKeystoneInfo table
function KeystoneRoulette:OnKeystoneUpdate(unitName, keystoneInfo, allKeystoneInfo)
	-- Update wheel if it's visible
	if self.WheelFrame and self.WheelFrame:IsShown() then
		self.WheelFrame:RefreshKeystones()
	end
end

---Handle group roster changes
function KeystoneRoulette:OnGroupRosterUpdate()
	-- Request keystone data when group changes
	self:ScheduleTimer('RequestKeystoneData', 1)
end

---Toggle the wheel window
function KeystoneRoulette:ToggleWheel()
	if not self.WheelFrame then
		self:CreateWheelFrame()
	end

	if self.WheelFrame:IsShown() then
		self.WheelFrame:Hide()
	else
		-- Request fresh keystone data
		self:RequestKeystoneData()
		self.WheelFrame:Show()
		self.WheelFrame:RefreshKeystones()
	end
end

---Announce winner in party chat
---@param keystone KeystoneRoulette.KeystoneData
function KeystoneRoulette:AnnounceWinner(keystone)
	if not self.db.announceWinner then
		return
	end
	if not IsInGroup() then
		return
	end

	local chatType = IsInRaid() and 'RAID' or 'PARTY'
	SendChatMessage('~~~~~~ KEYSTONE ROULETTE HAS SPOKEN! ~~~~~~', chatType)
	SendChatMessage("It's time for " .. keystone.player .. ' to warm up their key!', chatType)
	SendChatMessage(keystone.dungeonName .. ' +' .. keystone.level, chatType)
	SendChatMessage('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', chatType)
end
