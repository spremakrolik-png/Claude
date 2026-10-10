--!strict
-- Tools, hits and knockouts.
-- The client only says "I swung this tool in this direction". The server checks the cooldown, the safe zones and
-- the tool in hand, finds the target itself (distance, cone, line of sight) and applies the knockout:
-- knockback, a tumble, a dizzy label, one random unprotected item drops, then a short immunity.
-- While knocked out the server owns the victim's physics, so the victim can't walk away.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Types = require(ReplicatedStorage.Shared.Types)
local CombatState = require(script.Parent.Parent.Util.CombatState)
local HoldTracker = require(script.Parent.Parent.Util.HoldTracker)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local ToolFactory = require(script.Parent.Parent.Util.ToolFactory)
local AnnouncementService = require(script.Parent.AnnouncementService)
local BaseService = require(script.Parent.BaseService)
local ItemService = require(script.Parent.ItemService)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)

local COMBAT = GameConfig.Combat
local FLAT = Vector3.new(1, 0, 1)

local CombatService = {}

local useLimiter = RateLimiter.new(GameConfig.RateLimits.UseToolPerSecond, 1)
local lastUse: { [Player]: { [string]: number } } = {}
local shieldTokens: { [Player]: number } = {}
local dropsFolder: Instance? = nil

local function aliveParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

-- Horizontal unit vector, or nil for zero / NaN input.
local function flatten(vector: Vector3): Vector3?
	local flat = vector * FLAT
	local length = flat.Magnitude
	if not (length >= 0.01 and length < math.huge) then -- also rejects NaN and infinity
		return nil
	end
	return flat / length
end

-- Visible bubble while the player can't be hit (after leaving the room, after getting up).
local function updateShield(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local remaining = CombatState.shieldUntil(player) - Workspace:GetServerTimeNow()
	local shield = character:FindFirstChild("CombatShield")
	if remaining <= 0 then
		if shield then
			shield:Destroy()
		end
		return
	end
	if shield == nil then
		local field = Instance.new("ForceField")
		field.Name = "CombatShield"
		field.Visible = true
		field.Parent = character
	end
	local token = (shieldTokens[player] or 0) + 1
	shieldTokens[player] = token
	task.delay(remaining, function()
		if shieldTokens[player] == token then
			local current = character:FindFirstChild("CombatShield")
			if current then
				current:Destroy()
			end
		end
	end)
end

local function addDizzyLabel(character: Model, text: string)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Dizzy"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(4, 1.3)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 225, 90)
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = character
end

local function standUp(player: Player, character: Model)
	local _, humanoid, root = aliveParts(player)
	if player.Character ~= character or humanoid == nil or root == nil then
		return
	end
	local dizzy = character:FindFirstChild("Dizzy")
	if dizzy then
		dizzy:Destroy()
	end

	humanoid.PlatformStand = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	-- Back on the feet where the body lies, facing the way the chest pointed.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
	local floorY = if hit then hit.Position.Y else root.Position.Y - 1
	local standHeight = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local position = Vector3.new(root.Position.X, floorY + standHeight + 0.1, root.Position.Z)
	local facing = flatten(root.CFrame.LookVector) or flatten(-root.CFrame.UpVector) or Vector3.new(0, 0, -1)
	character:PivotTo(CFrame.lookAt(position, position + facing))
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	updateShield(player)
end

local function knockOut(target: Player, attacker: Player, def: Types.ToolDef, pushDirection: Vector3)
	local character, humanoid, root = aliveParts(target)
	if character == nil or humanoid == nil or root == nil then
		return
	end
	CombatState.setKnockedOut(target, def.knockoutSeconds, COMBAT.ImmunitySeconds)
	HoldTracker.cancelEverywhere(target) -- a hit interrupts any pickup in progress
	ItemService.CancelSwap(target)

	local dropped = ItemService.DropRandomUnprotected(target, root.Position)
	local attackerData = PlayerDataService.Get(attacker)
	if attackerData then
		attackerData.stats.knockouts += 1
	end
	if dropped then
		local name = ItemUtil.getDisplayName(dropped)
		AnnouncementService.Notify(target, `Тебя огрели! Потеряно: {name}`, "Warning")
		AnnouncementService.Notify(attacker, `Бонк! Выпало: {name}`, "Success")
	else
		AnnouncementService.Notify(target, "Тебя огрели!", "Warning")
	end

	-- Take over the physics so the victim can't walk out of the tumble.
	local strength = COMBAT.Knockback[def.knockback]
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = pushDirection * strength.push + Vector3.new(0, strength.lift, 0)
	-- Spinning around (up x push) tips the head over in the push direction.
	root.AssemblyAngularVelocity = Vector3.new(0, 1, 0):Cross(pushDirection) * COMBAT.SpinSpeed
	addDizzyLabel(character, def.dizzyText)

	task.delay(def.knockoutSeconds, function()
		standUp(target, character)
	end)
end

-- Closest valid target in front of the attacker, or nil.
local function findMeleeTarget(
	attacker: Player,
	origin: BasePart,
	aim: Vector3,
	def: Types.ToolDef
): (Player?, BasePart?)
	local minDot = math.cos(math.rad(def.arcDegrees / 2))
	-- Lag allowance grows with the attacker's ping, so low-ping players get close to the configured range.
	local reach = def.range + math.min(COMBAT.RangeSlack, 1.5 + attacker:GetNetworkPing() * 16)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	for _, candidate in Players:GetPlayers() do
		if candidate == attacker then
			continue
		end
		local character, _, root = aliveParts(candidate)
		if character == nil or root == nil then
			continue
		end
		local offset = root.Position - origin.Position
		if math.abs(offset.Y) > COMBAT.MaxHeightDifference then
			continue
		end
		local flat = offset * FLAT
		local distance = flat.Magnitude
		if distance > reach or distance >= bestDistance then
			continue
		end
		if distance > 1.5 and (flat / distance):Dot(aim) < minDot then
			continue
		end
		if BaseService.IsInOwnBase(candidate) or BaseService.IsInsideOwnZone(candidate) then
			continue
		end
		if CombatState.isInvulnerable(candidate) then
			continue
		end
		-- No hits through walls and props (other characters and floor drops don't block).
		local ignore: { Instance } = {}
		table.insert(ignore, character :: Model)
		local attackerCharacter = attacker.Character
		if attackerCharacter then
			table.insert(ignore, attackerCharacter)
		end
		local drops = dropsFolder
		if drops then
			table.insert(ignore, drops)
		end
		params.FilterDescendantsInstances = ignore
		if Workspace:Raycast(origin.Position, offset, params) ~= nil then
			continue
		end
		best, bestRoot, bestDistance = candidate, root, distance
	end
	return best, bestRoot
end

local function onUseTool(player: Player, toolId: unknown, direction: unknown)
	if typeof(toolId) ~= "string" or typeof(direction) ~= "Vector3" or not useLimiter(player) then
		return
	end
	local def = Tools.Defs[toolId]
	local data = PlayerDataService.Get(player)
	if def == nil or data == nil or data.level < def.unlockLevel then
		return
	end
	local character, _, root = aliveParts(player)
	if character == nil or root == nil then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == nil or tool:GetAttribute("ToolId") ~= toolId then
		return
	end
	if CombatState.isKnockedOut(player) or CombatState.isExitProtected(player) then
		return
	end
	if BaseService.IsInOwnBase(player) or BaseService.IsInsideOwnZone(player) then
		return
	end

	local uses = lastUse[player]
	if uses == nil then
		uses = {}
		lastUse[player] = uses
	end
	local now = os.clock()
	if now - (uses[toolId] or -math.huge) < def.cooldownSeconds - 0.35 then -- jitter allowance
		return
	end
	uses[toolId] = now

	-- The default Animate script plays its slash animation when a "toolanim" value appears in the tool.
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = "Slash"
	animation.Parent = tool
	Debris:AddItem(animation, 1) -- the Animate script only consumes it on the client
	Remotes.get("CombatEffect"):FireAllClients("Swing", root.Position)

	local aim = flatten(direction) or flatten(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	if def.kind == "Melee" then
		local target, targetRoot = findMeleeTarget(player, root, aim, def)
		if target ~= nil and targetRoot ~= nil then
			Remotes.get("CombatEffect"):FireAllClients("Hit", targetRoot.Position)
			knockOut(target, player, def, flatten(targetRoot.Position - root.Position) or aim)
		end
	end
end

local function hasTool(container: Instance?, id: string): boolean
	if container == nil then
		return false
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ToolId") == id then
			return true
		end
	end
	return false
end

local function giveTools(player: Player)
	local data = PlayerDataService.Get(player)
	local backpack = player:WaitForChild("Backpack", 10)
	if data == nil or backpack == nil then
		return
	end
	for _, id in Tools.Order do
		local def = Tools.Defs[id]
		if data.level >= def.unlockLevel then
			if not hasTool(backpack, id) and not hasTool(player.Character, id) then
				ToolFactory.create(def).Parent = backpack
			end
		end
	end
end

function CombatService.OnCharacterAdded(player: Player, _character: Model)
	CombatState.reset(player)
	giveTools(player)
end

function CombatService.OnPlayerRemoving(player: Player)
	lastUse[player] = nil
	shieldTokens[player] = nil
end

function CombatService.Init(map: MapBuilder.MapRefs)
	dropsFolder = map.drops
end

function CombatService.Start()
	Remotes.get("UseTool").OnServerEvent:Connect(onUseTool)
	BaseService.OnLeftBase(function(player)
		CombatState.setExitProtected(player, COMBAT.ExitProtectionSeconds)
		updateShield(player)
	end)
end

return CombatService
