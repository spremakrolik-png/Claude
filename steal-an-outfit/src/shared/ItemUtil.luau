--!strict
-- Lookups and derived values for items. Shared so the client can render names and incomes
-- from the compact ItemInstance tables the server sends.
local Types = require(script.Parent.Types)
local Items = require(script.Parent.Config.Items)
local Rarities = require(script.Parent.Config.Rarities)
local Mutations = require(script.Parent.Config.Mutations)
local GameConfig = require(script.Parent.Config.GameConfig)

local ItemUtil = {}

local defsById: { [string]: Types.ItemDef } = {}
local defsByRarity: { [Types.RarityId]: { Types.ItemDef } } = {}
local slotDefs: { [string]: Types.SlotDef } = {}

for _, def in Items do
	assert(defsById[def.id] == nil, `Duplicate item id "{def.id}"`)
	defsById[def.id] = def
	local list = defsByRarity[def.rarity]
	if list == nil then
		list = {}
		defsByRarity[def.rarity] = list
	end
	table.insert(list, def)
end

for _, slot in GameConfig.Slots do
	slotDefs[slot.id] = slot
end

function ItemUtil.getDef(itemId: string): Types.ItemDef?
	return defsById[itemId]
end

function ItemUtil.getItemsOfRarity(rarity: Types.RarityId): { Types.ItemDef }
	return defsByRarity[rarity] or {}
end

function ItemUtil.getSlotDef(slot: Types.SlotId): Types.SlotDef
	return slotDefs[slot]
end

-- Narrows an untrusted value (e.g. from a remote) to a SlotId.
function ItemUtil.toSlot(value: unknown): Types.SlotId?
	if typeof(value) == "string" and slotDefs[value] ~= nil then
		return slotDefs[value].id
	end
	return nil
end

local FALLBACK_RARITY: Types.RarityId = "Common"
local FALLBACK_MUTATION: Types.MutationId = "None"

function ItemUtil.getRarity(item: Types.ItemInstance): Types.RarityDef
	local def = defsById[item.itemId]
	return Rarities.Defs[if def then def.rarity else FALLBACK_RARITY]
end

function ItemUtil.getMutation(item: Types.ItemInstance): Types.MutationDef
	return Mutations.Defs[item.mutation] or Mutations.Defs[FALLBACK_MUTATION]
end

function ItemUtil.getSlot(item: Types.ItemInstance): Types.SlotId?
	local def = defsById[item.itemId]
	if def == nil then
		return nil
	end
	return def.slot
end

-- Income per second of a single item, including its mutation (player multipliers not included).
function ItemUtil.getIncome(item: Types.ItemInstance): number
	local def = defsById[item.itemId]
	if def == nil then
		return 0
	end
	local base = def.baseIncome or Rarities.Defs[def.rarity].income
	return base * ItemUtil.getMutation(item).multiplier
end

function ItemUtil.getSellPrice(item: Types.ItemInstance): number
	return ItemUtil.getIncome(item) * GameConfig.Economy.SellMultiplier
end

function ItemUtil.getDisplayName(item: Types.ItemInstance): string
	local def = defsById[item.itemId]
	local name = if def then def.displayName else item.itemId
	local mutation = ItemUtil.getMutation(item)
	return if mutation.label ~= "" then `{name} ({mutation.label})` else name
end

-- Same as getDisplayName, with the mutation label colored (for RichText labels).
function ItemUtil.getRichName(item: Types.ItemInstance): string
	local def = defsById[item.itemId]
	local name = if def then def.displayName else item.itemId
	local mutation = ItemUtil.getMutation(item)
	if mutation.label == "" then
		return name
	end
	return `{name} <font color="#{mutation.color:ToHex()}">({mutation.label})</font>`
end

return ItemUtil
