--!strict
-- Cash and income. Every tick, each player earns the income of everything they wear,
-- but only while they are out on the arena (not inside their own dressing room).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local BaseService = require(script.Parent.BaseService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}

-- Income per second with all multipliers (game passes and server boosts arrive in Phase 5).
function EconomyService.GetIncomePerSecond(player: Player): number
	local data = PlayerDataService.Get(player)
	if data == nil then
		return 0
	end
	local total = 0
	for _, item in data.equipped do
		total += ItemUtil.getIncome(item)
	end
	return total * Levels.incomeMultiplier(data.level)
end

function EconomyService.RefreshIncome(player: Player)
	player:SetAttribute("Income", EconomyService.GetIncomePerSecond(player))
end

function EconomyService.AddCash(player: Player, amount: number)
	local data = PlayerDataService.Get(player)
	if data == nil or amount == 0 then
		return
	end
	data.cash = math.max(0, data.cash + amount)
	player:SetAttribute("Cash", data.cash)
end

local function isOnArena(player: Player): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return not BaseService.IsInOwnBase(player)
end

function EconomyService.Start()
	local interval = GameConfig.Economy.IncomeTickSeconds
	task.spawn(function()
		while true do
			task.wait(interval)
			for _, player in Players:GetPlayers() do
				local income = EconomyService.GetIncomePerSecond(player)
				player:SetAttribute("Income", income)
				if income > 0 and isOnArena(player) then
					EconomyService.AddCash(player, income * interval)
				end
			end
		end
	end)
end

return EconomyService
