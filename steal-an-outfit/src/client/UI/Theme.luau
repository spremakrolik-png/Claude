--!strict
-- Colors, fonts and small builders shared by every client controller.
local Workspace = game:GetService("Workspace")

local Theme = {}

-- Bright "sticker" look: saturated panels with a white border, white text with a dark outline.
Theme.Colors = {
	Panel = Color3.fromRGB(255, 90, 165), -- pink
	PanelAlt = Color3.fromRGB(70, 150, 255), -- blue
	PanelLight = Color3.fromRGB(255, 160, 205),
	Border = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextOutline = Color3.fromRGB(70, 25, 65),
	Muted = Color3.fromRGB(255, 228, 242),
	Money = Color3.fromRGB(255, 242, 120),
	Income = Color3.fromRGB(205, 255, 190),
	Gold = Color3.fromRGB(255, 205, 60),
	Info = Color3.fromRGB(70, 150, 255),
	Success = Color3.fromRGB(60, 200, 110),
	Warning = Color3.fromRGB(255, 150, 40),
	Danger = Color3.fromRGB(255, 80, 100),
	Confirm = Color3.fromRGB(60, 200, 110),
	Neutral = Color3.fromRGB(150, 140, 170),
	Empty = Color3.fromRGB(205, 195, 222),
}

-- Montserrat (Gotham) has Cyrillic glyphs; FredokaOne does not.
Theme.Fonts = {
	Display = Enum.Font.GothamBlack,
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
	return Theme.new("UIStroke", { Color = Theme.Colors.TextOutline, Thickness = 2, Transparency = 0 })
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
