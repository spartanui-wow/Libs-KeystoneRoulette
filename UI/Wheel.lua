---@type KeystoneRoulette
local KeystoneRoulette = _G.KeystoneRoulette
local LSM = LibStub('LibSharedMedia-3.0')

-- Wheel constants
local WHEEL_RADIUS = 65 -- Distance from center to keystone icons
local WHEEL_SIZE = 150 -- Diameter of wheel background
local KEYSTONE_SIZE = 35 -- Size of each keystone icon
local WINDOW_WIDTH = 250
local WINDOW_HEIGHT = 320

---@class KeystoneRoulette.WheelFrame : Frame
---@field keystoneFrames table[]
---@field keystoneData KeystoneRoulette.KeystoneData[]
---@field spinning boolean
---@field spinProgress number
---@field spinStartTime number
---@field selectedIndex number
---@field wheelCenter Frame
---@field pointer Frame
---@field spinButton Button
---@field resultFrame Frame
---@field resultText FontString

---Play the configured wheel sound
function KeystoneRoulette:PlayWheelSound()
	if not self.db.soundEnabled then
		return
	end

	local soundFile = LSM:Fetch('sound', self.db.soundName or 'None')
	if soundFile and soundFile ~= 'None' then
		PlaySoundFile(soundFile, 'Master')
	end
end

---Create the main wheel frame
function KeystoneRoulette:CreateWheelFrame()
	if self.WheelFrame then
		return
	end

	-- Main window frame
	local frame = CreateFrame('Frame', 'KeystoneRouletteFrame', UIParent, 'BackdropTemplate')
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	frame:SetFrameStrata('DIALOG')
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)

	-- Backdrop styling
	frame:SetBackdrop({
		bgFile = 'Interface/Tooltips/UI-Tooltip-Background',
		edgeFile = 'Interface/Tooltips/UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

	-- Title bar
	local titleBar = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
	titleBar:SetHeight(28)
	titleBar:SetPoint('TOPLEFT', frame, 'TOPLEFT', 4, -4)
	titleBar:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -4, -4)
	titleBar:SetBackdrop({
		bgFile = 'Interface/Tooltips/UI-Tooltip-Background',
	})
	titleBar:SetBackdropColor(0.2, 0.2, 0.2, 1)

	local titleText = titleBar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	titleText:SetPoint('CENTER', titleBar, 'CENTER', 0, 0)
	titleText:SetText('Keystone Roulette')
	titleText:SetTextColor(1, 0.82, 0)

	-- Close button
	local closeButton = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
	closeButton:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
	closeButton:SetScript('OnClick', function()
		frame:Hide()
	end)

	-- Wheel background (dark circle)
	local wheelBack = frame:CreateTexture(nil, 'BACKGROUND')
	wheelBack:SetTexture('Interface/AddOns/WeakAuras/Media/Textures/Circle_White')
	wheelBack:SetVertexColor(0.13, 0.13, 0.13, 1)
	wheelBack:SetSize(WHEEL_SIZE - 30, WHEEL_SIZE - 30)
	wheelBack:SetPoint('CENTER', frame, 'CENTER', 0, 20)

	-- Wheel frame decoration
	local wheelFrame = frame:CreateTexture(nil, 'ARTWORK')
	wheelFrame:SetAtlas('Azerite-TitanBG-GearRank5-Front')
	wheelFrame:SetSize(WHEEL_SIZE, WHEEL_SIZE)
	wheelFrame:SetPoint('CENTER', frame, 'CENTER', 0, 20)
	frame.wheelDecoration = wheelFrame

	-- Center point for positioning keystones
	local wheelCenter = CreateFrame('Frame', nil, frame)
	wheelCenter:SetSize(1, 1)
	wheelCenter:SetPoint('CENTER', frame, 'CENTER', 0, 20)
	frame.wheelCenter = wheelCenter

	-- Ticker/Pointer on the right side
	local pointerBack = frame:CreateTexture(nil, 'OVERLAY')
	pointerBack:SetAtlas('Azerite-CenterBG-3Ranks')
	pointerBack:SetSize(50, 60)
	pointerBack:SetPoint('CENTER', wheelCenter, 'CENTER', 80, 0)
	pointerBack:SetRotation(math.rad(90))

	local pointer = frame:CreateTexture(nil, 'OVERLAY', nil, 1)
	pointer:SetTexture('Interface/AddOns/WeakAuras/PowerAurasMedia/Auras/Aura117')
	pointer:SetAtlas('orderhalltalents-prerequisite-arrow')
	pointer:SetSize(40, 50)
	pointer:SetPoint('CENTER', wheelCenter, 'CENTER', 80, 0)
	pointer:SetVertexColor(1, 0, 0.03, 1)
	frame.pointer = pointer

	-- Spin button in center
	local spinButton = CreateFrame('Button', nil, frame)
	spinButton:SetSize(40, 40)
	spinButton:SetPoint('CENTER', wheelCenter, 'CENTER', 0, 0)
	spinButton:SetNormalTexture('128-redbutton-refresh')
	spinButton:SetHighlightTexture('128-redbutton-refresh')
	spinButton:GetHighlightTexture():SetAlpha(0.3)
	spinButton:SetScript('OnClick', function()
		self:StartSpin()
	end)
	spinButton:SetScript('OnEnter', function(btn)
		GameTooltip:SetOwner(btn, 'ANCHOR_RIGHT')
		GameTooltip:AddLine('Click to Spin!')
		GameTooltip:Show()
	end)
	spinButton:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	frame.spinButton = spinButton

	-- Settings button (gear icon above result area)
	local settingsButton = CreateFrame('Button', nil, frame)
	settingsButton:SetSize(24, 24)
	settingsButton:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -15, 85)
	settingsButton:SetNormalAtlas('Warfronts-BaseMapIcons-Empty-Workshop-Minimap-small')
	settingsButton:SetHighlightAtlas('Warfronts-BaseMapIcons-Alliance-Workshop-Minimap')
	settingsButton:SetPushedAtlas('Warfronts-BaseMapIcons-Horde-Workshop-Minimap')
	settingsButton:SetScript('OnClick', function()
		-- Use the category ID stored during registration
		if KeystoneRoulette.settingsCategoryID then
			Settings.OpenToCategory(KeystoneRoulette.settingsCategoryID)
		end
	end)
	settingsButton:SetScript('OnEnter', function(btn)
		GameTooltip:SetOwner(btn, 'ANCHOR_RIGHT')
		GameTooltip:AddLine('Settings')
		GameTooltip:Show()
	end)
	settingsButton:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	frame.settingsButton = settingsButton

	-- Result display area
	local resultFrame = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
	resultFrame:SetSize(WINDOW_WIDTH - 20, 70)
	resultFrame:SetPoint('BOTTOM', frame, 'BOTTOM', 0, 10)
	resultFrame:SetBackdrop({
		bgFile = 'Interface/Tooltips/UI-Tooltip-Background',
		edgeFile = 'Interface/Tooltips/UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	resultFrame:SetBackdropColor(0.15, 0.15, 0.15, 1)
	resultFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	frame.resultFrame = resultFrame

	local resultText = resultFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	resultText:SetPoint('CENTER', resultFrame, 'CENTER', 0, 0)
	resultText:SetText('Press SPIN to select a keystone!')
	resultText:SetJustifyH('CENTER')
	resultText:SetWidth(WINDOW_WIDTH - 30)
	frame.resultText = resultText

	-- Initialize state
	frame.keystoneFrames = {}
	frame.keystoneData = {}
	frame.spinning = false
	frame.spinProgress = 0
	frame.selectedIndex = 0

	-- Add methods
	frame.RefreshKeystones = function(self)
		KeystoneRoulette:RefreshWheelKeystones()
	end

	-- OnUpdate for animation
	frame:SetScript('OnUpdate', function(self, elapsed)
		KeystoneRoulette:OnWheelUpdate(elapsed)
	end)

	-- Hide initially
	frame:Hide()

	self.WheelFrame = frame
end

---Create a keystone icon frame for the wheel
---@param index number
---@return Frame
function KeystoneRoulette:CreateKeystoneFrame(index)
	local parent = self.WheelFrame.wheelCenter
	local frame = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	frame:SetSize(KEYSTONE_SIZE, KEYSTONE_SIZE)

	-- Icon background
	local icon = frame:CreateTexture(nil, 'BACKGROUND')
	icon:SetTexture(525134) -- Keystone icon
	icon:SetAllPoints()
	frame.icon = icon

	-- Border
	frame:SetBackdrop({
		edgeFile = 'Interface/Tooltips/UI-Tooltip-Border',
		edgeSize = 8,
	})
	frame:SetBackdropBorderColor(0, 0, 0, 1)

	-- Player name (top)
	local playerText = frame:CreateFontString(nil, 'OVERLAY')
	playerText:SetFont('Fonts/ARIALN.TTF', 11, 'OUTLINE')
	playerText:SetPoint('TOP', frame, 'TOP', 0, 12)
	playerText:SetTextColor(1, 1, 1, 1)
	frame.playerText = playerText

	-- Level (center)
	local levelText = frame:CreateFontString(nil, 'OVERLAY')
	levelText:SetFont('Fonts/ARIALN.TTF', 18, 'OUTLINE')
	levelText:SetPoint('CENTER', frame, 'CENTER', 0, 0)
	levelText:SetTextColor(1, 1, 1, 1)
	frame.levelText = levelText

	-- Dungeon abbreviation (bottom)
	local dungeonText = frame:CreateFontString(nil, 'OVERLAY')
	dungeonText:SetFont('Fonts/ARIALN.TTF', 10, 'OUTLINE')
	dungeonText:SetPoint('BOTTOM', frame, 'BOTTOM', 0, -10)
	dungeonText:SetTextColor(1, 0.82, 0, 1)
	frame.dungeonText = dungeonText

	-- Tooltip
	frame:EnableMouse(true)
	frame:SetScript('OnEnter', function(self)
		if self.keystoneData then
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:AddLine(self.keystoneData.tooltip)
			GameTooltip:AddLine(self.keystoneData.player, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	frame:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	return frame
end

---Refresh keystone data and update wheel display
function KeystoneRoulette:RefreshWheelKeystones()
	local frame = self.WheelFrame
	if not frame then
		return
	end

	if self.logger then
		self.logger.debug('Refreshing wheel display...')
	end

	-- Get fresh keystone data
	frame.keystoneData = self:GetKeystoneData()

	-- Hide all existing keystone frames
	for _, ksFrame in ipairs(frame.keystoneFrames) do
		ksFrame:Hide()
	end

	-- Create/update frames for each keystone
	local count = #frame.keystoneData
	if count == 0 then
		frame.resultText:SetText('No keystones found!\nJoin a party or get a keystone.')
		frame.spinButton:Hide()
		if self.logger then
			self.logger.warning('Wheel refresh: No keystones to display')
		end
		return
	end

	frame.spinButton:Show()
	frame.resultText:SetText('Press SPIN to select a keystone!')

	if self.logger then
		self.logger.debug('Wheel refresh: Displaying ' .. count .. ' keystones')
	end

	for i, keystone in ipairs(frame.keystoneData) do
		-- Create frame if needed
		if not frame.keystoneFrames[i] then
			frame.keystoneFrames[i] = self:CreateKeystoneFrame(i)
		end

		local ksFrame = frame.keystoneFrames[i]
		ksFrame.keystoneData = keystone
		ksFrame.index = i

		-- Update display
		ksFrame.playerText:SetText(keystone.player)
		ksFrame.levelText:SetText('+' .. keystone.level)
		ksFrame.dungeonText:SetText(keystone.dungeonAbbrev)

		-- Set class color for player name
		local classColor = C_ClassColor.GetClassColor(GetClassInfo(keystone.classID))
		if classColor then
			ksFrame.playerText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
		end

		ksFrame:Show()
	end

	-- Position keystones around the wheel
	self:PositionKeystones(frame.spinProgress)
end

---Position keystones around the wheel based on current spin progress
---@param progress number Current spin progress (0-1 per rotation)
function KeystoneRoulette:PositionKeystones(progress)
	local frame = self.WheelFrame
	if not frame then
		return
	end

	local count = #frame.keystoneData
	if count == 0 then
		return
	end

	local radians = 2 * math.pi
	local chunkSize = radians / count
	local baseAngle = progress * radians

	for i, ksFrame in ipairs(frame.keystoneFrames) do
		if ksFrame:IsShown() then
			local angleOffset = (i - 1) * chunkSize
			local angle = baseAngle + angleOffset

			local x = WHEEL_RADIUS * math.cos(angle)
			local y = WHEEL_RADIUS * math.sin(angle)

			ksFrame:SetPoint('CENTER', frame.wheelCenter, 'CENTER', x, y)
		end
	end
end

---Start the wheel spin
function KeystoneRoulette:StartSpin()
	local frame = self.WheelFrame
	if not frame or frame.spinning then
		if self.logger then
			self.logger.debug('Spin blocked: ' .. (frame.spinning and 'already spinning' or 'no frame'))
		end
		return
	end

	local count = #frame.keystoneData
	if count == 0 then
		if self.logger then
			self.logger.warning('Spin blocked: no keystones on wheel')
		end
		return
	end

	-- Pick random winner
	-- Burn a variable number of random calls based on time to improve distribution
	local burnCount = math.floor(GetTime() * 1000) % 10 + 1
	for i = 1, burnCount do
		math.random()
	end
	frame.selectedIndex = math.random(1, count)
	frame.spinning = true
	frame.spinStartTime = GetTime()
	frame.spinProgress = 0

	-- Hide spin button during spin
	frame.spinButton:Hide()

	-- Update result text
	frame.resultText:SetText('Spinning...')

	local winner = frame.keystoneData[frame.selectedIndex]
	if self.logger then
		self.logger.info('Spin started!')
		self.logger.debug('  Keystones on wheel: ' .. count)
		self.logger.debug('  Spin duration: ' .. self.db.spinDuration .. 's')
		self.logger.debug('  Pre-selected winner: ' .. winner.player .. ' - ' .. winner.dungeonName .. ' +' .. winner.level)
	end
end

---Handle wheel update (animation)
---@param elapsed number
function KeystoneRoulette:OnWheelUpdate(elapsed)
	local frame = self.WheelFrame
	if not frame or not frame.spinning then
		return
	end

	local duration = self.db.spinDuration
	local elapsed_time = GetTime() - frame.spinStartTime
	local normalized = elapsed_time / duration

	if normalized >= 1 then
		-- Spin complete
		self:OnSpinComplete()
		return
	end

	-- Calculate spin progress with easing (fast start, slow end)
	-- Using ease-out cubic for smooth deceleration
	local eased = 1 - math.pow(1 - normalized, 3)

	-- Calculate total rotations (more at start, fewer at end)
	-- Target: several full rotations plus stop at selected index
	local count = #frame.keystoneData
	local targetAngle = (frame.selectedIndex - 1) / count -- Where we want to stop (0-1)
	local totalRotations = 5 + (1 - targetAngle) -- Base rotations plus offset to land on target

	frame.spinProgress = eased * totalRotations

	-- Position keystones
	self:PositionKeystones(frame.spinProgress)

	-- Animate pointer wobble during spin
	if frame.pointer and elapsed_time < duration - 0.5 then
		local wobble = math.sin(elapsed_time * 20) * 5
		frame.pointer:SetRotation(math.rad(wobble))
	else
		frame.pointer:SetRotation(0)
	end
end

---Handle spin completion
function KeystoneRoulette:OnSpinComplete()
	local frame = self.WheelFrame
	if not frame then
		return
	end

	frame.spinning = false

	-- Show spin button again
	frame.spinButton:Show()

	-- Get winner
	local winner = frame.keystoneData[frame.selectedIndex]
	if winner then
		-- Update result display
		local classColor = C_ClassColor.GetClassColor(GetClassInfo(winner.classID))
		local colorHex = classColor and classColor:GenerateHexColor() or 'ffffffff'

		frame.resultText:SetText('|cffFFD700Winner:|r\n|c' .. colorHex .. winner.player .. '|r\n' .. winner.dungeonName .. ' +' .. winner.level)

		-- Highlight winner frame
		for i, ksFrame in ipairs(frame.keystoneFrames) do
			if i == frame.selectedIndex then
				ksFrame:SetBackdropBorderColor(1, 0.82, 0, 1) -- Gold border
			else
				ksFrame:SetBackdropBorderColor(0, 0, 0, 1) -- Normal border
			end
		end

		-- Play victory sound
		self:PlayWheelSound()

		-- Announce in party chat
		self:AnnounceWinner(winner)

		if self.logger then
			self.logger.info('Spin complete! Winner: ' .. winner.player .. ' - ' .. winner.dungeonName .. ' +' .. winner.level)
			self.logger.debug('  Announce to chat: ' .. tostring(self.db.announceWinner and IsInGroup()))
		end
	else
		if self.logger then
			self.logger.error('Spin complete but no winner found at index ' .. tostring(frame.selectedIndex))
		end
	end
end
