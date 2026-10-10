--!strict
-- Per-player combat timers, shared by CombatService (writes) and other services (reads), so that ItemService
-- can refuse pickups from a knocked-out player without depending on CombatService.
-- Timers are also published as Player attributes in server time (KnockedUntil, ImmuneUntil, ProtectedUntil)
-- for the client UI.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

type Timers = {
	knockedUntil: number,
	immuneUntil: number, -- after a knockout: can't be knocked out again
	protectedUntil: number, -- after leaving the dressing room: can't be hit and can't hit
}

local CombatState = {}

local timers: { [Player]: Timers } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function get(player: Player): Timers
	local existing = timers[player]
	if existing then
		return existing
	end
	local created = { knockedUntil = 0, immuneUntil = 0, protectedUntil = 0 }
	timers[player] = created
	return created
end

function CombatState.isKnockedOut(player: Player): boolean
	return now() < get(player).knockedUntil
end

function CombatState.isExitProtected(player: Player): boolean
	return now() < get(player).protectedUntil
end

-- Nobody can knock this player out right now.
function CombatState.isInvulnerable(player: Player): boolean
	local t = get(player)
	local time = now()
	return time < t.knockedUntil or time < t.immuneUntil or time < t.protectedUntil
end

-- End of the longest running "can't be hit" timer (used for the shield visual).
function CombatState.shieldUntil(player: Player): number
	local t = get(player)
	return math.max(t.immuneUntil, t.protectedUntil)
end

function CombatState.setKnockedOut(player: Player, seconds: number, immunityAfter: number)
	local t = get(player)
	t.knockedUntil = now() + seconds
	t.immuneUntil = t.knockedUntil + immunityAfter
	player:SetAttribute("KnockedUntil", t.knockedUntil)
	player:SetAttribute("ImmuneUntil", t.immuneUntil)
end

function CombatState.setExitProtected(player: Player, seconds: number)
	local t = get(player)
	t.protectedUntil = now() + seconds
	player:SetAttribute("ProtectedUntil", t.protectedUntil)
end

-- Fresh character: no knockout carries over a respawn.
function CombatState.reset(player: Player)
	timers[player] = nil
	player:SetAttribute("KnockedUntil", 0)
	player:SetAttribute("ImmuneUntil", 0)
	player:SetAttribute("ProtectedUntil", 0)
end

Players.PlayerRemoving:Connect(function(player)
	timers[player] = nil
end)

return CombatState
