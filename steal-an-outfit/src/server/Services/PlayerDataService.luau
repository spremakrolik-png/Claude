--!strict
-- Owns each player's data table. Phase 1 keeps it in memory only; Phase 3 swaps the internals for
-- ProfileStore (session-locked saving) behind the same Load / Get / Release interface.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = {}

local dataByPlayer: { [Player]: Types.PlayerData } = {}

local function newData(): Types.PlayerData
	return {
		cash = GameConfig.Economy.StartingCash,
		level = 1,
		equipped = {},
		wardrobe = {},
		protectedSlots = {},
		receipts = {},
		stats = {
			stolen = 0,
			knockouts = 0,
		},
	}
end

-- May yield once real saving is in place; callers must check `player.Parent` afterwards.
function PlayerDataService.Load(player: Player): Types.PlayerData
	local data = newData()
	dataByPlayer[player] = data
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Income", 0)
	player:SetAttribute("InBase", false)
	return data
end

function PlayerDataService.Get(player: Player): Types.PlayerData?
	return dataByPlayer[player]
end

function PlayerDataService.Release(player: Player)
	dataByPlayer[player] = nil
end

return PlayerDataService
