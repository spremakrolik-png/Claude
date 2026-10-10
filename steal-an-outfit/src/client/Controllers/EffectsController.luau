--!strict
-- Local-only visuals: rainbow color cycling for Rainbow/Secret parts, wobbling dizzy labels over knocked-out
-- players, and "+$X" popups above your head.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local ItemVisuals = require(Shared.ItemVisuals)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local RAINBOW_STEP = 1 / 20 -- seconds between color updates
local POPUP_TWEEN = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local EffectsController = {}

local rainbowParts: { [BasePart]: number } = {}

local function trackRainbow(instance: Instance)
	if instance:IsA("BasePart") then
		local offset = instance:GetAttribute("RainbowOffset")
		rainbowParts[instance] = if typeof(offset) == "number" then offset else 0
	end
end

local function untrackRainbow(instance: Instance)
	if instance:IsA("BasePart") then
		rainbowParts[instance] = nil
	end
end

local function showCashPopup(amount: number)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local billboard: BillboardGui = Theme.new("BillboardGui", {
		Name = "CashPopup",
		Adornee = head,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(180, 46),
		StudsOffset = Vector3.new(0, 2.4, 0),
		LightInfluence = 0,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local label = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = `+{Format.money(amount)}`,
		TextColor3 = Theme.Colors.Money,
		Parent = billboard,
	})
	TweenService:Create(billboard, POPUP_TWEEN, { StudsOffset = Vector3.new(0, 4.6, 0) }):Play()
	TweenService:Create(label, POPUP_TWEEN, { TextTransparency = 1 }):Play()
	local outline = label:FindFirstChildOfClass("UIStroke")
	if outline then
		TweenService:Create(outline, POPUP_TWEEN, { Transparency = 1 }):Play()
	end
	task.delay(POPUP_TWEEN.Time, function()
		billboard:Destroy()
	end)
end

function EffectsController.Init() end

function EffectsController.Start()
	for _, instance in CollectionService:GetTagged(ItemVisuals.RAINBOW_TAG) do
		trackRainbow(instance)
	end
	CollectionService:GetInstanceAddedSignal(ItemVisuals.RAINBOW_TAG):Connect(trackRainbow)
	CollectionService:GetInstanceRemovedSignal(ItemVisuals.RAINBOW_TAG):Connect(untrackRainbow)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < RAINBOW_STEP then
			return
		end
		elapsed = 0
		local now = os.clock()
		for part, offset in rainbowParts do
			part.Color = Color3.fromHSV((now * 0.25 + offset) % 1, 0.8, 1)
		end
		for _, other in Players:GetPlayers() do
			local dizzy = if other.Character then other.Character:FindFirstChild("Dizzy") else nil
			local label = if dizzy then dizzy:FindFirstChildOfClass("TextLabel") else nil
			if label then
				label.Rotation = math.sin(now * 6) * 15
			end
		end
	end)

	-- Income arrives once per tick; sum it up and show at most one popup per second.
	local function readCash(): number
		local value = player:GetAttribute("Cash")
		return if typeof(value) == "number" then value else 0
	end
	local lastCash = readCash()
	local pending = 0
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local cash = readCash()
		if cash > lastCash then
			pending += cash - lastCash
		end
		lastCash = cash
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if pending >= 1 then
				showCashPopup(pending)
				pending = 0
			end
		end
	end)
end

return EffectsController
