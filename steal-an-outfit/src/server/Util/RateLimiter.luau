--!strict
-- Token bucket per player for remote events: `allow(player)` returns false when the player is spamming.

export type Limiter = (player: Player) -> boolean

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}

function RateLimiter.new(maxEvents: number, perSeconds: number): Limiter
	local refillPerSecond = maxEvents / perSeconds
	local buckets: { [Player]: Bucket } = setmetatable({}, { __mode = "k" }) :: any

	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if bucket == nil then
			bucket = { tokens = maxEvents, updatedAt = now }
			buckets[player] = bucket
		end
		bucket.tokens = math.min(maxEvents, bucket.tokens + (now - bucket.updatedAt) * refillPerSecond)
		bucket.updatedAt = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end
end

return RateLimiter
