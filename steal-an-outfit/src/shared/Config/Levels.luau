--!strict
-- Level progression. Levels are bought with Cash (Phase 4); for now only the income bonus is used.

local Levels = {
	MaxLevel = 20,
	BaseCost = 250,
	CostGrowth = 1.55,
	IncomeBonusPerLevel = 0.05, -- +5% income per level above 1
}

-- Cost to go from `level` to `level + 1`.
function Levels.costToNext(level: number): number
	return math.round(Levels.BaseCost * Levels.CostGrowth ^ (level - 1))
end

function Levels.incomeMultiplier(level: number): number
	return 1 + Levels.IncomeBonusPerLevel * (level - 1)
end

return Levels
