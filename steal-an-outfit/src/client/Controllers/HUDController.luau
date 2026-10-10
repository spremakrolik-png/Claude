--!strict
-- Money panel (left), drop timer (top-center) and the six body slots (bottom-center).
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
	frame: Frame,
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
	-- Left middle: the default chat window owns the top-left corner.
	local panel: Frame = Theme.new("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, -40),
		Size = UDim2.fromOffset(270, 112),
		BackgroundColor3 = Colors.Panel,
		Parent = gui,
	}, { Theme.corner(16), Theme.stroke(Colors.Border, 3) })
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
		TextColor3 = Colors.Income,
		Text = "+$0/с",
		Parent = panel,
	})
	levelLabel = Theme.label({
		Name = "Level",
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = "УРОВЕНЬ 1",
		Parent = panel,
	})
end

local function buildTimer()
	local pill: Frame = Theme.new("Frame", {
		Name = "DropTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(300, 44),
		BackgroundColor3 = Colors.PanelAlt,
		Parent = gui,
	}, { Theme.corner(22), Theme.stroke(Colors.Border, 3) })
	Theme.autoScale(pill)

	timerLabel = Theme.label({
		Name = "Text",
		Position = UDim2.fromOffset(16, 7),
		Size = UDim2.new(1, -32, 1, -14),
		Text = "ДРОП ЧЕРЕЗ 0:00",
		Parent = pill,
	})
end

local function buildSlots()
	local tileWidth, tileHeight, gap = 92, 98, 8
	local bar: Frame = Theme.new("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84), -- above the Roblox tool hotbar
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
	Theme.autoScale(bar, 0.75)

	for index, slot in GameConfig.Slots do
		local frame: Frame = Theme.new("Frame", {
			Name = slot.id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(tileWidth, tileHeight),
			BackgroundColor3 = Colors.Empty,
			Parent = bar,
		}, { Theme.corner(14), Theme.stroke(Colors.Border, 3) })
		Theme.label({
			Name = "Slot",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 16),
			Font = Theme.Fonts.Body,
			TextColor3 = Colors.Muted,
			Text = Format.upper(slot.displayName),
			Parent = frame,
		})
		local name = Theme.label({
			Name = "ItemName",
			Position = UDim2.fromOffset(6, 25),
			Size = UDim2.new(1, -12, 0, 46),
			RichText = true,
			TextWrapped = true,
			Text = "Пусто",
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
		tiles[slot.id] = { frame = frame, name = name, income = income }
	end
end

local function refreshStats()
	cashLabel.Text = Format.money(numberAttribute(player, "Cash", 0))
	if player:GetAttribute("InBase") == true then
		incomeLabel.Text = "В гримёрке доход не идёт"
		incomeLabel.TextColor3 = Colors.Muted
	else
		incomeLabel.Text = `+{Format.money(numberAttribute(player, "Income", 0))}/с`
		incomeLabel.TextColor3 = Colors.Income
	end
	levelLabel.Text = `УРОВЕНЬ {numberAttribute(player, "Level", 1)}`
end

local function renderSlots(equipped: Types.Equipped)
	for _, slot in GameConfig.Slots do
		local tile = tiles[slot.id]
		local item = equipped[slot.id]
		if item ~= nil then
			-- Plain name: the tile color shows the rarity and the income already includes the mutation.
			local def = ItemUtil.getDef(item.itemId)
			tile.frame.BackgroundColor3 = ItemUtil.getRarity(item).color
			tile.name.Text = if def then def.displayName else item.itemId
			tile.income.Text = `{Format.money(ItemUtil.getIncome(item))}/с`
		else
			tile.frame.BackgroundColor3 = Colors.Empty
			tile.name.Text = "Пусто"
			tile.income.Text = ""
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
				timerLabel.Text = `ДРОП ЧЕРЕЗ {Format.clock(nextDrop - Workspace:GetServerTimeNow())}`
			end
			task.wait(0.2)
		end
	end)
end

return HUDController
