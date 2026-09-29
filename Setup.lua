---@class KeystoneRoulette
local KeystoneRoulette = LibStub('AceAddon-3.0'):GetAddon('Libs-KeystoneRoulette')

local ICON_NAME = 'Libs Keystone Roulette'

---Register the first-run setup with Libs-AddonTools. Must run before the database is created, so
---a new install can be told apart from a player who used the addon before.
function KeystoneRoulette:RegisterSetup()
	if not LibAT or not LibAT.Setup then
		return
	end

	local reg = LibAT.Setup:Register('libs-keystoneroulette', {
		name = "Lib's Keystone Roulette",
		icon = 'Interface\\Icons\\inv_relics_hourglass',
		summary = 'Spin a wheel to pick which keystone your group runs next.',
		priority = 95,
		isExistingUser = function()
			return type(LibsKeystoneRouletteDB) == 'table' and next(LibsKeystoneRouletteDB) ~= nil
		end,
		optionsCommand = '/ksr options',
	})
	if not reg then
		return
	end

	-- A data bar already shows this addon, so the minimap button is not needed there
	local wantMinimap = not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('Libs-DataBar'))

	reg:AddStep({
		id = 'wheel',
		kind = 'toggles',
		name = 'The wheel',
		title = 'How should the wheel work?',
		text = 'Open the wheel with /ksr when your group has keys. You can change these later.',
		items = {
			{
				key = 'announceWinner',
				title = 'Tell the group',
				caption = 'The winning key is posted in group chat.',
				recommended = true,
			},
			{
				key = 'soundEnabled',
				title = 'Play sounds',
				caption = 'A sound plays when the wheel spins and when it stops.',
				recommended = true,
			},
			{
				key = 'minimap',
				title = 'Minimap button',
				caption = 'A button by the minimap that opens the wheel.',
				recommended = wantMinimap,
			},
		},
		get = function(key)
			local db = KeystoneRoulette.db
			if key == 'minimap' then
				return not db.minimap.hide
			end
			return db[key] and true or false
		end,
		set = function(key, value)
			local db = KeystoneRoulette.db
			if key == 'minimap' then
				db.minimap.hide = not value
				local LDBIcon = LibStub('LibDBIcon-1.0', true)
				if LDBIcon then
					if value then
						LDBIcon:Show(ICON_NAME)
					else
						LDBIcon:Hide(ICON_NAME)
					end
				end
			else
				db[key] = value
			end
			if KeystoneRoulette.logger then
				KeystoneRoulette.logger.debug('Setup set ' .. tostring(key) .. ' to ' .. tostring(value))
			end
		end,
	})
end
