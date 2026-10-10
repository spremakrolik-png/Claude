--!strict
-- Money panel (top-left), drop timer (top-center) and the six body slots (bottom-center).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local ItemUtil = require(Shared.ItemUtil)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

type SlotTile = {
	stroke: UIStroke,
	name: TextLabel,
	income: TextLabel,
}

local player = Players.LocalPlayer
local Colors = Theme.Colors

local HUDController = {}

local gui: ScreenGui
local cashLabel: TextLabel
local incomeLabel: TextLabel
local levelLabel: TextLabel
local timerLabel: TextLabel
local tiles: { [string]: SlotTile } = {}

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function buildStats()
	local panel: Frame = Theme.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(270, 112),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Theme.corner(14), Theme.stroke(Colors.Stroke, 2) })
	Theme.autoScale(panel)

	cashLabel = Theme.label({
		Name = "Cash",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Money,
		Text = "$0",
		Parent = panel,
	})
	incomeLabel = Theme.label({
		Name = "Income",
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Body,
		Text = "+$0/s",
		Parent = panel,
	})
	levelLabel = Theme.label({
		Name = "Level",
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = "LEVEL 1",
		Parent = panel,
	})
end

local function buildTimer()
	local pill: Frame = Theme.new("Frame", {
		Name = "DropTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(300, 44),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Theme.corner(22), Theme.stroke(Colors.Purple, 2) })
	Theme.autoScale(pill)

	timerLabel = Theme.label({
		Name = "Text",
		Position = UDim2.fromOffset(16, 7),
		Size = UDim2.new(1, -32, 1, -14),
		Text = "NEXT DROP IN 0:00",
		Parent = pill,
	})
end

local function buildSlots()
	local tileWidth, tileHeight, gap = 92, 98, 8
	local bar: Frame = Theme.new("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(#GameConfig.Slots * (tileWidth + gap) - gap, tileHeight),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gap),
		}),
	})
	Theme.autoScale(bar)

	for index, slot in GameConfig.Slots do
		local stroke = Theme.stroke(Colors.Empty, 2)
		local frame: Frame = Theme.new("Frame", {
			Name = slot.id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(tileWidth, tileHeight),
			BackgroundColor3 = Colors.Panel,
			BackgroundTransparency = 0.15,
			Parent = bar,
		}, { Theme.corner(12), stroke })
		Theme.label({
			Name = "Slot",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 16),
			Font = Theme.Fonts.Body,
			TextColor3 = Colors.Muted,
			Text = string.upper(slot.displayName),
			Parent = frame,
		})
		local name = Theme.label({
			Name = "ItemName",
			Position = UDim2.fromOffset(6, 25),
			Size = UDim2.new(1, -12, 0, 46),
			RichText = true,
			TextWrapped = true,
			TextColor3 = Colors.Empty,
			Text = "Empty",
			Parent = frame,
		})
		local income = Theme.label({
			Name = "Income",
			Position = UDim2.fromOffset(6, 74),
			Size = UDim2.new(1, -12, 0, 18),
			Font = Theme.Fonts.Body,
			TextColor3 = Colors.Money,
			Text = "",
			Parent = frame,
		})
		tiles[slot.id] = { stroke = stroke, name = name, income = income }
	end
end

local function refreshStats()
	cashLabel.Text = Format.money(numberAttribute(player, "Cash", 0))
	if player:GetAttribute("InBase") == true then
		incomeLabel.Text = "No income in your dressing room"
		incomeLabel.TextColor3 = Colors.Muted
	else
		incomeLabel.Text = `+{Format.money(numberAttribute(player, "Income", 0))}/s`
		incomeLabel.TextColor3 = Colors.Money
	end
	levelLabel.Text = `LEVEL {numberAttribute(player, "Level", 1)}`
end

local function renderSlots(equipped: Types.Equipped)
	for _, slot in GameConfig.Slots do
		local tile = tiles[slot.id]
		local item = equipped[slot.id]
		if item ~= nil then
			local rarity = ItemUtil.getRarity(item)
			tile.name.Text = ItemUtil.getRichName(item)
			tile.name.TextColor3 = rarity.uiColor
			tile.income.Text = `{Format.money(ItemUtil.getIncome(item))}/s`
			tile.stroke.Color = rarity.uiColor
			tile.stroke.Thickness = 3
		else
			tile.name.Text = "Empty"
			tile.name.TextColor3 = Colors.Empty
			tile.income.Text = ""
			tile.stroke.Color = Colors.Empty
			tile.stroke.Thickness = 2
		end
	end
end

function HUDController.Init()
	gui = Theme.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildStats()
	buildTimer()
	buildSlots()
end

function HUDController.Start()
	for _, attribute in { "Cash", "Income", "Level", "InBase" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
	refreshStats()

	Remotes.get("EquippedChanged").OnClientEvent:Connect(function(equipped: unknown)
		if typeof(equipped) == "table" then
			renderSlots(equipped :: Types.Equipped)
		end
	end)

	task.spawn(function()
		while true do
			local nextDrop = Workspace:GetAttribute("NextDropAt")
			if typeof(nextDrop) == "number" then
				timerLabel.Text = `NEXT DROP IN {Format.clock(nextDrop - Workspace:GetServerTimeNow())}`
			end
			task.wait(0.2)
		end
	end)
end

return HUDController
