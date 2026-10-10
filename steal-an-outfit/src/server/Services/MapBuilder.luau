--!strict
-- Builds the round runway arena.
--
-- Lookup order (so placeholders can be swapped for real models without touching code):
--   1. Workspace/Arena                         a complete hand-made map is used as is
--   2. ReplicatedStorage/Assets/Arena          a complete map template is cloned into Workspace
--   3. otherwise the map is built here; every piece first looks for ReplicatedStorage/Assets/<PieceName>
--      (ArenaShell, Mannequin, GrandMannequin, DressingRoom, ClothesRack, FoldingScreen, MakeupStation,
--      StageLight) and only builds a placeholder from primitives when the asset is missing.
--
-- Contract for hand-made pieces (see README): pivots sit on the floor, Mannequins have a "PromptPart" and the
-- six body attachments, DressingRooms have "Zone", "Barrier", "SpawnPoint" and "Sign" parts.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

export type MapRefs = {
	root: Model,
	center: Vector3,
	arenaRadius: number,
	mannequins: { Model },
	grandMannequin: Model?,
	bases: { Model },
	drops: Folder,
}

local MAP = GameConfig.Map

local PALETTE = {
	Floor = Color3.fromRGB(38, 20, 50),
	FloorBand = Color3.fromRGB(62, 30, 82),
	Wall = Color3.fromRGB(30, 16, 42),
	NeonPink = Color3.fromRGB(255, 70, 185),
	NeonPurple = Color3.fromRGB(150, 80, 255),
	WarmWhite = Color3.fromRGB(255, 236, 205),
	Podium = Color3.fromRGB(246, 236, 248),
	Catwalk = Color3.fromRGB(250, 246, 252),
	Mannequin = Color3.fromRGB(240, 236, 246),
	Pedestal = Color3.fromRGB(46, 24, 62),
	Gold = Color3.fromRGB(255, 200, 64),
	Metal = Color3.fromRGB(196, 196, 210),
	RoomWall = Color3.fromRGB(70, 38, 90),
	RoomFloor = Color3.fromRGB(110, 70, 128),
	Sign = Color3.fromRGB(24, 12, 34),
	Fabric = {
		Color3.fromRGB(255, 120, 190),
		Color3.fromRGB(140, 90, 255),
		Color3.fromRGB(255, 210, 90),
		Color3.fromRGB(90, 220, 255),
		Color3.fromRGB(250, 250, 250),
		Color3.fromRGB(255, 90, 120),
	},
}

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along Y
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis along Z

type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	reflectance: number?,
	canCollide: boolean?,
	parent: Instance,
}

local function part(props: PartProps): Part
	local instance = Instance.new("Part")
	instance.Name = props.name or "Part"
	instance.Anchored = true
	instance.Shape = props.shape or Enum.PartType.Block
	instance.Size = props.size
	instance.CFrame = props.cframe
	instance.Color = props.color
	instance.Material = props.material or Enum.Material.SmoothPlastic
	instance.Transparency = props.transparency or 0
	instance.Reflectance = props.reflectance or 0
	instance.CanCollide = if props.canCollide == nil then true else props.canCollide
	if not instance.CanCollide then
		instance.CanTouch = false
		instance.CanQuery = false
	end
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = props.parent
	return instance
end

-- Flat vertical cylinder from `bottomY` up by `height`.
local function disk(
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	bottomY: number,
	height: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part({
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, radius * 2, radius * 2),
		cframe = CFrame.new(center.X, bottomY + height / 2, center.Z) * UPRIGHT,
		color = color,
		material = material,
		parent = parent,
	})
end

local function attach(parent: BasePart, name: string, cframe: CFrame)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = cframe
	attachment.Parent = parent
end

local function polar(radius: number, angle: number, y: number): Vector3
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function spotlight(parent: Instance, position: Vector3, target: Vector3, color: Color3, range: number)
	local head = part({
		name = "LightHead",
		size = Vector3.new(1.6, 1.6, 2.4),
		cframe = CFrame.lookAt(position, target),
		color = Color3.fromRGB(30, 30, 36),
		material = Enum.Material.Metal,
		parent = parent,
	})
	part({
		name = "Lens",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.2, 1.3, 1.3),
		cframe = head.CFrame * CFrame.new(0, 0, -1.25) * FACING,
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 40
	light.Range = range
	light.Brightness = 4
	light.Color = color
	light.Shadows = false -- mobile-first: a dozen shadow-casting spotlights is too heavy for phones
	light.Parent = head
end

local function assetTemplate(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return if assets then assets:FindFirstChild(name) else nil
end

-- Clones Assets/<assetName> to `cframe` when it exists, otherwise builds a placeholder around the origin
-- (floor level, front = -Z) and moves it there. `scale` only applies to placeholders.
local function placeProp(
	assetName: string,
	instanceName: string,
	cframe: CFrame,
	parent: Instance,
	build: (Model) -> (),
	scale: number?
): Model
	local template = assetTemplate(assetName)
	local model: Model
	if template ~= nil and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		build(model)
		model.WorldPivot = CFrame.identity
		if scale ~= nil and scale ~= 1 then
			model:ScaleTo(scale)
		end
	end
	model.Name = instanceName
	model:PivotTo(cframe)
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------------------------------------------
-- Placeholder pieces
---------------------------------------------------------------------------------------------------------------

local function buildMannequin(model: Model, golden: boolean)
	local bodyColor = if golden then PALETTE.Gold else PALETTE.Mannequin
	local bodyMaterial = if golden then Enum.Material.Foil else Enum.Material.SmoothPlastic
	local function body(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame): Part
		return part({
			name = name,
			shape = shape,
			size = size,
			cframe = cframe,
			color = bodyColor,
			material = bodyMaterial,
			reflectance = 0.12,
			parent = model,
		})
	end

	disk(model, "Pedestal", Vector3.zero, 2.4, 0, 1.2, PALETTE.Pedestal)
	disk(model, "PedestalGlow", Vector3.zero, 2.55, 0.85, 0.2, PALETTE.NeonPink, Enum.Material.Neon).CanCollide = false
	body("Pole", Enum.PartType.Cylinder, Vector3.new(2.2, 0.35, 0.35), CFrame.new(0, 2.3, 0) * UPRIGHT)
	local waist = body("Waist", Enum.PartType.Block, Vector3.new(1.9, 0.5, 0.95), CFrame.new(0, 3.55, 0))
	local torso = body("Torso", Enum.PartType.Block, Vector3.new(2, 1.6, 1), CFrame.new(0, 4.6, 0))
	body("Neck", Enum.PartType.Cylinder, Vector3.new(0.3, 0.45, 0.45), CFrame.new(0, 5.55, 0) * UPRIGHT)
	local head = body("Head", Enum.PartType.Ball, Vector3.one * 1.2, CFrame.new(0, 6.3, 0))
	body(
		"LeftArm",
		Enum.PartType.Block,
		Vector3.new(0.5, 1.7, 0.5),
		CFrame.new(-1.3, 4.45, 0) * CFrame.Angles(0, 0, -0.12)
	)
	body(
		"RightArm",
		Enum.PartType.Block,
		Vector3.new(0.5, 1.7, 0.5),
		CFrame.new(1.3, 4.45, 0) * CFrame.Angles(0, 0, 0.12)
	)

	part({
		name = "PromptPart",
		size = Vector3.one,
		cframe = CFrame.new(0, 4.6, 0),
		color = bodyColor,
		transparency = 1,
		canCollide = false,
		parent = model,
	})

	-- Same names as on a character, so accessories line up exactly like on a player.
	attach(head, "HatAttachment", CFrame.new(0, 0.6, 0))
	attach(head, "FaceFrontAttachment", CFrame.new(0, 0, -0.6))
	attach(torso, "NeckAttachment", CFrame.new(0, 0.8, 0))
	attach(torso, "BodyFrontAttachment", CFrame.new(0, 0.1, -0.5))
	attach(torso, "BodyBackAttachment", CFrame.new(0, 0.1, 0.5))
	attach(waist, "WaistCenterAttachment", CFrame.identity)
end

-- Long axis along X, 10 studs.
local function buildClothesRack(model: Model)
	for _, x in { -4.8, 4.8 } do
		part({
			name = "Pole",
			size = Vector3.new(0.3, 6.2, 0.3),
			cframe = CFrame.new(x, 3.1, 0),
			color = PALETTE.Metal,
			material = Enum.Material.Metal,
			parent = model,
		})
		part({
			name = "Foot",
			size = Vector3.new(0.3, 0.3, 2.2),
			cframe = CFrame.new(x, 0.15, 0),
			color = PALETTE.Metal,
			material = Enum.Material.Metal,
			parent = model,
		})
	end
	part({
		name = "Bar",
		size = Vector3.new(10, 0.3, 0.3),
		cframe = CFrame.new(0, 6.1, 0),
		color = PALETTE.Metal,
		material = Enum.Material.Metal,
		parent = model,
	})
	for index = 0, 6 do
		part({
			name = "Garment",
			size = Vector3.new(0.5, 3.4, 2.2),
			cframe = CFrame.new(-3.9 + index * 1.3, 4.2, 0) * CFrame.Angles(0, (index % 3 - 1) * 0.12, 0),
			color = PALETTE.Fabric[index % #PALETTE.Fabric + 1],
			material = Enum.Material.Fabric,
			parent = model,
		})
	end
end

local function buildFoldingScreen(model: Model)
	local hinge = 1.7
	local angle = 0.45
	local panels = {
		CFrame.new(0, 4, 0),
		CFrame.new(-hinge - hinge * math.cos(angle), 4, hinge * math.sin(angle)) * CFrame.Angles(0, angle, 0),
		CFrame.new(hinge + hinge * math.cos(angle), 4, -hinge * math.sin(angle)) * CFrame.Angles(0, angle, 0),
	}
	for _, cframe in panels do
		part({
			name = "Panel",
			size = Vector3.new(3.4, 8, 0.3),
			cframe = cframe,
			color = Color3.fromRGB(255, 170, 215),
			material = Enum.Material.Fabric,
			parent = model,
		})
		part({
			name = "Trim",
			size = Vector3.new(3.4, 0.2, 0.36),
			cframe = cframe * CFrame.new(0, 4.1, 0),
			color = PALETTE.NeonPink,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
	end
end

-- Chair faces -Z toward a vanity with a lit mirror.
local function buildMakeupStation(model: Model)
	disk(model, "ChairBase", Vector3.zero, 1.2, 0, 0.3, PALETTE.Metal, Enum.Material.Metal)
	part({
		name = "ChairPole",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.6, 0.4, 0.4),
		cframe = CFrame.new(0, 1.1, 0) * UPRIGHT,
		color = PALETTE.Metal,
		material = Enum.Material.Metal,
		parent = model,
	})
	part({
		name = "Seat",
		size = Vector3.new(2.2, 0.6, 2.2),
		cframe = CFrame.new(0, 2.2, 0),
		color = Color3.fromRGB(255, 110, 170),
		material = Enum.Material.Fabric,
		parent = model,
	})
	part({
		name = "Backrest",
		size = Vector3.new(2.2, 2.6, 0.4),
		cframe = CFrame.new(0, 3.8, 1),
		color = Color3.fromRGB(255, 110, 170),
		material = Enum.Material.Fabric,
		parent = model,
	})

	part({
		name = "Vanity",
		size = Vector3.new(4, 0.3, 1.6),
		cframe = CFrame.new(0, 3.2, -2.8),
		color = PALETTE.Podium,
		reflectance = 0.2,
		parent = model,
	})
	for _, x in { -1.8, 1.8 } do
		part({
			name = "Leg",
			size = Vector3.new(0.3, 3.05, 0.3),
			cframe = CFrame.new(x, 1.55, -2.8),
			color = PALETTE.Metal,
			material = Enum.Material.Metal,
			parent = model,
		})
	end
	part({
		name = "Mirror",
		size = Vector3.new(3.4, 3.4, 0.2),
		cframe = CFrame.new(0, 5.2, -3.45),
		color = Color3.fromRGB(200, 220, 255),
		material = Enum.Material.Glass,
		reflectance = 0.6,
		parent = model,
	})
	for _, offset in
		{
			Vector3.new(-1.2, 7.05, 0),
			Vector3.new(0, 7.05, 0),
			Vector3.new(1.2, 7.05, 0),
			Vector3.new(-1.95, 5.8, 0),
			Vector3.new(1.95, 5.8, 0),
			Vector3.new(-1.95, 4.6, 0),
			Vector3.new(1.95, 4.6, 0),
		}
	do
		part({
			name = "Bulb",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 0.35,
			cframe = CFrame.new(offset.X, offset.Y, -3.35),
			color = PALETTE.WarmWhite,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
	end
end

-- Tripod light; the head points along -Z, tilted slightly down.
local function buildStageLight(model: Model)
	for index = 0, 2 do
		local angle = index / 3 * math.pi * 2
		part({
			name = "Leg",
			size = Vector3.new(0.25, 3, 0.25),
			cframe = CFrame.new(math.cos(angle) * 0.8, 1.4, math.sin(angle) * 0.8)
				* CFrame.Angles(math.sin(angle) * 0.4, 0, -math.cos(angle) * 0.4),
			color = Color3.fromRGB(30, 30, 36),
			material = Enum.Material.Metal,
			parent = model,
		})
	end
	part({
		name = "Pole",
		size = Vector3.new(0.4, 7.5, 0.4),
		cframe = CFrame.new(0, 5.6, 0),
		color = Color3.fromRGB(30, 30, 36),
		material = Enum.Material.Metal,
		parent = model,
	})
	spotlight(model, Vector3.new(0, 9.6, 0), Vector3.new(0, 7.6, -10), PALETTE.WarmWhite, 55)
end

-- Origin = doorway at floor level, -Z points into the room.
local function buildDressingRoom(model: Model)
	local width, depth, height = MAP.BaseWidth, MAP.BaseDepth, MAP.BaseHeight
	local doorWidth, doorHeight = MAP.DoorWidth, MAP.DoorHeight
	local thickness = 1
	local sideWidth = (width - doorWidth) / 2

	local function wall(name: string, size: Vector3, cframe: CFrame)
		part({ name = name, size = size, cframe = cframe, color = PALETTE.RoomWall, parent = model })
	end

	part({
		name = "Floor",
		size = Vector3.new(width, 1, depth),
		cframe = CFrame.new(0, -0.5, -depth / 2),
		color = PALETTE.RoomFloor,
		material = Enum.Material.Wood,
		reflectance = 0.05,
		parent = model,
	})
	wall("Roof", Vector3.new(width, 1, depth), CFrame.new(0, height + 0.5, -depth / 2))
	wall("BackWall", Vector3.new(width, height, thickness), CFrame.new(0, height / 2, -depth + thickness / 2))
	wall(
		"LeftWall",
		Vector3.new(thickness, height, depth),
		CFrame.new(-width / 2 + thickness / 2, height / 2, -depth / 2)
	)
	wall(
		"RightWall",
		Vector3.new(thickness, height, depth),
		CFrame.new(width / 2 - thickness / 2, height / 2, -depth / 2)
	)
	wall(
		"FrontLeft",
		Vector3.new(sideWidth, height, thickness),
		CFrame.new(-(doorWidth + sideWidth) / 2, height / 2, -thickness / 2)
	)
	wall(
		"FrontRight",
		Vector3.new(sideWidth, height, thickness),
		CFrame.new((doorWidth + sideWidth) / 2, height / 2, -thickness / 2)
	)
	wall(
		"Lintel",
		Vector3.new(doorWidth, height - doorHeight, thickness),
		CFrame.new(0, (doorHeight + height) / 2, -thickness / 2)
	)

	-- Neon door frame on the arena side of the outer wall.
	local frameZ = MAP.WallThickness + 0.15
	for _, x in { -doorWidth / 2 - 0.15, doorWidth / 2 + 0.15 } do
		part({
			name = "DoorFrame",
			size = Vector3.new(0.3, doorHeight, 0.3),
			cframe = CFrame.new(x, doorHeight / 2, frameZ),
			color = PALETTE.NeonPink,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
	end
	part({
		name = "DoorFrame",
		size = Vector3.new(doorWidth + 0.6, 0.3, 0.3),
		cframe = CFrame.new(0, doorHeight + 0.15, frameZ),
		color = PALETTE.NeonPink,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = model,
	})

	-- Only the owner passes (collision groups); the shimmer shows everyone else it is closed.
	local barrier = part({
		name = "Barrier",
		size = Vector3.new(doorWidth, doorHeight, 1),
		cframe = CFrame.new(0, doorHeight / 2, -0.5),
		color = PALETTE.NeonPink,
		material = Enum.Material.ForceField,
		transparency = 0.3,
		parent = model,
	})
	barrier.CanQuery = false
	barrier.CanTouch = false

	part({
		name = "Zone",
		size = Vector3.new(width - thickness * 2, height, depth - thickness * 2),
		cframe = CFrame.new(0, height / 2, -depth / 2),
		color = PALETTE.NeonPink,
		transparency = 1,
		canCollide = false,
		parent = model,
	})

	-- Faces the door.
	part({
		name = "SpawnPoint",
		size = Vector3.new(2, 1, 2),
		cframe = CFrame.new(0, 0.5, -depth + 5) * CFrame.Angles(0, math.pi, 0),
		color = PALETTE.NeonPink,
		transparency = 1,
		canCollide = false,
		parent = model,
	})

	-- Sign above the door, front face toward the arena.
	part({
		name = "Sign",
		size = Vector3.new(12, 3.2, 0.4),
		cframe = CFrame.new(0, doorHeight + 3.4, MAP.WallThickness + 0.3) * CFrame.Angles(0, math.pi, 0),
		color = PALETTE.Sign,
		parent = model,
	})

	-- Mirror (equipment UI in Phase 3) on the back wall.
	part({
		name = "Mirror",
		size = Vector3.new(6, 8, 0.3),
		cframe = CFrame.new(0, 5, -depth + thickness + 0.2),
		color = Color3.fromRGB(205, 220, 255),
		material = Enum.Material.Glass,
		reflectance = 0.5,
		parent = model,
	})
	part({
		name = "MirrorFrame",
		size = Vector3.new(6.6, 8.6, 0.2),
		cframe = CFrame.new(0, 5, -depth + thickness + 0.05),
		color = PALETTE.NeonPink,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = model,
	})

	-- Wardrobe rack (storage UI in Phase 3) along the left wall.
	local wardrobe = Instance.new("Model")
	wardrobe.Name = "Wardrobe"
	buildClothesRack(wardrobe)
	wardrobe.WorldPivot = CFrame.identity
	wardrobe:PivotTo(CFrame.new(-width / 2 + 2.5, 0, -depth / 2 - 1) * CFrame.Angles(0, math.pi / 2, 0))
	wardrobe.Parent = model

	-- Appraiser's table (selling in Phase 3) along the right wall.
	local appraiser = Instance.new("Model")
	appraiser.Name = "Appraiser"
	local tableX = width / 2 - 3
	part({
		name = "Top",
		size = Vector3.new(3.5, 0.4, 6),
		cframe = CFrame.new(tableX, 3, -depth / 2 - 1),
		color = PALETTE.Gold,
		material = Enum.Material.Foil,
		parent = appraiser,
	})
	part({
		name = "Base",
		size = Vector3.new(3, 2.8, 5.4),
		cframe = CFrame.new(tableX, 1.4, -depth / 2 - 1),
		color = PALETTE.Sign,
		parent = appraiser,
	})
	part({
		name = "Register",
		size = Vector3.new(1.5, 1, 1.2),
		cframe = CFrame.new(tableX, 3.7, -depth / 2 - 2.5),
		color = Color3.fromRGB(40, 40, 46),
		parent = appraiser,
	})
	part({
		name = "Gem",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 0.7,
		cframe = CFrame.new(tableX, 3.55, -depth / 2 + 0.5),
		color = PALETTE.Gold,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = appraiser,
	})
	appraiser.Parent = model

	local lamp = part({
		name = "Lamp",
		size = Vector3.new(3, 0.3, 3),
		cframe = CFrame.new(0, height - 0.15, -depth / 2),
		color = PALETTE.WarmWhite,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 210, 235)
	light.Parent = lamp
end

local function buildShell(parent: Model)
	local radius = MAP.ArenaRadius
	local thickness = MAP.WallThickness
	local wallHeight = MAP.WallHeight

	local floor = disk(parent, "Floor", Vector3.zero, radius + thickness + 2, -2, 2, PALETTE.Floor)
	floor.Reflectance = 0.25
	-- A lighter band under the mannequin ring: a wide disk, then a slightly taller inner disk in the base color.
	local outerBand = disk(parent, "FloorBand", Vector3.zero, MAP.MannequinRingRadius + 7, 0, 0.04, PALETTE.FloorBand)
	local innerBand = disk(parent, "FloorBand", Vector3.zero, MAP.MannequinRingRadius - 7, 0, 0.08, PALETTE.Floor)
	for _, band in { outerBand, innerBand } do
		band.CanCollide = false
		band.CanQuery = false
		band.Reflectance = 0.25
	end

	-- Outer wall: segments centered on multiples of (360 / WallSegments) degrees; door segments are left open.
	local segments = MAP.WallSegments
	local doorEvery = segments // MAP.BaseCount
	local doorOffset = doorEvery // 2
	local chord = 2 * (radius + thickness / 2) * math.tan(math.pi / segments) + 0.1
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Wall"
	wallFolder.Parent = parent
	for index = 0, segments - 1 do
		local angle = index / segments * math.pi * 2
		local isDoor = index % doorEvery == doorOffset
		local bottom = if isDoor then MAP.DoorHeight else 0
		local position = polar(radius + thickness / 2, angle, (bottom + wallHeight) / 2)
		local facing = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		part({
			name = "Segment",
			size = Vector3.new(chord, wallHeight - bottom, thickness),
			cframe = facing,
			color = PALETTE.Wall,
			parent = wallFolder,
		})

		local inner = polar(radius - 0.15, angle, 0)
		local inward = CFrame.lookAt(inner, Vector3.zero)
		part({
			name = "TopStrip",
			size = Vector3.new(chord, 0.4, 0.3),
			cframe = inward + Vector3.new(0, wallHeight - 1, 0),
			color = PALETTE.NeonPink,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = wallFolder,
		})
		if not isDoor then
			part({
				name = "BottomStrip",
				size = Vector3.new(chord, 0.3, 0.3),
				cframe = inward + Vector3.new(0, 0.6, 0),
				color = PALETTE.NeonPurple,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = wallFolder,
			})
		end
	end

	-- Podium: stacked tiers act as a gentle ramp from every side.
	local tiers = MAP.PodiumTiers
	for tier = 1, tiers do
		local tierRadius = MAP.PodiumRadius + (tiers - tier) * 3
		local tierHeight = MAP.PodiumHeight * tier / tiers
		local slab = disk(parent, "PodiumTier", Vector3.zero, tierRadius, 0, tierHeight, PALETTE.Podium)
		slab.Reflectance = 0.2
		local glow = disk(
			parent,
			"PodiumGlow",
			Vector3.zero,
			tierRadius + 0.35,
			tierHeight - 0.25,
			0.15,
			PALETTE.NeonPink,
			Enum.Material.Neon
		)
		glow.CanCollide = false
	end

	-- Catwalks from the podium to the outer wall.
	local catwalkLength = radius - 2 - MAP.PodiumRadius
	local catwalkMid = MAP.PodiumRadius + catwalkLength / 2
	for index = 0, MAP.CatwalkCount - 1 do
		local angle = index / MAP.CatwalkCount * math.pi * 2
		local along = CFrame.new(polar(catwalkMid, angle, 0)) * CFrame.Angles(0, -angle, 0)
		part({
			name = "Catwalk",
			size = Vector3.new(catwalkLength, MAP.CatwalkHeight, MAP.CatwalkWidth),
			cframe = along * CFrame.new(0, MAP.CatwalkHeight / 2, 0),
			color = PALETTE.Catwalk,
			reflectance = 0.3,
			parent = parent,
		})
		for _, side in { -1, 1 } do
			part({
				name = "CatwalkEdge",
				size = Vector3.new(catwalkLength, 0.2, 0.3),
				cframe = along * CFrame.new(0, MAP.CatwalkHeight, side * MAP.CatwalkWidth / 2),
				color = PALETTE.NeonPink,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = parent,
			})
		end
	end

	-- Light towers around the podium.
	for index = 0, 3 do
		local angle = (index + 0.5) / 4 * math.pi * 2
		local base = polar(MAP.PodiumRadius + 10, angle, 0)
		part({
			name = "Tower",
			size = Vector3.new(0.6, 16, 0.6),
			cframe = CFrame.new(base + Vector3.new(0, 8, 0)),
			color = Color3.fromRGB(30, 30, 36),
			material = Enum.Material.Metal,
			parent = parent,
		})
		local color = if index % 2 == 0 then PALETTE.NeonPink else PALETTE.WarmWhite
		spotlight(parent, base + Vector3.new(0, 16.5, 0), Vector3.new(0, MAP.PodiumHeight + 3, 0), color, 45)
		spotlight(
			parent,
			base + Vector3.new(0, 15, 0),
			polar(MAP.MannequinRingRadius, angle, 3),
			PALETTE.NeonPurple,
			45
		)
	end
end

local function setupLighting()
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end

	local bloom = ensure("BloomEffect", "RunwayBloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4

	local grading = ensure("ColorCorrectionEffect", "RunwayGrading") :: ColorCorrectionEffect
	grading.Saturation = 0.12
	grading.Contrast = 0.08
	grading.TintColor = Color3.fromRGB(255, 242, 255)
end

---------------------------------------------------------------------------------------------------------------
-- Assembly
---------------------------------------------------------------------------------------------------------------

local function indexOf(instance: Instance): number
	local fromAttribute = instance:GetAttribute("Index")
	if typeof(fromAttribute) == "number" then
		return fromAttribute
	end
	return tonumber(string.match(instance.Name, "%d+$")) or 0
end

local function sortedModels(folder: Instance?): { Model }
	local models: { Model } = {}
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(models, child)
			end
		end
	end
	table.sort(models, function(a, b)
		return indexOf(a) < indexOf(b)
	end)
	return models
end

local function collect(root: Model): MapRefs
	local mannequins = sortedModels(root:FindFirstChild("Mannequins"))
	local bases = sortedModels(root:FindFirstChild("Bases"))
	assert(#mannequins > 0, "Arena has no Mannequins folder with mannequin models")
	assert(#bases > 0, "Arena has no Bases folder with dressing room models")
	assert(#bases <= MAP.BaseCount, `Arena has {#bases} dressing rooms, GameConfig.Map.BaseCount is {MAP.BaseCount}`)

	local drops = root:FindFirstChild("Drops")
	if drops == nil or not drops:IsA("Folder") then
		local folder = Instance.new("Folder")
		folder.Name = "Drops"
		folder.Parent = root
		drops = folder
	end
	assert(drops ~= nil and drops:IsA("Folder"), "Arena.Drops must be a Folder")

	local grand = root:FindFirstChild("GrandMannequin")
	local pivot = root:GetPivot()
	return {
		root = root,
		center = pivot.Position,
		arenaRadius = MAP.ArenaRadius,
		mannequins = mannequins,
		grandMannequin = if grand ~= nil and grand:IsA("Model") then grand else nil,
		bases = bases,
		drops = drops,
	}
end

local function buildArena(): Model
	local root = Instance.new("Model")
	root.Name = "Arena"

	local shellTemplate = assetTemplate("ArenaShell")
	if shellTemplate ~= nil then
		shellTemplate:Clone().Parent = root
	else
		local shell = Instance.new("Model")
		shell.Name = "Shell"
		buildShell(shell)
		shell.Parent = root
	end

	-- Obstacles: the same layout in every quarter of the arena, clear of catwalks, doors and mannequins.
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = root
	local quarterLayout = {
		{ asset = "ClothesRack", radius = 60, degrees = 30, build = buildClothesRack, outward = false },
		{ asset = "ClothesRack", radius = 76, degrees = 80, build = buildClothesRack, outward = false },
		{ asset = "FoldingScreen", radius = 72, degrees = 48, build = buildFoldingScreen, outward = false },
		{ asset = "FoldingScreen", radius = 58, degrees = 62, build = buildFoldingScreen, outward = false },
		{ asset = "MakeupStation", radius = 66, degrees = 12, build = buildMakeupStation, outward = true },
		{ asset = "StageLight", radius = 82, degrees = 45, build = buildStageLight, outward = false },
	}
	for quarter = 0, 3 do
		for _, entry in quarterLayout do
			local angle = math.rad(quarter * 90 + entry.degrees)
			local position = polar(entry.radius, angle, 0)
			-- Front (-Z) toward the podium, so long props (racks, screens) run along the circle.
			local inward = CFrame.lookAt(position, Vector3.zero)
			local cframe = if entry.outward then inward * CFrame.Angles(0, math.pi, 0) else inward
			placeProp(entry.asset, entry.asset, cframe, props, entry.build)
		end
	end

	-- Mannequin ring, offset by half a step so no mannequin stands on a catwalk. They face outward.
	local mannequins = Instance.new("Folder")
	mannequins.Name = "Mannequins"
	mannequins.Parent = root
	for index = 1, MAP.MannequinCount do
		local angle = (index - 0.5) / MAP.MannequinCount * math.pi * 2
		local position = polar(MAP.MannequinRingRadius, angle, 0)
		local outward = CFrame.lookAt(position, position * 2)
		local model = placeProp("Mannequin", `Mannequin{index}`, outward, mannequins, function(placeholder)
			buildMannequin(placeholder, false)
		end)
		model:SetAttribute("Index", index)
	end

	-- Grand Mannequin on top of the podium (its drops arrive in Phase 4).
	placeProp("GrandMannequin", "GrandMannequin", CFrame.new(0, MAP.PodiumHeight, 0), root, function(placeholder)
		buildMannequin(placeholder, true)
	end, MAP.GrandMannequinScale)

	-- Dressing rooms behind the door gaps in the outer wall.
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = root
	local doorEvery = MAP.WallSegments // MAP.BaseCount
	for index = 1, MAP.BaseCount do
		local segment = (index - 1) * doorEvery + doorEvery // 2
		local angle = segment / MAP.WallSegments * math.pi * 2
		local doorway = polar(MAP.ArenaRadius + MAP.WallThickness, angle, 0)
		local intoRoom = CFrame.lookAt(doorway, doorway * 2)
		local model = placeProp("DressingRoom", `Base{index}`, intoRoom, bases, buildDressingRoom)
		model:SetAttribute("Index", index)
	end

	local drops = Instance.new("Folder")
	drops.Name = "Drops"
	drops.Parent = root

	root.WorldPivot = CFrame.identity
	return root
end

local MapBuilder = {}

function MapBuilder.Build(): MapRefs
	setupLighting()

	local existing = Workspace:FindFirstChild("Arena")
	if existing ~= nil and existing:IsA("Model") then
		return collect(existing)
	end

	local template = assetTemplate("Arena")
	local root: Model
	if template ~= nil and template:IsA("Model") then
		root = template:Clone()
	else
		root = buildArena()
	end
	root.Name = "Arena"
	root.Parent = Workspace
	return collect(root)
end

return MapBuilder
