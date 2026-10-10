--!strict
-- Client entry point: builds the UI controllers, then tells the server it is ready for state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Controllers = script.Parent.Controllers
local EffectsController = require(Controllers.EffectsController)
local HUDController = require(Controllers.HUDController)
local NotificationController = require(Controllers.NotificationController)
local SwapController = require(Controllers.SwapController)

HUDController.Init()
NotificationController.Init()
SwapController.Init()
EffectsController.Init()

HUDController.Start()
NotificationController.Start()
SwapController.Start()
EffectsController.Start()

Remotes.get("ClientReady"):FireServer()

-- There is no health in this game, and resetting would just be a free escape: hide the Reset button.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)
