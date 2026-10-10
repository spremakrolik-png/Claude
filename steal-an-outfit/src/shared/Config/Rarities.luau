--!strict
local Types = require(script.Parent.Parent.Types)

local Order: { Types.RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local Defs: { [Types.RarityId]: Types.RarityDef } = {
	Common = {
		id = "Common",
		displayName = "Обычный",
		order = 1,
		weight = 55,
		income = 1,
		color = Color3.fromRGB(176, 176, 188),
		uiColor = Color3.fromRGB(205, 205, 215),
		glow = false,
		announce = false,
	},
	Uncommon = {
		id = "Uncommon",
		displayName = "Необычный",
		order = 2,
		weight = 25,
		income = 3,
		color = Color3.fromRGB(76, 214, 104),
		uiColor = Color3.fromRGB(96, 230, 122),
		glow = false,
		announce = false,
	},
	Rare = {
		id = "Rare",
		displayName = "Редкий",
		order = 3,
		weight = 12,
		income = 8,
		color = Color3.fromRGB(58, 136, 255),
		uiColor = Color3.fromRGB(92, 160, 255),
		glow = false,
		announce = false,
	},
	Epic = {
		id = "Epic",
		displayName = "Эпический",
		order = 4,
		weight = 5,
		income = 20,
		color = Color3.fromRGB(168, 76, 255),
		uiColor = Color3.fromRGB(190, 120, 255),
		glow = false,
		announce = false,
	},
	Legendary = {
		id = "Legendary",
		displayName = "Легендарный",
		order = 5,
		weight = 2.2,
		income = 60,
		color = Color3.fromRGB(255, 196, 36),
		uiColor = Color3.fromRGB(255, 208, 70),
		glow = true,
		announce = true,
	},
	Mythic = {
		id = "Mythic",
		displayName = "Мифический",
		order = 6,
		weight = 0.7,
		income = 150,
		color = Color3.fromRGB(255, 46, 70),
		uiColor = Color3.fromRGB(255, 84, 104),
		glow = true,
		announce = true,
	},
	Secret = {
		id = "Secret",
		displayName = "Секретный",
		order = 7,
		weight = 0.1,
		income = 500,
		color = Color3.fromRGB(24, 22, 30),
		uiColor = Color3.fromRGB(255, 120, 235),
		glow = true,
		announce = true,
	},
}

return {
	Order = Order,
	Defs = Defs,
}
