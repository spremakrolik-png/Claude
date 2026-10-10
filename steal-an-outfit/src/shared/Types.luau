--!strict
-- Shared type definitions. Every module that passes these shapes around imports them from here.

export type SlotId = "Head" | "Face" | "Neck" | "Chest" | "Back" | "Waist"

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type MutationId = "None" | "Gold" | "Diamond" | "Rainbow"

-- Placeholder shape used when no real model exists for an item.
export type ItemStyle =
	"Crown"
	| "Hat"
	| "Halo"
	| "Glasses"
	| "Mask"
	| "Beads"
	| "Scarf"
	| "Medal"
	| "Bow"
	| "Gem"
	| "Wings"
	| "Cape"
	| "Bag"
	| "Belt"
	| "Pouch"

export type SlotDef = {
	id: SlotId,
	attachment: string, -- character attachment the accessory is welded to
	displayName: string,
}

export type RarityDef = {
	id: RarityId,
	displayName: string, -- shown in the UI ("Легендарный")
	order: number, -- 1 = most common; used for sorting and "X or better" checks
	weight: number, -- relative spawn weight
	income: number, -- base income per second
	color: Color3, -- color of the item itself
	uiColor: Color3, -- color used for text and UI strokes (differs from `color` only for very dark rarities)
	glow: boolean, -- Highlight + particles + light on the wearer
	announce: boolean, -- server-wide banner when it spawns
}

export type MutationDef = {
	id: MutationId,
	weight: number, -- relative roll weight (percent)
	multiplier: number, -- income multiplier
	label: string, -- shown after the item name: "Корона Дрипа (Золото)"; empty for no mutation
	color: Color3, -- UI color of the label
}

-- Static catalog entry.
export type ItemDef = {
	id: string,
	displayName: string,
	slot: SlotId,
	rarity: RarityId,
	style: ItemStyle,
	baseIncome: number?, -- overrides the rarity income when set
	assetName: string?, -- name of a ready-made Accessory in ReplicatedStorage/Assets/Items
}

-- A concrete item that exists in the world, on a body, or in a wardrobe.
-- `uid` is unique per instance, which is what prevents duplication.
export type ItemInstance = {
	uid: string,
	itemId: string,
	mutation: MutationId,
}

export type Equipped = { [SlotId]: ItemInstance }

export type PlayerData = {
	cash: number,
	level: number,
	equipped: Equipped,
	wardrobe: { ItemInstance },
	protectedSlots: { SlotId },
	receipts: { [string]: boolean },
	stats: {
		stolen: number,
		knockouts: number,
	},
}

export type NotifyKind = "Info" | "Success" | "Warning" | "Rare"

export type KnockbackStrength = "Weak" | "Medium" | "Strong" | "VeryStrong"

-- How a tool finds its targets. Phase 2 implements "Melee"; the others arrive with their tools in Phase 4.
export type ToolKind = "Melee"

export type ToolDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	kind: ToolKind,
	range: number, -- studs
	arcDegrees: number, -- full width of the cone in front of the attacker
	knockoutSeconds: number,
	knockback: KnockbackStrength,
	cooldownSeconds: number,
	dizzyText: string, -- floats above the knocked-out player's head
}

export type SwapOffer = {
	offerId: string,
	slot: SlotId,
	newItem: ItemInstance,
	oldItem: ItemInstance,
	expiresAt: number, -- workspace:GetServerTimeNow() based
}

return {}
