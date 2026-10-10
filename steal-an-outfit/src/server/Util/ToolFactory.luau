--!strict
-- Builds the Tool for a tool definition: ReplicatedStorage/Assets/Tools/<id> when it exists, otherwise a
-- placeholder from primitives. The Tool carries a "ToolId" attribute the server checks on every use.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local ToolFactory = {}

local PINK = Color3.fromRGB(255, 80, 160)
local GOLD = Color3.fromRGB(255, 205, 70)

local function piece(
	parent: Instance,
	handle: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
	return part
end

-- A pink handbag with a gold strap; the hand holds the top of the strap.
local function buildHandbag(tool: Tool)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.3, 1, 0.5)
	handle.Color = PINK
	handle.Material = Enum.Material.SmoothPlastic
	handle.Reflectance = 0.1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	piece(tool, handle, Vector3.new(1.34, 0.36, 0.54), CFrame.new(0, 0.34, 0), Color3.fromRGB(255, 140, 195))
	piece(tool, handle, Vector3.one * 0.2, CFrame.new(0, 0.2, -0.3), GOLD, Enum.Material.Foil)
	piece(
		tool,
		handle,
		Vector3.new(0.1, 0.75, 0.1),
		CFrame.new(-0.35, 0.82, 0) * CFrame.Angles(0, 0, -0.35),
		GOLD,
		Enum.Material.Foil
	)
	piece(
		tool,
		handle,
		Vector3.new(0.1, 0.75, 0.1),
		CFrame.new(0.35, 0.82, 0) * CFrame.Angles(0, 0, 0.35),
		GOLD,
		Enum.Material.Foil
	)
	piece(tool, handle, Vector3.new(0.5, 0.1, 0.1), CFrame.new(0, 1.15, 0), GOLD, Enum.Material.Foil)

	-- Grip: the handle point that sits in the hand (strap top), so the bag hangs below the fist.
	tool.Grip = CFrame.new(0, 1.15, 0)
end

local BUILDERS: { [string]: (Tool) -> () } = {
	HandbagSlap = buildHandbag,
}

function ToolFactory.create(def: Types.ToolDef): Tool
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Tools") else nil
	local template = if folder then folder:FindFirstChild(def.id) else nil

	local tool: Tool
	if template ~= nil and template:IsA("Tool") then
		tool = template:Clone()
	else
		tool = Instance.new("Tool")
		local build = BUILDERS[def.id]
		if build then
			build(tool)
		else
			warn(`No placeholder for tool "{def.id}"`)
		end
	end
	tool.Name = def.displayName
	tool.ToolTip = def.displayName
	tool.CanBeDropped = false
	tool:SetAttribute("ToolId", def.id)
	return tool
end

return ToolFactory
