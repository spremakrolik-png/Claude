--!strict
-- Timers, sizes and durations. Gameplay code reads every tunable number from the Config folder.
local Types = require(script.Parent.Parent.Types)

local Slots: { Types.SlotDef } = {
	{ id = "Head", attachment = "HatAttachment", displayName = "Head" },
	{ id = "Face", attachment = "FaceFrontAttachment", displayName = "Face" },
	{ id = "Neck", attachment = "NeckAttachment", displayName = "Neck" },
	{ id = "Chest", attachment = "BodyFrontAttachment", displayName = "Chest" },
	{ id = "Back", attachment = "BodyBackAttachment", displayName = "Back" },
	{ id = "Waist", attachment = "WaistCenterAttachment", displayName = "Waist" },
}

local GameConfig = {
	-- Order of the body slots in the HUD and everywhere else.
	Slots = Slots,

	RespawnSeconds = 3,

	Map = {
		ArenaRadius = 92, -- inner face of the outer wall (diameter ~184 studs)
		WallHeight = 30,
		WallThickness = 2,
		WallSegments = 48, -- must be a multiple of BaseCount so doors land on segment centers

		PodiumRadius = 18,
		PodiumHeight = 2,
		PodiumTiers = 3, -- shallow steps around the podium act as a ramp

		CatwalkCount = 4,
		CatwalkWidth = 6,
		CatwalkHeight = 1,

		MannequinCount = 12,
		MannequinRingRadius = 45,
		GrandMannequinScale = 1.6,

		BaseCount = 8,
		BaseWidth = 20,
		BaseDepth = 22,
		BaseHeight = 14,
		DoorWidth = 10,
		DoorHeight = 11,
	},

	Drops = {
		WaveIntervalSeconds = 60,
		FirstWaveDelaySeconds = 5,
		MaxAnnouncementsPerWave = 3,

		MannequinHoldSeconds = 0.6,
		FloorHoldSeconds = 0.3,
		PromptDistance = 8,
		PickupDistanceSlack = 6, -- extra studs tolerated on the server on top of PromptDistance

		FloorItemLifetimeSeconds = 30,
		FloorSettleSeconds = 1.2, -- physics time before a dropped item is anchored and becomes pickable
		DropPopHorizontal = 12,
		DropPopVertical = 26,

		SwapOfferSeconds = 8,
		SwapMaxDistance = 18, -- the item can be this far away when the player confirms a swap
	},

	Economy = {
		StartingCash = 0,
		IncomeTickSeconds = 1,
		SellMultiplier = 30, -- sell price = income per second * this
	},

	Zones = {
		PollSeconds = 0.2,
	},

	RateLimits = {
		SwapResponsePerSecond = 4,
		ClientReadyPerMinute = 6,
	},
}

return GameConfig
