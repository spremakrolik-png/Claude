--!strict
local Types = require(script.Parent.Parent.Types)

local Order: { Types.MutationId } = { "None", "Gold", "Diamond", "Rainbow" }

-- Weights are percentages (they sum to 100), multipliers apply to the item's income.
local Defs: { [Types.MutationId]: Types.MutationDef } = {
	None = { id = "None", weight = 90, multiplier = 1, label = "", color = Color3.fromRGB(255, 255, 255) },
	Gold = { id = "Gold", weight = 7, multiplier = 2, label = "Золото", color = Color3.fromRGB(255, 205, 60) },
	Diamond = {
		id = "Diamond",
		weight = 2.5,
		multiplier = 5,
		label = "Алмаз",
		color = Color3.fromRGB(150, 225, 255),
	},
	Rainbow = {
		id = "Rainbow",
		weight = 0.5,
		multiplier = 10,
		label = "Радуга",
		color = Color3.fromRGB(255, 120, 220),
	},
}

return {
	Order = Order,
	Defs = Defs,
}
