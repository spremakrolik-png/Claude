--!strict
-- Item instances on bodies and on the floor: equipping, the swap dialog, and physical drops.
-- Anything that can be picked up (a mannequin display, a floor drop) is described by a PickupSource,
-- so the pickup and swap rules live in one place.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local ItemVisuals = require(ReplicatedStorage.Shared.ItemVisuals)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CollisionGroups = require(script.Parent.Parent.Util.CollisionGroups)
local HoldTracker = require(script.Parent.Parent.Util.HoldTracker)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local AnnouncementService = require(script.Parent.AnnouncementService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)

export type PickupSource = {
	item: Types.ItemInstance,
	getPosition: () -> Vector3,
	isAvailable: () -> boolean,
	consume: () -> (), -- removes the item from the world
	goneMessage: (() -> string)?, -- why the item is gone when a swap is confirmed too late
}

type PendingSwap = {
	offer: Types.SwapOffer,
	source: PickupSource,
}

local DROPS = GameConfig.Drops

local ItemService = {}

local pendingSwaps: { [Player]: PendingSwap } = {}
local swapLimiter = RateLimiter.new(GameConfig.RateLimits.SwapResponsePerSecond, 1)
local rng = Random.new()
local dropsFolder: Folder
local arenaCenter = Vector3.zero
local arenaRadius = GameConfig.Map.ArenaRadius

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function findOutfitAccessory(character: Model, slot: Types.SlotId): Accessory?
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("OutfitSlot") == slot then
			return child
		end
	end
	return nil
end

local function attachToCharacter(player: Player, item: Types.ItemInstance)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local slot: Types.SlotId? = ItemUtil.getSlot(item)
	if character == nil or humanoid == nil or slot == nil then
		return
	end
	local previous = findOutfitAccessory(character, slot)
	if previous then
		previous:Destroy()
	end
	local accessory = ItemVisuals.buildAccessory(item)
	accessory:SetAttribute("OutfitSlot", slot)
	humanoid:AddAccessory(accessory)
end

local function sendEquipped(player: Player)
	local data = PlayerDataService.Get(player)
	if data ~= nil then
		Remotes.get("EquippedChanged"):FireClient(player, data.equipped)
	end
end

local function equip(player: Player, data: Types.PlayerData, item: Types.ItemInstance)
	local slot: Types.SlotId? = ItemUtil.getSlot(item)
	if slot == nil then
		return
	end
	data.equipped[slot] = item
	attachToCharacter(player, item)
	EconomyService.RefreshIncome(player)
	sendEquipped(player)
	local income = Format.money(EconomyService.GetIncomePerSecond(player))
	AnnouncementService.Notify(player, `Wearing {ItemUtil.getDisplayName(item)}! You now earn {income}/s`, "Success")
end

local function withinReach(root: BasePart, position: Vector3, limit: number): boolean
	return (root.Position - position).Magnitude <= limit
end

function ItemService.NewInstance(itemId: string, mutation: Types.MutationId): Types.ItemInstance
	return {
		uid = HttpService:GenerateGUID(false),
		itemId = itemId,
		mutation = mutation,
	}
end

function ItemService.GetEquipped(player: Player): Types.Equipped?
	local data = PlayerDataService.Get(player)
	return if data then data.equipped else nil
end

-- Removes the item from the slot and from the character. Returns what was removed.
function ItemService.Unequip(player: Player, slot: Types.SlotId): Types.ItemInstance?
	local data = PlayerDataService.Get(player)
	local item = if data then data.equipped[slot] else nil
	if data == nil or item == nil then
		return nil
	end
	data.equipped[slot] = nil
	local character = player.Character
	local accessory = if character then findOutfitAccessory(character, slot) else nil
	if accessory then
		accessory:Destroy()
	end
	EconomyService.RefreshIncome(player)
	sendEquipped(player)
	return item
end

-- Called by mannequin and floor prompts once the hold finished.
function ItemService.TryPickup(player: Player, source: PickupSource)
	local data = PlayerDataService.Get(player)
	local root = rootPart(player)
	if data == nil or root == nil or not source.isAvailable() then
		return
	end
	if BaseService.IsInOwnBase(player) then
		return
	end
	if not withinReach(root, source.getPosition(), DROPS.PromptDistance + DROPS.PickupDistanceSlack) then
		return
	end
	local slot: Types.SlotId? = ItemUtil.getSlot(source.item)
	if slot == nil then
		return
	end

	local current = data.equipped[slot]
	if current == nil then
		source.consume()
		equip(player, data, source.item)
		return
	end

	-- Slot taken: ask the player. The item stays in the world meanwhile; whoever is faster gets it.
	local offer: Types.SwapOffer = {
		offerId = HttpService:GenerateGUID(false),
		slot = slot,
		newItem = source.item,
		oldItem = current,
		expiresAt = Workspace:GetServerTimeNow() + DROPS.SwapOfferSeconds,
	}
	pendingSwaps[player] = { offer = offer, source = source }
	Remotes.get("SwapOffer"):FireClient(player, offer)
	task.delay(DROPS.SwapOfferSeconds + 1, function()
		local pending = pendingSwaps[player]
		if pending ~= nil and pending.offer.offerId == offer.offerId then
			pendingSwaps[player] = nil
		end
	end)
end

local function onSwapResponse(player: Player, offerId: unknown, accept: unknown)
	if typeof(offerId) ~= "string" or typeof(accept) ~= "boolean" or not swapLimiter(player) then
		return
	end
	local pending = pendingSwaps[player]
	if pending == nil or pending.offer.offerId ~= offerId then
		return
	end
	pendingSwaps[player] = nil
	if not accept then
		return
	end

	local offer = pending.offer
	local source = pending.source
	local data = PlayerDataService.Get(player)
	local root = rootPart(player)
	if data == nil or root == nil then
		return
	end
	if Workspace:GetServerTimeNow() > offer.expiresAt then
		AnnouncementService.Notify(player, "Too late! The offer expired.", "Warning")
		return
	end
	local current = data.equipped[offer.slot]
	if current == nil or current.uid ~= offer.oldItem.uid then
		return
	end
	if not source.isAvailable() then
		local message = if source.goneMessage then source.goneMessage() else "Too slow! Someone else grabbed it."
		AnnouncementService.Notify(player, message, "Warning")
		return
	end
	if BaseService.IsInOwnBase(player) or not withinReach(root, source.getPosition(), DROPS.SwapMaxDistance) then
		AnnouncementService.Notify(player, "You walked too far away.", "Warning")
		return
	end

	source.consume()
	local removed = ItemService.Unequip(player, offer.slot)
	if removed ~= nil then
		ItemService.DropOnFloor(removed, root.Position)
	end
	equip(player, data, source.item)
end

-- Lowest world Y of the visible parts of `model` (used to keep long items like capes above the floor).
local SIGNS = { -1, 1 }
local function lowestVisibleY(model: Model, ignore: BasePart): number
	local lowest = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= ignore and descendant.Transparency < 1 then
			local half = descendant.Size / 2
			for _, x in SIGNS do
				for _, y in SIGNS do
					for _, z in SIGNS do
						local corner =
							descendant.CFrame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
						lowest = math.min(lowest, corner.Y)
					end
				end
			end
		end
	end
	return lowest
end

local function settleDrop(model: Model, root: BasePart, item: Types.ItemInstance, source: PickupSource)
	-- Keep drops on the arena floor: pull them in from the wall, then snap them onto the ground.
	local position = root.Position
	local flat = Vector3.new(position.X - arenaCenter.X, 0, position.Z - arenaCenter.Z)
	local maxRadius = arenaRadius - 4
	if flat.Magnitude > maxRadius then
		flat = flat.Unit * maxRadius
	end
	local params = RaycastParams.new()
	params.CollisionGroup = CollisionGroups.PICKUPS
	local above = arenaCenter + flat + Vector3.new(0, position.Y - arenaCenter.Y + 4, 0)
	local hit = Workspace:Raycast(above, Vector3.new(0, -60, 0), params)
	local floorY = if hit then hit.Position.Y else arenaCenter.Y

	root.Anchored = true
	root.CFrame = CFrame.new(above.X, floorY + 1.6, above.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local sink = floorY + 0.2 - lowestVisibleY(model, root)
	if sink > 0 then
		root.CFrame += Vector3.new(0, sink, 0)
	end

	local rarity = ItemUtil.getRarity(item)
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.1, 2.6, 2.6)
	glow.CFrame = CFrame.new(above.X, floorY + 0.06, above.Z) * CFrame.Angles(0, 0, math.pi / 2)
	glow.Color = rarity.uiColor
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.35
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.Parent = model

	ItemVisuals.makeLabel(item, root, 2.6).Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = `{ItemUtil.getDisplayName(item)} ({Format.money(ItemUtil.getIncome(item))}/s)`
	prompt.HoldDuration = DROPS.FloorHoldSeconds
	prompt.MaxActivationDistance = DROPS.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local holds = HoldTracker.watch(prompt, function()
		return if source.isAvailable() then item.uid else nil
	end)
	prompt.Triggered:Connect(function(player)
		if holds.consume(player, item.uid) then
			ItemService.TryPickup(player, source)
		end
	end)
end

-- Pops an item out of `origin` onto the floor, where anyone can pick it up until it expires.
function ItemService.DropOnFloor(item: Types.ItemInstance, origin: Vector3)
	local model = ItemVisuals.buildModel(item)
	local handle = model.PrimaryPart
	assert(handle ~= nil, "Item model has no PrimaryPart")
	model.Name = "Drop"
	model:PivotTo(CFrame.new(origin + Vector3.new(0, 1.5, 0)))

	-- The root sits where the body attachment would be, so an upright root shows the item upright, as worn.
	local def = ItemUtil.getDef(item.itemId)
	local own = if def then handle:FindFirstChild(ItemUtil.getSlotDef(def.slot).attachment) else nil
	local attachmentOffset = if own ~= nil and own:IsA("Attachment") then own.CFrame else CFrame.identity

	-- Visual parts are massless and non-colliding; this invisible box carries the physics.
	local root = Instance.new("Part")
	root.Name = "PickupRoot"
	root.Size = Vector3.one * 1.4
	root.Transparency = 1
	root.CanTouch = false
	root.CanQuery = false
	root.CollisionGroup = CollisionGroups.PICKUPS
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 1, 0.1)
	root.CFrame = handle.CFrame * attachmentOffset
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = handle
	weld.C0 = attachmentOffset:Inverse()
	weld.Parent = root
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = dropsFolder

	root:SetNetworkOwner(nil)
	local angle = rng:NextNumber(0, math.pi * 2)
	root.AssemblyLinearVelocity = Vector3.new(
		math.cos(angle) * DROPS.DropPopHorizontal,
		DROPS.DropPopVertical,
		math.sin(angle) * DROPS.DropPopHorizontal
	)
	root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))

	local available = false -- not pickable while still flying
	local source: PickupSource = {
		item = item,
		getPosition = function()
			return root.Position
		end,
		isAvailable = function()
			return available and model.Parent ~= nil
		end,
		consume = function()
			available = false
			model:Destroy()
		end,
	}

	task.delay(DROPS.FloorSettleSeconds, function()
		if model.Parent ~= nil then
			settleDrop(model, root, item, source)
			available = true
		end
	end)
	task.delay(DROPS.FloorItemLifetimeSeconds, function()
		available = false
		model:Destroy()
	end)
end

function ItemService.SendSnapshot(player: Player)
	sendEquipped(player)
end

-- Re-dresses the character with everything the player wears (after spawn or respawn).
function ItemService.OnCharacterAdded(player: Player, character: Model)
	-- The avatar's appearance can still swap body parts right after spawning; attach after it settled.
	if not player:HasAppearanceLoaded() then
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Once(function()
			loaded = true
		end)
		local deadline = os.clock() + 5
		while not loaded and os.clock() < deadline and player.Character == character do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
	local data = PlayerDataService.Get(player)
	if data == nil or player.Character ~= character then
		return
	end
	for _, item in data.equipped do
		attachToCharacter(player, item)
	end
end

function ItemService.OnPlayerRemoving(player: Player)
	pendingSwaps[player] = nil
end

function ItemService.Init(map: MapBuilder.MapRefs)
	dropsFolder = map.drops
	arenaCenter = map.center
	arenaRadius = map.arenaRadius
end

function ItemService.Start()
	Remotes.get("SwapResponse").OnServerEvent:Connect(onSwapResponse)
end

return ItemService
