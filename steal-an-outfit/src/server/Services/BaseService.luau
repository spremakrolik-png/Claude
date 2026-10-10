--!strict
-- Dressing rooms: one per player, assigned on join and freed on leave.
-- Only the owner can pass the doorway (collision groups), and anyone else who ends up inside is
-- teleported out. Being inside your own room sets the "InBase" attribute, which stops income.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local CollisionGroups = require(script.Parent.Parent.Util.CollisionGroups)
local MapBuilder = require(script.Parent.MapBuilder)

type Base = {
	index: number,
	model: Model,
	zone: BasePart,
	barrier: BasePart,
	spawnPoint: BasePart,
	ownerLabel: TextLabel,
	infoLabel: TextLabel,
	owner: Player?,
	levelConnection: RBXScriptConnection?,
}

local BaseService = {}

local bases: { Base } = {}
local baseOf: { [Player]: Base } = {}
local insideOwnBase: { [Player]: boolean } = {}
-- Players without a room spawn on the podium, beside (not inside) the Grand Mannequin.
local FALLBACK_OFFSET = Vector3.new(0, GameConfig.Map.PodiumHeight + 3, -(GameConfig.Map.PodiumRadius - 4))
local fallbackSpawn = CFrame.new(FALLBACK_OFFSET)

local function findPart(model: Model, name: string): BasePart
	local found = model:FindFirstChild(name, true)
	if found ~= nil and found:IsA("BasePart") then
		return found
	end
	error(`{model:GetFullName()} needs a BasePart named "{name}"`)
end

local function signLabel(parent: SurfaceGui, name: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, y)
	label.Size = UDim2.fromScale(0.92, height)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = ""
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 70, 185)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function createSign(sign: BasePart): (TextLabel, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerSign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	return signLabel(gui, "Owner", 0.06, 0.56, 90), signLabel(gui, "Info", 0.62, 0.32, 48)
end

local function refreshSign(base: Base)
	local owner = base.owner
	if owner ~= nil then
		local level = owner:GetAttribute("Level")
		base.ownerLabel.Text = string.upper(owner.DisplayName)
		base.infoLabel.Text = `DRESSING ROOM  •  LV. {if typeof(level) == "number" then level else 1}`
	else
		base.ownerLabel.Text = "VACANT"
		base.infoLabel.Text = "DRESSING ROOM"
	end
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

-- A spot on the arena in front of the doorway (the barrier's LookVector points into the room).
local function outsideDoor(base: Base): CFrame
	local barrier = base.barrier
	local floorY = barrier.Position.Y - barrier.Size.Y / 2
	local outside = barrier.Position - barrier.CFrame.LookVector * 6
	local position = Vector3.new(outside.X, floorY + 3, outside.Z)
	return CFrame.lookAt(position, position - barrier.CFrame.LookVector)
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function poll()
	for _, player in Players:GetPlayers() do
		local root = rootPart(player)
		local own = baseOf[player]
		local inside = false
		if root ~= nil then
			local position = root.Position
			inside = own ~= nil and isInside(own.zone, position)
			for _, base in bases do
				if base ~= own and base.owner ~= nil and isInside(base.zone, position) then
					local character = player.Character
					if character ~= nil then
						character:PivotTo(outsideDoor(base))
					end
				end
			end
		end
		if insideOwnBase[player] ~= inside then
			insideOwnBase[player] = inside
			player:SetAttribute("InBase", inside)
		end
	end
end

function BaseService.Init(map: MapBuilder.MapRefs)
	fallbackSpawn = CFrame.new(map.center + FALLBACK_OFFSET)
	for index, model in map.bases do
		local zone = findPart(model, "Zone")
		zone.Transparency = 1
		zone.CanCollide = false
		zone.CanQuery = false
		zone.CanTouch = false

		local barrier = findPart(model, "Barrier")
		barrier.CollisionGroup = CollisionGroups.barrierGroup(index)

		local ownerLabel, infoLabel = createSign(findPart(model, "Sign"))
		local base: Base = {
			index = index,
			model = model,
			zone = zone,
			barrier = barrier,
			spawnPoint = findPart(model, "SpawnPoint"),
			ownerLabel = ownerLabel,
			infoLabel = infoLabel,
			owner = nil,
			levelConnection = nil,
		}
		refreshSign(base)
		table.insert(bases, base)
	end
end

function BaseService.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Zones.PollSeconds)
			poll()
		end
	end)
end

-- Returns false when every room is taken (the player then plays without a safe room).
function BaseService.Assign(player: Player): boolean
	for _, base in bases do
		if base.owner == nil then
			base.owner = player
			baseOf[player] = base
			base.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("BaseIndex", base.index)
			base.levelConnection = player:GetAttributeChangedSignal("Level"):Connect(function()
				refreshSign(base)
			end)
			refreshSign(base)
			return true
		end
	end
	warn(`No free dressing room for {player.Name}`)
	return false
end

function BaseService.Release(player: Player)
	insideOwnBase[player] = nil
	local base = baseOf[player]
	if base == nil then
		return
	end
	baseOf[player] = nil
	base.owner = nil
	if base.levelConnection then
		base.levelConnection:Disconnect()
		base.levelConnection = nil
	end
	base.model:SetAttribute("OwnerUserId", nil)
	refreshSign(base)
end

function BaseService.GetSpawnCFrame(player: Player): CFrame
	local base = baseOf[player]
	if base == nil then
		return fallbackSpawn
	end
	return base.spawnPoint.CFrame + Vector3.new(0, 3, 0)
end

function BaseService.IsInOwnBase(player: Player): boolean
	return insideOwnBase[player] == true
end

function BaseService.OnCharacterAdded(player: Player, character: Model)
	local base = baseOf[player]
	local group = if base then CollisionGroups.ownerGroup(base.index) else CollisionGroups.CHARACTERS
	CollisionGroups.setCharacterGroup(character, group)
end

return BaseService
