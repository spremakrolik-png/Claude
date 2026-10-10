--!strict
-- "This slot is taken - swap?" dialog. The server keeps the decision: the client only answers the offer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local ItemUtil = require(Shared.ItemUtil)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

type Card = {
	name: TextLabel,
	info: TextLabel,
	stroke: UIStroke,
}

local Colors = Theme.Colors

local SwapController = {}

local dialog: Frame
local title: TextLabel
local oldCard: Card
local newCard: Card
local countdown: Frame
local current: Types.SwapOffer? = nil

local function buildCard(parent: Frame, caption: string, x: number): Card
	local stroke = Theme.stroke(Colors.Empty, 2)
	local frame: Frame = Theme.new("Frame", {
		Position = UDim2.fromOffset(x, 64),
		Size = UDim2.fromOffset(200, 112),
		BackgroundColor3 = Colors.PanelLight,
		Parent = parent,
	}, { Theme.corner(12), stroke })
	Theme.label({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = caption,
		Parent = frame,
	})
	local name = Theme.label({
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 0, 48),
		RichText = true,
		TextWrapped = true,
		Text = "",
		Parent = frame,
	})
	local info = Theme.label({
		Position = UDim2.fromOffset(10, 82),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Theme.Fonts.Body,
		Text = "",
		Parent = frame,
	})
	return { name = name, info = info, stroke = stroke }
end

local function fillCard(card: Card, item: Types.ItemInstance)
	local rarity = ItemUtil.getRarity(item)
	card.name.Text = ItemUtil.getRichName(item)
	card.name.TextColor3 = rarity.uiColor
	card.info.Text = `{string.upper(rarity.id)}  •  {Format.money(ItemUtil.getIncome(item))}/s`
	card.stroke.Color = rarity.uiColor
end

local function close()
	current = nil
	dialog.Visible = false
end

local function respond(accept: boolean)
	local offer = current
	if offer == nil then
		return
	end
	close()
	Remotes.get("SwapResponse"):FireServer(offer.offerId, accept)
end

local function button(parent: Frame, text: string, color: Color3, x: number, accept: boolean)
	local instance: TextButton = Theme.new("TextButton", {
		Position = UDim2.fromOffset(x, 214),
		Size = UDim2.fromOffset(200, 56),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Modal = true, -- frees the mouse in first person / Shift Lock while the dialog is open
		Font = Theme.Fonts.Display,
		Text = text,
		TextColor3 = Colors.Text,
		TextScaled = true,
		Parent = parent,
	}, { Theme.corner(14), Theme.padding(10), Theme.textStroke() })
	instance.Activated:Connect(function()
		respond(accept)
	end)
end

local function show(offer: Types.SwapOffer)
	current = offer
	local slotName = ItemUtil.getSlotDef(offer.slot).displayName
	title.Text = `Your {string.upper(slotName)} slot is taken. Swap?`
	fillCard(oldCard, offer.oldItem)
	fillCard(newCard, offer.newItem)
	dialog.Visible = true

	task.spawn(function()
		while current == offer do
			local left = offer.expiresAt - Workspace:GetServerTimeNow()
			countdown.Size = UDim2.fromScale(math.clamp(left / GameConfig.Drops.SwapOfferSeconds, 0, 1), 1)
			if left <= 0 then
				close()
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

function SwapController.Init()
	local gui = Theme.new("ScreenGui", {
		Name = "SwapDialog",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	dialog = Theme.new("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(470, 300),
		BackgroundColor3 = Colors.Panel,
		Visible = false,
		Parent = gui,
	}, { Theme.corner(18), Theme.stroke(Colors.Stroke, 3) })
	Theme.autoScale(dialog)

	title = Theme.label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 36),
		Text = "",
		Parent = dialog,
	})
	oldCard = buildCard(dialog, "YOU WEAR", 20)
	newCard = buildCard(dialog, "NEW", 250)
	Theme.label({
		Position = UDim2.fromOffset(20, 182),
		Size = UDim2.new(1, -40, 0, 22),
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = "Your current item drops on the floor - anyone can grab it!",
		Parent = dialog,
	})
	button(dialog, "SWAP", Colors.Confirm, 20, true)
	button(dialog, "CANCEL", Colors.Neutral, 250, false)

	local track: Frame = Theme.new("Frame", {
		Position = UDim2.new(0, 20, 1, -16),
		Size = UDim2.new(1, -40, 0, 6),
		BackgroundColor3 = Colors.PanelLight,
		Parent = dialog,
	}, { Theme.corner(3) })
	countdown = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Pink,
		Parent = track,
	}, { Theme.corner(3) })
end

function SwapController.Start()
	Remotes.get("SwapOffer").OnClientEvent:Connect(function(offer: unknown)
		if typeof(offer) == "table" then
			show(offer :: Types.SwapOffer)
		end
	end)
end

return SwapController
