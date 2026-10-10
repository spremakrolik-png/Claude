--!strict
-- Item catalog. To use a real model for an item, put an Accessory named after the item `id`
-- (or after `assetName` when set) into ReplicatedStorage/Assets/Items. Otherwise a placeholder
-- of the given `style` is built from primitives.
local Types = require(script.Parent.Parent.Types)

local Items: { Types.ItemDef } = {
	-- Head
	{ id = "ThriftBeret", displayName = "Thrift Store Beret", slot = "Head", rarity = "Common", style = "Hat" },
	{ id = "VibesBucketHat", displayName = "Bucket Hat of Vibes", slot = "Head", rarity = "Uncommon", style = "Hat" },
	{ id = "DripCrown", displayName = "Drip Crown", slot = "Head", rarity = "Epic", style = "Crown" },
	{
		id = "MainCharacterTiara",
		displayName = "Main Character Tiara",
		slot = "Head",
		rarity = "Legendary",
		style = "Crown",
	},
	{
		id = "InfiniteAuraHalo",
		displayName = "Halo of Infinite Aura",
		slot = "Head",
		rarity = "Secret",
		style = "Halo",
	},

	-- Face
	{
		id = "DollarStoreShades",
		displayName = "Dollar Store Shades",
		slot = "Face",
		rarity = "Common",
		style = "Glasses",
	},
	{
		id = "HeartGlasses",
		displayName = "Heart-Shaped Glasses",
		slot = "Face",
		rarity = "Uncommon",
		style = "Glasses",
	},
	{
		id = "MainCharacterShades",
		displayName = "Main Character Shades",
		slot = "Face",
		rarity = "Rare",
		style = "Glasses",
	},
	{
		id = "MasqueradeMask",
		displayName = "Mysterious Masquerade Mask",
		slot = "Face",
		rarity = "Epic",
		style = "Mask",
	},
	{ id = "PlotArmorVeil", displayName = "Veil of Plot Armor", slot = "Face", rarity = "Mythic", style = "Mask" },

	-- Neck
	{ id = "PlasticBeads", displayName = "Plastic Bead Necklace", slot = "Neck", rarity = "Common", style = "Beads" },
	{ id = "GrandmasPearls", displayName = "Grandma's Pearls", slot = "Neck", rarity = "Rare", style = "Beads" },
	{ id = "RizzChain", displayName = "Rizz Chain", slot = "Neck", rarity = "Epic", style = "Beads" },
	{ id = "ChaosChoker", displayName = "Choker of Chaos", slot = "Neck", rarity = "Legendary", style = "Scarf" },
	{
		id = "InfiniteDripScarf",
		displayName = "Infinite Drip Scarf",
		slot = "Neck",
		rarity = "Mythic",
		style = "Scarf",
	},

	-- Chest
	{
		id = "ParticipationMedal",
		displayName = "Participation Medal",
		slot = "Chest",
		rarity = "Common",
		style = "Medal",
	},
	{ id = "BusinessBowTie", displayName = "Bow Tie of Business", slot = "Chest", rarity = "Uncommon", style = "Bow" },
	{ id = "GossipBrooch", displayName = "Brooch of Gossip", slot = "Chest", rarity = "Rare", style = "Gem" },
	{ id = "MedalOfSlay", displayName = "Medal of Slay", slot = "Chest", rarity = "Legendary", style = "Medal" },
	{ id = "HeartOfTheRunway", displayName = "Heart of the Runway", slot = "Chest", rarity = "Secret", style = "Gem" },

	-- Back
	{ id = "GroceryTote", displayName = "Tote Bag of Groceries", slot = "Back", rarity = "Common", style = "Bag" },
	{ id = "MiniBackpack", displayName = "Tiny Useless Backpack", slot = "Back", rarity = "Uncommon", style = "Bag" },
	{
		id = "OverconfidenceCape",
		displayName = "Cape of Overconfidence",
		slot = "Back",
		rarity = "Rare",
		style = "Cape",
	},
	{ id = "ButterflyWings", displayName = "Butterfly Wings", slot = "Back", rarity = "Epic", style = "Wings" },
	{ id = "AngelWingsOfDebt", displayName = "Angel Wings of Debt", slot = "Back", rarity = "Mythic", style = "Wings" },

	-- Waist
	{ id = "BasicBelt", displayName = "Basic Belt", slot = "Waist", rarity = "Common", style = "Belt" },
	{ id = "FannyPackDeluxe", displayName = "Fanny Pack Deluxe", slot = "Waist", rarity = "Uncommon", style = "Pouch" },
	{ id = "SassChainBelt", displayName = "Chain Belt of Sass", slot = "Waist", rarity = "Rare", style = "Belt" },
	{ id = "ConfidenceCorset", displayName = "Corset of Confidence", slot = "Waist", rarity = "Epic", style = "Pouch" },
	{
		id = "DripChampionBelt",
		displayName = "Championship Belt of Drip",
		slot = "Waist",
		rarity = "Legendary",
		style = "Belt",
	},
}

return Items
