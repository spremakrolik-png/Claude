--!strict
-- Colors, fonts and small builders shared by every client controller.
local Workspace = game:GetService("Workspace")

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(30, 16, 44),
	PanelLight = Color3.fromRGB(52, 28, 74),
	Stroke = Color3.fromRGB(255, 80, 190),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(196, 176, 218),
	Money = Color3.fromRGB(126, 255, 150),
	Pink = Color3.fromRGB(255, 80, 190),
	Purple = Color3.fromRGB(150, 80, 255),
	Gold = Color3.fromRGB(255, 208, 70),
	Warning = Color3.fromRGB(255, 186, 80),
	Danger = Color3.fromRGB(255, 84, 104),
	Confirm = Color3.fromRGB(70, 210, 120),
	Neutral = Color3.fromRGB(110, 100, 130),
	Empty = Color3.fromRGB(90, 80, 110),
}

Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
}

-- Creates an instance and assigns properties; `Parent` is applied last.
function Theme.new(className: string, props: { [string]: any }?, children: { any }?): any
	local instance: any = Instance.new(className :: any)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Returns Instance (not UICorner) so it can lead a children list of mixed instance types.
function Theme.corner(radius: number): Instance
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Theme.stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(): UIStroke
	return Theme.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.35 })
end

function Theme.padding(pixels: number): Instance
	local amount = UDim.new(0, pixels)
	return Theme.new("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
	})
end

function Theme.label(props: { [string]: any }): TextLabel
	local label: TextLabel = Theme.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	Theme.textStroke().Parent = label
	return label
end

-- Scales a fixed-pixel layout with the screen so it stays readable on phones and does not dominate monitors.
function Theme.autoScale(target: GuiObject)
	local scale: UIScale = Theme.new("UIScale", { Parent = target })
	local connection: RBXScriptConnection? = nil
	local function update()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.62, 1.2)
	end
	local function bindCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

return Theme
