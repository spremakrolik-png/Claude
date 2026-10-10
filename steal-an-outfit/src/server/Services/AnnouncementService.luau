--!strict
-- Toasts for one player and banners for the whole server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local AnnouncementService = {}

function AnnouncementService.Notify(player: Player, text: string, kind: Types.NotifyKind?)
	Remotes.get("Notify"):FireClient(player, text, kind or "Info")
end

function AnnouncementService.Broadcast(text: string, kind: Types.NotifyKind?)
	Remotes.get("Notify"):FireAllClients(text, kind or "Info")
end

return AnnouncementService
