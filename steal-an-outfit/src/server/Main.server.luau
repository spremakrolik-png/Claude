--!strict
-- Server entry point: builds the map, initializes services in dependency order, then handles players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CollisionGroups = require(script.Parent.Util.CollisionGroups)
local RateLimiter = require(script.Parent.Util.RateLimiter)
local Services = script.Parent.Services
local BaseService = require(Services.BaseService)
local EconomyService = require(Services.EconomyService)
local ItemService = require(Services.ItemService)
local MannequinService = require(Services.MannequinService)
local MapBuilder = require(Services.MapBuilder)
local PlayerDataService = require(Services.PlayerDataService)

Remotes.init()
CollisionGroups.setup(GameConfig.Map.BaseCount)

local map = MapBuilder.Build()
BaseService.Init(map)
ItemService.Init(map)
MannequinService.Init(map)

BaseService.Start()
ItemService.Start()
EconomyService.Start()
MannequinService.Start()

local readyLimiter = RateLimiter.new(GameConfig.RateLimits.ClientReadyPerMinute, 60)
Remotes.get("ClientReady").OnServerEvent:Connect(function(player)
	if readyLimiter(player) then
		ItemService.SendSnapshot(player)
	end
end)

-- Characters load manually (Players.CharacterAutoLoads = false). LoadCharacterAsync returns once the engine has
-- parented the character and placed it at its own spawn point, so moving it into the dressing room must happen after.
local function spawnCharacter(player: Player)
	player:LoadCharacterAsync()
	local character = player.Character
	if character ~= nil and character.Parent ~= nil then
		character:PivotTo(BaseService.GetSpawnCFrame(player))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	task.spawn(BaseService.OnCharacterAdded, player, character)
	task.spawn(ItemService.OnCharacterAdded, player, character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		humanoid.Died:Once(function()
			task.wait(GameConfig.RespawnSeconds)
			if player.Parent ~= nil and player.Character == character then
				spawnCharacter(player)
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	PlayerDataService.Load(player)
	if player.Parent == nil then
		return
	end
	BaseService.Assign(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	spawnCharacter(player)
end

local function onPlayerRemoving(player: Player)
	ItemService.OnPlayerRemoving(player)
	BaseService.Release(player)
	PlayerDataService.Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
