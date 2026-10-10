--!strict
-- Drop waves: every WaveIntervalSeconds each mannequin gets a fresh random item (unclaimed ones are replaced).
-- The time of the next wave is published as the Workspace attribute "NextDropAt" (server time).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemUtil = require(ReplicatedStorage.Shared.ItemUtil)
local ItemVisuals = require(ReplicatedStorage.Shared.ItemVisuals)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local HoldTracker = require(script.Parent.Parent.Util.HoldTracker)
local AnnouncementService = require(script.Parent.AnnouncementService)
local ItemService = require(script.Parent.ItemService)
local MapBuilder = require(script.Parent.MapBuilder)

type MannequinState = {
	model: Model,
	promptPart: BasePart,
	prompt: ProximityPrompt,
	attachments: { [string]: Attachment },
	labelHeight: number,
	holds: HoldTracker.Tracker,
	current: Types.ItemInstance?,
	display: Model?,
	replacedUid: string?, -- item that the last wave replaced (for the "too late" message)
}

local DROPS = GameConfig.Drops

local MannequinService = {}

local states: { MannequinState } = {}
local rng = Random.new()

-- Index of a weighted random entry; zero weights are never picked.
local function pickIndex(weights: { number }): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll <= 0 and weight > 0 then
			return index
		end
	end
	return #weights
end

-- `luck` multiplies the weight of Legendary and better (Server Luck boost in Phase 5).
function MannequinService.RollItem(luck: number): Types.ItemInstance
	local rarityWeights = {}
	for index, id: Types.RarityId in Rarities.Order do
		local rarity = Rarities.Defs[id]
		local weight = if rarity.announce then rarity.weight * luck else rarity.weight
		rarityWeights[index] = if #ItemUtil.getItemsOfRarity(id) > 0 then weight else 0
	end
	local rarityId: Types.RarityId = Rarities.Order[pickIndex(rarityWeights)]
	local candidates = ItemUtil.getItemsOfRarity(rarityId)
	local def = candidates[rng:NextInteger(1, #candidates)]

	local mutationWeights = {}
	for index, id: Types.MutationId in Mutations.Order do
		mutationWeights[index] = Mutations.Defs[id].weight
	end
	local mutation: Types.MutationId = Mutations.Order[pickIndex(mutationWeights)]
	return ItemService.NewInstance(def.id, mutation)
end

local function clear(state: MannequinState)
	if state.display then
		state.display:Destroy()
	end
	state.display = nil
	state.current = nil
	state.prompt.Enabled = false
end

local function show(state: MannequinState, item: Types.ItemInstance)
	state.replacedUid = if state.current then state.current.uid else nil
	clear(state)
	local model = ItemVisuals.buildModel(item)
	local def = ItemUtil.getDef(item.itemId)
	local target = if def then state.attachments[ItemUtil.getSlotDef(def.slot).attachment] else nil
	if target ~= nil then
		ItemVisuals.placeOnAttachment(model, item, target)
	else
		-- Mannequin without that attachment: float the item above it instead.
		local handle = model.PrimaryPart
		if handle then
			handle.Anchored = true
		end
		model:PivotTo(state.promptPart.CFrame + Vector3.new(0, state.labelHeight - 1, 0))
	end
	model.Name = "DisplayedItem"
	ItemVisuals.makeLabel(item, state.promptPart, state.labelHeight).Parent = model
	model.Parent = state.model

	state.display = model
	state.current = item
	state.prompt.ObjectText = `{ItemUtil.getDisplayName(item)} ({Format.money(ItemUtil.getIncome(item))}/s)`
	state.prompt.Enabled = true
end

local function onTriggered(state: MannequinState, player: Player)
	local item = state.current
	if item == nil then
		return
	end
	local uid = item.uid
	local held, heldUid = state.holds.consume(player, uid)
	if not held then
		-- The hold started on the previous item and a new wave replaced it mid-hold.
		if heldUid ~= nil and heldUid ~= uid and heldUid == state.replacedUid then
			AnnouncementService.Notify(player, "Too late! A new drop replaced it.", "Warning")
		end
		return
	end
	ItemService.TryPickup(player, {
		item = item,
		getPosition = function()
			return state.promptPart.Position
		end,
		isAvailable = function()
			local current = state.current
			return current ~= nil and current.uid == uid
		end,
		consume = function()
			clear(state)
		end,
		goneMessage = function()
			return if state.replacedUid == uid
				then "Too late! A new drop replaced it."
				else "Too slow! Someone else grabbed it."
		end,
	})
end

local function runWave()
	local announced = 0
	for _, state in states do
		local item = MannequinService.RollItem(1)
		show(state, item)
		local rarity = ItemUtil.getRarity(item)
		if rarity.announce and announced < DROPS.MaxAnnouncementsPerWave then
			announced += 1
			AnnouncementService.Broadcast(
				`A {string.upper(rarity.id)} {ItemUtil.getDisplayName(item)} appeared!`,
				"Rare"
			)
		end
	end
end

local function register(model: Model)
	local promptPart = model:FindFirstChild("PromptPart", true)
	if promptPart == nil or not promptPart:IsA("BasePart") then
		warn(`{model:GetFullName()} has no PromptPart; skipped`)
		return
	end

	local attachments: { [string]: Attachment } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") then
			attachments[descendant.Name] = descendant
		end
	end

	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take"
	prompt.HoldDuration = DROPS.MannequinHoldSeconds
	prompt.MaxActivationDistance = DROPS.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = promptPart

	local state: MannequinState
	local holds = HoldTracker.watch(prompt, function()
		local current = state.current
		return if current then current.uid else nil
	end)
	local created: MannequinState = {
		model = model,
		promptPart = promptPart,
		prompt = prompt,
		attachments = attachments,
		labelHeight = top - promptPart.Position.Y + 2.2, -- clears hats and halos on the head
		holds = holds,
		current = nil,
		display = nil,
		replacedUid = nil,
	}
	state = created
	prompt.Triggered:Connect(function(player)
		onTriggered(state, player)
	end)
	table.insert(states, state)
end

function MannequinService.Init(map: MapBuilder.MapRefs)
	for _, model in map.mannequins do
		register(model)
	end
end

function MannequinService.Start()
	task.spawn(function()
		Workspace:SetAttribute("NextDropAt", Workspace:GetServerTimeNow() + DROPS.FirstWaveDelaySeconds)
		task.wait(DROPS.FirstWaveDelaySeconds)
		while true do
			runWave()
			Workspace:SetAttribute("NextDropAt", Workspace:GetServerTimeNow() + DROPS.WaveIntervalSeconds)
			task.wait(DROPS.WaveIntervalSeconds)
		end
	end)
end

return MannequinService
