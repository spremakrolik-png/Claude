--!strict
-- Tools that knock players out. Unlocked by level and kept forever.
-- Phase 2 has the Handbag Slap; the other six tools (and their kinds) arrive in Phase 4.
-- To use a real model, put a Tool named after the tool `id` into ReplicatedStorage/Assets/Tools.
local Types = require(script.Parent.Parent.Types)

local Order: { string } = { "HandbagSlap" }

local Defs: { [string]: Types.ToolDef } = {
	HandbagSlap = {
		id = "HandbagSlap",
		displayName = "Сумочка",
		unlockLevel = 1,
		kind = "Melee",
		range = 6,
		arcDegrees = 120,
		knockoutSeconds = 1.5,
		knockback = "Medium",
		cooldownSeconds = 3,
		dizzyText = "💫 💫 💫",
	},
}

return {
	Order = Order,
	Defs = Defs,
}
