--!strict
-- Server-side check for hold-to-use ProximityPrompts. Triggered alone can be fired by an exploit without holding,
-- so a pickup only counts if the server saw the hold begin on the same item at least HoldDuration ago.
-- Phase 2 will call `cancel(player)` when a hit interrupts a pickup.
local Players = game:GetService("Players")

-- Allowed difference between the client's hold time and what the server measured (network jitter).
local TOLERANCE_SECONDS = 0.25

export type Tracker = {
	-- True when `player` held this prompt on item `uid` long enough. Consumes the hold either way.
	consume: (player: Player, uid: string) -> boolean,
	cancel: (player: Player) -> (),
	reset: () -> (),
}

type Hold = {
	startedAt: number,
	uid: string,
}

local HoldTracker = {}

-- `currentUid` returns the uid of the item the prompt offers right now (nil when there is none).
function HoldTracker.watch(prompt: ProximityPrompt, currentUid: () -> string?): Tracker
	local holds: { [Player]: Hold } = {}

	prompt.PromptButtonHoldBegan:Connect(function(player)
		local uid = currentUid()
		if uid ~= nil then
			holds[player] = { startedAt = os.clock(), uid = uid }
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)
	prompt.Destroying:Once(function()
		leaving:Disconnect()
	end)

	return {
		consume = function(player: Player, uid: string): boolean
			local hold = holds[player]
			holds[player] = nil
			return hold ~= nil
				and hold.uid == uid
				and os.clock() - hold.startedAt >= prompt.HoldDuration - TOLERANCE_SECONDS
		end,
		cancel = function(player: Player)
			holds[player] = nil
		end,
		reset = function()
			table.clear(holds)
		end,
	}
end

return HoldTracker
