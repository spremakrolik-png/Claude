--!strict
-- Tool input and combat feedback on the client.
-- Clicking with a tool (or the big action button / F / R2) sends "I swung this tool this way" to the server,
-- which decides whether anyone was hit. This module also draws the knockout screen, the protection status,
-- and plays swing/hit effects for everyone.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local Tools = require(Shared.Config.Tools)
local Theme = require(script.Parent.Parent.UI.Theme)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local CombatController = {}

local readyAt: { [string]: number } = {} -- os.clock() when each tool is off cooldown
local boundTools: { [Tool]: true } = setmetatable({}, { __mode = "k" }) :: any
local lastHintAt = 0

local actionButton: TextButton
local cooldownFill: Frame
local knockoutScreen: Frame
local knockoutTimer: TextLabel
local statusChip: Frame
local statusLabel: TextLabel
local promptsDisabled = false

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function timeAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function hint(text: string)
	if os.clock() - lastHintAt > 2 then
		lastHintAt = os.clock()
		NotificationController.Show(text, "Info")
	end
end

-- The first combat tool: the equipped one if any, otherwise one from the backpack.
local function findTool(): (Tool?, boolean)
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then
				return child, true
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then
				return child, false
			end
		end
	end
	return nil, false
end

local function useTool(tool: Tool)
	local toolId = tool:GetAttribute("ToolId")
	local def = if typeof(toolId) == "string" then Tools.Defs[toolId] else nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if def == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if timeAttribute("KnockedUntil") > serverNow() then
		return
	end
	if player:GetAttribute("InBase") == true then
		hint("В гримёрке драться нельзя")
		return
	end
	if timeAttribute("ProtectedUntil") > serverNow() then
		hint("Пока горит защита после выхода, бить нельзя")
		return
	end
	if os.clock() < (readyAt[def.id] or 0) then
		return
	end
	readyAt[def.id] = os.clock() + def.cooldownSeconds + 0.1 -- a little slack so the server never rejects it
	Remotes.get("UseTool"):FireServer(def.id, root.CFrame.LookVector)
end

local function bindTool(instance: Instance)
	if instance:IsA("Tool") and instance:GetAttribute("ToolId") ~= nil and not boundTools[instance] then
		boundTools[instance] = true
		instance.Activated:Connect(function()
			useTool(instance)
		end)
	end
end

-- Action button / key: equip the tool if needed, then swing.
local function pressAction()
	local tool, equipped = findTool()
	if tool == nil then
		return
	end
	if not equipped then
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid:EquipTool(tool)
		end
	end
	useTool(tool)
end

local function playAt(position: Vector3, soundId: string, burst: boolean)
	local anchor = Instance.new("Attachment")
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.8
	sound.RollOffMaxDistance = 120
	sound.Parent = anchor
	sound:Play()

	if burst then
		local stars = Instance.new("ParticleEmitter")
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Color = ColorSequence.new(Colors.Gold)
		stars.LightEmission = 1
		stars.Lifetime = NumberRange.new(0.4, 0.8)
		stars.Speed = NumberRange.new(8, 14)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Size = NumberSequence.new(0.6, 0)
		stars.Enabled = false
		stars.Parent = anchor
		stars:Emit(20)

		local billboard: BillboardGui = Theme.new("BillboardGui", {
			Adornee = anchor,
			AlwaysOnTop = true,
			MaxDistance = 70,
			Size = UDim2.fromScale(6, 2), -- studs: shrinks with distance
			StudsOffset = Vector3.new(0, 2.5, 0),
			LightInfluence = 0,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local label = Theme.label({
			Size = UDim2.fromScale(1, 1),
			Text = "БОНК!",
			TextColor3 = Colors.Gold,
			Rotation = math.random(-12, 12),
			Parent = billboard,
		})
		local rise = TweenInfo.new(0.9, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(billboard, rise, { StudsOffset = Vector3.new(0, 5, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
		local outline = label:FindFirstChildOfClass("UIStroke")
		if outline then
			TweenService:Create(outline, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		end
		task.delay(1, function()
			billboard:Destroy()
		end)
	end
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end

local function buildGui()
	local gui = Theme.new("ScreenGui", {
		Name = "Combat",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Big round action button above the mobile jump button (also clickable on PC).
	actionButton = Theme.new("TextButton", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -224), -- clears the mobile jump button, also on tablets
		Size = UDim2.fromOffset(118, 118),
		BackgroundColor3 = Colors.Panel,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Theme.stroke(Colors.Border, 4) })
	Theme.autoScale(actionButton)
	-- Dark disc in the middle that shrinks as the cooldown runs out.
	cooldownFill = Theme.new("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = actionButton,
	}, { Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Theme.label({
		Position = UDim2.fromScale(0.1, 0.28),
		Size = UDim2.fromScale(0.8, 0.34),
		Text = "БОНК!",
		Parent = actionButton,
	})
	Theme.label({
		Position = UDim2.fromScale(0.2, 0.64),
		Size = UDim2.fromScale(0.6, 0.16),
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = if UserInputService.TouchEnabled then "" else "[F]",
		Parent = actionButton,
	})
	actionButton.Activated:Connect(pressAction)

	-- Knockout screen: darkened edges, big title and a countdown.
	knockoutScreen = Theme.new("Frame", {
		Name = "Knockout",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local edges: { { position: UDim2, size: UDim2, rotation: number } } = {
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.3), rotation = 90 },
		{ position = UDim2.fromScale(0, 0.7), size = UDim2.fromScale(1, 0.3), rotation = -90 },
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.25, 1), rotation = 0 },
		{ position = UDim2.fromScale(0.75, 0), size = UDim2.fromScale(0.25, 1), rotation = 180 },
	}
	for _, edge in edges do
		Theme.new("Frame", {
			Position = edge.position,
			Size = edge.size,
			BackgroundColor3 = Colors.Panel,
			BorderSizePixel = 0,
			Parent = knockoutScreen,
		}, {
			Theme.new("UIGradient", {
				Rotation = edge.rotation,
				Transparency = NumberSequence.new(0.35, 1),
			}),
		})
	end
	local center: Frame = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55), -- below the notification stack
		Size = UDim2.fromOffset(420, 150),
		BackgroundTransparency = 1,
		Parent = knockoutScreen,
	})
	Theme.autoScale(center)
	Theme.label({
		Size = UDim2.new(1, 0, 0, 90),
		Text = "💫 НОКАУТ! 💫",
		TextColor3 = Colors.Gold,
		Parent = center,
	})
	knockoutTimer = Theme.label({
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		Parent = center,
	})

	-- Status chip above the slot bar: protection countdown.
	statusChip = Theme.new("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -220), -- above the slot bar at its largest scale
		Size = UDim2.fromOffset(300, 38),
		BackgroundColor3 = Colors.Info,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(19), Theme.stroke(Colors.Border, 3) })
	Theme.autoScale(statusChip)
	statusLabel = Theme.label({
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -24, 1, -10),
		Text = "",
		Parent = statusChip,
	})
end

local function update()
	local now = serverNow()
	local tool = findTool()
	actionButton.Visible = tool ~= nil and player.Character ~= nil

	local toolId = if tool then tool:GetAttribute("ToolId") else nil
	local def = if typeof(toolId) == "string" then Tools.Defs[toolId] else nil
	local left = if def then (readyAt[def.id] or 0) - os.clock() else 0
	local fraction = if def and left > 0 then math.min(1, left / def.cooldownSeconds) else 0
	cooldownFill.Size = UDim2.fromScale(fraction, fraction)

	local knockedLeft = timeAttribute("KnockedUntil") - now
	local knocked = knockedLeft > 0
	knockoutScreen.Visible = knocked
	if knocked then
		knockoutTimer.Text = `Встанешь через {Format.seconds(knockedLeft)}`
	end
	-- No pickups while lying on the floor.
	if knocked ~= promptsDisabled then
		promptsDisabled = knocked
		ProximityPromptService.Enabled = not knocked
	end

	local shieldLeft = math.max(timeAttribute("ProtectedUntil"), timeAttribute("ImmuneUntil")) - now
	statusChip.Visible = not knocked and shieldLeft > 0
	if statusChip.Visible then
		statusLabel.Text = `🛡 ЗАЩИТА {Format.seconds(shieldLeft)}`
	end
end

function CombatController.Init()
	buildGui()
end

function CombatController.Start()
	local function watchCharacter(character: Model)
		for _, child in character:GetChildren() do
			bindTool(child)
		end
		character.ChildAdded:Connect(bindTool)
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			child.ChildAdded:Connect(bindTool)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack.ChildAdded:Connect(bindTool)
	end

	ContextActionService:BindAction("StealAnOutfitAction", function(_, state)
		if state == Enum.UserInputState.Begin then
			pressAction()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	Remotes.get("CombatEffect").OnClientEvent:Connect(function(kind: unknown, position: unknown)
		if typeof(position) ~= "Vector3" then
			return
		end
		if kind == "Swing" then
			playAt(position, GameConfig.Sounds.Swing, false)
		elseif kind == "Hit" then
			playAt(position, GameConfig.Sounds.Hit, true)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return CombatController
