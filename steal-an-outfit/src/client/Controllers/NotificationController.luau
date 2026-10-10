--!strict
-- Toasts under the drop timer. "Rare" ones are bigger, golden and play a sound.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

type Style = {
	color: Color3,
	duration: number,
	height: number,
}

local Colors = Theme.Colors
local MAX_VISIBLE = 4
local FADE = TweenInfo.new(0.35)

local STYLES: { [Types.NotifyKind]: Style } = {
	Info = { color = Colors.Info, duration = 3, height = 42 },
	Success = { color = Colors.Success, duration = 3, height = 42 },
	Warning = { color = Colors.Warning, duration = 3.5, height = 42 },
	Rare = { color = Colors.Gold, duration = 5, height = 58 },
}

local NotificationController = {}

local container: Frame
local rareSound: Sound
local order = 0

local function dismiss(toast: Frame)
	if toast.Parent == nil then
		return
	end
	for _, descendant in toast:GetDescendants() do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, FADE, { TextTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, FADE, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(toast, FADE, { BackgroundTransparency = 1 }):Play()
	task.delay(FADE.Time, function()
		toast:Destroy()
	end)
end

function NotificationController.Show(text: string, kind: Types.NotifyKind)
	local style = STYLES[kind]
	order -= 1
	local toast: Frame = Theme.new("Frame", {
		Name = "Toast",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, style.height),
		BackgroundColor3 = style.color,
	}, { Theme.corner(14), Theme.stroke(Colors.Border, 3) })
	Theme.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 1, -12),
		Text = text,
		Parent = toast,
	})
	toast.Parent = container

	local toasts: { Frame } = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a: Frame, b: Frame)
		return a.LayoutOrder > b.LayoutOrder
	end)
	for index = 1, #toasts - MAX_VISIBLE do
		toasts[index]:Destroy()
	end

	if kind == "Rare" then
		SoundService:PlayLocalSound(rareSound)
	end
	task.delay(style.duration, dismiss, toast)
end

function NotificationController.Init()
	local gui = Theme.new("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	container = Theme.new("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(520, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	Theme.autoScale(container)

	rareSound = Theme.new("Sound", {
		Name = "RareDropSound",
		SoundId = GameConfig.Sounds.RareDrop,
		Volume = 0.7,
		Parent = SoundService,
	})
end

function NotificationController.Start()
	Remotes.get("Notify").OnClientEvent:Connect(function(text: unknown, kind: unknown)
		if typeof(text) ~= "string" then
			return
		end
		local style: Types.NotifyKind = if kind == "Success"
				or kind == "Warning"
				or kind == "Rare"
			then kind
			else "Info"
		NotificationController.Show(text, style)
	end)
end

return NotificationController
