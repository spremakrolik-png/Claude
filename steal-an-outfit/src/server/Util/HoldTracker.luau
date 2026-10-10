--!strict
-- Server-side check for hold-to-use ProximityPrompts. Triggered alone can be fired by an exploit without holding,
-- so a pickup only counts if the server saw a full hold (began, and not released early) on the same item.
-- A hit interrupts every pickup in progress: CombatService calls HoldTracker.cancelEverywhere(victim).
local Players = game:GetService("Players")

-- Allowed difference between the client's hold time and what the server measured (network jitter).
local TOLERANCE_SECONDS = 0.25

export type Tracker = {
	-- Whether `player` held this prompt on item `uid` long enough, plus the uid the hold was on.
	-- Consumes the hold either way.
	consume: (player: Player, uid: string) -> (boolean, string?),
	cancel: (player: Player) -> (),
}

type Hold = {
	uid: string,
	startedAt: number,
	endedAt: number?,
}

local HoldTracker = {}

local trackers: { [Tracker]: true } = setmetatable({}, { __mode = "k" }) :: any

-- `currentUid` returns the uid of the item the prompt offers right now (nil when there is none).
function HoldTracker.watch(prompt: ProximityPrompt, currentUid: () -> string?): Tracker
	local holds: { [Player]: Hold } = {}

	prompt.PromptButtonHoldBegan:Connect(function(player)
		local uid = currentUid()
		if uid ~= nil then
			holds[player] = { uid = uid, startedAt = os.clock(), endedAt = nil }
		else
			holds[player] = nil
		end
	end)
	-- A released hold is remembered with its length, so a short tap cannot be "armed" and completed later.
	prompt.PromptButtonHoldEnded:Connect(function(player)
		local hold = holds[player]
		if hold ~= nil and hold.endedAt == nil then
			hold.endedAt = os.clock()
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)
	local tracker: Tracker
	prompt.Destroying:Once(function()
		leaving:Disconnect()
		trackers[tracker] = nil
	end)

	tracker = {
		consume = function(player: Player, uid: string): (boolean, string?)
			local hold = holds[player]
			holds[player] = nil
			if hold == nil then
				return false, nil
			end
			local needed = prompt.HoldDuration - TOLERANCE_SECONDS
			local heldFor = (hold.endedAt or os.clock()) - hold.startedAt
			return hold.uid == uid and heldFor >= needed, hold.uid
		end,
		cancel = function(player: Player)
			holds[player] = nil
		end,
	}
	trackers[tracker] = true
	return tracker
end

-- Drops `player`'s holds on every watched prompt (used when the player gets knocked out).
function HoldTracker.cancelEverywhere(player: Player)
	for tracker in trackers do
		tracker.cancel(player)
	end
end

return HoldTracker
