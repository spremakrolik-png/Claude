--!strict
-- Collision groups:
--   Characters      players without a dressing room (and the default for characters)
--   BaseOwner<i>    the owner of dressing room i: walks through Barrier<i>
--   BaseBarrier<i>  the doorway of dressing room i: blocks everyone else
--   Pickups         dropped items: collide with the map and barriers, never with characters
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.CHARACTERS = "Characters"
CollisionGroups.PICKUPS = "Pickups"

function CollisionGroups.ownerGroup(baseIndex: number): string
	return `BaseOwner{baseIndex}`
end

function CollisionGroups.barrierGroup(baseIndex: number): string
	return `BaseBarrier{baseIndex}`
end

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function CollisionGroups.setup(baseCount: number)
	register(CollisionGroups.CHARACTERS)
	register(CollisionGroups.PICKUPS)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PICKUPS, CollisionGroups.CHARACTERS, false)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PICKUPS, CollisionGroups.PICKUPS, false)

	for index = 1, baseCount do
		local owner = CollisionGroups.ownerGroup(index)
		local barrier = CollisionGroups.barrierGroup(index)
		register(owner)
		register(barrier)
		PhysicsService:CollisionGroupSetCollidable(owner, barrier, false)
		PhysicsService:CollisionGroupSetCollidable(owner, CollisionGroups.PICKUPS, false)
	end
end

local watchers: { [Model]: RBXScriptConnection } = {}

-- Puts every part of the character (including parts added later, like accessories) into `group`.
function CollisionGroups.setCharacterGroup(character: Model, group: string)
	local function apply(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = group
		end
	end
	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end

	local previous = watchers[character]
	if previous then
		previous:Disconnect()
	end
	watchers[character] = character.DescendantAdded:Connect(apply)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and watchers[character] then
			watchers[character]:Disconnect()
			watchers[character] = nil
		end
	end)
end

return CollisionGroups
