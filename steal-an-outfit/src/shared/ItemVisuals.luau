--!strict
-- Builds the 3D look of an item.
-- 1. If ReplicatedStorage/Assets/Items/<assetName or id> is an Accessory with a Handle, it is cloned.
-- 2. Otherwise a placeholder is built from primitives, shaped by the item's `style` and colored by rarity.
-- Mutations change materials (Gold, Diamond) or tag parts for client-side color cycling (Rainbow).
-- Rarities with `glow` get a Highlight, sparkles and a light, so the wearer is visible from afar.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(script.Parent.Format)
local ItemUtil = require(script.Parent.ItemUtil)
local Types = require(script.Parent.Types)

local ItemVisuals = {}

-- Parts with this tag get their color cycled through the rainbow by the client (EffectsController).
ItemVisuals.RAINBOW_TAG = "RainbowPart"

type Role = "Main" | "Accent" | "Neon" | "Dark" | "Hidden"

type PartSpec = {
	shape: Enum.PartType,
	size: Vector3,
	-- Relative to the body attachment: +Y is up, -Z points out of the front of the body, +X is the wearer's right.
	cframe: CFrame,
	role: Role,
}

local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder

-- Cylinders run along X by default.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- axis along Y
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- axis along Z

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(38, 36, 44)

local GOLD_MAIN = Color3.fromRGB(255, 195, 50)
local GOLD_ACCENT = Color3.fromRGB(255, 232, 150)
local DIAMOND_MAIN = Color3.fromRGB(175, 230, 255)
local DIAMOND_ACCENT = Color3.fromRGB(235, 250, 255)

local function spec(shape: Enum.PartType, size: Vector3, cframe: CFrame, role: Role): PartSpec
	return { shape = shape, size = size, cframe = cframe, role = role }
end

local function mainOrAccent(index: number): Role
	return if index % 2 == 0 then "Main" else "Accent"
end

-- Placeholder shapes. The first spec of every list becomes the Handle.
local STYLES: { [Types.ItemStyle]: () -> { PartSpec } } = {
	Crown = function()
		local parts = { spec(CYLINDER, Vector3.new(0.45, 1.35, 1.35), CFrame.new(0, 0.12, 0) * UPRIGHT, "Main") }
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			local position = CFrame.new(math.sin(angle) * 0.58, 0.45, math.cos(angle) * 0.58)
			table.insert(
				parts,
				spec(BLOCK, Vector3.one * 0.3, position * CFrame.Angles(0, angle, math.pi / 4), "Accent")
			)
		end
		table.insert(parts, spec(BALL, Vector3.one * 0.32, CFrame.new(0, 0.12, -0.68), "Neon"))
		return parts
	end,

	Hat = function()
		return {
			spec(CYLINDER, Vector3.new(0.65, 1.3, 1.3), CFrame.new(0, 0.3, 0) * UPRIGHT, "Main"),
			spec(CYLINDER, Vector3.new(0.1, 2, 2), CFrame.new(0, 0.02, 0) * UPRIGHT, "Main"),
			spec(CYLINDER, Vector3.new(0.18, 1.34, 1.34), CFrame.new(0, 0.12, 0) * UPRIGHT, "Accent"),
			spec(BALL, Vector3.one * 0.25, CFrame.new(0, 0.66, 0), "Neon"),
		}
	end,

	Halo = function()
		local parts = { spec(BLOCK, Vector3.one * 0.2, CFrame.new(0, 0.9, 0), "Hidden") }
		for i = 0, 13 do
			local angle = i / 14 * math.pi * 2
			table.insert(
				parts,
				spec(BALL, Vector3.one * 0.22, CFrame.new(math.sin(angle) * 0.62, 0.9, math.cos(angle) * 0.62), "Neon")
			)
		end
		return parts
	end,

	Glasses = function()
		return {
			spec(BLOCK, Vector3.new(0.25, 0.08, 0.08), CFrame.new(0, 0.1, -0.08), "Dark"),
			spec(CYLINDER, Vector3.new(0.08, 0.42, 0.42), CFrame.new(-0.27, 0.1, -0.08) * FACING, "Main"),
			spec(CYLINDER, Vector3.new(0.08, 0.42, 0.42), CFrame.new(0.27, 0.1, -0.08) * FACING, "Main"),
			spec(BLOCK, Vector3.new(0.06, 0.06, 0.6), CFrame.new(-0.5, 0.1, 0.22), "Dark"),
			spec(BLOCK, Vector3.new(0.06, 0.06, 0.6), CFrame.new(0.5, 0.1, 0.22), "Dark"),
		}
	end,

	Mask = function()
		return {
			spec(BLOCK, Vector3.new(0.95, 0.38, 0.1), CFrame.new(0, 0.1, -0.05), "Main"),
			spec(CYLINDER, Vector3.new(0.04, 0.2, 0.2), CFrame.new(-0.22, 0.12, -0.11) * FACING, "Neon"),
			spec(CYLINDER, Vector3.new(0.04, 0.2, 0.2), CFrame.new(0.22, 0.12, -0.11) * FACING, "Neon"),
			spec(
				BLOCK,
				Vector3.new(0.12, 0.6, 0.08),
				CFrame.new(0.5, 0.45, -0.05) * CFrame.Angles(0, 0, -0.4),
				"Accent"
			),
			spec(
				BLOCK,
				Vector3.new(0.12, 0.45, 0.08),
				CFrame.new(0.38, 0.5, -0.06) * CFrame.Angles(0, 0, -0.15),
				"Accent"
			),
		}
	end,

	Beads = function()
		local parts = { spec(BLOCK, Vector3.one * 0.2, CFrame.new(0, 0, 0), "Hidden") }
		for i = 0, 15 do
			local angle = i / 16 * math.pi * 2
			local front = math.max(0, -math.cos(angle)) -- 1 at the front of the neck, 0 at the sides and back
			local position = CFrame.new(math.sin(angle) * 0.68, 0.02 - 0.32 * front * front, math.cos(angle) * 0.56)
			table.insert(parts, spec(BALL, Vector3.one * 0.22, position, mainOrAccent(i)))
		end
		table.insert(parts, spec(BALL, Vector3.one * 0.32, CFrame.new(0, -0.5, -0.6), "Neon"))
		return parts
	end,

	Scarf = function()
		return {
			spec(BLOCK, Vector3.new(1.25, 0.38, 0.28), CFrame.new(0, 0.05, -0.5), "Main"),
			spec(BLOCK, Vector3.new(1.25, 0.38, 0.28), CFrame.new(0, 0.05, 0.5), "Main"),
			spec(BLOCK, Vector3.new(0.28, 0.38, 1.28), CFrame.new(-0.62, 0.05, 0), "Main"),
			spec(BLOCK, Vector3.new(0.28, 0.38, 1.28), CFrame.new(0.62, 0.05, 0), "Main"),
			spec(
				BLOCK,
				Vector3.new(0.32, 1, 0.12),
				CFrame.new(0.3, -0.55, -0.66) * CFrame.Angles(0.1, 0, 0.08),
				"Accent"
			),
			spec(BLOCK, Vector3.new(0.32, 0.8, 0.12), CFrame.new(0, -0.45, -0.68) * CFrame.Angles(0.1, 0, 0), "Accent"),
		}
	end,

	Medal = function()
		return {
			spec(CYLINDER, Vector3.new(0.1, 0.55, 0.55), CFrame.new(0, -0.05, -0.08) * FACING, "Main"),
			spec(BLOCK, Vector3.new(0.32, 0.5, 0.06), CFrame.new(0, 0.32, -0.05), "Accent"),
			spec(BALL, Vector3.one * 0.2, CFrame.new(0, -0.05, -0.15), "Neon"),
		}
	end,

	Bow = function()
		return {
			spec(BLOCK, Vector3.new(0.2, 0.2, 0.16), CFrame.new(0, 0.55, -0.08), "Accent"),
			spec(
				BLOCK,
				Vector3.new(0.42, 0.32, 0.1),
				CFrame.new(-0.29, 0.55, -0.08) * CFrame.Angles(0, 0, 0.25),
				"Main"
			),
			spec(
				BLOCK,
				Vector3.new(0.42, 0.32, 0.1),
				CFrame.new(0.29, 0.55, -0.08) * CFrame.Angles(0, 0, -0.25),
				"Main"
			),
		}
	end,

	Gem = function()
		return {
			spec(CYLINDER, Vector3.new(0.08, 0.62, 0.62), CFrame.new(-0.45, 0.3, -0.04) * FACING, "Accent"),
			spec(
				BLOCK,
				Vector3.new(0.36, 0.36, 0.14),
				CFrame.new(-0.45, 0.3, -0.1) * CFrame.Angles(0, 0, math.pi / 4),
				"Neon"
			),
			spec(BALL, Vector3.one * 0.14, CFrame.new(-0.45, -0.02, -0.08), "Neon"),
		}
	end,

	Wings = function()
		return {
			spec(BLOCK, Vector3.new(0.35, 0.45, 0.22), CFrame.new(0, 0.15, 0.12), "Accent"),
			spec(
				BLOCK,
				Vector3.new(1.7, 0.95, 0.08),
				CFrame.new(-1.05, 0.45, 0.32) * CFrame.Angles(0, 0.3, -0.35),
				"Main"
			),
			spec(
				BLOCK,
				Vector3.new(1.7, 0.95, 0.08),
				CFrame.new(1.05, 0.45, 0.32) * CFrame.Angles(0, -0.3, 0.35),
				"Main"
			),
			spec(
				BLOCK,
				Vector3.new(1.2, 0.65, 0.08),
				CFrame.new(-0.8, -0.3, 0.3) * CFrame.Angles(0, 0.3, 0.3),
				"Accent"
			),
			spec(
				BLOCK,
				Vector3.new(1.2, 0.65, 0.08),
				CFrame.new(0.8, -0.3, 0.3) * CFrame.Angles(0, -0.3, -0.3),
				"Accent"
			),
		}
	end,

	Cape = function()
		return {
			spec(BLOCK, Vector3.new(2.05, 0.25, 0.42), CFrame.new(0, 0.72, 0.12), "Accent"),
			spec(BLOCK, Vector3.new(1.95, 2.5, 0.08), CFrame.new(0, -0.55, 0.22) * CFrame.Angles(-0.1, 0, 0), "Main"),
		}
	end,

	Bag = function()
		return {
			spec(BLOCK, Vector3.new(1.15, 1.3, 0.55), CFrame.new(0, -0.05, 0.3), "Main"),
			spec(BLOCK, Vector3.new(1.17, 0.35, 0.58), CFrame.new(0, 0.5, 0.3), "Accent"),
			spec(BLOCK, Vector3.new(0.85, 0.5, 0.14), CFrame.new(0, -0.32, 0.62), "Accent"),
			spec(BLOCK, Vector3.new(0.18, 0.12, 0.6), CFrame.new(-0.4, 0.75, 0), "Dark"),
			spec(BLOCK, Vector3.new(0.18, 0.12, 0.6), CFrame.new(0.4, 0.75, 0), "Dark"),
		}
	end,

	Belt = function()
		return {
			spec(BLOCK, Vector3.new(2.12, 0.32, 0.1), CFrame.new(0, 0, -0.56), "Main"),
			spec(BLOCK, Vector3.new(2.12, 0.32, 0.1), CFrame.new(0, 0, 0.56), "Main"),
			spec(BLOCK, Vector3.new(0.1, 0.32, 1.22), CFrame.new(-1.06, 0, 0), "Main"),
			spec(BLOCK, Vector3.new(0.1, 0.32, 1.22), CFrame.new(1.06, 0, 0), "Main"),
			spec(BLOCK, Vector3.new(0.5, 0.42, 0.08), CFrame.new(0, 0, -0.63), "Neon"),
		}
	end,

	Pouch = function()
		return {
			spec(BLOCK, Vector3.new(0.95, 0.55, 0.38), CFrame.new(0, -0.05, -0.75), "Main"),
			spec(BLOCK, Vector3.new(2.12, 0.16, 0.08), CFrame.new(0, 0.05, -0.56), "Dark"),
			spec(BLOCK, Vector3.new(2.12, 0.16, 0.08), CFrame.new(0, 0.05, 0.56), "Dark"),
			spec(BLOCK, Vector3.new(0.08, 0.16, 1.2), CFrame.new(-1.06, 0.05, 0), "Dark"),
			spec(BLOCK, Vector3.new(0.08, 0.16, 1.2), CFrame.new(1.06, 0.05, 0), "Dark"),
			spec(BLOCK, Vector3.new(0.85, 0.06, 0.04), CFrame.new(0, 0.12, -0.95), "Accent"),
			spec(BALL, Vector3.one * 0.16, CFrame.new(0, -0.08, -0.95), "Neon"),
		}
	end,
}

-- All rainbow parts of one item share a phase (overlapping faces would flicker otherwise);
-- different items get different phases so they do not pulse in sync.
local function rainbowPhase(item: Types.ItemInstance): number
	return (tonumber(string.sub(item.uid, -1), 16) or 0) / 16 -- last hex digit of the GUID
end

local function tagRainbow(part: BasePart, phase: number)
	CollectionService:AddTag(part, ItemVisuals.RAINBOW_TAG)
	part:SetAttribute("RainbowOffset", phase)
end

-- Gold / Diamond / Rainbow look for a part that would otherwise use `color`.
local function applyMutation(part: BasePart, mutation: Types.MutationId, accent: boolean, phase: number)
	if mutation == "Gold" then
		part.Color = if accent then GOLD_ACCENT else GOLD_MAIN
		part.Material = Enum.Material.Foil
		part.Reflectance = 0.1
	elseif mutation == "Diamond" then
		part.Color = if accent then DIAMOND_ACCENT else DIAMOND_MAIN
		part.Material = Enum.Material.Glass
		part.Transparency = 0.1
		part.Reflectance = 0.25
	elseif mutation == "Rainbow" then
		tagRainbow(part, phase)
	end
end

local function applyLook(part: BasePart, role: Role, item: Types.ItemInstance, rarity: Types.RarityDef)
	local phase = rainbowPhase(item)
	part.Material = Enum.Material.SmoothPlastic
	if role == "Hidden" then
		part.Transparency = 1
	elseif role == "Main" then
		part.Color = rarity.color
		part.Reflectance = 0.08
		applyMutation(part, item.mutation, false, phase)
	elseif role == "Accent" then
		part.Color = rarity.color:Lerp(WHITE, 0.55)
		applyMutation(part, item.mutation, true, phase)
	elseif role == "Neon" then
		part.Color = rarity.uiColor
		part.Material = Enum.Material.Neon
		if rarity.id == "Secret" or item.mutation == "Rainbow" then
			tagRainbow(part, phase)
		end
	else
		part.Color = DARK
	end
end

local function newPart(partSpec: PartSpec): Part
	local part = Instance.new("Part")
	part.Shape = partSpec.shape
	part.Size = partSpec.size
	part.CFrame = partSpec.cframe
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function buildPlaceholder(accessory: Accessory, item: Types.ItemInstance, def: Types.ItemDef): BasePart
	local rarity = ItemUtil.getRarity(item)
	local specs = STYLES[def.style]()
	local handleSpec = specs[1]
	local toHandleSpace = handleSpec.cframe:Inverse()

	local handle = newPart(handleSpec)
	handle.Name = "Handle"
	applyLook(handle, handleSpec.role, item, rarity)

	-- The attachment sits at the origin of the spec space, i.e. exactly on the body attachment.
	local attachment = Instance.new("Attachment")
	attachment.Name = ItemUtil.getSlotDef(def.slot).attachment
	attachment.CFrame = toHandleSpace
	attachment.Parent = handle
	handle.Parent = accessory

	for index = 2, #specs do
		local partSpec = specs[index]
		local part = newPart(partSpec)
		part.Name = partSpec.role
		applyLook(part, partSpec.role, item, rarity)
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = toHandleSpace * partSpec.cframe
		weld.Parent = part
		part.Parent = accessory
	end
	return handle
end

local function findAsset(def: Types.ItemDef): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local items = if assets then assets:FindFirstChild("Items") else nil
	return if items then items:FindFirstChild(def.assetName or def.id) else nil
end

local function createAccessory(item: Types.ItemInstance): (Accessory, BasePart)
	local def = ItemUtil.getDef(item.itemId)
	assert(def ~= nil, `Unknown item id "{item.itemId}"`)

	local asset = findAsset(def)
	if asset ~= nil then
		local handle = asset:FindFirstChild("Handle")
		if asset:IsA("Accessory") and handle ~= nil and handle:IsA("BasePart") then
			local accessory = asset:Clone()
			local clonedHandle = accessory:FindFirstChild("Handle") :: BasePart
			local phase = rainbowPhase(item)
			for _, descendant in accessory:GetDescendants() do
				if descendant:IsA("BasePart") then
					-- Same physics as the placeholders: carried by the Handle, never blocking or colliding.
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Massless = true
					-- Parts marked with the KeepLook attribute (e.g. textured meshes) keep their original look.
					if descendant:GetAttribute("KeepLook") ~= true then
						applyMutation(descendant, item.mutation, false, phase)
					end
				end
			end
			return accessory, clonedHandle
		end
		warn(`Assets/Items/{asset.Name} must be an Accessory with a Handle part; using a placeholder instead`)
	end

	local accessory = Instance.new("Accessory")
	return accessory, buildPlaceholder(accessory, item, def)
end

local function addGlow(container: Instance, handle: BasePart, rarity: Types.RarityDef)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = rarity.uiColor
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = rarity.uiColor
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = container

	local light = Instance.new("PointLight")
	light.Color = rarity.uiColor
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = handle

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(rarity.uiColor)
	sparkles.LightEmission = 1
	sparkles.Rate = 5
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Parent = handle
end

local function finish(container: Instance, handle: BasePart, item: Types.ItemInstance)
	container.Name = ItemUtil.getDisplayName(item)
	container:SetAttribute("ItemUid", item.uid)
	container:SetAttribute("ItemId", item.itemId)
	container:SetAttribute("Mutation", item.mutation)
	local rarity = ItemUtil.getRarity(item)
	if rarity.glow then
		addGlow(container, handle, rarity)
	end
end

-- Accessory ready for Humanoid:AddAccessory.
function ItemVisuals.buildAccessory(item: Types.ItemInstance): Accessory
	local accessory, handle = createAccessory(item)
	finish(accessory, handle, item)
	return accessory
end

-- Same parts as a Model (Handle is the PrimaryPart). Used for mannequin displays and floor drops.
function ItemVisuals.buildModel(item: Types.ItemInstance): Model
	local accessory, handle = createAccessory(item)
	local model = Instance.new("Model")
	for _, child in accessory:GetChildren() do
		child.Parent = model
	end
	accessory:Destroy()
	model.PrimaryPart = handle
	finish(model, handle, item)
	return model
end

-- Anchors a model from buildModel so that its slot attachment lines up with `target`.
function ItemVisuals.placeOnAttachment(model: Model, item: Types.ItemInstance, target: Attachment)
	local handle = model.PrimaryPart
	assert(handle ~= nil, "Item model has no PrimaryPart")
	local def = ItemUtil.getDef(item.itemId)
	local own = if def then handle:FindFirstChild(ItemUtil.getSlotDef(def.slot).attachment) else nil
	local offset = if own ~= nil and own:IsA("Attachment") then own.CFrame else CFrame.identity
	handle.Anchored = true
	model:PivotTo(target.WorldCFrame * offset:Inverse())
end

-- Floating name / rarity / income label.
function ItemVisuals.makeLabel(item: Types.ItemInstance, adornee: BasePart, heightOffset: number): BillboardGui
	local rarity = ItemUtil.getRarity(item)

	local gui = Instance.new("BillboardGui")
	gui.Name = "ItemLabel"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(9, 2.2)
	gui.StudsOffset = Vector3.new(0, heightOffset, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.56)
	name.Font = Enum.Font.GothamBlack
	name.RichText = true
	name.Text = ItemUtil.getRichName(item)
	name.TextColor3 = rarity.uiColor
	name.TextScaled = true
	name.Parent = gui

	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0, 0.56)
	info.Size = UDim2.fromScale(1, 0.44)
	info.Font = Enum.Font.GothamBold
	info.Text = `{Format.upper(rarity.displayName)}  •  {Format.money(ItemUtil.getIncome(item))}/с`
	info.TextColor3 = WHITE
	info.TextScaled = true
	info.Parent = gui

	for _, label in { name, info } do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.2
		stroke.Parent = label
	end

	return gui
end

return ItemVisuals
