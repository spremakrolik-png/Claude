--!strict
-- Single place that defines every RemoteEvent. The server creates them, clients wait for them.
--
--   ClientReady      C->S  ()                                  client finished wiring listeners
--   Notify           S->C  (text: string, kind: NotifyKind)    toast / banner
--   EquippedChanged  S->C  (equipped: Equipped)                 full snapshot of the player's body slots
--   SwapOffer        S->C  (offer: SwapOffer)                   "slot is taken, swap?" dialog
--   SwapResponse     C->S  (offerId: string, accept: boolean)  answer to a SwapOffer
--   UseTool          C->S  (toolId: string, direction: Vector3) "I swung this tool this way"; the server finds targets
--   CombatEffect     S->C  (kind: "Swing" | "Hit", position: Vector3) sound and particles for everyone
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteName =
	"ClientReady"
	| "Notify"
	| "EquippedChanged"
	| "SwapOffer"
	| "SwapResponse"
	| "UseTool"
	| "CombatEffect"

local REMOTE_NAMES: { RemoteName } =
	{ "ClientReady", "Notify", "EquippedChanged", "SwapOffer", "SwapResponse", "UseTool", "CombatEffect" }
local FOLDER_NAME = "Remotes"

local Remotes = {}

-- Server only: creates the folder and all remotes. Must run before anything calls Remotes.get.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	assert(folder ~= nil, "Remotes folder was not created")
	for _, name in REMOTE_NAMES do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: RemoteName): RemoteEvent
	local remote: Instance?
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		remote = if folder then folder:FindFirstChild(name) else nil
	else
		remote = ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name)
	end
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	error(`Remote "{name}" is missing (did the server call Remotes.init?)`)
end

return Remotes
