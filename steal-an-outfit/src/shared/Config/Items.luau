--!strict
-- Item catalog. To use a real model for an item, put an Accessory named after the item `id`
-- (or after `assetName` when set) into ReplicatedStorage/Assets/Items. Otherwise a placeholder
-- of the given `style` is built from primitives.
local Types = require(script.Parent.Parent.Types)

local Items: { Types.ItemDef } = {
	-- Head
	{
		id = "ThriftBeret",
		displayName = "Берет из секонд-хенда",
		slot = "Head",
		rarity = "Common",
		style = "Hat",
	},
	{
		id = "VibesBucketHat",
		displayName = "Панамка Вайба",
		slot = "Head",
		rarity = "Uncommon",
		style = "Hat",
	},
	{ id = "DripCrown", displayName = "Корона Дрипа", slot = "Head", rarity = "Epic", style = "Crown" },
	{
		id = "MainCharacterTiara",
		displayName = "Тиара Главной Героини",
		slot = "Head",
		rarity = "Legendary",
		style = "Crown",
	},
	{
		id = "InfiniteAuraHalo",
		displayName = "Нимб Бесконечной Ауры",
		slot = "Head",
		rarity = "Secret",
		style = "Halo",
	},

	-- Face
	{
		id = "DollarStoreShades",
		displayName = "Очки за сто рублей",
		slot = "Face",
		rarity = "Common",
		style = "Glasses",
	},
	{
		id = "HeartGlasses",
		displayName = "Очки-сердечки",
		slot = "Face",
		rarity = "Uncommon",
		style = "Glasses",
	},
	{
		id = "MainCharacterShades",
		displayName = "Очки Главного Героя",
		slot = "Face",
		rarity = "Rare",
		style = "Glasses",
	},
	{
		id = "MasqueradeMask",
		displayName = "Загадочная маска",
		slot = "Face",
		rarity = "Epic",
		style = "Mask",
	},
	{
		id = "PlotArmorVeil",
		displayName = "Вуаль Сюжетной Брони",
		slot = "Face",
		rarity = "Mythic",
		style = "Mask",
	},

	-- Neck
	{
		id = "PlasticBeads",
		displayName = "Пластиковые бусы",
		slot = "Neck",
		rarity = "Common",
		style = "Beads",
	},
	{
		id = "GrandmasPearls",
		displayName = "Бабушкин жемчуг",
		slot = "Neck",
		rarity = "Rare",
		style = "Beads",
	},
	{ id = "RizzChain", displayName = "Цепь Ризза", slot = "Neck", rarity = "Epic", style = "Beads" },
	{ id = "ChaosChoker", displayName = "Чокер Хаоса", slot = "Neck", rarity = "Legendary", style = "Scarf" },
	{
		id = "InfiniteDripScarf",
		displayName = "Шарф Бесконечного Дрипа",
		slot = "Neck",
		rarity = "Mythic",
		style = "Scarf",
	},

	-- Chest
	{
		id = "ParticipationMedal",
		displayName = "Медаль за участие",
		slot = "Chest",
		rarity = "Common",
		style = "Medal",
	},
	{
		id = "BusinessBowTie",
		displayName = "Бабочка Бизнесмена",
		slot = "Chest",
		rarity = "Uncommon",
		style = "Bow",
	},
	{ id = "GossipBrooch", displayName = "Брошь Сплетен", slot = "Chest", rarity = "Rare", style = "Gem" },
	{
		id = "MedalOfSlay",
		displayName = "Медаль «Слэй»",
		slot = "Chest",
		rarity = "Legendary",
		style = "Medal",
	},
	{
		id = "HeartOfTheRunway",
		displayName = "Сердце Подиума",
		slot = "Chest",
		rarity = "Secret",
		style = "Gem",
	},

	-- Back
	{
		id = "GroceryTote",
		displayName = "Шоппер с продуктами",
		slot = "Back",
		rarity = "Common",
		style = "Bag",
	},
	{
		id = "MiniBackpack",
		displayName = "Бесполезный мини-рюкзак",
		slot = "Back",
		rarity = "Uncommon",
		style = "Bag",
	},
	{
		id = "OverconfidenceCape",
		displayName = "Плащ Самоуверенности",
		slot = "Back",
		rarity = "Rare",
		style = "Cape",
	},
	{
		id = "ButterflyWings",
		displayName = "Крылья бабочки",
		slot = "Back",
		rarity = "Epic",
		style = "Wings",
	},
	{
		id = "AngelWingsOfDebt",
		displayName = "Ангельские крылья в кредит",
		slot = "Back",
		rarity = "Mythic",
		style = "Wings",
	},

	-- Waist
	{
		id = "BasicBelt",
		displayName = "Обычный ремень",
		slot = "Waist",
		rarity = "Common",
		style = "Belt",
	},
	{
		id = "FannyPackDeluxe",
		displayName = "Поясная сумка Делюкс",
		slot = "Waist",
		rarity = "Uncommon",
		style = "Pouch",
	},
	{
		id = "SassChainBelt",
		displayName = "Цепь-пояс Дерзости",
		slot = "Waist",
		rarity = "Rare",
		style = "Belt",
	},
	{
		id = "ConfidenceCorset",
		displayName = "Корсет Уверенности",
		slot = "Waist",
		rarity = "Epic",
		style = "Pouch",
	},
	{
		id = "DripChampionBelt",
		displayName = "Чемпионский пояс Дрипа",
		slot = "Waist",
		rarity = "Legendary",
		style = "Belt",
	},
}

return Items
